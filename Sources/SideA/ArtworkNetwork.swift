import Foundation

/// Artwork never needs account cookies, persistent URL caches, or redirects.
private final class ArtworkRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

enum ArtworkNetwork {
    static func allows(_ url: URL) -> Bool {
        url.scheme == "https" && url.user == nil && url.password == nil &&
        (url.port == nil || url.port == 443) &&
        ["api.music.yandex.net", "avatars.yandex.net", "avatars.mds.yandex.net"].contains(url.host ?? "")
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 20
        return URLSession(configuration: configuration, delegate: ArtworkRedirectPolicy(), delegateQueue: nil)
    }()

    static func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url, allows(url) else { throw URLError(.badURL) }
        return try await session.data(for: request)
    }
}
