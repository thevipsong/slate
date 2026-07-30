import SwiftUI
import UniformTypeIdentifiers

struct SlateArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension Notification.Name {
    static let importSlateArchive = Notification.Name("slate.importArchive")
    static let exportSlateArchive = Notification.Name("slate.exportArchive")
    static let configureSlateSync = Notification.Name("slate.configureSync")
}
