# Nginx Agent API 快速参考

## 基础信息

- **Base URL**: `http://localhost:5000/api`
- **端口**: 5000 (可配置)
- **认证**: Bearer Token (可选，推荐启用)

---

## 快速开始

### 1. 健康检查
```bash
curl http://localhost:5000/api/health
```

### 2. 获取Nginx状态
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:5000/api/nginx/status
```

### 3. 更新配置
```bash
curl -X PUT -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"content": "your nginx config"}' \
     http://localhost:5000/api/nginx/config
```

### 4. 重载Nginx
```bash
curl -X POST -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:5000/api/nginx/reload
```

---

## API端点速查表

| 方法 | 端点 | 描述 | 认证 |
|------|------|------|------|
| **健康检查** |
| GET | `/health` | 健康检查 | 否 |
| **Nginx状态** |
| GET | `/nginx/status` | 获取状态 | 是 |
| POST | `/nginx/start` | 启动Nginx | 是 |
| POST | `/nginx/stop` | 停止Nginx | 是 |
| POST | `/nginx/reload` | 重载配置 | 是 |
| **配置管理** |
| GET | `/nginx/config` | 获取配置 | 是 |
| PUT | `/nginx/config` | 更新配置 | 是 |
| GET | `/nginx/config/backups` | 列出备份 | 是 |
| GET | `/nginx/config/backups/{file}` | 获取备份 | 是 |
| POST | `/nginx/config/backups/{file}/restore` | 恢复备份 | 是 |
| **日志管理** |
| GET | `/nginx/logs` | 日志文件列表 | 是 |
| GET | `/nginx/logs/{name}` | 查看日志 | 是 |
| **监控统计** |
| GET | `/nginx/stats` | 系统统计 | 是 |
| GET | `/nginx/info` | Nginx信息 | 是 |

---

## 常用场景

### 场景1：更新Nginx配置

```bash
#!/bin/bash

API="http://localhost:5000/api"
TOKEN="your-token"

# 1. 获取当前配置
curl -H "Authorization: Bearer $TOKEN" $API/nginx/config > current.conf

# 2. 修改配置（手动编辑）
# nano new.conf

# 3. 更新配置
curl -X PUT -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d "@{\"content\": \"$(cat new.conf | sed 's/"/\\"/g')\"}" \
     $API/nginx/config

# 4. 重载Nginx
curl -X POST -H "Authorization: Bearer $TOKEN" $API/nginx/reload
```

### 场景2：查看最近错误

```bash
# 查看最后50行错误日志
curl -H "Authorization: Bearer $TOKEN" \
     "$API/nginx/logs/error.log?lines=50" | jq -r '.content'
```

### 场景3：监控Nginx状态

```bash
# 实时监控
curl -H "Authorization: Bearer $TOKEN" $API/nginx/stats | jq
```

### 场景4：回滚配置

```bash
# 1. 列出备份
curl -H "Authorization: Bearer $TOKEN" $API/nginx/config/backups | jq

# 2. 恢复指定备份
curl -X POST -H "Authorization: Bearer $TOKEN" \
     "$API/nginx/config/backups/nginx.conf.20240315_120000/restore"

# 3. 重载Nginx
curl -X POST -H "Authorization: Bearer $TOKEN" $API/nginx/reload
```

---

## 环境变量速查

```bash
# 基础配置
export API_HOST=0.0.0.0
export API_PORT=5000
export FLASK_ENV=production

# Nginx路径
export NGINX_CONFIG_PATH=/etc/nginx/nginx.conf
export NGINX_BACKUP_DIR=/etc/nginx/backup
export NGINX_LOG_DIR=/var/log/nginx

# 安全配置（重要）
export AUTH_TOKEN=your-strong-secret-token
export ALLOWED_ORIGINS=http://localhost:3000,https://admin.example.com

# 日志配置
export LOG_LEVEL=INFO
export LOG_FILE=/var/log/nginx-agent.log
```

---

## 状态码说明

| 状态码 | 含义 | 处理建议 |
|--------|------|----------|
| 200 | 成功 | 正常处理响应 |
| 400 | 请求错误 | 检查请求参数 |
| 401 | 认证失败 | 检查Token是否正确 |
| 404 | 资源不存在 | 检查URL路径 |
| 500 | 服务器错误 | 查看日志，重试 |

---

## Python客户端示例

```python
import requests

class NginxAgentAPI:
    def __init__(self, base_url, token=None):
        self.base_url = base_url
        self.headers = {}
        if token:
            self.headers['Authorization'] = f'Bearer {token}'
    
    def get(self, endpoint):
        return requests.get(f'{self.base_url}{endpoint}', 
                          headers=self.headers).json()
    
    def post(self, endpoint, data=None):
        return requests.post(f'{self.base_url}{endpoint}', 
                           headers=self.headers, json=data).json()
    
    def put(self, endpoint, data):
        return requests.put(f'{self.base_url}{endpoint}', 
                          headers=self.headers, json=data).json()

# 使用示例
api = NginxAgentAPI('http://localhost:5000/api', 
                   token='your-token')

# 检查健康状态
health = api.get('/health')
print(f"Nginx运行状态: {health['nginx_running']}")

# 获取状态
status = api.get('/nginx/status')
print(f"CPU使用率: {status['system_info']['cpu_usage']}")

# 重载配置
result = api.post('/nginx/reload')
print(f"结果: {result['message']}")
```

---

## 故障排查

### 问题1：API无响应
```bash
# 检查服务状态
ps aux | grep nginx-agent

# 检查端口监听
netstat -tln | grep 5000

# 查看日志
tail -f /var/log/nginx-agent.log
```

### 问题2：认证失败
```bash
# 检查Token
echo $AUTH_TOKEN

# 测试不带认证
curl http://localhost:5000/api/health

# 测试带认证
curl -H "Authorization: Bearer $AUTH_TOKEN" \
     http://localhost:5000/api/nginx/status
```

### 问题3：配置更新失败
```bash
# 手动测试配置
nginx -t

# 查看详细错误
curl -X PUT -H "Authorization: Bearer $TOKEN" \
     -d '{"content": "invalid config", "test": true}' \
     $API/nginx/config | jq
```

---

## 常用curl命令集合

```bash
# 保存为api.sh
API="http://localhost:5000/api"
TOKEN="your-token"

alias api-health="curl $API/health | jq"
alias api-status="curl -H \"Authorization: Bearer $TOKEN\" $API/nginx/status | jq"
alias api-config="curl -H \"Authorization: Bearer $TOKEN\" $API/nginx/config | jq '.content'"
alias api-reload="curl -X POST -H \"Authorization: Bearer $TOKEN\" $API/nginx/reload | jq"
alias api-logs="curl -H \"Authorization: Bearer $TOKEN\" $API/nginx/logs/error.log?lines=20 | jq -r '.content'"
```

---

**记住**：在生产环境中始终启用`AUTH_TOKEN`！
