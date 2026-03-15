#!/bin/bash

# Nginx Agent API 部署脚本
# 支持 Ubuntu/Debian 和 CentOS/RHEL

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要使用root权限运行"
        exit 1
    fi
}

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS=$(cat /etc/redhat-release | awk '{print $1}')
        VER=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
    else
        log_error "无法检测操作系统"
        exit 1
    fi
    log_info "检测到操作系统: $OS $VER"
}

# 安装依赖
install_dependencies() {
    log_info "开始安装依赖..."
    
    case "$OS" in
        *"Ubuntu"*|*"Debian"*)
            apt-get update
            apt-get install -y python3 python3-pip python3-venv nginx
            ;;
        *"CentOS"*|*"Red Hat"*)
            yum install -y python3 python3-pip python3-venv nginx
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
    
    log_success "依赖安装完成"
}

# 创建运行目录
create_directories() {
    log_info "创建运行目录..."
    
    mkdir -p /opt/nginx-agent
    mkdir -p /etc/nginx/backup
    mkdir -p /var/log/nginx-agent
    
    # 设置权限
    chmod 755 /etc/nginx/backup
    chmod 755 /var/log/nginx-agent
    
    log_success "目录创建完成"
}

# 复制文件
copy_files() {
    log_info "复制文件..."
    
    # 获取脚本所在目录
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    # 复制文件到目标目录
    cp -r "$SCRIPT_DIR"/* /opt/nginx-agent/
    
    # 设置权限
    chmod +x /opt/nginx-agent/app.py
    chmod +x /opt/nginx-agent/app_v2.py
    chmod +x /opt/nginx-agent/deploy.sh
    
    log_success "文件复制完成"
}

# 安装Python依赖
install_python_deps() {
    log_info "安装Python依赖..."
    
    cd /opt/nginx-agent
    
    # 创建虚拟环境（可选）
    if [ "$USE_VENV" = "true" ]; then
        python3 -m venv venv
        source venv/bin/activate
    fi
    
    # 安装依赖
    pip3 install -r requirements.txt
    
    log_success "Python依赖安装完成"
}

# 配置认证Token
setup_auth() {
    log_info "配置认证Token..."
    
    if [ -z "$AUTH_TOKEN" ]; then
        # 生成随机Token
        AUTH_TOKEN=$(openssl rand -hex 32)
        log_warning "未设置AUTH_TOKEN，生成随机Token: $AUTH_TOKEN"
        log_warning "请妥善保管此Token，后续API调用需要使用"
    fi
    
    # 写入环境变量文件
    cat > /etc/nginx-agent.env << EOF
# Nginx Agent 环境变量
export FLASK_ENV=production
export AUTH_TOKEN=$AUTH_TOKEN
export API_PORT=${API_PORT:-5000}
export NGINX_CONFIG_PATH=${NGINX_CONFIG_PATH:-/etc/nginx/nginx.conf}
export NGINX_BACKUP_DIR=${NGINX_BACKUP_DIR:-/etc/nginx/backup}
export NGINX_PID_PATH=${NGINX_PID_PATH:-/var/run/nginx.pid}
export NGINX_BINARY=${NGINX_BINARY:-/usr/sbin/nginx}
export NGINX_LOG_DIR=${NGINX_LOG_DIR:-/var/log/nginx}
EOF
    
    # 设置权限
    chmod 600 /etc/nginx-agent.env
    
    log_success "认证Token配置完成"
}

# 安装Systemd服务
install_systemd_service() {
    log_info "安装Systemd服务..."
    
    # 修改服务文件中的工作目录
    sed "s|/opt/nginx-agent|/opt/nginx-agent|g" /opt/nginx-agent/nginx-agent.service > /etc/systemd/system/nginx-agent.service
    
    # 重新加载systemd配置
    systemctl daemon-reload
    
    log_success "Systemd服务安装完成"
}

# 配置防火墙
setup_firewall() {
    log_info "配置防火墙..."
    
    # 检查防火墙状态
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian
        if ufw status | grep -q "active"; then
            ufw allow ${API_PORT:-5000}/tcp
            log_success "UFW防火墙规则已添加"
        fi
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL
        if firewall-cmd --state &> /dev/null; then
            firewall-cmd --permanent --add-port=${API_PORT:-5000}/tcp
            firewall-cmd --reload
            log_success "FirewallD规则已添加"
        fi
    else
        log_warning "未检测到支持的防火墙，请手动配置防火墙规则"
    fi
}

# 启动服务
start_service() {
    log_info "启动Nginx Agent服务..."
    
    # 启用服务
    systemctl enable nginx-agent
    
    # 启动服务
    systemctl start nginx-agent
    
    # 检查服务状态
    sleep 3
    if systemctl is-active --quiet nginx-agent; then
        log_success "Nginx Agent服务启动成功"
    else
        log_error "Nginx Agent服务启动失败"
        systemctl status nginx-agent
        exit 1
    fi
}

# 测试API
test_api() {
    log_info "测试API接口..."
    
    sleep 2
    
    # 测试健康检查接口
    response=$(curl -s http://localhost:${API_PORT:-5000}/api/health)
    if echo "$response" | grep -q "healthy"; then
        log_success "API健康检查通过"
    else
        log_error "API健康检查失败: $response"
        exit 1
    fi
    
    # 如果设置了Token，测试认证接口
    if [ -n "$AUTH_TOKEN" ]; then
        response=$(curl -s -H "Authorization: Bearer $AUTH_TOKEN" http://localhost:${API_PORT:-5000}/api/nginx/status)
        if echo "$response" | grep -q "running"; then
            log_success "API认证测试通过"
        else
            log_error "API认证测试失败: $response"
            exit 1
        fi
    fi
}

# 显示信息
show_info() {
    log_success "Nginx Agent API 部署完成！"
    echo
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${GREEN}API地址: http://localhost:${API_PORT:-5000}${NC}"
    echo -e "${GREEN}健康检查: http://localhost:${API_PORT:-5000}/api/health${NC}"
    if [ -n "$AUTH_TOKEN" ]; then
        echo -e "${GREEN}认证Token: $AUTH_TOKEN${NC}"
    fi
    echo -e "${YELLOW}========================================${NC}"
    echo
    echo "管理命令："
    echo "  sudo systemctl start nginx-agent   # 启动服务"
    echo "  sudo systemctl stop nginx-agent    # 停止服务"
    echo "  sudo systemctl restart nginx-agent # 重启服务"
    echo "  sudo systemctl status nginx-agent  # 查看状态"
    echo "  sudo journalctl -u nginx-agent -f  # 查看日志"
    echo
    log_warning "请妥善保管您的认证Token，不要泄露给他人！"
}

# 卸载函数
uninstall() {
    log_info "卸载Nginx Agent..."
    
    # 停止服务
    systemctl stop nginx-agent 2>/dev/null || true
    
    # 禁用服务
    systemctl disable nginx-agent 2>/dev/null || true
    
    # 删除服务文件
    rm -f /etc/systemd/system/nginx-agent.service
    
    # 重新加载systemd
    systemctl daemon-reload
    
    # 删除应用目录
    rm -rf /opt/nginx-agent
    
    # 删除环境变量文件
    rm -f /etc/nginx-agent.env
    
    log_success "Nginx Agent已卸载"
}

# 显示使用帮助
usage() {
    echo "使用方法: $0 [选项]"
    echo
    echo "选项："
    echo "  -h, --help          显示帮助信息"
    echo "  -u, --uninstall     卸载Nginx Agent"
    echo "  -t, --token TOKEN   设置认证Token"
    echo "  -p, --port PORT     设置API端口 (默认: 5000)"
    echo "  --use-venv          使用Python虚拟环境"
    echo
    echo "环境变量："
    echo "  AUTH_TOKEN          认证Token"
    echo "  API_PORT            API端口"
    echo "  NGINX_CONFIG_PATH   Nginx配置路径"
    echo "  NGINX_BACKUP_DIR    备份目录"
    echo "  NGINX_PID_PATH      PID文件路径"
    echo "  NGINX_BINARY        Nginx二进制文件路径"
    echo "  NGINX_LOG_DIR       日志目录"
    echo
    echo "示例："
    echo "  $0                                    # 使用默认配置安装"
    echo "  $0 -t my-secret-token                 # 使用指定Token安装"
    echo "  $0 -p 8080                            # 使用指定端口安装"
    echo "  $0 -u                                 # 卸载"
}

# 主函数
main() {
    # 解析参数
    USE_VENV="false"
    UNINSTALL="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -u|--uninstall)
                UNINSTALL="true"
                shift
                ;;
            -t|--token)
                AUTH_TOKEN="$2"
                shift 2
                ;;
            -p|--port)
                API_PORT="$2"
                shift 2
                ;;
            --use-venv)
                USE_VENV="true"
                shift
                ;;
            *)
                log_error "未知参数: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # 卸载模式
    if [ "$UNINSTALL" = "true" ]; then
        uninstall
        exit 0
    fi
    
    # 检查root权限
    check_root
    
    # 检测操作系统
    detect_os
    
    # 安装流程
    log_info "开始安装Nginx Agent API..."
    echo
    
    install_dependencies
    echo
    
    create_directories
    echo
    
    copy_files
    echo
    
    install_python_deps
    echo
    
    setup_auth
    echo
    
    install_systemd_service
    echo
    
    setup_firewall
    echo
    
    start_service
    echo
    
    test_api
    echo
    
    show_info
}

# 运行主函数
main "$@"
