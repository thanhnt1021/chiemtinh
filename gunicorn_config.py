import multiprocessing
import os
import sys
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(current_dir)
try:
    from project_conf import APP_PORT, PROJECT_NAME
except ImportError:
    APP_PORT = 8000
    PROJECT_NAME = "flask_app"
bind = f"0.0.0.0:{APP_PORT}"
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "gthread"
threads = 4
timeout = 300
log_dir = os.path.join(current_dir, 'logs')
if not os.path.exists(log_dir): os.makedirs(log_dir)
accesslog = os.path.join(log_dir, 'access.log')
errorlog = os.path.join(log_dir, 'error.log')
loglevel = "info"
proc_name = PROJECT_NAME
