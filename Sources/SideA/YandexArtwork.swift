import AppKit

/// Optional, user-approved lookup. Only title/artist go to Yandex's own catalogue;
/// an exact track/artist match is required before replacing the local thumbnail.
@MainActor
enum YandexArtwork {
    struct Search: Decodable {
        var result: Result?
        struct Result: Decodable { var tracks: Tracks? }
        struct Tracks: Decodable { var results: [Track]? }
    }
    struct Track: Decodable {
        var title: String
        var artists: [Artist]
        var albums: [Album]?
        var coverUri: String?
        struct Artist: Decodable { var name: String }
        struct Album: Decodable { var title: String }
    }
    private static var cache: [(String, Data)] = []

    static func normalized(_ value: String) -> String {
        String(value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    static func matchingCover(in data: Data, title: String, artist: String, album: String?) throws -> URL? {
        let tracks = try JSONDecoder().decode(Search.self, from: data).result?.tracks?.results ?? []
        let artistName = normalized(artist)
        let matches = tracks.filter { track in
            normalized(track.title) == normalized(title) && !track.artists.isEmpty &&
            track.artists.allSatisfy { !normalized($0.name).isEmpty && artistName.contains(normalized($0.name)) }
        }
        let albumMatches = matches.filter { track in
            guard let album, !album.isEmpty else { return false }
            return track.albums?.contains { normalized($0.title) == normalized(album) } == true
        }
        guard let track = albumMatches.first ?? (matches.count == 1 ? matches.first : nil),
              let uri = track.coverUri else { return nil }
        return fullSizeURL(uri)
    }

    static func fullSizeURL(_ uri: String) -> URL? {
        let source = uri.hasPrefix("https://") ? uri : "https://" + uri
        guard let url = URL(string: source.replacingOccurrences(of: "%%", with: "1000x1000")),
              ArtworkNetwork.allows(url), let host = url.host,
              ["avatars.yandex.net", "avatars.mds.yandex.net"].contains(host) else { return nil }
        return url
    }

    static func image(title: String, artist: String, album: String?) async throws -> NSImage? {
        let key = [title, artist, album ?? ""].joined(separator: "\u{1f}")
        if let cached = cache.first(where: { $0.0 == key }) { return NSImage(data: cached.1) }
        var components = URLComponents(string: "https://api.music.yandex.net/search")!
        components.queryItems = [URLQueryItem(name: "text", value: artist + " " + title), URLQueryItem(name: "type", value: "track"), URLQueryItem(name: "page", value: "0")]
        guard let searchURL = components.url else { return nil }
        var request = URLRequest(url: searchURL)
        request.timeoutInterval = 10
        let (result, response) = try await ArtworkNetwork.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let cover = try matchingCover(in: result, title: title, artist: artist, album: album) else { return nil }
        try Task.checkCancellation()
        var artworkRequest = URLRequest(url: cover)
        artworkRequest.timeoutInterval = 10
        let (data, imageResponse) = try await ArtworkNetwork.data(for: artworkRequest)
        guard (imageResponse as? HTTPURLResponse)?.statusCode == 200, data.count < 10_000_000,
              let image = NSImage(data: data) else { return nil }
        try Task.checkCancellation()
        cache.append((key, data))
        if cache.count > 4 { cache.removeFirst(cache.count - 4) }
        return image
    }
}
