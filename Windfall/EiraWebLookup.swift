//
//  EiraWebLookup.swift
//  Windfall
//
//  Looking things up online, straight from the device.
//
//  No server of our own is involved, so this works on an iPad anywhere
//  there is a connection. Two tools live here:
//
//    search_wikipedia   a general reference, needing no account or key
//    read_web_page      fetches one page and hands Eira its plain text
//
//  Species names are still resolved through GBIF in EiraTools.swift,
//  which is the more authoritative source for taxonomy.
//
//  General web search (type anything, get results from the whole web)
//  needs a search service, and those need an account. The WebSearchProvider
//  protocol at the bottom is the socket one plugs into later.
//
//  Trust: everything from here is labelled as unverified. Wikipedia and
//  web pages are useful leads, not authorities.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Turning a web page into plain text

enum WebText {

    /// Strips a page down to readable text.
    ///
    /// A small model can only take in a few pages of text at once, so the
    /// result is cut to `limit` characters, ending on a whole word.
    static func plainText(fromHTML html: String, limit: Int = 4000) -> String {
        var text = html

        // Whole blocks that are never readable content.
        for tag in ["script", "style", "noscript", "svg", "head", "nav", "footer"] {
            text = replace(text, "<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)>", with: " ")
        }
        text = replace(text, "<!--[\\s\\S]*?-->", with: " ")

        // Tags that end a line of text become line breaks.
        text = replace(text, "<br\\s*/?>|</(p|div|li|tr|h[1-6]|section|article)>", with: "\n")

        // Every remaining tag goes.
        text = replace(text, "<[^>]+>", with: " ")

        text = decodeEntities(text)

        // Tidy the spacing: runs of spaces to one, runs of blank lines to one.
        // \u{00A0} is the non-breaking space that &nbsp; turns into.
        text = replace(text, "[ \\t\u{00A0}]+", with: " ")
        text = replace(text, " ?\\n ?", with: "\n")
        text = replace(text, "\\n{2,}", with: "\n\n")
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return truncate(text, to: limit)
    }

    /// Cuts text to a length without splitting a word.
    static func truncate(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        let cut = String(text.prefix(limit))
        if let lastSpace = cut.lastIndex(where: { $0 == " " || $0 == "\n" }) {
            return String(cut[..<lastSpace]) + "…"
        }
        return cut + "…"
    }

    /// The page's title, if it has one.
    static func title(fromHTML html: String) -> String? {
        guard let range = html.range(
            of: "<title[^>]*>([\\s\\S]*?)</title>",
            options: [.regularExpression, .caseInsensitive]) else { return nil }
        let inner = replace(String(html[range]), "</?title[^>]*>", with: "")
        let cleaned = decodeEntities(inner).trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    static func decodeEntities(_ text: String) -> String {
        var result = text
        let named = ["&nbsp;": " ", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
                     "&#39;": "'", "&apos;": "'", "&ndash;": "–", "&mdash;": "—",
                     "&deg;": "°", "&times;": "×", "&amp;": "&"]
        // &amp; is decoded last, so "&amp;lt;" becomes "&lt;" and not "<".
        for key in named.keys.sorted(by: { $0 != "&amp;" && $1 == "&amp;" }) {
            result = result.replacingOccurrences(of: key, with: named[key] ?? "")
        }
        return result
    }

    private static func replace(_ text: String, _ pattern: String, with replacement: String) -> String {
        text.replacingOccurrences(of: pattern, with: replacement,
                                  options: [.regularExpression, .caseInsensitive])
    }
}

// MARK: - Wikipedia

/// Reads Wikipedia through its public interfaces. No account is needed.
struct WikipediaLookup {

    struct Article: Equatable {
        let title: String
        let extract: String
        let url: String?
    }

    var session: URLSession = .shared

    /// Finds the best-matching article and returns its opening summary.
    func lookUp(_ query: String) async throws -> Article? {
        guard let title = try await bestTitle(for: query) else { return nil }
        return try await summary(title: title)
    }

    func bestTitle(for query: String) async throws -> String? {
        var components = URLComponents(string: "https://en.wikipedia.org/w/api.php")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "list", value: "search"),
            URLQueryItem(name: "srsearch", value: query),
            URLQueryItem(name: "srlimit", value: "3"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "utf8", value: "1")
        ]
        guard let url = components.url else { return nil }
        let data = try await fetch(url)
        return Self.parseSearchTitles(data).first
    }

    func summary(title: String) async throws -> Article? {
        let path = title.replacingOccurrences(of: " ", with: "_")
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)")
        else { return nil }
        let data = try await fetch(url)
        return Self.parseSummary(data)
    }

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        // Wikipedia asks every app to say who it is.
        request.setValue("Windfall/1.0 (personal garden recording app)",
                         forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: request)
        return data
    }

    // The two readers below take raw data and are kept separate from the
    // network calls, so they can be tested without a connection.

    static func parseSearchTitles(_ data: Data) -> [String] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let query = json["query"] as? [String: Any],
              let results = query["search"] as? [[String: Any]] else { return [] }
        return results.compactMap { $0["title"] as? String }
    }

    static func parseSummary(_ data: Data) -> Article? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = json["title"] as? String,
              let extract = json["extract"] as? String, !extract.isEmpty else { return nil }
        let urls = json["content_urls"] as? [String: Any]
        let desktop = urls?["desktop"] as? [String: Any]
        return Article(title: title, extract: extract, url: desktop?["page"] as? String)
    }
}

// MARK: - Reading one page

struct WebPageReader {

    enum ReadError: LocalizedError {
        case notAWebAddress
        case tooLarge
        case notText

        var errorDescription: String? {
            switch self {
            case .notAWebAddress: return "That is not a web address Eira can open."
            case .tooLarge:       return "That page is too large to read."
            case .notText:        return "That address did not return a readable page."
            }
        }
    }

    var session: URLSession = .shared
    /// Pages over this size are refused before any text is extracted.
    var maximumBytes = 2_000_000

    func read(_ address: String, limit: Int = 4000) async throws -> (title: String?, text: String, host: String) {
        guard let url = Self.webURL(from: address), let host = url.host else {
            throw ReadError.notAWebAddress
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Windfall/1.0 (personal garden recording app)",
                         forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        guard data.count <= maximumBytes else { throw ReadError.tooLarge }
        guard let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else { throw ReadError.notText }

        return (WebText.title(fromHTML: html),
                WebText.plainText(fromHTML: html, limit: limit),
                host)
    }

    /// Accepts only ordinary web addresses. "example.org/page" is treated
    /// as https. Anything else, such as a file path, is refused.
    static func webURL(from address: String) -> URL? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: withScheme),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = url.host, host.contains(".") else { return nil }
        return url
    }
}

// MARK: - The tools Eira sees

extension EiraTools {

    static let searchWikipedia = ToolDefinition(
        name: "search_wikipedia",
        description: "Look up a topic on Wikipedia and return the opening summary of the best match. Use for general background when the user's own records and notes have nothing. Treat the result as an unverified lead.",
        parameters: [
            "type": "object",
            "properties": [
                "query": ["type": "string", "description": "The topic to look up"]
            ],
            "required": ["query"]
        ]
    )

    static let readWebPage = ToolDefinition(
        name: "read_web_page",
        description: "Fetch one web page and return its text. Use only when the user gives a web address or asks about a specific page.",
        parameters: [
            "type": "object",
            "properties": [
                "url": ["type": "string", "description": "The full web address"]
            ],
            "required": ["url"]
        ]
    )
}

extension ToolRunner {

    func searchWikipedia(_ query: String) async -> ToolResult {
        guard !query.isEmpty else { return ToolResult(text: "No topic given.", source: "app") }
        do {
            guard let article = try await WikipediaLookup().lookUp(query) else {
                return ToolResult(text: "Wikipedia has nothing matching \"\(query)\".",
                                  source: "Wikipedia")
            }
            let link = article.url.map { "\n\($0)" } ?? ""
            return ToolResult(text: "\(article.title): \(article.extract)\(link)",
                              source: "Wikipedia, unverified general reference")
        } catch {
            return ToolResult(text: "Couldn't reach Wikipedia: \(error.localizedDescription)",
                              source: "app")
        }
    }

    func readWebPage(_ address: String) async -> ToolResult {
        do {
            let page = try await WebPageReader().read(address)
            let heading = page.title.map { "\($0)\n\n" } ?? ""
            return ToolResult(text: heading + page.text,
                              source: "web page at \(page.host), unverified")
        } catch {
            return ToolResult(text: "Couldn't read that page: \(error.localizedDescription)",
                              source: "app")
        }
    }
}

// MARK: - A socket for general web search

/// General web search needs a search service. When one is chosen, it is
/// written as a type that conforms to this, and Eira gains a search tool
/// without anything else changing.
protocol WebSearchProvider {
    var name: String { get }
    func search(_ query: String, limit: Int) async throws -> [WebSearchResult]
}

struct WebSearchResult: Equatable {
    let title: String
    let url: String
    let snippet: String
}
