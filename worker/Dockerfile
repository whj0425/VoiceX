# 使用官方FunASR运行时镜像作为基础
FROM registry.cn-hangzhou.aliyuncs.com/funasr_repo/funasr:funasr-runtime-sdk-online-cpu-0.1.13

# 设置工作目录为FunASR runtime目录
WORKDIR /workspace/FunASR/runtime

# 暴露端口
EXPOSE 10095

# 设置环境变量
ENV MODELSCOPE_CACHE=/workspace/models

# 确保热词文件存在
RUN touch /workspace/FunASR/runtime/websocket/hotwords.txt

# 健康检查 - 检查WebSocket服务是否可用
HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=3 \
    CMD nc -z localhost 10095 || exit 1

# 创建自定义启动脚本确保前台运行
COPY start_server.sh /workspace/FunASR/runtime/
RUN chmod +x /workspace/FunASR/runtime/start_server.sh

# 启动C++ WebSocket服务器（支持ONNX模型）
CMD ["/workspace/FunASR/runtime/start_server.sh"]