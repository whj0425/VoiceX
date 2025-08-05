import Foundation
import ApplicationServices
import Carbon

@MainActor
class TextInjectionManager: ObservableObject {
    // 单例模式
    public static let shared = TextInjectionManager()

    @Published var isInjectionEnabled = false
    @Published var lastInjectedText = ""
    
    private var hasAccessibilityPermission = false
    
    // 私有化构造函数以强制使用单例
    private init() {
        checkAccessibilityPermission()
    }
    
    func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
        
        if !hasAccessibilityPermission {
            // 请求辅助功能权限
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            print("⚠️ 需要辅助功能权限，请在系统偏好设置中启用")
        } else {
            print("✅ 辅助功能权限已获得")
        }
    }
    
    func inject(text: String) {
        print("🔍 调试 - 注入检查:")
        print("   - isInjectionEnabled: \(isInjectionEnabled)")
        print("   - hasAccessibilityPermission: \(hasAccessibilityPermission)")
        print("   - text.isEmpty: \(text.isEmpty)")
        print("   - text: '\(text)'")
        
        guard isInjectionEnabled, hasAccessibilityPermission, !text.isEmpty else {
            print("⚠️ 文本注入未启用或无权限")
            return
        }
        
        print("🚀 开始注入文本: \(text)")
        // 使用CGEvent模拟键盘输入
        injectTextUsingCGEvent(text)
        lastInjectedText = text
        print("✅ 已注入文本: \(text)")
    }
    
    /// 新增的替换方法
    public func replace(oldText: String, with newText: String) {
        // 如果新旧文本相同，则不执行任何操作以提高效率
        guard oldText != newText else { return }

        let charactersToDelete = oldText.count

        print("🔄 替换文本: '\(oldText)' -> '\(newText)' (删除 \(charactersToDelete) 个字符)")

        if charactersToDelete > 0 {
            delete(characterCount: charactersToDelete)
        }
        inject(text: newText)
    }

    /// 新增的删除方法
    private func delete(characterCount: Int) {
        guard characterCount > 0 else { return }
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        // macOS中退格键的虚拟键码是51
        let keyCode = CGKeyCode(51)

        for _ in 0..<characterCount {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

            let loc = CGEventTapLocation.cghidEventTap
            keyDown?.post(tap: loc)
            keyUp?.post(tap: loc)

            // 在两次按键之间增加一个微小的延迟，以确保应用程序能够处理它
            usleep(1000) // 1ms
        }
        print("🗑️ 已删除 \(characterCount) 个字符")
    }

    private func injectTextUsingCGEvent(_ text: String) {
        // 使用更简单的方法：创建文本输入事件
        let source = CGEventSource(stateID: .combinedSessionState)
        
        for character in text {
            // 将字符转换为UTF-16编码用于macOS
            let utf16Array = Array(String(character).utf16)
            
            // 创建Unicode键盘事件
            if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
               !utf16Array.isEmpty {
                
                // 设置Unicode字符 (UniChar是UInt16类型)
                let unicodeString = utf16Array + [0] // null-terminated
                event.keyboardSetUnicodeString(stringLength: utf16Array.count, unicodeString: unicodeString)
                event.post(tap: .cghidEventTap)
            }
            
            // 短暂延迟以确保字符正确输入
            usleep(2000) // 2ms
        }
    }
    
    func toggleInjection() {
        print("🔄 切换注入状态 - 当前权限: \(hasAccessibilityPermission)")
        
        if !hasAccessibilityPermission {
            print("❌ 无辅助功能权限，重新检查...")
            checkAccessibilityPermission()
            return
        }
        
        isInjectionEnabled.toggle()
        print(isInjectionEnabled ? "🔓 文本注入已启用" : "🔒 文本注入已禁用")
    }
    
    func refreshPermissionStatus() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }
    
    var permissionStatus: String {
        if hasAccessibilityPermission {
            return isInjectionEnabled ? "注入已启用" : "注入已禁用"
        } else {
            return "需要辅助功能权限"
        }
    }
}