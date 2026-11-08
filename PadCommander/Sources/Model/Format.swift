import Foundation

enum Format {
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd.MM.yyyy HH:mm"
        return f
    }()

    static let longDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateStyle = .full
        f.timeStyle = .medium
        return f
    }()

    static let grouped: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        return f
    }()

    static func date(_ d: Date?) -> String {
        guard let d else { return "" }
        return dateFormatter.string(from: d)
    }

    /// 1.234.567 (klassisch, wie im alten Commander)
    static func bytes(_ n: Int64) -> String {
        grouped.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    /// 1,2 MB
    static func human(_ n: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        return f.string(fromByteCount: n)
    }

    /// "k" wie in der Statuszeile des Commanders.
    static func kilo(_ n: Int64) -> String {
        let k = (n + 1023) / 1024
        return bytes(k) + " k"
    }

    static func count(_ n: Int, _ one: String, _ many: String) -> String {
        "\(n) " + (n == 1 ? one : many)
    }
}
