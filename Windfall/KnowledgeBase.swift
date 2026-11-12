//
//  KnowledgeBase.swift
//  Windfall
//
//  Semantic search over your own documents, so Eira can answer from your
//  book, your notes and your corrections file rather than from whatever
//  it half-remembers.
//
//  A deliberate choice worth understanding: this uses NLEmbedding from
//  Apple's NaturalLanguage framework rather than a downloaded embedding
//  model. It is built into the OS, needs no package, no download and no
//  key, and runs on-device. The vectors are less good than a modern
//  dedicated embedding model — but they are free, instant, and quite good
//  enough to find the right paragraph in a few hundred pages.
//
//  No vector database either. At your corpus size — a book, some notes,
//  a corrections log — brute-force cosine similarity over a few thousand
//  chunks takes a few milliseconds. A vector store would be machinery
//  earning nothing.
//

import Foundation
import NaturalLanguage
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Models

@Model
final class KnowledgeDocument {

    var id: UUID = UUID()
    var title: String = ""
    var sourceDescription: String?      // where it came from, for citation
    var addedAt: Date = Date.now
    var characterCount: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \KnowledgeChunk.document)
    var chunks: [KnowledgeChunk]? = []

    init(title: String = "") { self.title = title }
}

@Model
final class KnowledgeChunk {

    var id: UUID = UUID()
    var text: String = ""
    var order: Int = 0
    /// Heading or section this came from, so citations can be specific.
    var context: String?

    /// The embedding, stored as raw bytes. SwiftData has no vector type,
    /// and a [Double] array would be far larger on disk.
    @Attribute(.externalStorage)
    var vectorData: Data?

    var document: KnowledgeDocument?

    init() {}

    var vector: [Double]? {
        get {
            guard let vectorData else { return nil }
            return vectorData.withUnsafeBytes { raw in
                Array(raw.bindMemory(to: Double.self))
            }
        }
        set {
            guard let newValue else { vectorData = nil; return }
            vectorData = newValue.withUnsafeBufferPointer { Data(buffer: $0) }
        }
    }
}

// MARK: - Chunking

enum Chunker {

    /// Splits on paragraphs, then packs them up to a target size.
    ///
    /// Chunking quality matters more than model size for retrieval. Cut
    /// mid-sentence and you get fragments that match nothing; make chunks
    /// too big and the relevant sentence is drowned by everything around
    /// it. Paragraph boundaries with a size ceiling is the pragmatic
    /// middle, and species-account text suits it particularly well.
    static func chunk(_ text: String,
                      targetCharacters: Int = 900,
                      overlap: Int = 120) -> [(text: String, context: String?)] {

        let paragraphs = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var chunks: [(String, String?)] = []
        var current = ""
        var heading: String?

        for paragraph in paragraphs {
            // Short lines with no full stop are probably headings.
            if paragraph.count < 80 && !paragraph.hasSuffix(".") && !paragraph.hasSuffix(",") {
                heading = paragraph
            }

            if current.count + paragraph.count > targetCharacters, !current.isEmpty {
                chunks.append((current, heading))
                // Carry the tail forward, so a sentence spanning the
                // boundary is still findable from either side.
                current = String(current.suffix(overlap)) + "\n" + paragraph
            } else {
                current += (current.isEmpty ? "" : "\n") + paragraph
            }
        }

        if !current.isEmpty { chunks.append((current, heading)) }
        return chunks
    }
}

// MARK: - Embedding

enum Embedder {

    private static let embedding = NLEmbedding.sentenceEmbedding(for: .english)

    static var isAvailable: Bool { embedding != nil }

    /// A vector for a chunk. Sentence embeddings work best on sentences,
    /// so a long chunk is embedded sentence by sentence and averaged —
    /// crude, but it holds the overall subject well enough to retrieve on.
    static func vector(for text: String) -> [Double]? {
        guard let embedding else { return nil }

        let tokeniser = NLTokenizer(unit: .sentence)
        tokeniser.string = text

        var vectors: [[Double]] = []
        tokeniser.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard sentence.count > 10,
                  let vector = embedding.vector(for: sentence) else { return true }
            vectors.append(vector)
            return true
        }

        guard !vectors.isEmpty else { return embedding.vector(for: text) }

        let dimensions = vectors[0].count
        var mean = [Double](repeating: 0, count: dimensions)
        for vector in vectors {
            for i in 0..<dimensions { mean[i] += vector[i] }
        }
        for i in 0..<dimensions { mean[i] /= Double(vectors.count) }
        return normalise(mean)
    }

    /// Normalised vectors mean cosine similarity is just a dot product.
    static func normalise(_ vector: [Double]) -> [Double] {
        let magnitude = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
    }

    static func similarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }
        var total = 0.0
        for i in 0..<a.count { total += a[i] * b[i] }
        return total
    }
}

// MARK: - Service

@Observable
@MainActor
final class KnowledgeService {

    var isIndexing = false
    var progress = ""
    var lastError: String?

    // MARK: Adding a document

    func add(text: String, title: String, source: String?, into context: ModelContext) async {
        guard Embedder.isAvailable else {
            lastError = "Sentence embeddings aren't available on this device."
            return
        }

        isIndexing = true
        defer { isIndexing = false }

        let document = KnowledgeDocument(title: title)
        document.sourceDescription = source
        document.characterCount = text.count
        context.insert(document)

        let pieces = Chunker.chunk(text)

        for (index, piece) in pieces.enumerated() {
            progress = "Indexing \(index + 1) of \(pieces.count)…"

            let chunk = KnowledgeChunk()
            chunk.text = piece.text
            chunk.context = piece.context
            chunk.order = index
            chunk.vector = Embedder.vector(for: piece.text)
            chunk.document = document
            document.chunks?.append(chunk)

            // Let the UI breathe on a long document.
            if index % 20 == 0 { await Task.yield() }
        }

        progress = "\(pieces.count) passages indexed from \(title)"
    }

    // MARK: Searching

    struct Hit {
        let chunk: KnowledgeChunk
        let score: Double
        var citation: String {
            let title = chunk.document?.title ?? "unknown source"
            if let context = chunk.context { return "\(title) — \(context)" }
            return title
        }
    }

    /// Brute-force cosine similarity. At a few thousand chunks this is
    /// milliseconds, and it avoids an index that could fall out of step.
    func search(_ query: String, in context: ModelContext, limit: Int = 4) -> [Hit] {
        guard let queryVector = Embedder.vector(for: query) else { return [] }
        let chunks = (try? context.fetch(FetchDescriptor<KnowledgeChunk>())) ?? []

        return chunks
            .compactMap { chunk -> Hit? in
                guard let vector = chunk.vector else { return nil }
                return Hit(chunk: chunk, score: Embedder.similarity(queryVector, vector))
            }
            .filter { $0.score > 0.3 }   // below this it's noise
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - Eira tool

extension EiraTools {

    static let searchNotes = ToolDefinition(
        name: "search_notes",
        description: "Search the user's own book, notes and corrections file for relevant passages. Use for questions about pollinator ecology, flower morphology, or anything the user has written about. Always prefer this over general knowledge.",
        parameters: [
            "type": "object",
            "properties": [
                "query": ["type": "string", "description": "What to look for"]
            ],
            "required": ["query"]
        ]
    )
}

extension ToolRunner {

    func searchNotes(_ query: String, service: KnowledgeService) -> ToolResult {
        let hits = service.search(query, in: context)

        guard !hits.isEmpty else {
            return ToolResult(text: "Nothing in the notes about \"\(query)\".",
                              source: "user's knowledge base")
        }

        let passages = hits.map { hit in
            "From \(hit.citation):\n\(hit.chunk.text)"
        }

        return ToolResult(text: passages.joined(separator: "\n\n---\n\n"),
                          source: "user's own documents")
    }
}

// MARK: - Knowledge screen

struct KnowledgeBaseView: View {

    @Query(sort: [SortDescriptor(\KnowledgeDocument.addedAt, order: .reverse)])
    private var documents: [KnowledgeDocument]

    @Environment(\.modelContext) private var context

    @State private var service = KnowledgeService()
    @State private var showingImporter = false
    @State private var testQuery = ""
    @State private var testHits: [KnowledgeService.Hit] = []

    var body: some View {
        List {
            Section {
                Button {
                    showingImporter = true
                } label: {
                    Label("Add a document", systemImage: "doc.badge.plus")
                }

                if service.isIndexing {
                    HStack { ProgressView(); Text(service.progress) }
                } else if !service.progress.isEmpty {
                    Label(service.progress, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                        .font(.callout)
                }
            } header: {
                Text("Documents")
            } footer: {
                Text("Plain text or Markdown. Your book, your notes, your corrections file. Everything is indexed on this device — nothing is uploaded.")
            }

            if !documents.isEmpty {
                Section("Indexed") {
                    ForEach(documents) { document in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(document.title).font(.subheadline)
                            Text("^[\((document.chunks ?? []).count) passage](inflect: true) · \(document.characterCount.formatted()) characters")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets { context.delete(documents[i]) }
                    }
                }

                Section {
                    TextField("Try a search", text: $testQuery)
                        .onSubmit {
                            testHits = service.search(testQuery, in: context)
                        }

                    ForEach(testHits.indices, id: \.self) { index in
                        let hit = testHits[index]
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(hit.citation).font(.caption.weight(.medium))
                                Spacer()
                                Text(String(format: "%.2f", hit.score))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Text(hit.chunk.text)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Test retrieval")
                } footer: {
                    Text("Worth checking before relying on it. If the right passage doesn't come back for a question you'd ask, the chunking needs adjusting rather than the model.")
                }
            }

            if let error = service.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("Knowledge")
        .paperScreen()
        .fileImporter(isPresented: $showingImporter,
                      allowedContentTypes: [.plainText, .text]) { result in
            switch result {
            case .success(let url):
                Task { await load(url) }
            case .failure(let error):
                service.lastError = error.localizedDescription
            }
        }
    }

    private func load(_ url: URL) async {
        guard url.startAccessingSecurityScopedResource() else {
            service.lastError = "Couldn't open that file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            service.lastError = "That file isn't plain text."
            return
        }

        await service.add(text: text,
                          title: url.deletingPathExtension().lastPathComponent,
                          source: url.lastPathComponent,
                          into: context)
    }
}
