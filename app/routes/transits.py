# app/routes/transits.py
from flask import Blueprint, render_template, request, redirect, url_for, session, flash
from datetime import datetime, date, timedelta
import pytz
import swisseph as swe
from config import Config
import astro00_lib as lib
from app.utils.helpers import resolve_profile_logic

transits_bp = Blueprint('transits', __name__)

def warmup_swe_engine():
    """
    Hàm mồi (Warm-up): Nạp dữ liệu vệ tinh vào RAM ngay lập tức.
    """
    try:
        swe.set_ephe_path(Config.EPHE_PATH)
        jd_now = swe.julday(2000, 1, 1, 12.0) 
        swe.calc_ut(jd_now, swe.SUN, swe.FLG_SWIEPH)
        print("--- [VANHAN] Engine Warm-up Successful! ---")
    except Exception as e:
        print(f"--- [VANHAN WARNING] Engine Warm-up Failed: {e} ---")

@transits_bp.route('/vanhan')
def vanhan_menu():
    if 'user_id' not in session: return redirect(url_for('auth.login'))
    return render_template('vanhan_menu.html', username=session.get('username'))

@transits_bp.route('/vanhan/chung', methods=['GET', 'POST'])
def transit_general():
    if 'user_id' not in session: return redirect(url_for('auth.login'))
    vn_tz = pytz.timezone('Asia/Ho_Chi_Minh')
    now_vn = datetime.now(vn_tz)
    default_loc = {"lat": 21.0283334, "lon": 105.854041, "tz": "Asia/Bangkok", "address": "Hà Nội, Vietnam"}
    chart_img, report = None, None
    if request.method == 'POST':
        try:
            lat = float(request.form.get('lat', default_loc['lat']))
            lon = float(request.form.get('lon', default_loc['lon']))
            tz_name = request.form.get('tz', default_loc['tz'])
            address = request.form.get('address', default_loc['address'])
            show_real_angle = (request.form.get('show_real_angle') == 'on')
            lib.swe.set_ephe_path(Config.EPHE_PATH)
            chart_data = lib.calculate_chart(now_vn.strftime("%d/%m/%Y"), now_vn.strftime("%H:%M"), lat, lon, tz_name)
            if chart_data:
                from app.utils.drawing.natal import create_natal_chart_image
                chart_img = create_natal_chart_image(chart_data, f"Current Sky ({now_vn.strftime('%H:%M')})", hide_houses=True, static_aries_asc=True)
                from app.utils.reports.transit import generate_current_sky_report
                report = generate_current_sky_report(chart_data, show_real_orb=show_real_angle)
            default_loc.update({"lat": lat, "lon": lon, "tz": tz_name, "address": address})
        except Exception as e:
            flash(f"Lỗi: {str(e)}", "error")
    return render_template('transit_general.html', loc=default_loc, chart_img=chart_img, report=report)

def get_outer_planet_cycle_data(lat, lon, start_date_obj, end_date_obj):
    outer_map = {"Jupiter": lib.swe.JUPITER, "Saturn": lib.swe.SATURN, "Uranus": lib.swe.URANUS, "Neptune": lib.swe.NEPTUNE, "Pluto": lib.swe.PLUTO}
    result = {}
    chart_A = lib.calculate_chart(start_date_obj.strftime("%d/%m/%Y"), "00:00", lat, lon, "UTC")
    chart_B = lib.calculate_chart(end_date_obj.strftime("%d/%m/%Y"), "00:00", lat, lon, "UTC")
    if not chart_A or not chart_B: return None
    jd_start, jd_end = chart_A["jd"], chart_B["jd"]
    total_days = int(jd_end - jd_start)
    step_days = 5
    steps = max(1, total_days // step_days)
    for p_name, p_id in outer_map.items():
        if p_name not in chart_A["planets"]: continue
        lon_A, lon_B = chart_A["planets"][p_name]["lon"], chart_B["planets"][p_name]["lon"]
        longitudes = [lon_A]
        for i in range(1, steps + 1):
            res = lib.swe.calc_ut(jd_start + (i * step_days), p_id, lib.swe.FLG_SWIEPH | lib.swe.FLG_SPEED)
            longitudes.append(res[0][0])
        longitudes.append(lon_B)
        diffs = [((l - lon_A + 180) % 360 - 180) for l in longitudes]
        min_diff, max_diff = min(diffs), max(diffs)
        result[p_name] = {'A': lon_A, 'B': lon_B, 'start': (lon_A + min_diff) % 360, 'end': (lon_A + max_diff) % 360, 'len': max_diff - min_diff}
    return result

@transits_bp.route('/vanhan/rieng', methods=['GET', 'POST'])
def transit_personal():
    if 'user_id' not in session: return redirect(url_for('auth.login'))
    vn_tz = pytz.timezone('Asia/Ho_Chi_Minh')
    now_vn = datetime.now(vn_tz)
    today_vn = now_vn.date()
    profiles = lib.load_profiles(session['user_id'])
    chart_img, house_report, aspect_report, selected_name, chart_title = None, "", "", None, ""
    aspects_list_1, aspects_list_2 = [], []
    t_date, start_date_str = today_vn, today_vn.strftime("%Y-%m-%d")
    end_date_str = (today_vn + timedelta(days=365)).strftime("%Y-%m-%d")
    transit_mode, transit_mode_input = 'single', 'existing'

    p = None
    profile_arg = request.args.get('profile')
    if request.method == 'POST' or profile_arg:
        if profile_arg:
            selected_name = profile_arg
            try: t_date = date(int(request.args.get('year')), int(request.args.get('month')), int(request.args.get('day')))
            except: t_date = today_vn
        else:
            transit_mode_input = request.form.get('mode', 'existing')
            transit_mode = request.form.get('transit_mode', 'single')
            
            p = resolve_profile_logic(session['user_id'], prefix='new' if transit_mode_input == 'new' else '', profiles_list=profiles)
            
            if p:
                selected_name = p['name']
                if transit_mode_input == 'new' and request.form.get('save_to_db'):
                    if not any(x['name'].lower() == p['name'].lower() for x in profiles):
                        lib.save_profile(p)
                        profiles = lib.load_profiles(session['user_id'])
            
            if transit_mode == 'single':
                try: t_date = date(int(request.form.get('t_year')), int(request.form.get('t_month')), int(request.form.get('t_day')))
                except: t_date = today_vn

        if p:
            try:
                lib.swe.set_ephe_path(Config.EPHE_PATH)
                natal_data = lib.calculate_chart(f"{p['dob']['day']}/{p['dob']['month']}/{p['dob']['year']}", f"{p['tob']['hour']}:{p['tob']['minute']}", p['loc']['lat'], p['loc']['lon'], p['loc']['tz'], manual_offset=p.get('tz_offset'))
                
                # --- PHẦN TRANSIT RIÊNG (SỬ DỤNG LOGIC CŨ CỦA RUNDEMO - KHÔNG DÙNG MANAGER CỦA MO) ---
                if transit_mode == 'single':
                    t_str = t_date.strftime("%d/%m/%Y")
                    transit_data = lib.calculate_chart(t_str, "00:00", p['loc']['lat'], p['loc']['lon'], "UTC", manual_offset=0)
                    if natal_data and transit_data:
                        chart_title = f"Transits: {selected_name} ({t_str})"
                        from app.utils.drawing.natal import create_natal_chart_image
                        chart_img = create_natal_chart_image(natal_data, p['name'], hide_houses=False, transit_data=transit_data, transit_mode='single')
                        def scan(t_list, out):
                            for tp in lib.TRANSIT_PLANET_ORDER:
                                tp_lon = transit_data["planets"][tp]["lon"]
                                for np_name in t_list:
                                    n_lon = (natal_data["planets"]["True Node"]["lon"] + 180) % 360 if np_name == "South Node" else natal_data["planets"][np_name]["lon"]
                                    asp = lib.check_aspect(tp_lon, n_lon)
                                    if asp and asp["aspect"] in lib.MAJOR_ASPECTS and asp["orb"] < 3.0:
                                        out.append({"t_p": tp, "t_p_sym": lib.PLANET_SYMBOLS.get(tp), "asp_sym": asp["symbol"], "asp_name": asp["aspect"], "n_p": np_name, "n_p_sym": lib.PLANET_SYMBOLS.get(np_name) if np_name != "South Node" else "☋", "orb": asp["orb"], "orb_str": f"{int(asp['orb'])}º{int((asp['orb'] % 1) * 60):02d}"})
                        scan(lib.TRANSIT_PLANET_ORDER, aspects_list_1)
                        scan(lib.NATAL_SPECIAL_POINTS, aspects_list_2)
                        from app.utils.reports.transit import generate_personal_transit_report
                        house_report, aspect_report = generate_personal_transit_report(natal_data, transit_data, p, mode='single', aspects_1=aspects_list_1, aspects_2=aspects_list_2)
                else:
                    # OUTER CYCLE MODE
                    start_date_str, end_date_str = request.form.get('start_date', start_date_str), request.form.get('end_date', end_date_str)
                    try:
                        s_date, e_date = datetime.strptime(start_date_str, "%Y-%m-%d").date(), datetime.strptime(end_date_str, "%Y-%m-%d").date()
                        cycle_data = get_outer_planet_cycle_data(p['loc']['lat'], p['loc']['lon'], s_date, e_date)
                        transit_start = lib.calculate_chart(s_date.strftime("%d/%m/%Y"), "00:00", p['loc']['lat'], p['loc']['lon'], "UTC", manual_offset=0)
                        transit_end = lib.calculate_chart(e_date.strftime("%d/%m/%Y"), "00:00", p['loc']['lat'], p['loc']['lon'], "UTC", manual_offset=0)
                        if natal_data and cycle_data and transit_start and transit_end:
                            chart_title = f"Đại Hạn: {selected_name} ({s_date.strftime('%d/%m/%Y')} - {e_date.strftime('%d/%m/%Y')})"
                            from app.utils.drawing.natal import create_natal_chart_image
                            chart_img = create_natal_chart_image(natal_data, p['name'], hide_houses=False, transit_data=cycle_data, transit_mode='outer_cycle')
                            from app.utils.reports.transit import generate_personal_transit_report
                            house_report, aspect_report = generate_personal_transit_report(natal_data, transit_start, p, mode='outer_cycle', transit_data_end=transit_end)
                    except: pass
            except Exception as e:
                print(f"Personal transit page error: {e}")

    return render_template('transit_personal.html', profiles=profiles, chart_img=chart_img, house_report=house_report, aspect_report=aspect_report, selected=selected_name, t_date=t_date, start_date_str=start_date_str, end_date_str=end_date_str, transit_mode=transit_mode, transit_mode_input=transit_mode_input, chart_title=chart_title, p=p, TRANSIT_PLANET_ORDER=lib.TRANSIT_PLANET_ORDER, RETURN_PLANET_ORDER=lib.RETURN_PLANET_ORDER, NATAL_SPECIAL_POINTS=lib.NATAL_SPECIAL_POINTS, ASPECTS_DEF=lib.ASPECTS_DEF, MAJOR_ASPECTS=lib.MAJOR_ASPECTS)

@transits_bp.route('/vanhan/chitiet', methods=['GET', 'POST'])
def transit_detailed():
    if 'user_id' not in session: return redirect(url_for('auth.login'))
    
    # 1. Warm-up Engine ngay lập tức
    warmup_swe_engine()
    
    vn_tz = pytz.timezone('Asia/Ho_Chi_Minh')
    now_vn = datetime.now(vn_tz)
    profiles = lib.load_profiles(session['user_id'])
    
    # 2. Logic ngày mặc định: 1 năm tính từ hôm nay (không ép về mùng 1)
    today = now_vn.date()
    start_date_obj = today
    end_date_obj = today + timedelta(days=365) # Mặc định 1 năm
    
    start_date_str, end_date_str = start_date_obj.strftime("%Y-%m-%d"), end_date_obj.strftime("%Y-%m-%d")
    
    chart_img, timeline_img, house_report, selected_name = None, None, "", None
    selected_houses = []
    p = None

    if request.method == 'POST':
        start_date_str = request.form.get('start_date')
        end_date_str = request.form.get('end_date')
        mode_input = request.form.get('mode', 'existing')
        
        p = resolve_profile_logic(session['user_id'], prefix='new' if mode_input == 'new' else '', profiles_list=profiles)
        
        if p:
            selected_name = p['name']
            if mode_input == 'new' and request.form.get('save_to_db'):
                if not any(x['name'].lower() == p['name'].lower() for x in profiles):
                    lib.save_profile(p)
                    profiles = lib.load_profiles(session['user_id'])
        
        if p:
            # 3. ANTI-CRASH BLOCK (Try-Except bao bọc logic tính toán nặng)
            try:
                s_date = datetime.strptime(start_date_str, "%Y-%m-%d").date()
                e_date = datetime.strptime(end_date_str, "%Y-%m-%d").date()
                
                house_list = []
                for i in range(1, 13):
                    if request.form.get(f'house_{i}'):
                        house_list.append(i)
                selected_houses = house_list
                
                lib.swe.set_ephe_path(Config.EPHE_PATH)
                
                # Tính Natal
                natal_data = lib.calculate_chart(f"{p['dob']['day']}/{p['dob']['month']}/{p['dob']['year']}", 
                                                f"{p['tob']['hour']}:{p['tob']['minute']}", 
                                                p['loc']['lat'], p['loc']['lon'], p['loc']['tz'], 
                                                manual_offset=p.get('tz_offset'))
                if natal_data:
                    # Tính Đại Hạn (Cycle Map)
                    cycle_data = get_outer_planet_cycle_data(p['loc']['lat'], p['loc']['lon'], s_date, e_date)
                    from app.utils.drawing.natal import create_natal_chart_image
                    chart_img = create_natal_chart_image(natal_data, p['name'], hide_houses=False, transit_data=cycle_data, transit_mode='outer_cycle')
                    
                    # Tính Report
                    transit_start = lib.calculate_chart(s_date.strftime("%d/%m/%Y"), "00:00", p['loc']['lat'], p['loc']['lon'], "UTC", manual_offset=0)
                    transit_end = lib.calculate_chart(e_date.strftime("%d/%m/%Y"), "00:00", p['loc']['lat'], p['loc']['lon'], "UTC", manual_offset=0)
                    from app.utils.reports.transit import generate_personal_transit_report
                    house_report, _ = generate_personal_transit_report(natal_data, transit_start, p, mode='outer_cycle', transit_data_end=transit_end)
                    
                    # Tính Timeline (Phần nặng nhất)
                    from app.utils.drawing.timeline import create_detailed_timeline_image
                    timeline_img = create_detailed_timeline_image(natal_data, s_date, e_date, house_list)
                    
            except Exception as e:
                # Bắt lỗi và thông báo cho người dùng thay vì sập server
                print(f"Detailed timeline page error: {e}")
                flash(f"Hệ thống đang quá tải hoặc gặp lỗi tính toán: {str(e)}. Vui lòng thử lại sau ít phút hoặc giảm bớt khoảng thời gian.", "error")
                
    return render_template('transit_chitiet.html', profiles=profiles, chart_img=chart_img, timeline_img=timeline_img, house_report=house_report, selected=selected_name, start_date_str=start_date_str, end_date_str=end_date_str, selected_houses=selected_houses, p=p)
