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
