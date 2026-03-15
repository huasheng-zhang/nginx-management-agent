# Nginx Agent API 文档

## 目录
1. [概述](#概述)
2. [版本信息](#版本信息)
3. [快速开始](#快速开始)
4. [认证与安全](#认证与安全)
5. [API端点](#api端点)
   - [健康检查](#健康检查)
   - [Nginx状态管理](#nginx状态管理)
   - [配置管理](#配置管理)
   - [日志管理](#日志管理)
   - [监控统计](#监控统计)
6. [请求/响应格式](#请求响应格式)
7. [错误处理](#错误处理)
8. [配置说明](#配置说明)
9. [部署指南](#部署指南)

## 概述

Nginx Agent API 是一个部署在各Nginx节点上的Agent服务，提供Nginx配置管理、状态监控、日志查看等功能。该API允许远程管理Nginx实例，支持配置文件的增删改查、Nginx进程控制、日志查看以及系统监控。

### 主要特性

- **配置管理**：获取、更新、备份和恢复Nginx配置文件
- **进程控制**：启动、停止、重载Nginx服务
- **日志查看**：实时查看Nginx访问日志和错误日志
- **状态监控**：获取Nginx运行状态、系统资源使用情况
- **安全管理**：支持Token认证和CORS配置
- **配置灵活**：支持环境变量和配置文件管理

## 版本信息

### v1.0 (app.py)
- 单体架构，所有功能在一个文件中实现
- 基础API端点
- 简单日志记录
- 固定配置路径

### v2.0 (app_v2.py + main.py + config.py)
- 模块化架构，使用Flask Blueprint
- 增强的配置管理（支持多环境）
- 改进的安全机制（CORS限制、Token认证）
- 结构化日志记录
- 环境变量支持

## 快速开始

### 启动API服务

**方式1：直接运行**
```bash
python app.py
```

**方式2：使用gunicorn（生产环境推荐）**
```bash
gunicorn -w 4 -b 0.0.0.0:5000 app:app
```

**方式3：运行v2版本**
```bash
python app_v2.py
```

### API基础信息

- **默认端口**: 5000
- **基础URL**: `http://localhost:5000/api`
- **Content-Type**: `application/json`

### 第一个API调用

```bash
# 健康检查
curl http://localhost:5000/api/health
```

预期响应：
```json
{
  "status": "healthy",
  "timestamp": "2026-03-15T12:00:00",
  "nginx_running": true
}
```

## 认证与安全

### Token认证（v2版本）

v2版本支持可选的Token认证机制。

**启用认证**

设置环境变量：
```bash
export AUTH_TOKEN="your-secret-token"
```

**在请求中使用Token**

```bash
curl -H "Authorization: Bearer your-secret-token" \
     http://localhost:5000/api/nginx/status
```

### CORS配置

**v1版本**
- 默认允许所有来源：`*`

**v2版本**
- 可配置允许的源：
```bash
export ALLOWED_ORIGINS="http://localhost:3000,https://admin.example.com"
```

### 安全最佳实践

1. **生产环境**务必设置`AUTH_TOKEN`
2. 限制`ALLOWED_ORIGINS`到特定的管理域名
3. 使用HTTPS传输敏感数据
4. 定期轮换认证Token
5. 配置防火墙限制API访问IP

## API端点

### 健康检查

#### GET /api/health

检查API服务和Nginx状态。

**请求参数**：无

**响应示例**：
```json
{
  "status": "healthy",
  "timestamp": "2026-03-15T12:00:00",
  "nginx_running": true
}
```

**状态说明**：
- `status`: API服务状态 (`healthy`/`unhealthy`)
- `nginx_running`: Nginx进程运行状态

---

### Nginx状态管理

#### GET /api/nginx/status

获取Nginx详细状态信息。

**认证要求**：v2版本需要Token

**响应示例**：
```json
{
  "running": true,
  "pid": 12345,
  "version": "nginx/1.18.0",
  "config_path": "/etc/nginx/nginx.conf",
  "system_info": {
    "cpu_usage": "15.3%",
    "memory_usage": "45.2%",
    "memory_total": "8GB",
    "load_average": [0.5, 0.6, 0.7]
  },
  "timestamp": "2026-03-15T12:00:00"
}
```

**字段说明**：
- `running`: Nginx是否正在运行
- `pid`: Nginx主进程ID
- `version`: Nginx版本信息
- `system_info`: 系统资源使用情况

#### POST /api/nginx/start

启动Nginx服务。

**认证要求**：需要Token

**请求体**：无

**响应示例**：
```json
{
  "success": true,
  "message": "Nginx started successfully"
}
```

**错误响应**：
```json
{
  "error": "Nginx is already running"
}
```

#### POST /api/nginx/stop

停止Nginx服务。

**认证要求**：需要Token

**请求体**：无

**响应示例**：
```json
{
  "success": true,
  "message": "Nginx stopped successfully"
}
```

#### POST /api/nginx/reload

重载Nginx配置（不中断服务）。

**认证要求**：需要Token

**请求体**：无

**响应示例**：
```json
{
  "success": true,
  "message": "Nginx reloaded successfully"
}
```

**说明**：重载配置前会先测试配置文件的语法正确性。

---

### 配置管理

#### GET /api/nginx/config

获取当前Nginx配置文件内容。

**认证要求**：v2版本需要Token

**响应示例**：
```json
{
  "path": "/etc/nginx/nginx.conf",
  "content": "user nginx;\nworker_processes auto;\n...",
  "size": 2048,
  "modified_time": "2026-03-15T10:30:00",
  "backup_dir": "/etc/nginx/backup"
}
```

#### PUT /api/nginx/config

更新Nginx配置文件。

**认证要求**：需要Token

**请求参数**：
```json
{
  "content": "new nginx configuration content",
  "backup": true,
  "test": true
}
```

**参数说明**：
- `content`: 新的Nginx配置内容（必需）
- `backup`: 是否备份当前配置（可选，默认true）
- `test`: 是否测试配置语法（可选，默认true）

**响应示例**：
```json
{
  "success": true,
  "message": "Configuration updated successfully",
  "backup_path": "/etc/nginx/backup/nginx.conf.20260315_120000",
  "tested": true
}
```

**错误响应**（配置测试失败）：
```json
{
  "error": "Nginx configuration test failed",
  "details": "nginx: [emerg] unexpected '}' in /tmp/nginx_test.conf:10"
}
```

#### GET /api/nginx/config/backups

列出所有配置备份文件。

**认证要求**：v2版本需要Token

**响应示例**：
```json
{
  "backups": [
    {
      "filename": "nginx.conf.20260315_120000",
      "path": "/etc/nginx/backup/nginx.conf.20260315_120000",
      "size": 2048,
      "created_time": "2026-03-15T12:00:00"
    },
    {
      "filename": "nginx.conf.20260314_110000",
      "path": "/etc/nginx/backup/nginx.conf.20260314_110000",
      "size": 2048,
      "created_time": "2026-03-14T11:00:00"
    }
  ],
  "backup_dir": "/etc/nginx/backup"
}
```

#### GET /api/nginx/config/backups/{filename}

获取指定备份文件的内容。

**认证要求**：v2版本需要Token

**路径参数**：
- `filename`: 备份文件名（例如：`nginx.conf.20260315_120000`）

**响应示例**：
```json
{
  "filename": "nginx.conf.20260315_120000",
  "content": "user nginx;\nworker_processes auto;\n..."
}
```

#### POST /api/nginx/config/backups/{filename}/restore

从备份文件恢复配置。

**认证要求**：v2版本需要Token

**路径参数**：
- `filename`: 备份文件名

**响应示例**：
```json
{
  "success": true,
  "message": "Configuration restored from nginx.conf.20260315_120000",
  "previous_config_backup": "/etc/nginx/backup/nginx.conf.20260315_120100"
}
```

---

### 日志管理

#### GET /api/nginx/logs

获取Nginx日志文件列表。

**认证要求**：v2版本需要Token

**响应示例**：
```json
{
  "log_files": [
    {
      "filename": "access.log",
      "path": "/var/log/nginx/access.log",
      "size": 1048576,
      "modified_time": "2026-03-15T12:00:00"
    },
    {
      "filename": "error.log",
      "path": "/var/log/nginx/error.log",
      "size": 524288,
      "modified_time": "2026-03-15T11:55:00"
    }
  ]
}
```

#### GET /api/nginx/logs/{logname}

查看指定日志文件的内容。

**认证要求**：v2版本需要Token

**路径参数**：
- `logname`: 日志文件名（例如：`access.log`）

**查询参数**：
- `lines`: 显示的行数（可选，默认100）

**响应示例**：
```json
{
  "logname": "access.log",
  "path": "/var/log/nginx/access.log",
  "content": "192.168.1.100 - - [15/Mar/2026:12:00:00 +0800] \"GET /api/health HTTP/1.1\" 200 50\n192.168.1.101 - - [15/Mar/2026:12:00:01 +0800] \"POST /api/nginx/reload HTTP/1.1\" 200 45",
  "lines": 100
}
```

**说明**：返回日志文件的最后N行内容。

---

### 监控统计

#### GET /api/nginx/stats

获取Nginx和系统的详细统计信息。

**认证要求**：v2版本需要Token

**响应示例**：
```json
{
  "timestamp": "2026-03-15T12:00:00",
  "nginx_running": true,
  "pid": 12345,
  "system": {
    "cpu_count": 4,
    "cpu_percent": 15.3,
    "memory": {
      "total": 8589934592,
      "available": 4724464025,
      "percent": 45.0,
      "used": 3865470567
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
    },
    {
      "pid": 12346,
      "cpu_percent": 1.8,
      "memory_rss": 8192000
    }
  ]
}
```

#### GET /api/nginx/info

获取Nginx的详细信息。

**认证要求**：v2版本需要Token

**响应示例**：
```json
{
  "config_path": "/etc/nginx/nginx.conf",
  "binary_path": "/usr/sbin/nginx",
  "pid_path": "/var/run/nginx.pid",
  "backup_dir": "/etc/nginx/backup",
  "log_dir": "/var/log/nginx",
  "running": true,
  "pid": 12345,
  "version": "nginx/1.18.0 (Ubuntu)",
  "configure_args": "--with-http_ssl_module --with-http_v2_module ...",
  "modules": ["ssl", "v2", "stub_status", "gzip"]
}
```

**字段说明**：
- `configure_args`: Nginx编译时的配置参数
- `modules`: 启用的Nginx模块列表

---

## 请求/响应格式

### 请求头

所有请求应该包含以下头信息：

```
Content-Type: application/json
Accept: application/json
Authorization: Bearer <token>  # 如果启用了认证
```

### 响应格式

所有响应均为JSON格式，包含以下通用结构：

**成功响应**：
```json
{
  "success": true,
  "message": "Operation completed successfully",
  "data": { ... }  // 可选的数据字段
}
```

**错误响应**：
```json
{
  "error": "Error description",
  "details": "Detailed error information"  // 可选
}
```

### HTTP状态码

- `200 OK`: 请求成功
- `400 Bad Request`: 请求参数错误
- `401 Unauthorized`: 认证失败
- `404 Not Found`: 资源不存在
- `500 Internal Server Error`: 服务器内部错误

---

## 错误处理

### 错误类型

#### 1. 认证错误

**状态码**: `401 Unauthorized`

```json
{
  "error": "Unauthorized"
}
```

**解决方法**: 提供正确的Authorization头。

#### 2. 配置错误

**状态码**: `400 Bad Request`

```json
{
  "error": "Nginx configuration test failed",
  "details": "nginx: [emerg] unknown directive 'wrong_directive' in /tmp/nginx_test.conf:5"
}
```

**解决方法**: 检查配置语法，参考Nginx官方文档。

#### 3. 文件不存在

**状态码**: `404 Not Found`

```json
{
  "error": "Nginx config file not found"
}
```

**解决方法**: 检查Nginx安装和配置文件路径。

#### 4. 进程状态错误

**状态码**: `400 Bad Request`

```json
{
  "error": "Nginx is not running"
}
```

**解决方法**: 先启动Nginx服务。

### 错误处理建议

1. **客户端**: 根据状态码判断错误类型
2. **重试机制**: 对500错误可以实现指数退避重试
3. **日志记录**: 记录错误详情便于排查问题
4. **用户提示**: 向用户提供友好的错误提示

---

## 配置说明

### 环境变量

#### 基础配置

| 变量名 | 说明 | 默认值 | 示例 |
|--------|------|--------|------|
| `API_HOST` | API监听地址 | `0.0.0.0` | `127.0.0.1` |
| `API_PORT` | API监听端口 | `5000` | `8080` |
| `DEBUG` | 调试模式 | `False` | `True` |
| `FLASK_ENV` | Flask环境 | `production` | `development` |

#### Nginx配置

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `NGINX_CONFIG_PATH` | Nginx配置文件路径 | `/etc/nginx/nginx.conf` |
| `NGINX_BACKUP_DIR` | 配置备份目录 | `/etc/nginx/backup` |
| `NGINX_PID_PATH` | Nginx PID文件路径 | `/var/run/nginx.pid` |
| `NGINX_BINARY` | Nginx可执行文件路径 | `/usr/sbin/nginx` |
| `NGINX_LOG_DIR` | Nginx日志目录 | `/var/log/nginx` |

#### 安全配置

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `AUTH_TOKEN` | 认证Token | `your-secret-token` |
| `ALLOWED_ORIGINS` | 允许的CORS源 | `http://localhost:3000,https://admin.example.com` |
| `SECRET_KEY` | Flask密钥 | `random-secret-key` |

#### 日志配置

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `LOG_FILE` | 日志文件路径 | `/var/log/nginx-agent.log` |
| `LOG_LEVEL` | 日志级别 | `INFO` |

### 配置文件（v2版本）

v2版本使用`config.py`进行配置管理，支持多环境：

```python
# 开发环境
class DevelopmentConfig(Config):
    DEBUG = True
    LOG_LEVEL = 'DEBUG'

# 生产环境
class ProductionConfig(Config):
    DEBUG = False
    LOG_LEVEL = 'INFO'

# 测试环境
class TestingConfig(Config):
    TESTING = True
    NGINX_CONFIG_PATH = '/tmp/nginx_test.conf'
```

**使用特定配置**：

```bash
export FLASK_ENV=production
python app_v2.py
```

---

## 部署指南

### 环境要求

- Python 3.6+
- Nginx（已安装并配置）
- Linux操作系统（推荐）

### 安装依赖

```bash
pip install -r requirements.txt
```

**核心依赖**：
- Flask: Web框架
- Flask-CORS: 跨域支持
- psutil: 系统监控

### 系统服务部署

#### 使用systemd（推荐）

创建服务文件 `/etc/systemd/system/nginx-agent.service`：

```ini
[Unit]
Description=Nginx Agent API Service
After=network.target

[Service]
Type=simple
User=nginx
Group=nginx
WorkingDirectory=/opt/nginx-agent
Environment=FLASK_ENV=production
Environment=AUTH_TOKEN=your-secret-token
ExecStart=/usr/bin/python3 /opt/nginx-agent/app_v2.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**启动服务**：

```bash
sudo systemctl daemon-reload
sudo systemctl enable nginx-agent
sudo systemctl start nginx-agent
```

#### 使用Docker部署

构建Docker镜像：

```bash
docker build -t nginx-agent .
```

运行容器：

```bash
docker run -d \
  --name nginx-agent \
  -p 5000:5000 \
  -v /etc/nginx:/etc/nginx \
  -v /var/log/nginx:/var/log/nginx \
  -e AUTH_TOKEN=your-secret-token \
  -e FLASK_ENV=production \
  nginx-agent
```

### 生产环境建议

1. **使用反向代理**
   - 在Nginx Agent前部署Nginx反向代理
   - 配置SSL/TLS加密
   - 限制访问IP范围

2. **安全配置**
   - 启用`AUTH_TOKEN`认证
   - 配置`ALLOWED_ORIGINS`
   - 使用强密码策略

3. **监控告警**
   - 监控API服务状态
   - 配置日志轮转
   - 设置异常告警

4. **性能优化**
   - 使用gunicorn运行
   - 配置合适的worker数量
   - 启用连接池

### 备份策略

1. **配置备份**：API自动备份每次配置变更
2. **日志备份**：配置logrotate进行日志轮转
3. **数据库备份**：如有需要，备份相关数据

---

## 使用示例

### Python客户端示例

```python
import requests
import json

class NginxAgentClient:
    def __init__(self, base_url, auth_token=None):
        self.base_url = base_url
        self.headers = {'Content-Type': 'application/json'}
        if auth_token:
            self.headers['Authorization'] = f'Bearer {auth_token}'
    
    def health_check(self):
        response = requests.get(f'{self.base_url}/health')
        return response.json()
    
    def get_nginx_status(self):
        response = requests.get(f'{self.base_url}/nginx/status', 
                              headers=self.headers)
        return response.json()
    
    def update_config(self, config_content):
        data = {
            'content': config_content,
            'backup': True,
            'test': True
        }
        response = requests.put(f'{self.base_url}/nginx/config',
                              headers=self.headers,
                              json=data)
        return response.json()
    
    def reload_nginx(self):
        response = requests.post(f'{self.base_url}/nginx/reload',
                               headers=self.headers)
        return response.json()

# 使用示例
client = NginxAgentClient('http://localhost:5000/api', 
                         auth_token='your-secret-token')

# 健康检查
health = client.health_check()
print(f"Nginx running: {health['nginx_running']}")

# 获取状态
status = client.get_nginx_status()
print(f"CPU usage: {status['system_info']['cpu_usage']}")

# 更新配置
with open('new_nginx.conf', 'r') as f:
    result = client.update_config(f.read())
if result.get('success'):
    print("Config updated successfully")
    client.reload_nginx()
```

### Shell脚本示例

```bash
#!/bin/bash

API_URL="http://localhost:5000/api"
AUTH_TOKEN="your-secret-token"

# 函数：发送API请求
call_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    curl -s -X $method \
         -H "Content-Type: application/json" \
         -H "Authorization: Bearer $AUTH_TOKEN" \
         -d "$data" \
         "$API_URL$endpoint"
}

# 健康检查
echo "Health check:"
call_api GET "/health" | jq .

# 获取Nginx状态
echo -e "\nNginx status:"
call_api GET "/nginx/status" | jq .

# 更新配置
echo -e "\nUpdating config:"
CONFIG_CONTENT=$(cat new_nginx.conf)
call_api PUT "/nginx/config" "{\"content\": \"$CONFIG_CONTENT\", \"backup\": true}" | jq .

# 重载Nginx
echo -e "\nReloading nginx:"
call_api POST "/nginx/reload" | jq .
```

---

## API测试

### 使用curl测试

```bash
# 测试所有端点
./test_api.sh
```

### 使用Postman

1. 导入API集合
2. 设置环境变量：
   - `baseUrl`: `http://localhost:5000/api`
   - `authToken`: `your-secret-token`
3. 在请求头中添加：
   - `Authorization: Bearer {{authToken}}`

### 使用pytest测试

```python
import pytest
import requests

def test_health_check():
    response = requests.get('http://localhost:5000/api/health')
    assert response.status_code == 200
    data = response.json()
    assert data['status'] == 'healthy'

def test_nginx_status():
    headers = {'Authorization': 'Bearer your-secret-token'}
    response = requests.get('http://localhost:5000/api/nginx/status', 
                           headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert 'running' in data
```

---

## 常见问题

### Q1: 无法连接API

**问题**：Connection refused

**解决**：
1. 检查服务是否运行：`ps aux | grep nginx-agent`
2. 检查端口监听：`netstat -tln | grep 5000`
3. 检查防火墙设置

### Q2: 认证失败

**问题**：401 Unauthorized

**解决**：
1. 检查Token是否正确
2. 检查请求头格式：`Authorization: Bearer <token>`
3. 检查环境变量是否设置

### Q3: 配置更新失败

**问题**：配置测试失败

**解决**：
1. 检查Nginx配置语法：`nginx -t`
2. 查看错误详情：`details`字段
3. 参考Nginx官方文档修正配置

### Q4: Nginx无法启动

**问题**：Start nginx failed

**解决**：
1. 检查Nginx是否已运行
2. 查看系统日志：`journalctl -u nginx`
3. 检查配置文件权限

### Q5: 权限不足

**问题**：Permission denied

**解决**：
1. 使用合适用户运行（推荐nginx用户）
2. 检查文件权限：`ls -l /etc/nginx/`
3. 检查SELinux/AppArmor设置

---

## 版本历史

### v1.0.0 (2024-01-15)
- 初始版本发布
- 实现基础API功能
- 支持配置管理和进程控制

### v2.0.0 (2024-03-01)
- 重构为模块化架构
- 增加Token认证
- 支持环境变量配置
- 改进日志系统
- 增强安全特性

---

## 贡献指南

欢迎提交Issue和Pull Request！

### 开发环境搭建

1. Fork项目
2. 创建特性分支：`git checkout -b feature/new-api`
3. 提交更改：`git commit -am 'Add new API endpoint'`
4. 推送到分支：`git push origin feature/new-api`
5. 创建Pull Request

### 代码规范

- 遵循PEP 8规范
- 添加必要的注释
- 更新相关文档
- 添加单元测试

---

## 许可证

MIT License

---

## 联系方式

- **项目地址**: https://github.com/your-org/nginx-agent
- **问题反馈**: https://github.com/your-org/nginx-agent/issues
- **邮件**: support@example.com

---

## 附录

### Nginx配置示例

```nginx
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # 包含其他配置
    include /etc/nginx/conf.d/*.conf;
}
```

### API性能优化建议

1. 使用连接池
2. 启用HTTP/2
3. 配置缓存策略
4. 使用CDN加速静态资源
5. 监控API响应时间

### 监控指标

建议监控以下指标：
- API请求响应时间
- Nginx进程状态
- 系统资源使用率
- 配置变更频率
- 错误率

---

**文档版本**: 1.0.0  
**最后更新**: 2026-03-15  
**维护者**: Nginx Agent Team