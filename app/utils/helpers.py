# app/utils/helpers.py
import unicodedata
from flask import request, session
import astro00_lib as lib

def clean_text(text):
    if not text: return ""
    text = unicodedata.normalize('NFD', text)
    text = "".join([c for c in text if unicodedata.category(c) != 'Mn'])
    return text.lower().replace(" ", "").replace("-", "").strip()

def safe_float(val, default=0.0):
    if val is None: return default
    try:
        s_val = str(val).strip()
        if not s_val: return default
        return float(s_val)
    except (ValueError, TypeError):
        return default

def safe_int(val, default=0):
    if val is None: return default
    try:
        s_val = str(val).strip()
        if not s_val: return default
        return int(s_val)
    except (ValueError, TypeError):
        return default

def parse_profile_from_form(prefix=""):
    """
    Hàm bóc tách dữ liệu hồ sơ từ Form một cách an toàn.
    Sử dụng Safe-casting để chống lỗi 500 khi trường dữ liệu rỗng.
    """
    # Nếu prefix là 'new', 'A', 'B'... thì tên trường sẽ là 'new_name', 'A_name'...
    # Nếu prefix là rỗng thì tên trường giữ nguyên 'name'
    p = prefix + "_" if prefix and prefix != "" else ""
    
    try:
        name = request.form.get(f'{p}name')
        if not name: return None
        
        # Bóc tách và ép kiểu an toàn
        day = safe_int(request.form.get(f'{p}day'), 1)
        month = safe_int(request.form.get(f'{p}month'), 1)
        year = safe_int(request.form.get(f'{p}year'), 2000)
        hour = safe_int(request.form.get(f'{p}hour'), 12)
        minute = safe_int(request.form.get(f'{p}minute'), 0)

        lat = safe_float(request.form.get(f'{p}lat'), 21.02)
        lon = safe_float(request.form.get(f'{p}lon'), 105.85)
        tz = request.form.get(f'{p}tz', 'Asia/Ho_Chi_Minh')
        address = request.form.get(f'{p}address', 'Hanoi, Vietnam')
        country_code = request.form.get(f'{p}country_code', 'vn')

        manual_tz_raw = request.form.get(f'{p}manual_tz')
        manual_tz_val = None
        if manual_tz_raw and str(manual_tz_raw).strip():
            try: manual_tz_val = float(manual_tz_raw)
            except: manual_tz_val = None

        return {
            "user_id": session.get('user_id'),
            "name": name.strip(),
            "gender": request.form.get(f'{p}gender', 'Female'),
            "dob": {"day": day, "month": month, "year": year},
            "tob": {"hour": hour, "minute": minute, "unknown": False},
            "loc": {
                "address": address, 
                "lat": lat, 
                "lon": lon, 
                "tz": tz, 
                "country_code": country_code
            },
            "tz_offset": manual_tz_val
        }
    except Exception as e:
        print(f"Helper parse form error ({prefix}): {e}")
        return None

def resolve_profile_logic(user_id, prefix='', profiles_list=None):
    """
    Logic xác định hồ sơ người dùng chọn:
    1. Nếu mode là 'existing': Tìm trong danh sách hồ sơ cũ.
    2. Nếu mode là 'new': Parse dữ liệu mới từ Form.
    Trả về Dict Profile hoặc None.
    """
    # Xác định key của mode (mode, mode_A, mode_B)
    mode_key = f'mode_{prefix}' if prefix in ['A', 'B'] else 'mode'
    mode = request.form.get(mode_key, 'existing')
    
    if mode == 'existing':
        # Xác định key của tên hồ sơ (profile, profileA, profileB)
        profile_key = f'profile{prefix}' if prefix in ['A', 'B'] else 'profile'
        target_name = request.form.get(profile_key)
        
        if not target_name: return None
        
        if not profiles_list:
            profiles_list = lib.load_profiles(user_id)
            
        p = next((x for x in profiles_list if x['name'].strip() == target_name.strip()), None)
        return p

    # Nếu là mode 'new' (prefix có thể là 'new' cho natal/transit hoặc 'A'/'B' cho cặp đôi)
    return parse_profile_from_form(prefix)
