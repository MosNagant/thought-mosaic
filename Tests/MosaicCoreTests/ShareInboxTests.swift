import XCTest
@testable import MosaicCore

final class ShareInboxTests: XCTestCase {
    private func fixture() throws -> (URL, MosaicRepository, MosaicShareInbox) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (root, MosaicRepository(directory: root.appendingPathComponent("App")), MosaicShareInbox(directory: root.appendingPathComponent("Inbox")))
    }
    private func item() -> MosaicShareInbox.Item {
        let attachment = MosaicAttachment(kind: .screenshot, filename: UUID().uuidString + ".jpg")
        return .init(note: MosaicNote(text: "From the screenshot", tags: [" 参考 ", "参考"], attachments: [attachment]), media: [attachment.filename: Data([1,2,3])])
    }
    func testImportPreservesExistingNotesDraftAndMediaAndRetriesIdempotently() throws {
        let (root, repo, inbox) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        var archive = MosaicArchive(); let original = MosaicNote(text: "Existing note")
        try archive.save(original); archive.draft = MosaicNote(text: "Unfinished draft")
        try repo.write(archive)
        let incoming = item(); try inbox.submit(incoming)
        let report = try inbox.importPending(into: repo)
        XCTAssertEqual(report.imported.count, 1); XCTAssertEqual(report.failureCount, 0)
        XCTAssertEqual(report.archive.draft, archive.draft)
        XCTAssertEqual(report.archive.notes.count, 2)
        let imported = try XCTUnwrap(report.archive.notes.first { $0.id == incoming.note.id })
        XCTAssertEqual(imported.tags, ["参考"])
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(repo.mediaURL(for: imported.attachments[0]))), Data([1,2,3]))
        // Retrying the same submission must not overwrite an already edited note.
        var changed = report.archive; var edited = imported; edited.text = "Edited after import"; try changed.save(edited); try repo.write(changed)
        try inbox.submit(incoming)
        let retried = try inbox.importPending(into: repo)
        XCTAssertEqual(retried.imported.count, 0); XCTAssertEqual(retried.archive.notes.count, 2)
        XCTAssertEqual(retried.archive.notes.first { $0.id == incoming.note.id }?.text, "Edited after import")
    }
    func testBrokenSubmissionIsRetainedWhileValidSubmissionImports() throws {
        let (root, repo, inbox) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        try inbox.submit(item())
        let broken = inbox.directory.appendingPathComponent("broken.json")
        try Data("invalid".utf8).write(to: broken)
        let report = try inbox.importPending(into: repo)
        XCTAssertEqual(report.imported.count, 1); XCTAssertEqual(report.failureCount, 1)
        XCTAssertEqual(try Data(contentsOf: broken), Data("invalid".utf8))
    }
    func testMissingMediaAndPathTraversalAreRejected() throws {
        let (root, _, inbox) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        var broken = item(); broken.media = [:]
        XCTAssertThrowsError(try inbox.submit(broken))
        broken.note.attachments[0].filename = "../outside.jpg"; broken.media = ["../outside.jpg": Data([1])]
        XCTAssertThrowsError(try inbox.submit(broken))
        XCTAssertThrowsError(try inbox.submit(.init(note: MosaicNote(), media: [:])))
    }
    func testFailedArchiveWriteKeepsIncomingSubmission() throws {
        let (root, repo, inbox) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        try Data("not a directory".utf8).write(to: repo.directory)
        let incoming = item(); try inbox.submit(incoming)
        let report = try inbox.importPending(into: repo)
        XCTAssertEqual(report.imported.count, 0); XCTAssertEqual(report.failureCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: inbox.directory.appendingPathComponent(incoming.note.id.uuidString + ".json").path))
    }
}
