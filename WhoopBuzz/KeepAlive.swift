import AVFoundation

/// Keeps the app process alive in the background by holding an active audio session
/// that loops inaudible audio.
///
/// Without this, iOS suspends the app a few seconds after the screen locks. A
/// suspended app receives no CallKit events and cannot write over Bluetooth, so the
/// strap would never buzz on a call while the phone is locked — which is the whole
/// point of the app.
///
/// An incoming call interrupts the audio session. `AVAudioPlayer` (rather than
/// `AVAudioEngine`) is used because it resumes cleanly after an interruption; on the
/// interruption-ended notification the session is reactivated and playback restarts,
/// so the app survives past the first call and stays alive for the next one.
///
/// The session uses `.playback` + `.mixWithOthers` so it never interrupts the user's
/// music, and the samples are digital silence, so nothing is ever heard. This is a
/// deliberate battery-for-reliability trade-off, acceptable for a personal sideloaded
/// app whose job is to never miss a call.
final class KeepAlive: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var enabled = false

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    func start() {
        enabled = true
        activateAndPlay()
    }

    func stop() {
        enabled = false
        player?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func activateAndPlay() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            return
        }

        if player == nil {
            player = try? AVAudioPlayer(data: KeepAlive.silentWav)
            player?.delegate = self
            player?.numberOfLoops = -1
        }
        player?.prepareToPlay()
        player?.play()
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard enabled,
              let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .ended {
            activateAndPlay()   // reactivate after the call so we keep the app alive
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if enabled { player.play() }   // restart if the loop ever ends
    }

    func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {
        if enabled { activateAndPlay() }
    }

    /// A small in-memory silent WAV (0.5s, 8 kHz mono 16-bit). Built in code so no
    /// audio asset has to be bundled.
    private static let silentWav: Data = {
        let sampleRate = 8000, channels = 1, bits = 16
        let frames = sampleRate / 2                      // 0.5 seconds
        let dataSize = frames * channels * (bits / 8)
        func u32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
        func u16(_ v: UInt16) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
        var d = Data()
        d.append(Data("RIFF".utf8))
        d.append(u32(UInt32(36 + dataSize)))
        d.append(Data("WAVE".utf8))
        d.append(Data("fmt ".utf8))
        d.append(u32(16))
        d.append(u16(1))                                 // PCM
        d.append(u16(UInt16(channels)))
        d.append(u32(UInt32(sampleRate)))
        d.append(u32(UInt32(sampleRate * channels * bits / 8)))
        d.append(u16(UInt16(channels * bits / 8)))
        d.append(u16(UInt16(bits)))
        d.append(Data("data".utf8))
        d.append(u32(UInt32(dataSize)))
        d.append(Data(count: dataSize))                  // silence
        return d
    }()
}
