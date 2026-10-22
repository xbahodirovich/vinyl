import Foundation
import Testing
@testable import SideA

@Test @MainActor func selectsExactYandexCoverAndRequestsOriginalResolution() throws {
    let payload = Data(#"{"result":{"tracks":{"results":[{"title":"Another Song","artists":[{"name":"The Artist"}],"coverUri":"avatars.yandex.net/get-music-content/wrong/%%"},{"title":"The Song","artists":[{"name":"The Artist"}],"albums":[{"title":"The Album"}],"coverUri":"avatars.yandex.net/get-music-content/right/%%"}]}}}"#.utf8)
    let url = try YandexArtwork.matchingCover(in: payload, title: "THE SONG", artist: "The Artist", album: "The Album")
    #expect(url?.absoluteString == "https://avatars.yandex.net/get-music-content/right/1000x1000")
    #expect(try YandexArtwork.matchingCover(in: payload, title: "Missing", artist: "The Artist", album: nil) == nil)
    #expect(try YandexArtwork.matchingCover(in: payload, title: "The Song", artist: "Someone Else", album: nil) == nil)
}

@Test @MainActor func doesNotChooseBetweenAmbiguousAlbumsOrUntrustedArtworkHosts() throws {
    let payload = Data(#"{"result":{"tracks":{"results":[{"title":"Song","artists":[{"name":"Artist"}],"albums":[{"title":"Album One"}],"coverUri":"avatars.yandex.net/first/%%"},{"title":"Song","artists":[{"name":"Artist"}],"albums":[{"title":"Album Two"}],"coverUri":"avatars.yandex.net/second/%%"}]}}}"#.utf8)
    #expect(try YandexArtwork.matchingCover(in: payload, title: "Song", artist: "Artist", album: nil) == nil)
    #expect(try YandexArtwork.matchingCover(in: payload, title: "Song", artist: "Artist", album: "Album Two")?.path == "/second/1000x1000")
    #expect(YandexArtwork.fullSizeURL("https://example.com/image/%%") == nil)
}

@Test func artworkNetworkRejectsUntrustedDestinations() throws {
    for value in ["http://avatars.yandex.net/a", "https://avatars.yandex.net.evil.example/a", "https://user:password" + "@" + "avatars.yandex.net/a", "https://avatars.yandex.net:8080/a", "file:///etc/passwd", "https://127.0.0.1/a"] {
        #expect(!ArtworkNetwork.allows(try #require(URL(string: value))))
    }
    #expect(ArtworkNetwork.allows(try #require(URL(string: "https://avatars.yandex.net/a/1000x1000"))))
}
