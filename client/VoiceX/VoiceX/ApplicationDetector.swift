import AppKit

struct ApplicationDetector {
    static func getActiveApplicationBundleIdentifier() -> String? {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}