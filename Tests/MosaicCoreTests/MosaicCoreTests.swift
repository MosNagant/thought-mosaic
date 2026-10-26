import XCTest
@testable import MosaicCore

final class MosaicCoreTests: XCTestCase {
    func testSaveAndDraftSurviveReload() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = MosaicRepository(directory: folder)
        var archive = try repository.load()
        let attachment = try repository.importMedia(Data([1, 2, 3]), kind: .photo, extension: "jpg")
        let note = MosaicNote(text: "街角的光", tags: [" 绘画参考 ", "绘画参考", ""], attachments: [attachment])
        archive.draft = note
        try repository.write(archive)
        XCTAssertEqual(try repository.load().draft, note)
        try archive.save(note)
        try repository.write(archive)
        let reloaded = try repository.load()
        XCTAssertNil(reloaded.draft)
        XCTAssertEqual(reloaded.notes.count, 1)
        XCTAssertEqual(reloaded.notes[0].tags, ["绘画参考"])
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(repository.mediaURL(for: attachment))), Data([1, 2, 3]))
    }

    func testEmptyNoteCannotBeSavedButAudioCan() throws {
        var archive = MosaicArchive()
        XCTAssertThrowsError(try archive.save(MosaicNote(text: " \n ", tags: ["标签"])))
        try archive.save(MosaicNote(attachments: [.init(kind: .audio, filename: "voice.m4a", duration: 3)]))
        XCTAssertEqual(archive.notes.first?.title, "语音")
    }

    func testEditingDoesNotDuplicateOrClearAnotherDraft() throws {
        var archive = MosaicArchive()
        var note = MosaicNote(text: "first")
        try archive.save(note)
        let other = MosaicNote(text: "another draft")
        archive.draft = other
        note.text = "edited"
        try archive.save(note)
        XCTAssertEqual(archive.notes.count, 1)
        XCTAssertEqual(archive.notes.first?.text, "edited")
        XCTAssertEqual(archive.draft, other)
    }

    func testCorruptArchiveIsReportedAndPreserved() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let repo = MosaicRepository(directory: folder)
        let corrupt = Data("not json".utf8)
        try corrupt.write(to: repo.archiveURL)
        XCTAssertThrowsError(try repo.load())
        XCTAssertEqual(try Data(contentsOf: repo.archiveURL), corrupt)
    }

    func testAttachmentCannotEscapeMediaDirectory() {
        let repo = MosaicRepository(directory: URL(fileURLWithPath: "/tmp/Mosaic"))
        XCTAssertNil(repo.mediaURL(for: .init(kind: .photo, filename: "../other.jpg")))
        XCTAssertNil(repo.mediaURL(for: .init(kind: .photo, filename: "/etc/hosts")))
    }
}
