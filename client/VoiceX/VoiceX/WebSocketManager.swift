import Foundation
import Network

@MainActor
class WebSocketManager: ObservableObject {
    @Published var isConnected = false
    @Published var lastRecognitionResult = ""
    @Published var isRecognizing = false
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let serverURL = URL(string: "ws://localhost:10096")!
    private weak var voiceRecognitionController: VoiceRecognitionController?
    
    private let startSignal: [String: Any] = [
        "mode": "2pass",
        "chunk_size": [5, 10, 5],
        "chunk_interval": 10,
        "wav_name": "voicex_streaming.wav",
        "is_speaking": true
    ]
    
    private let endSignal: [String: Any] = [
        "is_speaking": false
    ]
    
    init() {
        Task {
            await connect()
        }
    }
    
    func setVoiceRecognitionController(_ controller: VoiceRecognitionController) {
        voiceRecognitionController = controller
    }
    
    func connect() async {
        guard !isConnected else { return }
        
        print("🔌 尝试连接到服务器: \(serverURL)")
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: serverURL)
        
        webSocketTask?.resume()
        
        // 等待一下看是否连接成功
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        await MainActor.run {
            isConnected = true
            print("✅ WebSocket连接已建立")
        }
        
        startReceiving()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        isRecognizing = false
    }
    
    func startRecognition() async {
        guard isConnected, !isRecognizing else { return }
        
        do {
            let startData = try JSONSerialization.data(withJSONObject: startSignal)
            let startMessage = String(data: startData, encoding: .utf8)!
            
            try await webSocketTask?.send(.string(startMessage))
            isRecognizing = true
            print("📤 发送开始信号: \(startMessage)")
        } catch {
            print("❌ 发送开始信号失败: \(error)")
        }
    }
    
    func stopRecognition() async {
        guard isConnected, isRecognizing else { return }
        
        do {
            let endData = try JSONSerialization.data(withJSONObject: endSignal)
            let endMessage = String(data: endData, encoding: .utf8)!
            
            try await webSocketTask?.send(.string(endMessage))
            isRecognizing = false
            print("📤 发送结束信号: \(endMessage)")
        } catch {
            print("❌ 发送结束信号失败: \(error)")
        }
    }
    
    func sendAudioChunk(_ audioData: Data) async {
        guard isConnected, isRecognizing else { return }
        
        do {
            try await webSocketTask?.send(.data(audioData))
            print("📤 发送音频块: \(audioData.count) 字节")
        } catch {
            print("❌ 发送音频块失败: \(error)")
        }
    }
    
    private func startReceiving() {
        guard let webSocketTask = webSocketTask else { return }
        
        Task {
            do {
                let message = try await webSocketTask.receive()
                await handleMessage(message)
                
                if isConnected {
                    startReceiving()
                }
            } catch {
                print("❌ 接收消息失败: \(error)")
                await MainActor.run {
                    isConnected = false
                    isRecognizing = false
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            await processRecognitionResult(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                await processRecognitionResult(text)
            }
        @unknown default:
            print("⚠️ 未知消息类型")
        }
    }
    
    private func processRecognitionResult(_ jsonString: String) async {
        do {
            guard let data = jsonString.data(using: .utf8),
                  let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = result["text"] as? String else {
                print("⚠️ 无效结果格式: \(jsonString)")
                return
            }
            
            let isFinal = result["is_final"] as? Bool ?? true
            let mode = result["mode"] as? String ?? (isFinal ? "2pass-offline" : "2pass-online")
            let status = isFinal ? "【最终】" : "【中间】"
            
            print("\(status) 识别结果: \(text)")
            print("🔍 模式: \(mode), is_final: \(isFinal)")
            
            await MainActor.run {
                lastRecognitionResult = text
                
                // 委托给 VoiceRecognitionController 处理
                voiceRecognitionController?.handleRecognizedResult(
                    mode: mode,
                    text: text,
                    isFinal: isFinal
                )
            }
            
        } catch {
            print("❌ 解析识别结果失败: \(error)")
        }
    }
}