# app/routes/charts.py
from flask import Blueprint, render_template, request, redirect, url_for, session, flash
import swisseph as swe
import astro00_lib as lib
from config import Config
from app.utils.helpers import resolve_profile_logic
from app.utils.drawing import create_natal_chart_image, create_synastry_chart_image
from app.utils.reports import generate_natal_report, generate_synastry_report
from app.utils.reports.transit import generate_personal_transit_report
from datetime import datetime, date
import pytz

charts_bp = Blueprint('charts', __name__)

@charts_bp.route('/natal', methods=['GET', 'POST'])
def natal_page():
    if 'user_id' not in session: return redirect(url_for('auth.login'))
    
    profiles = lib.load_profiles(session['user_id'])
    chart_img, report, selected_name, p = None, None, None, None
    transit_report = None
    show_real_angle = (request.form.get('show_real_angle') == 'on')
    quick_action = request.form.get('quick_action')

    # Chỉ xử lý khi bấm nút (POST) hoặc có tham số profile cụ thể (GET sửa xong quay lại)
    if request.method == 'POST':
        # Dùng resolve_profile_logic để lấy p (Natal dùng prefix 'new' cho mode nhập mới)
        p = resolve_profile_logic(session['user_id'], prefix='new', profiles_list=profiles)
        
        if p:
            selected_name = p['name']
            # Lưu nếu là chế độ nhập mới và có check lưu
            mode = request.form.get('mode', 'existing')
            if mode == 'new' and request.form.get('save_to_db'):
                if not any(x['name'].lower() == p['name'].lower() for x in profiles):
                    lib.save_profile(p)
                    profiles = lib.load_profiles(session['user_id'])
                    
    elif request.method == 'GET' and request.args.get('profile'):
        selected_name = request.args.get('profile')
        p = next((x for x in profiles if x['name'] == selected_name), None)

    # KHÔNG CÓ FALLBACK: Nếu không có p (mới vào trang), biểu đồ sẽ không hiện

    if p:
        try:
            dob = f"{p['dob']['day']}/{p['dob']['month']}/{p['dob']['year']}"
            tob = f"{p['tob']['hour']}:{p['tob']['minute']}"
            swe.set_ephe_path(Config.EPHE_PATH)
            natal_data = lib.calculate_chart(dob, tob, p['loc']['lat'], p['loc']['lon'], p['loc']['tz'], manual_offset=p.get('tz_offset'))

            if natal_data:
                chart_img = create_natal_chart_image(natal_data, p['name'])
                report = generate_natal_report(natal_data, p, show_real_orb=show_real_angle)
                vn_tz = pytz.timezone('Asia/Ho_Chi_Minh')
                now_vn = datetime.now(vn_tz)

                if quick_action == 'transit_now':
                    t_date_str = now_vn.strftime("%d/%m/%Y")
                    transit_data = lib.calculate_chart(t_date_str, now_vn.strftime("%H:%M"), p['loc']['lat'], p['loc']['lon'], "UTC", manual_offset=0)
                    if transit_data:
                        chart_img = create_natal_chart_image(natal_data, p['name'], hide_houses=False, transit_data=transit_data, transit_mode='single')
                        aspects_list_1, aspects_list_2 = [], []
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
                        transit_report = generate_personal_transit_report(natal_data, transit_data, p, mode='single', aspects_1=aspects_list_1, aspects_2=aspects_list_2)

                elif quick_action == 'cycle_1y':
                    from app.routes.transits import get_outer_planet_cycle_data
                    start_date = now_vn.date()
                    try: end_date = date(start_date.year + 1, start_date.month, start_date.day)
                    except ValueError: end_date = date(start_date.year + 1, 2, 28)
                    cycle_data = get_outer_planet_cycle_data(p['loc']['lat'], p['loc']['lon'], start_date, end_date)
                    transit_start = lib.calculate_chart(start_date.strftime("%d/%m/%Y"), "00:00", p['loc']['lat'], p['loc']['lon'], "UTC", manual_offset=0)
                    transit_end = lib.calculate_chart(end_date.strftime("%d/%m/%Y"), "00:00", p['loc']['lat'], p['loc']['lon'], "UTC", manual_offset=0)
                    if cycle_data and transit_start and transit_end:
                        chart_img = create_natal_chart_image(natal_data, p['name'], hide_houses=False, transit_data=cycle_data, transit_mode='outer_cycle')
                        transit_report = generate_personal_transit_report(natal_data, transit_start, p, mode='outer_cycle', transit_data_end=transit_end)
        except Exception as e:
            print(f"Natal page error: {e}")

    return render_template('natal.html', profiles=profiles, chart_img=chart_img, report=report, transit_report=transit_report, selected=selected_name, show_real_angle=show_real_angle, TRANSIT_PLANET_ORDER=lib.TRANSIT_PLANET_ORDER, RETURN_PLANET_ORDER=lib.RETURN_PLANET_ORDER, NATAL_SPECIAL_POINTS=lib.NATAL_SPECIAL_POINTS, ASPECTS_DEF=lib.ASPECTS_DEF, MAJOR_ASPECTS=lib.MAJOR_ASPECTS)

@charts_bp.route('/synastry', methods=['GET', 'POST'])
def synastry_page():
    if 'user_id' not in session: return redirect(url_for('auth.login'))
    profiles = lib.load_profiles(session['user_id'])
    chart_img, report_html, grid_img, theme_html, selected_A, selected_B, pA, pB = None, None, None, None, None, None, None, None
    show_real_angle = (request.form.get('show_real_angle') == 'on')

    if request.method == 'POST':
        pA = resolve_profile_logic(session['user_id'], prefix='A', profiles_list=profiles)
        pB = resolve_profile_logic(session['user_id'], prefix='B', profiles_list=profiles)
        
        if pA:
            selected_A = pA['name']
            if request.form.get('mode_A') == 'new' and request.form.get('save_A'):
                if not any(x['name'].lower() == pA['name'].lower() for x in profiles):
                    lib.save_profile(pA)
                    profiles = lib.load_profiles(session['user_id'])
        if pB:
            selected_B = pB['name']
            if request.form.get('mode_B') == 'new' and request.form.get('save_B'):
                if not any(x['name'].lower() == pB['name'].lower() for x in profiles):
                    lib.save_profile(pB)
                    profiles = lib.load_profiles(session['user_id'])

    elif request.method == 'GET' and request.args.get('profileA') and request.args.get('profileB'):
        selected_A, selected_B = request.args.get('profileA'), request.args.get('profileB')
        pA = next((x for x in profiles if x['name'] == selected_A), None)
        pB = next((x for x in profiles if x['name'] == selected_B), None)

    # KHÔNG CÓ FALLBACK: Chỉ hiện khi pA và pB đều tồn tại (sau khi Submit)

    if pA and pB:
        try:
            swe.set_ephe_path(Config.EPHE_PATH)
            def calc(p_obj): return lib.calculate_chart(f"{p_obj['dob']['day']}/{p_obj['dob']['month']}/{p_obj['dob']['year']}", f"{p_obj['tob']['hour']}:{p_obj['tob']['minute']}", p_obj['loc']['lat'], p_obj['loc']['lon'], p_obj['loc']['tz'], manual_offset=p_obj.get('tz_offset'))
            cA, cB = calc(pA), calc(pB)
            if cA and cB:
                chart_img = create_synastry_chart_image(cA, cB, pA['name'], pB['name'])
                report_html, grid_img, theme_html = generate_synastry_report(cA, cB, pA, pB, show_real_orb=show_real_angle)
        except Exception as e:
            print(f"Synastry page error: {e}")

    return render_template('synastry.html', profiles=profiles, chart_img=chart_img, report_html=report_html, grid_img=grid_img, theme_html=theme_html, selected_A=selected_A, selected_B=selected_B, pA=pA, pB=pB)

@charts_bp.route('/composite', methods=['GET', 'POST'])
def composite_page():
    if 'user_id' not in session: return redirect(url_for('auth.login'))
    profiles = lib.load_profiles(session['user_id'])
    chart_img, report, selected_A, selected_B, pA, pB = None, None, None, None, None, None
    show_real_angle = (request.form.get('show_real_angle') == 'on')

    if request.method == 'POST':
        pA = resolve_profile_logic(session['user_id'], prefix='A', profiles_list=profiles)
        pB = resolve_profile_logic(session['user_id'], prefix='B', profiles_list=profiles)
        
        if pA:
            selected_A = pA['name']
            if request.form.get('mode_A') == 'new' and request.form.get('save_A'):
                if not any(x['name'].lower() == pA['name'].lower() for x in profiles):
                    lib.save_profile(pA)
                    profiles = lib.load_profiles(session['user_id'])
        if pB:
            selected_B = pB['name']
            if request.form.get('mode_B') == 'new' and request.form.get('save_B'):
                if not any(x['name'].lower() == pB['name'].lower() for x in profiles):
                    lib.save_profile(pB)
                    profiles = lib.load_profiles(session['user_id'])

    # KHÔNG CÓ FALLBACK: Chỉ hiện sau khi Submit

    if pA and pB:
        try:
            swe.set_ephe_path(Config.EPHE_PATH)
            def calc(p_obj): return lib.calculate_chart(f"{p_obj['dob']['day']}/{p_obj['dob']['month']}/{p_obj['dob']['year']}", f"{p_obj['tob']['hour']}:{p_obj['tob']['minute']}", p_obj['loc']['lat'], p_obj['loc']['lon'], p_obj['loc']['tz'], manual_offset=p_obj.get('tz_offset'))
            cA, cB = calc(pA), calc(pB)
            if cA and cB:
                comp_data = lib.calculate_composite_chart(cA, cB)
                comp_name = f"Composite: {pA['name']} & {pB['name']}"
                chart_img = create_natal_chart_image(comp_data, comp_name)
                report = generate_natal_report(comp_data, {"name": comp_name, "loc": {"address": "Midpoint Method"}, "info": {"local_time": "Composite Chart"}}, show_real_orb=show_real_angle)
        except Exception as e:
            print(f"Composite page error: {e}")

    return render_template('composite.html', profiles=profiles, chart_img=chart_img, report=report, selected_A=selected_A, selected_B=selected_B, pA=pA, pB=pB)

@charts_bp.route('/planet-connect')
def planet_connect_page(): return render_template('planet_connect.html')
