import AVFoundation
import SwiftUI

@MainActor
final class AudioService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var playingID: UUID?
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var timer: Timer?

    func start() async throws {
        let granted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
        try Task.checkCancellation()
        guard granted else { throw AudioError.permissionDenied }
        stopPlayback()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mosaic-\(UUID()).m4a")
        do {
            let recording = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ])
            guard recording.record() else { throw AudioError.recordingFailed }
            recorder = recording
            elapsed = 0
            isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.elapsed = self.recorder?.currentTime ?? self.elapsed
                }
            }
        } catch {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }
    }

    func stop() -> (url: URL, duration: TimeInterval)? {
        guard let recorder else { return nil }
        let result = (recorder.url, max(elapsed, recorder.currentTime))
        recorder.stop()
        self.recorder = nil
        timer?.invalidate()
        timer = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return result
    }

    func play(_ attachment: MosaicAttachment, at url: URL) throws {
        if playingID == attachment.id { stopPlayback(); return }
        stopPlayback()
        try AVAudioSession.sharedInstance().setCategory(.playback)
        try AVAudioSession.sharedInstance().setActive(true)
        let audio = try AVAudioPlayer(contentsOf: url)
        audio.delegate = self
        player = audio
        guard audio.play() else { throw AudioError.playbackFailed }
        playingID = attachment.id
    }

    func stopPlayback() {
        // A text-only edit has no audio session to deactivate. Avoid a blocking
        // system audio call on every Save, Back, and sheet dismissal.
        guard player != nil else { return }
        player?.stop()
        player = nil
        playingID = nil
        if !isRecording { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.stopPlayback() }
    }

    enum AudioError: LocalizedError {
        case permissionDenied, recordingFailed, playbackFailed
        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "麦克风权限未开启。可在 iPhone 设置中允许 Thought Mosaic 使用麦克风。"
            case .recordingFailed: return "录音未能开始，请稍后重试。"
            case .playbackFailed: return "这段语音暂时无法播放。"
            }
        }
    }
}

func recordingTime(_ duration: TimeInterval) -> String {
    let seconds = max(0, Int(duration))
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
}
