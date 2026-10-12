# setup.py
import subprocess
import os
import sys
import argparse

def create_requirements():
    """Nếu không có file requirements.txt thì tạo file này từ pip freeze."""
    print("Không tìm thấy requirements.txt. Tạo file mới từ pip freeze ...")
    with open("requirements.txt", "w") as f:
        result = subprocess.run(["pip", "freeze"], capture_output=True, text=True)
        f.write(result.stdout)
    print("Đã tạo file requirements.txt.")

def get_package_version(pip_name):
    """Lấy phiên bản của package từ pip show."""
    result = subprocess.run(["pip", "show", pip_name], capture_output=True, text=True)
    for line in result.stdout.splitlines():
        if line.startswith("Version: "):
            return line.split(": ")[1]
    return None

def update_package(package, version=None):
    """
    Cài đặt hoặc nâng cấp package. Với tên chứa '_' sẽ chuyển thành '-' khi pip install.
    """
    pip_name = package.replace('_','-')
    install_cmd = ["pip", "install"]
    if version:
        install_cmd.append(f"{pip_name}=={version}")
        print(f"Cài đặt package: {pip_name} phiên bản {version}")
    else:
        install_cmd += [pip_name, "--upgrade"]
        print(f"Nâng cấp package: {pip_name} lên phiên bản mới nhất")

    subprocess.run(install_cmd)

    pkg_version = get_package_version(pip_name)
    if pkg_version:
        new_line = f"{pip_name}=={pkg_version}"
        if not os.path.exists("requirements.txt"):
            with open("requirements.txt", "w") as f:
                f.write(new_line + "\n")
            print(f"Đã tạo requirements.txt với dòng: {new_line}")
        else:
            with open("requirements.txt", "r") as f:
                lines = f.readlines()
            updated = False
            with open("requirements.txt", "w") as f:
                for line in lines:
                    if line.lower().startswith(pip_name.lower()+"=="):
                        f.write(new_line+"\n")
                        updated = True
                    else:
                        f.write(line)
                if not updated:
                    f.write(new_line+"\n")
                    print(f"Thêm {new_line} vào requirements.txt")
            print(f"Đã cập nhật requirements.txt với {new_line}")
    else:
        print(f"Không xác định được phiên bản của {pip_name} sau khi cài đặt.")

def install_requirements():
    """Cài đặt tất cả các package có trong requirements.txt."""
    print("Tiến hành cài đặt các package từ requirements.txt ...")
    subprocess.run(["pip", "install", "-r", "requirements.txt"])

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Setup script để cài đặt hoặc nâng cấp package và cập nhật requirements.txt"
    )
    parser.add_argument(
        "packages", nargs="*", help="Tên package (python import name) muốn cài đặt hoặc nâng cấp"
    )
    parser.add_argument("--version", help="Phiên bản cụ thể của package (ví dụ: 2.0.0)")
    args = parser.parse_args()

    if args.packages:
        for pkg in args.packages:
            update_package(pkg, version=args.version)
    else:
        if not os.path.exists("requirements.txt"):
            create_requirements()
        install_requirements()


