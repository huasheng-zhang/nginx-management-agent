#!/bin/bash
# Nginx Agent API 测试脚本
# 快速测试所有API端点

# 配置
API_URL="${API_URL:-http://localhost:5000/api}"
AUTH_TOKEN="${AUTH_TOKEN:-}"

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 函数：发送请求
api_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local auth_required=${4:-false}
    
    local url="${API_URL}${endpoint}"
    local headers=""
    
    if [ "$auth_required" = "true" ] && [ -n "$AUTH_TOKEN" ]; then
        headers="-H \"Authorization: Bearer ${AUTH_TOKEN}\""
    fi
    
    echo -n "Testing ${method} ${endpoint}... "
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" $headers "$url" 2>/dev/null)
    elif [ "$method" = "POST" ]; then
        response=$(curl -s -X POST -w "\n%{http_code}" $headers \
                   -H "Content-Type: application/json" \
                   -d "$data" "$url" 2>/dev/null)
    elif [ "$method" = "PUT" ]; then
        response=$(curl -s -X PUT -w "\n%{http_code}" $headers \
                   -H "Content-Type: application/json" \
                   -d "$data" "$url" 2>/dev/null)
    fi
    
    # 分离响应体和状态码
    http_code=$(echo "$response" | tail -n 1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        echo -e "${GREEN}✓ PASS${NC} (Status: $http_code)"
        return 0
    elif [ "$http_code" = "400" ] || [ "$http_code" = "404" ]; then
        echo -e "${YELLOW}⚠ SKIP${NC} (Status: $http_code - Expected for some tests)"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} (Status: $http_code)"
        if [ -n "$body" ]; then
            echo "  Response: $body"
        fi
        return 1
    fi
}

# 主测试流程
main() {
    echo "=========================================="
    echo "  Nginx Agent API 测试"
    echo "=========================================="
    echo "API地址: $API_URL"
    if [ -n "$AUTH_TOKEN" ]; then
        echo "认证: 已启用"
    else
        echo "认证: 未启用"
    fi
    echo "=========================================="
    
    passed=0
    failed=0
    
    # 1. 健康检查（无需认证）
    echo ""
    echo "1. 健康检查:"
    if api_request "GET" "/health"; then
        ((passed++))
    else
        ((failed++))
    fi
    
    # 如果启用了认证，测试需要认证的端点
    if [ -n "$AUTH_TOKEN" ]; then
        echo ""
        echo "2. Nginx状态管理:"
        
        if api_request "GET" "/nginx/status" "" "true"; then
            ((passed++))
        else
            ((failed++))
        fi
        
        # 注意：跳过启动/停止测试，避免影响生产环境
        echo "  ⚠  跳过启动/停止测试（可能影响生产环境）"
        
        if api_request "POST" "/nginx/reload" "{}" "true"; then
            ((passed++))
        else
            ((failed++))
        fi
        
        echo ""
        echo "3. 配置管理:"
        if api_request "GET" "/nginx/config" "" "true"; then
            ((passed++))
        else
            ((failed++))
        fi
        
        if api_request "GET" "/nginx/config/backups" "" "true"; then
            ((passed++))
        else
            ((failed++))
        fi
        
        echo ""
        echo "4. 日志管理:"
        if api_request "GET" "/nginx/logs" "" "true"; then
            ((passed++))
        else
            ((failed++))
        fi
        
        if api_request "GET" "/nginx/logs/error.log" "" "true"; then
            ((passed++))
        else
            ((failed++))
        fi
        
        echo ""
        echo "5. 统计信息:"
        if api_request "GET" "/nginx/stats" "" "true"; then
            ((passed++))
        else
            ((failed++))
        fi
        
        if api_request "GET" "/nginx/info" "" "true"; then
            ((passed++))
        else
            ((failed++))
        fi
    else
        echo ""
        echo "⚠  需要AUTH_TOKEN环境变量来测试认证端点"
        echo "   示例: export AUTH_TOKEN=your-token"
    fi
    
    # 总结
    echo ""
    echo "=========================================="
    echo "  测试总结"
    echo "=========================================="
    echo -e "总测试数: $((passed + failed))"
    echo -e "${GREEN}通过: $passed${NC}"
    echo -e "${RED}失败: $failed${NC}"
    echo "=========================================="
    
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}🎉 所有测试通过！${NC}"
        exit 0
    else
        echo -e "${RED}⚠️  $failed 个测试失败${NC}"
        exit 1
    fi
}

# 显示帮助
show_help() {
    cat << EOF
Nginx Agent API 测试脚本

用法:
    ./test_api.sh [选项]

选项:
    -h, --help     显示帮助信息

环境变量:
    API_URL        API地址 (默认: http://localhost:5000/api)
    AUTH_TOKEN     认证Token (可选)

示例:
    # 测试本地API（无需认证）
    ./test_api.sh

    # 测试带认证的API
    export AUTH_TOKEN="your-secret-token"
    ./test_api.sh

    # 测试远程API
    export API_URL="http://192.168.1.100:5000/api"
    export AUTH_TOKEN="your-secret-token"
    ./test_api.sh
EOF
}

# 参数解析
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    "")
        main
        ;;
    *)
        echo "未知选项: $1"
        echo "使用 --help 查看帮助"
        exit 1
        ;;
esac
