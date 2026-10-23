#!/bin/bash
set -e

# ==============================================================================
# DEPLOY.SH - FIXED VERSION (Function Defined Globally)
# ==============================================================================

PROJECT_DIR=$(pwd)
SERVER_CONF_DIR="$PROJECT_DIR/server_conf"
LOGS_DIR="$PROJECT_DIR/logs"
GUNICORN_LIST_FILE="/root/NCEgunicorn.txt"

# --- 1. KIỂM TRA INPUT ---
if [ ! -f "project_conf.py" ]; then
    echo "❌ LỖI: Không tìm thấy 'project_conf.py'. Vui lòng tạo file này trước."
    exit 1
fi

get_config() {
    PYTHONPATH=. python3 -c "import project_conf; print(getattr(project_conf, '$1', 'False'))"
}

echo ">>> 📥 Đang đọc cấu hình..."
APP_PORT=$(get_config "APP_PORT")
PROJECT_NAME=$(get_config "PROJECT_NAME")
NGINX_FILE=$(get_config "NGINX_CONF_FILENAME")
SERVICE_FILE=$(get_config "SYSTEMD_SERVICE_FILENAME")
DOMAIN=$(get_config "DOMAIN_NAME")
CERT_EMAIL=$(get_config "CERTBOT_EMAIL")
SERVICE_NAME="${SERVICE_FILE%.*}"
SETUP_SYSTEMD=$(get_config "SETUP_SYSTEMD")
SETUP_NGINX=$(get_config "SETUP_NGINX")

SETUP_SERVER_OLD=$(get_config "SETUP_SERVER")
if [ "$SETUP_SERVER_OLD" == "True" ]; then
    if [ "$SETUP_SYSTEMD" == "False" ]; then SETUP_SYSTEMD="True"; fi
    if [ "$SETUP_NGINX" == "False" ]; then SETUP_NGINX="True"; fi
fi

echo "    - Port: $APP_PORT | Domain: $DOMAIN"

# ==============================================================================
# QUAN TRỌNG: ĐỊNH NGHĨA HÀM NGAY ĐẦU FILE ĐỂ TRÁNH LỖI "COMMAND NOT FOUND"
# ==============================================================================
wait_for_port_soft() {
    local port=$1
    local retries=60
    echo -n "    ⏳ Waiting for App to listen on port $port..."
    for ((i=1; i<=retries; i++)); do
        if (echo > /dev/tcp/127.0.0.1/$port) >/dev/null 2>&1; then
            echo " ✅ Online!"
            return 0
        fi
        echo -n "."
        sleep 1
    done
    echo " ⚠️  Timeout! App khởi động chậm, nhưng vẫn tiếp tục setup Nginx..."
    return 1
}
# ==============================================================================

# --- 2. SINH CÁC FILE PYTHON CẤU HÌNH ---

# 2.1. WSGI.PY
if [ ! -f "wsgi.py" ]; then
    echo ">>> 📄 Creating wsgi.py..."
    cat > wsgi.py <<EOF
from app import create_app
from project_conf import APP_PORT
app = create_app()
if __name__ == "__main__":
    app.run(host='0.0.0.0', port=APP_PORT, debug=False, threaded=True)
EOF
fi

# 2.2. GUNICORN_CONFIG.PY
if [ ! -f "gunicorn_config.py" ]; then
    echo ">>> 📄 Creating gunicorn_config.py..."
    cat > gunicorn_config.py <<EOF
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
EOF
fi

# 2.3. CONFIG.PY
if [ ! -f "config.py" ]; then
    echo ">>> 📄 Creating config.py..."
    cat > config.py <<EOF
import os
import secrets
import astro00_lib as lib

class Config:
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    EPHE_PATH = os.path.join(BASE_DIR, 'ephe')
    SECRET_FILE = os.path.join(BASE_DIR, 'secret.key')
    CREDS_PATH = os.path.join(BASE_DIR, 'mine01.json')
    PERMANENT_SESSION_LIFETIME = 86400 * 30 
    lib.nap_env_local()
    ADMIN_USER = os.environ.get("ADMIN_USER", "nguydev")
    ADMIN_PASS_HASH = lib.hash_password(os.environ["ADMIN_PASS"]) if os.environ.get("ADMIN_PASS") else None
    SHEETS_SCOPE = ['https://spreadsheets.google.com/feeds', 'https://www.googleapis.com/auth/drive']
    SPREADSHEET_KEY_PLANETS = '1JKvme29_UelRvZzN_pzzg5ZLh9HIT0lWo1uf7UlpCbs'
    WORKSHEET_NAME_PLANETS = 'list'
    DRIVE_SCOPE = ['https://www.googleapis.com/auth/drive.readonly']
    DRIVE_FOLDER_ID = '1LOjRXwn2tKi27vLijSFRL7S86bDkuRS3'

    @staticmethod
    def get_secret_key():
        if os.path.exists(Config.SECRET_FILE):
            with open(Config.SECRET_FILE, 'r') as f:
                return f.read().strip()
        else:
            new_key = secrets.token_hex(32)
            with open(Config.SECRET_FILE, 'w') as f:
                f.write(new_key)
            return new_key
EOF
fi

# --- 3. SINH CÁC FILE TIỆN ÍCH ---

# 3.1. SETUP.PY
if [ ! -f "setup.py" ]; then
    echo ">>> 📄 Creating setup.py..."
    cat > setup.py <<'EOF'
import subprocess
import os
import sys
import argparse
def create_requirements():
    print("Tao requirements.txt tu pip freeze...")
    with open("requirements.txt", "w") as f:
        subprocess.run(["pip", "freeze"], stdout=f, text=True)
def get_package_version(pip_name):
    result = subprocess.run(["pip", "show", pip_name], capture_output=True, text=True)
    for line in result.stdout.splitlines():
        if line.startswith("Version: "): return line.split(": ")[1]
    return None
def update_package(package, version=None):
    pip_name = package.replace('_','-')
    install_cmd = ["pip", "install", f"{pip_name}=={version}"] if version else ["pip", "install", pip_name, "--upgrade"]
    subprocess.run(install_cmd)
    pkg_version = get_package_version(pip_name)
    if pkg_version:
        new_line = f"{pip_name}=={pkg_version}"
        if not os.path.exists("requirements.txt"):
            with open("requirements.txt", "w") as f: f.write(new_line + "\n")
        else:
            with open("requirements.txt", "r") as f: lines = f.readlines()
            with open("requirements.txt", "w") as f:
                updated = False
                for line in lines:
                    if line.lower().startswith(pip_name.lower()+"=="):
                        f.write(new_line+"\n"); updated = True
                    else: f.write(line)
                if not updated: f.write(new_line+"\n")
def install_requirements():
    print("Cai dat tu requirements.txt...")
    subprocess.run(["pip", "install", "-r", "requirements.txt"])
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("packages", nargs="*"); parser.add_argument("--version")
    args = parser.parse_args()
    if args.packages:
        for pkg in args.packages: update_package(pkg, version=args.version)
    else:
        if not os.path.exists("requirements.txt"): create_requirements()
        install_requirements()
EOF
fi

# 3.2. REQUIREMENTS.TXT & OLD.TXT
if [ ! -f "requirements.txt" ]; then touch requirements.txt; fi
if [ ! -f "old.txt" ]; then touch old.txt; fi

# 3.3. EXPORT_CODE.PY
if [ ! -f "export_code.py" ]; then
    echo ">>> 📄 Creating export_code.py..."
    cat > export_code.py <<EOF
import os
PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
IGNORE_DIRS = {'venv', '__pycache__', '.git', 'logs', 'node_modules', 'static/images'}
IGNORE_FILES = {'.DS_Store', 'full_project_source.txt', 'poetry.lock', 'package-lock.json', 'old.txt'}
INCLUDE_EXTENSIONS = {'.py', '.html', '.css', '.js', '.sh', '.txt', '.md', '.json', '.conf', '.service', '.ini'}
ALWAYS_INCLUDE = {'requirements.txt', 'project_conf.py', 'export_code.py', 'setup.py', 'deploy.sh', 'export.sh', 'update.sh', 'getversion.sh', 'apply.py'}
OUTPUT_FILE = 'full_project_source.txt'
def is_text_file(filename):
    if filename in ALWAYS_INCLUDE: return True
    if filename in IGNORE_FILES: return False
    return any(filename.endswith(ext) for ext in INCLUDE_EXTENSIONS)
def collect_files(start_path):
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as outfile:
        outfile.write(f"=== PROJECT EXPORT ===\n\n")
        for root, dirs, files in os.walk(start_path):
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS and not d.startswith('.')]
            for file in files:
                if file.startswith('.'): continue
                if not is_text_file(file): continue
                path = os.path.join(root, file)
                rel_path = os.path.relpath(path, start_path)
                outfile.write(f"{'='*60}\nFILE: {rel_path}\n{'='*60}\n")
                try:
                    with open(path, 'r', encoding='utf-8', errors='ignore') as f: outfile.write(f.read() + "\n\n")
                except: outfile.write("[Error reading file]\n\n")
    print(f"✅ Exported to {OUTPUT_FILE}")
if __name__ == "__main__": collect_files(PROJECT_DIR)
EOF
fi

# 3.4. APPLY.PY
if [ ! -f "apply.py" ]; then
    echo ">>> 📄 Creating apply.py..."
    cat > apply.py <<'EOF'
import os
import re
import sys
current_script_dir = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = current_script_dir
SOURCE_FILE = os.path.join(PROJECT_ROOT, 'old.txt')
ALLOWED_PREFIXES = ['app/', 'astro00_lib/']
def is_allowed(filename):
    norm_name = filename.replace('\\', '/')
    for prefix in ALLOWED_PREFIXES:
        if norm_name.startswith(prefix): return True
    return False
def parse_and_update():
    if not os.path.exists(SOURCE_FILE):
        print(f"❌ Lỗi: Không tìm thấy {SOURCE_FILE}"); return
    print(f"🚀 Updating from: {SOURCE_FILE}")
    with open(SOURCE_FILE, 'r', encoding='utf-8') as f: lines = f.readlines()
    current_file = None; buffer = []
    separator_pattern = re.compile(r'^={60}$')
    file_pattern = re.compile(r'^FILE: (.+)$')
    i = 0
    while i < len(lines):
        line = lines[i].rstrip('\n')
        if separator_pattern.match(line.strip()):
            if current_file and buffer: save_file(current_file, buffer); current_file = None; buffer = []
            if i + 1 < len(lines):
                next_line = lines[i+1].strip()
                file_match = file_pattern.match(next_line)
                if file_match:
                    current_file = file_match.group(1).strip()
                    if i + 2 < len(lines) and separator_pattern.match(lines[i+2].strip()): i += 3; continue
                    else: i += 2; continue
        if current_file:
            if not separator_pattern.match(line.strip()): buffer.append(lines[i])
        i += 1
    if current_file and buffer: save_file(current_file, buffer)
    print("✅ Hoàn tất apply.py")
def save_file(rel_path, content_lines):
    if not is_allowed(rel_path): print(f"⏭️  Skip: {rel_path}"); return
    full_path = os.path.join(PROJECT_ROOT, rel_path)
    dir_name = os.path.dirname(full_path)
    try:
        if not os.path.exists(dir_name): os.makedirs(dir_name, exist_ok=True)
        content_str = "".join(content_lines).strip() + "\n"
        with open(full_path, 'w', encoding='utf-8') as f: f.write(content_str)
        print(f"✅ Updated: {rel_path}")
    except Exception as e: print(f"❌ Error {rel_path}: {e}")
if __name__ == "__main__": parse_and_update()
EOF
fi

# 3.5. EXPORT.SH
if [ ! -f "export.sh" ]; then
    echo ">>> 📄 Creating export.sh..."
    cat > export.sh <<'EOF'
#!/bin/bash
set -e
PROJECT_DIR=$(dirname "$(readlink -f "$0")")
echo ">>> 📂 Đang ở thư mục: $PROJECT_DIR"
if [ -d "$PROJECT_DIR/venv" ]; then source "$PROJECT_DIR/venv/bin/activate"
else echo ">>> ⚠️  Không tìm thấy venv."; fi
if [ -f "$PROJECT_DIR/export_code.py" ]; then
    python3 "$PROJECT_DIR/export_code.py"
else echo "❌ Lỗi: Không tìm thấy export_code.py!"; exit 1; fi
EOF
    chmod +x export.sh
fi

# 3.6. GETVERSION.SH
if [ ! -f "getversion.sh" ]; then
    echo ">>> 📄 Creating getversion.sh..."
    cat > getversion.sh <<'EOF'
#!/bin/bash
set -e
PROJECT_DIR=$(dirname "$(readlink -f "$0")")
echo ">>> 📂 Đang ở thư mục: $PROJECT_DIR"
if [ -d "$PROJECT_DIR/venv" ]; then source "$PROJECT_DIR/venv/bin/activate"; fi
if [ -f "$PROJECT_DIR/apply.py" ]; then
    echo ">>> 🚀 Đang chạy apply.py..."
    python3 "$PROJECT_DIR/apply.py"
else echo "❌ Lỗi: Không tìm thấy apply.py!"; exit 1; fi
if [ -f "$PROJECT_DIR/update.sh" ]; then
    echo ">>> 🔄 Đang chạy update.sh..."
    chmod +x "$PROJECT_DIR/update.sh"
    "$PROJECT_DIR/update.sh"
else echo "⚠️  Cảnh báo: Không tìm thấy update.sh!"; fi
echo ">>> ✅ GET VERSION COMPLETED!"
EOF
    chmod +x getversion.sh
fi

# 3.7. UPDATE.SH (Sinh file này với hàm wait_for_port_soft riêng bên trong)
if [ ! -f "update.sh" ]; then
    echo ">>> 📄 Creating update.sh..."
    cat > update.sh <<'EOF'
#!/bin/bash
set -e
PROJECT_DIR=$(pwd)
SERVER_CONF_DIR="$PROJECT_DIR/server_conf"
GUNICORN_LIST_FILE="/root/NCEgunicorn.txt"
get_config() { PYTHONPATH=. python3 -c "import project_conf; print(getattr(project_conf, '$1', 'False'))"; }
echo ">>> ♻️  ĐANG CẬP NHẬT HỆ THỐNG..."
APP_PORT=$(get_config "APP_PORT")
PROJECT_NAME=$(get_config "PROJECT_NAME")
NGINX_FILE=$(get_config "NGINX_CONF_FILENAME")
SERVICE_FILE=$(get_config "SYSTEMD_SERVICE_FILENAME")
DOMAIN=$(get_config "DOMAIN_NAME")
CERT_EMAIL=$(get_config "CERTBOT_EMAIL")
SERVICE_NAME="${SERVICE_FILE%.*}"
SETUP_SYSTEMD=$(get_config "SETUP_SYSTEMD")
SETUP_NGINX=$(get_config "SETUP_NGINX")
SETUP_SERVER_OLD=$(get_config "SETUP_SERVER")
if [ "$SETUP_SERVER_OLD" == "True" ]; then
    if [ "$SETUP_SYSTEMD" == "False" ]; then SETUP_SYSTEMD="True"; fi
    if [ "$SETUP_NGINX" == "False" ]; then SETUP_NGINX="True"; fi
fi
echo ">>> ℹ️  Target: Port $APP_PORT | Domain $DOMAIN"
echo ">>> 📦 Updating libs..."
source venv/bin/activate
pip install -r requirements.txt > /dev/null
find . -type d -name "__pycache__" -exec rm -r {} + || true

wait_for_port_soft() {
    local port=$1
    local retries=60
    echo -n "    ⏳ Waiting for App to listen on port $port..."
    for ((i=1; i<=retries; i++)); do
        if (echo > /dev/tcp/127.0.0.1/$port) >/dev/null 2>&1; then echo " ✅ Online!"; return 0; fi
        echo -n "."; sleep 1
    done
    echo " ⚠️  Timeout! App khởi động chậm."; return 1
}

if [ "$SETUP_SYSTEMD" == "True" ]; then
    echo ">>> ⚙️  Checking Service Config..."
    EXISTING_SVC=$(find "$SERVER_CONF_DIR" -maxdepth 1 -name "*.service" ! -name "$SERVICE_FILE" -print -quit)
    if [ -n "$EXISTING_SVC" ]; then
        OLD_SVC_FILENAME=$(basename "$EXISTING_SVC"); OLD_SVC_NAME="${OLD_SVC_FILENAME%.*}"
        echo ">>> ⚠️  Service Name Changed ($OLD_SVC_NAME -> $SERVICE_NAME)"
        sudo systemctl stop "$OLD_SVC_NAME" || true; sudo systemctl disable "$OLD_SVC_NAME" || true
        if [ -f "$GUNICORN_LIST_FILE" ]; then grep -vFx "$OLD_SVC_FILENAME" "$GUNICORN_LIST_FILE" > "${GUNICORN_LIST_FILE}.tmp" && mv "${GUNICORN_LIST_FILE}.tmp" "$GUNICORN_LIST_FILE"; fi
        mv "$EXISTING_SVC" "$SERVER_CONF_DIR/$SERVICE_FILE"
    fi
    if [ ! -f "$SERVER_CONF_DIR/$SERVICE_FILE" ]; then
        echo ">>> 📝 Creating new Service template..."
        cat > "$SERVER_CONF_DIR/$SERVICE_FILE" <<INNEREOF
[Unit]
Description=Gunicorn instance for $PROJECT_NAME
After=network.target
[Service]
User=root
Group=www-data
WorkingDirectory=$PROJECT_DIR
Environment="PATH=$PROJECT_DIR/venv/bin"
ExecStart=$PROJECT_DIR/venv/bin/gunicorn --config gunicorn_config.py wsgi:app
Restart=always
[Install]
WantedBy=multi-user.target
INNEREOF
    else
        echo ">>> ✏️  Updating Service config..."
        sed -i "s|WorkingDirectory=.*|WorkingDirectory=$PROJECT_DIR|g" "$SERVER_CONF_DIR/$SERVICE_FILE"
        sed -i "s|Environment=.*|Environment=\"PATH=$PROJECT_DIR/venv/bin\"|g" "$SERVER_CONF_DIR/$SERVICE_FILE"
        sed -i "s|ExecStart=.*|ExecStart=$PROJECT_DIR/venv/bin/gunicorn --config gunicorn_config.py wsgi:app|g" "$SERVER_CONF_DIR/$SERVICE_FILE"
        sed -i "s|Description=.*|Description=Gunicorn instance for $PROJECT_NAME|g" "$SERVER_CONF_DIR/$SERVICE_FILE"
    fi
    sudo cp "$SERVER_CONF_DIR/$SERVICE_FILE" "/etc/systemd/system/$SERVICE_FILE"
    sudo systemctl daemon-reload
    echo ">>> 🔄 Restarting Service $SERVICE_NAME..."
    sudo systemctl enable "$SERVICE_NAME"; sudo systemctl restart "$SERVICE_NAME"
    wait_for_port_soft "$APP_PORT" || echo "    -> App chưa sẵn sàng, nhưng Nginx vẫn sẽ được update..."
    if [ ! -f "$GUNICORN_LIST_FILE" ]; then touch "$GUNICORN_LIST_FILE"; fi
    if ! grep -Fxq "$SERVICE_FILE" "$GUNICORN_LIST_FILE"; then echo "$SERVICE_FILE" >> "$GUNICORN_LIST_FILE"; fi
fi

if [ "$SETUP_NGINX" == "True" ]; then
    echo ">>> 🌐 Checking Nginx Config..."
    EXISTING_NGX=$(find "$SERVER_CONF_DIR" -maxdepth 1 -name "*.conf" ! -name "$NGINX_FILE" -print -quit)
    if [ -n "$EXISTING_NGX" ]; then
        OLD_NGX_NAME=$(basename "$EXISTING_NGX")
        echo ">>> ⚠️  Nginx Config Name Changed ($OLD_NGX_NAME -> $NGINX_FILE)"
        sudo rm "/etc/nginx/sites-enabled/$OLD_NGX_NAME" || true
        mv "$EXISTING_NGX" "$SERVER_CONF_DIR/$NGINX_FILE"
    fi
    if [ ! -f "$SERVER_CONF_DIR/$NGINX_FILE" ]; then
        echo ">>> 📝 Creating new Nginx template..."
        cat > "$SERVER_CONF_DIR/$NGINX_FILE" <<INNEREOF
server {
    server_name $DOMAIN;
    access_log /var/log/nginx/${PROJECT_NAME}_access.log;
    error_log /var/log/nginx/${PROJECT_NAME}_error.log;
    location /static { alias $PROJECT_DIR/app/static; expires 30d; }
    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_connect_timeout 300s;
        proxy_read_timeout 300s;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
INNEREOF
    else
        echo ">>> ✏️  Updating Nginx config..."
        sed -i -E "s|proxy_pass http://127.0.0.1:[0-9]+;|proxy_pass http://127.0.0.1:$APP_PORT;|g" "$SERVER_CONF_DIR/$NGINX_FILE"
        sed -i "s|alias .*/static;|alias $PROJECT_DIR/app/static;|g" "$SERVER_CONF_DIR/$NGINX_FILE"
        sed -i "s|server_name .*|server_name $DOMAIN;|g" "$SERVER_CONF_DIR/$NGINX_FILE"
        sed -i "s|access_log /var/log/nginx/.*_access.log;|access_log /var/log/nginx/${PROJECT_NAME}_access.log;|g" "$SERVER_CONF_DIR/$NGINX_FILE"
        sed -i "s|error_log /var/log/nginx/.*_error.log;|error_log /var/log/nginx/${PROJECT_NAME}_error.log;|g" "$SERVER_CONF_DIR/$NGINX_FILE"
    fi
    sudo cp "$SERVER_CONF_DIR/$NGINX_FILE" "/etc/nginx/sites-available/$NGINX_FILE"
    if [ ! -f "/etc/nginx/sites-enabled/$NGINX_FILE" ]; then sudo ln -s "/etc/nginx/sites-available/$NGINX_FILE" "/etc/nginx/sites-enabled/$NGINX_FILE"; fi
    echo ">>> 🧪 Testing Nginx syntax..."
    if sudo nginx -t; then sudo systemctl reload nginx; echo ">>> ✅ Nginx Reloaded."
    else echo ">>> ❌ Nginx Config Error!"; exit 1; fi
    echo ">>> 🔑 Checking SSL..."
    CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    if [ -f "$CERT_PATH" ]; then
        echo "    ✅ Certificate found. Installing config..."
        sudo certbot install --nginx --non-interactive --redirect --cert-name "$DOMAIN"
    else
        echo "    🆕 Certificate missing. Requesting new..."
        sudo certbot run --nginx --non-interactive --agree-tos --redirect -m "$CERT_EMAIL" -d "$DOMAIN"
    fi
    sudo systemctl reload nginx
fi
echo ">>> ✅ UPDATE COMPLETED!"
EOF
    chmod +x update.sh
fi

# --- 4. CONFIG TEMPLATES ---
if [ ! -d "$SERVER_CONF_DIR" ]; then mkdir -p "$SERVER_CONF_DIR"; fi

if [ "$SETUP_SYSTEMD" == "True" ]; then
    cat > "$SERVER_CONF_DIR/$SERVICE_FILE" <<EOF
[Unit]
Description=Gunicorn instance for $PROJECT_NAME
After=network.target

[Service]
User=root
Group=www-data
WorkingDirectory=$PROJECT_DIR
Environment="PATH=$PROJECT_DIR/venv/bin"
ExecStart=$PROJECT_DIR/venv/bin/gunicorn --config gunicorn_config.py wsgi:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF
fi

if [ "$SETUP_NGINX" == "True" ]; then
    cat > "$SERVER_CONF_DIR/$NGINX_FILE" <<EOF
server {
    server_name $DOMAIN;
    access_log /var/log/nginx/${PROJECT_NAME}_access.log;
    error_log /var/log/nginx/${PROJECT_NAME}_error.log;

    location /static {
        alias $PROJECT_DIR/app/static;
        expires 30d;
    }

    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_connect_timeout 300s;
        proxy_read_timeout 300s;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
fi

# --- 5. INSTALL LIBS ---
mkdir -p "$LOGS_DIR"
if [ ! -d "venv" ]; then python3 -m venv venv; fi
echo ">>> 📦 Installing requirements..."
source venv/bin/activate
pip install -r requirements.txt > /dev/null

# --- 6. APPLY & VERIFY (ROBUST MODE) ---

# A. DEPLOY APP
if [ "$SETUP_SYSTEMD" == "True" ]; then
    echo ">>> ⚙️  Deploying Service..."
    if [ -f "$SERVER_CONF_DIR/$SERVICE_FILE" ]; then
        sudo cp "$SERVER_CONF_DIR/$SERVICE_FILE" "/etc/systemd/system/$SERVICE_FILE"
        sudo systemctl daemon-reload
        sudo systemctl enable "$SERVICE_NAME"
        
        echo "    - Restarting $SERVICE_NAME..."
        sudo systemctl restart "$SERVICE_NAME"
        
        # --- CHỜ MỀM (SOFT WAIT) ---
        wait_for_port_soft "$APP_PORT" || echo "    -> Tiếp tục cấu hình Nginx (App có thể sẽ tự chạy sau)..."

        # Startup List
        if [ ! -f "$GUNICORN_LIST_FILE" ]; then touch "$GUNICORN_LIST_FILE"; fi
        if ! grep -Fxq "$SERVICE_FILE" "$GUNICORN_LIST_FILE"; then
            [ -n "$(tail -c1 "$GUNICORN_LIST_FILE")" ] && echo >> "$GUNICORN_LIST_FILE"
            echo "$SERVICE_FILE" >> "$GUNICORN_LIST_FILE"
        fi
    fi
fi

# B. DEPLOY NGINX & SSL
if [ "$SETUP_NGINX" == "True" ]; then
    echo ">>> 🌐 Deploying Nginx..."
    if [ -f "$SERVER_CONF_DIR/$NGINX_FILE" ]; then
        sudo cp "$SERVER_CONF_DIR/$NGINX_FILE" "/etc/nginx/sites-available/$NGINX_FILE"
        if [ ! -f "/etc/nginx/sites-enabled/$NGINX_FILE" ]; then
            sudo ln -s "/etc/nginx/sites-available/$NGINX_FILE" "/etc/nginx/sites-enabled/$NGINX_FILE"
        fi
        
        if ! sudo nginx -t; then echo "❌ Config Nginx lỗi. Không thể tiếp tục."; exit 1; fi
        
        sudo systemctl reload nginx 

        echo ">>> 🔑 Checking SSL (Safe Mode)..."
        CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
        
        if [ -f "$CERT_PATH" ]; then
            echo "    ✅ Certificate found. Re-installing config..."
            sudo certbot install --nginx --non-interactive --redirect --cert-name "$DOMAIN"
        else
            echo "    🆕 Certificate missing. Requesting NEW certificate..."
            sudo certbot run --nginx --non-interactive --agree-tos --redirect -m "$CERT_EMAIL" -d "$DOMAIN"
        fi
        
        sudo systemctl reload nginx
    fi
fi

echo ">>> ✅ DEPLOY COMPLETED! Web sẽ hoạt động ngay khi App khởi động xong."