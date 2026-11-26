import AppKit
import CoreGraphics
import FadeAwayCore

/// Reads the on-screen window list once per poll and returns the debounced auto-presentation reason.
/// Reads only owner PID, layer, alpha and bounds (plus each display's notch inset), so it needs no Screen Recording permission.
@MainActor
final class AutoPresentationMonitor {
    private var debouncer = SignalDebouncer()
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    func poll(now: Date) -> AutoReason? {
        let raw = AutoPresentationDetector.detect(windows: windows(), displays: displays())
        return debouncer.update(raw: raw, now: now)
    }

    func reset() { debouncer.reset() }

    private func displays() -> [DisplaySnapshot] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        var insets: [CGDirectDisplayID: CGFloat] = [:]
        for screen in NSScreen.screens {
            if let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value {
                insets[id] = screen.safeAreaInsets.top
            }
        }
        return ids.prefix(Int(count)).map { DisplaySnapshot(bounds: CGDisplayBounds($0), topInset: insets[$0] ?? 0) }
    }

    /// A missing window list counts as "no windows": detection failure means no signal.
    private func windows() -> [WindowSnapshot] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        var owners: [pid_t: (bundleID: String?, regular: Bool)] = [:]
        return list.compactMap { info in
            guard let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value, pid != ownPID,
                let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { return nil }
            let owner =
                owners[pid]
                ?? {
                    let app = NSRunningApplication(processIdentifier: pid)
                    let value = (bundleID: app?.bundleIdentifier, regular: app?.activationPolicy == .regular)
                    owners[pid] = value
                    return value
                }()
            return WindowSnapshot(
                ownerBundleID: owner.bundleID, ownerIsRegularApp: owner.regular,
                layer: (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0,
                alpha: (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1,
                bounds: bounds)
        }
    }
}
