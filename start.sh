#!/bin/bash

# Nginx Agent API 快速启动脚本
# 支持开发环境和生产环境

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 变量
ENV=${1:-production}
PORT=${API_PORT:-5000}

# 显示使用说明
usage() {
    echo "使用方法: $0 [environment]"
    echo
    echo "参数："
    echo "  production    生产环境 (默认)"
    echo "  development   开发环境"
    echo "  help          显示帮助"
    echo
    echo "环境变量："
    echo "  API_PORT      API端口 (默认: 5000)"
    echo "  AUTH_TOKEN    认证Token"
}

# 检查依赖
check_dependencies() {
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}错误: 未找到python3${NC}"
        exit 1
    fi
    
    if ! command -v gunicorn &> /dev/null && [ "$ENV" = "production" ]; then
        echo -e "${YELLOW}警告: 未找到gunicorn，请先安装: pip install gunicorn${NC}"
        exit 1
    fi
}

# 检查Nginx
check_nginx() {
    if ! command -v nginx &> /dev/null; then
        echo -e "${YELLOW}警告: 未找到nginx，请确保nginx已安装${NC}"
    else
        echo -e "${GREEN}✓ Nginx已安装: $(nginx -v 2>&1)${NC}"
    fi
}

# 检查配置文件
check_config() {
    if [ ! -f "/etc/nginx/nginx.conf" ]; then
        echo -e "${YELLOW}警告: Nginx配置文件不存在: /etc/nginx/nginx.conf${NC}"
    else
        echo -e "${GREEN}✓ Nginx配置文件存在${NC}"
    fi
}

# 生产环境启动
start_production() {
    echo -e "${BLUE}启动生产环境...${NC}"
    echo -e "${BLUE}API端口: $PORT${NC}"
    
    # 检查是否需要认证
    if [ -n "$AUTH_TOKEN" ]; then
        echo -e "${GREEN}✓ 已启用Token认证${NC}"
    else
        echo -e "${YELLOW}警告: 未设置AUTH_TOKEN，建议设置以增强安全性${NC}"
    fi
    
    # 使用gunicorn启动
    echo -e "${BLUE}使用gunicorn启动服务器...${NC}"
    exec gunicorn \
        --workers 4 \
        --bind 0.0.0.0:$PORT \
        --timeout 60 \
        --access-logfile - \
        --error-logfile - \
        main:app
}

# 开发环境启动
start_development() {
    echo -e "${BLUE}启动开发环境...${NC}"
    echo -e "${BLUE}API端口: $PORT${NC}"
    echo -e "${YELLOW}开发模式已启用，请勿在生产环境使用${NC}"
    
    # 设置开发环境变量
    export FLASK_ENV=development
    export DEBUG=True
    
    # 使用Flask内置服务器启动
    echo -e "${BLUE}使用Flask开发服务器启动...${NC}"
    exec python3 app_v2.py
}

# 主函数
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Nginx Agent API 启动程序${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    
    # 检查依赖
    check_dependencies
    
    # 检查Nginx
    check_nginx
    
    # 检查配置文件
    check_config
    
    echo
    
    case $ENV in
        production|prod)
            start_production
            ;;
        development|dev)
            start_development
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo -e "${RED}错误: 未知的环境: $ENV${NC}"
            usage
            exit 1
            ;;
    esac
}

# 显示欢迎信息
echo -e "${GREEN}Nginx Agent API${NC}"
echo -e "${YELLOW}按 Ctrl+C 停止服务${NC}"
echo

# 运行主函数
trap 'echo -e "\n${YELLOW}服务已停止${NC}"; exit 0' SIGINT SIGTERM
main "$@"
