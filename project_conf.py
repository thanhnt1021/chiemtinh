# ==============================================================================
# MASTER CONFIGURATION FILE
# Chỉ cần chỉnh sửa thông tin tại đây. deploy.sh và update.sh sẽ lo phần còn lại.
# ==============================================================================

# --- 1. THÔNG TIN ỨNG DỤNG ---
APP_PORT = 65501                # Port nội bộ Gunicorn chạy (WSGI sẽ lấy port này)
PROJECT_NAME = "chiemtinh"      # Tên gợi nhớ cho process (hiện trong htop)

# --- 2. CẤU HÌNH SERVER (NGINX & SYSTEMD) ---
# Tên file bạn muốn tạo ra trong server_conf/ và copy vào /etc/...
NGINX_CONF_FILENAME = "chiemtinh.conf"
SYSTEMD_SERVICE_FILENAME = "chiemtinh.service"

# Domain chính để config Nginx và chạy Certbot
DOMAIN_NAME = "chiemtinh.jst4.fun"
CERTBOT_EMAIL = "admin@chiemtinh.jst4.fun"

# --- 3. CHẾ ĐỘ TRIỂN KHAI CHI TIẾT (ON/OFF) ---
# SETUP_SYSTEMD: Tạo/Update file service, start Gunicorn qua systemd
# SETUP_NGINX: Tạo/Update file nginx, chạy Certbot
SETUP_SYSTEMD = True
SETUP_NGINX = True