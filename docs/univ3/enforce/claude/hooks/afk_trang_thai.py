#!/usr/bin/env python3
"""afk_trang_thai.py — MỘT nguồn trạng thái «founder đang AFK» cho mọi hook.

Ghi: `afk_mode.py` (UserPromptSubmit) — bật khi founder báo rời máy, tắt khi founder báo đã về.
Đọc: `afk_hoi_inbox_gate.py` (PreToolUse:AskUserQuestion) — đang AFK thì chặn hỏi trong CLI.

WHY cờ nằm ở thư mục người dùng chứ không theo phiên: founder rời máy là rời MỌI phiên, mọi dự án;
phiên mới mở lúc founder vắng cũng không được hỏi trong CLI (anh Thành 11/10/2026: «đã bảo /afk thì
câu hỏi gửi theo list vào inbox mà»).
WHY tự hết sau 8 tiếng: founder hay quên gõ «tao về rồi»; cờ sống mãi thì hôm sau ngồi máy vẫn bị cấm
hỏi — cổng chặn phải có lối ra.
"""
import json
import os
import time

THU_MUC = os.path.expanduser("~/.claude/afk")
TEP = os.path.join(THU_MUC, "trang-thai.json")
HAN_GIAY = 8 * 3600


def bat(trich: str = "") -> None:
    os.makedirs(THU_MUC, exist_ok=True)
    bay_gio = int(time.time())
    with open(TEP, "w", encoding="utf-8") as f:
        json.dump(
            {"bat_luc": bay_gio, "het_han": bay_gio + HAN_GIAY, "trich": trich[:200]},
            f,
            ensure_ascii=False,
        )


def tat() -> None:
    try:
        os.remove(TEP)
    except FileNotFoundError:
        pass


def dang_afk():
    """dict trạng thái nếu đang AFK và chưa hết hạn, ngược lại None."""
    try:
        with open(TEP, encoding="utf-8") as f:
            tt = json.load(f)
    except Exception:
        return None
    if int(tt.get("het_han", 0)) <= int(time.time()):
        tat()
        return None
    return tt


# ══════ Vé d991d9a878 (W301 15/10/2026, thẻ Task-12102026-21) — ANH LÀM QUA TELEGRAM = VẮNG KHỎI CLI ══════
# Lệnh anh Thành 12/10: cấm bật hộp hỏi trong CLI khi anh đang làm qua Telegram. Đo 14/10 (W279): hai
# cổng hộp hỏi chỉ chặn khi có cờ /afk hoặc `.claude/anh-vang`; ca 19:37 gõ CLI → 19:41 Reply Telegram,
# cả hai cổng cho hộp hỏi qua. Nay coi anh VẮNG khi lời MỚI NHẤT của anh đến từ Telegram và mới hơn
# lượt anh gõ CLI cuối (mọi dự án, sổ lệnh `~/.claude/so-lenh/*/<ngày>/.so.json`).
# Mốc Telegram: dự án có bảng thẻ Việc giao Dev (ChicHub) → `task_dev.task_dev_event` trên DB SỐNG
# `chichub_bigdb`, lời của anh (`source='dev'`) mang `meta.tg_chat` (Reply / tin / /viec từ Telegram).
# Dự án khác không có nguồn → không đổi gì. Hỏng / chậm (> 3 giây) → coi như không có mốc (fail-open).
# Nhớ đệm 60 giây ở `~/.claude/afk/moc-telegram.json` để hai cổng cùng lượt không hỏi DB hai lần.
# Lùi: `UNIV3_VANG_TELEGRAM_TAT=1`.
import glob as _glob
import re as _re
import subprocess as _sp

GOC_SO_LENH = os.path.abspath(os.environ.get("UNIV3_SO_LENH_ROOT") or os.path.expanduser("~/.claude/so-lenh"))
TEP_NHO_TG = os.path.join(THU_MUC, "moc-telegram.json")
NHO_TG_GIAY = 60
SQL_TG = ("select coalesce(extract(epoch from max(at)), 0) from task_dev.task_dev_event "
          "where source = 'dev' and meta::jsonb ? 'tg_chat' and at > now() - interval '3 days'")


def luot_go_cli_cuoi():
    """Mốc epoch lượt anh gõ CLI mới nhất (mọi dự án, 2 ngày sổ gần nhất mỗi dự án); không có → None."""
    tot = None
    for du_an in _glob.glob(os.path.join(GOC_SO_LENH, "*")):
        for d in sorted(_glob.glob(os.path.join(du_an, "????-??-??")))[-2:]:
            try:
                with open(os.path.join(d, ".so.json"), encoding="utf-8") as f:
                    muc = (json.load(f) or {}).get("muc", {}) or {}
            except Exception:
                continue
            for m in muc.values():
                try:
                    luc = float(m.get("luc"))
                except Exception:
                    continue
                if tot is None or luc > tot:
                    tot = luc
    return tot


def _goc_task_dev(cwd):
    p = os.path.abspath(cwd or os.getcwd())
    while True:
        if os.path.isdir(os.path.join(p, "src", "lib", "task-dev")) and os.path.isfile(os.path.join(p, ".env")):
            return p
        cha = os.path.dirname(p)
        if cha == p:
            return ""
        p = cha


def _url_db_song(goc):
    """DATABASE_URL của dự án, ÉP tên DB sống `chichub_bigdb` (`.env` trần trỏ DB dev), bỏ ?schema=…"""
    try:
        with open(os.path.join(goc, ".env"), encoding="utf-8") as f:
            for dong in f:
                m = _re.match(r'\s*DATABASE_URL\s*=\s*"?([^"\n]+)"?', dong)
                if m:
                    url = m.group(1).split("?", 1)[0]
                    return _re.sub(r"/[A-Za-z0-9_]+$", "/chichub_bigdb", url)
    except Exception:
        pass
    return ""


def moc_telegram_cuoi(cwd=""):
    """Mốc epoch lời mới nhất của anh đến từ Telegram (dự án có bảng thẻ); không có / hỏng → None."""
    gia = os.environ.get("UNIV3_MOC_TELEGRAM_ANH")      # ca thử
    if gia is not None:
        try:
            return float(gia) or None
        except Exception:
            return None
    goc = _goc_task_dev(cwd)
    if not goc:
        return None
    try:
        with open(TEP_NHO_TG, encoding="utf-8") as f:
            nho = json.load(f)
        if nho.get("goc") == goc and time.time() - float(nho.get("luc", 0)) < NHO_TG_GIAY:
            return float(nho.get("moc") or 0) or None
    except Exception:
        pass
    url = _url_db_song(goc)
    if not url:
        return None
    try:
        r = _sp.run(["psql", url, "-At", "-c", SQL_TG], capture_output=True, text=True, timeout=3.0,
                    env=dict(os.environ, PGCONNECT_TIMEOUT="2"))
        moc = float((r.stdout or "").strip() or 0) if r.returncode == 0 else None
    except Exception:
        moc = None
    if moc is None:
        return None
    try:
        os.makedirs(THU_MUC, exist_ok=True)
        with open(TEP_NHO_TG, "w", encoding="utf-8") as f:
            json.dump({"goc": goc, "luc": time.time(), "moc": moc}, f)
    except Exception:
        pass
    return moc or None


def vang_qua_telegram(cwd="", cli=None, tg=None):
    """dict {tg, cli} nếu lời mới nhất của anh đến từ Telegram, mới hơn lượt gõ CLI cuối; ngược lại None."""
    if os.environ.get("UNIV3_VANG_TELEGRAM_TAT") == "1":
        return None
    tg = moc_telegram_cuoi(cwd) if tg is None else tg
    if not tg:
        return None
    cli = luot_go_cli_cuoi() if cli is None else cli
    if cli is not None and cli >= tg:
        return None
    return {"tg": tg, "cli": cli}


def anh_vang(cwd=""):
    """Một câu hỏi cho mọi cổng: anh có VẮNG khỏi CLI không (cờ /afk HOẶC đang làm qua Telegram)."""
    return bool(dang_afk()) or bool(vang_qua_telegram(cwd))


def cach_hoi_anh(cwd="", nhanh=False):
    """Cụm chữ «hỏi bằng gì» cho lời nhắc của cổng: anh ở máy → hộp hỏi; anh vắng → tin riêng.

    `nhanh=True` (gọi từ UserPromptSubmit): anh VỪA gõ CLI nên chắc chắn mới hơn lời Telegram —
    chỉ xét cờ /afk, không hỏi DB (mỗi lần hỏi DB qua đường hầm ~2 giây, không được cộng vào mọi lượt gõ)."""
    if (bool(dang_afk()) if nhanh else anh_vang(cwd)):
        if _goc_task_dev(cwd):
            return ("tin riêng anh qua `node scripts/task-dev.mjs tin --rieng --loai hoi` "
                    "(anh đang VẮNG khỏi CLI — cấm AskUserQuestion)")
        return ("inbox founder của dự án (không có thì ghi `~/.claude/afk/cau-hoi-<dự án>.md`) — "
                "founder đang VẮNG, cấm AskUserQuestion")
    return "`AskUserQuestion`"


def _ca_thu():
    """python3 afk_trang_thai.py --ca-thu — ca gốc vé d991d9a878: gõ CLI 19:37, Reply Telegram 19:41."""
    import calendar
    import tempfile
    vn = lambda hm: calendar.timegm(time.strptime("2026-10-14 " + hm, "%Y-%m-%d %H:%M")) - 7 * 3600
    tong, sai = 0, 0

    def ca(ten, dung):
        nonlocal tong, sai
        tong += 1
        sai += 0 if dung else 1
        print("%s %s" % ("PASS" if dung else "FAIL", ten))

    ca("1. CLI 19:37, Telegram 19:41 → VẮNG", vang_qua_telegram("/x", cli=vn("19:37"), tg=vn("19:41")) is not None)
    ca("2. Telegram 19:41, CLI 19:45 → có mặt", vang_qua_telegram("/x", cli=vn("19:45"), tg=vn("19:41")) is None)
    ca("3. chưa từng gõ CLI, có lời Telegram → VẮNG", vang_qua_telegram("/x", cli=0.0, tg=vn("19:41")) is not None)
    ca("4. dự án không có nguồn Telegram → có mặt (không đổi gì)", moc_telegram_cuoi(tempfile.gettempdir()) is None
       if os.environ.get("UNIV3_MOC_TELEGRAM_ANH") is None else True)
    os.environ["UNIV3_VANG_TELEGRAM_TAT"] = "1"
    ca("5. công tắc lùi UNIV3_VANG_TELEGRAM_TAT=1 → tắt", vang_qua_telegram("/x", cli=vn("19:37"), tg=vn("19:41")) is None)
    os.environ.pop("UNIV3_VANG_TELEGRAM_TAT")
    with tempfile.TemporaryDirectory() as d:
        os.makedirs(os.path.join(d, "A", "2026-10-14"))
        with open(os.path.join(d, "A", "2026-10-14", ".so.json"), "w", encoding="utf-8") as f:
            json.dump({"muc": {"L01": {"luc": str(vn("19:37"))}, "L02": {"luc": "hỏng"}}}, f)
        global GOC_SO_LENH
        cu, GOC_SO_LENH = GOC_SO_LENH, d
        try:
            ca("6. sổ lệnh: lấy lượt gõ mới nhất, bỏ dòng hỏng", luot_go_cli_cuoi() == vn("19:37"))
        finally:
            GOC_SO_LENH = cu
    print("\n%d/%d ca đúng" % (tong - sai, tong))
    return 1 if sai else 0


if __name__ == "__main__":
    import sys as _sys
    if "--ca-thu" in _sys.argv:
        _sys.exit(_ca_thu())
