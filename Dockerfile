# Nginx Agent API Dockerfile
FROM python:3.9-slim

# 安装Nginx和必要工具
RUN apt-get update && apt-get install -y \
    nginx \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 创建应用目录
WORKDIR /app

# 复制依赖文件
COPY requirements.txt .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY . .

# 创建必要目录
RUN mkdir -p /etc/nginx/backup /var/log/nginx-agent

# 设置权限
RUN chmod +x /app/app.py /app/app_v2.py /app/deploy.sh

# 暴露端口
EXPOSE 5000

# 环境变量
ENV FLASK_ENV=production
ENV PYTHONPATH=/app

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/api/health || exit 1

# 启动应用
CMD ["gunicorn", "--workers", "4", "--bind", "0.0.0.0:5000", "--timeout", "60", "--access-logfile", "-", "--error-logfile", "-", "main:app"]
