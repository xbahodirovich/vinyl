import AppKit
import SwiftUI
import Testing
@testable import SideA

@Test func platterStopsAndResumesWithoutJumping() {
    var clock = RecordRotation()
    #expect(clock.angle(at: 100) == 0)
    clock.setPlaying(true, at: 100)
    #expect(abs(clock.angle(at: 100.9) - .pi) < 0.00001)
    clock.setPlaying(false, at: 100.9)
    #expect(abs(clock.angle(at: 500) - .pi) < 0.00001)
    clock.setPlaying(true, at: 500)
    #expect(abs(clock.angle(at: 500) - .pi) < 0.00001)
    // Duplicate play notifications must not reset the phase.
    clock.setPlaying(true, at: 500.45)
    #expect(abs(clock.angle(at: 500.9) - 2 * .pi) < 0.00001)
}

@Test @MainActor func compositorRemovesAnimationWhilePaused() {
    let view = RecordSurface(face: SwiftUI.Color.black)
    view.layoutSubtreeIfNeeded()
    view.setSpinning(true)
    #expect(view.platterLayer.animation(forKey: "platter") != nil)
    view.setSpinning(false)
    #expect(view.platterLayer.animationKeys()?.isEmpty != false)
}

@Test @MainActor func rotatingRecordStaysAnchoredDuringRelayout() {
    let view = RecordSurface(face: Color.black)
    view.frame = NSRect(x: 0, y: 0, width: 335, height: 335)
    view.layoutSubtreeIfNeeded()
    for degrees in [0.0, 45, 90, 135, 180, 270, 359] {
        view.platterLayer.transform = CATransform3DMakeRotation(degrees * .pi / 180, 0, 0, 1)
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        #expect(view.platterLayer.position == CGPoint(x: 167.5, y: 167.5))
        #expect(view.platterLayer.bounds == CGRect(x: 0, y: 0, width: 335, height: 335))
        #expect(view.platterLayer.anchorPoint == CGPoint(x: 0.5, y: 0.5))
        #expect(CATransform3DIsIdentity(view.layer?.transform ?? CATransform3DIdentity))
    }
}

@Test func wallpaperLevelIsBelowDesktopIcons() {
    let wallpaper = Int(CGWindowLevelForKey(.desktopWindow)) + 1
    #expect(wallpaper < Int(CGWindowLevelForKey(.desktopIconWindow)))
    #expect(wallpaper < Int(CGWindowLevelForKey(.normalWindow)))
}

@Test @MainActor func trackChangesUpdateTitleAndDecodedArtwork() throws {
    let store = NowPlayingStore()
    func event(title: String, red: UInt8, blue: UInt8, playing: Bool) throws -> Data {
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 4, bitsPerPixel: 32))
        let pixels = try #require(bitmap.bitmapData)
        pixels[0] = red; pixels[1] = 0; pixels[2] = blue; pixels[3] = 255
        let image = try #require(bitmap.representation(using: .png, properties: [:]))
        return try JSONSerialization.data(withJSONObject: ["type": "data", "diff": false, "payload": ["bundleIdentifier": "ru.yandex.desktop.music", "title": title, "artist": "Test artist", "playing": playing, "artworkData": image.base64EncodedString()]])
    }
    let firstEvent = try event(title: "First track", red: 255, blue: 0, playing: true)
    store.receive(firstEvent)
    let firstArtwork = try #require(store.artwork)
    #expect(store.title == "First track")
    #expect(store.isPlaying)
    store.receive(firstEvent)
    #expect(store.artwork === firstArtwork)
    store.receive(try event(title: "Second track", red: 0, blue: 255, playing: false))
    #expect(store.title == "Second track")
    #expect(store.artist == "Test artist")
    #expect(store.artwork != nil)
    #expect(store.artwork !== firstArtwork)
    #expect(!store.isPlaying)
}
