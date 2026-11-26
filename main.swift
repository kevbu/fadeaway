import AppKit
import ServiceManagement

// FadeAway: hides apps that have been in the background longer than a timeout.

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let defaults = UserDefaults.standard
    private var lastActive: [pid_t: Date] = [:]
    private var timer: Timer?

    private let choices: [(title: String, seconds: Int)] = [
        ("15 seconds", 15), ("30 seconds", 30), ("1 minute", 60),
        ("2 minutes", 120), ("5 minutes", 300), ("15 minutes", 900), ("1 hour", 3600),
    ]

    // MARK: Settings

    private var defaultTimeout: Int {
        get { let v = defaults.integer(forKey: "defaultTimeout"); return v > 0 ? v : 30 }
        set { defaults.set(newValue, forKey: "defaultTimeout") }
    }

    /// Bundle ID -> seconds. 0 means "never hide".
    private var overrides: [String: Int] {
        get { defaults.dictionary(forKey: "overrides") as? [String: Int] ?? [:] }
        set { defaults.set(newValue, forKey: "overrides") }
    }

    private var paused: Bool {
        get { defaults.bool(forKey: "paused") }
        set { defaults.set(newValue, forKey: "paused"); updateIcon() }
    }

    private func timeout(for app: NSRunningApplication) -> Int {
        if let id = app.bundleIdentifier, let t = overrides[id] { return t }
        return defaultTimeout
    }

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()

        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func updateIcon() {
        let name = paused ? "eye" : "eye.slash"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "FadeAway")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    private func regularApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
    }

    // MARK: Core loop

    private func tick() {
        let now = Date()
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        var alive = Set<pid_t>()

        for app in regularApps() {
            let pid = app.processIdentifier
            alive.insert(pid)
            // Active, hidden and paused states all restart the countdown.
            if paused || app.isActive || pid == front || app.isHidden {
                lastActive[pid] = now
                continue
            }
            guard let last = lastActive[pid] else { lastActive[pid] = now; continue }
            let limit = timeout(for: app)
            if limit > 0, now.timeIntervalSince(last) >= Double(limit) {
                app.hide()
                lastActive[pid] = now
            }
        }
        lastActive = lastActive.filter { alive.contains($0.key) }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let pause = NSMenuItem(title: "Pause hiding", action: #selector(togglePause), keyEquivalent: "p")
        pause.target = self
        pause.state = paused ? .on : .off
        menu.addItem(pause)

        let def = NSMenuItem(title: "Default timeout: \(label(defaultTimeout))", action: nil, keyEquivalent: "")
        def.submenu = timeoutMenu(bundleID: nil, current: defaultTimeout)
        menu.addItem(def)

        menu.addItem(.separator())
        let header = NSMenuItem(title: "Running apps", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let apps = regularApps().sorted {
            ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending
        }
        for app in apps {
            guard let id = app.bundleIdentifier else { continue }
            let override = overrides[id]
            let suffix = override == nil ? "default" : label(override!)
            let item = NSMenuItem(title: "\(app.localizedName ?? id)  (\(suffix))", action: nil, keyEquivalent: "")
            if let icon = app.icon?.copy() as? NSImage {
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
            }
            item.submenu = timeoutMenu(bundleID: id, current: override)
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let hideNow = NSMenuItem(title: "Hide all others now", action: #selector(hideOthers), keyEquivalent: "h")
        hideNow.target = self
        menu.addItem(hideNow)

        let login = NSMenuItem(title: "Launch at login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit FadeAway", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    /// bundleID nil = menu for the global default. `current` nil = app uses the default.
    private func timeoutMenu(bundleID: String?, current: Int?) -> NSMenu {
        let menu = NSMenu()
        func add(_ title: String, _ seconds: Int?, on: Bool) {
            let item = NSMenuItem(title: title, action: #selector(pickTimeout(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = Choice(bundleID: bundleID, seconds: seconds)
            item.state = on ? .on : .off
            menu.addItem(item)
        }
        if bundleID != nil {
            add("Use default (\(label(defaultTimeout)))", nil, on: current == nil)
            add("Never hide", 0, on: current == 0)
            menu.addItem(.separator())
        }
        for c in choices { add(c.title, c.seconds, on: current == c.seconds) }
        return menu
    }

    private func label(_ seconds: Int) -> String {
        if seconds == 0 { return "never" }
        if let c = choices.first(where: { $0.seconds == seconds }) { return c.title }
        return "\(seconds) s"
    }

    // MARK: Actions

    @objc private func togglePause() { paused.toggle() }

    @objc private func pickTimeout(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? Choice else { return }
        if let id = choice.bundleID {
            var o = overrides
            o[id] = choice.seconds  // nil removes the override
            overrides = o
        } else if let s = choice.seconds {
            defaultTimeout = s
        }
    }

    @objc private func hideOthers() {
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        for app in regularApps() where app.processIdentifier != front && !app.isHidden {
            app.hide()
        }
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change the login item"
            alert.informativeText = error.localizedDescription
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}

private final class Choice: NSObject {
    let bundleID: String?
    let seconds: Int?
    init(bundleID: String?, seconds: Int?) { self.bundleID = bundleID; self.seconds = seconds }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
