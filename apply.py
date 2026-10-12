import os
import re
import sys

# --- CẤU HÌNH ĐỘNG (AUTO-DETECT) ---

# Lấy đường dẫn tuyệt đối của thư mục chứa file script này
current_script_dir = os.path.dirname(os.path.abspath(__file__))

# PROJECT_ROOT bây giờ chính là thư mục chứa script này
PROJECT_ROOT = current_script_dir

# File nguồn old.txt nằm cùng thư mục với script
SOURCE_FILE = os.path.join(PROJECT_ROOT, 'old.txt')

# DANH SÁCH ĐƯỢC PHÉP CẬP NHẬT (WHITELIST)
ALLOWED_PREFIXES = [
    'app/',
    'astro00_lib/'
]

def is_allowed(filename):
    """Kiểm tra xem file có thuộc phạm vi cho phép update không."""
    norm_name = filename.replace('\\', '/')
    for prefix in ALLOWED_PREFIXES:
        if norm_name.startswith(prefix):
            return True
    return False

def parse_and_update():
    if not os.path.exists(SOURCE_FILE):
        print(f"❌ Lỗi: Không tìm thấy file nguồn tại: {SOURCE_FILE}")
        print(f"👉 Vui lòng đảm bảo 'old.txt' nằm cùng thư mục với file script này.")
        return

    print(f"📂 Thư mục gốc (Project Root): {PROJECT_ROOT}")
    print(f"🚀 Bắt đầu cập nhật từ: {SOURCE_FILE}")
    print(f"🎯 Phạm vi cho phép: {ALLOWED_PREFIXES}")
    print("-" * 60)

    try:
        with open(SOURCE_FILE, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"❌ Lỗi khi đọc file nguồn: {e}")
        return

    current_file = None
    buffer = []
    separator_pattern = re.compile(r'^={60}$')  # Dòng chứa 60 dấu bằng
    file_pattern = re.compile(r'^FILE: (.+)$')  # Dòng chứa tên file

    i = 0
    while i < len(lines):
        line = lines[i].rstrip('\n')

        # Kiểm tra dòng phân cách bắt đầu file
        if separator_pattern.match(line.strip()):
            # Lưu file trước đó nếu có
            if current_file and buffer:
                save_file(current_file, buffer)
                current_file = None
                buffer = []

            # Tìm tên file ở dòng tiếp theo
            if i + 1 < len(lines):
                next_line = lines[i+1].strip()
                file_match = file_pattern.match(next_line)
                if file_match:
                    current_file = file_match.group(1).strip()
                    # Nhảy qua header
                    if i + 2 < len(lines) and separator_pattern.match(lines[i+2].strip()):
                        i += 3 
                        continue
                    else:
                        i += 2
                        continue
        
        # Nếu đang trong trạng thái đọc nội dung file
        if current_file:
            if not separator_pattern.match(line.strip()):
                buffer.append(lines[i])
        
        i += 1

    # Lưu file cuối cùng
    if current_file and buffer:
        save_file(current_file, buffer)

    print("-" * 60)
    print("✅ Hoàn tất quá trình cập nhật.")

def save_file(rel_path, content_lines):
    """Ghi nội dung vào file nếu đường dẫn hợp lệ."""
    
    if not is_allowed(rel_path):
        print(f"⏭️  Bỏ qua (Skip): {rel_path}")
        return

    full_path = os.path.join(PROJECT_ROOT, rel_path)
    dir_name = os.path.dirname(full_path)

    try:
        if not os.path.exists(dir_name):
            os.makedirs(dir_name, exist_ok=True)
            print(f"   + Đã tạo thư mục: {dir_name}")

        content_str = "".join(content_lines).strip() + "\n"
        
        with open(full_path, 'w', encoding='utf-8') as f:
            f.write(content_str)
        
        print(f"✅ Đã cập nhật: {rel_path}")

    except Exception as e:
        print(f"❌ Lỗi khi ghi file {rel_path}: {str(e)}")

if __name__ == "__main__":
    parse_and_update()