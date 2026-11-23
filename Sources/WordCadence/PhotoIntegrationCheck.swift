#if DEBUG
import CadenceCore
import Foundation

enum PhotoIntegrationCheck {
    static func run() async throws {
        let callback = try OAuthCallback(state: "test-state")
        let redirect = try await callback.redirectURI()
        let wrong = URL(string: redirect + "?state=wrong&code=mock")!
        let (_, wrongResponse) = try await URLSession.shared.data(from: wrong)
        try check((wrongResponse as? HTTPURLResponse)?.statusCode == 400, "Incorrect OAuth state was accepted.")
        let correct = URL(string: redirect + "?state=test-state&code=mock")!
        let (_, correctResponse) = try await URLSession.shared.data(from: correct)
        try check((correctResponse as? HTTPURLResponse)?.statusCode == 200, "Valid OAuth callback was rejected.")
        let result = try await callback.wait()
        try check(result.queryItems?.contains(URLQueryItem(name: "code", value: "mock")) == true, "Callback code was lost.")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TranscriptionFixture.self]
        let session = URLSession(configuration: configuration)
        let client = PhotoTranscriber(session: session)
        defer { session.invalidateAndCancel() }

        let catalog = try await client.models(token: "dummy")
        try check(catalog.map(\.slug) == ["image-fixture"], "The account's displayable model catalog was not recognized.")
        let root = FileManager.default.temporaryDirectory.appending(path: "word-cadence-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let photoURL = root.appending(path: "page.png")
        let tinyPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jk98AAAAASUVORK5CYII=")!
        try tinyPNG.write(to: photoURL)
        let photos = try SourcePhoto.load([photoURL, photoURL], startingAt: 1)
        try check(photos.allSatisfy { $0.jpeg.starts(with: [0xff, 0xd8]) }, "Image import did not produce JPEG data.")
        let draft = try await client.transcribe(photos, model: "image-fixture", token: "dummy", guidance: "Photo 2 goes first")
        try check(draft.pages.map(\.id) == [2, 1], "Suggested reading order was lost.")
        try check(draft.questions.count == 1, "A model question was lost.")
        let joined = try draft.assembled()
        try check(joined == "Start.\nShared\nFinish.", "Shared text was not joined correctly.")
        var interrupted = ResponseStream()
        try interrupted.consume("data: {\"type\":\"response.output_text.delta\",\"delta\":\"partial\"}")
        try check((try? interrupted.result()) == nil, "An incomplete stream was accepted.")
        print("Photo check passed: loopback state, model catalog, image encoding, streamed questions and reordered transcript.")
    }

    private static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw AppFailure.setup(message) }
    }
}

private final class TranscriptionFixture: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard request.value(forHTTPHeaderField: "Authorization") == "Bearer dummy",
                  let url = request.url, url.host == "api.openai.com" else { throw URLError(.badServerResponse) }
            let data: Data
            let contentType: String
            if url.path == "/v1/models" {
                data = Data("""
                {"models":[{"slug":"hidden","display_name":"Hidden","visibility":"hide"},
                {"slug":"image-fixture","display_name":"Fixture","visibility":"list"}]}
                """.utf8)
                contentType = "application/json"
            } else {
                guard url.path == "/v1/responses", request.httpMethod == "POST",
                      let body = try JSONSerialization.jsonObject(with: bodyData()) as? [String: Any],
                      body["stream"] as? Bool == true, body["store"] as? Bool == false,
                      body["model"] as? String == "image-fixture",
                      let input = body["input"] as? [[String: Any]],
                      let content = input.first?["content"] as? [[String: String]],
                      content.filter({ $0["image_url"]?.hasPrefix("data:image/jpeg;base64,") == true }).count == 2,
                      content.last?["text"]?.contains("Photo 2 goes first") == true else {
                    throw URLError(.cannotParseResponse)
                }
                let draft = PageProposal(pages: [
                    PageDraft(id: 2, text: "Start.\nShared"),
                    PageDraft(id: 1, text: "Shared\nFinish.", overlap: "Shared")
                ], questions: ["Does Photo 2 come first?"])
                let json = String(decoding: try JSONEncoder().encode(draft), as: UTF8.self)
                let delta = try JSONSerialization.data(withJSONObject: ["type": "response.output_text.delta", "delta": json])
                let prefix = "event: response.output_text.delta\ndata: "
                let suffix = "\n\ndata: {\"type\":\"response.completed\"}\n\n"
                data = Data(prefix.utf8) + delta + Data(suffix.utf8)
                contentType = "text/event-stream"
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                           headerFields: ["Content-Type": contentType])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private func bodyData() throws -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { throw URLError(.cannotDecodeRawData) }
        stream.open()
        defer { stream.close() }
        var body = Data()
        var bytes = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = stream.read(&bytes, maxLength: bytes.count)
            if count < 0 { throw stream.streamError ?? URLError(.cannotDecodeRawData) }
            if count == 0 { return body }
            body.append(contentsOf: bytes.prefix(count))
        }
    }
}
#endif
