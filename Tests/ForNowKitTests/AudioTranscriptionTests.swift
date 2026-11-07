import XCTest
@testable import ForNowKit

@MainActor
final class AudioTranscriptionTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    private func store(now: @escaping () -> Date = Date.init) -> StashStore {
        StashStore(metadataStore: JSONMetadataStore(fileURL: root.appendingPathComponent("items.json")),
                   trashMetadataStore: JSONTrashMetadataStore(fileURL: root.appendingPathComponent("trash.json")),
                   fileStorage: DiskFileStorage(rootDirectory: root.appendingPathComponent("Files")), now: now)
    }

    private func audio(_ store: StashStore, data: String = "audio") throws -> StashItem {
        try store.addAudio(data: Data(data.utf8), suggestedName: "录音", durationSeconds: 8)
    }

    func testOldAudioMetadataLoadsWithoutTranscription() throws {
        let item = try audio(store())
        let decoded = try JSONDecoder().decode(StashItem.self, from: JSONEncoder().encode(item))
        XCTAssertNil(decoded.transcription)
        XCTAssertEqual(decoded.durationSeconds, 8)
    }

    func testLongTranscriptPersistsSeparatelyFromNoteAndAudio() throws {
        let store = store()
        let item = try audio(store)
        store.setNote("原备注", for: item.id)
        let text = String(repeating: "完整转写内容。\n", count: 300)
        store.setTranscription(.init(status: .completed, localeIdentifier: "zh-CN", text: text), for: item.id)
        let reloaded = self.store()
        reloaded.load()
        let saved = try XCTUnwrap(reloaded.audioItem(id: item.id))
        XCTAssertEqual(saved.transcription?.text, text)
        XCTAssertEqual(saved.note, "原备注")
        XCTAssertEqual(saved.relativePath, item.relativePath)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(store.absoluteURL(for: item))), Data("audio".utf8))
    }

    func testReloadMarksUnfinishedJobsInterruptedIncludingTrash() throws {
        let store = store()
        let first = try audio(store, data: "first")
        let second = try audio(store, data: "second")
        store.setTranscription(.init(status: .preparing, localeIdentifier: "zh-CN"), for: first.id)
        store.setTranscription(.init(status: .queued, localeIdentifier: "en-US"), for: second.id)
        store.remove(ids: [second.id])
        let reloaded = self.store()
        reloaded.load()
        XCTAssertEqual(reloaded.audioItem(id: first.id)?.transcription?.status, .interrupted)
        XCTAssertEqual(reloaded.audioItem(id: second.id)?.transcription?.status, .interrupted)
        let persisted = self.store()
        persisted.load()
        XCTAssertEqual(persisted.audioItem(id: second.id)?.transcription?.status, .interrupted)
    }

    func testQueueDeduplicatesSerializesAndPreservesEditsAndTrash() async throws {
        let store = store()
        let first = try audio(store, data: "one")
        let second = try audio(store, data: "two")
        let engine = StubTranscriber(outcomes: [.text("第一段。"), .text("Second.")])
        let controller = AudioTranscriptionController(store: store, transcriber: engine)
        controller.enqueue(first.id, localeIdentifier: "zh-CN")
        controller.enqueue(first.id, localeIdentifier: "zh-CN")
        controller.enqueue(second.id, localeIdentifier: "en-US")
        store.setNote("稍后补充的备注", for: first.id)
        store.setLocked(true, for: [first.id])
        store.remove(ids: [second.id])
        await controller.waitUntilIdle()
        XCTAssertEqual(store.audioItem(id: first.id)?.transcription?.text, "第一段。")
        XCTAssertEqual(store.audioItem(id: first.id)?.note, "稍后补充的备注")
        XCTAssertEqual(store.audioItem(id: first.id)?.locked, true)
        XCTAssertEqual(store.trashItems.first?.item.transcription?.text, "Second.")
        _ = store.restoreFromTrash(ids: [second.id])
        XCTAssertEqual(store.items.first(where: { $0.id == second.id })?.transcription?.text, "Second.")
        let calls = await engine.calls
        let maxConcurrent = await engine.maxConcurrent
        XCTAssertEqual(calls, ["zh-CN", "en-US"])
        XCTAssertEqual(maxConcurrent, 1)
    }

    func testFailureDoesNotBlockNextJobAndRetryCanSucceed() async throws {
        let store = store()
        let first = try audio(store, data: "one")
        let second = try audio(store, data: "two")
        let engine = StubTranscriber(outcomes: [.failure, .text(" \n "), .text("恢复成功")])
        let controller = AudioTranscriptionController(store: store, transcriber: engine)
        controller.enqueue(first.id, localeIdentifier: "zh-CN")
        controller.enqueue(second.id, localeIdentifier: "zh-CN")
        await controller.waitUntilIdle()
        XCTAssertEqual(store.audioItem(id: first.id)?.transcription?.status, .failed)
        XCTAssertEqual(store.audioItem(id: second.id)?.transcription?.status, .noSpeech)
        controller.enqueue(first.id, localeIdentifier: "zh-CN")
        await controller.waitUntilIdle()
        XCTAssertEqual(store.audioItem(id: first.id)?.transcription?.text, "恢复成功")
        XCTAssertEqual(store.audioItem(id: first.id)?.transcription?.status, .completed)
    }

    func testUnavailableRetryPreservesExistingTranscript() async throws {
        let store = store()
        let item = try audio(store)
        store.setTranscription(.init(status: .completed, localeIdentifier: "zh-CN", text: "原文"), for: item.id)
        let controller = AudioTranscriptionController(store: store, transcriber: StubTranscriber(outcomes: [.unavailable]))
        controller.enqueue(item.id, localeIdentifier: "xx")
        await controller.waitUntilIdle()
        XCTAssertEqual(store.audioItem(id: item.id)?.transcription?.status, .unavailable)
        XCTAssertEqual(store.audioItem(id: item.id)?.transcription?.text, "原文")
    }

    func testMissingAndNonAudioItemsCannotAcquireTranscript() {
        let store = store()
        let text = store.addText("文字")
        let result = AudioTranscription(status: .completed, localeIdentifier: "zh-CN", text: "不应写入")
        XCTAssertFalse(store.setTranscription(result, for: UUID()))
        XCTAssertFalse(store.setTranscription(result, for: text.id))
        XCTAssertNil(store.items.first?.transcription)
    }

    func testCompletedJobCannotResurrectExpiredRecording() async throws {
        var now = Date()
        let store = store(now: { now })
        let item = try audio(store)
        let controller = AudioTranscriptionController(store: store, transcriber: StubTranscriber(outcomes: [.text("结果")]))
        controller.enqueue(item.id, localeIdentifier: "zh-CN")
        store.remove(ids: [item.id])
        now = now.addingTimeInterval(31 * 24 * 60 * 60)
        store.purgeExpiredTrash()
        await controller.waitUntilIdle()
        XCTAssertNil(store.audioItem(id: item.id))
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(store.trashItems.isEmpty)
    }
}

private actor StubTranscriber: AudioTranscribing {
    enum Outcome { case text(String), failure, unavailable }
    var outcomes: [Outcome]
    var calls: [String] = []
    var maxConcurrent = 0
    private var inFlight = 0

    init(outcomes: [Outcome]) { self.outcomes = outcomes }

    func transcribe(fileURL: URL, localeIdentifier: String,
                    progress: @escaping @Sendable (AudioTranscription.Status) async -> Void) async throws -> String {
        calls.append(localeIdentifier)
        inFlight += 1
        maxConcurrent = max(maxConcurrent, inFlight)
        defer { inFlight -= 1 }
        let result = outcomes.removeFirst()
        await progress(.preparing)
        await Task.yield()
        await progress(.transcribing)
        switch result {
        case .text(let text): return text
        case .failure: throw CocoaError(.fileReadUnknown)
        case .unavailable: throw LocalTranscriptionError.unavailable("语言不可用")
        }
    }
}
