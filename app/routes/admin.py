from flask import Blueprint, render_template, redirect, url_for, session, flash
import astro00_lib as lib
from config import Config

admin_bp = Blueprint('admin', __name__)

@admin_bp.route('/admin')
def admin_page():
    if 'user_id' not in session or session.get('username') != Config.ADMIN_USER:
        flash('Bạn không có quyền truy cập trang này!', 'error')
        return redirect(url_for('main.dashboard'))
    users = lib.get_all_users_admin()
    profiles = lib.get_all_profiles_admin()
    return render_template('admin.html', users=users, profiles=profiles)

@admin_bp.route('/admin/delete_user/<int:user_id>')
def admin_delete_user(user_id):
    if 'user_id' not in session or session.get('username') != Config.ADMIN_USER: return "Unauthorized", 403
    if lib.delete_user_admin(user_id): flash('Đã xóa user thành công.', 'success')
    else: flash('Lỗi khi xóa user.', 'error')
    return redirect(url_for('admin.admin_page'))
