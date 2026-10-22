import AppKit

struct BrowserPlayback: Codable, Sendable {
    var title: String
    var artist: String
    var album: String
    var playing: Bool
    var artwork: String?
    var duration: Double?
    var elapsedTime: Double?
    var session: String
}

enum BrowserBridge {
    static let playbackNotification = Notification.Name("local.sidea.browser.playback")
    static let commandNotification = Notification.Name("local.sidea.browser.command")

    static func readExactly(_ count: Int) -> Data? {
        var result = Data()
        while result.count < count {
            guard let chunk = try? FileHandle.standardInput.read(upToCount: count - result.count), !chunk.isEmpty else { return nil }
            result.append(chunk)
        }
        return result
    }

    @MainActor static func runHost() {
        let center = DistributedNotificationCenter.default()
        let observer = center.addObserver(forName: commandNotification, object: nil, queue: .main) { notification in
            guard let session = notification.userInfo?["session"] as? String,
                  let command = notification.userInfo?["command"] as? Int,
                  let data = try? JSONSerialization.data(withJSONObject: ["session": session, "command": command]) else { return }
            var length = UInt32(data.count).littleEndian
            let header = withUnsafeBytes(of: &length) { Data($0) }
            try? FileHandle.standardOutput.write(contentsOf: header + data)
        }
        Thread {
            while let header = readExactly(4) {
                let count = header.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
                guard count > 0, count < 65_536,
                      let data = readExactly(Int(count)),
                      let payload = try? JSONDecoder().decode(BrowserPlayback.self, from: data),
                      payload.title.count <= 2000, payload.session.count <= 100,
                      let normalized = try? JSONEncoder().encode(payload),
                      let string = String(data: normalized, encoding: .utf8) else { break }
                DistributedNotificationCenter.default().postNotificationName(playbackNotification, object: nil, userInfo: ["json": string], deliverImmediately: true)
            }
            exit(0)
        }.start()
        withExtendedLifetime(observer) { RunLoop.main.run() }
    }
}
