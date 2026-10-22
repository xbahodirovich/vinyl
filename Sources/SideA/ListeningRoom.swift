import AppKit
import CoreImage
import SwiftUI

enum RoomLighting: String, CaseIterable, Identifiable, Sendable {
    case day, night
    var id: String { rawValue }
    var title: String { self == .day ? "Listening Room" : "After Hours" }
}

/// Pixel landmarks in the authored photographs, kept separate from display scaling.
struct RoomGeometry: Sendable {
    static let canvas = CGSize(width: 1557, height: 1010)
    var sleeve: [CGPoint]
    var platter: CGRect
    var pivot: CGPoint
    var playingTip: CGPoint
    var parkedTip: CGPoint

    static let room = RoomGeometry(
        sleeve: [CGPoint(x: 97, y: 369), CGPoint(x: 464, y: 349), CGPoint(x: 479, y: 685), CGPoint(x: 120, y: 711)],
        platter: CGRect(x: 556, y: 514, width: 335, height: 139),
        pivot: CGPoint(x: 970, y: 514), playingTip: CGPoint(x: 800, y: 615), parkedTip: CGPoint(x: 1002, y: 660)
    )
    static let cutout = RoomGeometry(
        sleeve: [CGPoint(x: 77, y: 296), CGPoint(x: 592, y: 268), CGPoint(x: 610, y: 746), CGPoint(x: 103, y: 782)],
        platter: CGRect(x: 721, y: 509, width: 480, height: 194),
        pivot: CGPoint(x: 1314, y: 509), playingTip: CGPoint(x: 1072, y: 648), parkedTip: CGPoint(x: 1360, y: 714)
    )
}

@MainActor
enum RoomAssets {
    static let day = load("listening-room-day")
    static let night = load("listening-room-night")
    static let cutout = load("listening-room-cutout").flatMap { cleanedMatte($0) }
    static func load(_ name: String) -> NSImage? {
        Bundle.main.resourceURL.map { $0.appendingPathComponent("Scenes/\(name).png") }.flatMap { NSImage(contentsOf: $0) }
    }
    private static func cleanedMatte(_ image: NSImage) -> NSImage? {
        // Asset preparation is static. Inset the supplied alpha matte slightly so
        // pale/colored generation-edge pixels cannot halo over dark wallpapers.
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
        let source = CIImage(cgImage: cgImage)
        let alpha = CIVector(x: 0, y: 0, z: 0, w: 1)
        let mask = source.applyingFilter("CIColorMatrix", parameters: ["inputRVector": alpha, "inputGVector": alpha, "inputBVector": alpha,
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1)])
            .applyingFilter("CIMorphologyMinimum", parameters: ["inputRadius": 3])
        let result = source.applyingFilter("CIBlendWithMask", parameters: ["inputBackgroundImage": CIImage(color: .clear).cropped(to: source.extent), "inputMaskImage": mask])
        guard let output = CIContext(options: [.cacheIntermediates: false]).createCGImage(result, from: source.extent) else { return image }
        return NSImage(cgImage: output, size: image.size)
    }
}

struct ListeningRoom: View {
    @Environment(NowPlayingStore.self) private var player
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isVisible: Bool
    let showsBackground: Bool
    let lighting: RoomLighting

    private var geometry: RoomGeometry { showsBackground ? .room : .cutout }
    private var image: NSImage? { showsBackground ? (lighting == .day ? RoomAssets.day : RoomAssets.night) : RoomAssets.cutout }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let image {
                Image(nsImage: image).resizable().frame(width: 1557, height: 1010)
            }
            if let artwork = player.artwork, player.accepted,
               let projection = SleeveProjection.project(artwork, corners: geometry.sleeve) {
                Image(nsImage: projection.image).resizable()
                    .frame(width: projection.rect.width, height: projection.rect.height)
                    .blendMode(.multiply)
                    .position(x: projection.rect.midX, y: projection.rect.midY)
                    .accessibilityLabel("Album cover for \(player.playback?.album ?? player.title)")
            } else {
                Text("Vinyl").font(.system(size: showsBackground ? 36 : 48, weight: .medium, design: .serif)).italic()
                    .foregroundStyle(Color(red: 0.25, green: 0.17, blue: 0.10))
                    .rotationEffect(.degrees(-3))
                    .position(x: geometry.sleeve.map(\.x).reduce(0, +) / 4, y: geometry.sleeve.map(\.y).reduce(0, +) / 4)
            }

            CompositorRecord(spinning: player.isPlaying && isVisible && !reduceMotion,
                             textureID: RecordTextureIdentity(artwork: player.accepted ? player.artwork.map(ObjectIdentifier.init) : nil, night: showsBackground && lighting == .night)) {
                RoomRecordFace(artwork: player.accepted ? player.artwork : nil, diameter: geometry.platter.width, night: showsBackground && lighting == .night)
            }
            .frame(width: geometry.platter.width, height: geometry.platter.width)
            .scaleEffect(x: 1, y: geometry.platter.height / geometry.platter.width)
            .position(x: geometry.platter.midX, y: geometry.platter.midY)
            .accessibilityHidden(true)

            // The spindle and the light reflection belong to the room, so they never rotate.
            ReflectionRing().fill(AngularGradient(stops: [
                .init(color: .white.opacity(0.03), location: 0),
                .init(color: Color(red: 0.92, green: 0.83, blue: 0.61).opacity(0.23), location: 0.045),
                .init(color: .white.opacity(0.035), location: 0.12),
                .init(color: .clear, location: 0.22), .init(color: .clear, location: 0.39),
                .init(color: Color(red: 0.92, green: 0.83, blue: 0.61).opacity(0.26), location: 0.48),
                .init(color: .white.opacity(0.09), location: 0.54),
                .init(color: .clear, location: 0.64), .init(color: .clear, location: 0.88),
                .init(color: .white.opacity(0.1), location: 0.97), .init(color: .white.opacity(0.03), location: 1)
            ], center: .center, angle: .degrees(-12)), style: FillStyle(eoFill: true))
                .frame(width: geometry.platter.width, height: geometry.platter.width)
                .scaleEffect(x: 1, y: geometry.platter.height / geometry.platter.width)
                .opacity(showsBackground && lighting == .night ? 0.55 : 1)
                .position(x: geometry.platter.midX, y: geometry.platter.midY)
            Capsule().fill(LinearGradient(colors: [Color(red: 0.42, green: 0.38, blue: 0.27), Color(red: 0.85, green: 0.79, blue: 0.62), Color(white: 0.36)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 4, height: 10)
                .overlay(alignment: .top) { Ellipse().fill(Color(red: 0.83, green: 0.8, blue: 0.69)).frame(height: 2) }
                .shadow(color: .black.opacity(0.4), radius: 1, x: 1, y: 1)
                .position(x: geometry.platter.midX, y: geometry.platter.midY - 4)
            RoomTonearm(geometry: geometry, progress: player.accepted ? 1 : 0, lift: player.accepted && !player.isPlaying ? 4 : 0)
                .animation(reduceMotion || !isVisible ? nil : .easeInOut(duration: 0.25), value: player.isPlaying)
                .animation(reduceMotion || !isVisible ? nil : .easeInOut(duration: 0.25), value: player.accepted)

        }
        .frame(width: 1557, height: 1010)
    }
}

private struct RecordTextureIdentity: Hashable {
    let artwork: ObjectIdentifier?
    let night: Bool
}

private struct ReflectionRing: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(ellipseIn: rect)
        path.addEllipse(in: rect.insetBy(dx: rect.width * 0.344, dy: rect.height * 0.344))
        return path
    }
}

private struct RoomRecordFace: View {
    let artwork: NSImage?
    let diameter: CGFloat
    let night: Bool

    var body: some View {
        ZStack {
            Circle().fill(Color(red: night ? 0.065 : 0.11, green: night ? 0.052 : 0.095, blue: night ? 0.04 : 0.075))
            Canvas { context, size in
                for index in 0..<17 {
                    let inset = size.width * (0.015 + Double(index) * 0.019)
                    context.stroke(Path(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)), with: .color(.white.opacity(index.isMultiple(of: 4) ? 0.13 : 0.055)), lineWidth: 0.6)
                }
            }
            if let artwork {
                Image(nsImage: artwork).resizable().scaledToFill().frame(width: diameter * 0.31, height: diameter * 0.31).clipShape(Circle())
                    .overlay { Circle().fill(Color.black.opacity(night ? 0.16 : 0.03)).frame(width: diameter * 0.31, height: diameter * 0.31) }
            } else {
                Circle().fill(Color(red: 0.54, green: 0.24, blue: 0.1)).frame(width: diameter * 0.31, height: diameter * 0.31)
                Text("Vinyl").font(.system(size: diameter * 0.055, design: .serif)).italic().foregroundStyle(.white.opacity(0.75))
            }
        }.frame(width: diameter, height: diameter)
    }
}

/// Rotate the complete arm in the platter plane, then project into the photograph.
/// This preserves its physical length and bend throughout parking and playback.
struct TonearmPose {
    let geometry: RoomGeometry
    let progress: Double
    var lift: Double = 0
    private var projection: CGFloat { geometry.platter.height / geometry.platter.width }
    private var rotation: CGFloat {
        let playing = atan2((geometry.playingTip.y - geometry.pivot.y) / projection, geometry.playingTip.x - geometry.pivot.x)
        let parked = atan2((geometry.parkedTip.y - geometry.pivot.y) / projection, geometry.parkedTip.x - geometry.pivot.x)
        return (parked - playing) * (1 - progress)
    }
    func project(_ point: CGPoint) -> CGPoint {
        let x = point.x - geometry.pivot.x
        let y = (point.y - geometry.pivot.y) / projection
        return CGPoint(x: geometry.pivot.x + x * cos(rotation) - y * sin(rotation),
                       y: geometry.pivot.y + (x * sin(rotation) + y * cos(rotation)) * projection
                           - lift * hypot(x, y) / hypot(geometry.playingTip.x - geometry.pivot.x, (geometry.playingTip.y - geometry.pivot.y) / projection))
    }
    var tip: CGPoint { project(geometry.playingTip) }
    var neck: CGPoint { project(CGPoint(x: geometry.playingTip.x + 24, y: geometry.playingTip.y - 8)) }
    var control: CGPoint { project(CGPoint(x: geometry.playingTip.x + 14, y: geometry.playingTip.y - 2)) }
    var cartridgeAngle: Double {
        let angle = -17.0 * .pi / 180
        let endpoint = project(CGPoint(x: geometry.playingTip.x + 10 * cos(angle), y: geometry.playingTip.y + 10 * sin(angle)))
        return atan2(endpoint.y - tip.y, endpoint.x - tip.x) * 180 / .pi
    }
}

private struct ArmPath: Shape {
    let geometry: RoomGeometry
    var progress: Double
    var lift: Double
    func path(in rect: CGRect) -> Path {
        let pose = TonearmPose(geometry: geometry, progress: progress, lift: lift)
        var path = Path()
        path.move(to: geometry.pivot)
        path.addLine(to: pose.neck)
        path.addQuadCurve(to: pose.tip, control: pose.control)
        return path
    }
}

private struct RoomTonearm: View, Animatable {
    let geometry: RoomGeometry
    nonisolated var progress: Double
    nonisolated var lift: Double
    nonisolated var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(progress, lift) }
        set { progress = newValue.first; lift = newValue.second }
    }
    var body: some View {
        let pose = TonearmPose(geometry: geometry, progress: progress, lift: lift)
        let rest = TonearmPose(geometry: geometry, progress: 0).neck
        ZStack(alignment: .topLeading) {
            // A fixed cradle supports the parked arm, clear of the control knob.
            RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.12))
                .frame(width: 13, height: 5).position(x: rest.x, y: rest.y + 8)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 1, y: 2)
            Capsule().fill(Color(red: 0.46, green: 0.43, blue: 0.33))
                .frame(width: 4, height: 9).position(x: rest.x, y: rest.y + 3)
            ArmPath(geometry: geometry, progress: progress, lift: lift)
                .stroke(.black.opacity(0.32), style: StrokeStyle(lineWidth: 5, lineCap: .round)).blur(radius: 1.7).offset(x: 2, y: 4)
            ArmPath(geometry: geometry, progress: progress, lift: lift)
                .stroke(Color(red: 0.27, green: 0.27, blue: 0.22), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            ArmPath(geometry: geometry, progress: progress, lift: lift)
                .stroke(LinearGradient(colors: [Color(red: 0.7, green: 0.67, blue: 0.52), Color(red: 0.48, green: 0.48, blue: 0.39), Color(red: 0.62, green: 0.6, blue: 0.46)], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            ArmPath(geometry: geometry, progress: progress, lift: lift)
                .stroke(Color(red: 0.92, green: 0.88, blue: 0.71).opacity(0.36), lineWidth: 0.7).offset(y: -1)
            Ellipse().fill(LinearGradient(colors: [Color(white: 0.24), Color(red: 0.68, green: 0.66, blue: 0.52), Color(white: 0.27)], startPoint: .top, endPoint: .bottom))
                .frame(width: 17, height: 12).rotationEffect(.degrees(-33)).position(geometry.pivot)
            RoundedRectangle(cornerRadius: 1).fill(Color(white: 0.08)).frame(width: 22, height: 10)
                .overlay(alignment: .bottom) { Rectangle().fill(Color(red: 0.55, green: 0.28, blue: 0.07)).frame(height: 4) }
                .rotationEffect(.degrees(pose.cartridgeAngle)).position(pose.tip)
        }.frame(width: 1557, height: 1010).accessibilityHidden(true)
    }
}

@MainActor
enum SleeveProjection {
    nonisolated static func targetRect(_ corners: [CGPoint]) -> CGRect {
        guard let minX = corners.map(\.x).min(), let maxX = corners.map(\.x).max(),
              let minY = corners.map(\.y).min(), let maxY = corners.map(\.y).max() else { return .zero }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).integral
    }
    struct Result {
        let image: NSImage
        let rect: CGRect
    }
    private struct Entry {
        let source: NSImage
        let corners: [CGPoint]
        let result: Result
    }
    private static let context = CIContext(options: [.cacheIntermediates: false])
    private static var cache: [Entry] = []

    /// A small perspective texture is generated only on track/layout changes, never
    /// per animation frame. Keeping the source retains a stable cache identity.
    static func project(_ image: NSImage, corners: [CGPoint]) -> Result? {
        if let entry = cache.first(where: { $0.source === image && $0.corners == corners }) { return entry.result }
        guard corners.count == 4, let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let points = corners.map { CIVector(x: $0.x, y: RoomGeometry.canvas.height - $0.y) }
        let projected = CIImage(cgImage: cgImage).applyingFilter("CIPerspectiveTransform", parameters: [
            "inputTopLeft": points[0], "inputTopRight": points[1],
            "inputBottomRight": points[2], "inputBottomLeft": points[3]
        ])
        let rect = targetRect(corners)
        let extent = CGRect(x: rect.minX, y: RoomGeometry.canvas.height - rect.maxY, width: rect.width, height: rect.height)
        let scale: CGFloat = 2
        let retina = projected.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let output = context.createCGImage(retina, from: extent.applying(CGAffineTransform(scaleX: scale, y: scale))) else { return nil }
        let result = Result(image: NSImage(cgImage: output, size: extent.size), rect: rect)
        cache.append(Entry(source: image, corners: corners, result: result))
        if cache.count > 4 { cache.removeFirst(cache.count - 4) }
        return result
    }
}
