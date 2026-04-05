import Foundation

enum AppLog {
    static func debug(_ category: String, _ message: String, metadata: [String: String] = [:]) {
        AppLogger.shared.log(level: .debug, category: category, message: message, metadata: metadata)
    }

    static func info(_ category: String, _ message: String, metadata: [String: String] = [:]) {
        AppLogger.shared.log(level: .info, category: category, message: message, metadata: metadata)
    }

    static func warning(_ category: String, _ message: String, metadata: [String: String] = [:]) {
        AppLogger.shared.log(level: .warning, category: category, message: message, metadata: metadata)
    }

    static func error(_ category: String, _ message: String, metadata: [String: String] = [:]) {
        AppLogger.shared.log(level: .error, category: category, message: message, metadata: metadata)
    }
}

private enum AppLogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

private final class AppLogger: @unchecked Sendable {
    static let shared = AppLogger(appName: "TapThock")

    private enum Constants {
        static let currentLogFilename = "current.log"
        static let maxArchivedFiles = 5
        static let maxFileSizeBytes: UInt64 = 1_000_000
    }

    private let queue = DispatchQueue(label: "com.tapthock.logger", qos: .utility)
    private let fileManager: FileManager
    private let logsDirectoryURL: URL
    private let currentLogURL: URL
    private let timestampFormatter: ISO8601DateFormatter
    private let archiveDateFormatter: DateFormatter

    // Persistent file handle — opened once and kept open for the session.
    // Access is serialised by `queue`.
    private var fileHandle: FileHandle?
    // Approximate byte count written in this session; avoids a stat() call on
    // every write for the rotation check.
    private var approximateFileSize: UInt64 = 0

    private init(appName: String, fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let logsRootURL = libraryURL.appending(path: "Logs", directoryHint: .isDirectory)
        logsDirectoryURL = logsRootURL.appending(path: appName, directoryHint: .isDirectory)
        currentLogURL = logsDirectoryURL.appending(path: Constants.currentLogFilename)

        timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        archiveDateFormatter = DateFormatter()
        archiveDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        archiveDateFormatter.dateFormat = "yyyyMMdd-HHmmss"

        // Schedule setup asynchronously so init never blocks the main thread.
        queue.async { [self] in
            prepareLogDirectory()
            openFileHandle()
            writeSessionHeader()
        }
    }

    func log(level: AppLogLevel, category: String, message: String, metadata: [String: String]) {
        queue.async {
            self.rotateIfNeeded()

            var line = "\(self.timestampFormatter.string(from: Date())) [\(level.rawValue)] [\(category)] \(self.sanitize(message))"
            if !metadata.isEmpty {
                let metadataString = metadata
                    .sorted { $0.key < $1.key }
                    .map { "\($0.key)=\(self.sanitize($0.value))" }
                    .joined(separator: " ")
                line += " | \(metadataString)"
            }
            line += "\n"

            self.append(line)
        }
    }

    private func prepareLogDirectory() {
        do {
            try fileManager.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true)
            if !fileManager.fileExists(atPath: currentLogURL.path) {
                fileManager.createFile(atPath: currentLogURL.path, contents: nil)
            }
        } catch {
            fputs("TapThock logging setup failed: \(error)\n", stderr)
        }
    }

    /// Opens the persistent file handle and seeks to end, capturing the
    /// current file size for the rotation heuristic.
    private func openFileHandle() {
        do {
            let handle = try FileHandle(forWritingTo: currentLogURL)
            let endOffset = try handle.seekToEnd()
            approximateFileSize = endOffset
            fileHandle = handle
        } catch {
            fputs("TapThock log handle open failed: \(error)\n", stderr)
        }
    }

    private func writeSessionHeader() {
        let processInfo = ProcessInfo.processInfo
        append("=== Session started pid=\(processInfo.processIdentifier) at \(timestampFormatter.string(from: Date())) ===\n")
        append("Logs directory: \(logsDirectoryURL.path)\n")
    }

    private func rotateIfNeeded() {
        guard approximateFileSize >= Constants.maxFileSizeBytes else { return }

        // Close the current handle before rotating the file.
        try? fileHandle?.close()
        fileHandle = nil

        let archiveURL = logsDirectoryURL.appending(path: "TapThock-\(archiveDateFormatter.string(from: Date())).log")
        do {
            if fileManager.fileExists(atPath: archiveURL.path) {
                try fileManager.removeItem(at: archiveURL)
            }
            try fileManager.moveItem(at: currentLogURL, to: archiveURL)
            fileManager.createFile(atPath: currentLogURL.path, contents: nil)
            pruneArchivedLogs()
        } catch {
            fputs("TapThock log rotation failed: \(error)\n", stderr)
        }

        // Re-open handle pointing at the fresh empty file.
        openFileHandle()
        append("=== Log rotated at \(timestampFormatter.string(from: Date())) ===\n")
    }

    private func pruneArchivedLogs() {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: logsDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let archivedLogs = contents
            .filter { $0.lastPathComponent != Constants.currentLogFilename }
            .sorted {
                let lhsDate = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate > rhsDate
            }

        guard archivedLogs.count > Constants.maxArchivedFiles else { return }

        for archivedLog in archivedLogs.dropFirst(Constants.maxArchivedFiles) {
            try? fileManager.removeItem(at: archivedLog)
        }
    }

    private func append(_ line: String) {
        guard let data = line.data(using: .utf8), let handle = fileHandle else { return }
        do {
            try handle.write(contentsOf: data)
            approximateFileSize += UInt64(data.count)
        } catch {
            fputs("TapThock log write failed: \(error)\n", stderr)
        }
    }

    private func sanitize(_ value: String) -> String {
        value.replacingOccurrences(of: "\n", with: "\\n")
    }
}
