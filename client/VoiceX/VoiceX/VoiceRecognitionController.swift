import Foundation
import SwiftUI

@MainActor
class VoiceRecognitionController: ObservableObject {
    @Published var isActive = false
    @Published var recognitionText = ""
    @Published var connectionStatus = "未连接"
    @Published var hasAudioPermission = false
    
    private let webSocketManager = WebSocketManager()
    private let audioRecorder = AudioRecorder()
    private var textInjectionManager: TextInjectionManager?
    private var lastInjectedText: String = ""
    
    init() {
        setupBindings()
    }
    
    func setTextInjectionManager(_ manager: TextInjectionManager) {
        textInjectionManager = manager
        webSocketManager.setVoiceRecognitionController(self)
    }
    
    private func setupBindings() {
        webSocketManager.$isConnected
            .receive(on: DispatchQueue.main)
            .map { $0 ? "已连接" : "未连接" }
            .assign(to: &$connectionStatus)
        
        webSocketManager.$lastRecognitionResult
            .receive(on: DispatchQueue.main)
            .assign(to: &$recognitionText)
        
        audioRecorder.$hasPermission
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasAudioPermission)
    }
    
    func toggleRecognition() {
        if isActive {
            stopRecognition()
        } else {
            startRecognition()
        }
    }
    
    private func startRecognition() {
        guard hasAudioPermission else {
            audioRecorder.checkPermission()
            return
        }
        
        guard webSocketManager.isConnected else {
            connectionStatus = "连接失败"
            return
        }
        
        Task {
            await webSocketManager.startRecognition()
            
            await MainActor.run {
                audioRecorder.startRecording { [weak self] audioData in
                    Task {
                        await self?.webSocketManager.sendAudioChunk(audioData)
                    }
                }
                
                isActive = true
                recognitionText = "正在录音..."
            }
        }
    }
    
    private func stopRecognition() {
        Task {
            await webSocketManager.stopRecognition()
            
            await MainActor.run {
                audioRecorder.stopRecording()
                isActive = false
                lastInjectedText = "" // 重置注入状态
            }
        }
    }
    
    func clearText() {
        recognitionText = ""
    }
    
    func reconnect() {
        Task {
            webSocketManager.disconnect()
            await webSocketManager.connect()
        }
    }
    
    // MARK: - 自适应文本注入策略
    func handleRecognizedResult(mode: String, text: String, isFinal: Bool) {
        // 检测当前活动的应用
        let activeAppID = ApplicationDetector.getActiveApplicationBundleIdentifier()
        
        print("🎯 处理识别结果: mode=\(mode), text='\(text)', isFinal=\(isFinal)")
        print("🔍 当前活动应用: \(activeAppID ?? "unknown")")
        
        // 根据应用ID选择不同的处理策略
        if activeAppID == "com.apple.Terminal" {
            // 策略A：检测到是终端应用
            handleTerminalStrategy(mode: mode, text: text, isFinal: isFinal)
        } else {
            // 策略B：是其他普通应用
            handleStandardStrategy(mode: mode, text: text, isFinal: isFinal)
        }
    }
    
    // 标准应用的实时替换策略
    private func handleStandardStrategy(mode: String, text: String, isFinal: Bool) {
        guard let textInjectionManager = textInjectionManager,
              textInjectionManager.isInjectionEnabled else {
            return
        }
        
        print("📝 标准策略: mode=\(mode), 替换 '\(lastInjectedText)' -> '\(text)'")
        
        if mode == "2pass-online" {
            // 中间结果：实时替换
            textInjectionManager.replace(oldText: lastInjectedText, with: text)
            lastInjectedText = text
        } else if mode == "2pass-offline" || isFinal {
            // 最终结果：最后一次替换，然后重置状态
            textInjectionManager.replace(oldText: lastInjectedText, with: text)
            lastInjectedText = ""
        }
    }
    
    // 终端应用的最终注入策略
    private func handleTerminalStrategy(mode: String, text: String, isFinal: Bool) {
        guard let textInjectionManager = textInjectionManager,
              textInjectionManager.isInjectionEnabled else {
            return
        }
        
        print("🖥️ 终端策略: mode=\(mode), isFinal=\(isFinal)")
        
        // 完全忽略所有中间(online)结果
        if mode == "2pass-online" {
            print("⏭️ 跳过中间结果（终端策略）")
            return
        }

        // 只在收到最终(offline)结果时才执行操作
        if mode == "2pass-offline" || isFinal {
            print("✅ 注入最终结果（终端策略）: '\(text)'")
            textInjectionManager.injectText(text)
            lastInjectedText = ""
        }
    }
}