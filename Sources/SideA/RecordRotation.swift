import QuartzCore
import SwiftUI

/// A monotonic clock shared with the compositor's time base; stopping preserves phase.
struct RecordRotation {
    private(set) var angle = 0.0
    private(set) var startedAt: Double?
    static let radiansPerSecond = 2 * Double.pi / 1.8 // 33⅓ RPM

    func angle(at time: Double) -> Double {
        angle + (startedAt.map { max(0, time - $0) * Self.radiansPerSecond } ?? 0)
    }

    mutating func setPlaying(_ playing: Bool, at time: Double) {
        if playing, startedAt == nil { startedAt = time }
        else if !playing, let start = startedAt {
            angle = (angle + max(0, time - start) * Self.radiansPerSecond).truncatingRemainder(dividingBy: 2 * .pi)
            startedAt = nil
        }
    }
}

/// SwiftUI draws the record only when its content changes. Core Animation rotates the
/// resulting layer without a TimelineView, display link, timer, or per-frame body updates.
struct CompositorRecord<Face: View>: NSViewRepresentable {
    var spinning: Bool
    let textureID: AnyHashable?
    let face: Face

    init(spinning: Bool, textureID: AnyHashable? = nil, @ViewBuilder face: () -> Face) {
        self.spinning = spinning
        self.textureID = textureID
        self.face = face()
    }

    func makeNSView(context: Context) -> RecordSurface<Face> { RecordSurface(face: face) }
    func updateNSView(_ view: RecordSurface<Face>, context: Context) {
        view.updateFace(face, textureID: textureID)
        view.setSpinning(spinning)
    }
    static func dismantleNSView(_ view: RecordSurface<Face>, coordinator: ()) { view.setSpinning(false) }
}

final class RecordSurface<Face: View>: NSView {
    /// This layer is ours, never AppKit's view-owned backing layer. AppKit is free
    /// to relayout the view without rewriting an animated layer's frame/anchor.
    let platterLayer = CALayer()
    private var face: Face
    private var textureID: AnyHashable?
    private var textureDirty = true
    private var textureSize = CGSize.zero
    private var clock = RecordRotation()
    private var spinning = false

    init(face: Face) {
        self.face = face
        super.init(frame: NSRect(x: 0, y: 0, width: 247, height: 247))
        wantsLayer = true
        platterLayer.contentsGravity = .resize
        platterLayer.minificationFilter = .trilinear
        platterLayer.magnificationFilter = .linear
        layer?.addSublayer(platterLayer)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Never assign `frame` to a rotated layer: its bounding box changes with
        // angle and turns a subsequent layout into an unintended translation.
        platterLayer.bounds = CGRect(origin: .zero, size: bounds.size)
        platterLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        platterLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()
        renderTextureIfNeeded()
    }

    func updateFace(_ face: Face, textureID: AnyHashable?) {
        if self.textureID != textureID || textureID == nil {
            self.face = face
            self.textureID = textureID
            textureDirty = true
        }
        needsLayout = true
    }

    private func renderTextureIfNeeded() {
        guard bounds.width > 0, bounds.height > 0, textureDirty || textureSize != bounds.size else { return }
        let renderer = ImageRenderer(content: face.frame(width: bounds.width, height: bounds.height))
        renderer.scale = max(2, window?.backingScaleFactor ?? 2)
        guard let image = renderer.cgImage else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        platterLayer.contents = image
        platterLayer.contentsScale = renderer.scale
        CATransaction.commit()
        textureSize = bounds.size
        textureDirty = false
    }

    func setSpinning(_ enabled: Bool) {
        guard enabled != spinning else { return }
        let layer = platterLayer
        let now = CACurrentMediaTime()
        clock.setPlaying(enabled, at: now)
        spinning = enabled
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.removeAnimation(forKey: "platter")
        let angle = clock.angle(at: now)
        // The view's layer coordinate system is y-up: negative angles rotate
        // clockwise when viewed from above the record, before ellipse projection.
        layer.transform = CATransform3DMakeRotation(-angle, 0, 0, 1)
        let previewAngle = CommandLine.arguments.first { $0.hasPrefix("--record-phase=") }
            .flatMap { Double($0.dropFirst("--record-phase=".count)) }
        if let previewAngle, CommandLine.arguments.contains("--render-live-preview") {
            layer.transform = CATransform3DMakeRotation(-previewAngle * .pi / 180, 0, 0, 1)
            CATransaction.commit()
            return
        }
        if enabled {
            let animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = -angle
            animation.toValue = -angle - 2 * Double.pi
            animation.duration = 1.8
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            layer.add(animation, forKey: "platter")
        }
        CATransaction.commit()
    }
}
