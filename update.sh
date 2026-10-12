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
