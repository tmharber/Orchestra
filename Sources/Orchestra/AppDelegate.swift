import AppKit

@main
struct OrchestraApplication {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenuBuilder.build()
        NSApp.applicationIconImage = AppIconLoader.load()

        let controller = MainWindowController()
        mainWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

enum AppIconLoader {
    static func load() -> NSImage? {
        guard
            let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
            let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        image.size = NSSize(width: 512, height: 512)
        return image
    }
}

enum MainMenuBuilder {
    static func build() -> NSMenu {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit Orchestra",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(
            withTitle: "New Terminal",
            action: #selector(MainWindowController.enterSplitMode(_:)),
            keyEquivalent: "t"
        )
        fileMenu.addItem(
            withTitle: "Close Pane",
            action: #selector(MainWindowController.closeActivePane(_:)),
            keyEquivalent: "w"
        )
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(
            withTitle: "Copy",
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        editMenu.addItem(
            withTitle: "Paste",
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        )
        editMenu.addItem(.separator())
        editMenu.addItem(
            withTitle: "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(
            withTitle: "Split Right",
            action: #selector(MainWindowController.splitActivePaneRight(_:)),
            keyEquivalent: "d"
        )

        let splitDown = NSMenuItem(
            title: "Split Down",
            action: #selector(MainWindowController.splitActivePaneDown(_:)),
            keyEquivalent: "d"
        )
        splitDown.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(splitDown)
        viewMenu.addItem(.separator())
        let allowMouseReporting = NSMenuItem(
            title: "Allow Terminal Mouse Reporting",
            action: #selector(MainWindowController.toggleActiveTerminalMouseReporting(_:)),
            keyEquivalent: "o"
        )
        allowMouseReporting.keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(allowMouseReporting)
        viewMenu.addItem(.separator())
        viewMenu.addItem(
            withTitle: "Toggle Left Sidebar",
            action: #selector(MainWindowController.toggleLeftSidebar(_:)),
            keyEquivalent: "["
        )
        viewMenu.addItem(
            withTitle: "Toggle Right Sidebar",
            action: #selector(MainWindowController.toggleRightSidebar(_:)),
            keyEquivalent: "]"
        )
        viewItem.submenu = viewMenu
        mainMenu.addItem(viewItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(
            withTitle: "Minimize",
            action: #selector(NSWindow.miniaturize(_:)),
            keyEquivalent: "m"
        )
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)

        return mainMenu
    }
}
