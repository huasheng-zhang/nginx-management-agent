"""
Nginx Agent API 配置文件
部署在各Nginx节点上
"""

import os
from pathlib import Path

class Config:
    """基础配置"""
    # Flask配置
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'nginx-agent-secret-key-change-this-in-production'
    
    # API配置
    API_HOST = os.environ.get('API_HOST', '0.0.0.0')
    API_PORT = int(os.environ.get('API_PORT', 5000))
    DEBUG = os.environ.get('DEBUG', 'False').lower() == 'true'
    
    # Nginx配置
    NGINX_CONFIG_PATH = os.environ.get('NGINX_CONFIG_PATH', '/etc/nginx/nginx.conf')
    NGINX_BACKUP_DIR = os.environ.get('NGINX_BACKUP_DIR', '/etc/nginx/backup')
    NGINX_PID_PATH = os.environ.get('NGINX_PID_PATH', '/var/run/nginx.pid')
    NGINX_BINARY = os.environ.get('NGINX_BINARY', '/usr/sbin/nginx')
    NGINX_LOG_DIR = os.environ.get('NGINX_LOG_DIR', '/var/log/nginx')
    
    # 安全配置
    ALLOWED_ORIGINS = os.environ.get('ALLOWED_ORIGINS', '*').split(',')
    AUTH_TOKEN = os.environ.get('AUTH_TOKEN')  # 如果设置，需要Token认证
    
    # 日志配置
    LOG_FILE = os.environ.get('LOG_FILE', '/var/log/nginx-agent.log')
    LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')
    
    # 监控配置
    METRICS_UPDATE_INTERVAL = int(os.environ.get('METRICS_UPDATE_INTERVAL', '10'))
    
    @staticmethod
    def init_app(app):
        pass

class DevelopmentConfig(Config):
    """开发环境配置"""
    DEBUG = True
    LOG_LEVEL = 'DEBUG'

class ProductionConfig(Config):
    """生产环境配置"""
    DEBUG = False
    LOG_LEVEL = 'INFO'
    
    @classmethod
    def init_app(cls, app):
        Config.init_app(app)
        
        # 生产环境日志配置
        import logging
        from logging.handlers import RotatingFileHandler
        
        handler = RotatingFileHandler(
            cls.LOG_FILE, 
            maxBytes=1024*1024*10,  # 10MB
            backupCount=10
        )
        handler.setLevel(getattr(logging, cls.LOG_LEVEL))
        handler.setFormatter(logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        ))
        app.logger.addHandler(handler)

class TestingConfig(Config):
    """测试环境配置"""
    TESTING = True
    DEBUG = True
    NGINX_CONFIG_PATH = '/tmp/nginx_test.conf'
    NGINX_BACKUP_DIR = '/tmp/nginx_backup'
    LOG_FILE = '/tmp/nginx-agent-test.log'

# 配置映射
config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
    'default': ProductionConfig
}
