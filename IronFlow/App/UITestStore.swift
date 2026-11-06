#if DEBUG
import Foundation

/// A test hook: a store on disk for the interface tests that close the app and open it again. With
/// `-ui-testing -ui-store <name>`, the app opens the store `tmp/ui-tests/<name>/IronFlow.store` in its
/// own temporary folder, never the real store in Application Support; `-ui-store-new` (the first
/// launch of a test) removes what an earlier run left in that folder first. The name is letters,
/// digits and "-" only, so the folder is always inside `tmp/ui-tests`.
enum UITestStore {
    static let flag = "-ui-store"
    static let newFlag = "-ui-store-new"

    struct InvalidName: LocalizedError {
        let name: String
        var errorDescription: String? { "Invalid -ui-store name '\(name)'." }
    }

    /// The store's name, when the app was launched for interface tests with a store on disk.
    static func name(in arguments: [String]) -> String? {
        guard arguments.contains("-ui-testing"),
              let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    /// Where the store is, its folder emptied first with `-ui-store-new`; `nil` without `-ui-store`.
    static func url(in arguments: [String]) throws -> URL? {
        guard let name = name(in: arguments) else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        guard !name.isEmpty, name.unicodeScalars.allSatisfy(allowed.contains) else { throw InvalidName(name: name) }
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "ui-tests", directoryHint: .isDirectory)
            .appending(path: name, directoryHint: .isDirectory)
        if arguments.contains(newFlag), FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: folder)
        }
        return folder.appending(path: "IronFlow.store")
    }
}
#endif
