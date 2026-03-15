#!/usr/bin/env python3
"""
Nginx Agent API - 部署在各Nginx节点上的Agent服务
提供Nginx配置管理、状态监控、日志查看等功能
支持配置文件和环境变量
"""

from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import os
import sys
import json
import time
import psutil
import subprocess
import logging
from datetime import datetime
from pathlib import Path
import shutil
from functools import wraps

# 加载配置
from config import config

def create_app(config_name='default'):
    """应用工厂函数"""
    app = Flask(__name__)
    app.config.from_object(config[config_name])
    config[config_name].init_app(app)
    
    CORS(app, resources={r"/api/*": {"origins": app.config['ALLOWED_ORIGINS']}})
    
    # 配置日志
    setup_logging(app)
    
    # 注册蓝图
    from main import main as main_blueprint
    app.register_blueprint(main_blueprint, url_prefix='/api')
    
    return app

def setup_logging(app):
    """配置日志"""
    if not app.debug:
        # 生产环境使用RotatingFileHandler
        import logging
        from logging.handlers import RotatingFileHandler
        
        handler = RotatingFileHandler(
            app.config['LOG_FILE'],
            maxBytes=1024*1024*10,  # 10MB
            backupCount=10
        )
        handler.setLevel(getattr(logging, app.config['LOG_LEVEL']))
        handler.setFormatter(logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        ))
        app.logger.addHandler(handler)
    else:
        # 开发环境使用控制台日志
        logging.basicConfig(
            level=getattr(logging, app.config['LOG_LEVEL']),
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )

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

if __name__ == '__main__':
    env = os.environ.get('FLASK_ENV', 'production')
    app = create_app(env)
    
    app.run(
        host=app.config['API_HOST'],
        port=app.config['API_PORT'],
        debug=app.config['DEBUG']
    )
