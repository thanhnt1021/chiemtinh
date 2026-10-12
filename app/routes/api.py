from flask import Blueprint, request, jsonify, send_file, Response, session
from geopy.geocoders import Nominatim
from timezonefinder import TimezoneFinder
import io
import os
import sys
from googleapiclient.http import MediaIoBaseDownload
import app.cache as cache
from app.utils.google_services import get_planet_data_from_sheet, get_drive_service, cache_drive_images
import astro00_lib as lib
from config import Config

api_bp = Blueprint('api', __name__)

# Bản đồ mã bang của Mỹ để hiển thị chuẩn phong cách Astro.com
US_STATE_TO_CODE = {
    "Alabama": "AL", "Alaska": "AK", "Arizona": "AZ", "Arkansas": "AR", "California": "CA", "Colorado": "CO",
    "Connecticut": "CT", "Delaware": "DE", "Florida": "FL", "Georgia": "GA", "Hawaii": "HI", "Idaho": "ID",
    "Illinois": "IL", "Indiana": "IN", "Iowa": "IA", "Kansas": "KS", "Kentucky": "KY", "Louisiana": "LA",
    "Maine": "ME", "Maryland": "MD", "Massachusetts": "MA", "Michigan": "MI", "Minnesota": "MN",
    "Mississippi": "MS", "Missouri": "MO", "Montana": "MT", "Nebraska": "NE", "Nevada": "NV",
    "New Hampshire": "NH", "New Jersey": "NJ", "New Mexico": "NM", "New York": "NY", "North Carolina": "NC",
    "North Dakota": "ND", "Ohio": "OH", "Oklahoma": "OK", "Oregon": "OR", "Pennsylvania": "PA",
    "Rhode Island": "RI", "South Carolina": "SC", "South Dakota": "SD", "Tennessee": "TN", "Texas": "TX",
    "Utah": "UT", "Vermont": "VT", "Virginia": "VA", "Washington": "WA", "West Virginia": "WV",
    "Wisconsin": "WI", "Wyoming": "WY", "District of Columbia": "DC"
}

@api_bp.route('/api/search-location')
def search_location_api():
    q = request.args.get('q', '').strip()
    cc = request.args.get('cc', '').strip()     # Country Code (ISO)
    cn = request.args.get('cn', '').strip()     # Country Name (Manual)
    
    if not q:
        return jsonify([])
    
    # Cache key cho phiên bản Super Search mới
    cache_key = f"loc_v6_ultra_{q.lower()}_{cc.lower()}_{cn.lower()}"
    if cache_key in cache.LOCATION_CACHE:
        return jsonify(cache.LOCATION_CACHE[cache_key])
    
    try:
        # User-Agent uy tín để Nominatim trả về nhiều kết quả hơn
        geo = Nominatim(user_agent="AstroSystem_Astrocom_Mirror_v1.6", timeout=15)
        
        search_query = q
        # limit=50 để quét sạch mọi ngóc ngách như Astro.com
        search_params = {
            "exactly_one": False, 
            "limit": 50, 
            "language": 'en', 
            "addressdetails": True
        }
        
        if cc and cc != 'other':
            search_params["country_codes"] = cc
        elif cc == 'other' and cn:
            search_query = f"{q}, {cn}"

        locs = geo.geocode(search_query, **search_params)
        
        # Thử tìm kiếm mở rộng nếu lọc theo quốc gia không ra kết quả
        if not locs and cc and cc != 'other':
            search_params.pop("country_codes", None)
            locs = geo.geocode(f"{q}, {cc}", **search_params)

        results = []
        seen_ids = set() # Dùng OSM_ID để khử trùng chuẩn xác nhất

        if locs:
            tf = TimezoneFinder()
            for l in locs:
                if l.raw.get('place_id') in seen_ids:
                    continue
                seen_ids.add(l.raw.get('place_id'))

                addr = l.raw.get('address', {})
                country_code = addr.get('country_code', '').lower()
                
                # --- LOGIC BÓC TÁCH ĐỊA DANH SIÊU CHI TIẾT THEO PHÂN CẤP ---
                # Lấy tên cụ thể nhất có thể
                specific_name = (
                    addr.get('hospital') or addr.get('university') or addr.get('amenity') or
                    addr.get('suburb') or addr.get('neighbourhood') or addr.get('hamlet') or
                    addr.get('village') or addr.get('city_district') or addr.get('town') or 
                    addr.get('city') or addr.get('county') or q.split(',')[0]
                )
                
                state_full = addr.get('state') or addr.get('province') or ""
                country_full = addr.get('country', '')

                # Định dạng hiển thị chuẩn Astro.com: "City, ST (US) = State_Name, Coords"
                if country_code in lib.COUNTRIES_WITH_STATES:
                    # Nếu là Mỹ, Canada... hiển thị mã Bang
                    state_code = US_STATE_TO_CODE.get(state_full, state_full) if country_code == 'us' else state_full
                    
                    # Nếu kết quả trả về chính là 1 Bang (không phải thành phố), ghi chú rõ
                    if l.raw.get('type') == 'state' or specific_name == state_full:
                        label_prefix = f"{state_full} (State)"
                    else:
                        label_prefix = f"{specific_name}, {state_code} ({country_code.upper()})"
                    
                    label_suffix = f"{state_full}"
                else:
                    # Các nước không chia bang (Việt Nam...)
                    label_prefix = f"{specific_name} ({country_code.upper()})"
                    label_suffix = f"{country_full}"
                
                # Format tọa độ Astro (ví dụ: 40n43, 74w00)
                astro_coords = lib.format_coord_astro_pair(l.latitude, l.longitude)
                display_label = f"{label_prefix} = {label_suffix}, {astro_coords}"

                results.append({
                    "display_name": display_label, 
                    "short_name": f"{specific_name}, {state_full if state_full else country_full} ({country_code.upper()})",
                    "lat": l.latitude, 
                    "lon": l.longitude,
                    "country_code": country_code,
                    "tz": tf.timezone_at(lng=l.longitude, lat=l.latitude) or "UTC"
                })
                
        cache.LOCATION_CACHE[cache_key] = results
        return jsonify(results)
    except Exception as e:
        print(f"Super Search API Error: {e}")
        return jsonify([])

@api_bp.route('/api/planet-data')
def planet_data_api():
    return jsonify(get_planet_data_from_sheet())

@api_bp.route('/api/planet-images')
def planet_images_api():
    if not cache.cho_images_cache:
        cache_drive_images()
    return jsonify({"cho": cache.cho_images_cache, "nhan": cache.nhan_images_cache})

@api_bp.route('/api/image/<file_id>')
def image_proxy(file_id):
    try:
        service = get_drive_service()
        req = service.files().get_media(fileId=file_id)
        fh = io.BytesIO()
        MediaIoBaseDownload(fh, req).next_chunk()
        fh.seek(0)
        return send_file(fh, mimetype='image/png')
    except:
        return Response(status=404)

@api_bp.route('/api/tra-goc-transit', methods=['POST'])
def tra_goc_transit():
    if 'user_id' not in session:
        return jsonify([]), 403
    data = request.json
    lib.swe.set_ephe_path(Config.EPHE_PATH)
    profiles = lib.load_profiles(session['user_id'])
    target_name = data.get('natal_name', '').strip()
    p = next((x for x in profiles if x['name'].strip() == target_name), None)
    if not p:
        return jsonify([])
    natal = lib.calculate_chart(f"{p['dob']['day']}/{p['dob']['month']}/{p['dob']['year']}", f"{p['tob']['hour']}:{p['tob']['minute']}", p['loc']['lat'], p['loc']['lon'], p['loc']['tz'], manual_offset=p.get('tz_offset'))
    if not natal:
        return jsonify([])
    res = lib.find_exact_aspect_times(data['p_trans'], data['p_natal'], data['aspect'], f"{data['day']}/{data['month']}/{data['year']}", natal)
    return jsonify(res)

@api_bp.route('/api/tra-hoi-vi', methods=['POST'])
def tra_hoi_vi():
    if 'user_id' not in session:
        return jsonify([]), 403
    data = request.json
    lib.swe.set_ephe_path(Config.EPHE_PATH)
    profiles = lib.load_profiles(session['user_id'])
    target_name = data.get('natal_name', '').strip()
    p = next((x for x in profiles if x['name'].strip() == target_name), None)
    if not p:
        return jsonify([])
    natal = lib.calculate_chart(f"{p['dob']['day']}/{p['dob']['month']}/{p['dob']['year']}", f"{p['tob']['hour']}:{p['tob']['minute']}", p['loc']['lat'], p['loc']['lon'], p['loc']['tz'], manual_offset=p.get('tz_offset'))
    if not natal:
        return jsonify([])
    res = lib.find_return_times(data['p_trans'], f"{data['day']}/{data['month']}/{data['year']}", natal)
    return jsonify(res)

@api_bp.route('/api/tra-nha-transit', methods=['POST'])
def tra_nha_transit():
    if 'user_id' not in session:
        return jsonify({}), 403
    data = request.json
    lib.swe.set_ephe_path(Config.EPHE_PATH)
    profiles = lib.load_profiles(session['user_id'])
    target_name = data.get('natal_name', '').strip()
    p = next((x for x in profiles if x['name'].strip() == target_name), None)
    if not p:
        return jsonify({})
    natal = lib.calculate_chart(f"{p['dob']['day']}/{p['dob']['month']}/{p['dob']['year']}", f"{p['tob']['hour']}:{p['tob']['minute']}", p['loc']['lat'], p['loc']['lon'], p['loc']['tz'], manual_offset=p.get('tz_offset'))
    res = lib.find_current_house_transit_period(data['p_trans'], natal, d=data.get('day'), m=data.get('month'), y=data.get('year'))
    return jsonify(res)
