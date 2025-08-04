#!/bin/bash

# VoiceX Worker Docker 启动脚本
# 针对 M4 Pro 48GB 内存优化配置

set -e

# 配置变量
IMAGE_NAME="voicex-worker"
CONTAINER_NAME="voicex-worker-container"
HOST_PORT=10096
CONTAINER_PORT=10095
MODELS_DIR="$(pwd)/models"
MEMORY_LIMIT="32g"
CPU_LIMIT="8"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查Docker是否运行
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker 未运行或未安装"
        exit 1
    fi
    log_info "Docker 检查通过"
}

# 创建模型存储目录
create_models_dir() {
    if [ ! -d "$MODELS_DIR" ]; then
        mkdir -p "$MODELS_DIR"
        log_info "创建模型目录: $MODELS_DIR"
    fi
}

# 停止并删除现有容器
cleanup_existing() {
    if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_warn "发现现有容器，正在清理..."
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
        docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
        log_info "现有容器已清理"
    fi
}

# 构建Docker镜像
build_image() {
    log_info "构建 Docker 镜像: $IMAGE_NAME"
    docker build -t "$IMAGE_NAME" .
    if [ $? -eq 0 ]; then
        log_info "镜像构建成功"
    else
        log_error "镜像构建失败"
        exit 1
    fi
}

# 启动容器
start_container() {
    log_info "启动 FunASR Worker 容器..."
    log_info "配置: 内存限制=${MEMORY_LIMIT}, CPU限制=${CPU_LIMIT}核"
    log_info "端口映射: ${HOST_PORT} -> ${CONTAINER_PORT}"
    
    docker run -d \
        --name "$CONTAINER_NAME" \
        --memory="$MEMORY_LIMIT" \
        --cpus="$CPU_LIMIT" \
        --restart=unless-stopped \
        -p "${HOST_PORT}:${CONTAINER_PORT}" \
        -v "${MODELS_DIR}:/workspace/models" \
        --health-interval=30s \
        --health-timeout=10s \
        --health-start-period=180s \
        --health-retries=3 \
        "$IMAGE_NAME"
    
    if [ $? -eq 0 ]; then
        log_info "容器启动成功"
        log_info "容器名称: $CONTAINER_NAME"
        log_info "访问地址: localhost:$HOST_PORT"
    else
        log_error "容器启动失败"
        exit 1
    fi
}

# 显示容器状态
show_status() {
    log_info "等待容器启动完成..."
    sleep 5
    
    echo ""
    log_info "=== 容器状态 ==="
    docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
    log_info "=== 容器日志 (最近10行) ==="
    docker logs --tail 10 "$CONTAINER_NAME"
    
    echo ""
    log_info "=== 健康检查状态 ==="
    docker inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}'
}

# 主函数
main() {
    log_info "启动 VoiceX Worker Docker 容器"
    log_info "工作目录: $(pwd)"
    
    check_docker
    create_models_dir
    cleanup_existing
    build_image
    start_container
    show_status
    
    echo ""
    log_info "=== 使用说明 ==="
    echo "查看日志: docker logs -f $CONTAINER_NAME"
    echo "停止容器: docker stop $CONTAINER_NAME"
    echo "重启容器: docker restart $CONTAINER_NAME"
    echo "进入容器: docker exec -it $CONTAINER_NAME /bin/bash"
    echo ""
    log_info "Worker 服务已启动完成!"
}

# 脚本参数处理
case "${1:-start}" in
    "start")
        main
        ;;
    "stop")
        log_info "停止 Worker 容器..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || log_warn "容器未运行"
        ;;
    "restart")
        log_info "重启 Worker 容器..."
        docker restart "$CONTAINER_NAME" 2>/dev/null || log_error "容器不存在"
        ;;
    "logs")
        docker logs -f "$CONTAINER_NAME" 2>/dev/null || log_error "容器不存在"
        ;;
    "status")
        docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
    "clean")
        log_info "清理所有相关资源..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
        docker rmi "$IMAGE_NAME" 2>/dev/null || true
        log_info "清理完成"
        ;;
    *)
        echo "用法: $0 {start|stop|restart|logs|status|clean}"
        echo "  start   - 启动服务 (默认)"
        echo "  stop    - 停止服务"
        echo "  restart - 重启服务"
        echo "  logs    - 查看日志"
        echo "  status  - 查看状态"
        echo "  clean   - 清理所有资源"
        exit 1
        ;;
esac