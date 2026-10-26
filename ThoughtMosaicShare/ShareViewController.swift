import UIKit
import SwiftUI
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private var loadingTask: Task<Void, Never>?
    override func viewDidLoad() {
        super.viewDidLoad()
        let model = ShareCaptureModel()
        let root = ShareCaptureView(model: model, close: { [weak self] in
            self?.loadingTask?.cancel()
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        })
        let hosting = UIHostingController(rootView: root)
        addChild(hosting); view.addSubview(hosting.view); hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor), hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hosting.didMove(toParent: self)
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        loadingTask = Task { await model.load(items) }
    }
}

@MainActor
final class ShareCaptureModel: ObservableObject {
    @Published var note = MosaicNote()
    @Published var previews: [UUID: UIImage] = [:]
    @Published var loading = true
    @Published var saved = false
    @Published var loadedSuccessfully = false
    @Published var error: String?
    private var media: [String: Data] = [:]

    func load(_ items: [NSExtensionItem]) async {
        defer { loading = false }
        do {
            for provider in items.flatMap({ $0.attachments ?? [] }) {
                try Task.checkCancellation()
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) || provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    guard note.attachments.count < 5 else { throw MosaicShareInbox.InboxError.invalidItem }
                    let data: Data
                    if provider.canLoadObject(ofClass: UIImage.self) {
                        data = try await withCheckedThrowingContinuation { continuation in
                            provider.loadObject(ofClass: UIImage.self) { object, error in
                                if let image = object as? UIImage, let jpeg = image.jpegData(compressionQuality: 0.9) {
                                    continuation.resume(returning: jpeg)
                                } else { continuation.resume(throwing: error ?? MosaicError.invalidAttachment) }
                            }
                        }
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                        data = try await withCheckedThrowingContinuation { continuation in
                            provider.loadItem(forTypeIdentifier: UTType.image.identifier) { value, error in
                                do { continuation.resume(returning: try Self.imageData(from: value)) }
                                catch { continuation.resume(throwing: error) }
                            }
                        }
                    } else {
                        // Files and Safari can provide the image as a security-scoped file URL.
                        data = try await withCheckedThrowingContinuation { continuation in
                            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { value, error in
                                do {
                                    guard let file = value as? URL, file.isFileURL else { throw error ?? MosaicError.invalidAttachment }
                                    let scoped = file.startAccessingSecurityScopedResource()
                                    defer { if scoped { file.stopAccessingSecurityScopedResource() } }
                                    let values = try file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                                    guard values.isRegularFile == true, let size = values.fileSize, size <= 30_000_000 else { throw MosaicError.invalidAttachment }
                                    continuation.resume(returning: try Data(contentsOf: file))
                                } catch { continuation.resume(throwing: error) }
                            }
                        }
                    }
                    guard data.count <= 30_000_000 else { throw MosaicShareInbox.InboxError.invalidItem }
                    let jpeg = try await Task.detached(priority: .userInitiated) {
                        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { throw MosaicError.invalidAttachment }
                        let scale = min(1, 2000 / max(image.size.width, image.size.height))
                        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                        let format = UIGraphicsImageRendererFormat()
                        format.scale = 1
                        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                            image.draw(in: CGRect(origin: .zero, size: size))
                        }
                        guard let result = resized.jpegData(compressionQuality: 0.85) else { throw MosaicError.invalidAttachment }
                        return result
                    }.value
                    try Task.checkCancellation()
                    let attachment = MosaicAttachment(kind: .screenshot, filename: UUID().uuidString + ".jpg")
                    media[attachment.filename] = jpeg; previews[attachment.id] = UIImage(data: jpeg)
                    note.attachments.append(attachment)
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    let link: URL = try await withCheckedThrowingContinuation { continuation in
                        provider.loadItem(forTypeIdentifier: UTType.url.identifier) { value, error in
                            if let link = value as? URL { continuation.resume(returning: link) }
                            else { continuation.resume(throwing: error ?? MosaicError.invalidAttachment) }
                        }
                    }
                    if !note.text.isEmpty { note.text += "\n" }; note.text += link.absoluteString
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    let text: String = try await withCheckedThrowingContinuation { continuation in
                        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { value, error in
                            if let text = value as? String { continuation.resume(returning: text) }
                            else if let data = value as? Data, let text = String(data: data, encoding: .utf8) { continuation.resume(returning: text) }
                            else { continuation.resume(throwing: error ?? MosaicError.invalidAttachment) }
                        }
                    }
                    if !note.text.isEmpty { note.text += "\n" }; note.text += text
                }
            }
            loadedSuccessfully = true
        } catch is CancellationError { }
        catch { self.error = "素材没有完整载入，请取消后重新分享。\n\(error.localizedDescription)" }
    }
    private nonisolated static func imageData(from value: Any?) throws -> Data {
        if let image = value as? UIImage, let data = image.jpegData(compressionQuality: 0.9) { return data }
        if let data = value as? Data {
            guard data.count <= 30_000_000 else { throw MosaicError.invalidAttachment }
            if UIImage(data: data) != nil { return data }
            // Some share providers offer a securely archived UIImage under public.image.
            if let image = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIImage.self, from: data),
               let jpeg = image.jpegData(compressionQuality: 0.9) { return jpeg }
        }
        if let file = value as? URL, file.isFileURL {
            let scoped = file.startAccessingSecurityScopedResource()
            defer { if scoped { file.stopAccessingSecurityScopedResource() } }
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true, let size = values.fileSize, size <= 30_000_000 else { throw MosaicError.invalidAttachment }
            return try Data(contentsOf: file)
        }
        throw MosaicError.invalidAttachment
    }

    func save() {
        do {
            note.tags = MosaicNote.normalizedTags(note.tags); note.updatedAt = Date()
            let selectedMedia = Dictionary(uniqueKeysWithValues: note.attachments.compactMap { attachment in
                media[attachment.filename].map { (attachment.filename, $0) }
            })
            try MosaicShareInbox.shared().submit(.init(note: note, media: selectedMedia))
            saved = true
        } catch { self.error = error.localizedDescription }
    }
}

private struct ShareCaptureView: View {
    @ObservedObject var model: ShareCaptureModel
    let close: () -> Void
    @State private var showTags = false
    @State private var confirmCancel = false
    @FocusState private var typing: Bool
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if model.saved {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 60)).padding(.top, 30)
                        Text("已保存").font(.title.bold()).accessibilityIdentifier("sharedSaved")
                        Text("已保留这次分享。打开 Thought Mosaic 后，会自动加入记录列表。")
                            .foregroundStyle(.secondary)
                        Button("完成", action: close).buttonStyle(MosaicButtonStyle(primary: true))
                    } else {
                        if model.loading { ProgressView("正在接收分享内容…") }
                        if let error = model.error { Text(error).foregroundStyle(.red).font(.footnote) }
                        ForEach(model.note.attachments) { attachment in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("分享的图片").font(.caption)
                                    Spacer()
                                    Button("移除", systemImage: "xmark") { model.note.attachments.removeAll { $0.id == attachment.id } }
                                        .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                                }
                                if let image = model.previews[attachment.id] {
                                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 210).clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }.padding(10).background(MosaicTheme.material, in: RoundedRectangle(cornerRadius: 14))
                        }
                        Text("想记住什么？一句话也可以。").font(.headline)
                        TextEditor(text: $model.note.text).frame(height: 120).focused($typing)
                            .padding(8).overlay(RoundedRectangle(cornerRadius: 12).stroke(MosaicTheme.line))
                            .accessibilityLabel("分享想法内容").accessibilityIdentifier("sharedThoughtText")
                        if typing { Button("完成输入") { typing = false }.frame(minHeight: 44) }
                        Text("标签（可选）").font(.subheadline.bold())
                        TagFlow {
                            ForEach(model.note.tags, id: \.self) { TagChip(text: $0) }
                            Button("＋ 添加标签") { typing = false; showTags = true }.frame(minHeight: 44)
                        }
                    }
                }.padding(20)
            }
            .navigationTitle("截图与灵感").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !model.saved {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { typing = false; confirmCancel = true } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") { typing = false; model.save() }.buttonStyle(.borderedProminent)
                            .disabled(model.loading || !model.note.hasContent || !model.loadedSuccessfully)
                            .accessibilityIdentifier("saveSharedNote")
                    }
                }
            }
            .alert("放弃这次分享？", isPresented: $confirmCancel) {
                Button("继续编辑", role: .cancel) {}
                Button("放弃", role: .destructive, action: close)
            } message: { Text("未保存的文字不会保留，原始截图仍在来源 App 中。") }
            .sheet(isPresented: $showTags) {
                TagSheet(selected: model.note.tags, recent: ["街头观察", "绘画参考", "人物动作", "日常生活"]) { model.note.tags = $0 }
            }
        }.tint(MosaicTheme.action)
    }
}
