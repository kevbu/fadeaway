import Foundation

/// Smooths the raw auto-presentation signal. On after `onDelay` of continuous signal,
/// off after `offDelay` of continuous absence. While on, the reason follows the raw signal at once.
public struct SignalDebouncer: Sendable {
    public var onDelay: TimeInterval
    public var offDelay: TimeInterval
    public private(set) var output: AutoReason?
    private var signalSince: Date?
    private var absentSince: Date?

    public init(onDelay: TimeInterval = 2, offDelay: TimeInterval = 5) {
        self.onDelay = onDelay
        self.offDelay = offDelay
    }

    public mutating func update(raw: AutoReason?, now: Date) -> AutoReason? {
        if let raw {
            absentSince = nil
            let since = signalSince ?? now
            signalSince = since
            if output != nil || now.timeIntervalSince(since) >= onDelay { output = raw }
        } else {
            signalSince = nil
            let since = absentSince ?? now
            absentSince = since
            if output != nil, now.timeIntervalSince(since) >= offDelay { output = nil }
        }
        return output
    }

    public mutating func reset() {
        output = nil
        signalSince = nil
        absentSince = nil
    }
}
