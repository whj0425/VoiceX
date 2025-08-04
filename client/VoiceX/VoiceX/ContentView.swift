//
//  ContentView.swift
//  VoiceX
//
//  Created by xyx on 4/8/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var controller = VoiceRecognitionController()
    
    var body: some View {
        VStack(spacing: 20) {
            headerView
            connectionStatusView
            recognitionTextView
            controlButtonsView
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("VoiceX 实时语音识别")
                .font(.title2)
                .fontWeight(.semibold)
        }
    }
    
    private var connectionStatusView: some View {
        HStack {
            Circle()
                .fill(controller.connectionStatus == "已连接" ? .green : .red)
                .frame(width: 8, height: 8)
            Text("连接状态: \(controller.connectionStatus)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if !controller.hasAudioPermission {
                Text("需要麦克风权限")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private var recognitionTextView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("识别结果:")
                    .font(.headline)
                Spacer()
                Button("清除") {
                    controller.clearText()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            ScrollView {
                Text(controller.recognitionText.isEmpty ? "点击开始按钮开始语音识别..." : controller.recognitionText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 200)
        }
    }
    
    private var controlButtonsView: some View {
        HStack(spacing: 20) {
            Button(action: {
                controller.toggleRecognition()
            }) {
                HStack {
                    Image(systemName: controller.isActive ? "stop.circle.fill" : "mic.circle.fill")
                    Text(controller.isActive ? "停止录音" : "开始录音")
                }
                .frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!controller.hasAudioPermission || controller.connectionStatus != "已连接")
            
            Button("重新连接") {
                controller.reconnect()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

#Preview {
    ContentView()
}
