from flask import Blueprint, render_template, request, redirect, url_for, session, flash
import uuid
import re
import astro00_lib as lib
from config import Config

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/')
def index():
    if 'user_id' in session: return redirect(url_for('main.dashboard'))
    return redirect(url_for('auth.login'))

@auth_bp.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        if username == Config.ADMIN_USER:
            if lib.hash_password(password) == Config.ADMIN_PASS_HASH:
                session['user_id'] = 'admin_id_9999'
                session['username'] = Config.ADMIN_USER
                session.permanent = False
                return redirect(url_for('main.dashboard'))
            else:
                flash('Sai mật khẩu Admin!', 'error')
                return render_template('login.html')
        users = lib.load_users()
        if username in users:
            hashed_pw = lib.hash_password(password)
            if users[username]['password'] == hashed_pw:
                session['user_id'] = users[username]['user_id']
                session['username'] = username
                session.permanent = bool(request.form.get('remember'))
                return redirect(url_for('main.dashboard'))
        flash('Sai tên đăng nhập hoặc mật khẩu!', 'error')
    return render_template('login.html')

@auth_bp.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        confirm = request.form.get('confirm_password')
        if username == Config.ADMIN_USER:
            flash('Tên đăng nhập này không khả dụng.', 'error')
            return redirect(url_for('auth.register'))
        if not username or not password or not confirm:
            flash('Vui lòng nhập đầy đủ thông tin!', 'error')
            return redirect(url_for('auth.register'))
        if not re.match(r'^[a-z0-9_]+$', username):
            flash('Tên đăng nhập chỉ được chứa chữ thường, số và dấu gạch dưới!', 'error')
            return redirect(url_for('auth.register'))
        if password != confirm:
            flash('Mật khẩu xác nhận không khớp!', 'error')
            return redirect(url_for('auth.register'))
        users = lib.load_users()
        if username in users:
            flash('Tên đăng nhập đã tồn tại!', 'error')
            return redirect(url_for('auth.register'))
        new_user = {"username": username, "password": lib.hash_password(password), "user_id": str(uuid.uuid4())}
        lib.save_users({username: new_user})
        flash('Đăng ký thành công! Vui lòng đăng nhập.', 'success')
        return redirect(url_for('auth.login'))
    return render_template('register.html')

@auth_bp.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('auth.login'))

@auth_bp.route('/forgot-password', methods=['GET', 'POST'])
def forgot_password():
    if request.method == 'POST':
        username = request.form.get('username')
        new_pass = request.form.get('new_password')
        confirm = request.form.get('confirm_password')

        if not username or not new_pass or not confirm:
            flash('Vui lòng điền đầy đủ thông tin!', 'error')
            return redirect(url_for('auth.forgot_password'))

        if new_pass != confirm:
            flash('Mật khẩu xác nhận không khớp!', 'error')
            return redirect(url_for('auth.forgot_password'))

        # Gọi hàm trong thư viện để reset
        if lib.reset_user_password(username, new_pass):
            flash('Đổi mật khẩu thành công! Mời đăng nhập lại.', 'success')
            return redirect(url_for('auth.login'))
        else:
            flash('Tên đăng nhập không tồn tại!', 'error')
            return redirect(url_for('auth.forgot_password'))

    return render_template('forgot_password.html')
