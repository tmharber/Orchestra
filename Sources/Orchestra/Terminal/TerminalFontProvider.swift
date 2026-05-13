import AppKit

enum TerminalFontProvider {
    static func preferredFont(defaultSize: CGFloat = 13) -> NSFont {
        environmentFont(defaultSize: defaultSize)
            ?? iTermFont(defaultSize: defaultSize)
            ?? installedPowerlineCapableFont(defaultSize: defaultSize)
            ?? .monospacedSystemFont(ofSize: defaultSize, weight: .regular)
    }

    private static func environmentFont(defaultSize: CGFloat) -> NSFont? {
        let environment = ProcessInfo.processInfo.environment
        guard let name = environment["ORCHESTRA_TERMINAL_FONT"], !name.isEmpty else {
            return nil
        }

        let size = CGFloat(Double(environment["ORCHESTRA_TERMINAL_FONT_SIZE"] ?? "") ?? Double(defaultSize))
        return font(named: name, size: size)
    }

    private static func iTermFont(defaultSize: CGFloat) -> NSFont? {
        guard
            let domain = UserDefaults.standard.persistentDomain(forName: "com.googlecode.iterm2"),
            let profiles = domain["New Bookmarks"] as? [[String: Any]]
        else {
            return nil
        }

        let defaultGuid = domain["Default Bookmark Guid"] as? String
        let profile = profiles.first { $0["Guid"] as? String == defaultGuid }
            ?? profiles.first { $0["Name"] as? String == "Default" }
            ?? profiles.first

        guard let profile else {
            return nil
        }

        let keys = ["Normal Font", "Non Ascii Font"]
        for key in keys {
            guard let fontSpec = profile[key] as? String else {
                continue
            }

            if let font = font(fromITermSpec: fontSpec, defaultSize: defaultSize) {
                return font
            }
        }

        return nil
    }

    private static func font(fromITermSpec spec: String, defaultSize: CGFloat) -> NSFont? {
        let parts = spec.split(separator: " ")
        guard !parts.isEmpty else {
            return nil
        }

        let parsedSize = parts.last.flatMap { Double($0) }
        let size = CGFloat(parsedSize ?? Double(defaultSize))
        let nameParts = parsedSize == nil ? parts : parts.dropLast()
        let name = nameParts.joined(separator: " ")

        return font(named: name, size: size)
    }

    private static func installedPowerlineCapableFont(defaultSize: CGFloat) -> NSFont? {
        let preferredNames = [
            "MesloLGS NF Regular",
            "MesloLGS-NF-Regular",
            "Hack Nerd Font Mono Regular",
            "HackNerdFontMono-Regular",
            "JetBrainsMono Nerd Font Mono Regular",
            "JetBrainsMonoNerdFontMono-Regular",
            "FiraCode Nerd Font Mono Regular",
            "FiraCodeNerdFontMono-Regular",
            "CaskaydiaCove Nerd Font Mono Regular",
            "CaskaydiaCoveNerdFontMono-Regular",
            "SauceCodePro Nerd Font Mono Regular",
            "SauceCodeProNerdFontMono-Regular"
        ]

        for name in preferredNames {
            if let font = font(named: name, size: defaultSize) {
                return font
            }
        }

        return NSFontManager.shared.availableFonts
            .first { name in
                let lowercased = name.lowercased()
                return lowercased.contains("nerdfontmono")
                    || lowercased.contains("nerd-font-mono")
                    || lowercased.contains("powerline")
                    || lowercased.contains("meslolgs")
            }
            .flatMap { font(named: $0, size: defaultSize) }
    }

    private static func font(named name: String, size: CGFloat) -> NSFont? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let font = NSFont(name: trimmed, size: size) {
            return font
        }

        let displayName = trimmed.replacingOccurrences(of: "-", with: " ")
        return NSFont(name: displayName, size: size)
    }
}
