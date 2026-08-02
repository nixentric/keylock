import Cocoa

/// Circular duration picker: drag anywhere on the ring, or click the readout and type.
/// AppKit's own circular slider is a bare knob, so the ring and the drag maths live here.

let maxMinutes = 120

/// Degrees clockwise from twelve o'clock → minutes. Pulled out so the maths is testable.
func minutesForAngle(_ degrees: Double) -> Int {
    var deg = degrees.truncatingRemainder(dividingBy: 360)
    if deg < 0 { deg += 360 }
    return clampMinutes(Int((deg / 360 * Double(maxMinutes)).rounded()))
}

/// Accepts what someone would actually type into the readout: "25", "0:45", "01:30:00".
/// Returns nil for anything unparseable, so the field can fall back to its old value.
func minutesFromTimeText(_ text: String) -> Int? {
    let parts = text.split(separator: ":").map { Int($0.trimmingCharacters(in: .whitespaces)) }
    guard !parts.isEmpty, parts.count <= 3, !parts.contains(where: { $0 == nil }) else { return nil }
    let n = parts.map { $0! }
    let minutes: Int
    switch n.count {
    case 1: minutes = n[0]
    case 2: minutes = n[0] * 60 + n[1]
    case 3: minutes = n[0] * 60 + n[1] + (n[2] >= 30 ? 1 : 0)  // seconds round to the nearest minute
    default: return nil
    }
    return minutes > 0 ? clampMinutes(minutes) : nil
}

final class DialView: NSView, NSTextFieldDelegate {
    var onChange: (Int) -> Void = { _ in }
    var minutes: Int = 5 {
        didSet {
            guard minutes != oldValue else { return }
            updateReadout()
            needsDisplay = true
            onChange(minutes)
        }
    }

    private let totalLabel = NSTextField(labelWithString: "")
    private let timeField = NSTextField(string: "")
    private let ring: CGFloat = 8

    init(diameter: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: diameter),
            heightAnchor.constraint(equalToConstant: diameter),
        ])

        totalLabel.font = .systemFont(ofSize: 13)
        totalLabel.textColor = .secondaryLabelColor

        // The readout is the input: click it and type, no separate edit mode.
        timeField.font = .monospacedDigitSystemFont(ofSize: 38, weight: .semibold)
        timeField.alignment = .center
        timeField.isBordered = false
        timeField.drawsBackground = false
        timeField.focusRingType = .none
        timeField.delegate = self
        timeField.toolTip = "Type a duration, e.g. 25 or 01:30:00"

        let hint = NSTextField(labelWithString: "click to type")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor

        let stack = NSStackView(views: [totalLabel, timeField, hint])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.widthAnchor.constraint(equalToConstant: diameter - 60),
        ])

        setAccessibilityRole(.slider)
        setAccessibilityLabel("Lock duration in minutes")
        updateReadout()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// The window is movable by its background, which otherwise turns every drag on the
    /// dial into a window drag.
    override var mouseDownCanMoveWindow: Bool { false }

    private func updateReadout() {
        totalLabel.stringValue = "Total \(minutes) minute\(minutes == 1 ? "" : "s")"
        if timeField.currentEditor() == nil {  // don't fight the text being typed
            timeField.stringValue = String(format: "%02d:%02d:00", minutes / 60, minutes % 60)
        }
        setAccessibilityValueDescription(totalLabel.stringValue)
    }

    func controlTextDidEndEditing(_ note: Notification) {
        if let typed = minutesFromTimeText(timeField.stringValue) {
            minutes = typed
        }
        updateReadout()  // normalise, or put the old value back when the input made no sense
    }

    override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - ring / 2 - 2

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = ring
        NSColor.separatorColor.setStroke()
        track.stroke()

        // Progress runs clockwise from twelve o'clock, same direction the clock reads.
        let fraction = CGFloat(minutes) / CGFloat(maxMinutes)
        let endAngle = 90 - 360 * fraction
        let progress = NSBezierPath()
        progress.appendArc(withCenter: center, radius: radius, startAngle: 90,
                           endAngle: endAngle, clockwise: true)
        progress.lineWidth = ring
        progress.lineCapStyle = .round
        NSColor.controlAccentColor.setStroke()
        progress.stroke()

        let radians = endAngle * .pi / 180
        let knob = NSPoint(x: center.x + cos(radians) * radius,
                           y: center.y + sin(radians) * radius)
        NSColor.controlAccentColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: knob.x - ring, y: knob.y - ring,
                                    width: ring * 2, height: ring * 2)).fill()
    }

    override func mouseDown(with event: NSEvent) { setFromDrag(event) }
    override func mouseDragged(with event: NSEvent) { setFromDrag(event) }

    private func setFromDrag(_ event: NSEvent) {
        window?.makeFirstResponder(self)  // commit any in-progress typing first
        let p = convert(event.locationInWindow, from: nil)
        // atan2(dx, dy) measures clockwise from twelve o'clock, which is what the dial shows.
        let degrees = atan2(p.x - bounds.midX, p.y - bounds.midY) * 180 / .pi
        minutes = minutesForAngle(Double(degrees))
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case 124, 126: minutes = clampMinutes(minutes + 1)  // right, up
        case 123, 125: minutes = clampMinutes(minutes - 1)  // left, down
        default: super.keyDown(with: event)
        }
    }
}
