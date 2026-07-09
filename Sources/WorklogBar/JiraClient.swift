import Foundation

struct JiraConfig {
    var baseURL: URL
    var email: String
    var token: String

    var isCloud: Bool { baseURL.host?.hasSuffix(".atlassian.net") == true }

    var authHeader: String {
        if isCloud {
            let raw = Data("\(email):\(token)".utf8).base64EncodedString()
            return "Basic \(raw)"
        } else {
            return "Bearer \(token)"
        }
    }
}

enum JiraError: LocalizedError {
    case http(Int, String)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .http(let code, let body):
            if code == 401 {
                return "Authentication failed (401). Check your email/token — Cloud API tokens expire after one year."
            }
            return "Jira returned HTTP \(code): \(body.prefix(200))"
        case .notConfigured:
            return "Not configured. Open Settings and enter your Jira URL and token."
        }
    }
}

struct JiraClient {
    let config: JiraConfig

    func myself() async throws -> Myself {
        try await decode(request(path: "/rest/api/2/myself"))
    }

    func issuesWithMyWorklogs(from startDate: String, before endDateExclusive: String) async throws -> [Issue] {
        try await search(jql: "worklogAuthor = currentUser() AND worklogDate >= \"\(startDate)\" AND worklogDate < \"\(endDateExclusive)\"")
    }

    func transitions(issueKey: String) async throws -> [Transition] {
        let resp: TransitionsResponse = try await decode(request(path: "/rest/api/2/issue/\(issueKey)/transitions"))
        return resp.transitions
    }

    func applyTransition(issueKey: String, transitionId: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["transition": ["id": transitionId]])
        _ = try await request(path: "/rest/api/2/issue/\(issueKey)/transitions", method: "POST", body: body)
    }

    func worklogs(issueKey: String) async throws -> [Worklog] {
        let page: WorklogPage = try await decode(request(path: "/rest/api/2/issue/\(issueKey)/worklog"))
        return page.worklogs
    }

    func addWorklog(issueKey: String, started: Date, seconds: Int, comment: String? = nil) async throws {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        var payload: [String: Any] = [
            "started": fmt.string(from: started),
            "timeSpentSeconds": seconds,
        ]
        if let comment, !comment.isEmpty { payload["comment"] = comment }
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await request(path: "/rest/api/2/issue/\(issueKey)/worklog", method: "POST", body: body)
    }

    func updateWorklog(issueKey: String, worklogId: String, seconds: Int, comment: String? = nil) async throws {
        var payload: [String: Any] = ["timeSpentSeconds": seconds]
        if let comment, !comment.isEmpty { payload["comment"] = comment }
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await request(path: "/rest/api/2/issue/\(issueKey)/worklog/\(worklogId)", method: "PUT", body: body)
    }

    func deleteWorklog(issueKey: String, worklogId: String) async throws {
        _ = try await request(path: "/rest/api/2/issue/\(issueKey)/worklog/\(worklogId)", method: "DELETE")
    }

    // Cloud's /rest/api/2/search was replaced by /search/jql; DC still uses the classic endpoint.
    func search(jql: String, maxResults: Int = 50) async throws -> [Issue] {
        let path = config.isCloud ? "/rest/api/3/search/jql" : "/rest/api/2/search"
        let query = [
            URLQueryItem(name: "jql", value: jql),
            URLQueryItem(name: "fields", value: "summary,status,issuetype"),
            URLQueryItem(name: "maxResults", value: String(maxResults)),
        ]
        let resp: SearchResponse = try await decode(request(path: path, query: query))
        return resp.issues
    }

    /// Searches every project the user can see — used for pinning tickets
    /// (meetings, shared work) that aren't necessarily assigned to them.
    func searchIssues(matching text: String) async throws -> [Issue] {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let jql: String
        if let range = trimmed.range(of: #"^[A-Za-z][A-Za-z0-9]*-\d+$"#, options: .regularExpression) {
            jql = "key = \"\(trimmed[range].uppercased())\""
        } else {
            let escaped = trimmed.replacingOccurrences(of: "\"", with: "\\\"")
            jql = "text ~ \"\(escaped)*\" ORDER BY updated DESC"
        }
        return try await search(jql: jql, maxResults: 15)
    }

    private func request(
        path: String,
        query: [URLQueryItem] = [],
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Data {
        var comps = URLComponents(url: config.baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.httpBody = body
        req.setValue(config.authHeader, forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw JiraError.http(code, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        try JSONDecoder().decode(T.self, from: data)
    }
}
