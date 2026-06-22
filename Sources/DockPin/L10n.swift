import Foundation

enum L10n {
    static func t(_ key: String, _ arguments: CVarArg...) -> String {
        let format = Bundle.main.localizedString(forKey: key, value: key, table: nil)
        guard !arguments.isEmpty else {
            return format
        }
        return String(format: format, locale: Locale.current, arguments: arguments)
    }
}
