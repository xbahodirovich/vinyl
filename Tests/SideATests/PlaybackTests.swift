import Foundation
import Testing
@testable import SideA

@Test func recognizesSupportedPlayersAndParents() {
    #expect(MusicSource.identify(bundleID: "ru.yandex.desktop.music") == .yandex)
    #expect(MusicSource.identify(bundleID: "com.spotify.client") == .spotify)
    #expect(MusicSource.identify(bundleID: "com.apple.Music") == .apple)
    #expect(MusicSource.identify(bundleID: "helper", parentID: "ru.yandex.desktop.music") == .yandex)
    #expect(MusicSource.identify(bundleID: "com.apple.Safari") == nil)
}

@Test func decodesRealAdapterShapeAndClampsProgress() throws {
    let data = Data(#"{"type":"data","diff":false,"payload":{"bundleIdentifier":"ru.yandex.desktop.music","title":"Track","artist":"Artist","playing":true,"duration":200,"elapsedTime":190,"timestamp":1000}}"#.utf8)
    let event = try JSONDecoder().decode(PlaybackEvent.self, from: data)
    #expect(event.payload.source == .yandex)
    #expect(event.payload.progress(at: Date(timeIntervalSince1970: 1005)) == 195)
    #expect(event.payload.progress(at: Date(timeIntervalSince1970: 1100)) == 200)
    var paused = event.payload
    paused.playing = false
    #expect(paused.progress(at: Date(timeIntervalSince1970: 1100)) == 190)
}

@Test func emptyPayloadClearsPlayback() throws {
    let event = try JSONDecoder().decode(PlaybackEvent.self, from: Data(#"{"type":"data","diff":false,"payload":{}}"#.utf8))
    #expect(event.payload.source == nil)
    #expect(event.payload.progress(at: .now) == 0)
}

@Test func adapterISODateDoesNotDiscardLiveYandexTrack() throws {
    let event = try JSONDecoder().decode(PlaybackEvent.self, from: Data(#"{"type":"data","diff":false,"payload":{"bundleIdentifier":"ru.yandex.desktop.music","title":"Live track","artist":"Artist","playing":true,"duration":188.1,"elapsedTime":0.1,"timestamp":"2026-10-19T04:52:33Z"}}"#.utf8))
    #expect(event.payload.source == .yandex)
    #expect(event.payload.title == "Live track")
    #expect(event.payload.playing == true)
    let timestamp = try #require(event.payload.timestamp)
    #expect(abs(event.payload.progress(at: Date(timeIntervalSince1970: timestamp + 2)) - 2.1) < 0.00001)
}

@Test func fractionalAndInvalidTimestampsRetainTrackMetadata() throws {
    let fractional = try JSONDecoder().decode(Playback.self, from: Data(#"{"title":"Track","timestamp":"2026-10-19T04:52:33.123Z"}"#.utf8))
    #expect(fractional.timestamp != nil)
    let invalid = try JSONDecoder().decode(Playback.self, from: Data(#"{"title":"Track","timestamp":"unknown"}"#.utf8))
    #expect(invalid.title == "Track")
    #expect(invalid.timestamp == nil)
}

@Test @MainActor func idleStateDoesNotAdvertiseMusicServices() {
    #expect(NowPlayingStore().artist.isEmpty)
}

@Test @MainActor func browserPlaybackAndSourceSelection() {
    let store = NowPlayingStore()
    store.receive(Data(#"{"type":"data","diff":false,"payload":{"bundleIdentifier":"com.spotify.client","title":"Desktop song","playing":true}}"#.utf8))
    #expect(store.title == "Desktop song")
    store.receiveBrowser(BrowserPlayback(title: "Browser song", artist: "Artist", album: "Album", playing: true, session: "1"))
    #expect(store.title == "Browser song")
    #expect(store.playback?.source == .yandex)
    store.selectedSource = "Spotify"
    store.choosePlayback()
    #expect(store.title == "Desktop song")
    store.selectedSource = "Apple Music"
    store.choosePlayback()
    #expect(!store.accepted)
    #expect(!store.isPlaying)
}

@Test @MainActor func pausedBackgroundTabDoesNotReplacePlayingYandexTab() {
    let store = NowPlayingStore()
    store.receiveBrowser(BrowserPlayback(title: "Playing tab", artist: "Artist", album: "Album", playing: true, session: "1"))
    store.receiveBrowser(BrowserPlayback(title: "Paused tab", artist: "Artist", album: "Album", playing: false, session: "2"))
    #expect(store.title == "Playing tab")
    store.receiveBrowser(BrowserPlayback(title: "Playing tab", artist: "Artist", album: "Album", playing: false, session: "1"))
    #expect(!store.isPlaying)
}
