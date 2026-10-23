//
//  Localization.swift
//  Pocket Ledger
//
//  Resolves app strings from a specific language bundle so default category
//  names follow the in-app language choice (which may differ from the device
//  language). SwiftUI `Text` already uses the environment locale; this mirror
//  exists for the non-SwiftUI lookup in `Category.displayName`.
//

import Foundation

enum Localization {
    /// Current in-app language code (BCP-47), kept in sync with AppSettings by
    /// the app root.
    static var languageCode = "en"

    /// Looks up `key` in the selected language's bundle, falling back to the
    /// main bundle. Returns `key` itself if there is no translation.
    static func string(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let value = NSLocalizedString(key, bundle: bundle, value: key, comment: "")
            if value != key { return value }
        }
        let main = NSLocalizedString(key, value: key, comment: "")
        return main
    }
}

enum AppLanguages {
    /// Supported in-app languages: code + its own native display name.
    static let supported: [(code: String, name: String)] = [
        ("en", "English"),
        ("my", "မြန်မာ"),
    ]

    static func name(for code: String) -> String {
        supported.first { $0.code == code }?.name ?? code
    }
}
