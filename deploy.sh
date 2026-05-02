#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "=========================================="
echo "  RapidRelay 一键部署脚本"
echo "=========================================="
echo ""

get_local_ip() {
    local_ip=""
    if command -v hostname &> /dev/null; then
        local_ip=$(hostname -I 2>/dev/null | awk '{print $1}') || local_ip=""
    fi
    if [ -z "$local_ip" ]; then
        local_ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' | head -1) || local_ip="127.0.0.1"
    fi
    echo "$local_ip"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "缺少必需命令: $1"
        return 1
    fi
    return 0
}

log_info "正在检查环境..."

if ! check_command "node"; then
    echo "请先安装 Node.js: https://nodejs.org/"
    exit 1
fi

if ! check_command "npm"; then
    log_error "npm 未安装"
    exit 1
fi

log_success "Node.js 版本: $(node -v)"
log_success "npm 版本: $(npm -v)"
echo ""

DEFAULT_PORT=3000
read -p "请输入服务端口 [默认: $DEFAULT_PORT]: " PORT
PORT=$(echo "${PORT:-$DEFAULT_PORT}" | tr -d '[:space:]')

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    log_error "端口必须是 1-65535 之间的数字"
    exit 1
fi
log_info "使用端口: $PORT"
echo ""

echo "=========================================="
echo "  选择服务监听模式"
echo "=========================================="
echo ""
echo "  [1] 本地监听 (127.0.0.1)"
echo "      - 仅本机可访问"
echo "      - 适合配合 Nginx/Caddy 反向代理使用"
echo ""
echo "  [2] 局域网开放 (0.0.0.0)"
echo "      - 局域网内设备可访问"
echo "      - 需要手动配置防火墙/安全组"
echo ""
echo "  [3] 公网开放 (0.0.0.0)"
echo "      - 直接监听所有网络接口"
echo "      - 服务可直接通过公网 IP:端口 访问"
echo ""

read -p "请选择监听模式 [默认: 1]: " MODE
MODE=$(echo "${MODE:-1}" | tr -d '[:space:]')

case "$MODE" in
    1)
        LISTEN_IP="127.0.0.1"
        MODE_DESC="本地监听"
        ;;
    2)
        LISTEN_IP="0.0.0.0"
        MODE_DESC="局域网开放"
        ;;
    3)
        LISTEN_IP="0.0.0.0"
        MODE_DESC="公网开放"
        ;;
    *)
        log_error "无效选择，使用默认模式: 本地监听"
        LISTEN_IP="127.0.0.1"
        MODE_DESC="本地监听"
        ;;
esac

log_info "监听模式: $MODE_DESC ($LISTEN_IP)"
echo ""

if [ "$MODE" = "2" ] || [ "$MODE" = "3" ]; then
    log_warn "注意: 服务将监听所有网络接口"
    if [ "$MODE" = "2" ]; then
        log_warn "请确保已配置防火墙规则，限制只允许必要端口访问"
    else
        log_warn "建议配合防火墙或安全组使用，限制访问来源"
    fi
    echo ""
fi

log_info "正在安装依赖..."
if ! npm install --legacy-peer-deps 2>&1; then
    log_error "依赖安装失败，正在重试..."
    if ! npm install --legacy-peer-deps --registry=https://registry.npmmirror.com 2>&1; then
        log_error "依赖安装失败，请检查网络连接"
        exit 1
    fi
fi

log_success "依赖安装完成"
echo ""

if [ -f "package.json" ] && grep -q '"start":' package.json 2>/dev/null; then
    ORIGINAL_START=$(grep '"start":' package.json | sed 's/.*"start": *"\([^"]*\)".*/\1/')
    log_info "原始启动命令: $ORIGINAL_START"
fi

update_env_file() {
    local key="$1"
    local value="$2"
    local file=".env"

    if [ ! -f "$file" ]; then
        touch "$file" 2>/dev/null || return 1
    fi

    if grep -q "^${key}=" "$file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file" 2>/dev/null || return 1
    else
        echo "${key}=${value}" >> "$file" 2>/dev/null || return 1
    fi
    return 0
}

update_env_file "PORT" "$PORT"
update_env_file "HOST" "$LISTEN_IP"

export PORT="$PORT"
export HOST="$LISTEN_IP"

log_info "正在启动服务..."
echo ""

nohup npm start > /tmp/rapidrelay.log 2>&1 &
SERVER_PID=$!

sleep 2

if ! kill -0 $SERVER_PID 2>/dev/null; then
    log_error "服务启动失败，查看日志: tail -f /tmp/rapidrelay.log"
    exit 1
fi

LOCAL_IP=$(get_local_ip)

echo ""
echo "=========================================="
echo "  ✅ 服务已成功启动!"
echo "=========================================="
echo ""

if [ "$LISTEN_IP" = "127.0.0.1" ]; then
    echo "  监听地址: localhost:$PORT"
    echo "  本机访问: http://127.0.0.1:$PORT"
    echo "  局域网:  http://$LOCAL_IP:$PORT (需配置反向代理)"
    echo ""
    echo "  🔧 反向代理配置示例 (Nginx):"
    echo "     location / {"
    echo "         proxy_pass http://127.0.0.1:$PORT;"
    echo "         proxy_set_header Host \$host;"
    echo "         proxy_set_header X-Real-IP \$remote_addr;"
    echo "     }"
else
    echo "  监听地址: http://$LISTEN_IP:$PORT"
    echo "  本机访问: http://127.0.0.1:$PORT"
    echo "  局域网:   http://$LOCAL_IP:$PORT"
    echo "  公网访问: http://<你的公网IP>:$PORT"
fi

echo ""
echo "  日志查看: tail -f /tmp/rapidrelay.log"
echo "  进程管理: pm2 logs 或 kill $SERVER_PID"
echo ""
echo "=========================================="
