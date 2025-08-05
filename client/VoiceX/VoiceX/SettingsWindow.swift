//
//  SettingsWindow.swift
//  VoiceX
//
//  Created for VoiceX Stage 5: Menu Bar Application
//

import SwiftUI
import AppKit

@MainActor
class SettingsWindowManager: ObservableObject {
    private var window: NSWindow?
    private var hostingController: NSHostingController<SettingsContentView>?
    private var windowDelegate: WindowDelegate?
    
    // 依赖注入
    private var voiceController: VoiceRecognitionController?
    private var textInjectionManager: TextInjectionManager?
    
    init() {}
    
    func setDependencies(
        voiceController: VoiceRecognitionController,
        textInjectionManager: TextInjectionManager
    ) {
        self.voiceController = voiceController
        self.textInjectionManager = textInjectionManager
    }
    
    func showWindow() {
        if window == nil {
            createWindow()
        }
        
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        
        // 激活应用程序（确保窗口显示在最前面）
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideWindow() {
        window?.orderOut(nil)
    }
    
    private func createWindow() {
        guard let voiceController = voiceController,
              let textInjectionManager = textInjectionManager else {
            print("⚠️ 设置窗口：依赖组件未初始化")
            return
        }
        
        // 创建设置内容视图
        let contentView = SettingsContentView(
            voiceController: voiceController,
            textInjectionManager: textInjectionManager
        )
        
        // 创建主持控制器
        hostingController = NSHostingController(rootView: contentView)
        
        // 创建窗口
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        guard let window = window, let hostingController = hostingController else { return }
        
        // 配置窗口
        window.title = "VoiceX 设置"
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("VoiceXSettingsWindow")
        
        // 设置最小尺寸
        window.minSize = NSSize(width: 450, height: 350)
        
        // 设置窗口关闭时的行为（隐藏而不是销毁）
        windowDelegate = WindowDelegate(manager: self)
        window.delegate = windowDelegate
    }
}

// MARK: - 窗口代理
private class WindowDelegate: NSObject, NSWindowDelegate {
    weak var manager: SettingsWindowManager?
    
    init(manager: SettingsWindowManager) {
        self.manager = manager
        super.init()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 隐藏窗口而不是关闭
        manager?.hideWindow()
        return false
    }
}

// MARK: - 设置内容视图
struct SettingsContentView: View {
    @ObservedObject var voiceController: VoiceRecognitionController
    @ObservedObject var textInjectionManager: TextInjectionManager
    
    var body: some View {
        VStack(spacing: 20) {
            headerView
            connectionStatusView
            controlButtonsView
            
            Spacer()
            
            // 菜单栏应用说明
            VStack(spacing: 8) {
                Text("💡 提示")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text("VoiceX 现在作为菜单栏应用运行")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("使用菜单栏开关即可快速启用/禁用语音识别")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
        .padding()
        .frame(minWidth: 450, minHeight: 300)
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "gearshape.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("VoiceX 设置")
                .font(.title2)
                .fontWeight(.semibold)
        }
    }
    
    private var connectionStatusView: some View {
        HStack {
            Circle()
                .fill(voiceController.connectionStatus == "已连接" ? .green : .red)
                .frame(width: 8, height: 8)
            Text("连接状态: \(voiceController.connectionStatus)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if !voiceController.hasAudioPermission {
                Text("需要麦克风权限")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    
    private var controlButtonsView: some View {
        HStack(spacing: 20) {
            Button("重新连接") {
                voiceController.reconnect()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

#Preview {
    // 预览用的模拟对象
    let voiceController = VoiceRecognitionController()
    let textInjectionManager = TextInjectionManager()
    
    return SettingsContentView(
        voiceController: voiceController,
        textInjectionManager: textInjectionManager
    )
}