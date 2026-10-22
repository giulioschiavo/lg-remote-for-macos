import Foundation

func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: .main, comment: "")
}
func LF(_ key: String, _ argument: String) -> String {
    String(format: L(key), locale: Locale.current, argument)
}
