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
    
    init() {
        setupBindings()
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