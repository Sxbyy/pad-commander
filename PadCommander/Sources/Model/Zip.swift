import Foundation
import Compression

enum CRC32 {
    static let table: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func update(_ crc: UInt32, _ data: Data) -> UInt32 {
        var c = ~crc
        table.withUnsafeBufferPointer { t in
            data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) in
                for b in buf { c = t[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
            }
        }
        return ~c
    }
}

private func le16(_ v: UInt16) -> [UInt8] { [UInt8(v & 0xFF), UInt8(v >> 8)] }
private func le32(_ v: UInt32) -> [UInt8] {
    [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8(v >> 24)]
}
private func rd16(_ b: [UInt8], _ o: Int) -> UInt16 { UInt16(b[o]) | (UInt16(b[o + 1]) << 8) }
private func rd32(_ b: [UInt8], _ o: Int) -> UInt32 {
    UInt32(b[o]) | (UInt32(b[o + 1]) << 8) | (UInt32(b[o + 2]) << 16) | (UInt32(b[o + 3]) << 24)
}

enum DOSTime {
    static func encode(_ date: Date) -> (time: UInt16, date: UInt16) {
        let c = Calendar(identifier: .gregorian).dateComponents(in: .current, from: date)
        let y = max(1980, min(2107, c.year ?? 1980))
        let t = ((c.hour ?? 0) << 11) | ((c.minute ?? 0) << 5) | ((c.second ?? 0) / 2)
        let d = ((y - 1980) << 9) | ((c.month ?? 1) << 5) | (c.day ?? 1)
        return (UInt16(truncatingIfNeeded: t), UInt16(truncatingIfNeeded: d))
    }

    static func decode(time t: UInt16, date d: UInt16) -> Date? {
        var c = DateComponents()
        c.year = Int(d >> 9) + 1980
        c.month = Int((d >> 5) & 0xF)
        c.day = Int(d & 0x1F)
        c.hour = Int(t >> 11)
        c.minute = Int((t >> 5) & 0x3F)
        c.second = Int(t & 0x1F) * 2
        return Calendar(identifier: .gregorian).date(from: c)
    }
}

struct ZipEntry {
    var name: String
    var method: UInt16
    var flags: UInt16
    var crc: UInt32
    var compressedSize: UInt32
    var size: UInt32
    var localOffset: UInt32
    var modified: Date?
    var isDirectory: Bool { name.hasSuffix("/") }
}

/// Entpackt ein ZIP-Archiv (Speichern und Deflate, ohne Zip64/Verschluesselung).
final class UnzipJob: @unchecked Sendable {
    let archive: URL
    let target: URL
    private(set) var cancelled = false
    var report: (OpProgress) -> Void = { _ in }

    init(archive: URL, target: URL) {
        self.archive = archive
        self.target = target
    }

    func cancel() { cancelled = true }

    static func cp437(_ bytes: [UInt8]) -> String {
        let enc = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosLatinUS.rawValue)))
        return String(bytes: bytes, encoding: enc) ?? String(decoding: bytes, as: UTF8.self)
    }

    func readEntries(_ h: FileHandle) throws -> [ZipEntry] {
        let fileSize = try h.seekToEnd()
        let tailLen = UInt64(min(fileSize, 65_557))
        try h.seek(toOffset: fileSize - tailLen)
        let tail = [UInt8](try h.read(upToCount: Int(tailLen)) ?? Data())
        var eocd = -1
        var i = tail.count - 22
        while i >= 0 {
            if tail[i] == 0x50, tail[i + 1] == 0x4B, tail[i + 2] == 0x05, tail[i + 3] == 0x06 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw OpError("Das ist kein gültiges ZIP-Archiv.") }
        let count = Int(rd16(tail, eocd + 10))
        let cdSize = rd32(tail, eocd + 12)
        let cdOffset = rd32(tail, eocd + 16)
        if cdOffset == 0xFFFF_FFFF || count == 0xFFFF {
            throw OpError("Große ZIP64-Archive werden noch nicht unterstützt.")
        }
        try h.seek(toOffset: UInt64(cdOffset))
        let cd = [UInt8](try h.read(upToCount: Int(cdSize)) ?? Data())
        var entries: [ZipEntry] = []
        var p = 0
        for _ in 0..<count {
            guard p + 46 <= cd.count, rd32(cd, p) == 0x0201_4B50 else { throw OpError("Das Inhaltsverzeichnis des Archivs ist beschädigt.") }
            let flags = rd16(cd, p + 8)
            let method = rd16(cd, p + 10)
            let time = rd16(cd, p + 12)
            let date = rd16(cd, p + 14)
            let crc = rd32(cd, p + 16)
            let csize = rd32(cd, p + 20)
            let usize = rd32(cd, p + 24)
            let nameLen = Int(rd16(cd, p + 28))
            let extraLen = Int(rd16(cd, p + 30))
            let commentLen = Int(rd16(cd, p + 32))
            let offset = rd32(cd, p + 42)
            guard p + 46 + nameLen <= cd.count else { throw OpError("Das Archiv ist beschädigt.") }
            let nameBytes = Array(cd[(p + 46)..<(p + 46 + nameLen)])
            let name = (flags & 0x800) != 0 ? String(decoding: nameBytes, as: UTF8.self) : Self.cp437(nameBytes)
            entries.append(ZipEntry(name: name.replacingOccurrences(of: "\\", with: "/"), method: method, flags: flags, crc: crc,
                                    compressedSize: csize, size: usize, localOffset: offset,
                                    modified: DOSTime.decode(time: time, date: date)))
            p += 46 + nameLen + extraLen + commentLen
        }
        return entries
    }

    func run() throws {
        let fm = FileManager()
        let h = try FileHandle(forReadingFrom: archive)
        defer { try? h.close() }
        let entries = try readEntries(h)
        let total = max(1, entries.reduce(Int64(0)) { $0 + Int64($1.size) })
        var done: Int64 = 0
        var last = Date.distantPast
        try fm.createDirectory(at: target, withIntermediateDirectories: true)
        for e in entries {
            if cancelled { throw CancellationError() }
            let parts = e.name.split(separator: "/").map(String.init).filter { !$0.isEmpty && $0 != "." }
            if parts.isEmpty || parts.contains("..") { continue }
            if parts.first == "__MACOSX" { continue }
            let dst = parts.reduce(target) { $0.appendingPathComponent($1) }
            if e.isDirectory {
                try fm.createDirectory(at: dst, withIntermediateDirectories: true)
                continue
            }
            if (e.flags & 1) != 0 { throw OpError("„\(e.name)“ ist verschlüsselt – das wird nicht unterstützt.") }
            guard e.method == 0 || e.method == 8 else { throw OpError("„\(e.name)“ nutzt ein unbekanntes Packverfahren (\(e.method)).") }
            try fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
            try h.seek(toOffset: UInt64(e.localOffset))
            let lh = [UInt8](try h.read(upToCount: 30) ?? Data())
            guard lh.count == 30, rd32(lh, 0) == 0x0403_4B50 else { throw OpError("Das Archiv ist beschädigt (\(e.name)).") }
            let dataStart = UInt64(e.localOffset) + 30 + UInt64(rd16(lh, 26)) + UInt64(rd16(lh, 28))
            try h.seek(toOffset: dataStart)
            let targetName = dst.lastPathComponent
            let out = FileOps.uniqueURLIfNeeded(dst)
            guard fm.createFile(atPath: out.path, contents: nil) else { throw OpError("„\(targetName)“ kann nicht angelegt werden.") }
            let oh = try FileHandle(forWritingTo: out)
            var crc: UInt32 = 0
            var remaining = Int(e.compressedSize)
            do {
                let sink: (Data) throws -> Void = { d in
                    crc = CRC32.update(crc, d)
                    try oh.write(contentsOf: d)
                    done += Int64(d.count)
                }
                var filter: OutputFilter?
                if e.method == 8 {
                    filter = try OutputFilter(.decompress, using: .zlib) { (d: Data?) in
                        if let d { try sink(d) }
                    }
                }
                while remaining > 0 {
                    if cancelled { throw CancellationError() }
                    let chunk = try h.read(upToCount: min(remaining, 1 << 20)) ?? Data()
                    if chunk.isEmpty { break }
                    remaining -= chunk.count
                    if let filter { try filter.write(chunk) } else { try sink(chunk) }
                    if Date().timeIntervalSince(last) > 0.12 {
                        last = Date()
                        report(OpProgress(title: "Entpacken", detail: e.name, fraction: Double(done) / Double(total)))
                    }
                }
                try filter?.finalize()
                try oh.close()
            } catch {
                try? oh.close()
                try? fm.removeItem(at: out)
                throw error
            }
            if crc != e.crc { throw OpError("Prüfsumme von „\(e.name)“ stimmt nicht – Archiv beschädigt.") }
            if let m = e.modified { try? fm.setAttributes([.modificationDate: m], ofItemAtPath: out.path) }
        }
    }
}

/// Packt Dateien und Ordner in ein ZIP-Archiv (Deflate, bereits gepackte Formate werden nur gespeichert).
final class ZipJob: @unchecked Sendable {
    let sources: [URL]
    let output: URL
    private(set) var cancelled = false
    var report: (OpProgress) -> Void = { _ in }
    private static let storeOnly: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "mp4", "mov", "m4v",
                                                 "mp3", "m4a", "aac", "zip", "gz", "7z", "rar", "xz", "bz2", "docx",
                                                 "xlsx", "pptx", "pages", "numbers", "key", "ipa", "apk"]

    init(sources: [URL], output: URL) {
        self.sources = sources
        self.output = output
    }

    func cancel() { cancelled = true }

    private struct Item { let url: URL; let name: String; let isDir: Bool }

    private func collect() -> [Item] {
        var list: [Item] = []
        func walk(_ url: URL, _ name: String) {
            if FileOps.isDir(url) {
                list.append(Item(url: url, name: name + "/", isDir: true))
                let children = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
                for c in children.sorted() where c != ".DS_Store" {
                    walk(url.appendingPathComponent(c), name + "/" + c)
                }
            } else {
                list.append(Item(url: url, name: name, isDir: false))
            }
        }
        for s in sources { walk(s, s.lastPathComponent) }
        return list
    }

    func run() throws {
        let fm = FileManager()
        let items = collect()
        if items.count > 0xFFFF { throw OpError("Mehr als 65.535 Einträge lassen sich (noch) nicht in ein Archiv packen.") }
        let total = max(1, sources.reduce(Int64(0)) { $0 + FileOps.size(of: $1) })
        if total > Int64(UInt32.max) - 1 { throw OpError("Mehr als 4 GB lassen sich (noch) nicht packen.") }
        guard fm.createFile(atPath: output.path, contents: nil) else { throw OpError("Das Archiv kann nicht angelegt werden.") }
        let out = try FileHandle(forWritingTo: output)
        var ok = false
        defer {
            try? out.close()
            if !ok { try? fm.removeItem(at: output) }
        }
        var central = Data()
        var offset: UInt64 = 0
        var done: Int64 = 0
        var last = Date.distantPast
        for item in items {
            if cancelled { throw CancellationError() }
            let nameData = Data(item.name.utf8)
            let mdate = (try? fm.attributesOfItem(atPath: item.url.path))?[.modificationDate] as? Date ?? Date()
            let (dt, dd) = DOSTime.encode(mdate)
            let ext = (item.name as NSString).pathExtension.lowercased()
            let method: UInt16 = item.isDir || Self.storeOnly.contains(ext) ? 0 : 8
            let headerOffset = offset
            var header = Data()
            header.append(contentsOf: le32(0x0403_4B50))
            header.append(contentsOf: le16(20))
            header.append(contentsOf: le16(0x800))
            header.append(contentsOf: le16(method))
            header.append(contentsOf: le16(dt))
            header.append(contentsOf: le16(dd))
            header.append(contentsOf: le32(0))
            header.append(contentsOf: le32(0))
            header.append(contentsOf: le32(0))
            header.append(contentsOf: le16(UInt16(nameData.count)))
            header.append(contentsOf: le16(0))
            header.append(nameData)
            try out.write(contentsOf: header)
            offset += UInt64(header.count)
            var crc: UInt32 = 0
            var csize: UInt64 = 0
            var usize: UInt64 = 0
            if !item.isDir {
                let input = try FileHandle(forReadingFrom: item.url)
                defer { try? input.close() }
                var filter: OutputFilter?
                if method == 8 {
                    filter = try OutputFilter(.compress, using: .zlib) { (d: Data?) in
                        if let d { try out.write(contentsOf: d); csize += UInt64(d.count) }
                    }
                }
                while true {
                    if cancelled { throw CancellationError() }
                    let chunk = try autoreleasepool { try input.read(upToCount: 1 << 20) } ?? Data()
                    if chunk.isEmpty { break }
                    crc = CRC32.update(crc, chunk)
                    usize += UInt64(chunk.count)
                    if let filter { try filter.write(chunk) } else { try out.write(contentsOf: chunk); csize += UInt64(chunk.count) }
                    done += Int64(chunk.count)
                    if Date().timeIntervalSince(last) > 0.12 {
                        last = Date()
                        report(OpProgress(title: "Packen", detail: item.name, fraction: Double(done) / Double(total)))
                    }
                }
                try filter?.finalize()
                offset += csize
                if csize > UInt64(UInt32.max) || offset > UInt64(UInt32.max) { throw OpError("Das Archiv würde größer als 4 GB.") }
                // Pruefsumme und Groessen in den lokalen Kopf nachtragen
                try out.seek(toOffset: headerOffset + 14)
                var fix = Data()
                fix.append(contentsOf: le32(crc))
                fix.append(contentsOf: le32(UInt32(csize)))
                fix.append(contentsOf: le32(UInt32(usize)))
                try out.write(contentsOf: fix)
                try out.seek(toOffset: offset)
            }
            var c = Data()
            c.append(contentsOf: le32(0x0201_4B50))
            c.append(contentsOf: le16(0x031E))
            c.append(contentsOf: le16(20))
            c.append(contentsOf: le16(0x800))
            c.append(contentsOf: le16(method))
            c.append(contentsOf: le16(dt))
            c.append(contentsOf: le16(dd))
            c.append(contentsOf: le32(crc))
            c.append(contentsOf: le32(UInt32(csize)))
            c.append(contentsOf: le32(UInt32(usize)))
            c.append(contentsOf: le16(UInt16(nameData.count)))
            c.append(contentsOf: le16(0))
            c.append(contentsOf: le16(0))
            c.append(contentsOf: le16(0))
            c.append(contentsOf: le16(0))
            c.append(contentsOf: le32(item.isDir ? 0x41ED_0010 : 0x81A4_0000))
            c.append(contentsOf: le32(UInt32(headerOffset)))
            c.append(nameData)
            central.append(c)
        }
        let cdOffset = offset
        try out.write(contentsOf: central)
        var end = Data()
        end.append(contentsOf: le32(0x0605_4B50))
        end.append(contentsOf: le16(0))
        end.append(contentsOf: le16(0))
        end.append(contentsOf: le16(UInt16(min(items.count, 0xFFFF))))
        end.append(contentsOf: le16(UInt16(min(items.count, 0xFFFF))))
        end.append(contentsOf: le32(UInt32(central.count)))
        end.append(contentsOf: le32(UInt32(cdOffset)))
        end.append(contentsOf: le16(0))
        try out.write(contentsOf: end)
        ok = true
        report(OpProgress(title: "Packen", detail: "Fertig", fraction: 1))
    }
}

extension FileOps {
    static func uniqueURLIfNeeded(_ url: URL) -> URL { uniqueURL(url) }
}

extension AppModel {
    /// Entpackt in einen Unterordner (Name des Archivs) im angegebenen Fenster.
    func unpack(_ item: FileItem, into panel: PanelModel) {
        unpack([item], into: panel)
    }

    /// Mehrere Archive nacheinander entpacken, jedes in einen eigenen Unterordner.
    func unpack(_ items: [FileItem], into panel: PanelModel) {
        guard let dir = panel.dir, !items.isEmpty else { return }
        let jobs: [(URL, UnzipJob)] = items.map { item in
            (item.url, UnzipJob(archive: item.url, target: FileOps.uniqueURL(dir.appendingPathComponent(item.baseName, isDirectory: true))))
        }
        let select = jobs.last?.1.target.lastPathComponent
        run(title: "Entpacken", cancel: { jobs.forEach { $0.1.cancel() } }, select: select, in: panel) { [weak self] in
            for (archive, job) in jobs {
                job.report = { pr in Task { @MainActor in self?.busy?.progress = pr } }
                try await Task.detached {
                    try FileOps.coordinatedRead(archive) { _ in try job.run() }
                }.value
            }
        }
    }

    /// Alt+F9: markierte ZIP-Archive ins andere Fenster entpacken.
    func unpackSelection() {
        let zips = active.selection.filter { $0.isZip }
        guard !zips.isEmpty else { flash("Kein ZIP-Archiv ausgewählt"); return }
        unpack(zips, into: inactive)
        active.unmarkAll()
    }

    /// Alt+F5: Auswahl ins andere Fenster packen.
    func packSelection() {
        let p = active
        let items = p.selection
        guard !items.isEmpty, let targetDir = inactive.dir else { flash("Nichts ausgewählt"); return }
        let suggestion = (items.count == 1 ? items[0].baseName : (p.components.last ?? "Archiv")) + ".zip"
        let target = inactive
        dialog = .input(InputDialog(title: "Packen", prompt: "\(items.count) Element(e) packen nach \(target.location.name):\(target.relativePath) als:", text: suggestion, okTitle: "Packen", selectBaseName: true) { [weak self] text in
            guard let self, var name = FileOps.validName(text) else { return }
            if !name.lowercased().hasSuffix(".zip") { name += ".zip" }
            let out = FileOps.uniqueURL(targetDir.appendingPathComponent(name))
            let job = ZipJob(sources: items.map { $0.url }, output: out)
            self.run(title: "Packen", cancel: { job.cancel() }, select: out.lastPathComponent, in: target) { [weak self] in
                job.report = { pr in Task { @MainActor in self?.busy?.progress = pr } }
                try await Task.detached { try job.run() }.value
            }
            p.unmarkAll()
        })
    }
}
