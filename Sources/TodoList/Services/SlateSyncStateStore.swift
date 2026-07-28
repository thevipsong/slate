import Foundation

actor SlateSyncStateStore {
    private let fileURL: URL

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        let root: URL
        if let baseDirectory {
            root = baseDirectory
        } else {
            root = (try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )) ?? fileManager.homeDirectoryForCurrentUser
        }
        fileURL = root
            .appendingPathComponent("Slate", isDirectory: true)
            .appendingPathComponent("sync-state.json")
    }

    func load() -> SlateLocalSyncState {
        guard let data = try? Data(contentsOf: fileURL) else {
            return SlateLocalSyncState()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(SlateLocalSyncState.self, from: data))
            ?? SlateLocalSyncState()
    }

    func save(_ state: SlateLocalSyncState) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: fileURL, options: .atomic)
    }

    func markLocalChange() {
        var state = load()
        state.localModifiedAt = Date()
        try? save(state)
    }

    func clearBaseline() throws {
        let current = load()
        try save(
            SlateLocalSyncState(
                deviceID: current.deviceID,
                localModifiedAt: Date()
            )
        )
    }
}
