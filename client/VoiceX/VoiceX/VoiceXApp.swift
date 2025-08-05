//
//  VoiceXApp.swift
//  VoiceX
//
//  Created by xyx on 4/8/25.
//  Stage 5: Menu Bar Application Architecture
//

import SwiftUI
import AppKit

@main
struct VoiceXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // 空场景，使用菜单栏架构
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    // 核心组件
    private var menuBarManager: MenuBarManager!
    private var settingsWindowManager: SettingsWindowManager!
    private var voiceController: VoiceRecognitionController!
    private var textInjectionManager: TextInjectionManager!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 VoiceX 菜单栏应用启动")
        
        Task { @MainActor in
            // 初始化核心组件
            setupComponents()
            
            // 建立组件间的依赖关系
            setupDependencies()
            
            // 隐藏默认的应用程序窗口
            hideDefaultWindow()
            
            print("✅ VoiceX 菜单栏应用初始化完成")
        }
    }
    
    @MainActor
    private func setupComponents() {
        // 初始化业务逻辑组件
        voiceController = VoiceRecognitionController()
        textInjectionManager = TextInjectionManager()
        
        // 初始化UI管理组件
        menuBarManager = MenuBarManager()
        settingsWindowManager = SettingsWindowManager()
    }
    
    @MainActor 
    private func setupDependencies() {
        // 设置VoiceRecognitionController的依赖
        voiceController.setTextInjectionManager(textInjectionManager)
        
        // 设置MenuBarManager的依赖
        menuBarManager.setDependencies(
            voiceController: voiceController,
            textInjectionManager: textInjectionManager,
            settingsWindow: settingsWindowManager
        )
        
        // 设置SettingsWindowManager的依赖
        settingsWindowManager.setDependencies(
            voiceController: voiceController,
            textInjectionManager: textInjectionManager
        )
    }
    
    private func hideDefaultWindow() {
        // 隐藏默认创建的主窗口
        if let window = NSApplication.shared.windows.first {
            window.orderOut(nil)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 菜单栏应用不应该在关闭最后一个窗口时退出
        return false
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("👋 VoiceX 应用即将退出")
        
        // 清理资源
        if voiceController.isActive {
            voiceController.toggleRecognition()
        }
    }
}
