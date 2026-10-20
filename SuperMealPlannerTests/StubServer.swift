//  A server that answers from the test, so the client can be driven without a network.

import Foundation

final class StubServer: URLProtocol {
    struct Answer {
        var status: Int = 200
        var body: Data = Data("{}".utf8)
        var headers: [String: String] = [:]
    }

    /// Set by a test: the path (and query) asked for, and the answer to give.
    nonisolated(unsafe) static var answer: (URLRequest) -> Answer = { _ in Answer() }
    nonisolated(unsafe) static var seen: [URLRequest] = []

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubServer.self]
        seen = []
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var request = self.request
        // URLSession strips the body into a stream; read it back so a test can check what was sent.
        if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            stream.close()
            request.httpBody = data
        }
        StubServer.seen.append(request)
        let answer = StubServer.answer(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: answer.status,
                                       httpVersion: "HTTP/1.1", headerFields: answer.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: answer.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
