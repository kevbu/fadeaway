import AppKit
import FadeAwayCore
import ServiceManagement

// FadeAway: hides apps that have been in the background longer than a timeout.

@MainActor
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

    private var fastTimeout: Int {
        get { let v = defaults.integer(forKey: "fastTimeout"); return v > 0 ? v : 15 }
        set { defaults.set(newValue, forKey: "fastTimeout") }
    }

    /// Bundle ID -> AppCategory raw value. Neutral apps have no entry.
    private var categories: [String: String] {
        get { defaults.dictionary(forKey: "categories") as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: "categories") }
    }

    private var paused: Bool {
        get { defaults.bool(forKey: "paused") }
        set { defaults.set(newValue, forKey: "paused"); updateIcon() }
    }

    private var activeMode: Mode { ModeCenter.shared.state.activeMode }

    private func category(for bundleID: String) -> AppCategory {
        AppCategory(stored: categories[bundleID])
    }

    private func timeout(for app: NSRunningApplication) -> Int {
        let id = app.bundleIdentifier
        return TimeoutResolver.effectiveTimeout(
            mode: activeMode, category: id.map(category(for:)) ?? .neutral, override: id.flatMap { overrides[$0] },
            defaultTimeout: defaultTimeout, fastTimeout: fastTimeout, manualPause: paused)
    }

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        ModeCenter.shared.onChange = { [weak self] in self?.updateIcon() }
        updateIcon()

        // Follow the Focus that is already on at launch. No filter means Normal.
        Task { @MainActor in
            if let filter = try? await FadeAwayFocusFilter.current {
                ModeCenter.shared.applyFocus(filter.mode?.mode ?? .normal)
            }
        }

        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func updateIcon() {
        let name = StatusPresentation.iconSymbol(manualPause: paused, mode: activeMode)
        let description = StatusPresentation.accessibilityDescription(manualPause: paused, mode: activeMode)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = StatusPresentation.modeTitle(ModeCenter.shared.state)
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
            if TimeoutResolver.isPaused(manualPause: paused, mode: activeMode) || app.isActive || pid == front || app.isHidden {
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

        let mode = NSMenuItem(title: StatusPresentation.modeTitle(ModeCenter.shared.state), action: nil, keyEquivalent: "")
        mode.submenu = modeMenu()
        menu.addItem(mode)

        let pause = NSMenuItem(title: "Pause hiding", action: #selector(togglePause), keyEquivalent: "p")
        pause.target = self
        pause.state = paused ? .on : .off
        menu.addItem(pause)

        let def = NSMenuItem(title: "Default timeout: \(label(defaultTimeout))", action: nil, keyEquivalent: "")
        def.submenu = timeoutMenu(target: .defaultTimeout, current: defaultTimeout)
        menu.addItem(def)

        let fast = NSMenuItem(title: "Fast timeout: \(label(fastTimeout))", action: nil, keyEquivalent: "")
        fast.submenu = timeoutMenu(target: .fastTimeout, current: fastTimeout)
        menu.addItem(fast)

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
            let suffix = StatusPresentation.appSuffix(
                timeoutLabel: override == nil ? "default" : label(override!), category: category(for: id))
            let item = NSMenuItem(title: "\(app.localizedName ?? id)  (\(suffix))", action: nil, keyEquivalent: "")
            if let icon = app.icon?.copy() as? NSImage {
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
            }
            item.submenu = timeoutMenu(target: .app(id), current: override)
            addCategoryItems(to: item.submenu!, bundleID: id)
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

    /// `current` nil = app uses the default.
    private func timeoutMenu(target: Choice.Target, current: Int?) -> NSMenu {
        let menu = NSMenu()
        func add(_ title: String, _ seconds: Int?, on: Bool) {
            let item = NSMenuItem(title: title, action: #selector(pickTimeout(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = Choice(target: target, seconds: seconds)
            item.state = on ? .on : .off
            menu.addItem(item)
        }
        if case .app = target {
            add("Use default (\(label(defaultTimeout)))", nil, on: current == nil)
            add("Never hide", 0, on: current == 0)
            menu.addItem(.separator())
        }
        for c in choices { add(c.title, c.seconds, on: current == c.seconds) }
        return menu
    }

    private func modeMenu() -> NSMenu {
        let menu = NSMenu()
        let manual = ModeCenter.shared.state.manualMode
        func add(_ title: String, _ mode: Mode?, on: Bool) {
            let item = NSMenuItem(title: title, action: #selector(pickMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ModeChoice(mode: mode)
            item.state = on ? .on : .off
            menu.addItem(item)
        }
        add("Automatic (follow Focus)", nil, on: manual == nil)
        menu.addItem(.separator())
        for m in Mode.allCases { add(m.title, m, on: manual == m) }
        menu.addItem(.separator())
        let setup = NSMenuItem(title: "Set up Focus Filters…", action: #selector(openFocusSettings), keyEquivalent: "")
        setup.target = self
        menu.addItem(setup)
        return menu
    }

    private func addCategoryItems(to menu: NSMenu, bundleID: String) {
        menu.addItem(.separator())
        let header = NSMenuItem(title: "Category", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        let current = category(for: bundleID)
        for c in AppCategory.allCases {
            let item = NSMenuItem(title: c.title, action: #selector(pickCategory(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = CategoryChoice(bundleID: bundleID, category: c)
            item.state = c == current ? .on : .off
            menu.addItem(item)
        }
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
        switch choice.target {
        case .app(let id):
            var o = overrides
            o[id] = choice.seconds  // nil removes the override
            overrides = o
        case .defaultTimeout:
            if let s = choice.seconds { defaultTimeout = s }
        case .fastTimeout:
            if let s = choice.seconds { fastTimeout = s }
        }
    }

    @objc private func pickMode(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? ModeChoice else { return }
        if let mode = choice.mode {
            ModeCenter.shared.pickManual(mode)
        } else {
            ModeCenter.shared.pickAutomatic()
        }
    }

    @objc private func pickCategory(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? CategoryChoice else { return }
        var c = categories
        c[choice.bundleID] = choice.category == .neutral ? nil : choice.category.rawValue
        categories = c
    }

    @objc private func openFocusSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension")!
        if !NSWorkspace.shared.open(url) {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
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
    enum Target { case app(String), defaultTimeout, fastTimeout }
    let target: Target
    let seconds: Int?
    init(target: Target, seconds: Int?) { self.target = target; self.seconds = seconds }
}

/// mode nil = Automatic (follow Focus).
private final class ModeChoice: NSObject {
    let mode: Mode?
    init(mode: Mode?) { self.mode = mode }
}

private final class CategoryChoice: NSObject {
    let bundleID: String
    let category: AppCategory
    init(bundleID: String, category: AppCategory) { self.bundleID = bundleID; self.category = category }
}

// Top-level code runs on the main thread. AppDelegate is @MainActor.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
