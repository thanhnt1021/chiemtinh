# app/routes/main.py
from flask import Blueprint, render_template, request, redirect, url_for, session, flash
import astro00_lib as lib
from config import Config
from app.utils.helpers import parse_profile_from_form
from urllib.parse import unquote

main_bp = Blueprint('main', __name__)

@main_bp.route('/dashboard')
def dashboard():
    if 'user_id' not in session: return redirect(url_for('auth.login'))
    return render_template('dashboard.html', username=session['username'])

@main_bp.route('/user')
def user_page():
    if 'user_id' not in session: return redirect(url_for('auth.login'))
    users = lib.load_users()
    current = users.get(session['username'])
    if session['username'] == Config.ADMIN_USER: current = {'username': Config.ADMIN_USER}
    if not current: return redirect(url_for('auth.logout'))
    my_profiles = lib.load_profiles(session['user_id'])
    return render_template('user.html', username=session['username'], profiles=my_profiles)

@main_bp.route('/user/change_password', methods=['POST'])
def change_password_route():
    if 'user_id' not in session: return redirect(url_for('auth.login'))
    old_pass = request.form.get('old_pass')
    new_pass = request.form.get('new_pass')
    confirm_pass = request.form.get('confirm_pass')
    if new_pass != confirm_pass:
        flash('Mật khẩu mới không khớp!', 'error')
        return redirect(url_for('main.user_page'))
    success, msg = lib.change_password(session['username'], old_pass, new_pass)
    flash(msg, 'success' if success else 'error')
    return redirect(url_for('main.user_page'))

@main_bp.route('/edit_profile/<name>')
def edit_profile(name):
    if 'user_id' not in session: return redirect(url_for('auth.login'))
    profiles = lib.load_profiles(session['user_id'])
    profile = next((p for p in profiles if p['name'] == name), None)
    if not profile:
        flash('Không tìm thấy hồ sơ!', 'error')
        return redirect(url_for('main.user_page'))
    return render_template('input.html', profiles=profiles, edit_profile=profile)

@main_bp.route('/delete_profile/<path:name>')
def delete_profile(name):
    if 'user_id' not in session: return redirect(url_for('auth.login'))
    decoded_name = unquote(name)
    lib.delete_profile(session['user_id'], decoded_name)
    flash(f'Đã xóa hồ sơ: {decoded_name}', 'success')
    return redirect(url_for('main.user_page'))

@main_bp.route('/input', methods=['GET', 'POST'])
def input_page():
    if 'user_id' not in session: return redirect(url_for('auth.login'))
    profiles = lib.load_profiles(session['user_id'])
    if request.method == 'POST':
        try:
            name = request.form.get('name')
            original_name = request.form.get('original_name')
            return_to = request.form.get('return_to')
            p_data = parse_profile_from_form()
            if not p_data: raise Exception("Dữ liệu không hợp lệ")

            if original_name and original_name.strip():
                if name.lower() != original_name.lower() and any(x['name'].lower() == name.lower() for x in profiles):
                    flash(f"Tên hồ sơ '{name}' đã tồn tại. Vui lòng chọn tên khác.", "error")
                    return render_template('input.html', profiles=profiles, edit_profile=p_data)
                lib.update_profile(session['user_id'], original_name, p_data)
                flash(f'Đã cập nhật hồ sơ {name}!', 'success')
            else:
                if any(x['name'].lower() == name.lower() for x in profiles):
                    flash(f"Tên hồ sơ '{name}' đã tồn tại.", "error")
                    return render_template('input.html', profiles=profiles)
                lib.save_profile(p_data)
                flash('Đã lưu thành công!', 'success')

            if return_to == 'natal':
                return redirect(url_for('charts.natal_page', profile=name))
            elif return_to == 'synastry':
                other = request.form.get('other_profile')
                role = request.form.get('role')
                if role == 'A': return redirect(url_for('charts.synastry_page', profileA=name, profileB=other))
                return redirect(url_for('charts.synastry_page', profileA=other, profileB=name))
            elif return_to == 'composite':
                other = request.form.get('other_profile')
                role = request.form.get('role')
                if role == 'A': return redirect(url_for('charts.composite_page', profileA=name, profileB=other))
                return redirect(url_for('charts.composite_page', profileA=other, profileB=name))
            elif return_to == 'vanhan_rieng':
                d, m, y = request.form.get('r_day'), request.form.get('r_month'), request.form.get('r_year')
                return redirect(url_for('transits.transit_personal', profile=name, day=d, month=m, year=y))

            return redirect(url_for('main.user_page'))
        except Exception as e:
            flash(f'Lỗi: {str(e)}', 'error')
    return render_template('input.html', profiles=profiles)

@main_bp.route('/profile')
def profile_page(): return redirect(url_for('main.user_page'))

@main_bp.route('/nuoitool')
def nuoi_tool():
    return render_template('nuoitool.html')
