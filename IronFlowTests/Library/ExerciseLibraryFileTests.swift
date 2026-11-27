import Foundation
import Testing
@testable import IronFlow

/// The app's `ExerciseLibrary.json`: read whole, once, and with its errors handled. That it says what the
/// approved design/lista-base-dados.json says is checked by `DefaultExerciseLibraryTests`, which reads the
/// library built from it.
struct ExerciseLibraryFileTests {
    /// The tests' own bundle, which has no library file.
    private final class TestBundleToken {}

    @Test("The file of the app is read whole, with no error: 1,525 combinations, the same that the library and the muscles have")
    func readWhole() throws {
        #expect(ExerciseLibraryFile.error == nil)
        let entries = try ExerciseLibraryFile.read(from: .main).get()
        #expect(entries.count == 1_525)
        #expect(entries == ExerciseLibraryFile.entries)
        #expect(entries.map(\.key) == DefaultExerciseLibrary.all.map(\.key))
        #expect(entries.map(\.key) == DefaultExerciseMuscles.all.map(\.key))
    }

    @Test("A bundle without the file gives an error, not a library")
    func missingFile() {
        let result = ExerciseLibraryFile.read(from: Bundle(for: TestBundleToken.self))
        #expect(result == .failure(ExerciseLibraryFileError(reason: "missing")))
    }

    @Test("A file that is not the library gives an error, not a library: cut, empty, or with an unknown equipment")
    func unreadableFile() throws {
        let valid = #"{"key":"k","id":"0A000000-0000-4000-8000-00000000000A","name":"N","group":"chest","base":"B","option":"barbell","variation":null,"focus":"F","common":true,"primary":["chest"],"secondary":[],"machine":null}"#
        for contents in ["[" + valid, "", "[" + valid.replacingOccurrences(of: "\"barbell\"", with: "\"trampolim\"") + "]"] {
            let directory = try makeTemporaryDirectory()
            defer { removeTemporaryDirectory(directory) }
            try Data(contents.utf8).write(to: directory.appending(path: "\(ExerciseLibraryFile.fileName).json"))
            let bundle = try #require(Bundle(url: directory))
            let result = ExerciseLibraryFile.read(from: bundle)
            #expect(throws: ExerciseLibraryFileError.self) { try result.get() }
        }
        // The same entry, whole, is read.
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        try Data(("[" + valid + "]").utf8).write(to: directory.appending(path: "\(ExerciseLibraryFile.fileName).json"))
        let bundle = try #require(Bundle(url: directory))
        #expect(try ExerciseLibraryFile.read(from: bundle).get().map(\.option) == [.barbell])
    }

    /// Not a limit, a measure: how long reading the file takes, done once when the app opens.
    @Test("The time to read the file is printed")
    func readTime() throws {
        let clock = ContinuousClock()
        var durations: [Duration] = []
        for _ in 0..<5 {
            let start = clock.now
            let entries = try ExerciseLibraryFile.read(from: .main).get()
            durations.append(start.duration(to: clock.now))
            #expect(entries.count == 1_525)
        }
        let sorted = durations.sorted()
        print("MEDIÇÃO leitura do ExerciseLibrary.json (1.525 combinações, 5 leituras): mediana \(sorted[2]), mínimo \(sorted[0]), máximo \(sorted[4])")
    }
}
