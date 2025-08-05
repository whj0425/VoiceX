import Foundation
import Network

@MainActor
class WebSocketManager: ObservableObject {
    @Published var isConnected = false
    @Published var lastRecognitionResult = ""
    @Published var isRecognizing = false
    
    // 新增：用于将详细结果传递给控制器的闭包
    var onRecognitionResult: ((_ mode: String, _ text: String, _ isFinal: Bool) -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private let serverURL = URL(string: "ws://localhost:10096")!
    
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
    
    // `setTextInjectionManager` 已被移除
    
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
            // `lastInjectedText` 相关的逻辑已被移除
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
            await processRecognitionResult(jsonString: text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                await processRecognitionResult(jsonString: text)
            }
        @unknown default:
            print("⚠️ 未知消息类型")
        }
    }
    
    private func processRecognitionResult(jsonString: String) async {
        do {
            guard let data = jsonString.data(using: .utf8),
                  let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = result["text"] as? String else {
                print("⚠️ 无效结果格式: \(jsonString)")
                return
            }
            
            // 解析 "mode" 和 "is_final"
            let mode = result["mode"] as? String ?? "unknown"
            let isFinal = result["is_final"] as? Bool ?? false
            
            print("📦 [WebSocket] 收到结果: mode='\(mode)', is_final=\(isFinal), text='\(text)'")
            
            await MainActor.run {
                // 更新UI显示的文本
                self.lastRecognitionResult = text
                
                // 通过闭包将详细结果传递出去
                self.onRecognitionResult?(mode, text, isFinal)
            }
            
        } catch {
            print("❌ 解析识别结果失败: \(error)")
        }
    }
}