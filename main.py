#!/usr/bin/env python3
"""
Nginx Agent API - 主蓝图模块
包含所有API路由和逻辑
"""

from flask import Blueprint, current_app, request, jsonify, send_file
import os
import psutil
import subprocess
import time
from datetime import datetime
import shutil
from functools import wraps

main = Blueprint('main', __name__)

def get_logger():
    return current_app.logger

def check_nginx_status():
    """检查Nginx进程状态"""
    try:
        for proc in psutil.process_iter(['pid', 'name']):
            if proc.info['name'] == 'nginx':
                return True
        return False
    except:
        return False

def get_nginx_pid():
    """获取Nginx主进程PID"""
    try:
        pid_path = current_app.config['NGINX_PID_PATH']
        if os.path.exists(pid_path):
            with open(pid_path, 'r') as f:
                return int(f.read().strip())
    except:
        pass
    return None

def execute_command(cmd, check=False):
    """执行系统命令"""
    try:
        result = subprocess.run(
            cmd, 
            shell=True, 
            capture_output=True, 
            text=True,
            timeout=30
        )
        if check and result.returncode != 0:
            raise Exception(f"Command failed: {result.stderr}")
        return result
    except subprocess.TimeoutExpired:
        raise Exception("Command execution timeout")
    except Exception as e:
        raise Exception(f"Command execution failed: {str(e)}")

def backup_config():
    """备份当前Nginx配置"""
    try:
        config_path = current_app.config['NGINX_CONFIG_PATH']
        backup_dir = current_app.config['NGINX_BACKUP_DIR']
        
        if not os.path.exists(backup_dir):
            os.makedirs(backup_dir, exist_ok=True)
        
        if os.path.exists(config_path):
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            backup_path = os.path.join(backup_dir, f'nginx.conf.{timestamp}')
            shutil.copy2(config_path, backup_path)
            return backup_path
    except Exception as e:
        get_logger().error(f"Backup config failed: {str(e)}")
    return None

def require_auth(f):
    """认证装饰器"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_token = current_app.config.get('AUTH_TOKEN')
        if auth_token:
            token = request.headers.get('Authorization')
            if not token or token != f"Bearer {auth_token}":
                return jsonify({'error': 'Unauthorized'}), 401
        return f(*args, **kwargs)
    return decorated_function

@main.route('/health', methods=['GET'])
def health_check():
    """健康检查接口"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'nginx_running': check_nginx_status()
    })

@main.route('/nginx/status', methods=['GET'])
@require_auth
def nginx_status():
    """获取Nginx状态信息"""
    try:
        is_running = check_nginx_status()
        pid = get_nginx_pid()
        
        nginx_binary = current_app.config['NGINX_BINARY']
        
        # 获取Nginx版本
        version = None
        try:
            result = execute_command(f"{nginx_binary} -v 2>&1")
            if result.returncode == 0:
                version = result.stderr.strip()
        except:
            pass
        
        # 获取系统资源使用情况
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        
        status_info = {
            'running': is_running,
            'pid': pid,
            'version': version,
            'config_path': current_app.config['NGINX_CONFIG_PATH'],
            'system_info': {
                'cpu_usage': f"{cpu_percent}%",
                'memory_usage': f"{memory.percent}%",
                'memory_total': f"{memory.total // (1024**3)}GB",
                'load_average': os.getloadavg() if hasattr(os, 'getloadavg') else None
            },
            'timestamp': datetime.now().isoformat()
        }
        
        return jsonify(status_info)
    
    except Exception as e:
        get_logger().error(f"Get nginx status failed: {str(e)}")
        return jsonify({'error': str(e)}), 500

@main.route('/nginx/config', methods=['GET'])
@require_auth
def get_config():
    """获取Nginx配置内容"""
    try:
        config_path = current_app.config['NGINX_CONFIG_PATH']
        
        if not os.path.exists(config_path):
            return jsonify({'error': 'Nginx config file not found'}), 404
        
        with open(config_path, 'r', encoding='utf-8') as f:
            config_content = f.read()
        
        # 获取配置文件状态
        stat = os.stat(config_path)
        
        return jsonify({
            'path': config_path,
            'content': config_content,
            'size': stat.st_size,
            'modified_time': datetime.fromtimestamp(stat.st_mtime).isoformat(),
            'backup_dir': current_app.config['NGINX_BACKUP_DIR']
        })
    
    except Exception as e:
        get_logger().error(f"Get nginx config failed: {str(e)}")
        return jsonify({'error': str(e)}), 500

@main.route('/nginx/config', methods=['PUT'])
@require_auth
def update_config():
    """更新Nginx配置"""
    try:
        data = request.get_json()
        if not data or 'content' not in data:
            return jsonify({'error': 'Missing config content'}), 400
        
        content = data['content']
        backup_before = data.get('backup', True)
        test_config = data.get('test', True)
        
        config_path = current_app.config['NGINX_CONFIG_PATH']
        nginx_binary = current_app.config['NGINX_BINARY']
        
        # 备份当前配置
        backup_path = None
        if backup_before:
            backup_path = backup_config()
            if backup_path:
                get_logger().info(f"Config backed up to: {backup_path}")
        
        # 测试配置
        if test_config:
            # 先写入临时文件进行测试
            temp_config = '/tmp/nginx_test.conf'
            with open(temp_config, 'w', encoding='utf-8') as f:
                f.write(content)
            
            result = execute_command(f"{nginx_binary} -t -c {temp_config}")
            os.remove(temp_config)
            
            if result.returncode != 0:
                return jsonify({
                    'error': 'Nginx configuration test failed',
                    'details': result.stderr
                }), 400
        
        # 写入配置
        with open(config_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        return jsonify({
            'success': True,
            'message': 'Configuration updated successfully',
            'backup_path': backup_path,
            'tested': test_config
        })
    
    except Exception as e:
        get_logger().error(f"Update nginx config failed: {str(e)}")
        return jsonify({'error': str(e)}), 500

@main.route('/nginx/reload', methods=['POST'])
@require_auth
def reload_nginx():
    """重载Nginx配置"""
    try:
        if not check_nginx_status():
            return jsonify({'error': 'Nginx is not running'}), 400
        
        nginx_binary = current_app.config['NGINX_BINARY']
        result = execute_command(f"{nginx_binary} -s reload", check=True)
        
        get_logger().info("Nginx configuration reloaded")
        return jsonify({
            'success': True,
            'message': 'Nginx reloaded successfully'
        })
    
    except Exception as e:
        get_logger().error(f"Reload nginx failed: {str(e)}")
        return jsonify({'error': str(e)}), 500

@main.route('/nginx/start', methods=['POST'])
@require_auth
def start_nginx():
    """启动Nginx"""
    try:
        if check_nginx_status():
            return jsonify({'error': 'Nginx is already running'}), 400
        
        nginx_binary = current_app.config['NGINX_BINARY']
        result = execute_command(nginx_binary, check=True)
        
        # 等待Nginx启动
        time.sleep(2)
        
        if not check_nginx_status():
            raise Exception("Nginx failed to start")
        
        get_logger().info("Nginx started successfully")
        return jsonify({
            'success': True,
            'message': 'Nginx started successfully'
        })
    
    except Exception as e:
        get_logger().error(f"Start nginx failed: {str(e)}")
        return jsonify({'error': str(e)}), 500

@main.route('/nginx/stop', methods=['POST'])
@require_auth
def stop_nginx():
    """停止Nginx"""
    try:
        if not check_nginx_status():
            return jsonify({'error': 'Nginx is not running'}), 400
        
        nginx_binary = current_app.config['NGINX_BINARY']
        result = execute_command(f"{nginx_binary} -s stop", check=True)
        
        # 等待Nginx停止
        time.sleep(2)
        
        if check_nginx_status():
            raise Exception("Nginx failed to stop")
        
        get_logger().info("Nginx stopped successfully")
        return jsonify({
            'success': True,
            'message': 'Nginx stopped successfully'
        })
    
    except Exception as e:
        get_logger().error(f"Stop nginx failed: {str(e)}")
        return jsonify({'error': str(e)}), 500

@main.route('/nginx/config/backups', methods=['GET'])
@require_auth
def list_backups():
    """列出配置备份文件"""
    try:
        backups = []
        backup_dir = current_app.config['NGINX_BACKUP_DIR']
        
        if os.path.exists(backup_dir):
            for filename in os.listdir(backup_dir):
                if filename.startswith('nginx.conf.'):
                    filepath = os.path.join(backup_dir, filename)
                    stat = os.stat(filepath)
                    backups.append({
                        'filename': filename,
                        'path': filepath,
                        'size': stat.st_size,
                        'created_time': datetime.fromtimestamp(stat.st_ctime).isoformat()
                    })
        
        backups.sort(key=lambda x: x['created_time'], reverse=True)
        
        return jsonify({
            'backups': backups,
            'backup_dir': backup_dir
        })
    
    except Exception as e:
        get_logger().error(f"List backups failed: {str(e)}")
        return jsonify({'error': str(e)}), 500

@main.route('/nginx/config/backups/<filename>', methods=['GET'])
@require_auth
def get_backup(filename):
    """获取备份配置文件内容"""
    try:
        # 安全检查，防止路径遍历
        if '..' in filename or filename.startswith('/'):
            return jsonify({'error': 'Invalid filename'}), 400
        
        backup_dir = current_app.config['NGINX_BACKUP_DIR']
        backup_path = os.path.join(backup_dir, filename)
        
        if not os.path.exists(backup_path):
            return jsonify({'error': 'Backup file not found'}), 404
        
        with open(backup_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        return jsonify({
            'filename': filename,
            'content': content
        })
    
    except Exception as e:
        get_logger().error(f"Get backup failed: {str(e)}")
        return jsonify({'error': str(e)}), 500

@main.route('/nginx/config/backups/<filename>/restore', methods=['POST'])
@require_auth
def restore_backup(filename):
    """恢复备份配置"""
    try:
        # 安全检查
        if '..' in filename or filename.startswith('/'):
            return jsonify({'error': 'Invalid filename'}), 400
        
        backup_dir = current_app.config['NGINX_BACKUP_DIR']
        backup_path = os.path.join(backup_dir, filename)
        
        if not os.path.exists(backup_path):
            return jsonify({'error': 'Backup file not found'}), 404
        
        # 备份当前配置
        current_backup = backup_config()
        config_path = current_app.config['NGINX_CONFIG_PATH']
        
        # 恢复备份
        shutil.copy2(backup_path, config_path)
        
        get_logger().info(f"Config restored from backup: {filename}")
        return jsonify({
            'success': True,
            'message': f'Configuration restored from {filename}',
            'previous_config_backup': current_backup
        })
    
    except Exception as e:
        get_logger().error(f"Restore backup failed: {str(e)}")
        return jsonify({'error': str(e)}), 500

@main.route('/nginx/logs', methods=['GET'])
@require_auth
def get_logs():
    """获取Nginx日志文件列表"""
    try:
        log_files = []
        log_dir = current_app.config['NGINX_LOG_DIR']
        
        if os.path.exists(log_dir):
            for filename in os.listdir(log_dir):
                if filename.endswith('.log'):
                    filepath = os.path.join(log_dir, filename)
                    if os.path.isfile(filepath):
                        stat = os.stat(filepath)
                        log_files.append({
                            'filename': filename,
                            'path': filepath,
                            'size': stat.st_size,
                            'modified_time': datetime.fromtimestamp(stat.st_mtime).isoformat()
                        })
        
        return jsonify({
            'log_files': log_files
        })
    
    except Exception as e:
        get_logger().error(f"Get log files failed: {str(e)}")
        return jsonify({'error': str(e)}), 500

@main.route('/nginx/logs/<logname>', methods=['GET'])
@require_auth
def view_log(logname):
    """查看日志文件内容"""
    try:
        lines = request.args.get('lines', '100')
        try:
            lines = int(lines)
        except:
            lines = 100
        
        # 安全检查
        if '..' in logname or logname.startswith('/'):
            return jsonify({'error': 'Invalid log name'}), 400
        
        # 查找日志文件
        log_path = None
        log_dir = current_app.config['NGINX_LOG_DIR']
        
        test_path = os.path.join(log_dir, logname)
        if os.path.exists(test_path):
            log_path = test_path
        
        if not log_path or not os.path.isfile(log_path):
            return jsonify({'error': 'Log file not found'}), 404
        
        # 读取日志文件最后几行
        result = execute_command(f"tail -n {lines} {log_path}")
        
        if result.returncode != 0:
            return jsonify({'error': 'Failed to read log file'}), 500
        
        return jsonify({
            'logname': logname,
            'path': log_path,
            'content': result.stdout,
            'lines': lines
        })
    
    except Exception as e:
        get_logger().error(f"View log failed: {str(e)}")
        return jsonify({'error': str(e)}), 500

@main.route('/nginx/stats', methods=['GET'])
@require_auth
def nginx_stats():
    """获取Nginx运行统计"""
    try:
        stats = {
            'timestamp': datetime.now().isoformat(),
            'nginx_running': check_nginx_status(),
            'pid': get_nginx_pid(),
            'system': {
                'cpu_count': psutil.cpu_count(),
                'cpu_percent': psutil.cpu_percent(interval=1),
                'memory': {
                    'total': psutil.virtual_memory().total,
                    'available': psutil.virtual_memory().available,
                    'percent': psutil.virtual_memory().percent,
                    'used': psutil.virtual_memory().used
                },
                'disk': {}
            }
        }
        
        # 获取磁盘使用情况
        for partition in psutil.disk_partitions():
            try:
                usage = psutil.disk_usage(partition.mountpoint)
                stats['system']['disk'][partition.mountpoint] = {
                    'total': usage.total,
                    'used': usage.used,
                    'free': usage.free,
                    'percent': usage.percent
                }
            except:
                pass
        
        # 获取Nginx进程信息
        nginx_processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_info']):
            if proc.info['name'] == 'nginx':
                nginx_processes.append({
                    'pid': proc.info['pid'],
                    'cpu_percent': proc.info['cpu_percent'],
                    'memory_rss': proc.info['memory_info'].rss if proc.info['memory_info'] else None
                })
        
        stats['nginx_processes'] = nginx_processes
        
        return jsonify(stats)
    
    except Exception as e:
        get_logger().error(f"Get nginx stats failed: {str(e)}")
        return jsonify({'error': str(e)}), 500

@main.route('/nginx/info', methods=['GET'])
@require_auth
def nginx_info():
    """获取Nginx详细信息"""
    try:
        info = {
            'config_path': current_app.config['NGINX_CONFIG_PATH'],
            'binary_path': current_app.config['NGINX_BINARY'],
            'pid_path': current_app.config['NGINX_PID_PATH'],
            'backup_dir': current_app.config['NGINX_BACKUP_DIR'],
            'log_dir': current_app.config['NGINX_LOG_DIR'],
            'running': check_nginx_status(),
            'pid': get_nginx_pid(),
            'version': None,
            'configure_args': None,
            'modules': []
        }
        
        nginx_binary = current_app.config['NGINX_BINARY']
        
        # 获取版本和编译信息
        try:
            result = execute_command(f"{nginx_binary} -V 2>&1")
            if result.returncode == 0:
                stderr = result.stderr
                # 解析版本信息
                for line in stderr.split('\n'):
                    if 'nginx version' in line:
                        info['version'] = line.strip()
                    elif 'configure arguments' in line:
                        info['configure_args'] = line.split(':', 1)[1].strip()
                        # 解析模块
                        if '--with-http' in line:
                            modules = []
                            parts = line.split()
                            for part in parts:
                                if part.startswith('--with-http') and not part.startswith('--with-http_'):
                                    module = part.replace('--with-http_', '').replace('_module', '')
                                    modules.append(module)
                            info['modules'] = modules
        except:
            pass
        
        return jsonify(info)
    
    except Exception as e:
        get_logger().error(f"Get nginx info failed: {str(e)}")
        return jsonify({'error': str(e)}), 500
