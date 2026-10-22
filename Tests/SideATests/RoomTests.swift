import AppKit
import Testing
@testable import SideA

@Test func projectedSleeveTextureUsesItsPhysicalBounds() {
    #expect(SleeveProjection.targetRect(RoomGeometry.room.sleeve) == CGRect(x: 97, y: 349, width: 382, height: 362))
    #expect(SleeveProjection.targetRect(RoomGeometry.cutout.sleeve) == CGRect(x: 77, y: 268, width: 533, height: 514))
}

@Test func projectedRecordAndSleeveStayInsideScene() {
    let bounds = CGRect(origin: .zero, size: RoomGeometry.canvas)
    for geometry in [RoomGeometry.room, .cutout] {
        #expect(bounds.contains(geometry.platter))
        #expect(geometry.platter.width > geometry.platter.height)
        #expect(geometry.sleeve.allSatisfy { bounds.contains($0) })
        #expect(geometry.playingTip.x < geometry.pivot.x)
    }
}

@Test func tonearmRetainsPhysicalLengthWhileParking() {
    for geometry in [RoomGeometry.room, .cutout] {
        let scale = geometry.platter.height / geometry.platter.width
        func length(_ point: CGPoint) -> Double {
            hypot(point.x - geometry.pivot.x, (point.y - geometry.pivot.y) / scale)
        }
        let original = TonearmPose(geometry: geometry, progress: 1)
        for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
            let pose = TonearmPose(geometry: geometry, progress: progress)
            #expect(abs(length(pose.tip) - length(original.tip)) < 0.00001)
            #expect(abs(length(pose.neck) - length(original.neck)) < 0.00001)
        }
        #expect(TonearmPose(geometry: geometry, progress: 0).tip.x > geometry.pivot.x)
    }
}

@Test func pausedArmStaysAboveTheRecordWithFixedPivot() {
    for geometry in [RoomGeometry.room, .cutout] {
        let playing = TonearmPose(geometry: geometry, progress: 1)
        let paused = TonearmPose(geometry: geometry, progress: 1, lift: 4)
        #expect(paused.project(geometry.pivot) == geometry.pivot)
        #expect(abs(paused.tip.x - playing.tip.x) < 0.00001)
        #expect(abs(paused.tip.y - playing.tip.y + 4) < 0.00001)
        #expect(geometry.platter.contains(paused.tip))
    }
}
