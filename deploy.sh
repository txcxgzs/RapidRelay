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

setup_nvm() {
    for nvm_dir in "$HOME/.nvm" "/root/.nvm" "/opt/.nvm" "/usr/local/nvm"; do
        if [ -d "$nvm_dir" ]; then
            export NVM_DIR="$nvm_dir"
            if [ -s "$NVM_DIR/nvm.sh" ]; then
                . "$NVM_DIR/nvm.sh" 2>/dev/null
            fi
        fi
    done
    
    for node_dir in "$HOME/.nvm/versions/node" "/root/.nvm/versions/node" "/opt/.nvm/versions/node" "/usr/local/nvm/versions/node"; do
        if [ -d "$node_dir" ]; then
            latest_node=$(ls -t "$node_dir" 2>/dev/null | head -1)
            if [ -n "$latest_node" ] && [ -x "$node_dir/$latest_node/bin/node" ]; then
                export PATH="$node_dir/$latest_node/bin:$PATH"
            fi
        fi
    done
    
    if [ -d "$HOME/.local/bin" ] && [ -x "$HOME/.local/bin/node" ]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi
    if [ -d "/usr/local/bin" ] && [ -x "/usr/local/bin/node" ]; then
        export PATH="/usr/local/bin:$PATH"
    fi
    if [ -d "/opt/node/bin" ] && [ -x "/opt/node/bin/node" ]; then
        export PATH="/opt/node/bin:$PATH"
    fi
}

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

check_running() {
    pgrep -f "node.*server.js" > /dev/null 2>&1
    return $?
}

stop_service() {
    log_info "正在停止服务..."
    pkill -f "node.*server.js" 2>/dev/null
    sleep 1
    if pgrep -f "node.*server.js" > /dev/null 2>&1; then
        pkill -9 -f "node.*server.js" 2>/dev/null
        sleep 1
    fi
    log_success "服务已停止"
}

uninstall_service() {
    echo ""
    echo "=========================================="
    echo "  卸载 RapidRelay"
    echo "=========================================="
    echo ""
    
    read -p "确认要卸载吗？这将停止服务并删除日志文件 (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "已取消卸载"
        return 0
    fi
    
    stop_service
    
    log_info "正在清理日志文件..."
    rm -f /tmp/rapidrelay.log 2>/dev/null
    
    log_warn "提示: 项目文件和 .env 文件未被删除，如需完全移除请手动删除项目目录"
    
    echo ""
    log_success "卸载完成！"
    echo ""
}

install_nodejs() {
    if [ -f "/etc/debian_version" ] || [ -f "/etc/lsb-release" ]; then
        log_info "检测到 Debian/Ubuntu 系统，正在安装 Node.js..."
        apt update 2>/dev/null
        apt install -y curl 2>/dev/null || true
        
        if ! command -v nvm &> /dev/null; then
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash 2>/dev/null || true
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
        fi
        
        nvm install --lts 2>/dev/null || true
        nvm use --lts 2>/dev/null || true
        
    elif [ -f "/etc/redhat-release" ] || [ -f "/etc/centos-release" ] || [ -f "/etc/fedora-release" ]; then
        log_info "检测到 RHEL/CentOS/Fedora 系统，正在安装 Node.js..."
        yum install -y curl 2>/dev/null || dnf install -y curl 2>/dev/null || true
        
        if ! command -v nvm &> /dev/null; then
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash 2>/dev/null || true
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
        fi
        
        nvm install --lts 2>/dev/null || true
        nvm use --lts 2>/dev/null || true
        
    else
        log_info "正在尝试通用安装方式..."
        if ! command -v nvm &> /dev/null; then
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash 2>/dev/null || true
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
        fi
        
        nvm install --lts 2>/dev/null || true
        nvm use --lts 2>/dev/null || true
    fi
    
    echo 'export NVM_DIR="$HOME/.nvm"' >> "$HOME/.bashrc" 2>/dev/null
    echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> "$HOME/.bashrc" 2>/dev/null
}

check_command() {
    for attempt in 1 2 3; do
        if command -v "$1" &> /dev/null; then
            return 0
        fi
        
        if [ "$1" = "node" ] || [ "$1" = "npm" ]; then
            for search_dir in "$HOME/.nvm/versions/node" "/root/.nvm/versions/node" "/opt/.nvm/versions/node" "/usr/local/nvm/versions/node"; do
                if [ -d "$search_dir" ]; then
                    for version_dir in "$search_dir"/*; do
                        if [ -d "$version_dir" ] && [ -x "$version_dir/bin/$1" ]; then
                            export PATH="$version_dir/bin:$PATH"
                        fi
                    done
                fi
            done
        fi
    done
    
    log_error "缺少必需命令: $1"
    return 1
}

install_deps() {
    for registry in "" "--registry=https://registry.npmmirror.com" "--registry=https://registry.npmjs.org" "--registry=https://r.cnpmjs.org"; do
        if [ -z "$registry" ]; then
            log_info "尝试使用默认镜像源..."
        else
            log_info "尝试使用镜像源: $registry"
        fi
        
        if npm install --legacy-peer-deps $registry 2>&1; then
            return 0
        fi
    done
    return 1
}

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

install_or_update_service() {
    local is_update="$1"
    
    echo ""
    echo "=========================================="
    if [ "$is_update" = "true" ]; then
        echo "  更新 RapidRelay"
    else
        echo "  安装 RapidRelay"
    fi
    echo "=========================================="
    echo ""
    
    setup_nvm
    log_info "正在检查环境..."
    
    if ! check_command "node"; then
        log_info "Node.js 未安装，正在自动安装..."
        install_nodejs
        setup_nvm
    fi
    
    if ! check_command "npm"; then
        log_error "npm 未安装"
        exit 1
    fi
    
    log_success "Node.js 版本: $(node -v)"
    log_success "npm 版本: $(npm -v)"
    
    echo ""
    
    DEFAULT_PORT=3000
    if [ -f ".env" ]; then
        SAVED_PORT=$(grep "^PORT=" .env | cut -d= -f2 2>/dev/null)
        if [ -n "$SAVED_PORT" ]; then
            DEFAULT_PORT="$SAVED_PORT"
        fi
    fi
    
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
    
    if [ "$is_update" = "true" ]; then
        stop_service
    fi
    
    log_info "正在安装依赖..."
    
    if ! install_deps; then
        log_error "依赖安装失败，请检查网络连接"
        log_info "您也可以尝试手动执行: npm install"
        exit 1
    fi
    
    log_success "依赖安装完成"
    
    echo ""
    
    update_env_file "PORT" "$PORT"
    update_env_file "HOST" "$LISTEN_IP"
    
    export PORT="$PORT"
    export HOST="$LISTEN_IP"
    
    log_info "正在启动服务..."
    echo ""
    
    nohup npm start > /tmp/rapidrelay.log 2>&1 &
    SERVER_PID=$!
    
    sleep 3
    
    if pgrep -f "node.*server.js" > /dev/null; then
        log_success "服务启动成功！"
    else
        log_error "服务启动失败，查看日志: tail -f /tmp/rapidrelay.log"
        if [ -f /tmp/rapidrelay.log ]; then
            echo ""
            log_warn "最近的错误日志:"
            tail -20 /tmp/rapidrelay.log
        fi
        exit 1
    fi
    
    LOCAL_IP=$(get_local_ip)
    
    echo ""
    echo "=========================================="
    echo "  ✅ 部署成功！"
    echo "=========================================="
    echo ""
    
    if [ "$LISTEN_IP" = "127.0.0.1" ]; then
        echo "  监听地址: localhost:$PORT"
        echo "  本机访问: http://127.0.0.1:$PORT"
        echo "  局域网:   http://$LOCAL_IP:$PORT (需配置反向代理)"
        echo ""
        echo "  🔧 反向代理配置示例 (Nginx):"
        echo "     location / {"
        echo "         proxy_pass http://127.0.0.1:$PORT;"
        echo "         proxy_set_header Host \$host;"
        echo "         proxy_set_header X-Real-IP \$remote_addr;"
        echo "         proxy_set_header X-Forwarded-Proto \$scheme;"
        echo "         proxy_set_header X-Forwarded-Host \$host;"
        echo "     }"
    else
        echo "  监听地址: http://$LISTEN_IP:$PORT"
        echo "  本机访问: http://127.0.0.1:$PORT"
        echo "  局域网:   http://$LOCAL_IP:$PORT"
        echo "  公网访问: http://<你的公网IP>:$PORT"
    fi
    
    echo ""
    echo "  日志查看: tail -f /tmp/rapidrelay.log"
    echo "  进程 PID: $SERVER_PID"
    echo ""
    echo "=========================================="
}

echo ""
echo "=========================================="
echo "  RapidRelay 部署脚本"
echo "=========================================="
echo ""

setup_nvm

if check_running; then
    log_warn "检测到 RapidRelay 服务正在运行"
    echo ""
    echo "请选择操作:"
    echo "  [1] 更新 - 停止旧服务并重新启动"
    echo "  [2] 卸载 - 停止服务并清理"
    echo "  [3] 取消"
    echo ""
    
    read -p "请选择 [默认: 1]: " choice
    choice=$(echo "${choice:-1}" | tr -d '[:space:]')
    
    case "$choice" in
        1)
            install_or_update_service "true"
            ;;
        2)
            uninstall_service
            ;;
        3)
            log_info "已取消操作"
            exit 0
            ;;
        *)
            log_error "无效选择"
            exit 1
            ;;
    esac
else
    log_info "未检测到运行中的服务，将执行安装"
    install_or_update_service "false"
fi
