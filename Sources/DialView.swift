import Cocoa

/// Circular duration picker: drag anywhere on the dial to set minutes. AppKit's own circular
/// slider is a bare knob, so the ring, the readout and the drag maths live here.

let maxMinutes = 120

/// Degrees clockwise from twelve o'clock → minutes. Pulled out so the maths is testable.
func minutesForAngle(_ degrees: Double) -> Int {
    var deg = degrees.truncatingRemainder(dividingBy: 360)
    if deg < 0 { deg += 360 }
    return clampMinutes(Int((deg / 360 * Double(maxMinutes)).rounded()))
}

final class DialView: NSView {
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
    private let timeLabel = NSTextField(labelWithString: "")
    private let ring: CGFloat = 8

    init(diameter: CGFloat, customButton: NSButton) {
        super.init(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: diameter),
            heightAnchor.constraint(equalToConstant: diameter),
        ])

        totalLabel.font = .systemFont(ofSize: 13)
        totalLabel.textColor = .secondaryLabelColor
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 38, weight: .semibold)

        let stack = NSStackView(views: [totalLabel, timeLabel, customButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        setAccessibilityRole(.slider)
        setAccessibilityLabel("Lock duration in minutes")
        updateReadout()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func updateReadout() {
        totalLabel.stringValue = "Total \(minutes) minute\(minutes == 1 ? "" : "s")"
        timeLabel.stringValue = String(format: "%02d:%02d:00", minutes / 60, minutes % 60)
        setAccessibilityValueDescription(totalLabel.stringValue)
    }

    override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - ring / 2 - 2

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = ring
        NSColor.separatorColor.setStroke()
        track.stroke()

        // Progress runs clockwise from twelve o'clock, same as the readout counts down.
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
