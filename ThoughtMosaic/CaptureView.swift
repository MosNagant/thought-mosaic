import SwiftUI
import PhotosUI
import AVFoundation

struct CaptureView: View {
    @EnvironmentObject private var store: MosaicStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var audio = AudioService()
    @State private var note: MosaicNote
    @State private var original: MosaicNote
    @State private var sheet: Sheet?
    @State private var showPhotos = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var importing = false
    @State private var requestingAudio = false
    @State private var showExit = false
    @State private var saved = false
    @State private var openedEntry = false
    @State private var importedKind: MosaicAttachment.Kind = .photo
    @State private var resumeEditingAfterExit = false
    @State private var audioStartTask: Task<Void, Never>?
    @FocusState private var editingText: Bool
    let entry: CaptureEntry

    enum Sheet: String, Identifiable { case tags, camera; var id: String { rawValue } }

    init(note: MosaicNote, entry: CaptureEntry) {
        _note = State(initialValue: note)
        _original = State(initialValue: note)
        self.entry = entry
    }

    var body: some View {
        NavigationStack {
            Group {
                if saved {
                    SavedView(note: note, done: { dismiss() }, again: newNote)
                } else {
                    editor
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle(saved ? "" : "快速记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !saved {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("返回", systemImage: "chevron.backward", action: requestExit)
                            .disabled(importing || requestingAudio)
                            .accessibilityIdentifier("exitEditor")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存", action: save)
                            .buttonStyle(.borderedProminent)
                            .disabled(!note.hasContent || audio.isRecording || importing || requestingAudio)
                            .accessibilityIdentifier("saveNote")
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if editingText {
                    HStack {
                        Spacer()
                        Button("收起键盘", systemImage: "keyboard.chevron.compact.down") { editingText = false }
                            .frame(minHeight: 44).accessibilityIdentifier("dismissKeyboard")
                    }
                    .padding(.horizontal, 20).background(.regularMaterial)
                } else if audio.isRecording {
                    recordingCard.padding(.horizontal, 20).padding(.vertical, 8)
                        .background(.regularMaterial)
                }
            }
            .alert("有未保存内容", isPresented: $showExit) {
                Button("保留草稿") { if store.keepDraft(note) { dismiss() } }
                    .accessibilityIdentifier("keepDraft")
                Button(isSavedNote ? "放弃修改" : "放弃记录", role: .destructive) {
                    if store.discardDraft(id: note.id) { dismiss() }
                }
                Button("继续编辑", role: .cancel) { editingText = resumeEditingAfterExit }
            } message: { Text("你想怎么处理这次记录？") }
        }
        .interactiveDismissDisabled()
        .sheet(item: $sheet) { value in
            switch value {
            case .tags:
                TagSheet(selected: note.tags, recent: store.archive.recentTags) { note.tags = $0 }
            case .camera:
                CameraPicker(onImage: { image in
                    addImage(image, kind: .photo)
                    sheet = nil
                }, onCancel: { sheet = nil }).ignoresSafeArea()
            }
        }
        .photosPicker(isPresented: $showPhotos, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, value in
            guard let value else { return }
            importing = true
            Task { @MainActor in
                defer { importing = false; selectedPhoto = nil }
                do {
                    guard let data = try await value.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                        throw MosaicError.invalidAttachment
                    }
                    addImage(image, kind: importedKind)
                } catch { store.message = "图片未能导入。\n\(error.localizedDescription)" }
            }
        }
        .alert("提示", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("知道了") { store.message = nil }
        } message: { Text(store.message ?? "") }
        .task {
            guard !openedEntry else { return }
            openedEntry = true
            let initialEntry = store.requestedEntry ?? entry
            store.requestedEntry = nil
            await handleEntry(initialEntry)
        }
        .onChange(of: store.requestedEntry) { _, value in
            guard let value else { return }
            if note.hasContent && !saved {
                store.message = "快捷入口已就绪。请先保存或退出当前记录，再开始下一条。"
            } else {
                store.requestedEntry = nil
                if saved { newNote() }
                Task { await handleEntry(value) }
            }
        }
        .onChange(of: scenePhase) { _, value in
            if value == .background && !saved {
                finishRecording()
                if note.hasContent && note != original { _ = store.keepDraft(note) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in
            if audio.isRecording { finishRecording() }
        }
        .onDisappear { audioStartTask?.cancel(); finishRecording(); audio.stopPlayback() }
    }

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(note.attachments) { attachment in attachmentCard(attachment) }
                Text("想记住什么？一句话也可以。")
                    .font(.headline).foregroundStyle(MosaicTheme.ink).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        if note.text.isEmpty {
                            Text("刚刚想到了什么？").foregroundStyle(MosaicTheme.muted)
                                .padding(.top, 8).padding(.leading, 5).allowsHitTesting(false)
                        }
                        TextEditor(text: $note.text)
                            .scrollContentBackground(.hidden).frame(height: 140)
                            .focused($editingText).accessibilityLabel("想法内容").accessibilityIdentifier("thoughtText")
                    }.font(.callout)
                    HStack {
                        if editingText {
                            Button("完成输入") { editingText = false }
                                .font(.footnote).frame(minHeight: 44)
                                .accessibilityIdentifier("finishTyping")
                        }
                        Spacer()
                        Button {
                            editingText = false
                            requestingAudio = true
                            audioStartTask = Task { @MainActor in
                                defer { requestingAudio = false }
                                do { try await audio.start() }
                                catch is CancellationError { }
                                catch { store.message = error.localizedDescription }
                            }
                        } label: { Text(requestingAudio ? "正在开启…" : "◉  语音").font(.footnote) }
                            .foregroundStyle(MosaicTheme.secondary).frame(minHeight: 44)
                            .disabled(audio.isRecording || requestingAudio)
                            .accessibilityIdentifier("recordAudio")
                    }
                }.padding(10).frame(minHeight: 146)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MosaicTheme.line))
                HStack(spacing: 10) {
                    Button("▣  拍照") { Task { await openCamera() } }.frame(maxWidth: 140)
                    Button("▧  添加图片") { editingText = false; importedKind = .photo; showPhotos = true }
                        .frame(maxWidth: 158).accessibilityIdentifier("addPhoto")
                }.buttonStyle(MosaicButtonStyle()).disabled(importing || audio.isRecording || requestingAudio)
                if importing { ProgressView("正在导入图片…").font(.caption) }
                Divider().overlay(MosaicTheme.line)
                Text("标签（可选）").font(.callout.bold())
                TagFlow {
                    ForEach(note.tags, id: \.self) { tag in
                        Button { editingText = false; sheet = .tags } label: { TagChip(text: tag) }.buttonStyle(.plain)
                    }
                    if note.tags.isEmpty {
                        ForEach(["街头观察", "绘画参考"], id: \.self) { tag in
                            Button { note.tags.append(tag) } label: { TagChip(text: tag) }.buttonStyle(.plain)
                        }
                    }
                    Button { editingText = false; sheet = .tags } label: { TagChip(text: "＋ 添加标签") }
                        .buttonStyle(.plain).accessibilityIdentifier("addTags")
                }
                Text(note.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.subheadline).foregroundStyle(MosaicTheme.muted)
            }
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 30)
            .frame(maxWidth: 560, alignment: .leading).frame(maxWidth: .infinity)
        }.scrollDismissesKeyboard(.interactively).accessibilityIdentifier("captureScroll")
    }

    @ViewBuilder private func attachmentCard(_ attachment: MosaicAttachment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TagChip(text: attachment.label, selected: true)
                Spacer()
                Button("×") {
                    if audio.playingID == attachment.id { audio.stopPlayback() }
                    note.attachments.removeAll { $0.id == attachment.id }
                }.font(.title3).foregroundStyle(.white).frame(width: 44, height: 44)
                    .background(MosaicTheme.secondary, in: RoundedRectangle(cornerRadius: 11))
                    .accessibilityLabel("移除\(attachment.label)")
            }
            switch attachment.kind {
            case .sample: SampleMaterialView()
            case .audio:
                Button {
                    guard let url = store.repository.mediaURL(for: attachment) else { return }
                    do { try audio.play(attachment, at: url) } catch { store.message = error.localizedDescription }
                } label: {
                    HStack {
                        Text(audio.playingID == attachment.id ? "停止播放" : "播放语音")
                        Spacer()
                        Text(recordingTime(attachment.duration ?? 0)).monospacedDigit()
                    }.padding(12)
                }.buttonStyle(.plain).disabled(audio.isRecording)
            case .photo, .screenshot:
                if let url = store.repository.mediaURL(for: attachment) {
                    AttachmentImage(url: url, label: attachment.label)
                } else {
                    Text("素材文件暂时无法读取").font(.caption).padding()
                }
            }
        }.padding(10).background(MosaicTheme.material, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(MosaicTheme.line))
    }

    private var recordingCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("正在录音").font(.headline)
                Text(recordingTime(audio.elapsed)).font(.title2.bold()).monospacedDigit()
            }
            Spacer()
            Button("停止录音", action: finishRecording).buttonStyle(MosaicButtonStyle(primary: true))
                .frame(maxWidth: 150).accessibilityIdentifier("stopRecording")
        }.padding(16).background(MosaicTheme.subtle, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(MosaicTheme.line))
    }

    private var isSavedNote: Bool { store.archive.notes.contains { $0.id == note.id } }

    private func requestExit() {
        resumeEditingAfterExit = editingText
        editingText = false
        finishRecording()
        audio.stopPlayback()
        if note != original || (note.hasContent && !isSavedNote) { showExit = true }
        else { dismiss() }
    }
    private func save() {
        editingText = false
        audio.stopPlayback()
        if store.save(note) { original = note; saved = true }
    }
    private func newNote() {
        note = MosaicNote(); original = note; saved = false
    }
    private func addImage(_ image: UIImage, kind: MosaicAttachment.Kind) {
        do { note.attachments.append(try store.importImage(image, kind: kind)) }
        catch { store.message = error.localizedDescription }
    }
    private func finishRecording() {
        guard let result = audio.stop() else { return }
        do {
            let data = try Data(contentsOf: result.url)
            let attachment = try store.repository.importMedia(data, kind: .audio, extension: "m4a", duration: result.duration)
            note.attachments.append(attachment)
            try? FileManager.default.removeItem(at: result.url)
        } catch { store.message = "录音未能加入记录。\n\(error.localizedDescription)" }
    }
    private func openCamera() async {
        editingText = false
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            store.message = "当前设备没有可用相机。模拟器中可以通过“添加图片”或“体验 Figma 示例”演示。"
            return
        }
        let allowed = await AVCaptureDevice.requestAccess(for: .video)
        if allowed { sheet = .camera }
        else { store.message = "相机权限未开启。可在 iPhone 设置中允许 Thought Mosaic 使用相机。" }
    }
    private func handleEntry(_ entry: CaptureEntry) async {
        switch entry {
        case .camera: await openCamera()
        case .screenshot: importedKind = .screenshot; showPhotos = true
        case .direct, .sample: break
        }
    }
}

/// Decode once per attachment, off the UI thread. Typing must not reload full-size photos.
private struct AttachmentImage: View {
    let url: URL
    let label: String
    @State private var image: UIImage?
    @State private var loading = true

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityLabel(label)
            } else if loading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 130)
            } else {
                Text("素材文件暂时无法读取").font(.caption).padding()
            }
        }
        .task(id: url) {
            image = await Task.detached(priority: .userInitiated) {
                UIImage(contentsOfFile: url.path)?.preparingThumbnail(of: CGSize(width: 1120, height: 440))
            }.value
            loading = false
        }
    }
}
