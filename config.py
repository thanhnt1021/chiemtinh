import os
import secrets
import astro00_lib as lib

class Config:
    # Đường dẫn hệ thống
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    EPHE_PATH = os.path.join(BASE_DIR, 'ephe')
    SECRET_FILE = os.path.join(BASE_DIR, 'secret.key')
    CREDS_PATH = os.path.join(BASE_DIR, 'mine01.json')

    # Cấu hình Web
    PERMANENT_SESSION_LIFETIME = 86400 * 30 # 30 ngày
    
    # Cấu hình Admin
    ADMIN_USER = "nguydev"
    ADMIN_PASS_HASH = lib.hash_password("***DA-GO***")

    # Cấu hình Google Services
    SHEETS_SCOPE = ['https://spreadsheets.google.com/feeds', 'https://www.googleapis.com/auth/drive']
    SPREADSHEET_KEY_PLANETS = '1JKvme29_UelRvZzN_pzzg5ZLh9HIT0lWo1uf7UlpCbs'
    
    # --- CẬP NHẬT TÊN SHEET ---
    WORKSHEET_NAME_NATAL = 'Natallist'       # Sheet cho chế độ Natal
    WORKSHEET_NAME_SYNASTRY = 'Synastrylist' # Sheet cho chế độ Synastry
    
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