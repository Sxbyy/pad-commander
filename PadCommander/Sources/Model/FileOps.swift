import Foundation

struct OpError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    init(_ m: String) { message = m }
}

enum ConflictChoice {
    case overwrite, overwriteAll, skip, skipAll, rename, cancel
}

enum ConflictPolicy: String, CaseIterable, Identifiable {
    case ask, overwrite, skip, rename
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ask: return "Nachfragen"
        case .overwrite: return "Überschreiben"
        case .skip: return "Überspringen"
        case .rename: return "Umbenennen"
        }
    }
}

/// Fortschritt, der an die Oberflaeche gemeldet wird.
struct Progress {
    var title: String
    var detail: String
    var fraction: Double?
}

enum FileOps {
    static func isDir(_ url: URL) -> Bool {
        var d: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &d) && d.boolValue
    }

    static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Groesse einer Datei oder eines ganzen Ordners.
    static func size(of url: URL, cancelled: () -> Bool = { false }) -> Int64 {
        let fm = FileManager.default
        if !isDir(url) {
            return Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        var total: Int64 = 0
        guard let en = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: []) else { return 0 }
        for case let u as URL in en {
            if cancelled() { break }
            if let v = try? u.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]), v.isDirectory != true {
                total += Int64(v.fileSize ?? 0)
            }
        }
        return total
    }

    /// "Name (2).ext", falls "Name.ext" schon existiert.
    static func uniqueURL(_ url: URL) -> URL {
        guard exists(url) else { return url }
        let dir = url.deletingLastPathComponent()
        let name = url.lastPathComponent
        let ext = (name as NSString).pathExtension
        let base = ext.isEmpty ? name : (name as NSString).deletingPathExtension
        var n = 2
        while true {
            let candidate = ext.isEmpty ? "\(base) (\(n))" : "\(base) (\(n)).\(ext)"
            let u = dir.appendingPathComponent(candidate)
            if !exists(u) { return u }
            n += 1
        }
    }

    static func validName(_ name: String) -> String? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty || n == "." || n == ".." { return nil }
        if n.contains("/") || n.contains(":") { return nil }
        return n
    }

    /// Lesen mit Dateikoordination (laedt iCloud-Dateien bei Bedarf herunter).
    static func coordinatedRead<T>(_ url: URL, _ body: (URL) throws -> T) throws -> T {
        var coordError: NSError?
        var result: Result<T, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [.withoutChanges], error: &coordError) { u in
            result = Result { try body(u) }
        }
        if let e = coordError { throw e }
        guard let r = result else { throw OpError("Zugriff auf „\(url.lastPathComponent)“ nicht möglich.") }
        return try r.get()
    }

    static func coordinatedWrite<T>(_ url: URL, options: NSFileCoordinator.WritingOptions = [.forReplacing], _ body: (URL) throws -> T) throws -> T {
        var coordError: NSError?
        var result: Result<T, Error>?
        NSFileCoordinator().coordinate(writingItemAt: url, options: options, error: &coordError) { u in
            result = Result { try body(u) }
        }
        if let e = coordError { throw e }
        guard let r = result else { throw OpError("Schreiben von „\(url.lastPathComponent)“ nicht möglich.") }
        return try r.get()
    }
}

/// Kopieren / Verschieben im Hintergrund.
final class TransferJob: @unchecked Sendable {
    enum Op { case copy, move }

    let op: Op
    let sources: [URL]
    let targetDir: URL
    /// Neuer Name, nur bei genau einer Quelle ("Kopieren als").
    let renameTo: String?
    var policy: ConflictPolicy
    private(set) var cancelled = false
    private let fm = FileManager()
    private var totalBytes: Int64 = 0
    private var doneBytes: Int64 = 0
    private var lastReport = Date.distantPast
    private(set) var finishedCount = 0
    private(set) var skippedCount = 0

    var report: (Progress) -> Void = { _ in }
    var ask: (String) async -> ConflictChoice = { _ in .cancel }

    init(op: Op, sources: [URL], targetDir: URL, renameTo: String?, policy: ConflictPolicy) {
        self.op = op
        self.sources = sources
        self.targetDir = targetDir
        self.renameTo = renameTo
        self.policy = policy
    }

    func cancel() { cancelled = true }

    private var title: String { op == .copy ? "Kopieren" : "Verschieben" }

    private func checkCancel() throws {
        if cancelled { throw CancellationError() }
    }

    func run() async throws {
        let target = targetDir.standardizedFileURL
        for s in sources {
            let sp = s.standardizedFileURL.path
            if target.path == sp || target.path.hasPrefix(sp + "/") {
                throw OpError("„\(s.lastPathComponent)“ kann nicht in sich selbst \(op == .copy ? "kopiert" : "verschoben") werden.")
            }
        }
        if !FileOps.exists(targetDir) {
            try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
        }
        report(Progress(title: title, detail: "Größe wird berechnet …", fraction: nil))
        totalBytes = max(1, sources.reduce(Int64(0)) { $0 + FileOps.size(of: $1, cancelled: { self.cancelled }) })
        for s in sources {
            try checkCancel()
            let name = (sources.count == 1 ? renameTo : nil) ?? s.lastPathComponent
            var dst = targetDir.appendingPathComponent(name)
            if dst.standardizedFileURL.path == s.standardizedFileURL.path {
                if op == .move { continue }
                dst = FileOps.uniqueURL(dst)
            }
            try await transfer(s, to: dst)
            finishedCount += 1
        }
        report(Progress(title: title, detail: "Fertig", fraction: 1))
    }

    private func resolveConflict(_ dst: URL) async throws -> ConflictPolicy {
        switch policy {
        case .overwrite, .skip, .rename:
            return policy
        case .ask:
            let choice = await ask(dst.lastPathComponent)
            switch choice {
            case .overwrite: return .overwrite
            case .overwriteAll: policy = .overwrite; return .overwrite
            case .skip: return .skip
            case .skipAll: policy = .skip; return .skip
            case .rename: return .rename
            case .cancel: cancelled = true; throw CancellationError()
            }
        }
    }

    private func transfer(_ src: URL, to dstIn: URL) async throws {
        try checkCancel()
        var dst = dstIn
        let srcIsDir = FileOps.isDir(src)
        if FileOps.exists(dst) {
            if srcIsDir && FileOps.isDir(dst) {
                // Ordner zusammenfuehren
                let children = try fm.contentsOfDirectory(at: src, includingPropertiesForKeys: nil)
                for child in children {
                    try await transfer(child, to: dst.appendingPathComponent(child.lastPathComponent))
                }
                if op == .move, (try? fm.contentsOfDirectory(atPath: src.path))?.isEmpty == true {
                    try? fm.removeItem(at: src)
                }
                return
            }
            switch try await resolveConflict(dst) {
            case .skip:
                skippedCount += 1
                doneBytes += FileOps.size(of: src)
                return
            case .rename:
                dst = FileOps.uniqueURL(dst)
            case .overwrite, .ask:
                try FileOps.coordinatedWrite(dst, options: [.forDeleting]) { u in try fm.removeItem(at: u) }
            }
        }
        if op == .move {
            let bytes = FileOps.size(of: src)
            let moved: Bool = (try? FileOps.coordinatedWrite(src, options: [.forMoving]) { u in
                try fm.moveItem(at: u, to: dst)
                return true
            }) ?? false
            if moved {
                doneBytes += bytes
                tick(src.lastPathComponent, force: true)
                return
            }
        }
        try FileOps.coordinatedRead(src) { readURL in
            try copyTree(readURL, to: dst)
        }
        if op == .move {
            try FileOps.coordinatedWrite(src, options: [.forDeleting]) { u in try fm.removeItem(at: u) }
        }
    }

    private func copyTree(_ src: URL, to dst: URL) throws {
        try checkCancel()
        if FileOps.isDir(src) {
            try fm.createDirectory(at: dst, withIntermediateDirectories: true)
            for child in try fm.contentsOfDirectory(at: src, includingPropertiesForKeys: nil) {
                try copyTree(child, to: dst.appendingPathComponent(child.lastPathComponent))
            }
            return
        }
        try copyFile(src, to: dst)
    }

    private func copyFile(_ src: URL, to dst: URL) throws {
        let input = try FileHandle(forReadingFrom: src)
        defer { try? input.close() }
        guard fm.createFile(atPath: dst.path, contents: nil) else {
            throw OpError("„\(dst.lastPathComponent)“ kann im Ziel nicht angelegt werden.")
        }
        let output = try FileHandle(forWritingTo: dst)
        var ok = false
        defer {
            try? output.close()
            if !ok { try? fm.removeItem(at: dst) }
        }
        let chunk = 4 * 1024 * 1024
        while true {
            try checkCancel()
            let data = try autoreleasepool { try input.read(upToCount: chunk) } ?? Data()
            if data.isEmpty { break }
            try output.write(contentsOf: data)
            doneBytes += Int64(data.count)
            tick(src.lastPathComponent)
        }
        ok = true
        if let attrs = try? fm.attributesOfItem(atPath: src.path), let date = attrs[.modificationDate] as? Date {
            try? output.close()
            try? fm.setAttributes([.modificationDate: date], ofItemAtPath: dst.path)
        }
    }

    private func tick(_ name: String, force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastReport) > 0.12 else { return }
        lastReport = now
        let f = min(1, Double(doneBytes) / Double(max(totalBytes, 1)))
        report(Progress(title: title, detail: "\(name)  –  \(Format.human(doneBytes)) von \(Format.human(totalBytes))", fraction: f))
    }
}

/// Loeschen im Hintergrund.
final class DeleteJob: @unchecked Sendable {
    let urls: [URL]
    private(set) var cancelled = false
    var report: (Progress) -> Void = { _ in }

    init(urls: [URL]) { self.urls = urls }
    func cancel() { cancelled = true }

    func run() throws {
        let fm = FileManager()
        for (i, u) in urls.enumerated() {
            if cancelled { throw CancellationError() }
            report(Progress(title: "Löschen", detail: u.lastPathComponent, fraction: Double(i) / Double(max(urls.count, 1))))
            try FileOps.coordinatedWrite(u, options: [.forDeleting]) { url in try fm.removeItem(at: url) }
        }
    }
}
