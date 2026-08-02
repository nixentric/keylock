import Cocoa

/// Shared circular gauge. The launcher dial and the lock screen countdown draw the same ring,
/// one filling as you pick a duration, the other emptying as it runs out.

func drawRing(in bounds: NSRect, fraction: CGFloat, lineWidth: CGFloat,
              track: NSColor, progress: NSColor, showKnob: Bool) {
    let center = NSPoint(x: bounds.midX, y: bounds.midY)
    let radius = min(bounds.width, bounds.height) / 2 - lineWidth / 2 - 2

    let ring = NSBezierPath()
    ring.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
    ring.lineWidth = lineWidth
    track.setStroke()
    ring.stroke()

    guard fraction > 0 else { return }

    // Clockwise from twelve o'clock, the direction a clock reads.
    let endAngle = 90 - 360 * min(fraction, 1)
    let arc = NSBezierPath()
    arc.appendArc(withCenter: center, radius: radius, startAngle: 90,
                  endAngle: endAngle, clockwise: true)
    arc.lineWidth = lineWidth
    arc.lineCapStyle = .round
    progress.setStroke()
    arc.stroke()

    guard showKnob else { return }
    let radians = endAngle * .pi / 180
    let knob = NSPoint(x: center.x + cos(radians) * radius, y: center.y + sin(radians) * radius)
    progress.setFill()
    NSBezierPath(ovalIn: NSRect(x: knob.x - lineWidth, y: knob.y - lineWidth,
                                width: lineWidth * 2, height: lineWidth * 2)).fill()
}

/// `90` → "01:30", `3675` → "1:01:15". Minutes and seconds always padded.
func clockText(_ seconds: Int) -> String {
    let s = max(0, seconds)
    return s >= 3600
        ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        : String(format: "%02d:%02d", s / 60, s % 60)
}

/// Read-only ring for the lock screen: no dragging, no typing, just time draining away.
final class CountdownRing: NSView {
    private let total: Int
    private var remaining: Int
    private let timeLabel = NSTextField(labelWithString: "")

    init(diameter: CGFloat, seconds: Int) {
        total = max(seconds, 1)
        remaining = seconds
        super.init(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: diameter),
            heightAnchor.constraint(equalToConstant: diameter),
        ])

        let caption = NSTextField(labelWithString: "⌨️  Keyboard locked")
        caption.font = .systemFont(ofSize: 15, weight: .medium)
        caption.textColor = .white.withAlphaComponent(0.6)

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 52, weight: .semibold)
        timeLabel.textColor = .white

        let stack = NSStackView(views: [caption, timeLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        update(remaining: seconds)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func update(remaining: Int) {
        self.remaining = remaining
        timeLabel.stringValue = clockText(remaining)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        drawRing(in: bounds, fraction: CGFloat(remaining) / CGFloat(total), lineWidth: 10,
                 track: .white.withAlphaComponent(0.15), progress: .controlAccentColor,
                 showKnob: false)
    }
}
