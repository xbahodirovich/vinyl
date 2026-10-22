import AppKit
import Observation
import SwiftUI

@MainActor @Observable
final class WallpaperActivity {
    var visible = false
}

final class WallpaperWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class WallpaperWindows: NSObject {
    struct Display {
        let window: WallpaperWindow
        let activity: WallpaperActivity
    }
    private(set) var displays: [Display] = []
    private let player: NowPlayingStore
    private var awake = true
    private var sessionActive = true
    private(set) var shown = true
    var lighting = RoomLighting(rawValue: UserDefaults.standard.string(forKey: "roomLighting") ?? "day") ?? .day {
        didSet {
            UserDefaults.standard.set(lighting.rawValue, forKey: "roomLighting")
            rebuild()
        }
    }
    var showsBackground = UserDefaults.standard.object(forKey: "showsBackground") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(showsBackground, forKey: "showsBackground")
            rebuild()
        }
    }

    init(player: NowPlayingStore) {
        self.player = player
        super.init()
    }

    func start() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        center.addObserver(self, selector: #selector(occlusionChanged), name: NSWindow.didChangeOcclusionStateNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification] {
            workspace.addObserver(self, selector: #selector(sleeping), name: name, object: nil)
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification] {
            workspace.addObserver(self, selector: #selector(waking), name: name, object: nil)
        }
        workspace.addObserver(self, selector: #selector(sessionResigned), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspace.addObserver(self, selector: #selector(sessionActivated), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        workspace.addObserver(self, selector: #selector(spaceChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        rebuild()
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        closeDisplays()
    }

    func setShown(_ value: Bool) {
        shown = value
        for display in displays {
            if value { display.window.orderBack(nil) }
            else { display.activity.visible = false; display.window.orderOut(nil) }
        }
        refreshActivity()
    }

    private func closeDisplays() {
        for display in displays { display.activity.visible = false; display.window.close() }
        displays.removeAll()
    }

    func rebuild() {
        closeDisplays()
        for screen in NSScreen.screens {
            let window = WallpaperWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
            let activity = WallpaperActivity()
            window.title = "Vinyl Wallpaper"
            window.isReleasedWhenClosed = false
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.isOpaque = showsBackground
            window.backgroundColor = showsBackground ? NSColor(red: 0.09, green: 0.085, blue: 0.075, alpha: 1) : .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isExcludedFromWindowsMenu = true
            window.hidesOnDeactivate = false
            window.contentView = NSHostingView(rootView: WallpaperScene(activity: activity, showsBackground: showsBackground, lighting: lighting).environment(player))
            window.setFrame(screen.frame, display: true)
            displays.append(Display(window: window, activity: activity))
            if shown { window.orderBack(nil) }
        }
        refreshActivity()
    }

    private func refreshActivity() {
        for display in displays {
            display.activity.visible = shown && awake && sessionActive && display.window.occlusionState.contains(.visible)
        }
    }

    @objc private func screensChanged(_ notification: Notification) { rebuild() }
    @objc private func occlusionChanged(_ notification: Notification) { refreshActivity() }
    @objc private func sleeping(_ notification: Notification) { awake = false; refreshActivity() }
    @objc private func waking(_ notification: Notification) { awake = true; refreshActivity() }
    @objc private func sessionResigned(_ notification: Notification) { sessionActive = false; refreshActivity() }
    @objc private func sessionActivated(_ notification: Notification) { sessionActive = true; refreshActivity() }
    @objc private func spaceChanged(_ notification: Notification) {
        if shown { for display in displays { display.window.orderBack(nil) } }
        refreshActivity()
    }
}

struct WallpaperScene: View {
    let activity: WallpaperActivity
    let showsBackground: Bool
    var lighting: RoomLighting = .day

    var body: some View {
        GeometryReader { geometry in
            let scale = max(geometry.size.width / RoomGeometry.canvas.width, geometry.size.height / RoomGeometry.canvas.height)
            ZStack {
                ListeningRoom(isVisible: activity.visible, showsBackground: showsBackground, lighting: lighting)
                    .frame(width: RoomGeometry.canvas.width, height: RoomGeometry.canvas.height)
                    .scaleEffect(scale)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }
}
