import Foundation

/// 录音保存后串行转写，避免多段录音同时加载模型、占用设备资源。
@MainActor
public final class AudioTranscriptionController {
    private let store: StashStore
    private let transcriber: any AudioTranscribing
    private var queue: [(id: UUID, locale: String)] = []
    private var pendingIDs: Set<UUID> = []
    private var worker: Task<Void, Never>?

    public init(store: StashStore, transcriber: any AudioTranscribing = LocalAudioTranscriber()) {
        self.store = store
        self.transcriber = transcriber
    }

    public func enqueue(_ itemID: UUID, localeIdentifier: String) {
        guard let item = store.audioItem(id: itemID), !pendingIDs.contains(itemID) else { return }
        pendingIDs.insert(itemID)
        queue.append((itemID, localeIdentifier))
        store.setTranscription(AudioTranscription(status: .queued, localeIdentifier: localeIdentifier,
                                                   text: item.transcription?.text), for: itemID)
        if worker == nil {
            worker = Task { await self.drainQueue() }
        }
    }

    /// 供生命周期管理和测试等待队列落盘，不阻塞主线程。
    public func waitUntilIdle() async { await worker?.value }

    private func drainQueue() async {
        while !queue.isEmpty {
            let job = queue.removeFirst()
            defer { pendingIDs.remove(job.id) }
            guard let item = store.audioItem(id: job.id), let url = store.absoluteURL(for: item) else { continue }
            var result = AudioTranscription(status: .transcribing, localeIdentifier: job.locale,
                                            text: item.transcription?.text)
            do {
                let rawText = try await transcriber.transcribe(fileURL: url, localeIdentifier: job.locale) { [weak self] status in
                    await self?.updateProgress(status, id: job.id)
                }
                let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                result.status = text.isEmpty ? .noSpeech : .completed
                // 重试未识别到语音时也保留之前已保存的原文。
                if !text.isEmpty { result.text = text }
            } catch let error as LocalTranscriptionError {
                result.status = .unavailable
                result.message = error.localizedDescription
            } catch is CancellationError {
                result.status = .interrupted
            } catch {
                result.status = .failed
                result.message = "本地转写失败，请检查语言模型下载或更换语言后重试"
            }
            store.setTranscription(result, for: job.id)
        }
        worker = nil
    }

    private func updateProgress(_ status: AudioTranscription.Status, id: UUID) {
        guard var result = store.audioItem(id: id)?.transcription else { return }
        result.status = status
        store.setTranscription(result, for: id)
    }
}
