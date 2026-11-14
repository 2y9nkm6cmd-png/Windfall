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
import SwiftData
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

        // Whole blocks that are never readable content. "popover-content"
        // is the RHS's pop-up glossary: the meaning of a word such as
        // "perennial", written out in the middle of a sentence and
        // hidden until the word is tapped. Left in, a definition that
        // mentions dying back was picked out as pruning advice
        // (14 November 2026).
        for tag in ["script", "style", "noscript", "svg", "head", "nav", "footer", "popover-content"] {
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
    ///
    /// The query is first tried as a page title. Wikipedia redirects
    /// everyday names to the right article, so "red mason bee" arrives at
    /// "Osmia bicornis". Searching is the fallback, because a search for
    /// the same words returns the broader "Mason bee" article first.
    func lookUp(_ query: String) async throws -> Article? {
        if let exact = try? await summary(title: query) { return exact }
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
        // A disambiguation page is a list of possible meanings ("Robin
        // may refer to..."), not an article, so it is not an answer.
        if json["type"] as? String == "disambiguation" { return nil }
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
        /// The site answered that there is no such page (or refused).
        /// The number is the site's own code: 404 is "not found".
        case notFound(Int)

        var errorDescription: String? {
            switch self {
            case .notAWebAddress: return "That is not a web address Eira can open."
            case .tooLarge:       return "That page is too large to read."
            case .notText:        return "That address did not return a readable page."
            case .notFound(let code): return "The site said there is no page at that address (\(code))."
            }
        }
    }

    /// A page as it came back, before it is cut to size.
    struct Page {
        let title: String?
        /// All of the page's readable text.
        let text: String
        let host: String
        /// Where the page really was, which can differ from the address
        /// asked for when the site sends the reader on elsewhere.
        let address: String
    }

    var session: URLSession = .shared
    /// Pages over this size are refused before any text is extracted.
    var maximumBytes = 2_000_000

    /// Fetches a page whole.
    ///
    /// Until 14 November 2026 a page was cut to its first 4,000
    /// characters as it was read. A growing guide's pruning advice can
    /// sit far below that, so the whole text is now kept here and the
    /// right part chosen afterwards (WebText.passages).
    ///
    /// A site's answer carries a number. 200 means "here it is", 404
    /// "no such page". Anything outside 200 to 299 is now treated as no
    /// page, where before a "not found" page was read as if it were
    /// the answer.
    func fetch(_ address: String) async throws -> Page {
        guard let url = Self.webURL(from: address), let host = url.host else {
            throw ReadError.notAWebAddress
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Windfall/1.0 (personal garden recording app)",
                         forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        // `as?` asks whether the answer is a web answer, which has a code.
        if let code = (response as? HTTPURLResponse)?.statusCode, !(200...299).contains(code) {
            throw ReadError.notFound(code)
        }
        guard data.count <= maximumBytes else { throw ReadError.tooLarge }
        guard let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else { throw ReadError.notText }

        let pageTitle = WebText.title(fromHTML: html)
        let readable = WebText.plainText(fromHTML: html, limit: 200_000)
        return Page(title: pageTitle,
                    text: readable,
                    host: response.url?.host ?? host,
                    address: response.url?.absoluteString ?? url.absoluteString)
    }

    func read(_ address: String, limit: Int = 4000) async throws -> (title: String?, text: String, host: String) {
        let page = try await fetch(address)
        return (page.title, WebText.truncate(page.text, to: limit), page.host)
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

    func searchWikipedia(_ query: String, question: String = "") async -> ToolResult {
        guard !query.isEmpty else { return ToolResult(text: "No topic given.", source: "app") }
        do {
            guard let article = try await WikipediaLookup().lookUp(query) else {
                return ToolResult(text: "Wikipedia has nothing matching \"\(query)\".",
                                  source: "Wikipedia")
            }
            let link = article.url.map { "\n\($0)" } ?? ""
            var result = ToolResult(text: "\(article.title): \(article.extract)\(link)",
                                    source: "Wikipedia, unverified general reference")
            // What was found can be offered for keeping. See KeptFacts.
            if let address = article.url {
                let asked = question.isEmpty ? query : question
                result.onlineFind = OnlineFind(sourceName: "Wikipedia", trust: .general, address: address,
                                         title: article.title,
                                         plantName: plantNamed(in: asked + " " + article.title),
                                         field: KeptFacts.field(forQuestion: asked, words: ""))
            }
            return result
        } catch {
            return ToolResult(text: "Couldn't reach Wikipedia: \(error.localizedDescription)",
                              source: "app")
        }
    }

    /// Reads one page and hands back the part that bears on the question.
    ///
    /// `question` is what the gardener typed, if the app is reading the
    /// page for them. The address is taken out of it, and what is left
    /// says which paragraphs to pick: asked about pruning, she is
    /// handed the pruning. With no question, or a page that does not
    /// mention it, the top of the page is handed over as before.
    ///
    /// The source line names the site and says how far it is trusted
    /// (EiraSources.swift), where before every page was "unverified".
    func readWebPage(_ address: String, question: String = "") async -> ToolResult {
        do {
            let page = try await WebPageReader().fetch(address)
            let source = WebSources.source(forAddress: page.address)
            let asked = question.replacingOccurrences(of: address, with: " ")
            let topic = CareTopic.find(in: asked)
            let named = plantNamed(in: asked + " " + (page.title ?? ""))
            let weak = KeptFacts.pageWords(forQuestion: asked, plant: named)
            var body = WebText.passages(in: page.text, strong: topic?.pageWords ?? [], weak: weak)
            if body.isEmpty { body = WebText.truncate(page.text, to: 1200) }

            let heading = page.title.map { "\($0)\n\n" } ?? ""
            var result = ToolResult(text: heading + body,
                                    source: "\(source.name), \(source.trust.said), at \(page.address)")
            result.onlineFind = OnlineFind(sourceName: source.name, trust: source.trust, address: page.address,
                                     title: page.title,
                                     plantName: named,
                                     field: KeptFacts.field(forQuestion: asked, words: ""))
            return result
        } catch {
            return ToolResult(text: "Couldn't read that page: \(error.localizedDescription)",
                              source: "app")
        }
    }

    /// The plant in the library that a piece of text names, if any.
    func plantNamed(in text: String) -> String? {
        let plants = (try? context.fetch(FetchDescriptor<Plant>())) ?? []
        return KeptFacts.plantNamed(in: text, among: plants.map(\.commonName))
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
