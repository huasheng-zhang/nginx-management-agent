# Nginx Agent API

Nginx Agent API 是一个部署在各Nginx节点上的轻量级Agent服务，提供RESTful API接口用于管理Nginx配置、监控状态、查看日志等操作。

## 功能特性

- ✅ **配置管理**：获取、更新、备份、恢复Nginx配置文件
- ✅ **状态监控**：实时监控Nginx运行状态、系统资源使用情况
- ✅ **服务控制**：启动、停止、重载Nginx服务
- ✅ **日志查看**：查看Nginx访问日志和错误日志
- ✅ **安全认证**：支持Token认证机制
- ✅ **配置备份**：自动备份配置，支持版本回滚

## API 接口文档

### 1. 健康检查

```http
GET /api/health
```

**响应示例：**
```json
{
  "status": "healthy",
  "timestamp": "2026-03-14T10:30:00",
  "nginx_running": true
}
```

### 2. 获取Nginx状态

```http
GET /api/nginx/status
Authorization: Bearer your-auth-token (如果需要认证)
```

**响应示例：**
```json
{
  "running": true,
  "pid": 12345,
  "version": "nginx version: nginx/1.21.0",
  "config_path": "/etc/nginx/nginx.conf",
  "system_info": {
    "cpu_usage": "12.5%",
    "memory_usage": "45.2%",
    "memory_total": "8GB",
    "load_average": [0.5, 0.6, 0.7]
  },
  "timestamp": "2026-03-14T10:30:00"
}
```

### 3. 获取Nginx配置

```http
GET /api/nginx/config
Authorization: Bearer your-auth-token
```

**响应示例：**
```json
{
  "path": "/etc/nginx/nginx.conf",
  "content": "... nginx配置内容 ...",
  "size": 2048,
  "modified_time": "2026-03-14T09:00:00",
  "backup_dir": "/etc/nginx/backup"
}
```

### 4. 更新Nginx配置

```http
PUT /api/nginx/config
Authorization: Bearer your-auth-token
Content-Type: application/json

{
  "content": "... 新的nginx配置内容 ...",
  "backup": true,
  "test": true
}
```

**参数说明：**
- `content` (required): Nginx配置内容
- `backup` (optional): 是否在更新前备份，默认为true
- `test` (optional): 是否测试配置有效性，默认为true

**响应示例：**
```json
{
  "success": true,
  "message": "Configuration updated successfully",
  "backup_path": "/etc/nginx/backup/nginx.conf.20260314_103000",
  "tested": true
}
```

### 5. 重载Nginx配置

```http
POST /api/nginx/reload
Authorization: Bearer your-auth-token
```

**响应示例：**
```json
{
  "success": true,
  "message": "Nginx reloaded successfully"
}
```

### 6. 启动Nginx

```http
POST /api/nginx/start
Authorization: Bearer your-auth-token
```

**响应示例：**
```json
{
  "success": true,
  "message": "Nginx started successfully"
}
```

### 7. 停止Nginx

```http
POST /api/nginx/stop
Authorization: Bearer your-auth-token
```

**响应示例：**
```json
{
  "success": true,
  "message": "Nginx stopped successfully"
}
```

### 8. 列出配置备份

```http
GET /api/nginx/config/backups
Authorization: Bearer your-auth-token
```

**响应示例：**
```json
{
  "backups": [
    {
      "filename": "nginx.conf.20260314_103000",
      "path": "/etc/nginx/backup/nginx.conf.20260314_103000",
      "size": 2048,
      "created_time": "2026-03-14T10:30:00"
    }
  ],
  "backup_dir": "/etc/nginx/backup"
}
```

### 9. 恢复备份配置

```http
POST /api/nginx/config/backups/{filename}/restore
Authorization: Bearer your-auth-token
```

**响应示例：**
```json
{
  "success": true,
  "message": "Configuration restored from nginx.conf.20260314_103000",
  "previous_config_backup": "/etc/nginx/backup/nginx.conf.20260314_103500"
}
```

### 10. 获取日志文件列表

```http
GET /api/nginx/logs
Authorization: Bearer your-auth-token
```

**响应示例：**
```json
{
  "log_files": [
    {
      "filename": "access.log",
      "path": "/var/log/nginx/access.log",
      "size": 1048576,
      "modified_time": "2026-03-14T10:30:00"
    },
    {
      "filename": "error.log",
      "path": "/var/log/nginx/error.log",
      "size": 524288,
      "modified_time": "2026-03-14T10:25:00"
    }
  ]
}
```

### 11. 查看日志内容

```http
GET /api/nginx/logs/{logname}?lines=100
Authorization: Bearer your-auth-token
```

**参数说明：**
- `lines` (optional): 显示最后几行，默认为100

**响应示例：**
```json
{
  "logname": "access.log",
  "path": "/var/log/nginx/access.log",
  "content": "... 日志内容 ...",
  "lines": 100
}
```

### 12. 获取系统统计信息

```http
GET /api/nginx/stats
Authorization: Bearer your-auth-token
```

**响应示例：**
```json
{
  "timestamp": "2026-03-14T10:30:00",
  "nginx_running": true,
  "pid": 12345,
  "system": {
    "cpu_count": 4,
    "cpu_percent": 12.5,
    "memory": {
      "total": 8589934592,
      "available": 4718592000,
      "percent": 45.2,
      "used": 3871342592
    },
    "disk": {
      "/": {
        "total": 107374182400,
        "used": 53687091200,
        "free": 53687091200,
        "percent": 50.0
      }
    }
  },
  "nginx_processes": [
    {
      "pid": 12345,
      "cpu_percent": 2.1,
      "memory_rss": 10240000
    }
  ]
}
```

### 13. 获取Nginx详细信息

```http
GET /api/nginx/info
Authorization: Bearer your-auth-token
```

**响应示例：**
```json
{
  "config_path": "/etc/nginx/nginx.conf",
  "binary_path": "/usr/sbin/nginx",
  "pid_path": "/var/run/nginx.pid",
  "backup_dir": "/etc/nginx/backup",
  "log_dir": "/var/log/nginx",
  "running": true,
  "pid": 12345,
  "version": "nginx version: nginx/1.21.0",
  "configure_args": "--prefix=/etc/nginx --sbin-path=/usr/sbin/nginx",
  "modules": ["ssl", "v2", "realip", "addition", "sub"]
}
```

## 部署指南

### 环境要求

- Python 3.7+
- Nginx
- Linux操作系统（推荐Ubuntu/CentOS）

### 安装步骤

1. **安装依赖**

```bash
# 安装Python依赖
pip install -r requirements.txt

# 或使用系统包管理器安装gunicorn（生产环境推荐）
# Ubuntu/Debian
sudo apt-get install gunicorn

# CentOS/RHEL
sudo yum install gunicorn
```

2. **配置文件权限**

Agent需要读取Nginx配置和日志文件，建议以root用户运行或使用sudo。

```bash
# 创建日志目录
sudo mkdir -p /var/log/nginx-agent
sudo mkdir -p /etc/nginx/backup

# 设置权限
sudo chmod 755 /etc/nginx/backup
sudo chmod 755 /var/log/nginx-agent
```

3. **配置环境变量（可选）**

```bash
# 编辑环境变量文件
sudo nano /etc/environment

# 添加以下内容
export FLASK_ENV=production
export AUTH_TOKEN=your-secure-token-here
export API_PORT=5000
```

4. **运行应用**

**开发环境：**
```bash
python app.py
```

**生产环境（推荐）：**
```bash
# 使用gunicorn运行
gunicorn --workers 4 --bind 0.0.0.0:5000 --timeout 60 --access-logfile /var/log/nginx-agent-access.log --error-logfile /var/log/nginx-agent-error.log main:app
```

5. **配置为系统服务（推荐）**

```bash
# 复制服务文件
sudo cp nginx-agent.service /etc/systemd/system/

# 重新加载systemd配置
sudo systemctl daemon-reload

# 启动服务
sudo systemctl start nginx-agent

# 设置开机自启
sudo systemctl enable nginx-agent

# 查看服务状态
sudo systemctl status nginx-agent
```

### 安全配置

#### 启用认证

1. **生成安全Token**

```bash
# 生成随机Token
openssl rand -hex 32
```

2. **配置Token**

可以通过以下方式配置认证Token：

- 环境变量：
```bash
export AUTH_TOKEN=your-generated-token
```

- 在config.py中设置：
```python
AUTH_TOKEN = 'your-generated-token'
```

3. **在请求中使用Token**

```http
GET /api/nginx/status
Authorization: Bearer your-generated-token
```

#### 防火墙配置

```bash
# 仅允许特定IP访问（示例）
sudo ufw allow from 192.168.1.0/24 to any port 5000

# 或仅允许本地访问
sudo ufw allow from 127.0.0.1 to any port 5000
```

### Docker部署（可选）

1. **创建Dockerfile**

```dockerfile
FROM python:3.9-slim

RUN apt-get update && apt-get install -y \
    nginx \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["gunicorn", "--workers", "4", "--bind", "0.0.0.0:5000", "--timeout", "60", "main:app"]
```

2. **构建镜像**

```bash
docker build -t nginx-agent .
```

3. **运行容器**

```bash
docker run -d \
  --name nginx-agent \
  --network host \
  -v /etc/nginx:/etc/nginx \
  -v /var/log/nginx:/var/log/nginx \
  -e AUTH_TOKEN=your-token \
  nginx-agent
```

### 监控和日志

#### 应用日志

- 主日志：`/var/log/nginx-agent.log`
- 访问日志：`/var/log/nginx-agent-access.log`
- 错误日志：`/var/log/nginx-agent-error.log`

#### 监控服务状态

```bash
# 查看systemd服务状态
sudo systemctl status nginx-agent

# 查看实时日志
sudo tail -f /var/log/nginx-agent.log

# 查看gunicorn访问日志
sudo tail -f /var/log/nginx-agent-access.log
```

### 故障排查

#### 常见问题

1. **权限问题**
   - 确保Agent有足够的权限访问Nginx配置文件和日志
   - 建议以root用户运行或使用sudo

2. **端口冲突**
   - 默认端口为5000，可以通过`API_PORT`环境变量修改

3. **Nginx命令找不到**
   - 确保Nginx在系统PATH中，或在config.py中正确配置`NGINX_BINARY`路径

4. **配置测试失败**
   - 检查配置文件的语法是否正确
   - 查看返回的错误详情

#### 调试模式

```bash
# 开发环境启用调试模式
export FLASK_ENV=development
export DEBUG=True
python app.py
```

### 性能优化

#### Gunicorn配置

```bash
# 根据CPU核心数调整workers数量
workers = multiprocessing.cpu_count() * 2 + 1

# 使用gevent worker（高并发场景）
gunicorn --worker-class gevent --workers 8 --bind 0.0.0.0:5000 main:app
```

#### 系统参数调优

```bash
# 增加文件描述符限制
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

# 增加端口范围
echo "net.ipv4.ip_local_port_range = 1024 65535" >> /etc/sysctl.conf
sysctl -p
```

## API调用示例

### Python示例

```python
import requests

API_URL = "http://your-nginx-node:5000/api"
AUTH_TOKEN = "your-token"

headers = {
    "Authorization": f"Bearer {AUTH_TOKEN}"
}

# 获取状态
response = requests.get(f"{API_URL}/nginx/status", headers=headers)
print(response.json())

# 更新配置
with open("nginx.conf", "r") as f:
    config_content = f.read()

response = requests.put(
    f"{API_URL}/nginx/config",
    headers=headers,
    json={
        "content": config_content,
        "backup": True,
        "test": True
    }
)
print(response.json())

# 重载Nginx
response = requests.post(f"{API_URL}/nginx/reload", headers=headers)
print(response.json())
```

### curl示例

```bash
# 获取状态
curl -H "Authorization: Bearer your-token" http://localhost:5000/api/nginx/status

# 更新配置
curl -X PUT -H "Authorization: Bearer your-token" \
  -H "Content-Type: application/json" \
  -d '{"content": "..."}' \
  http://localhost:5000/api/nginx/config

# 重载Nginx
curl -X POST -H "Authorization: Bearer your-token" \
  http://localhost:5000/api/nginx/reload
```

## 许可证

MIT License

## 贡献

欢迎提交Issue和Pull Request！

## 联系方式

如有问题，请联系：your-email@example.com
