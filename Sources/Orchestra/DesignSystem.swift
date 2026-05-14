import AppKit

enum DS {
    enum Metrics {
        static let unit: CGFloat = 4
        static let sidebarWidth: CGFloat = 256
        static let sidebarHeaderHeight: CGFloat = 64
        static let sidebarInset: CGFloat = 14
        static let rowHeight: CGFloat = 30
        static let rowCornerRadius: CGFloat = 7
        static let paneCornerRadius: CGFloat = 8
        static let paneChromeHeight: CGFloat = 28
        static let dividerSize: CGFloat = 8
        static let tileInset: CGFloat = 7
    }

    enum Palette {
        static var sidebarDivider: NSColor {
            NSColor(name: "sidebarDivider") { appearance in
                appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
                    ? NSColor.white.withAlphaComponent(0.06)
                    : NSColor.black.withAlphaComponent(0.08)
            }
        }

        static var tileGutter: NSColor {
            NSColor(name: "tileGutter") { appearance in
                appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
                    ? NSColor(white: 0.06, alpha: 1.0)
                    : NSColor(white: 0.92, alpha: 1.0)
            }
        }

        static var paneTitleBarFill: NSColor {
            NSColor(name: "paneTitleBarFill") { appearance in
                appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
                    ? NSColor(white: 0.12, alpha: 1.0)
                    : NSColor(white: 0.96, alpha: 1.0)
            }
        }

        static var paneTitleBarBorder: NSColor {
            NSColor(name: "paneTitleBarBorder") { appearance in
                appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
                    ? NSColor.white.withAlphaComponent(0.07)
                    : NSColor.black.withAlphaComponent(0.08)
            }
        }

        static var paneInactiveBorder: NSColor {
            NSColor(name: "paneInactiveBorder") { appearance in
                appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
                    ? NSColor.white.withAlphaComponent(0.08)
                    : NSColor.black.withAlphaComponent(0.10)
            }
        }

        static var rowHover: NSColor {
            NSColor.labelColor.withAlphaComponent(0.06)
        }

        static var rowActiveFill: NSColor {
            NSColor.controlAccentColor.withAlphaComponent(0.18)
        }

        static var rowActiveText: NSColor {
            NSColor.labelColor
        }

        static var badgeFill: NSColor {
            NSColor.labelColor.withAlphaComponent(0.08)
        }

        static var badgeActiveFill: NSColor {
            NSColor.controlAccentColor.withAlphaComponent(0.22)
        }

        static var badgeText: NSColor {
            NSColor.secondaryLabelColor
        }

        static var badgeActiveText: NSColor {
            NSColor.labelColor
        }
    }

    enum Typography {
        static func eyebrow() -> NSFont {
            roundedFont(ofSize: 10, weight: .semibold)
        }

        static func sidebarTitle() -> NSFont {
            roundedFont(ofSize: 22, weight: .bold)
        }

        static func row(weight: NSFont.Weight = .regular) -> NSFont {
            roundedFont(ofSize: 13, weight: weight)
        }

        static func badge() -> NSFont {
            NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        }

        static func paneTitle() -> NSFont {
            roundedFont(ofSize: 11, weight: .medium)
        }

        static func paneTitleMono() -> NSFont {
            NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        }

        static func emptyStatePrimary() -> NSFont {
            roundedFont(ofSize: 16, weight: .medium)
        }

        static func emptyStateSecondary() -> NSFont {
            roundedFont(ofSize: 12, weight: .regular)
        }

        static func dialogLabel() -> NSFont {
            roundedFont(ofSize: 12, weight: .semibold)
        }

        static func dialogValue() -> NSFont {
            NSFont.systemFont(ofSize: 13, weight: .regular)
        }

        static func dialogMono() -> NSFont {
            NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        }

        private static func roundedFont(ofSize size: CGFloat, weight: NSFont.Weight) -> NSFont {
            let base = NSFont.systemFont(ofSize: size, weight: weight)
            guard let descriptor = base.fontDescriptor.withDesign(.rounded),
                  let rounded = NSFont(descriptor: descriptor, size: size) else {
                return base
            }
            return rounded
        }
    }
}

extension NSAttributedString {
    static func tracked(_ string: String, font: NSFont, color: NSColor, tracking: CGFloat) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [
            .font: font,
            .foregroundColor: color,
            .kern: tracking
        ])
    }
}
