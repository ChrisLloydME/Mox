import Foundation

actor Aria2Client {
    private let endpoint: URL
    private let secret: String
    private let session: URLSession
    private var requestID = 0

    init(port: Int = 29_100, secret: String, session: URLSession = .shared) {
        endpoint = URL(string: "http://127.0.0.1:\(port)/jsonrpc")!
        self.secret = secret
        self.session = session
    }

    func call<Result: Decodable>(_ method: String, parameters: [Any] = [], as type: Result.Type = Result.self) async throws -> Result {
        requestID += 1
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": requestID,
            "method": "aria2.\(method)",
            "params": ["token:\(secret)"] + parameters
        ]
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RPCError(code: -1, message: "The download engine returned an invalid response.")
        }
        let decoded = try JSONDecoder().decode(RPCResponse<Result>.self, from: data)
        if let error = decoded.error { throw error }
        guard let result = decoded.result else { throw RPCError(code: -2, message: "The download engine returned no result.") }
        return result
    }

    func waitUntilReady(timeout: TimeInterval = 8) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        var lastError: Error?
        while Date() < deadline {
            do {
                let _: Aria2Version = try await call("getVersion")
                return
            } catch {
                lastError = error
                try await Task.sleep(for: .milliseconds(150))
            }
        }
        throw lastError ?? RPCError(code: -3, message: "The download engine did not start in time.")
    }

    func tasks() async throws -> [Aria2Task] {
        async let active: [Aria2Task] = call("tellActive")
        async let waiting: [Aria2Task] = call("tellWaiting", parameters: [0, 1_000])
        async let stopped: [Aria2Task] = call("tellStopped", parameters: [0, 1_000])
        return try await active + waiting + stopped
    }

    func add(uris: [String], directory: String, split: Int) async throws -> String {
        try await call("addUri", parameters: [uris, ["dir": directory, "split": String(split)]])
    }

    func addTorrent(data: Data, directory: String) async throws -> String {
        try await call("addTorrent", parameters: [data.base64EncodedString(), [], ["dir": directory, "force-save": "true"]])
    }

    func pause(gid: String) async throws { let _: String = try await call("forcePause", parameters: [gid]) }
    func resume(gid: String) async throws { let _: String = try await call("unpause", parameters: [gid]) }
    func remove(gid: String) async throws { let _: String = try await call("forceRemove", parameters: [gid]) }
    func removeResult(gid: String) async throws { let _: String = try await call("removeDownloadResult", parameters: [gid]) }
    func files(gid: String) async throws -> [Aria2File] { try await call("getFiles", parameters: [gid]) }
    func peers(gid: String) async throws -> [Aria2Peer] { try await call("getPeers", parameters: [gid]) }
    func globalStat() async throws -> Aria2GlobalStat { try await call("getGlobalStat") }
    func saveSession() async throws { let _: String = try await call("saveSession") }
    func shutdown() async throws { let _: String = try await call("shutdown") }
    func changeGlobalOptions(_ options: [String: String]) async throws {
        let _: String = try await call("changeGlobalOption", parameters: [options])
    }
}
