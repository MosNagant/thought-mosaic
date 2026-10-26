import Foundation

/// Each extension submission is an immutable, atomic file. Only the main app
/// updates its archive, so sharing never races with or overwrites an open draft.
public struct MosaicShareInbox {
    public static let appGroup = "group.com.mosnagant.thoughtmosaic"
    public let directory: URL
    public init(directory: URL) { self.directory = directory }

    public struct Item: Codable, Sendable {
        public var note: MosaicNote
        public var media: [String: Data]
        public init(note: MosaicNote, media: [String: Data]) { self.note = note; self.media = media }
    }
    public struct ImportReport {
        public var archive: MosaicArchive
        public var imported: [MosaicNote]
        public var failureCount: Int
    }
    public static func shared() throws -> MosaicShareInbox {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            throw InboxError.unavailable
        }
        return MosaicShareInbox(directory: container.appendingPathComponent("CaptureInbox", isDirectory: true))
    }
    public enum InboxError: LocalizedError {
        case unavailable, invalidItem
        public var errorDescription: String? {
            switch self {
            case .unavailable: return "共享空间尚未配置。请在 Xcode 为 App 和分享扩展启用同一个 App Group，再安装到设备。"
            case .invalidItem: return "分享内容不完整或图片过大，原内容尚未保存，请重新分享。"
            }
        }
    }
    private func validate(_ item: Item) throws {
        guard item.note.hasContent, item.note.attachments.count <= 5,
              item.media.values.reduce(0, { $0 + $1.count }) <= 25_000_000 else { throw InboxError.invalidItem }
        for attachment in item.note.attachments {
            guard [.photo, .screenshot].contains(attachment.kind),
                  attachment.filename == URL(fileURLWithPath: attachment.filename).lastPathComponent,
                  attachment.filename.hasSuffix(".jpg"),
                  let data = item.media[attachment.filename], !data.isEmpty else { throw InboxError.invalidItem }
        }
    }
    public func submit(_ item: Item) throws {
        try validate(item)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(item).write(to: directory.appendingPathComponent(item.note.id.uuidString + ".json"), options: .atomic)
    }
    public func importPending(into repository: MosaicRepository) throws -> ImportReport {
        var archive = try repository.load()
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return ImportReport(archive: archive, imported: [], failureCount: 0)
        }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
            .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var imported: [MosaicNote] = [], failures = 0
        for file in files {
            do {
                let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? 0) <= 36_000_000 else { throw InboxError.invalidItem }
                let item = try JSONDecoder().decode(Item.self, from: Data(contentsOf: file))
                try validate(item)
                if !archive.notes.contains(where: { $0.id == item.note.id }) {
                    var note = item.note
                    note.attachments = try item.note.attachments.map { attachment in
                        try repository.importMedia(item.media[attachment.filename]!, kind: attachment.kind, extension: "jpg")
                    }
                    var next = archive
                    try next.save(note, now: item.note.updatedAt)
                    try repository.write(next)
                    archive = next
                    imported.append(note)
                }
                // A failed acknowledgement can safely be retried: the UUID is
                // already in the archive and will never create a duplicate.
                try FileManager.default.removeItem(at: file)
            } catch { failures += 1 }
        }
        return ImportReport(archive: archive, imported: imported, failureCount: failures)
    }
}
