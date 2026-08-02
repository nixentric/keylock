import Cocoa

/// The launcher: pick how long to lock for, and grant Accessibility if it is still missing.
/// Nothing locks until you press Start, so this is also the last screen where the keyboard works.

func clampMinutes(_ n: Int) -> Int { max(1, min(120, n)) }

private let minutesKey = "lockMinutes"

private let launcherWidth: CGFloat = 460

final class Launcher: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var stack: NSStackView?
    private let field = NSTextField()
    private let stepper = NSStepper()
    private let permissionNote = NSTextField(wrappingLabelWithString: "")
    private let permissionButton = NSButton()
    private let startButton = NSButton()
    private var poll: Timer?
    private var lastTrusted: Bool?
    private let onStart: (Int) -> Void

    init(onStart: @escaping (Int) -> Void) {
        self.onStart = onStart
    }

    func show(defaultMinutes: Int) {
        let logo = NSImageView(image: Bundle.main.image(forResource: "logo")
            ?? NSApp.applicationIconImage)
        logo.imageScaling = .scaleProportionallyUpOrDown
        NSLayoutConstraint.activate([
            logo.widthAnchor.constraint(equalToConstant: 140),
            logo.heightAnchor.constraint(equalToConstant: 140),
        ])

        let title = NSTextField(labelWithString: "KeyLock")
        title.font = .systemFont(ofSize: 26, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "Lock the keyboard while you clean it")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor

        let formatter = NumberFormatter()
        formatter.minimum = 1
        formatter.maximum = 120
        formatter.allowsFloats = false
        field.formatter = formatter
        field.alignment = .right
        field.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        field.integerValue = clampMinutes(defaultMinutes)
        field.target = self
        field.action = #selector(fieldChanged)
        field.widthAnchor.constraint(equalToConstant: 56).isActive = true

        stepper.minValue = 1
        stepper.maxValue = 120
        stepper.integerValue = field.integerValue
        stepper.valueWraps = false
        stepper.target = self
        stepper.action = #selector(stepperChanged)

        let formLabel = NSTextField(labelWithString: "Lock for")
        formLabel.font = .systemFont(ofSize: 14)
        let unitLabel = NSTextField(labelWithString: "minutes")
        unitLabel.font = .systemFont(ofSize: 14)
        unitLabel.textColor = .secondaryLabelColor
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [formLabel, spacer, field, stepper, unitLabel])
        row.orientation = .horizontal
        row.spacing = 10

        // A card instead of a bare row: same controls, less form-in-a-dialog stiffness.
        let form = NSBox()
        form.boxType = .custom
        form.borderWidth = 0
        form.cornerRadius = 12
        form.fillColor = .controlBackgroundColor
        form.contentViewMargins = NSSize(width: 18, height: 14)
        form.contentView = row
        form.widthAnchor.constraint(equalToConstant: launcherWidth - 88).isActive = true

        startButton.title = "Start lock"
        startButton.bezelStyle = .rounded
        startButton.controlSize = .large
        startButton.font = .systemFont(ofSize: 15, weight: .medium)
        startButton.keyEquivalent = "\r"  // default button: system accent blue, white title
        startButton.target = self
        startButton.action = #selector(start)
        NSLayoutConstraint.activate([
            startButton.widthAnchor.constraint(equalToConstant: launcherWidth - 88),
            startButton.heightAnchor.constraint(equalToConstant: 42),
        ])

        permissionNote.font = .systemFont(ofSize: 12)
        permissionNote.textColor = .secondaryLabelColor
        permissionNote.alignment = .center
        permissionNote.preferredMaxLayoutWidth = launcherWidth - 64

        permissionButton.title = "Open System Settings"
        permissionButton.bezelStyle = .rounded
        permissionButton.target = self
        permissionButton.action = #selector(openAccessibilitySettings)

        let stack = NSStackView(views: [logo, title, subtitle, form, startButton,
                                        permissionNote, permissionButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 20
        stack.setCustomSpacing(6, after: title)
        stack.setCustomSpacing(32, after: subtitle)
        stack.setCustomSpacing(16, after: form)
        stack.setCustomSpacing(28, after: startButton)
        // Top inset clears the traffic lights, since the content runs under the title bar.
        stack.edgeInsets = NSEdgeInsets(top: 46, left: 44, bottom: 40, right: 44)
        self.stack = stack

        // Seamless: no title bar strip, content goes edge to edge, drag anywhere to move it.
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: launcherWidth, height: 400),
                         styleMask: [.titled, .closable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.title = "KeyLock"
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.contentView = stack
        w.isReleasedWhenClosed = false
        window = w

        refreshPermission()  // also sizes the window; the permission block changes its height
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // TCC does not notify us, so poll. Cheap, and it lets Start light up the moment
        // the switch is flipped instead of making you relaunch.
        poll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshPermission()
        }
    }

    func close() {
        poll?.invalidate()
        window?.close()
        window = nil
    }

    private func refreshPermission() {
        let trusted = AXIsProcessTrusted()
        guard trusted != lastTrusted else { return }  // don't resize the window every tick
        lastTrusted = trusted
        startButton.isEnabled = trusted
        permissionNote.isHidden = trusted
        permissionButton.isHidden = trusted
        permissionNote.stringValue = trusted ? "" : """
            KeyLock needs Accessibility access to block your keyboard. Open System Settings, \
            switch KeyLock on under Privacy & Security › Accessibility, then come back — \
            Start lights up on its own.
            """
        resizeToFit()
        if trusted { poll?.invalidate() }
    }

    /// Size the window from its content, with the width pinned first — reading `fittingSize`
    /// before the width is known collapses the whole layout into a narrow strip.
    private func resizeToFit() {
        guard let window, let stack else { return }
        stack.layoutSubtreeIfNeeded()
        window.setContentSize(NSSize(width: launcherWidth, height: stack.fittingSize.height))
    }

    @objc private func fieldChanged() {
        field.integerValue = clampMinutes(field.integerValue)
        stepper.integerValue = field.integerValue
    }

    @objc private func stepperChanged() {
        field.integerValue = stepper.integerValue
    }

    @objc private func start() {
        let minutes = clampMinutes(field.integerValue)
        UserDefaults.standard.set(minutes, forKey: minutesKey)
        onStart(minutes * 60)
    }

    @objc private func openAccessibilitySettings() {
        // Registers KeyLock in the Accessibility list so there is a switch to flip.
        _ = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

func savedMinutes() -> Int {
    let saved = UserDefaults.standard.integer(forKey: minutesKey)
    return saved == 0 ? 5 : clampMinutes(saved)
}
