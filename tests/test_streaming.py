import asyncio
import websockets
import json
import argparse
import time

# --- 配置 ---
parser = argparse.ArgumentParser()
parser.add_argument("--host", type=str, default="localhost", help="Server IP address")
parser.add_argument("--port", type=int, default=10096, help="Server port")
parser.add_argument("--audio_in", type=str, default="./test2.wav", help="Path to the test audio file (16k, 16bit, mono)")
parser.add_argument("--chunk_ms", type=int, default=100, help="Chunk duration in milliseconds")
args = parser.parse_args()

SERVER_URI = f"ws://{args.host}:{args.port}"
AUDIO_FILE_PATH = args.audio_in
CHUNK_MS = args.chunk_ms

# 计算音频块大小: 16kHz * 16bit * 1channel * chunk_ms/1000
# = 16000 * 2 * (chunk_ms/1000) bytes
CHUNK_SIZE = int(16000 * 2 * (CHUNK_MS / 1000))

print(f"流式配置: {CHUNK_MS}ms/块, {CHUNK_SIZE}字节/块")

# --- WebSocket协议信号 ---
START_SIGNAL = json.dumps({
    "mode": "2pass",
    "chunk_size": [5, 10, 5],  # 600ms latency配置
    "chunk_interval": 10,      # 60ms发送间隔
    "wav_name": f"streaming_test_{int(time.time())}.wav",
    "is_speaking": True,
})

END_SIGNAL = json.dumps({"is_speaking": False})


async def streaming_audio_sender(websocket):
    """流式发送音频数据，模拟实时语音输入"""
    print(f"开始流式发送音频文件: {AUDIO_FILE_PATH}")
    print(f"每 {CHUNK_MS}ms 发送 {CHUNK_SIZE} 字节")
    
    try:
        with open(AUDIO_FILE_PATH, "rb") as f:
            chunk_count = 0
            start_time = time.time()
            
            while True:
                chunk = f.read(CHUNK_SIZE)
                if not chunk:
                    break
                
                chunk_count += 1
                current_time = time.time() - start_time
                
                # 发送音频块
                await websocket.send(chunk)
                print(f"[{current_time:.2f}s] 发送第{chunk_count}块 ({len(chunk)}字节)")
                
                # 模拟实时间隔
                await asyncio.sleep(CHUNK_MS / 1000.0)
                
    except FileNotFoundError:
        print(f"错误：找不到音频文件 {AUDIO_FILE_PATH}")
        return
    except Exception as e:
        print(f"发送音频时出错: {e}")


async def streaming_result_receiver(websocket):
    """接收并处理流式识别结果"""
    print("开始接收流式结果...")
    result_count = 0
    
    try:
        async for message in websocket:
            result = json.loads(message)
            result_count += 1
            
            if 'text' in result:
                is_final = result.get('is_final', True)
                text = result['text']
                status = "【最终】" if is_final else "【中间】"
                
                print(f"{status} 结果#{result_count}: {text}")
                
                # 显示完整结果信息（调试用）
                if not is_final:
                    print(f"    详细: {result}")
            else:
                print(f"收到其他消息: {result}")

    except websockets.exceptions.ConnectionClosed as e:
        print(f"连接已关闭: {e}")
    except Exception as e:
        print(f"接收时发生错误: {e}")


async def main():
    """主函数：流式语音识别测试"""
    print("=" * 60)
    print("FunASR 实时流式语音识别测试")
    print("=" * 60)
    print(f"连接服务器: {SERVER_URI}")
    print(f"音频文件: {AUDIO_FILE_PATH}")
    print(f"流式参数: {CHUNK_MS}ms块大小, {CHUNK_SIZE}字节/块")
    print("=" * 60)
    
    try:
        async with websockets.connect(SERVER_URI) as websocket:
            print("✅ WebSocket连接成功！")
            
            # 发送开始信号
            await websocket.send(START_SIGNAL)
            print("📤 已发送开始信号")

            # 并发执行发送和接收任务
            print("🚀 开始流式传输...")
            receiver_task = asyncio.create_task(streaming_result_receiver(websocket))
            sender_task = asyncio.create_task(streaming_audio_sender(websocket))
            
            # 等待发送完成
            await sender_task
            print("📤 音频发送完成")
            
            # 等待一点时间让服务器处理剩余数据
            await asyncio.sleep(1)
            
            # 发送结束信号
            await websocket.send(END_SIGNAL)
            print("📤 已发送结束信号")

            # 等待接收任务完成或超时
            try:
                await asyncio.wait_for(receiver_task, timeout=5.0)
            except asyncio.TimeoutError:
                print("⏰ 接收任务超时")
            
            print("✅ 流式测试完成")

    except Exception as e:
        print(f"❌ 连接失败或发生错误: {e}")


if __name__ == "__main__":
    print("--- FunASR 实时流式 WebSocket 测试客户端 ---")
    asyncio.run(main())