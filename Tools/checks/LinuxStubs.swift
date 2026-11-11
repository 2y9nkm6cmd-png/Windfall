#if !canImport(SwiftUI)
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
// Stand-ins for Apple-only types, so app logic can be type-checked on Linux.
// These exist only in the checking harness, never in the app.
public struct CLLocationCoordinate2D { public var latitude: Double; public var longitude: Double
    public init(latitude: Double, longitude: Double) { self.latitude = latitude; self.longitude = longitude } }
public struct FetchDescriptor<T> { public init() {} ; public init(sortBy: [Any]) {} }
// A small working stand-in: it remembers what is inserted, so tests can
// run an import and count what arrived.
public final class ModelContext {
    public init() {}
    private var objects: [AnyObject] = []
    public func fetch<T>(_ d: FetchDescriptor<T>) throws -> [T] { objects.compactMap { $0 as? T } }
    public func fetchCount<T>(_ d: FetchDescriptor<T>) throws -> Int { try fetch(d).count }
    public func insert<T>(_ m: T) { let o = m as AnyObject; if !objects.contains(where: { $0 === o }) { objects.append(o) } }
    public func delete<T>(_ m: T) { let o = m as AnyObject; objects.removeAll { $0 === o } }
    public func save() throws {}
}
struct __Lines: AsyncSequence { typealias Element = String
    struct AsyncIterator: AsyncIteratorProtocol { mutating func next() async throws -> String? { nil } }
    func makeAsyncIterator() -> AsyncIterator { AsyncIterator() } }
struct __Bytes { var lines: __Lines { __Lines() } }
func __bytes(_ r: URLRequest) async throws -> (__Bytes, URLResponse) { fatalError() }
public struct Color: Hashable { public static let red = Color(), green = Color(), blue = Color(), orange = Color(), yellow = Color(), pink = Color(), purple = Color(), teal = Color(), gray = Color(), brown = Color(), mint = Color(), indigo = Color(), secondary = Color(), primary = Color(), accentColor = Color(), white = Color(), black = Color(), clear = Color()
    public func opacity(_ o: Double) -> Color { self } }
public final class NLEmbedding { public static func sentenceEmbedding(for l: NLLanguage) -> NLEmbedding? { nil }
    public func vector(for s: String) -> [Double]? { nil } }
public enum NLLanguage { case english }
public enum NLTokenUnit { case sentence, word }
public final class NLTokenizer { public init(unit: NLTokenUnit) {} ; public var string: String? = nil
    public func enumerateTokens(in r: Range<String.Index>, using block: (Range<String.Index>, Int) -> Bool) {} }
extension URL { func startAccessingSecurityScopedResource() -> Bool { true } ; func stopAccessingSecurityScopedResource() {} }
#endif
