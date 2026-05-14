import Foundation

enum DirectoryResolver {
    static func existingDirectory(_ directory: String, fallback: String) -> String {
        let expanded = expand(directory)
        let fallbackExpanded = expand(fallback)

        if isExistingDirectory(expanded) {
            return expanded
        }

        if isExistingDirectory(fallbackExpanded) {
            return fallbackExpanded
        }

        return NSHomeDirectory()
    }

    private static func expand(_ directory: String) -> String {
        let expanded = (directory as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardizedFileURL.path
    }

    private static func isExistingDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
