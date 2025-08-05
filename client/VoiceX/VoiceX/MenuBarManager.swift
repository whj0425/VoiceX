//
//  MenuBarManager.swift
//  VoiceX
//
//  Created for VoiceX Stage 5: Menu Bar Application
//

import SwiftUI
import AppKit
import Combine

@MainActor
class MenuBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    
    @Published var isVoiceRecognitionEnabled = false
    @Published var connectionStatus: String = "未连接"
    
    // 依赖注入
    private var voiceController: VoiceRecognitionController?
    private var textInjectionManager: TextInjectionManager?
    private var settingsWindow: SettingsWindowManager?
    
    init() {
        setupMenuBar()
    }
    
    func setDependencies(
        voiceController: VoiceRecognitionController,
        textInjectionManager: TextInjectionManager,
        settingsWindow: SettingsWindowManager
    ) {
        self.voiceController = voiceController
        self.textInjectionManager = textInjectionManager
        self.settingsWindow = settingsWindow
        
        // 监听语音识别状态变化
        setupBindings()
    }
    
    private func setupMenuBar() {
        // 创建状态栏项目
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        guard let statusItem = statusItem else { return }
        
        // 设置初始图标
        updateStatusIcon(isActive: false, isConnected: false)
        
        // 创建菜单
        setupMenu()
        statusItem.menu = menu
    }
    
    private func setupMenu() {
        menu = NSMenu()
        
        // 主开关菜单项
        let toggleItem = NSMenuItem(
            title: "启用语音识别",
            action: #selector(toggleVoiceRecognition),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu?.addItem(toggleItem)
        
        // 分隔线
        menu?.addItem(NSMenuItem.separator())
        
        // 设置菜单项
        let settingsItem = NSMenuItem(
            title: "设置...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu?.addItem(settingsItem)
        
        // 退出菜单项
        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu?.addItem(quitItem)
    }
    
    private func setupBindings() {
        guard let voiceController = voiceController else { return }
        
        // 监听连接状态变化
        voiceController.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.connectionStatus = status
                self?.updateMenuAndIcon()
            }
            .store(in: &cancellables)
        
        // 监听活动状态变化
        voiceController.$isActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in
                self?.updateMenuAndIcon()
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    @objc private func toggleVoiceRecognition() {
        guard let voiceController = voiceController,
              let textInjectionManager = textInjectionManager else {
            print("⚠️ 依赖组件未初始化")
            return
        }
        
        isVoiceRecognitionEnabled.toggle()
        
        if isVoiceRecognitionEnabled {
            // 启用语音识别和文本注入
            if !textInjectionManager.isInjectionEnabled {
                textInjectionManager.toggleInjection()
            }
            
            // 如果未连接，先连接
            if connectionStatus != "已连接" {
                voiceController.reconnect()
            }
            
            // 开始录音
            if !voiceController.isActive {
                voiceController.toggleRecognition()
            }
        } else {
            // 停止语音识别
            if voiceController.isActive {
                voiceController.toggleRecognition()
            }
        }
        
        updateMenuAndIcon()
    }
    
    @objc private func openSettings() {
        settingsWindow?.showWindow()
    }
    
    @objc private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
    
    private func updateMenuAndIcon() {
        guard let menu = menu,
              let voiceController = voiceController else { return }
        
        // 更新主开关菜单项文本
        if let toggleItem = menu.items.first {
            toggleItem.title = isVoiceRecognitionEnabled ? "禁用语音识别" : "启用语音识别"
            toggleItem.state = isVoiceRecognitionEnabled ? .on : .off
        }
        
        // 更新状态栏图标
        let isConnected = connectionStatus == "已连接"
        let isActive = voiceController.isActive
        updateStatusIcon(isActive: isActive, isConnected: isConnected)
    }
    
    private func updateStatusIcon(isActive: Bool, isConnected: Bool) {
        guard let statusButton = statusItem?.button else { return }
        
        // 根据状态选择不同的图标
        let iconName: String
        if !isConnected {
            iconName = "exclamationmark.triangle.fill" // 连接失败
        } else if isActive {
            iconName = "mic.fill" // 正在录音
        } else {
            iconName = "mic" // 待机状态
        }
        
        statusButton.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        statusButton.image?.isTemplate = true
        
        // 设置工具提示
        let tooltip: String
        if !isConnected {
            tooltip = "VoiceX - 连接失败"
        } else if isActive {
            tooltip = "VoiceX - 正在录音"
        } else {
            tooltip = "VoiceX - 就绪"
        }
        statusButton.toolTip = tooltip
    }
}