import Foundation
import SwiftUI

@MainActor
class VoiceRecognitionController: ObservableObject {
    @Published var isActive = false
    @Published var recognitionText = "" // This will still be updated for the UI
    @Published var connectionStatus = "未连接"
    @Published var hasAudioPermission = false
    
    private let webSocketManager = WebSocketManager()
    private let audioRecorder = AudioRecorder()
    // TextInjectionManager is now a singleton, so we don't need a local instance
    
    // State for the replacement strategy
    private var lastInjectedText: String = ""

    init() {
        setupBindings()
    }
    
    // No longer need setTextInjectionManager
    
    private func setupBindings() {
        // Bind connection status
        webSocketManager.$isConnected
            .receive(on: DispatchQueue.main)
            .map { $0 ? "已连接" : "未连接" }
            .assign(to: &$connectionStatus)
        
        // Bind recognition text for UI display
        webSocketManager.$lastRecognitionResult
            .receive(on: DispatchQueue.main)
            .assign(to: &$recognitionText)
        
        // Bind audio permission
        audioRecorder.$hasPermission
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasAudioPermission)

        // Set up the callback for detailed recognition results
        webSocketManager.onRecognitionResult = { [weak self] (mode, text, isFinal) in
            self?.handleRecognizedResult(mode: mode, text: text, isFinal: isFinal)
        }
    }

    // The new core logic for handling results
    public func handleRecognizedResult(mode: String, text: String, isFinal: Bool) {
        // 1. Detect the active application
        let activeAppID = ApplicationDetector.getActiveApplicationBundleIdentifier()

        print("🧠 [Controller] Handling result for app '\(activeAppID ?? "Unknown")': mode='\(mode)', is_final=\(isFinal), text='\(text)'")

        // 2. Choose the strategy based on the application ID
        if activeAppID == "com.apple.Terminal" {
            handleTerminalStrategy(mode: mode, text: text, isFinal: isFinal)
        } else {
            handleStandardStrategy(mode: mode, text: text, isFinal: isFinal)
        }
    }

    // Strategy for standard applications (real-time replacement)
    private func handleStandardStrategy(mode: String, text: String, isFinal: Bool) {
        print("    -> Using Standard Strategy")
        // FunASR 2-pass mode can be identified by the mode name
        if mode == "2pass-online" {
            TextInjectionManager.shared.replace(oldText: self.lastInjectedText, with: text)
            self.lastInjectedText = text
        } else if mode == "2pass-offline" {
            TextInjectionManager.shared.replace(oldText: self.lastInjectedText, with: text)
            self.lastInjectedText = "" // Reset for the next utterance
        } else if isFinal {
            // Fallback for non-2pass modes or final messages
            TextInjectionManager.shared.replace(oldText: self.lastInjectedText, with: text)
            self.lastInjectedText = ""
        }
    }

    // Strategy for the Terminal (inject only the final result)
    private func handleTerminalStrategy(mode: String, text: String, isFinal: Bool) {
        print("    -> Using Terminal Strategy")
        // Ignore all intermediate results
        if mode == "2pass-online" {
            print("       -> Ignoring online result.")
            return
        }

        // Inject only the final, definitive result
        if mode == "2pass-offline" || isFinal {
            print("       -> Injecting final result.")
            TextInjectionManager.shared.inject(text: text)
            self.lastInjectedText = "" // Reset state for consistency
        }
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
        
        // Reset state before starting a new recognition
        self.lastInjectedText = ""

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
}