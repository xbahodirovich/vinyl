import AppKit
import SwiftUI

@main
enum SideALauncher {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--native-host") { BrowserBridge.runHost() }
        else { SideAApp.main() }
    }
}

struct SideAApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Vinyl", systemImage: "opticaldisc") {
            MenuContent(player: delegate.player, delegate: delegate)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let player = NowPlayingStore()
    private(set) var wallpapers: WallpaperWindows!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if CommandLine.arguments.contains("--enable-yandex-artwork") {
            UserDefaults.standard.set(true, forKey: "highResolutionYandexArtwork")
            player.highResolutionArtworkEnabled = true
        }
        if CommandLine.arguments.contains("--render-live-preview") {
            player.start()
            Task {
                try? await Task.sleep(for: .seconds(2))
                if player.highResolutionArtworkEnabled {
                    for _ in 0..<12 {
                        if (player.artwork?.representations.map(\.pixelsWide).max() ?? 0) >= 1000 { break }
                        try? await Task.sleep(for: .milliseconds(500))
                    }
                }
                let report: [String: Any] = ["accepted": player.accepted, "playing": player.isPlaying,
                    "source": player.playback?.source?.rawValue ?? "", "title": player.title,
                    "artist": player.artist, "artworkLoaded": player.artwork != nil, "connection": player.connection,
                    "artworkPixelWidth": player.artwork?.representations.map(\.pixelsWide).max() ?? 0]
                if let path = CommandLine.arguments.last,
                   let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
                    try? data.write(to: URL(fileURLWithPath: path + ".json"))
                }
                renderPreview()
            }
            return
        }
        if CommandLine.arguments.contains("--render-preview") {
            DispatchQueue.main.async { self.renderPreview() }
            return
        }
        wallpapers = WallpaperWindows(player: player)
        wallpapers.start()
        if CommandLine.arguments.contains("--verify-wallpaper") {
            Task { await verifyWallpaper() }
            return
        }
        player.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        wallpapers?.stop()
        player.stop()
    }

    private func verifyWallpaper() async {
        // Exercise our own windows without controlling any music player or other app.
        player.highResolutionArtworkEnabled = false
        try? await Task.sleep(for: .seconds(1))
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: NSApp)
        try? await Task.sleep(for: .seconds(1))
        var checks: [String: Bool] = [:]
        checks["oneWindowPerDisplay"] = wallpapers.displays.count == NSScreen.screens.count
        checks["menuBarOnly"] = NSApp.activationPolicy() == .accessory
        checks["fullDisplayFrames"] = wallpapers.displays.allSatisfy { display in
            NSScreen.screens.contains { $0.frame == display.window.frame }
        }
        checks["borderlessClickThrough"] = wallpapers.displays.allSatisfy {
            $0.window.styleMask == .borderless && $0.window.ignoresMouseEvents && !$0.window.canBecomeKey && !$0.window.hasShadow
        }
        checks["wallpaperLevel"] = wallpapers.displays.allSatisfy {
            $0.window.level.rawValue == Int(CGWindowLevelForKey(.desktopWindow)) + 1 && $0.window.level.rawValue < Int(CGWindowLevelForKey(.desktopIconWindow))
        }
        let behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        checks["allSpacesFlags"] = wallpapers.displays.allSatisfy { $0.window.collectionBehavior.isSuperset(of: behavior) }
        let background = wallpapers.showsBackground
        wallpapers.showsBackground = false
        checks["transparentBackground"] = wallpapers.displays.allSatisfy { !$0.window.isOpaque && $0.window.backgroundColor == .clear }
        wallpapers.showsBackground = background
        try? await Task.sleep(for: .seconds(1))
        let visible = wallpapers.displays.map { $0.activity.visible }
        func cpuSeconds() -> Double {
            var usage = rusage()
            getrusage(RUSAGE_SELF, &usage)
            return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
        }
        func measure(seconds: Double) async -> Double {
            let cpu = cpuSeconds()
            let wall = ProcessInfo.processInfo.systemUptime
            try? await Task.sleep(for: .seconds(seconds))
            return 100 * (cpuSeconds() - cpu) / (ProcessInfo.processInfo.systemUptime - wall)
        }
        func rotatingLayers() -> Int {
            func count(_ layer: CALayer) -> Int {
                (layer.animation(forKey: "platter") == nil ? 0 : 1) + (layer.sublayers ?? []).reduce(0) { $0 + count($1) }
            }
            return wallpapers.displays.reduce(0) { $0 + ($1.window.contentView?.layer.map(count) ?? 0) }
        }
        let idleCPU = await measure(seconds: 3)
        player.receive(Data(#"{"type":"data","diff":false,"payload":{"bundleIdentifier":"ru.yandex.desktop.music","title":"Performance test (simulated)","artist":"Vinyl diagnostics","playing":true}}"#.utf8))
        try? await Task.sleep(for: .seconds(1))
        let playingLayers = rotatingLayers()
        let expectedLayers = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : wallpapers.displays.filter { $0.activity.visible }.count
        checks["rotatesVisibleDisplaysWhilePlaying"] = playingLayers == expectedLayers
        let playingCPU = await measure(seconds: 5)
        player.receive(Data(#"{"type":"data","diff":false,"payload":{"bundleIdentifier":"ru.yandex.desktop.music","title":"Performance test (simulated)","playing":false}}"#.utf8))
        try? await Task.sleep(for: .seconds(1))
        checks["noRotationWhilePaused"] = rotatingLayers() == 0
        let pausedCPU = await measure(seconds: 3)
        let report: [String: Any] = ["checks": checks, "displayCount": wallpapers.displays.count,
            "displayVisibleAtStart": visible, "rotatingLayersWhilePlaying": playingLayers, "simulatedPlayback": true,
            "cpuPercentOfOneCore": ["idle": idleCPU, "playing": playingCPU, "paused": pausedCPU],
            "limits": "Measures app CPU with synthetic playback; excludes media helper/GPU and does not verify physical Space swipes or hot-plugging."]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            let path = CommandLine.arguments.last ?? "/tmp/side-a-wallpaper-verification.json"
            try? data.write(to: URL(fileURLWithPath: path))
        }
        NSApp.terminate(nil)
    }

    private func renderPreview() {
        if CommandLine.arguments.contains("--sample-artwork") {
            // Explicitly labelled synthetic content exercises the live artwork projection.
            if let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 256, pixelsHigh: 256, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 1024, bitsPerPixel: 32), let pixels = bitmap.bitmapData {
                for y in 0..<256 {
                    for x in 0..<256 {
                        let offset = y * 1024 + x * 4
                        let circle = hypot(Double(x - 128), Double(y - 118)) < 72
                        pixels[offset] = circle ? 224 : 22
                        pixels[offset + 1] = circle ? 115 : 55
                        pixels[offset + 2] = circle ? 38 : 68
                        pixels[offset + 3] = 255
                    }
                }
                if let data = bitmap.representation(using: .png, properties: [:]), let event = try? JSONSerialization.data(withJSONObject: ["type": "data", "diff": false, "payload": ["bundleIdentifier": "ru.yandex.desktop.music", "title": "Artwork projection preview", "artist": "Simulated track — not live playback", "playing": CommandLine.arguments.contains("--sample-playing"), "artworkData": data.base64EncodedString()]]) { player.receive(event) }
            }
        }
        let activity = WallpaperActivity()
        activity.visible = true
        let content = WallpaperScene(activity: activity, showsBackground: !CommandLine.arguments.contains("--transparent"), lighting: CommandLine.arguments.contains("--night") ? .night : .day)
            .environment(player).frame(width: 1440, height: 900)
        let host = NSHostingView(rootView: content)
        let preview = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900), styleMask: .borderless, backing: .buffered, defer: false)
        preview.contentView = host
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: bitmap)
            if let png = bitmap.representation(using: .png, properties: [:]) {
            let path = CommandLine.arguments.last ?? "/tmp/side-a-preview.png"
            try? png.write(to: URL(fileURLWithPath: path))
            }
        }
        NSApp.terminate(nil)
    }
}

struct MenuContent: View {
    @Bindable var player: NowPlayingStore
    let delegate: AppDelegate
    @State private var wallpaperShown = true
    @AppStorage("showsBackground") private var showsBackground = true
    @AppStorage("roomLighting") private var lighting = "day"
    @AppStorage("highResolutionYandexArtwork") private var highResolutionArtwork = false

    var body: some View {
        Text(player.connection)
        Divider()
        Toggle("Show Wallpaper", isOn: $wallpaperShown)
            .onChange(of: wallpaperShown) { _, value in delegate.wallpapers?.setShown(value) }
        Toggle("Scene Background", isOn: $showsBackground)
            .onChange(of: showsBackground) { _, value in delegate.wallpapers?.showsBackground = value }
        Picker("Room Lighting", selection: $lighting) {
            ForEach(RoomLighting.allCases) { scene in Text(scene.title).tag(scene.rawValue) }
        }
        .onChange(of: lighting) { _, value in delegate.wallpapers?.lighting = RoomLighting(rawValue: value) ?? .day }
        Toggle("High-Resolution Yandex Covers", isOn: $highResolutionArtwork)
            .onChange(of: highResolutionArtwork) { _, value in player.highResolutionArtworkEnabled = value; player.choosePlayback() }
        Divider()
        Button("Previous Track") { player.command(5) }.disabled(!player.accepted)
        Button(player.isPlaying ? "Pause" : "Play") { player.command(2) }.disabled(!player.accepted)
        Button("Next Track") { player.command(4) }.disabled(!player.accepted)
        Picker("Music Source", selection: $player.selectedSource) {
            Text("Automatic").tag("Automatic")
            ForEach(MusicSource.allCases) { source in Text(source.rawValue).tag(source.rawValue) }
        }
        .onChange(of: player.selectedSource) { _, _ in player.choosePlayback() }
        Button("Reconnect") { player.reconnect() }
        Divider()
        Button("Quit Vinyl") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
    }
}
