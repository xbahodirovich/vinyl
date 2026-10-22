import Foundation

enum MusicSource: String, CaseIterable, Identifiable, Sendable {
    case yandex = "Yandex Music"
    case spotify = "Spotify"
    case apple = "Apple Music"
    var id: String { rawValue }

    static func identify(bundleID: String, parentID: String? = nil) -> Self? {
        for identifier in [bundleID, parentID ?? ""] {
            switch identifier {
            case "ru.yandex.desktop.music": return .yandex
            case "com.spotify.client": return .spotify
            case "com.apple.Music", "com.apple.iTunes": return .apple
            default: continue
            }
        }
        return nil
    }
}

struct Playback: Decodable, Sendable {
    var bundleIdentifier: String?
    var parentApplicationBundleIdentifier: String?
    var title: String?
    var artist: String?
    var album: String?
    var playing: Bool?
    var duration: Double?
    var elapsedTime: Double?
    var timestamp: Double?
    var artworkData: String?
    var playbackRate: Double?

    var source: MusicSource? {
        MusicSource.identify(bundleID: bundleIdentifier ?? "", parentID: parentApplicationBundleIdentifier)
    }

    func progress(at date: Date) -> Double {
        let delta = playing == true ? max(0, date.timeIntervalSince1970 - (timestamp ?? date.timeIntervalSince1970)) * (playbackRate ?? 1) : 0
        return min(max(0, (elapsedTime ?? 0) + delta), max(0, duration ?? 0))
    }
}

struct PlaybackEvent: Decodable, Sendable {
    var type: String
    var diff: Bool
    var payload: Playback
}

extension Playback {
    private enum CodingKeys: String, CodingKey {
        case bundleIdentifier, parentApplicationBundleIdentifier, title, artist, album
        case playing, duration, elapsedTime, timestamp, artworkData, playbackRate
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        var time: Double?
        if let number = try? values.decode(Double.self, forKey: .timestamp) {
            time = number
        } else if let string = try? values.decode(String.self, forKey: .timestamp) {
            // MediaRemote Adapter emits ISO 8601 by default; numeric timestamps
            // remain accepted for browser messages and older payloads.
            let date = (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(string))
                ?? (try? Date.ISO8601FormatStyle().parse(string))
            time = date?.timeIntervalSince1970
        }
        self.init(
            bundleIdentifier: try values.decodeIfPresent(String.self, forKey: .bundleIdentifier),
            parentApplicationBundleIdentifier: try values.decodeIfPresent(String.self, forKey: .parentApplicationBundleIdentifier),
            title: try values.decodeIfPresent(String.self, forKey: .title),
            artist: try values.decodeIfPresent(String.self, forKey: .artist),
            album: try values.decodeIfPresent(String.self, forKey: .album),
            playing: try values.decodeIfPresent(Bool.self, forKey: .playing),
            duration: try values.decodeIfPresent(Double.self, forKey: .duration),
            elapsedTime: try values.decodeIfPresent(Double.self, forKey: .elapsedTime),
            timestamp: time,
            artworkData: try values.decodeIfPresent(String.self, forKey: .artworkData),
            playbackRate: try values.decodeIfPresent(Double.self, forKey: .playbackRate)
        )
    }
}
