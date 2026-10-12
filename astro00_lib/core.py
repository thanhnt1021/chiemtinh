# astro00_lib/core.py
import swisseph as swe
import os
import ssl
import certifi
import sys
from datetime import datetime, timedelta
import pytz
from zoneinfo import ZoneInfo
from timezonefinder import TimezoneFinder
import geopy.geocoders
from .const import ZODIAC_NAMES, ZODIAC_CODES, ASPECTS_DEF, PLANET_IDS, OUTER_PLANETS, RULER_MAP, CORE_PLANETS

# --- CẤU HÌNH SSL VÀ ĐƯỜNG DẪN EPHE ---
try:
    ctx = ssl.create_default_context(cafile=certifi.where())
    geopy.geocoders.options.default_ssl_context = ctx
except:
    pass

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EPHE_PATH = os.path.join(BASE_DIR, 'ephe')
swe.set_ephe_path(EPHE_PATH)


def get_zodiac(lon):
    """Xác định cung hoàng đạo và độ trong cung."""
    lon = lon % 360
    idx = int(lon / 30)
    deg_in_sign = lon % 30
    return idx, ZODIAC_NAMES[idx], ZODIAC_CODES[idx], deg_in_sign


def get_house_of_planet(planet_lon, cusps):
    """Xác định hành tinh nằm ở nhà nào."""
    p_lon = planet_lon % 360
    real_cusps = list(cusps)
    if len(real_cusps) == 13: 
        real_cusps = real_cusps[1:]
    for i in range(12):
        c_curr = real_cusps[i]
        c_next = real_cusps[(i + 1) % 12]
        dist_p = (p_lon - c_curr) % 360
        size_h = (c_next - c_curr) % 360
        if dist_p < size_h: 
            return i + 1
    return 1


def round_orb(orb_val):
    """Làm tròn Orb để hiển thị."""
    return int(round(orb_val))


def check_aspect(p1_lon, p2_lon, custom_orbs=None):
    """Kiểm tra góc hợp giữa hai tọa độ hành tinh."""
    diff = abs(p1_lon - p2_lon)
    if diff > 180: 
        diff = 360 - diff
    for asp_name, asp_data in ASPECTS_DEF.items():
        limit = asp_data["orb"]
        if custom_orbs and asp_name in custom_orbs: 
            limit = custom_orbs[asp_name]
        if abs(diff - asp_data["angle"]) <= limit:
            raw_orb = abs(diff - asp_data["angle"])
            if raw_orb >= 10.0: 
                return None
            return {
                "aspect": asp_name, 
                "name_vn": asp_data["name_vn"], 
                "orb": raw_orb, 
                "orb_round": round_orb(raw_orb),
                "type": asp_data["type"], 
                "symbol": asp_data["symbol"]
            }
    return None


def get_timezone_str(lat, lon):
    """Lấy tên timezone IANA từ tọa độ."""
    tf = TimezoneFinder()
    return tf.timezone_at(lng=lon, lat=lat)


def get_true_lmt_offset(lon):
    """Tính LMT (Local Mean Time) dựa trên kinh độ."""
    return lon / 15.0


def is_coord_in_vietnam(lat, lon):
    """Kiểm tra xem tọa độ có thuộc Việt Nam hay không."""
    if 8.0 <= lat <= 24.0 and 102.0 <= lon <= 110.0:
        return True
    return False


def get_vietnam_historical_offset(year, month, day, lat, lon):
    """Logic lịch sử múi giờ Việt Nam - GIỮ NGUYÊN 100% NHƯ CAM KẾT."""
    ymd = (year, month, day)
    if ymd < (1906, 7, 1): 
        return lon / 15.0
    if (1906, 7, 1) <= ymd <= (1911, 4, 30): 
        return 7.1083  # 7h06m30s
    if (1911, 5, 1) <= ymd <= (1942, 12, 31): 
        return 7.0
    if (1943, 1, 1) <= ymd <= (1945, 3, 13): 
        return 8.0
    if (1945, 3, 14) <= ymd <= (1945, 9, 1): 
        return 9.0
    if (1945, 9, 2) <= ymd < (1975, 6, 13):
        is_south = lat < 17.0
        if not is_south:
            return 7.0
        else:
            if ymd <= (1955, 6, 30):
                return 8.0
            elif (1955, 7, 1) <= ymd <= (1959, 12, 31):
                return 7.0
            else:
                return 8.0
    return 7.0


def to_dms(deg, is_lat=True):
    """Chuyển tọa độ sang định dạng Độ Phút Giây."""
    direction = ""
    if is_lat:
        direction = "N" if deg >= 0 else "S"
    else:
        direction = "E" if deg >= 0 else "W"
    adeg = abs(deg)
    d = int(adeg)
    m_float = (adeg - d) * 60
    m = int(m_float)
    s = int(round((m_float - m) * 60))
    if s == 60: m += 1; s = 0
    if m == 60: d += 1; m = 0
    return f"{d}°{m}'{direction}"


def calculate_chart(dob_str, tob_str, lat, lon, tz_str=None, manual_offset=None):
    """Tính toán bản đồ sao tổng thể - Đã nâng cấp logic múi giờ quốc tế chuẩn xác và an toàn kiểu dữ liệu."""
    try:
        dt_local = datetime.strptime(f"{dob_str} {tob_str}", "%d/%m/%Y %H:%M")
        
        # 1. TÌM MÚI GIỜ (OFFSET) CHUẨN XÁC VỚI BẪY LỖI ÉP KIỂU
        final_offset = 0.0
        is_manual_valid = False
        if manual_offset is not None and str(manual_offset).strip() != "":
            try:
                final_offset = float(manual_offset)
                is_manual_valid = True
            except:
                is_manual_valid = False

        if not is_manual_valid:
            if is_coord_in_vietnam(lat, lon):
                final_offset = get_vietnam_historical_offset(dt_local.year, dt_local.month, dt_local.day, lat, lon)
            else:
                iana_tz = tz_str
                if not iana_tz or iana_tz == "UTC":
                    iana_tz = get_timezone_str(lat, lon) or "UTC"
                try:
                    # Sử dụng ZoneInfo để tự động tính Giờ mùa hè (DST) cho quốc tế
                    tz_info = ZoneInfo(iana_tz)
                    dt_aware = dt_local.replace(tzinfo=tz_info)
                    off_delta = dt_aware.utcoffset()
                    final_offset = off_delta.total_seconds() / 3600.0 if off_delta else 0.0
                except:
                    final_offset = 0.0

        # 2. CHUYỂN SANG GIỜ UTC VÀ TÍNH JULIAN DAY
        dt_utc = dt_local - timedelta(hours=final_offset)
        jd = swe.julday(dt_utc.year, dt_utc.month, dt_utc.day, dt_utc.hour + dt_utc.minute / 60.0)
        
        swe.set_topo(lat, lon, 0)
        
        # 3. THÔNG TIN KỸ THUẬT
        gst = swe.sidtime(jd)
        lst_hours = (gst * 15 + lon) % 360 / 15.0
        h_lst = int(lst_hours)
        m_lst = int((lst_hours - h_lst) * 60)
        lst_str = f"{h_lst:02d}:{m_lst:02d}"
        
        technical_info = {
            "local_time": f"{dt_local.strftime('%d/%m/%Y %H:%M')} (GMT{final_offset:+g})",
            "ut_time": dt_utc.strftime("%d/%m/%Y %H:%M"),
            "lst": lst_str,
            "lat_lon": f"{to_dms(lat, True)}, {to_dms(lon, False)}",
            "house_sys": "Placidus system"
        }

        # 4. TÍNH NHÀ VÀ HÀNH TINH
        cusps, ascmc = swe.houses(jd, lat, lon, b'P')
        angles = {"Asc": ascmc[0], "MC": ascmc[1], "Vertex": ascmc[3]}
        
        planets = {}
        for p_name, p_id in PLANET_IDS.items():
            res = swe.calc_ut(jd, p_id, swe.FLG_SWIEPH | swe.FLG_SPEED)
            planets[p_name] = {"lon": res[0][0], "lat": res[0][1], "speed": res[0][3]}
        
        planets.update({
            "Vertex": {"lon": ascmc[3], "lat": 0, "speed": 0},
            "Asc": {"lon": ascmc[0], "lat": 0, "speed": 0},
            "MC": {"lon": ascmc[1], "lat": 0, "speed": 0}
        })
        
        return {
            "jd": jd, 
            "cusps": cusps, 
            "angles": angles, 
            "planets": planets,
            "info": technical_info,
            "meta": {"lat": lat, "lon": lon, "tz": tz_str, "offset_used": final_offset}
        }
    except Exception as e:
        print(f"Error calculating chart: {e}")
        return None


def get_natal_planet_near_cusp(chart, house_num):
    """Tìm hành tinh Natal nằm gần đỉnh nhà nhất (Chỉ xét 10 hành tinh CORE)."""
    cusps_raw = chart["cusps"]
    cusps = list(cusps_raw)[1:] if len(cusps_raw) == 13 else list(cusps_raw)
    house_idx = house_num - 1
    c_start = cusps[house_idx]
    c_end = cusps[(house_idx + 1) % 12]
    best_p = None
    min_dist = 999.0
    for p_name, info in chart["planets"].items():
        # --- FIX: Chỉ xét các hành tinh chính, bỏ qua Asc/MC/Nodes/Chiron ---
        if p_name not in CORE_PLANETS: continue
        
        if is_in_house_zone(info["lon"], c_start, c_end):
            dist = (info["lon"] - c_start) % 360
            if dist < min_dist:
                min_dist = dist
                best_p = p_name
    return best_p


def get_house_ruler_planet(chart, house_num):
    """Lấy hành tinh chủ quản của đỉnh nhà."""
    cusps_raw = chart["cusps"]
    cusps = list(cusps_raw)[1:] if len(cusps_raw) == 13 else list(cusps_raw)
    c_lon = cusps[house_num - 1]
    _, z_name, _, _ = get_zodiac(c_lon)
    return RULER_MAP.get(z_name)


def get_p_pos(jd, p_name, lat, lon):
    """Lấy tọa độ hành tinh tại Julian Day."""
    try:
        if p_name == "South Node":
            res = swe.calc_ut(jd, swe.TRUE_NODE, swe.FLG_SWIEPH)
            return (res[0][0] + 180) % 360
        elif p_name == "Vertex":
            _, ascmc = swe.houses(jd, lat, lon, b'P')
            return ascmc[3]
        elif p_name in PLANET_IDS:
            res = swe.calc_ut(jd, PLANET_IDS[p_name], swe.FLG_SWIEPH)
            return res[0][0]
        return 0.0
    except:
        return 0.0


def _get_current_orb_strict(jd, p_trans, p_nat_pos, target_angle, lat, lon):
    pos = get_p_pos(jd, p_trans, lat, lon)
    dist = abs(swe.difdeg2n(pos, p_nat_pos))
    return abs(dist - target_angle)


def _find_boundary_strict(jd_start, jd_end, p_trans, p_nat_pos, target_angle, lat, lon):
    l, r = jd_start, jd_end
    for _ in range(30):
        m = (l + r) / 2
        if _get_current_orb_strict(m, p_trans, p_nat_pos, target_angle, lat, lon) < 3.0:
            if _get_current_orb_strict(l, p_trans, p_nat_pos, target_angle, lat, lon) >= 3.0:
                r = m
            else:
                l = m
        else:
            if _get_current_orb_strict(l, p_trans, p_nat_pos, target_angle, lat, lon) < 3.0:
                r = m
            else:
                l = m
    return (l + r) / 2


def _find_hits_strict(jd_s, jd_e, p_trans, p_nat_pos, target_angle, lat, lon):
    hits = []
    t1_deg = (p_nat_pos + target_angle) % 360
    t2_deg = (p_nat_pos - target_angle) % 360
    pos_start = get_p_pos(jd_s, p_trans, lat, lon)
    active_target = t1_deg if abs(swe.difdeg2n(pos_start, t1_deg)) < abs(swe.difdeg2n(pos_start, t2_deg)) else t2_deg
    steps = 200
    step_size = (jd_e - jd_s) / steps
    for i in range(steps):
        t1 = jd_s + i * step_size
        t2 = jd_s + (i + 1) * step_size
        def get_rel(t):
            return swe.difdeg2n(get_p_pos(t, p_trans, lat, lon), active_target)
        r1, r2 = get_rel(t1), get_rel(t2)
        if r1 * r2 <= 0:
            ml, mr = t1, t2
            for _ in range(30):
                mm = (ml + mr) / 2
                if r1 * get_rel(mm) <= 0:
                    mr = mm
                else:
                    ml = mm
            hits.append((ml + mr) / 2)
    return hits


def find_exact_aspect_times(p_trans, p_natal, aspect_name, start_date_str, natal_chart):
    lat = natal_chart["meta"].get("lat", 21.0)
    lon = natal_chart["meta"].get("lon", 105.0)
    target_angle = ASPECTS_DEF[aspect_name]["angle"]
    n_lon = (natal_chart["planets"]["True Node"]["lon"] + 180) % 360 if p_natal == "South Node" else natal_chart["planets"][p_natal]["lon"]
    dt_s = datetime.strptime(start_date_str, "%d/%m/%Y")
    jd_curr = swe.julday(dt_s.year, dt_s.month, dt_s.day, 0)
    
    if p_trans in ["Moon", "Vertex"]: step, limit_days = 0.02, 365
    elif p_trans in ["Sun", "Mercury", "Venus", "Mars"]: step, limit_days = 0.1, 3650
    else: step, limit_days = 1.0, 36525
    
    limit_jd = jd_curr + limit_days
    results = []
    
    def fmt(jd_val):
        y, m, d, h_f = swe.revjul(jd_val)
        off = get_vietnam_historical_offset(y, m, d, lat, lon) if is_coord_in_vietnam(lat, lon) else 0.0
        dt = datetime(y, m, d) + timedelta(seconds=round((h_f + off) * 3600))
        return dt.strftime("%d/%m/%Y"), dt.strftime("%H:%M:%S")

    while jd_curr < limit_jd and len(results) < 5:
        if _get_current_orb_strict(jd_curr, p_trans, n_lon, target_angle, lat, lon) < 3.0:
            jd_back = jd_curr
            while _get_current_orb_strict(jd_back, p_trans, n_lon, target_angle, lat, lon) < 3.0:
                jd_back -= step
            start_jd = _find_boundary_strict(jd_back, jd_back + step, p_trans, n_lon, target_angle, lat, lon)
            
            jd_fwd = jd_curr
            while jd_fwd < limit_jd and _get_current_orb_strict(jd_fwd, p_trans, n_lon, target_angle, lat, lon) < 3.0:
                jd_fwd += step
            end_jd = _find_boundary_strict(jd_fwd - step, jd_fwd, p_trans, n_lon, target_angle, lat, lon)
            
            exact_hits = [{"d": fmt(h)[0], "t": fmt(h)[1]} for h in _find_hits_strict(start_jd, end_jd, p_trans, n_lon, target_angle, lat, lon)]
            results.append({"start": {"d": fmt(start_jd)[0], "t": fmt(start_jd)[1]}, "end": {"d": fmt(end_jd)[0], "t": fmt(end_jd)[1]}, "exact_hits": exact_hits})
            jd_curr = end_jd + (step / 2)
        else:
            jd_curr += step
    return results


def is_in_house_zone(lon, cusp_start, cusp_end):
    lon = lon % 360
    if cusp_start < cusp_end:
        return cusp_start <= lon < cusp_end
    else:
        return lon >= cusp_start or lon < cusp_end


def find_return_times(p_name, start_date_str, natal_chart):
    lat, lon = natal_chart["meta"]["lat"], natal_chart["meta"]["lon"]
    cusps_raw = natal_chart["cusps"]
    cusps = list(cusps_raw)[1:] if len(cusps_raw) == 13 else list(cusps_raw)
    n_lon = natal_chart["planets"][p_name]["lon"]
    target_house_idx = -1
    for i in range(12):
        if is_in_house_zone(n_lon, cusps[i], cusps[(i + 1) % 12]):
            target_house_idx = i
            break
    c_start, c_end = cusps[target_house_idx], cusps[(target_house_idx + 1) % 12]
    
    if p_name == "Moon": step, limit_days = 0.05, 365
    elif p_name in ["Sun", "Mercury", "Venus", "Mars"]: step, limit_days = 0.2, 3650
    elif p_name in ["Jupiter", "Saturn", "Chiron"]: step, limit_days = 1.0, 36525
    else: step, limit_days = 2.0, 146100
    
    dt_s = datetime.strptime(start_date_str, "%d/%m/%Y")
    jd_curr = swe.julday(dt_s.year, dt_s.month, dt_s.day, 0)
    limit_jd = jd_curr + limit_days
    results = []

    def fmt(jd_val):
        y, m, d, h_f = swe.revjul(jd_val)
        off = get_vietnam_historical_offset(y, m, d, lat, lon) if is_coord_in_vietnam(lat, lon) else 0.0
        dt = datetime(y, m, d) + timedelta(seconds=round((h_f + off) * 3600))
        return dt.strftime("%d/%m/%Y"), dt.strftime("%H:%M:%S")

    while jd_curr < limit_jd and len(results) < 10:
        if is_in_house_zone(get_p_pos(jd_curr, p_name, lat, lon), c_start, c_end):
            jd_back = jd_curr
            back_limit = jd_curr - limit_days
            while is_in_house_zone(get_p_pos(jd_back, p_name, lat, lon), c_start, c_end) and jd_back > back_limit:
                jd_back -= step
            bl, br = jd_back, jd_back + step
            for _ in range(25):
                bm = (bl + br) / 2
                if is_in_house_zone(get_p_pos(bm, p_name, lat, lon), c_start, c_end): br = bm
                else: bl = bm
            start_jd = br
            
            jd_fwd = jd_curr
            while jd_fwd < limit_jd and is_in_house_zone(get_p_pos(jd_fwd, p_name, lat, lon), c_start, c_end):
                jd_fwd += step
            el, er = jd_fwd - step, jd_fwd
            for _ in range(25):
                em = (el + er) / 2
                if is_in_house_zone(get_p_pos(em, p_name, lat, lon), c_start, c_end): el = em
                else: er = em
            end_jd = el
            
            exact_hits = [{"d": fmt(h)[0], "t": fmt(h)[1]} for h in _find_hits_strict(start_jd, end_jd, p_name, n_lon, 0, lat, lon)]
            results.append({"house": target_house_idx + 1, "start": {"d": fmt(start_jd)[0], "t": fmt(start_jd)[1]}, "end": {"d": fmt(end_jd)[0], "t": fmt(end_jd)[1]}, "exact_hits": exact_hits})
            jd_curr = end_jd + (step / 2)
        else:
            jd_curr += step
    return results


def find_current_house_transit_period(p_name, natal_chart, d=None, m=None, y=None):
    lat, lon = natal_chart["meta"]["lat"], natal_chart["meta"]["lon"]
    cusps_raw = natal_chart["cusps"]
    cusps = list(cusps_raw)[1:] if len(cusps_raw) == 13 else list(cusps_raw)
    now_utc = datetime.now(pytz.utc)
    t_d, t_m, t_y = (int(d) if d else now_utc.day), (int(m) if m else now_utc.month), (int(y) if y else now_utc.year)
    jd_now = swe.julday(t_y, t_m, t_d, now_utc.hour + now_utc.minute / 60.0)
    pos_now = get_p_pos(jd_now, p_name, lat, lon)
    house_idx = -1
    for i in range(12):
        if is_in_house_zone(pos_now, cusps[i], cusps[(i + 1) % 12]):
            house_idx = i
            break
    if house_idx == -1: return None
    c_start, c_end = cusps[house_idx], cusps[(house_idx + 1) % 12]
    
    if p_name == "Moon": step, scan_limit = 0.05, 365
    elif p_name in ["Sun", "Mercury", "Venus", "Mars"]: step, scan_limit = 0.2, 3650
    elif p_name in ["Jupiter", "Saturn", "Chiron"]: step, scan_limit = 1.0, 36525
    else: step, scan_limit = 2.0, 146100
    
    def fmt(jd_val):
        y_f, m_f, d_f, h_f = swe.revjul(jd_val)
        off = get_vietnam_historical_offset(y_f, m_f, d_f, lat, lon) if is_coord_in_vietnam(lat, lon) else 0.0
        dt = datetime(y_f, m_f, d_f) + timedelta(seconds=round((h_f + off) * 3600))
        return dt.strftime("%d/%m/%Y"), dt.strftime("%H:%M:%S")
    
    jd_back = jd_now
    back_limit = jd_now - scan_limit
    while is_in_house_zone(get_p_pos(jd_back, p_name, lat, lon), c_start, c_end) and jd_back > back_limit:
        jd_back -= step
    bl, br = jd_back, jd_back + step
    for _ in range(25):
        bm = (bl + br) / 2
        if is_in_house_zone(get_p_pos(bm, p_name, lat, lon), c_start, c_end): br = bm
        else: bl = bm
    start_jd = br
    
    jd_fwd = jd_now
    fwd_limit = jd_now + scan_limit
    while is_in_house_zone(get_p_pos(jd_fwd, p_name, lat, lon), c_start, c_end) and jd_fwd < fwd_limit:
        jd_fwd += step
    el, er = jd_fwd - step, jd_fwd
    for _ in range(25):
        em = (el + er) / 2
        if is_in_house_zone(get_p_pos(em, p_name, lat, lon), c_start, c_end): el = em
        else: er = em
    return {"house": house_idx + 1, "start": {"d": fmt(start_jd)[0], "t": fmt(start_jd)[1]}, "end": {"d": fmt(el)[0], "t": fmt(el)[1]}}


def format_coord_astro(val, is_lat=True):
    v_abs = abs(val)
    d = int(v_abs)
    m = int((v_abs - d) * 60)
    suffix = ('n' if val >= 0 else 's') if is_lat else ('e' if val >= 0 else 'w')
    return f"{d}{suffix}{m:02d}"


def format_coord_astro_pair(lat, lon):
    return f"{format_coord_astro(lat, True)}, {format_coord_astro(lon, False)}"


def hash_password(password):
    import hashlib
    return hashlib.sha256(password.encode()).hexdigest()


def check_password_strength(password):
    return len(password) >= 6
