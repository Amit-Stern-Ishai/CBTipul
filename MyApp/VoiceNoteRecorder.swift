import SwiftUI
import AVFoundation

/// Records a voice note into a local `.m4a` file and plays it back.
///
/// The recorded file is kept locally for now; sending it to Whisper for
/// transcription will be wired up next.
@Observable
@MainActor
final class VoiceNoteRecorder {
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var tickTask: Task<Void, Never>?

    private(set) var isRecording = false
    private(set) var isPlaying = false
    private(set) var recordingURL: URL?
    /// Seconds recorded so far (live while recording, final afterwards).
    private(set) var duration: TimeInterval = 0
    var errorMessage: String?

    func startRecording() async {
        errorMessage = nil

        guard await AVAudioApplication.requestRecordPermission() else {
            errorMessage = L10n.micPermissionDenied
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("voice-note-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.record()

            self.recorder = recorder
            recordingURL = nil
            duration = 0
            isRecording = true

            tickTask?.cancel()
            tickTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(250))
                    guard let self else { return }
                    if let recorder = self.recorder {
                        self.duration = recorder.currentTime
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopRecording() {
        tickTask?.cancel()
        guard let recorder else { return }
        duration = recorder.currentTime
        recorder.stop()
        recordingURL = recorder.url
        self.recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func togglePlayback() {
        if isPlaying {
            player?.stop()
            player = nil
            isPlaying = false
            tickTask?.cancel()
            return
        }
        guard let recordingURL else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: recordingURL)
            player.play()
            self.player = player
            isPlaying = true

            // Reset the button once playback reaches the end.
            tickTask?.cancel()
            tickTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(250))
                    guard let self else { return }
                    if self.player?.isPlaying != true {
                        self.player = nil
                        self.isPlaying = false
                        return
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes the recorded file and resets to the idle state.
    func discard() {
        player?.stop()
        player = nil
        isPlaying = false
        tickTask?.cancel()
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
        duration = 0
    }
}
