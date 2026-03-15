"""
Gunicorn configuration file for production deployment.
"""

import multiprocessing
import os

# Server socket
bind = "127.0.0.1:8000"
backlog = 2048

# Worker processes
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2

# Logging
accesslog = os.path.join(os.path.dirname(__file__), "logs", "gunicorn_access.log")
errorlog = os.path.join(os.path.dirname(__file__), "logs", "gunicorn_error.log")
loglevel = "info"
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s'

# Process naming
proc_name = "stall_capture"

# Server mechanics
daemon = False
pidfile = "/tmp/gunicorn_stall_capture.pid"
umask = 0
user = None
group = None
tmp_upload_dir = None

# SSL (if using SSL directly with Gunicorn)
# keyfile = None
# certfile = None

# Preload app for better performance
preload_app = True

# Worker timeout
graceful_timeout = 30

# Restart workers after this many requests (helps prevent memory leaks)
max_requests = 1000
max_requests_jitter = 50
