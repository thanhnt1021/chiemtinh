import os
import io
import gspread
from oauth2client.service_account import ServiceAccountCredentials
from google.oauth2.service_account import Credentials as ServiceAccountCreds_GoogleAuth
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload
from config import Config
import app.cache as cache
from app.utils.helpers import clean_text

def get_google_sheet_client():
    creds = ServiceAccountCredentials.from_json_keyfile_name(Config.CREDS_PATH, Config.SHEETS_SCOPE)
    return gspread.authorize(creds)

def get_drive_service():
    creds = ServiceAccountCreds_GoogleAuth.from_service_account_file(Config.CREDS_PATH, scopes=Config.DRIVE_SCOPE)
    return build('drive', 'v3', credentials=creds)

def get_planet_data_from_sheet():
    """
    Lấy dữ liệu từ cả 2 sheet: Natallist và Synastrylist
    """
    try:
        client = get_google_sheet_client()
        sh = client.open_by_key(Config.SPREADSHEET_KEY_PLANETS)
        
        # 1. LẤY DATA NATAL
        sheet_natal = sh.worksheet(Config.WORKSHEET_NAME_NATAL)
        records_natal = sheet_natal.get_all_records()
        natal_data = []
        for row in records_natal:
            p_name = row.get("Hành tinh", "").strip()
            if not p_name: continue
            natal_data.append({
                "name": p_name,
                "code": clean_text(p_name),
                "type": row.get("Loại hành tinh", "").strip(),
                "text_pos": row.get("Tích cực", "").strip(),
                "text_neg": row.get("Tiêu cực", "").strip(),
                "text_rec": row.get("Nhận về", "").strip()
            })

        # 2. LẤY DATA SYNASTRY
        # Nếu chưa tạo sheet này thì trả về rỗng để không lỗi app
        synastry_data = []
        try:
            sheet_synastry = sh.worksheet(Config.WORKSHEET_NAME_SYNASTRY)
            records_synastry = sheet_synastry.get_all_records()
            for row in records_synastry:
                p_name = row.get("Hành tinh", "").strip()
                if not p_name: continue
                synastry_data.append({
                    "name": p_name,
                    "code": clean_text(p_name),
                    "text_give": row.get("Truyền đi", "").strip(),
                    "text_receive": row.get("Nhận về", "").strip()
                })
        except gspread.exceptions.WorksheetNotFound:
            print(f"Warning: Worksheet '{Config.WORKSHEET_NAME_SYNASTRY}' not found.")

        return {
            "natal": natal_data,
            "synastry": synastry_data
        }

    except Exception as e:
        return {"error": str(e)}

def find_folder_id(service, folder_name, parent_id):
    try:
        query = f"'{parent_id}' in parents and mimeType='application/vnd.google-apps.folder'"
        response = service.files().list(q=query, spaces='drive', fields='files(id, name)').execute()
        for f in response.get('files', []):
            if f.get('name').lower() == folder_name.lower(): return f.get('id')
        return None
    except:
        return None

def get_files_from_folder(service, folder_id):
    local_cache = {}
    if not folder_id: return local_cache
    try:
        query = f"'{folder_id}' in parents"
        response = service.files().list(q=query, spaces='drive', fields='files(id, name, mimeType)').execute()
        for file in response.get('files', []):
            if 'image' in file.get('mimeType') or file.get('name').lower().endswith(('.jpg', '.png')):
                key = clean_text(os.path.splitext(file.get('name'))[0])
                local_cache[key] = f"/api/image/{file.get('id')}"
        return local_cache
    except:
        return local_cache

def cache_drive_images():
    try:
        service = get_drive_service()
        cho_id = find_folder_id(service, "CHO", Config.DRIVE_FOLDER_ID)
        nhan_id = find_folder_id(service, "NHAN", Config.DRIVE_FOLDER_ID)
        if cho_id: cache.cho_images_cache = get_files_from_folder(service, cho_id)
        if nhan_id: cache.nhan_images_cache = get_files_from_folder(service, nhan_id)
        print("--- Đã cache ảnh từ Drive ---")
    except Exception as e:
        print(f"Lỗi cache ảnh: {e}")
