import AVFoundation
import Foundation

@MainActor
class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var hasPermission = false
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFormat: AVAudioFormat?
    
    private var onAudioData: ((Data) -> Void)?
    
    private let sampleRate: Double = 16000.0
    private let channels: UInt32 = 1
    private let bitDepth: UInt32 = 16
    
    private let chunkDurationMs: Double = 100.0
    private var expectedChunkSize: Int {
        return Int(sampleRate * Double(bitDepth) / 8.0 * Double(channels) * (chunkDurationMs / 1000.0))
    }
    
    private var audioBuffer = Data()
    
    init() {
        checkPermission()
    }
    
    func checkPermission() {
        #if os(macOS)
        // 在macOS上，麦克风权限会在第一次尝试访问时自动请求
        // 我们先假设有权限，实际权限检查会在启动AudioEngine时进行
        hasPermission = true
        #else
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            hasPermission = true
        case .denied:
            hasPermission = false
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
                DispatchQueue.main.async {
                    self?.hasPermission = allowed
                }
            }
        @unknown default:
            hasPermission = false
        }
        #endif
    }
    
    func startRecording(onAudioData: @escaping (Data) -> Void) {
        guard hasPermission, !isRecording else { return }
        
        self.onAudioData = onAudioData
        
        do {
            try setupAudioSession()
            try startAudioEngine()
            isRecording = true
            print("🎤 开始录音 - 采样率: \(sampleRate)Hz, 声道: \(channels), 位深: \(bitDepth)bit")
            print("📦 音频块大小: \(expectedChunkSize) 字节 (每 \(chunkDurationMs)ms)")
        } catch {
            print("❌ 启动录音失败: \(error)")
            #if os(macOS)
            // 在macOS上，如果权限被拒绝，更新权限状态
            if error.localizedDescription.contains("access") || error.localizedDescription.contains("permission") {
                hasPermission = false
            }
            #endif
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        inputNode = nil
        
        audioBuffer.removeAll()
        onAudioData = nil
        isRecording = false
        
        print("🛑 停止录音")
    }
    
    private func setupAudioSession() throws {
        #if os(iOS) || os(tvOS) || os(watchOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        try audioSession.setPreferredSampleRate(sampleRate)
        try audioSession.setPreferredInputNumberOfChannels(Int(channels))
        #endif
    }
    
    private func startAudioEngine() throws {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        guard let audioEngine = audioEngine,
              let inputNode = inputNode else {
            throw AudioRecorderError.failedToCreateAudioEngine
        }
        
        // 使用输入节点的原始格式进行 tap 安装
        let inputFormat = inputNode.outputFormat(forBus: 0)
        print("🎤 输入格式: \(inputFormat)")
        
        // 创建目标格式
        audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        )
        
        guard let audioFormat = audioFormat else {
            throw AudioRecorderError.failedToCreateAudioFormat
        }
        
        print("🎯 目标格式: \(audioFormat)")
        
        // 创建格式转换器
        let converter = AVAudioConverter(from: inputFormat, to: audioFormat)
        guard let audioConverter = converter else {
            throw AudioRecorderError.failedToCreateAudioFormat
        }
        
        // 使用输入格式安装 tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, converter: audioConverter, targetFormat: audioFormat)
        }
        
        try audioEngine.start()
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        // 创建输出缓冲区
        let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else { return }
        
        // 执行格式转换
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        if status != .haveData, let error = error {
            print("❌ 音频转换失败: \(error)")
            return
        }
        
        guard let channelData = outputBuffer.int16ChannelData?[0] else { return }
        
        let frameCount = Int(outputBuffer.frameLength)
        let data = Data(bytes: channelData, count: frameCount * 2)
        
        audioBuffer.append(data)
        
        while audioBuffer.count >= expectedChunkSize {
            let chunk = audioBuffer.prefix(expectedChunkSize)
            audioBuffer.removeFirst(expectedChunkSize)
            
            DispatchQueue.main.async { [weak self] in
                self?.onAudioData?(Data(chunk))
            }
        }
    }
}

enum AudioRecorderError: Error {
    case failedToCreateAudioEngine
    case failedToCreateAudioFormat
    case permissionDenied
}