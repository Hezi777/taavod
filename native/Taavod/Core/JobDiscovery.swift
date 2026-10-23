import CryptoKit
import Darwin
import Foundation
import Observation

nonisolated struct JobLead: Identifiable, Sendable {
    var title: String
    var company: String
    var url: String
    var description: String
    var source: String
    var location = ""
    var postedAt = ""
    var id: String { url }
}

nonisolated enum PublicJobHTTP {
    enum Failure: LocalizedError {
        case invalidURL, privateAddress, network, tooManyRedirects
        var errorDescription: String? {
            switch self {
            case .invalidURL: "Use a public HTTPS job link without a username, password, or custom port."
            case .privateAddress: "Private and local network addresses cannot be imported."
            case .network: "The page could not be downloaded. Paste the job description into a manual entry instead."
            case .tooManyRedirects: "This page redirects too many times. Use its final job link or paste the description."
            }
        }
    }
    static func isPublicAddress(_ address: String) -> Bool {
        if address.contains(":") {
            let value = address.lowercased()
            return (value.hasPrefix("2") || value.hasPrefix("3")) && !value.hasPrefix("2001:db8") && !value.hasPrefix("2002:") && !value.hasPrefix("2001:0:")
        }
        let bytes = address.split(separator: ".").compactMap { Int($0) }
        guard bytes.count == 4, bytes.allSatisfy({ (0...255).contains($0) }) else { return false }
        let a = bytes[0], b = bytes[1], c = bytes[2]
        if [0, 10, 127].contains(a) || a >= 224 || (a == 100 && (64...127).contains(b)) { return false }
        if a == 169 && b == 254 || a == 172 && (16...31).contains(b) || a == 192 && b == 168 { return false }
        if a == 192 && b == 0 && [0, 2].contains(c) || a == 192 && b == 88 && c == 99 { return false }
        if a == 198 && (b == 18 || b == 19 || b == 51 && c == 100) || a == 203 && b == 0 && c == 113 { return false }
        return true
    }
    @concurrent static func get(_ url: URL, redirects: Int = 0) async throws -> Data {
        guard redirects <= 4 else { throw Failure.tooManyRedirects }
        guard url.scheme == "https", let host = url.host?.lowercased(), url.user == nil, url.password == nil,
              url.port == nil || url.port == 443, host.contains("."), !host.hasSuffix(".local"), !host.hasSuffix(".internal"), host != "localhost" else { throw Failure.invalidURL }
        var hints = addrinfo(); hints.ai_socktype = SOCK_STREAM
        var addresses: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, "443", &hints, &addresses) == 0, let first = addresses else { throw Failure.network }
        defer { freeaddrinfo(first) }
        var ips: [String] = []; var cursor: UnsafeMutablePointer<addrinfo>? = first
        while let current = cursor {
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(current.pointee.ai_addr, current.pointee.ai_addrlen, &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 { ips.append(String(cString: buffer)) }
            cursor = current.pointee.ai_next
        }
        guard !ips.isEmpty, ips.allSatisfy(isPublicAddress) else { throw Failure.privateAddress }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("taavod-public-page-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let headerURL = directory.appendingPathComponent("headers"), bodyURL = directory.appendingPathComponent("body")
        let ip = ips[0].contains(":") ? "[\(ips[0])]" : ips[0]
        // macOS curl pins the checked IP while retaining certificate verification and SNI.
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = ["--silent", "--fail-with-body", "--noproxy", "*", "--proto", "=https", "--max-time", "15", "--max-filesize", "2097152", "--resolve", "\(host):443:\(ip)", "--header", "Accept-Encoding: identity", "--user-agent", "Taavod/1.0 (personal job capture)", "--dump-header", headerURL.path, "--output", bodyURL.path, url.absoluteString]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        try Task.checkCancellation()
        guard process.terminationStatus == 0 else { throw Failure.network }
        let headers = try String(contentsOf: headerURL, encoding: .utf8)
        let lines = headers.components(separatedBy: "\r\n")
        let status = lines.first?.split(separator: " ").dropFirst().first.flatMap { Int($0) } ?? 0
        if (300..<400).contains(status) {
            guard let line = lines.first(where: { $0.lowercased().hasPrefix("location:") }),
                  let next = URL(string: String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces), relativeTo: url)?.absoluteURL else { throw Failure.network }
            return try await get(next, redirects: redirects + 1)
        }
        guard (200..<300).contains(status) else { throw Failure.network }
        let data = try Data(contentsOf: bodyURL)
        guard data.count <= 2_097_152 else { throw Failure.network }
        return data
    }
}

@Observable final class JobDiscovery {
    var leads: [JobLead] = []
    var error: String?
    var isLoading = false
    var status = ""

    static func canonicalURL(_ input: String) -> String {
        guard var parts = URLComponents(string: input.trimmingCharacters(in: .whitespacesAndNewlines)) else { return input }
        parts.fragment = nil; parts.host = parts.host?.lowercased()
        if parts.host?.hasSuffix("linkedin.com") == true {
            let queryID = parts.queryItems?.first { $0.name == "currentJobId" }?.value
            let pathID = parts.path.components(separatedBy: "/").last(where: { !$0.isEmpty })?.split(separator: "-").last.map(String.init)
            if let id = queryID ?? pathID, !id.isEmpty, id.allSatisfy(\.isNumber) { return "https://www.linkedin.com/jobs/view/" + id }
        }
        parts.queryItems = parts.queryItems?.filter { !($0.name.lowercased().hasPrefix("utm_") || ["gclid", "fbclid", "trackingId", "refId"].contains($0.name)) }
        if parts.queryItems?.isEmpty == true { parts.queryItems = nil }
        return parts.string ?? input
    }
    func capture(_ input: String) async {
        guard let url = URL(string: input) else { error = "Enter a valid public HTTPS job URL."; return }
        isLoading = true; error = nil; status = "Reading the public job page…"; defer { isLoading = false }
        do {
            let data = try await PublicJobHTTP.get(url)
            let html = String(decoding: data, as: UTF8.self)
            let pattern = #"<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            var posting: [String: Any]?
            func find(_ object: Any) -> [String: Any]? {
                if let list = object as? [Any] { return list.compactMap(find).first }
                guard let dictionary = object as? [String: Any] else { return nil }
                if dictionary["@type"] as? String == "JobPosting" { return dictionary }
                if let graph = dictionary["@graph"] { return find(graph) }
                return nil
            }
            for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
                guard let range = Range(match.range(at: 1), in: html), let json = String(html[range]).data(using: .utf8), let value = try? JSONSerialization.jsonObject(with: json) else { continue }
                if let found = find(value) { posting = found; break }
            }
            let organization = posting?["hiringOrganization"] as? [String: Any]
            let titleRegex = try NSRegularExpression(pattern: "<title[^>]*>([\\s\\S]*?)</title>", options: .caseInsensitive)
            let title = titleRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)).flatMap { Range($0.range(at: 1), in: html) }.map { Self.plain(String(html[$0])) } ?? "Review imported role"
            leads = [JobLead(title: posting?["title"] as? String ?? title, company: organization?["name"] as? String ?? "", url: Self.canonicalURL(url.absoluteString), description: Self.plain(posting?["description"] as? String ?? html), source: "URL capture", postedAt: posting?["datePosted"] as? String ?? "")]
            status = "Review this capture before saving. A successful download does not verify that applications are open."
        } catch { self.error = error.localizedDescription }
    }
    func search(_ query: String) async {
        guard let key = KeychainSecret.read(service: "com.hezi777.taavod", account: "tavily") else { error = "Connect Tavily in Coach Settings for web search. Company feeds and manual capture work without a key."; return }
        isLoading = true; error = nil; status = "Searching public job pages…"; defer { isLoading = false }
        do {
            var request = URLRequest(url: URL(string: "https://api.tavily.com/search")!); request.httpMethod = "POST"; request.timeoutInterval = 20
            request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization"); request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query, "max_results": 15, "include_answer": false])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw PublicJobHTTP.Failure.network }
            let body = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            leads = (body?["results"] as? [[String: Any]] ?? []).compactMap { item in
                guard let url = item["url"] as? String, let title = item["title"] as? String else { return nil }
                return JobLead(title: title, company: "", url: Self.canonicalURL(url), description: item["content"] as? String ?? "", source: "Tavily search")
            }
            status = "\(leads.count) public results. Review each role; search results may include expired vacancies."
        } catch { self.error = "Job search failed. Check the Tavily connection and try again." }
    }
    func companyFeeds(_ watchlist: [JSONValue]) async {
        isLoading = true; error = nil; leads = []; status = "Reading your saved company feeds…"; defer { isLoading = false }
        var failures = 0, configured = 0
        for item in watchlist {
            let company = item.object, slug = company.text("feedSlug"), kind = company.text("feedType")
            guard !slug.isEmpty, slug.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }), ["greenhouse", "lever"].contains(kind) else { continue }
            configured += 1
            let address = kind == "greenhouse" ? "https://boards-api.greenhouse.io/v1/boards/\(slug)/jobs?content=true" : "https://api.lever.co/v0/postings/\(slug)?mode=json"
            do {
                let (data, response) = try await URLSession.shared.data(from: URL(string: address)!)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw PublicJobHTTP.Failure.network }
                let body = try JSONSerialization.jsonObject(with: data)
                let jobs = kind == "greenhouse" ? (body as? [String: Any])?["jobs"] as? [[String: Any]] ?? [] : body as? [[String: Any]] ?? []
                leads += jobs.compactMap { job in
                    guard let url = (job["absolute_url"] ?? job["hostedUrl"]) as? String else { return nil }
                    let location = (job["location"] as? [String: Any])?["name"] as? String ?? (job["categories"] as? [String: Any])?["location"] as? String ?? ""
                    return JobLead(title: (job["title"] ?? job["text"]) as? String ?? "Role", company: company.text("name"), url: Self.canonicalURL(url), description: Self.plain((job["content"] ?? job["descriptionPlain"]) as? String ?? ""), source: kind.capitalized + " feed", location: location)
                }
            } catch { failures += 1 }
        }
        status = configured == 0 ? "No company feeds are configured in this imported watchlist. Use URL capture or web search." : "\(leads.count) listings · \(failures) feeds unavailable. Review each role before saving."
    }
    static func plain(_ html: String) -> String {
        String(html.replacingOccurrences(of: #"<(script|style)[^>]*>[\s\S]*?</\1>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ").replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).prefix(30_000))
    }
}
