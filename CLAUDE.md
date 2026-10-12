@AGENTS.md

# chiemtinh.jst4.fun — Web ứng dụng chiêm tinh (Flask)

> File này được Claude Code đọc tự động đầu mỗi phiên làm việc.
> Cập nhật khi có quyết định lớn thay đổi.

> **LUẬT VẬN HÀNH:** nạp từ `@AGENTS.md` (sinh từ univ3 `docs/univ3/`, canonical).
> Cập nhật luật: `~/.claude/universal-hooks/sync-uni.sh check` → (gộp tay) → `push` → `pull`.
> CẤM `pull` khi `check` chưa báo SẠCH.

## Bối cảnh

Web app chiêm tinh (natal chart, synastry, composite, transit) chạy trên domain
`chiemtinh.jst4.fun`. Mục tiêu sản phẩm CHƯA ĐƯỢC CHỐT — xem `docs/GOAL.md`.

## Stack (đọc từ code thật, không phỏng đoán)

- **Backend:** Flask + Gunicorn (`wsgi.py`, `gunicorn_config.py`) — worker `gthread`, port lấy từ `project_conf.py:APP_PORT` (65501).
- **Tính toán chiêm tinh:** `pyswisseph` (Swiss Ephemeris), dữ liệu ephemeris trong `ephe/`.
- **Thư viện lõi:** `astro00_lib/` — `core.py`, `const.py`, `synastry_logic.py`, `composite_logic.py`, `db_models.py`.
- **DB:** SQLAlchemy + `psycopg2-binary` (PostgreSQL); khởi tạo qua `lib.init_db()` trong `app/__init__.py`.
- **Dịch vụ ngoài:** Google Sheets (`gspread`) + Google Drive (cache ảnh) qua service account.
- **Phụ trợ:** `geopy`, `timezonefinder`, `pytz`, `numpy`, `matplotlib`.

## Cấu trúc

| Đường dẫn | Vai trò |
|---|---|
| `wsgi.py` | Điểm vào WSGI, gọi `create_app()` |
| `app/__init__.py` | Factory: set ephe path, `init_db()`, đăng ký blueprint, cache ảnh Drive |
| `app/routes/` | `auth.py` `main.py` `charts.py` `admin.py` `api.py` `transits.py` |
| `app/utils/` | `google_services.py`, `helpers.py`, `drawing/`, `reports/` |
| `app/templates/`, `app/static/` | Giao diện |
| `astro00_lib/` | Lõi tính toán chiêm tinh |
| `config.py` | `Config` — đường dẫn, session, tài khoản admin, khoá Google Sheets/Drive |
| `project_conf.py` | Cấu hình triển khai: port, domain, tên file nginx/systemd |
| `server_conf/` | `chiemtinh.conf` (nginx), `chiemtinh.service` (systemd) |
| `deploy.sh`, `update.sh`, `export.sh`, `getversion.sh` | Script triển khai/cập nhật trên VPS |
| `docs/univ3/` | Cache bộ luật univ3 (SSOT: `thanhnt1021/univ3`) — KHÔNG sửa tay ở đây |

## Deploy

- systemd service `chiemtinh.service` + nginx `chiemtinh.conf`, domain `chiemtinh.jst4.fun`, Certbot bật (`project_conf.py`).
- Quy trình do `deploy.sh` / `update.sh` lo. **CHƯA verify trên máy này** — cần founder xác nhận trước khi chạy thật.
- Bot nhận việc oHa (@nguyclaudebot, Worker `oha-bot`): mở phiên tự kéo việc sếp; gửi sếp chỉ qua CLI `gui` (`python3 scripts/sep-viec/sep_viec.py`).

## Cảnh báo đang mở (chưa xử lý — chờ founder chốt)

1. **Chưa phải git repo.** `git status` → `fatal: not a git repository`. Chưa `git init` vì cần founder quyết tên repo / remote.
2. **Secret nằm trong thư mục làm việc:** `secret.key` (Flask secret), `mine01.json` (Google service-account private key). Đã có `.gitignore` chặn, nhưng **phải kiểm lại trước lần commit đầu tiên**.
3. **Mật khẩu admin hardcode trong `config.py`** (`ADMIN_USER` / `ADMIN_PASS_HASH` sinh từ chuỗi thuần trong code). Nên chuyển sang biến môi trường.
