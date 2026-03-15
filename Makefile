.PHONY: help install install-dev run run-dev test clean docker-build docker-run docker-stop uninstall

# 默认变量
PYTHON := python3
PIP := pip3
VENV := venv
ACTIVATE := $(VENV)/bin/activate

# 颜色定义
BLUE := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

help: ## 显示帮助信息
	@echo "$(BLUE)Nginx Agent API - 可用命令$(RESET)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "$(GREEN)%-20s$(RESET) %s\n", "命令", "说明"} /^[a-zA-Z_-]+:.*?##/ { printf "$(YELLOW)%-20s$(RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ 安装与部署

install: ## 生产环境安装
	@echo "$(GREEN)开始安装Nginx Agent API...$(RESET)"
	sudo bash deploy.sh

install-dev: ## 开发环境安装
	@echo "$(GREEN)开始安装开发环境...$(RESET)"
	@if [ ! -d "$(VENV)" ]; then \
		echo "$(BLUE)创建虚拟环境...$(RESET)"; \
		$(PYTHON) -m venv $(VENV); \
	fi
	@echo "$(BLUE)激活虚拟环境并安装依赖...$(RESET)"
	@. $(ACTIVATE) && $(PIP) install -r requirements.txt
	@echo "$(GREEN)开发环境安装完成！$(RESET)"
	@echo "$(YELLOW)请执行: source $(VENV)/bin/activate 激活虚拟环境$(RESET)"

uninstall: ## 卸载Nginx Agent
	@echo "$(YELLOW)正在卸载Nginx Agent...$(RESET)"
	sudo bash deploy.sh --uninstall

##@ 运行与开发

run: ## 生产环境运行（使用gunicorn）
	@echo "$(BLUE)启动生产服务器...$(RESET)"
	@gunicorn --workers 4 --bind 0.0.0.0:5000 --timeout 60 --access-logfile /var/log/nginx-agent-access.log --error-logfile /var/log/nginx-agent-error.log main:app

run-dev: ## 开发环境运行
	@echo "$(BLUE)启动开发服务器...$(RESET)"
	@if [ -d "$(VENV)" ]; then \
		echo "$(YELLOW)检测到虚拟环境，使用虚拟环境运行$(RESET)"; \
		. $(ACTIVATE) && $(PYTHON) app_v2.py; \
	else \
		$(PYTHON) app_v2.py; \
	fi

test: ## 测试API接口
	@echo "$(BLUE)测试API接口...$(RESET)"
	@bash -c ' \
		if [ -n "$$AUTH_TOKEN" ]; then \
			echo "$(GREEN)使用Token测试认证接口...$(RESET)"; \
			curl -s -H "Authorization: Bearer $$AUTH_TOKEN" http://localhost:5000/api/nginx/status | python3 -m json.tool; \
		else \
			echo "$(YELLOW)未设置AUTH_TOKEN，只测试健康检查接口...$(RESET)"; \
			curl -s http://localhost:5000/api/health | python3 -m json.tool; \
		fi \
	'

##@ Docker操作

docker-build: ## 构建Docker镜像
	@echo "$(BLUE)构建Docker镜像...$(RESET)"
	@docker build -t nginx-agent:latest .

docker-run: ## 运行Docker容器
	@echo "$(GREEN)启动Docker容器...$(RESET)"
	@docker-compose up -d

docker-stop: ## 停止Docker容器
	@echo "$(YELLOW)停止Docker容器...$(RESET)"
	@docker-compose down

docker-logs: ## 查看Docker容器日志
	@echo "$(BLUE)查看容器日志...$(RESET)"
	@docker-compose logs -f

docker-shell: ## 进入Docker容器shell
	@echo "$(BLUE)进入容器shell...$(RESET)"
	@docker exec -it nginx-agent bash

##@ 系统管理

status: ## 查看服务状态
	@echo "$(BLUE)查看Nginx Agent服务状态...$(RESET)"
	@sudo systemctl status nginx-agent || echo "$(RED)服务未运行或未安装$(RESET)"

logs: ## 查看服务日志
	@echo "$(BLUE)查看服务日志...$(RESET)"
	@sudo journalctl -u nginx-agent -f || tail -f /var/log/nginx-agent.log || echo "$(RED)无法查看日志$(RESET)"

restart: ## 重启服务
	@echo "$(YELLOW)重启Nginx Agent服务...$(RESET)"
	@sudo systemctl restart nginx-agent
	@echo "$(GREEN)服务已重启$(RESET)"

stop: ## 停止服务
	@echo "$(YELLOW)停止Nginx Agent服务...$(RESET)"
	@sudo systemctl stop nginx-agent || echo "$(RED)服务未运行$(RESET)"
	@echo "$(GREEN)服务已停止$(RESET)"

##@ 清理

clean: ## 清理临时文件和日志
	@echo "$(YELLOW)清理临时文件...$(RESET)"
	@find . -type f -name "*.pyc" -delete
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)清理完成$(RESET)"

clean-logs: ## 清理日志文件
	@echo "$(YELLOW)清理日志文件...$(RESET)"
	@sudo rm -f /var/log/nginx-agent*.log 2>/dev/null || true
	@sudo rm -f /var/log/nginx-agent-access.log 2>/dev/null || true
	@sudo rm -f /var/log/nginx-agent-error.log 2>/dev/null || true
	@echo "$(GREEN)日志清理完成$(RESET)"

##@ 配置

env-setup: ## 复制环境变量示例文件
	@echo "$(BLUE)创建环境变量配置文件...$(RESET)"
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(GREEN)已创建.env文件，请根据需要修改配置$(RESET)"; \
	else \
		echo "$(YELLOW).env文件已存在，跳过创建$(RESET)"; \
	fi

backup-config: ## 备份Nginx配置
	@echo "$(BLUE)备份Nginx配置...$(RESET)"
	@sudo python3 -c "
import shutil, datetime, os
timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
backup_path = f'/etc/nginx/backup/nginx.conf.{timestamp}'
os.makedirs('/etc/nginx/backup', exist_ok=True)
shutil.copy2('/etc/nginx/nginx.conf', backup_path)
print(f'配置已备份到: {backup_path}')
"
	@echo "$(GREEN)备份完成$(RESET)"

##@ 开发工具

lint: ## 代码检查
	@echo "$(BLUE)执行代码检查...$(RESET)"
	@which flake8 > /dev/null 2>&1 && flake8 *.py || echo "$(YELLOW)flake8未安装，跳过代码检查$(RESET)"

format: ## 代码格式化
	@echo "$(BLUE)执行代码格式化...$(RESET)"
	@which black > /dev/null 2>&1 && black *.py || echo "$(YELLOW)black未安装，跳过代码格式化$(RESET)"

# 变量检查
vars:
	@echo "$(BLUE)当前配置变量：$(RESET)"
	@echo "PYTHON: $(PYTHON)"
	@echo "PIP: $(PIP)"
	@echo "API_PORT: ${API_PORT:-5000}"
	@echo "AUTH_TOKEN: $(if [ -n "$$AUTH_TOKEN" ]; then echo "$$AUTH_TOKEN"; else echo "未设置"; fi)"

.DEFAULT_GOAL := help
