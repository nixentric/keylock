import Cocoa

// Lock the keyboard while you clean it. Mouse stays alive so you can unlock.
// Escape hatches, in order: hold Unlock 1.5s, auto-unlock timer, quit the app.

func shouldSwallow(_ type: CGEventType) -> Bool {
    switch type {
    case .keyDown, .keyUp, .flagsChanged: return true
    default: return false
    }
}

func versionParts(_ s: String) -> [Int] {
    s.drop(while: { !$0.isNumber }).split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
}

func isNewer(_ remote: String, than local: String) -> Bool {
    let r = versionParts(remote), l = versionParts(local)
    for i in 0 ..< max(r.count, l.count) {
        let a = i < r.count ? r[i] : 0, b = i < l.count ? l[i] : 0
        if a != b { return a > b }
    }
    return false
}

func parseSeconds(_ args: [String]) -> Int {
    guard let i = args.firstIndex(of: "--seconds"), i + 1 < args.count,
          let n = Int(args[i + 1]), n > 0 else { return 300 }
    return n
}

// MARK: - self-check

if CommandLine.arguments.contains("--selftest") {
    assert(shouldSwallow(.keyDown) && shouldSwallow(.keyUp) && shouldSwallow(.flagsChanged))
    assert(!shouldSwallow(.mouseMoved) && !shouldSwallow(.leftMouseDown) && !shouldSwallow(.scrollWheel))
    assert(isNewer("v1.2.0", than: "1.1.9") && isNewer("2.0", than: "1.9.9"))
    assert(!isNewer("v1.0.0", than: "1.0") && !isNewer("1.0", than: "1.0.1"))
    assert(!isNewer("", than: "1.0") && isNewer("1.2.0-beta", than: "1.1"))
    assert(parseSeconds([]) == 300)
    assert(parseSeconds(["--seconds", "90"]) == 90)
    assert(parseSeconds(["--seconds", "0"]) == 300)
    assert(parseSeconds(["--seconds"]) == 300)
    print("ok")
    exit(0)
}

// MARK: - hold-to-unlock button

final class HoldButton: NSButton {
    var timer: Timer?
    var onHold: () -> Void = {}

    override func mouseDown(with event: NSEvent) {
        highlight(true)
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            self?.onHold()
        }
    }

    override func mouseUp(with event: NSEvent) {
        highlight(false)
        timer?.invalidate()
    }
}

// MARK: - app

/// Borderless windows refuse key status by default, which leaves the overlay unfocused.
final class Overlay: NSWindow {
    override var canBecomeKey: Bool { true }
}

final class App: NSObject, NSApplicationDelegate {
    var tap: CFMachPort?
    var windows: [NSWindow] = []
    var setupWindow: NSWindow?
    var locked = false
    var labels: [NSTextField] = []
    var remaining = parseSeconds(CommandLine.arguments)
    var note = ""

    /// Ask GitHub for the latest release tag. No Sparkle, no appcast: one endpoint, one line of UI.
    func checkForUpdate() {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let repo = info["KLUpdateRepo"] as? String, !repo.isEmpty,
              let local = info["CFBundleShortVersionString"] as? String,
              let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")
        else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String, isNewer(tag, than: local) else { return }
            DispatchQueue.main.async {
                self?.note = "\n\nUpdate \(tag) available — github.com/\(repo)/releases"
                self?.updateLabel()
            }
        }.resume()
    }

    func applicationDidFinishLaunching(_ note: Notification) {
        if AXIsProcessTrusted() { startLock() } else { showSetup() }
    }

    /// Gate before the lock: Accessibility is required, so walk the user through granting it
    /// and start the moment it lands, instead of dead-ending in an alert.
    func showSetup() {
        // Registers KeyLock in the Accessibility list so there is a checkbox to tick.
        _ = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)

        let title = NSTextField(labelWithString: "Turn on Accessibility first")
        title.font = .systemFont(ofSize: 22, weight: .semibold)

        let body = NSTextField(wrappingLabelWithString: """
            KeyLock needs Accessibility access to block your keyboard.

            1. Click the button below — System Settings opens at Privacy & Security › Accessibility.
            2. Switch KeyLock on (unlock the padlock first if it is closed).
            3. Come back here. The lock screen starts as soon as the permission lands.
            """)
        body.font = .systemFont(ofSize: 13)

        let status = NSTextField(labelWithString: "Waiting for permission…")
        status.font = .systemFont(ofSize: 13, weight: .medium)
        status.textColor = .secondaryLabelColor

        let open = NSButton(title: "Open System Settings", target: self,
                            action: #selector(openAccessibilitySettings))
        open.bezelStyle = .rounded
        open.controlSize = .large
        open.keyEquivalent = "\r"

        let stack = NSStackView(views: [title, body, open, status])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 28, left: 28, bottom: 28, right: 28)

        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 320),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "KeyLock"
        w.contentView = stack
        w.center()
        // NSWindow created in code frees itself on close, which leaves ARC holding a dead
        // pointer. Closing this window then crashed the next deactivate notification.
        w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        setupWindow = w

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard AXIsProcessTrusted(), let self else { return }
            t.invalidate()
            status.stringValue = "Permission granted — locking…"
            self.setupWindow?.close()
            self.setupWindow = nil
            self.startLock()
        }
    }

    @objc func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func startLock() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, ctx in
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    let app = Unmanaged<App>.fromOpaque(ctx!).takeUnretainedValue()
                    if let t = app.tap { CGEvent.tapEnable(tap: t, enable: true) }
                    return Unmanaged.passUnretained(event)
                }
                return shouldSwallow(type) ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque())

        guard let tap else {
            // Granting Accessibility to an already-running process does not always reach an
            // existing process; a fresh launch does. Retry once, then give up honestly.
            guard !CommandLine.arguments.contains("--relaunched") else {
                let a = NSAlert()
                a.messageText = "Could not lock the keyboard"
                a.informativeText = "The event tap was refused. Check Accessibility permission for KeyLock."
                a.runModal()
                NSApp.terminate(nil)
                return
            }
            let config = NSWorkspace.OpenConfiguration()
            config.createsNewApplicationInstance = true
            config.arguments = CommandLine.arguments.dropFirst() + ["--relaunched"]
            NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
                DispatchQueue.main.async { NSApp.terminate(nil) }
            }
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(),
                           CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        showOverlay()
        checkForUpdate()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
    }

    func showOverlay() {
        // One window per screen: centring inside a single union-of-all-screens window puts the
        // text on whichever display AppKit calls "main", which is not the one you are looking at.
        for screen in NSScreen.screens {
            let w = Overlay(contentRect: screen.frame, styleMask: .borderless,
                            backing: .buffered, defer: false)
            w.level = .screenSaver
            w.backgroundColor = NSColor.black.withAlphaComponent(0.92)
            w.isOpaque = false
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            w.setFrame(screen.frame, display: true)
            w.isReleasedWhenClosed = false

            let title = NSTextField(labelWithString: "⌨️  Keyboard locked")
            title.font = .systemFont(ofSize: 44, weight: .semibold)
            title.textColor = .white

            let label = NSTextField(labelWithString: "")
            label.font = .monospacedDigitSystemFont(ofSize: 17, weight: .regular)
            label.textColor = .white.withAlphaComponent(0.7)
            label.alignment = .center
            label.maximumNumberOfLines = 0
            labels.append(label)

            let button = HoldButton(title: "Hold to unlock", target: nil, action: nil)
            button.bezelStyle = .rounded
            button.controlSize = .large
            button.font = .systemFont(ofSize: 17)
            button.onHold = { [weak self] in self?.unlock() }

            let stack = NSStackView(views: [title, label, button])
            stack.orientation = .vertical
            stack.spacing = 24
            stack.alignment = .centerX
            stack.translatesAutoresizingMaskIntoConstraints = false
            let content = w.contentView!
            content.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            ])
            w.orderFrontRegardless()
            windows.append(w)
        }
        windows.first?.makeKeyAndOrderFront(nil)
        locked = true
        NSApp.activate(ignoringOtherApps: true)
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching]
        updateLabel()
    }

    // Both handlers only apply while locked. Running them on the setup screen fought with
    // System Settings for focus and flickered the menu bar in and out.
    func applicationDidBecomeActive(_ note: Notification) {
        guard locked else { return }
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching]
    }

    func applicationDidResignActive(_ note: Notification) {
        guard locked else { return }
        NSApp.activate(ignoringOtherApps: true)
        windows.forEach { $0.orderFrontRegardless() }
    }

    func tick() {
        remaining -= 1
        if remaining <= 0 { unlock() } else { updateLabel() }
    }

    func updateLabel() {
        let text = String(format: "Hold the button 1.5s, or auto-unlock in %d:%02d",
                          remaining / 60, remaining % 60)
        labels.forEach { $0.stringValue = text + note }
    }

    func unlock() {
        locked = false
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        NSApp.presentationOptions = []
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
