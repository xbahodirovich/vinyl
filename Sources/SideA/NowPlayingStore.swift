import AppKit
import Observation
import OSLog

@MainActor @Observable
final class NowPlayingStore {
    var playback: Playback?
    var artwork: NSImage?
    var connection = "Connecting to Now Playing…"
    var selectedSource = "Automatic"
    var highResolutionArtworkEnabled = UserDefaults.standard.bool(forKey: "highResolutionYandexArtwork")
    private var process: Process?
    private var streamTask: Task<Void, Never>?
    private var artworkValue: String?
    private var systemPlayback: Playback?
    private var browserPlayback: BrowserPlayback?
    private var browserUpdated = Date.distantPast
    private var browserObserver: NSObjectProtocol?
    private var browserExpiry: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var browserActive = false
    private var highResolutionTask: Task<Void, Never>?
    private var highResolutionImage: NSImage?
    private var desktopCoverKey: String?
    private var requestedCoverKey: String?
    private let logger = Logger(subsystem: "local.sidea.mac", category: "NowPlaying")

    var accepted: Bool {
        guard let source = playback?.source else { return false }
        return selectedSource == "Automatic" || selectedSource == source.rawValue
    }
    var isPlaying: Bool { accepted && playback?.playing == true }
    var title: String { accepted ? playback?.title ?? "Untitled track" : "Your next side awaits" }
    var artist: String { accepted ? playback?.artist ?? "Unknown artist" : "" }

    private func helper(arguments: [String]) throws -> Process {
        guard let resourceURL = Bundle.main.resourceURL else { throw CocoaError(.fileNoSuchFile) }
        let script = resourceURL.appendingPathComponent("mediaremote-adapter.pl")
        let framework = Bundle.main.bundleURL.appendingPathComponent("Contents/Frameworks/MediaRemoteAdapter.framework")
        guard FileManager.default.fileExists(atPath: script.path), FileManager.default.fileExists(atPath: framework.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        task.arguments = [script.path, framework.path] + arguments
        return task
    }

    func start() {
        if browserObserver == nil {
            browserObserver = DistributedNotificationCenter.default().addObserver(forName: BrowserBridge.playbackNotification, object: nil, queue: .main) { [weak self] notification in
                guard let string = notification.userInfo?["json"] as? String,
                      let payload = try? JSONDecoder().decode(BrowserPlayback.self, from: Data(string.utf8)) else { return }
                MainActor.assumeIsolated { self?.receiveBrowser(payload) }
            }
        }
        guard process == nil else { return }
        do {
            let task = try helper(arguments: ["stream", "--no-diff", "--debounce=120"])
            let output = Pipe()
            task.standardOutput = output
            task.standardError = FileHandle.nullDevice
            try task.run()
            process = task
            connection = "Listening for music"
            streamTask = Task { [weak self] in
                do {
                    for try await line in output.fileHandleForReading.bytes.lines {
                        guard !Task.isCancelled else { break }
                        self?.receive(Data(line.utf8))
                    }
                    guard !Task.isCancelled else { return }
                    self?.connection = "Now Playing disconnected. Choose Reconnect in the menu."
                    self?.playback = nil
                    self?.artwork = nil
                    self?.process = nil
                } catch {
                    guard !Task.isCancelled else { return }
                    self?.connection = "Couldn’t read Now Playing. Choose Reconnect in the menu."
                    self?.logger.error("Media stream failed: \(error.localizedDescription)")
                    self?.playback = nil
                    self?.artwork = nil
                    self?.process = nil
                }
            }
        } catch {
            connection = "Now Playing helper is missing. Rebuild with Scripts/build.sh."
            logger.error("Helper launch failed: \(error.localizedDescription)")
        }
    }

    func receive(_ data: Data) {
        guard let event = try? JSONDecoder().decode(PlaybackEvent.self, from: data), event.type == "data", !event.diff else {
            logger.error("Couldn’t decode a Now Playing update")
            return
        }
        systemPlayback = event.payload
        choosePlayback()
    }

    func receiveBrowser(_ payload: BrowserPlayback) {
        if browserPlayback?.playing == true, payload.playing == false,
           browserPlayback?.session != payload.session, Date.now.timeIntervalSince(browserUpdated) < 6 { return }
        browserPlayback = payload
        browserUpdated = .now
        browserExpiry?.cancel()
        browserExpiry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(7))
            guard !Task.isCancelled else { return }
            self?.choosePlayback()
        }
        choosePlayback()
    }

    func choosePlayback() {
        if !highResolutionArtworkEnabled {
            highResolutionTask?.cancel()
            requestedCoverKey = nil
        }
        let browser = Date.now.timeIntervalSince(browserUpdated) < 6 ? browserPlayback : nil
        let wantsYandex = selectedSource == "Automatic" || selectedSource == MusicSource.yandex.rawValue
        browserActive = wantsYandex && browser != nil && (browser?.playing == true || systemPlayback?.playing != true || systemPlayback?.source == nil)
        if browserActive, let browser {
            highResolutionTask?.cancel()
            requestedCoverKey = nil
            playback = Playback(bundleIdentifier: "ru.yandex.desktop.music", title: browser.title, artist: browser.artist, album: browser.album, playing: browser.playing, duration: browser.duration, elapsedTime: browser.elapsedTime, timestamp: browserUpdated.timeIntervalSince1970)
            connection = "Connected to Yandex Music in your browser"
            loadArtwork(url: browser.artwork)
        } else {
            playback = systemPlayback
            connection = systemPlayback?.source.map { "Connected to \($0.rawValue)" } ?? "Waiting for a supported music player"
            let coverKey = [systemPlayback?.bundleIdentifier ?? "", systemPlayback?.title ?? "", systemPlayback?.artist ?? "", systemPlayback?.album ?? ""].joined(separator: "\u{1f}")
            if desktopCoverKey != coverKey {
                highResolutionTask?.cancel()
                highResolutionImage = nil
                requestedCoverKey = nil
                desktopCoverKey = coverKey
                artworkValue = nil
                artwork = nil
            }
            let value = systemPlayback?.artworkData
            if artworkValue != value {
                artworkTask?.cancel()
                artworkValue = value
                artwork = highResolutionImage ?? value.flatMap { Data(base64Encoded: $0) }.flatMap(NSImage.init(data:))
            }
            if highResolutionArtworkEnabled, systemPlayback?.source == .yandex, accepted,
               let title = systemPlayback?.title, let artist = systemPlayback?.artist, !title.isEmpty, !artist.isEmpty {
                if let highResolutionImage { artwork = highResolutionImage }
                else if requestedCoverKey != coverKey {
                    requestedCoverKey = coverKey
                    let album = systemPlayback?.album
                    highResolutionTask = Task { [weak self] in
                        do {
                            guard let image = try await YandexArtwork.image(title: title, artist: artist, album: album),
                                  !Task.isCancelled, let self, self.desktopCoverKey == coverKey,
                                  !self.browserActive, self.highResolutionArtworkEnabled else { return }
                            let originalWidth = self.artwork?.representations.map(\.pixelsWide).max() ?? 0
                            guard (image.representations.map(\.pixelsWide).max() ?? 0) > originalWidth else { return }
                            self.highResolutionImage = image
                            self.artwork = image
                        } catch {
                            // Keep the actual local cover when no exact high-resolution match is available.
                        }
                    }
                }
            } else if highResolutionImage != nil {
                highResolutionTask?.cancel()
                highResolutionImage = nil
                requestedCoverKey = nil
                artwork = value.flatMap { Data(base64Encoded: $0) }.flatMap(NSImage.init(data:))
            }
        }
    }

    private func loadArtwork(url: String?) {
        guard artworkValue != url else { return }
        artworkValue = url
        artworkTask?.cancel()
        artwork = nil
        guard let url, let resource = URL(string: url), resource.scheme == "https",
              let host = resource.host,
              host == "avatars.yandex.net" || host == "avatars.mds.yandex.net" else { return }
        artworkTask = Task { [weak self] in
            do {
                let (data, response) = try await ArtworkNetwork.data(for: URLRequest(url: resource))
                guard !Task.isCancelled, (response as? HTTPURLResponse)?.statusCode == 200, response.url?.host == host, data.count < 10_000_000 else { return }
                self?.artwork = NSImage(data: data)
            } catch { /* Retain the original sleeve when artwork is unavailable. */ }
        }
    }

    func stop() {
        highResolutionTask?.cancel()
        requestedCoverKey = nil
        browserExpiry?.cancel()
        artworkTask?.cancel()
        if let browserObserver { DistributedNotificationCenter.default().removeObserver(browserObserver) }
        browserObserver = nil
        streamTask?.cancel()
        streamTask = nil
        process?.terminate()
        process = nil
    }

    func reconnect() { stop(); start() }

    func command(_ id: Int) {
        guard accepted else { return }
        if browserActive, let browserPlayback {
            DistributedNotificationCenter.default().postNotificationName(BrowserBridge.commandNotification, object: nil, userInfo: ["session": browserPlayback.session, "command": id], deliverImmediately: true)
            return
        }
        do {
            let task = try helper(arguments: ["send", String(id)])
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            task.terminationHandler = { [weak self] process in
                let failed = process.terminationStatus != 0
                Task { @MainActor in
                    if failed { self?.connection = "The music player couldn’t handle that control." }
                }
            }
            try task.run()
        } catch {
            connection = "Couldn’t send the playback command. Try reconnecting."
        }
    }
}
