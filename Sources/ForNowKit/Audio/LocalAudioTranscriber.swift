import AVFoundation
import Foundation
import Speech

public enum LocalTranscriptionError: LocalizedError {
    case unavailable(String)

    public var errorDescription: String? {
        switch self { case .unavailable(let message): return message }
    }
}

public protocol AudioTranscribing: Sendable {
    func transcribe(fileURL: URL, localeIdentifier: String,
                    progress: @escaping @Sendable (AudioTranscription.Status) async -> Void) async throws -> String
}

/// 只使用设备端 SpeechTranscriber；不回退到服务器识别。
public actor LocalAudioTranscriber: AudioTranscribing {
    public init() {}

    public func transcribe(fileURL: URL, localeIdentifier: String,
                           progress: @escaping @Sendable (AudioTranscription.Status) async -> Void) async throws -> String {
        guard #available(macOS 26.0, *) else {
            throw LocalTranscriptionError.unavailable("本地转写需要 macOS 26 或更高版本")
        }
        guard SpeechTranscriber.isAvailable else {
            throw LocalTranscriptionError.unavailable("当前设备不支持本地转写，录音已保留")
        }
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: localeIdentifier)) else {
            throw LocalTranscriptionError.unavailable("不支持所选转写语言，请在设置中更换")
        }
        try Task.checkCancellation()
        await progress(.preparing)
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        let alreadyReserved = await AssetInventory.reservedLocales.contains(locale)
        if !alreadyReserved { try await AssetInventory.reserve(locale: locale) }
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
            try Task.checkCancellation()
            await progress(.transcribing)
            let text = try await analyze(fileURL: fileURL, transcriber: transcriber)
            if !alreadyReserved { await AssetInventory.release(reservedLocale: locale) }
            return text
        } catch {
            if !alreadyReserved { await AssetInventory.release(reservedLocale: locale) }
            throw error
        }
    }

    @available(macOS 26.0, *)
    private func analyze(fileURL: URL, transcriber: SpeechTranscriber) async throws -> String {
        let file = try AVAudioFile(forReading: fileURL)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        return try await withTaskCancellationHandler {
            // 必须同时消费结果，避免长文件分析因结果背压阻塞。
            try await withThrowingTaskGroup(of: String?.self) { group in
                group.addTask {
                    var text = ""
                    for try await result in transcriber.results {
                        text += String(result.text.characters)
                    }
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                group.addTask {
                    if let end = try await analyzer.analyzeSequence(from: file) {
                        try await analyzer.finalizeAndFinish(through: end)
                    } else {
                        await analyzer.cancelAndFinishNow()
                    }
                    return nil
                }
                do {
                    var text = ""
                    for try await result in group {
                        if let result { text = result }
                    }
                    return text
                } catch {
                    group.cancelAll()
                    await analyzer.cancelAndFinishNow()
                    throw error
                }
            }
        } onCancel: {
            Task { await analyzer.cancelAndFinishNow() }
        }
    }
}
