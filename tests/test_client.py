#!/usr/bin/env python3
"""
VoiceX Worker 测试客户端
用于测试 FunASR TCP 服务器的连接和识别功能
"""

import socket
import struct
import json
import time
import wave
import numpy as np
import argparse
import logging
from pathlib import Path
from typing import Optional

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class VoiceXTestClient:
    def __init__(self, host='localhost', port=10096):
        self.host = host
        self.port = port
        self.socket = None
        
    def connect(self) -> bool:
        """连接到FunASR TCP服务器"""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.settimeout(10)
            self.socket.connect((self.host, self.port))
            logger.info(f"成功连接到服务器 {self.host}:{self.port}")
            return True
        except Exception as e:
            logger.error(f"连接失败: {e}")
            return False
    
    def disconnect(self):
        """断开连接"""
        if self.socket:
            self.socket.close()
            self.socket = None
            logger.info("已断开连接")
    
    def send_audio_data(self, audio_data: bytes) -> Optional[dict]:
        """发送音频数据并接收识别结果"""
        if not self.socket:
            logger.error("未连接到服务器")
            return None
        
        try:
            # 发送数据长度
            length_header = struct.pack('<I', len(audio_data))
            self.socket.sendall(length_header)
            
            # 发送音频数据
            self.socket.sendall(audio_data)
            logger.info(f"已发送 {len(audio_data)} 字节音频数据")
            
            # 接收响应长度
            response_length_data = self.socket.recv(4)
            if len(response_length_data) != 4:
                logger.error("接收响应长度失败")
                return None
            
            response_length = struct.unpack('<I', response_length_data)[0]
            
            # 接收响应内容
            response_data = b''
            while len(response_data) < response_length:
                chunk = self.socket.recv(response_length - len(response_data))
                if not chunk:
                    logger.error("接收响应数据失败")
                    return None
                response_data += chunk
            
            # 解析JSON响应
            response_str = response_data.decode('utf-8')
            response = json.loads(response_str)
            
            logger.info(f"收到响应: {response}")
            return response
            
        except Exception as e:
            logger.error(f"发送音频数据失败: {e}")
            return None
    
    def generate_test_audio(self, duration=3, sample_rate=16000) -> bytes:
        """生成测试音频数据（正弦波）"""
        # 生成440Hz正弦波，持续duration秒
        t = np.linspace(0, duration, duration * sample_rate, False)
        frequency = 440  # A4音符
        audio_samples = np.sin(2 * np.pi * frequency * t) * 0.3
        
        # 转换为16-bit PCM格式
        audio_int16 = (audio_samples * 32767).astype(np.int16)
        return audio_int16.tobytes()
    
    def load_wav_file(self, wav_path: str) -> Optional[bytes]:
        """加载WAV文件"""
        try:
            with wave.open(wav_path, 'rb') as wav_file:
                # 检查音频格式
                channels = wav_file.getnchannels()
                sample_width = wav_file.getsampwidth()
                framerate = wav_file.getframerate()
                
                logger.info(f"WAV文件信息: {channels}声道, {sample_width}字节采样, {framerate}Hz")
                
                # 读取音频数据
                frames = wav_file.readframes(wav_file.getnframes())
                
                # 转换为16kHz单声道（如果需要）
                if framerate != 16000 or channels != 1 or sample_width != 2:
                    logger.warn(f"音频格式不匹配，需要16kHz单声道16bit，当前为{framerate}Hz {channels}声道 {sample_width*8}bit")
                    # 这里可以添加音频格式转换逻辑
                
                return frames
                
        except Exception as e:
            logger.error(f"加载WAV文件失败: {e}")
            return None

def test_connection(client: VoiceXTestClient) -> bool:
    """测试连接"""
    logger.info("=== 测试连接 ===")
    return client.connect()

def test_synthetic_audio(client: VoiceXTestClient) -> bool:
    """测试合成音频识别"""
    logger.info("=== 测试合成音频识别 ===")
    
    # 生成测试音频
    test_audio = client.generate_test_audio(duration=2)
    logger.info(f"生成了 {len(test_audio)} 字节的测试音频")
    
    # 发送音频并获取结果
    result = client.send_audio_data(test_audio)
    
    if result:
        if result.get('success'):
            logger.info(f"识别成功: {result.get('text', '无文本')}")
            return True
        else:
            logger.error(f"识别失败: {result.get('error', '未知错误')}")
    
    return False

def test_wav_file(client: VoiceXTestClient, wav_path: str) -> bool:
    """测试WAV文件识别"""
    logger.info(f"=== 测试WAV文件识别: {wav_path} ===")
    
    if not Path(wav_path).exists():
        logger.error(f"WAV文件不存在: {wav_path}")
        return False
    
    # 加载WAV文件
    audio_data = client.load_wav_file(wav_path)
    if not audio_data:
        return False
    
    # 发送音频并获取结果
    result = client.send_audio_data(audio_data)
    
    if result:
        if result.get('success'):
            logger.info(f"识别成功: {result.get('text', '无文本')}")
            return True
        else:
            logger.error(f"识别失败: {result.get('error', '未知错误')}")
    
    return False

def test_stress(client: VoiceXTestClient, num_requests=10) -> bool:
    """压力测试"""
    logger.info(f"=== 压力测试: {num_requests} 次请求 ===")
    
    success_count = 0
    test_audio = client.generate_test_audio(duration=1)
    
    start_time = time.time()
    
    for i in range(num_requests):
        logger.info(f"发送第 {i+1}/{num_requests} 个请求")
        result = client.send_audio_data(test_audio)
        
        if result and result.get('success'):
            success_count += 1
        
        time.sleep(0.1)  # 短暂延迟
    
    end_time = time.time()
    total_time = end_time - start_time
    
    logger.info(f"压力测试完成:")
    logger.info(f"  总请求数: {num_requests}")
    logger.info(f"  成功数: {success_count}")
    logger.info(f"  成功率: {success_count/num_requests*100:.1f}%")
    logger.info(f"  总耗时: {total_time:.2f}秒")
    logger.info(f"  平均延迟: {total_time/num_requests:.3f}秒/请求")
    
    return success_count > 0

def main():
    parser = argparse.ArgumentParser(description='VoiceX Worker 测试客户端')
    parser.add_argument('--host', default='localhost', help='服务器地址')
    parser.add_argument('--port', type=int, default=10096, help='服务器端口')
    parser.add_argument('--wav', help='测试WAV文件路径')
    parser.add_argument('--stress', type=int, default=0, help='压力测试请求数量')
    parser.add_argument('--test', choices=['connection', 'synthetic', 'all'], default='all', help='测试类型')
    
    args = parser.parse_args()
    
    # 创建客户端
    client = VoiceXTestClient(args.host, args.port)
    
    try:
        # 连接测试
        if args.test in ['connection', 'all']:
            if not test_connection(client):
                logger.error("连接测试失败，退出")
                return False
        else:
            if not client.connect():
                logger.error("无法连接到服务器，退出")
                return False
        
        success = True
        
        # 合成音频测试
        if args.test in ['synthetic', 'all']:
            success = test_synthetic_audio(client) and success
        
        # WAV文件测试
        if args.wav:
            success = test_wav_file(client, args.wav) and success
        
        # 压力测试
        if args.stress > 0:
            success = test_stress(client, args.stress) and success
        
        if success:
            logger.info("所有测试通过！")
        else:
            logger.error("部分测试失败！")
        
        return success
        
    finally:
        client.disconnect()

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)