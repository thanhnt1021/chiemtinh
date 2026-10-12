from flask import Flask
from config import Config
import swisseph as swe
import astro00_lib as lib
from app.utils.google_services import cache_drive_images

def create_app():
    app = Flask(__name__)
    
    # 1. Cấu hình App
    app.secret_key = Config.get_secret_key()
    app.permanent_session_lifetime = Config.PERMANENT_SESSION_LIFETIME
    
    # 2. Cấu hình SwissEph
    try:
        swe.set_ephe_path(Config.EPHE_PATH)
        print(f"--- [INIT] Đã set đường dẫn Ephe: {Config.EPHE_PATH} ---")
    except Exception as e:
        print(f"--- [INIT] Lỗi set đường dẫn Ephe: {e} ---")

    # 3. Khởi tạo DB
    lib.init_db()

    # 4. Đăng ký Blueprints (Routes)
    from app.routes.auth import auth_bp
    from app.routes.main import main_bp
    from app.routes.charts import charts_bp
    from app.routes.admin import admin_bp
    from app.routes.api import api_bp
    from app.routes.transits import transits_bp  # <--- IMPORT MỚI

    app.register_blueprint(auth_bp)
    app.register_blueprint(main_bp)
    app.register_blueprint(charts_bp)
    app.register_blueprint(admin_bp)
    app.register_blueprint(api_bp)
    app.register_blueprint(transits_bp) # <--- ĐĂNG KÝ MỚI

    # 5. Cache ảnh Google Drive (Chạy ngầm hoặc khi start)
    try:
        cache_drive_images()
    except Exception as e:
        print(f"--- [INIT] Lỗi cache ảnh Drive: {e} ---")

    return app
