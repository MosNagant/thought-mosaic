import Foundation

public struct MosaicAttachment: Codable, Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case photo, screenshot, audio, sample }
    public var id: UUID
    public var kind: Kind
    public var filename: String
    public var duration: TimeInterval?

    public init(id: UUID = UUID(), kind: Kind, filename: String, duration: TimeInterval? = nil) {
        self.id = id
        self.kind = kind
        self.filename = filename
        self.duration = duration
    }

    public var label: String {
        switch kind {
        case .photo: return "照片"
        case .screenshot: return "截图"
        case .audio: return "语音"
        case .sample: return "示例素材"
        }
    }
}

public struct MosaicNote: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var text: String
    public var tags: [String]
    public var attachments: [MosaicAttachment]
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), text: String = "", tags: [String] = [],
                attachments: [MosaicAttachment] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.text = text
        self.tags = tags
        self.attachments = attachments
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
    }

    public var title: String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? (attachments.first?.label ?? "灵感记录") : value
    }

    public static func normalizedTags(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let tag = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
            guard !tag.isEmpty, seen.insert(tag.lowercased()).inserted else { return nil }
            return tag
        }
    }
}

public struct MosaicArchive: Codable, Equatable, Sendable {
    public var schemaVersion: Int = 1
    public var notes: [MosaicNote] = []
    public var draft: MosaicNote?
    public init() {}

    public var recentTags: [String] {
        MosaicNote.normalizedTags(notes.sorted { $0.updatedAt > $1.updatedAt }.flatMap(\.tags)
            + ["街头观察", "人物动作", "绘画参考", "日常生活"])
    }

    public mutating func save(_ value: MosaicNote, now: Date = Date()) throws {
        guard value.hasContent else { throw MosaicError.emptyNote }
        var note = value
        note.updatedAt = now
        note.tags = MosaicNote.normalizedTags(note.tags)
        notes.removeAll { $0.id == note.id }
        notes.insert(note, at: 0)
        if draft?.id == note.id { draft = nil }
    }
}

public enum MosaicError: LocalizedError {
    case emptyNote, unsupportedArchive, invalidAttachment
    public var errorDescription: String? {
        switch self {
        case .emptyNote: return "写下一句话，或添加一份素材后再保存。"
        case .unsupportedArchive: return "记录来自更新版本，请更新 App 后再打开。"
        case .invalidAttachment: return "素材文件无法读取，请重新添加。"
        }
    }
}

/// Atomic archive replacement keeps the last successful save intact on failure.
public struct MosaicRepository {
    public let directory: URL
    public var archiveURL: URL { directory.appendingPathComponent("mosaic.json") }
    public var mediaDirectory: URL { directory.appendingPathComponent("Media", isDirectory: true) }

    public init(directory: URL) { self.directory = directory }

    public func load() throws -> MosaicArchive {
        guard FileManager.default.fileExists(atPath: archiveURL.path) else { return MosaicArchive() }
        let result = try JSONDecoder().decode(MosaicArchive.self, from: Data(contentsOf: archiveURL))
        guard result.schemaVersion == 1 else { throw MosaicError.unsupportedArchive }
        return result
    }

    public func write(_ archive: MosaicArchive) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(archive).write(to: archiveURL, options: .atomic)
    }

    public func importMedia(_ data: Data, kind: MosaicAttachment.Kind, extension suffix: String,
                            duration: TimeInterval? = nil) throws -> MosaicAttachment {
        guard !data.isEmpty, ["jpg", "png", "m4a"].contains(suffix) else { throw MosaicError.invalidAttachment }
        try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        let attachment = MosaicAttachment(kind: kind, filename: "\(UUID().uuidString).\(suffix)", duration: duration)
        try data.write(to: mediaDirectory.appendingPathComponent(attachment.filename), options: .atomic)
        return attachment
    }

    public func mediaURL(for attachment: MosaicAttachment) -> URL? {
        guard attachment.kind != .sample, !attachment.filename.isEmpty,
              attachment.filename == URL(fileURLWithPath: attachment.filename).lastPathComponent else { return nil }
        return mediaDirectory.appendingPathComponent(attachment.filename)
    }
}
