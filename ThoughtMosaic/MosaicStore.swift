import SwiftUI
import UIKit

@MainActor
final class MosaicStore: ObservableObject {
    @Published private(set) var archive = MosaicArchive()
    @Published var message: String?
    @Published private(set) var loadFailed = false
    @Published var requestedEntry: CaptureEntry?
    let repository: MosaicRepository

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let arguments = ProcessInfo.processInfo.arguments
        let testing = arguments.contains("--ui-testing")
        let testID = arguments.first { $0.hasPrefix("--test-session=") }
            .flatMap { UUID(uuidString: String($0.dropFirst("--test-session=".count))) }
        let folder = testing ? "MosaicUITests/\(testID?.uuidString ?? "Default")" : "ThoughtMosaic"
        repository = MosaicRepository(directory: base.appendingPathComponent(folder))
        do { archive = try repository.load() }
        catch {
            loadFailed = true
            message = "无法读取本地记录，原文件已保留。\n\(error.localizedDescription)"
        }
    }

    @discardableResult
    func save(_ note: MosaicNote) -> Bool {
        update { try $0.save(note) }
    }

    @discardableResult
    func keepDraft(_ note: MosaicNote) -> Bool {
        update {
            if note.hasContent { $0.draft = note }
            else if $0.draft?.id == note.id { $0.draft = nil }
        }
    }

    @discardableResult
    func discardDraft(id: UUID) -> Bool {
        update { if $0.draft?.id == id { $0.draft = nil } }
    }

    private func update(_ change: (inout MosaicArchive) throws -> Void) -> Bool {
        guard !loadFailed else {
            message = "本地记录尚未成功读取，为保护原文件，暂时无法写入。"
            return false
        }
        do {
            var next = archive
            try change(&next)
            try repository.write(next)
            archive = next
            return true
        } catch {
            message = "保存失败，内容仍留在编辑页。\n\(error.localizedDescription)"
            return false
        }
    }

    func importImage(_ image: UIImage, kind: MosaicAttachment.Kind = .photo) throws -> MosaicAttachment {
        let maxSide: CGFloat = 2000
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = resized.jpegData(compressionQuality: 0.85) else { throw MosaicError.invalidAttachment }
        return try repository.importMedia(data, kind: kind, extension: "jpg")
    }
}
