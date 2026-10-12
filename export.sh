#!/bin/bash
set -e

# ==============================================================================
# EXPORT.SH - SCRIPT XUẤT SOURCE CODE
# ==============================================================================

# Lấy thư mục hiện tại chứa script
PROJECT_DIR=$(dirname "$(readlink -f "$0")")

echo ">>> 📂 Đang ở thư mục: $PROJECT_DIR"

# Kiểm tra xem có môi trường ảo (venv) không
if [ -d "$PROJECT_DIR/venv" ]; then
    echo ">>> 🐍 Kích hoạt môi trường ảo (venv)..."
    source "$PROJECT_DIR/venv/bin/activate"
else
    echo ">>> ⚠️  Không tìm thấy venv. Đang thử chạy bằng python hệ thống..."
fi

# Chạy script export_code.py
if [ -f "$PROJECT_DIR/export_code.py" ]; then
    echo ">>> 📄 Đang chạy export_code.py..."
    python3 "$PROJECT_DIR/export_code.py"
    echo ">>> ✅ Hoàn tất! Kiểm tra file 'full_project_source.txt'."
else
    echo "❌ Lỗi: Không tìm thấy file export_code.py!"
    exit 1
fi