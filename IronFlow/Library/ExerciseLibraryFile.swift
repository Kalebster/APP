import Foundation
import OSLog

/// Why the library file could not be read. Only the error's kind and code: never a person's data, which the
/// file does not have anyway.
struct ExerciseLibraryFileError: Error, Equatable, Sendable {
    let reason: String
}

/// The 1,525 combinations of the base list (26/11/2026), read once from `ExerciseLibrary.json`, which the app
/// carries in its bundle: the file is generated from design/lista-base-dados.json, the approved one, with
/// the keys and ids of the app, and a test checks that both say the same. A file and not Swift code: written
/// in Swift, the 1,525 entries made the optimized (Release) build take more than 28 minutes.
///
/// Read the first time the library is used (when the app opens, by the seeder), on whatever thread asks,
/// once: Swift initializes a `static let` once and safely across threads. A file that cannot be read is
/// logged and gives an empty library; the seeder then refuses to run (`ExerciseLibraryError.libraryFileUnreadable`)
/// and changes nothing in the store.
enum ExerciseLibraryFile {
    /// One combination, as the file has it: the stable raw values of the app's enums.
    struct Entry: Decodable, Equatable, Sendable {
        let key: String
        let id: String
        let name: String
        let group: MuscleGroup
        let base: String
        let option: LibraryEquipment
        let variation: String?
        let focus: String
        let common: Bool
        let primary: [Muscle]
        let secondary: [Muscle]
        let machine: MachineType?
    }

    static let fileName = "ExerciseLibrary"

    /// The file's entries, read once.
    static let contents: Result<[Entry], ExerciseLibraryFileError> = read()

    /// The entries; empty when the file could not be read.
    static var entries: [Entry] {
        (try? contents.get()) ?? []
    }

    /// Why the file could not be read; `nil` when it was.
    static var error: ExerciseLibraryFileError? {
        if case .failure(let error) = contents { return error }
        return nil
    }

    private static let logger = Logger(subsystem: "com.ironflow.app", category: "library")

    /// Reads and decodes the file of `bundle`.
    static func read(from bundle: Bundle = .main) -> Result<[Entry], ExerciseLibraryFileError> {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            logger.error("Exercise library file missing from the bundle")
            return .failure(ExerciseLibraryFileError(reason: "missing"))
        }
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            return .success(try JSONDecoder().decode([Entry].self, from: data))
        } catch {
            let nsError = error as NSError
            logger.error("Could not read the exercise library file: \(String(reflecting: type(of: error)), privacy: .public) \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
            return .failure(ExerciseLibraryFileError(reason: "\(nsError.domain) \(nsError.code)"))
        }
    }
}
