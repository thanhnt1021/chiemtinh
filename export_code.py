import os

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))

# Các thư mục cần bỏ qua (Chuẩn chung)
IGNORE_DIRS = {
    'venv', '__pycache__', '.git', 'logs', 'node_modules', 'static/images', '_old_code_backup/'
}

# Các file cần bỏ qua TUYỆT ĐỐI (Tránh loop và file rác)
# LƯU Ý: Không bỏ qua 'export_code.py' để nó tự export chính nó
IGNORE_FILES = {
    '.DS_Store', 'old.txt', 'full_project_source.txt', 
    'poetry.lock', 'package-lock.json', 'old.txt'
}

# Các đuôi file cần lấy nội dung (Code files)
INCLUDE_EXTENSIONS = {
    '.py', '.html', '.css', '.js', '.sh', '.txt', '.md', '.json', '.conf', '.service', '.ini'
}

# Các file bắt buộc lấy (bất chấp đuôi hoặc bị ignore nhầm)
ALWAYS_INCLUDE = {'requirements.txt', 'project_conf.py', 'export_code.py'}

OUTPUT_FILE = 'full_project_source.txt'

def is_text_file(filename):
    # Luôn lấy file trong ALWAYS_INCLUDE
    if filename in ALWAYS_INCLUDE:
        return True
    
    # Bỏ qua file trong IGNORE_FILES
    if filename in IGNORE_FILES:
        return False
        
    # Lấy file có đuôi cho phép
    return any(filename.endswith(ext) for ext in INCLUDE_EXTENSIONS)

def collect_files(start_path):
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as outfile:
        outfile.write(f"=== PROJECT EXPORT ===\n\n")
        for root, dirs, files in os.walk(start_path):
            # Lọc bỏ thư mục trong IGNORE_DIRS và thư mục ẩn
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS and not d.startswith('.')]
            
            for file in files:
                # Bỏ qua file ẩn
                if file.startswith('.'): continue
                
                # Kiểm tra điều kiện lấy file
                if not is_text_file(file): continue
                
                path = os.path.join(root, file)
                rel_path = os.path.relpath(path, start_path)
                
                outfile.write(f"{'='*60}\nFILE: {rel_path}\n{'='*60}\n")
                try:
                    with open(path, 'r', encoding='utf-8', errors='ignore') as f: 
                        outfile.write(f.read() + "\n\n")
                except: 
                    outfile.write("[Error reading file]\n\n")
                    
    print(f"✅ Exported to {OUTPUT_FILE}")

if __name__ == "__main__":
    collect_files(PROJECT_DIR)
