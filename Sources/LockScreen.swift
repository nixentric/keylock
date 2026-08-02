import Cocoa

/// The lock screen itself: one black overlay per display, a countdown, and the hold-to-unlock
/// button. Everything here is mouse-driven, because the keyboard is dead by the time it appears.

/// Deliberately a hold, not a click: a cloth dragged across the trackpad clicks things.
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

/// Borderless windows refuse key status by default, which leaves the overlay unfocused.
final class Overlay: NSWindow {
    override var canBecomeKey: Bool { true }
}

final class LockScreen {
    private var windows: [NSWindow] = []
    private var labels: [NSTextField] = []
    private var timer: Timer?
    private var remaining: Int
    private var note = ""
    private let onUnlock: () -> Void

    init(seconds: Int, onUnlock: @escaping () -> Void) {
        remaining = seconds
        self.onUnlock = onUnlock
    }

    func show() {
        // One window per screen. Centring inside a single union-of-all-screens window puts the
        // text on whichever display AppKit calls "main", which is not the one you are looking at.
        for screen in NSScreen.screens {
            let w = Overlay(contentRect: screen.frame, styleMask: .borderless,
                            backing: .buffered, defer: false)
            w.level = .screenSaver
            w.backgroundColor = NSColor.black.withAlphaComponent(0.92)
            w.isOpaque = false
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            w.setFrame(screen.frame, display: true)
            // Windows created in code free themselves on close, leaving a dangling reference
            // that segfaults the next deactivate notification.
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
        updateLabels()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    /// Re-assert the overlay when something else steals the front.
    func bringToFront() {
        windows.forEach { $0.orderFrontRegardless() }
    }

    func setNote(_ text: String) {
        note = "\n\n" + text
        updateLabels()
    }

    private func tick() {
        remaining -= 1
        if remaining <= 0 { unlock() } else { updateLabels() }
    }

    private func updateLabels() {
        let text = String(format: "Hold the button 1.5s, or auto-unlock in %d:%02d",
                          remaining / 60, remaining % 60)
        labels.forEach { $0.stringValue = text + note }
    }

    private func unlock() {
        timer?.invalidate()
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        onUnlock()
    }
}
