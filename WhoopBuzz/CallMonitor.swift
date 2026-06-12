import CallKit
import Foundation

/// Observes system call events via CallKit and reports incoming calls.
///
/// CallKit surfaces every call routed through the system call UI, which includes
/// native cellular calls *and* VoIP apps that adopt CallKit — WhatsApp, FaceTime,
/// Telegram. That is what lets a single observer cover both native and WhatsApp calls.
final class CallMonitor: NSObject, CXCallObserverDelegate {
    private let observer = CXCallObserver()

    /// Fired on the main queue when a new inbound call starts ringing.
    var onIncomingCall: (() -> Void)?

    override init() {
        super.init()
        observer.setDelegate(self, queue: .main)
    }

    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        // A ringing inbound call: incoming, not yet answered, not ended.
        guard !call.isOutgoing, !call.hasConnected, !call.hasEnded else { return }
        onIncomingCall?()
    }
}
