import asyncio
import websockets
import json
import argparse

# --- 配置 ---
# 您可以直接在命令行中指定参数，如此处所示，
# 或者直接修改默认值。
parser = argparse.ArgumentParser()
parser.add_argument("--host", type=str, default="localhost", help="Server IP address")
parser.add_argument("--port", type=int, default=10096, help="Server port")
parser.add_argument("--audio_in", type=str, default="./test_audio.wav", help="Path to the test audio file (16k, 16bit, mono)")
args = parser.parse_args()

SERVER_URI = f"ws://{args.host}:{args.port}"
AUDIO_FILE_PATH = args.audio_in
CHUNK_SIZE = 3200  # 每次发送3200字节 (相当于0.1秒的16k 16bit音频)

# --- 关键：基于官方示例修正的协议 ---

# 1. “开始”信号
# 必须包含 "mode", "wav_name", "is_speaking"
# 可选加入 hotwords 等参数
START_SIGNAL = json.dumps({
    "mode": "online",  # 明确使用2pass模式
    "wav_name": "my_test_audio.wav",
    "is_speaking": True,
    # "hotwords": "阿里巴巴 支付宝" # 如果需要，可以添加热词
})

# 2. “结束”信号
END_SIGNAL = json.dumps({"is_speaking": False})


async def audio_sender(websocket):
    """异步生成器，读取并发送音频文件"""
    print(f"开始发送音频文件: {AUDIO_FILE_PATH}...")
    try:
        with open(AUDIO_FILE_PATH, "rb") as f:
            while True:
                chunk = f.read(CHUNK_SIZE)
                if not chunk:
                    break
                # 发送二进制音频数据
                await websocket.send(chunk)
                await asyncio.sleep(0.1) # 模拟真实说话间隔
    except FileNotFoundError:
        print(f"错误：找不到音频文件 {AUDIO_FILE_PATH}")
        return

async def result_receiver(websocket):
    """接收并打印识别结果"""
    print("开始接收结果...")
    try:
        async for message in websocket:
            result = json.loads(message)
            if 'text' in result:
                print(f"收到结果: {result['text']}")
            else:
                print(f"收到消息: {result}")

    except websockets.exceptions.ConnectionClosed as e:
        print(f"连接已关闭: {e}")
    except Exception as e:
        print(f"接收时发生错误: {e}")

async def main():
    """主函数，建立连接并管理任务"""
    print(f"尝试连接到服务器: {SERVER_URI}")
    try:
        async with websockets.connect(SERVER_URI) as websocket:
            print("连接成功！")
            
            # 发送开始信号
            await websocket.send(START_SIGNAL)
            print("已发送开始信号。")

            # 并发执行发送和接收任务
            receiver_task = asyncio.create_task(result_receiver(websocket))
            sender_task = asyncio.create_task(audio_sender(websocket))
            
            # 等待发送任务完成
            await sender_task
            
            # 等待接收任务完成（可能会因为服务器关闭连接而结束）
            await asyncio.sleep(1) # 给服务器一点时间处理最后的数据
            await websocket.send(END_SIGNAL)
            print("已发送结束信号。")

            # 等待接收任务自然结束或超时
            try:
                await asyncio.wait_for(receiver_task, timeout=5.0)
            except asyncio.TimeoutError:
                print("接收任务超时。")

    except Exception as e:
        print(f"连接失败或发生错误: {e}")


if __name__ == "__main__":
    print("--- FunASR WebSocket 官方协议客户端测试 ---")
    asyncio.run(main())