#!/usr/bin/env python3
"""CLI máy nhà của bot nhận việc oHa (skill bot-nhan-viec, hợp đồng references/hop-dong.md).

Máy chủ: Cloudflare Worker `oha-bot` (workers/oha-bot). Khoá đọc từ .env dự án; biến môi trường đè .env.
Mọi tin gửi sếp CHỈ qua lệnh `gui` (máy chủ cấp/giữ mã + ghi tin bot vào kho để Reply vào đúng thẻ).
"""
import argparse
import base64
import html
import io
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

GOC = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Ca thử đặt SEP_VIEC_TRANG ra thư mục riêng: pid / da-thay của kho thử không được giẫm lên con canh thật đang chạy.
TRANG = os.environ.get("SEP_VIEC_TRANG") or os.path.join(GOC, ".claude", "sep-viec")
VN = timezone(timedelta(hours=7))
TRANG_THAI = ["cho-xac-nhan", "cho-sep-tra-loi", "sep-da-tra-loi", "dang-lam", "xong", "huy", "da-chuyen"]
TT_DONG = ("xong", "huy", "da-chuyen")
# Founder chốt 12/10/2026: mã việc dự án là oHa-ddmmyyyy-NN. Mã cũ Task-… gõ vào vẫn nhận, CLI quy đổi.
# Đa dự án (W47 21/10/2026, Task-21102026-08 ChicHub): cùng một bot, dự án khác đặt SEP_VIEC_DU_AN=TUNG trong .env
# → mã TUNG-ddmmyyyy-NN, mọi lệnh gửi kèm header X-Du-An để máy chủ đọc đúng sổ của dự án đó.
TIEN_TO_GOC = "oHa"
TIEN_TO = TIEN_TO_GOC  # đặt lại sau khi đọc .env (dưới)


def doi_ma(s):
    if not s:
        return s
    s = s.strip()
    if TIEN_TO != TIEN_TO_GOC:
        return re.sub(r"^" + re.escape(TIEN_TO) + "-", TIEN_TO + "-", s, flags=re.I)
    return re.sub(r"^(?:task|oha)-", TIEN_TO + "-", s, flags=re.I)


def doc_env():
    e = {}
    p = os.path.join(GOC, ".env")
    if os.path.exists(p):
        for d in open(p, encoding="utf-8"):
            d = d.strip()
            if d and not d.startswith("#") and "=" in d:
                k, v = d.split("=", 1)
                e[k.strip()] = v.strip().strip('"').strip("'")
    for k in list(e) + ["SEP_VIEC_URL", "SEP_VIEC_DU_AN"]:
        if os.environ.get(k):
            e[k] = os.environ[k]
    return e


ENV = doc_env()
TIEN_TO = (ENV.get("SEP_VIEC_DU_AN") or TIEN_TO_GOC).strip()
if not re.fullmatch(r"[A-Za-z]{2,10}", TIEN_TO):
    sys.exit(f"SEP_VIEC_DU_AN lạ: {TIEN_TO!r} — chỉ chữ cái, 2–10 ký tự")
# Ca thử trỏ TG_API_BASE về máy Telegram giả → không gọi Telegram thật.
TG_GOC = (os.environ.get("TG_API_BASE") or ENV.get("TG_API_BASE") or "https://api.telegram.org").rstrip("/")


def can(k):
    v = ENV.get(k)
    if not v:
        sys.exit(f"Thiếu {k} trong .env")
    return v


def goi(act, body=None, canh=False):
    url = can("SEP_VIEC_URL").rstrip("/") + "/api?act=" + act
    h = {"X-Sep-Viec-Token": can("SEP_VIEC_TOKEN"), "X-Nhip-Tim": "1", "User-Agent": "sep-viec-cli/1",
         "Content-Type": "application/json"}
    if canh:
        h["X-Canh"] = "1"
    if TIEN_TO != TIEN_TO_GOC:
        h["X-Du-An"] = TIEN_TO
    data = json.dumps(body, ensure_ascii=False).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, headers=h, method="POST" if data is not None else "GET")
    try:
        # Tệp đính kèm (PDF vài MB) đi qua máy chủ rồi mới tới Telegram — 40 giây không đủ.
        with urllib.request.urlopen(req, timeout=180 if body and body.get("tep") else 40) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        try:
            j = json.loads(e.read().decode())
        except Exception:
            j = {"ok": False, "loi": f"HTTP {e.code}"}
        j["_ma_http"] = e.code
        return j


def tg(method, **body):
    req = urllib.request.Request(f"{TG_GOC}/bot{can('TG_BOT_TOKEN')}/{method}",
                                 data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=40) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return json.loads(e.read().decode())


def gio(ts):
    return datetime.fromtimestamp(int(ts or 0), VN).strftime("%d/%m %H:%M")


def doc_json(ten, mac_dinh):
    try:
        return json.load(open(os.path.join(TRANG, ten), encoding="utf-8"))
    except Exception:
        return mac_dinh


def ghi_json(ten, d):
    os.makedirs(TRANG, exist_ok=True)
    tmp = os.path.join(TRANG, ten + ".tmp")
    json.dump(d, open(tmp, "w", encoding="utf-8"), ensure_ascii=False)
    os.replace(tmp, os.path.join(TRANG, ten))


def tai_tep(file_id, thu_muc, ten_goc):
    """getFile, thử lại 3 lượt, ghi .tmp rồi đổi tên. Trả đường dẫn hoặc None."""
    os.makedirs(thu_muc, exist_ok=True)
    for lan in range(3):
        f = tg("getFile", file_id=file_id)
        if f.get("error_code") == 400:      # file_id hỏng: thử lại vô ích
            return None
        duong = (f.get("result") or {}).get("file_path")
        if duong:
            dich = os.path.join(thu_muc, ten_goc + os.path.splitext(duong)[1])
            if os.path.exists(dich):
                return dich
            try:
                with urllib.request.urlopen(f"{TG_GOC}/file/bot{can('TG_BOT_TOKEN')}/{duong}", timeout=60) as r:
                    open(dich + ".tmp", "wb").write(r.read())
                os.replace(dich + ".tmp", dich)
                return dich
            except Exception:
                pass
        time.sleep(1 + lan)
    return None


def in_loi_cli(ds, bao_da_nhan=True):
    if not ds:
        return
    print("📨 LỜI CHỦ GỬI THẲNG VÀO CLI — coi như chủ gõ trong cửa sổ này:")
    for c in ds:
        # 7f: lenh_may = /tatmay /momay (làm đúng tệp lệnh ghi trong lời) · tong-hop = sổ dồn /lamdi
        nhan = {"lenh_may": "⚙ LỆNH MÁY", "tong-hop": "🗂 SỔ DỒN"}.get(c.get("loai"), "clitell")
        print(f"  [{nhan} #{c['id']} · {gio(c['luc'])}] {c['chu']}")
        if c.get("noi_tiep"):
            print(f"      (Reply vào: «{c['noi_tiep'][:300]}»)")
    print("  → trả lời chủ: python3 scripts/sep-viec/sep_viec.py clitell-tra --id <id> --chu \"…\"")
    if bao_da_nhan:
        r = goi("clitell-da-nhan", {"ids": [c["id"] for c in ds]})
        if not r.get("ok"):
            print(f"  (báo đã nhận hỏng: {r.get('loi')} — lần hỏi sau sẽ in lại)")


def cmd_moi(a):
    cli = goi("clitell")
    loi_cli = (cli.get("loi_cli") or []) if cli.get("ok") else []
    r = goi("chua-doc")
    if not r.get("ok"):
        sys.exit(f"Không lấy được tin: {r.get('loi')}")
    tin = r["tin"]
    dl = r.get("duyet_luot")
    if a.json:
        print(json.dumps({"loi_cli": loi_cli, "tin": tin, "duyet_luot": dl}, ensure_ascii=False, indent=1))
    else:
        if r.get("tam_dung"):
            print("⏸ Máy đang TẠM DỪNG (/pause) — con canh không gọi phiên dậy cho việc thẻ tới /khoidong hoặc 7h sáng.")
        if dl:
            print("📋 " + dong_duyet_luot(dl))
        in_loi_cli(loi_cli, bao_da_nhan=False)
        if not tin:
            print("Không có tin sếp chưa đọc.")
        for t in tin:
            ma = t.get("ma_viec") or "-"
            nd = t["noi_dung"]
            if t.get("sua_luc") and t.get("ban_truoc") is not None:
                nd = f"ĐÃ SỬA «{t['ban_truoc']}» → «{nd}»"
            dau = f"#{t['id']} [{gio(t['luc'])}] {t.get('tu_ten') or '?'} · {ma}"
            if t.get("tieu_de") and ma != "-":
                dau += f" ({t['tieu_de']} · {t.get('trang_thai')})"
            print(f"{dau} · msg {t['message_id']}{' · reply ' + str(t['reply_to']) if t.get('reply_to') else ''}")
            print("   " + nd.replace("\n", "\n   "))
            if t.get("anh"):
                p = tai_tep(t["anh"], os.path.join(TRANG, "anh", ma if ma != "-" else "chua-gan"), f"tin{t['id']}")
                print(f"   📎 {p or '(tải tệp hỏng — chạy lại: anh --id ' + str(t['id']) + ')'}")
        if tin:
            print(f"→ xử xong thì: da-doc --id {','.join(str(t['id']) for t in tin)} (chỉ id đã xử)")
    if loi_cli and not a.json:
        goi("clitell-da-nhan", {"ids": [c["id"] for c in loi_cli]})
    thay = set(doc_json("da-thay.json", []))
    ghi_json("da-thay.json", sorted(thay | {t["id"] for t in tin}))


def ids_tu(s):
    try:
        return [int(x) for x in re.split(r"[,\s]+", s.strip()) if x]
    except ValueError:
        sys.exit("--id phải là số, cách nhau dấu phẩy")


def cmd_da_doc(a):
    r = goi("da-doc", {"ids": ids_tu(a.id)})
    print(json.dumps(r, ensure_ascii=False))


def canh_song():
    p = os.path.join(TRANG, "canh.pid")
    try:
        pid = int(open(p).read().strip())
        os.kill(pid, 0)
        return pid
    except Exception:
        return None


def cmd_canh(a):
    os.makedirs(TRANG, exist_ok=True)
    pid = canh_song()
    if pid and pid != os.getpid():
        print(f"Con canh đã chạy (pid {pid}) — không bật con thứ hai.")
        return
    pfile = os.path.join(TRANG, "canh.pid")
    open(pfile, "w").write(str(os.getpid()))
    het = time.time() + a.phut * 60
    bao_dung = False
    try:
        while time.time() < het:
            try:
                # Lời chủ / lệnh máy (/tatmay /momay) vẫn gọi phiên dậy kể cả lúc /pause — chủ đang nói thẳng với phiên.
                cli = goi("clitell", canh=True)
                if cli.get("ok") and cli.get("loi_cli"):
                    in_loi_cli(cli["loi_cli"])
                    return
                r = goi("chua-doc")
                if r.get("ok") and r.get("tam_dung"):
                    # 7f /pause: vẫn hỏi mỗi lượt (không tốn token) nhưng KHÔNG thoát; không ghi da-thay để /khoidong xong
                    # lượt sau thấy đủ mục chưa báo mà gọi phiên làm bù.
                    if not bao_dung:
                        print("(con canh: máy đang TẠM DỪNG — vẫn hỏi, không gọi phiên dậy cho việc thẻ tới /khoidong)", file=sys.stderr)
                        bao_dung = True
                    ghi_json("trang-thai.json", {"ids": [], "luc": int(time.time()), "tam_dung": True})
                elif r.get("ok"):
                    bao_dung = False
                    ids = [t["id"] for t in r["tin"]]
                    dl = r.get("duyet_luot")
                    # 7e — lượt duyệt cần máy: báo khi lượt/trạng thái đổi, hoặc báo rồi mà quá --nhac-phut vẫn y nguyên.
                    cu = doc_json("trang-thai.json", {})
                    dl_bao = cu.get("dl_bao") or {}
                    khoa_dl = "%s:%s:%s" % (dl["id"], dl["trang_thai"], dl["cap_nhat"]) if dl else None
                    bao_dl = bool(dl) and (dl_bao.get("khoa") != khoa_dl or time.time() - dl_bao.get("luc", 0) >= a.nhac_phut * 60)
                    if bao_dl:
                        dl_bao = {"khoa": khoa_dl, "luc": int(time.time())}
                    ghi_json("trang-thai.json", {"ids": ids, "luc": int(time.time()), "dl_bao": dl_bao if dl else {}, "duyet_luot": dl})
                    if bao_dl:
                        print("🔔 📋 " + dong_duyet_luot(dl) + " — xong thì BẬT LẠI con canh")
                        return
                    thay = set(doc_json("da-thay.json", []))
                    moi = [i for i in ids if i not in thay]
                    if moi:
                        ghi_json("da-thay.json", sorted(thay | set(moi)))
                        print(f"🔔 CÓ VIỆC SẾP MỚI: {len(moi)} tin (#{', #'.join(map(str, moi))}) — gõ «check viec sep» / làm theo .claude/commands/check-viec-sep.md, xong BẬT LẠI canh.")
                        return
            except Exception as e:
                print(f"(con canh: lỗi mạng {e} — thử lại lượt sau)", file=sys.stderr)
            time.sleep(a.giay)
        print(f"Con canh hết {a.phut} phút, " + ("máy đang TẠM DỪNG (/pause) — bật lại để còn nghe lời chủ." if bao_dung else "không có tin mới — bật lại nếu còn làm."))
    finally:
        if canh_song() == os.getpid():
            os.remove(pfile)


def nhan_anh(duong, nhan):
    from PIL import Image, ImageDraw, ImageFont
    im = Image.open(duong).convert("RGB")
    w, h = im.size
    co = max(24, w // 18)
    font = None
    for f in ["/System/Library/Fonts/Supplemental/Arial Bold.ttf", "/System/Library/Fonts/Supplemental/Arial.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]:
        if os.path.exists(f):
            font = ImageFont.truetype(f, co)
            break
    font = font or ImageFont.load_default()
    cao = int(co * 1.6)
    moi = Image.new("RGB", (w, h + cao), (20, 20, 20))
    moi.paste(im, (0, cao))
    ImageDraw.Draw(moi).text((co // 2, int(co * 0.25)), nhan, fill=(255, 220, 0), font=font)
    b = io.BytesIO()
    moi.save(b, "PNG")
    return b.getvalue()


def dung_tin(a):
    tieu = a.tieu_de.strip()
    ma = a.ma or "{MA}"
    dong = [f"<b>[{ma}] {html.escape(tieu)}</b>", ""]
    if a.noi_dung:
        dong += [html.escape(x) for x in a.noi_dung.replace("\\n", "\n").split("\n") if x.strip()]
    if a.hoi:
        cau = re.split(r"\s*(?=\b\d+\.\s)", a.hoi.replace("\\n", "\n").strip())
        dong.append("")
        for c in [x.strip() for x in cau if x.strip()]:
            dong.append(re.sub(r"\b(\d[A-D])\b", r"<b>\1</b>", html.escape(c)))
        dong += ["", "👉 Reply tin này, gõ mã lựa chọn (vd 1A 2B) hoặc nói thêm"]
    elif a.xac_nhan:
        dong += ["", f"👉 <b>{html.escape(a.xac_nhan)}</b> Reply 1A = Đã đọc"]
    if a.cuoi:
        dong += ["", html.escape(a.cuoi)]
    return "\n".join(dong)


def cmd_gui(a):
    if not (a.hoi or a.xac_nhan or a.cuoi):
        sys.exit("Thiếu dòng cuối: dùng --hoi (tin hỏi), --xac-nhan <tên> (tin chỉ cần biết) hoặc --cuoi «👉 …»")
    anh = a.anh or []
    nhan = a.nhan_anh or []
    if nhan and len(nhan) != len(anh):
        sys.exit("--nhan-anh phải đủ một nhãn cho mỗi --anh")
    b64 = []
    for i, p in enumerate(anh):
        raw = nhan_anh(p, nhan[i]) if nhan else open(p, "rb").read()
        b64.append(base64.b64encode(raw).decode())
    tep = None
    duong_tep, chu_tep = getattr(a, "tep", None), getattr(a, "chu_tep", None)  # lối dl_ns_hoi dựng Namespace không có 2 trường này
    if duong_tep:
        if anh:
            sys.exit("--tep không đi cùng --anh (Telegram gửi tài liệu và ảnh là hai loại tin khác nhau)")
        if not os.path.isfile(duong_tep):
            sys.exit(f"Không có tệp {duong_tep}")
        tep = {"ten": chu_tep or os.path.basename(duong_tep), "b64": base64.b64encode(open(duong_tep, "rb").read()).decode()}
    elif chu_tep:
        sys.exit("--chu-tep chỉ dùng cùng --tep")
    tt = a.tt or ("cho-sep-tra-loi" if a.hoi else "xong" if a.xac_nhan else None)
    a.ma = doi_ma(a.ma)
    body = {"chu": dung_tin(a), "html": True, "tieu_de": a.tieu_de, "anh": b64, "thu": a.thu}
    for k, v in (("ma", a.ma), ("duyet_luot", getattr(a, "duyet_luot", None)), ("reply_to", a.reply), ("chat_id", a.nhom), ("trang_thai", tt), ("noi_dung", a.mo_ta)):
        if v:
            body[k] = v
    if a.rieng:
        body["rieng"] = True
    if getattr(a, "rieng_that", False):
        body["rieng"] = True
        body["rieng_that"] = True
    if tep:
        body["tep"] = tep
    r = goi("gui", body)
    if getattr(a, "tra_ve", False):
        return r
    if a.thu and r.get("ok"):
        print(f"[THỬ — chưa gửi] tới: {r['chat']} · mã: {r['ma']} · thân {r['than_dong']} dòng / {r['than_ky_tu']} ký tự · {len(b64)} ảnh"
              + (f" · tệp «{r['tep']['ten']}» {r['tep']['kb']} KB" if r.get("tep") else ""))
        print(r["chu"])
        return
    print(json.dumps({k: v for k, v in r.items() if k != "chu"}, ensure_ascii=False))
    if not r.get("ok"):
        sys.exit(1)


def cmd_tao_viec(a):
    body = {"tieu_de": a.tieu_de}
    for k, v in (("noi_dung", a.noi_dung), ("ma", doi_ma(a.ma)), ("tin_goc", a.tin_goc), ("trang_thai", a.tt),
                 ("nguoi_giao", a.nguoi_giao), ("chat_id", a.chat)):
        if v:
            body[k] = v
    if a.giao_luc:
        body["giao_luc"] = int(datetime.strptime(a.giao_luc, "%d/%m/%Y %H:%M").replace(tzinfo=VN).timestamp())
    if a.gan:
        body["gan"] = ids_tu(a.gan)
    print(json.dumps(goi("tao-viec", body), ensure_ascii=False))


def cmd_trang_thai(a):
    print(json.dumps(goi("trang-thai", {"ma": doi_ma(a.ma), "trang_thai": a.tt}), ensure_ascii=False))


def cmd_ghi(a):
    body = {"ma": doi_ma(a.ma), "noi_dung": a.noi_dung}
    if getattr(a, "tt", None):
        body["trang_thai"] = a.tt
    if getattr(a, "cho", None):
        body["noi_dung"] = f"{a.noi_dung} · chờ: {a.cho}" if a.noi_dung else f"Chờ: {a.cho}"
    if not body["noi_dung"]:
        body.pop("noi_dung")
    print(json.dumps(goi("ghi" if body.get("noi_dung") else "trang-thai", body), ensure_ascii=False))


def cmd_keo(a):
    r = goi("tat-ca")
    if not r.get("ok"):
        sys.exit(f"Không kéo được sổ: {r.get('loi')}")
    theo = {}
    for t in r["tin"]:
        theo.setdefault(t["ma_viec"], []).append(t)
    dong = [f"# Sổ việc sếp (bot nhận việc {TIEN_TO}) — tự sinh bởi `sep_viec.py keo`, đừng sửa tay", "",
            f"Kéo lúc {datetime.now(VN).strftime('%d/%m/%Y %H:%M')} (giờ VN).", ""]
    con = 0
    for v in r["viec"]:
        if v["trang_thai"] not in TT_DONG:
            con += 1
        dong += [f"## {v['ma']} · {v['tieu_de']}", f"- Trạng thái: `{v['trang_thai']}` · cập nhật {gio(v['cap_nhat'])}"]
        if v.get("noi_dung"):
            dong.append("- Mô tả: " + v["noi_dung"].replace("\n", " / "))
        for t in theo.get(v["ma"], []):
            ai = "máy" if t["chat_id"] == "may" else ("bot" if t["la_bot"] else (t.get("tu_ten") or "?"))
            dong.append(f"  - [{gio(t['luc'])}] **{ai}**: {t['noi_dung'][:500].replace(chr(10), ' / ')}")
            if t.get("anh") and not t["la_bot"]:
                # Không tải hàng loạt ở đây (hook mở phiên gọi keo, phải nhanh) — cần tệp thì `anh --id`.
                dong.append(f"    - 📎 có tệp: python3 scripts/sep-viec/sep_viec.py anh --id {t['id']}")
        dong.append("")
    os.makedirs(TRANG, exist_ok=True)
    so = os.path.join(TRANG, "SO-VIEC.md")
    open(so, "w", encoding="utf-8").write("\n".join(dong))
    print(f"Sổ việc: {len(r['viec'])} việc ({con} chưa xong) → {os.path.relpath(so, GOC)}")


def cmd_anh(a):
    r = goi("chua-doc")
    t = next((x for x in r.get("tin", []) if x["id"] == a.id), None)
    if not t:
        tc = goi("tat-ca")
        t = next((x for x in tc.get("tin", []) if x["id"] == a.id), None)
    if not t or not t.get("anh"):
        sys.exit("Tin này không có tệp (hoặc không tìm thấy id).")
    print(tai_tep(t["anh"], os.path.join(TRANG, "anh", t.get("ma_viec") or "chua-gan"), f"tin{a.id}") or "Tải hỏng sau 3 lượt.")


def cmd_clitell_tra(a):
    r = goi("clitell-tra", {"id": a.id, "chu": a.chu, "thu": a.thu})
    print(json.dumps(r, ensure_ascii=False))
    if not r.get("ok"):
        sys.exit(1)


def cmd_dat_webhook(a):
    url = can("SEP_VIEC_URL").rstrip("/") + "/hook"
    r = tg("setWebhook", url=url, secret_token=can("TG_WEBHOOK_SECRET"),
           allowed_updates=["message", "edited_message", "message_reaction"], drop_pending_updates=False)
    print("setWebhook:", r.get("ok"), r.get("description"))
    cmd_menu(a)
    cmd_webhook_info(a)


def cmd_menu(a):
    """Menu «/» (7f): máy chủ đặt từ CHỖ KHAI LỆNH DUY NHẤT (cùng nguồn chữ /help) — máy nhà không gọi Telegram thẳng."""
    r = goi("menu-xem" if getattr(a, "xem", False) else "menu", {})
    for x in r.get("pham_vi") or []:
        print(f"menu {x['ten']}:", x["ok"], " ".join("/" + c for c in x["lenh"]), x.get("loi") or "")
    if not r.get("ok"):
        print("⛔", r.get("loi") or "có phạm vi đặt menu hỏng")
        sys.exit(1)


def cmd_webhook_info(a):
    w = tg("getWebhookInfo").get("result", {})
    w.pop("ip_address", None)
    print("getWebhookInfo:", json.dumps(w, ensure_ascii=False))


def cmd_xoa(a):
    body = {}
    if a.tin:
        body["tin"] = ids_tu(a.tin)
    if a.ma:
        body["ma"] = [doi_ma(x) for x in re.split(r"[,\s]+", a.ma) if x]
    if a.clitell:
        body["clitell"] = ids_tu(a.clitell)
    if a.dl:
        body["dl"] = ids_tu(a.dl)
    if not body:
        sys.exit("Nêu đích danh --tin / --ma / --clitell / --dl (không có xoá theo dải).")
    print(json.dumps(goi("xoa", body), ensure_ascii=False))


def cmd_nhap(a):
    print(json.dumps(goi("nhap", json.load(open(a.tep, encoding="utf-8"))), ensure_ascii=False))


def cmd_nhip(a):
    print(json.dumps(goi("nhip"), ensure_ascii=False))


def cmd_quet_nhac(a):
    print(json.dumps(goi("quet-nhac", {"thu": a.thu}), ensure_ascii=False))


# ---------- 7e duyệt lượt /lam ----------
DL_NHOM = [("lam", "Làm ngay", "du_kien", "✅"), ("hoi", "Cần hỏi lại", "cau", "❓"), ("gop", "Gộp", "vi_sao", "🔗"),
           ("bo", "Bỏ", "vi_sao", "✖"), ("de_sau", "Để sau", "vi_sao", "⏸")]
DL_MAU = {"lam": (46, 125, 50), "hoi": (230, 120, 0), "gop": (25, 100, 200), "bo": (110, 110, 110), "de_sau": (110, 110, 110)}
DL_AI = {"sep": "hỏi sếp", "chu-nha": "hỏi chủ nhà"}
DL_VIEC_CAN = {
    "cho-may": "chạy duyet-luot --ra pa.json → xếp MỖI việc đang chờ vào đúng một nhóm → phuong-an --tep pa.json (--thu trước)",
    "gop-y": "sửa phương án theo góp ý của chủ nhà rồi phuong-an --tep pa.json gửi bản mới",
    "da-ok": "chủ nhà đã OK — chạy ap-phuong-an rồi làm các việc vừa khởi động",
    "dang-ap": "đang áp dở — chạy lại ap-phuong-an (gửi nốt câu hỏi, không gửi trùng)",
}
TEN_CHU_NHA = ENV.get("TEN_CHU_NHA") or "Chủ nhà"
TRAN_CAPTION = 1024
TRAN_TIEU_DE = 70


def dong_duyet_luot(dl):
    s = "DUYỆT LƯỢT DL%s (%s): %s" % (dl["id"], dl["trang_thai"], DL_VIEC_CAN.get(dl["trang_thai"], "chờ"))
    if dl.get("gop_y") and dl["trang_thai"] == "gop-y":
        s += " · góp ý: «%s»" % dl["gop_y"].replace("\n", " / ")[:300]
    return s


def gon(s):
    return re.sub(r"\s+", " ", str(s or "")).strip()


def do_dai_thay(h):
    return len(html.unescape(re.sub(r"<[^>]+>", "", h)))


def dl_dong(pa, ct):
    """Hàng bảng theo thứ tự nhóm: (nhóm, STT, mã, tiêu đề việc, chữ cột cuối)."""
    hang, stt = [], 0
    for k, _, truong, _ in DL_NHOM:
        if k == "gop":
            for g in pa.get("gop") or []:
                for p in g["phu"]:
                    stt += 1
                    hang.append((k, stt, p, gon(ct.get(p, {}).get("tieu_de")), "gộp vào %s%s" % (g["chinh"], " — " + g["vi_sao"] if g.get("vi_sao") else "")))
            continue
        for x in pa.get(k) or []:
            stt += 1
            chu = x.get(truong) or ""
            if k == "hoi":
                chu = "%s: %s" % (DL_AI.get(x["ai"], x["ai"]), chu)
            hang.append((k, stt, x["ma"], gon(ct.get(x["ma"], {}).get("tieu_de")), gon(chu)))
    return hang


def dl_chu_thich(pa, ct, dl_ma, ban):
    """Chú thích tin phương án (≤ 1024 ký tự). Mã dài quá thì liệt kê STT (khớp ảnh) thay cho mã."""
    hang = dl_dong(pa, ct)

    def soan(theo_stt):
        out = ["📋 <b>[%s] Duyệt lượt · bản %s</b> · %d việc đang chờ" % (html.escape(dl_ma), ban, len(hang)), ""]
        for k, ten, _, icon in DL_NHOM:
            ds = [h for h in hang if h[0] == k]
            if not ds:
                continue
            if k == "hoi":
                ai = {x["ma"]: DL_AI.get(x["ai"], x["ai"]) for x in pa["hoi"]}
                muc = ["%s (%s)" % (h[1] if theo_stt else h[2], ai[h[2]]) for h in ds]
            elif k == "gop":
                muc = []
                for g in pa["gop"]:
                    st = [str(h[1]) if theo_stt else h[2] for h in ds if h[2] in g["phu"]]
                    muc.append("%s → %s" % (", ".join(st), g["chinh"]))
            else:
                muc = [str(h[1]) if theo_stt else h[2] for h in ds]
            out.append("%s <b>%s (%d):</b> %s" % (icon, ten, len(ds), html.escape(" · ".join(map(str, muc)))))
        out += ["", "📍 <b>Xem ở:</b> bảng chi tiết trong ảnh" + (" (số là STT trong bảng)" if theo_stt else ""),
                "👉 <b>Cần làm:</b> <b>%s</b> — Reply tin này: gõ <b>OK</b> = duyệt hết · hoặc góp ý từng mục, vd «2 bỏ · 5 hỏi sếp "
                "thêm giá · gộp 3 với 7»" % html.escape(TEN_CHU_NHA)]
        return "\n".join(out)
    h = soan(False)
    return h if do_dai_thay(h) <= TRAN_CAPTION else soan(True)


def _font(co, dam=False):
    from PIL import ImageFont
    ds = (["/System/Library/Fonts/Supplemental/Arial Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"] if dam else []) + \
         ["/System/Library/Fonts/Supplemental/Arial.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]
    for f in ds:
        if os.path.exists(f):
            return ImageFont.truetype(f, co)
    return ImageFont.load_default()


def _xuong_dong(chu, font, rong):
    dong, cur = [], ""
    for tu in str(chu).split():
        thu = (cur + " " + tu).strip()
        if font.getlength(thu) <= rong or not cur:
            cur = thu
        else:
            dong.append(cur)
            cur = tu
    return dong + ([cur] if cur else []) or [""]


def dl_anh(hang, tieu, ghi_chu, dai):
    """Ảnh bảng (Pillow): dải đỏ · tiêu đề · hàng đầu nền tối · khối nhóm hàng màu · hộp ghi chú vàng. Trả list PNG bytes (≤ 3 trang)."""
    from PIL import Image, ImageDraw
    W, PAD = 1600, 30
    cot = [("STT", 80), ("Mã việc", 270), ("Việc", 540), ("Dự kiến / câu hỏi / gộp vào", W - 2 * PAD - 80 - 270 - 540)]
    f, fd, ft = _font(26), _font(26, True), _font(34, True)
    ten_nhom = {k: (t, i) for k, t, _, i in DL_NHOM}
    khoi = []   # (loại, dữ liệu, cao)
    nhom_truoc = None
    for h in hang:
        if h[0] != nhom_truoc:
            khoi.append(("nhom", h[0], 48))
            nhom_truoc = h[0]
        o = [_xuong_dong(str(h[1]), f, cot[0][1] - 16), _xuong_dong(h[2], f, cot[1][1] - 16),
             _xuong_dong(h[3] or "(chưa có tiêu đề)", f, cot[2][1] - 16), _xuong_dong(h[4], f, cot[3][1] - 16)]
        khoi.append(("hang", (h[0], o), max(len(x) for x in o) * 34 + 18))
    dau_cao = 70 + 70 + 52
    trang, cur, cao = [], [], dau_cao
    for k in khoi:
        if cao + k[2] > 6000 and cur:
            trang.append(cur)
            cur, cao = [], dau_cao
        cur.append(k)
        cao += k[2]
    trang.append(cur)
    trang = trang[:3]
    ra = []
    for so, ds in enumerate(trang, 1):
        H = dau_cao + sum(k[2] for k in ds) + 150
        im = Image.new("RGB", (W, H), (255, 255, 255))
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, W, 60], fill=(200, 30, 30))
        d.text((PAD, 12), dai + (" · trang %d/%d" % (so, len(trang)) if len(trang) > 1 else ""), fill="white", font=fd)
        d.text((PAD, 80), tieu, fill=(20, 20, 20), font=ft)
        y = 140
        d.rectangle([PAD, y, W - PAD, y + 52], fill=(45, 45, 55))
        x = PAD
        for t, r in cot:
            d.text((x + 8, y + 12), t, fill="white", font=fd)
            x += r
        y += 52
        for loai, du, c in ds:
            if loai == "nhom":
                t, icon = ten_nhom[du]
                d.rectangle([PAD, y, W - PAD, y + c], fill=DL_MAU[du])
                d.text((PAD + 8, y + 10), t.upper(), fill="white", font=fd)
            else:
                nhom, o = du
                nen = tuple(min(255, 235 + (v // 20)) for v in DL_MAU[nhom])
                d.rectangle([PAD, y, W - PAD, y + c], fill=nen, outline=(210, 210, 210))
                x = PAD
                for i, (t, r) in enumerate(cot):
                    for j, dong in enumerate(o[i]):
                        d.text((x + 8, y + 9 + j * 34), dong, fill=(20, 20, 20), font=fd if i == 1 else f)
                    x += r
            y += c
        y += 20
        d.rectangle([PAD, y, W - PAD, y + 100], fill=(255, 243, 176), outline=(220, 180, 0))
        for j, dong in enumerate(_xuong_dong(ghi_chu, fd, W - 2 * PAD - 30)[:2]):
            d.text((PAD + 15, y + 14 + j * 38), dong, fill=(60, 40, 0), font=fd)
        b = io.BytesIO()
        im.save(b, "PNG")
        ra.append(b.getvalue())
    return ra


def dl_anh_viec(v, dl_id, duong):
    """Ảnh bảng MỘT việc (đầu câu hỏi gửi chủ nhà riêng)."""
    hang = [("hoi", 1, v["ma"], gon(v.get("tieu_de")), gon(v.get("noi_dung"))[:400])]
    b = dl_anh(hang, "Việc cần anh làm rõ trước khi làm", "%s Reply tin này: gõ mã lựa chọn (vd 1A) hoặc nói thêm" % TEN_CHU_NHA,
               "Duyệt lượt DL%s · câu hỏi" % dl_id)[0]
    open(duong, "wb").write(b)
    return duong


def dl_ns_hoi(x, v, dl_id, thu, anh=None, nhom=None):
    """Namespace cho cmd_gui: câu «cần hỏi lại» của lượt. Hỏi sếp → NHÓM (Reply tin gốc nếu tin gốc ở nhóm); hỏi chủ nhà →
    chat riêng có ảnh bảng việc. Trạng thái giữ «cho-xac-nhan»: hỏi không phải cho làm."""
    rieng = x["ai"] == "chu-nha"
    td = gon(x.get("tieu_de")) or gon(v.get("tieu_de")) or "(chưa đặt tiêu đề)"
    td = td if len(td) <= TRAN_TIEU_DE else td[:TRAN_TIEU_DE - 1].rstrip() + "…"
    return argparse.Namespace(
        ma=x["ma"], tieu_de=td, noi_dung="%s duyệt lượt DL%s: việc này cần làm rõ trước khi làm." % (TEN_CHU_NHA, dl_id),
        hoi=x["cau"], xac_nhan=None, cuoi=None, anh=[anh] if anh else [], nhan_anh=[], mo_ta=None, tt="cho-xac-nhan",
        nhom=None if rieng else nhom, reply=None if rieng or not nhom else v.get("tin_goc"), rieng=rieng, thu=thu,
        duyet_luot=dl_id, tra_ve=True)


def cmd_duyet_luot(a):
    """Gom lượt + việc đang chờ (nội dung, tin, diễn biến) + mẫu phương án ra JSON, in tóm tắt."""
    r = goi("duyet-luot-xem", {"id": a.id} if a.id else {})
    if not r.get("ok"):
        sys.exit("Không đọc được lượt: %s" % r.get("loi"))
    d = r.get("dl")
    cho = [dict(r["viec"].get(m, {"ma": m}), tin=[{"luc": gio(t["luc"]), "ai": "máy" if t["chat_id"] == "may" else ("bot" if t["la_bot"] else t.get("tu_ten")),
                                                     "noi_dung": t["noi_dung"], "ban_truoc": t.get("ban_truoc")} for t in r["tin"].get(m, [])])
           for m in r["cho"]]
    ra = {"dl": d and {k: d.get(k) for k in ("id", "trang_thai", "ban", "gop_y", "lich_su", "phuong_an")},
          "cho": cho, "mo_khac": [{"ma": m, "tieu_de": r["viec"].get(m, {}).get("tieu_de"), "trang_thai": r["viec"].get(m, {}).get("trang_thai")} for m in r["mo_khac"]],
          "huong_dan": "Xếp MỖI việc trong «cho» vào ĐÚNG MỘT nhóm: lam {ma, du_kien} · hoi {ma, ai: sep|chu-nha, cau: '1. …? 1A … · 1B …', tieu_de?} · "
                       "gop {chinh, phu:[…], vi_sao} (chinh = việc chờ đã xếp lam/hoi/de_sau, hoặc việc trong mo_khac) · bo / de_sau {ma, vi_sao} CHỈ khi chủ nhà góp ý bảo thế.",
          "mau_phuong_an": (d or {}).get("phuong_an") or {"lam": [], "hoi": [], "gop": [], "bo": [], "de_sau": []}}
    s = json.dumps(ra, ensure_ascii=False, indent=1)
    if a.ra:
        open(a.ra, "w", encoding="utf-8").write(s)
    else:
        print(s)
    print("%s · %d việc đang chờ: %s · %d việc đang mở khác" % (
        ("DL%s %s bản %s" % (d["id"], d["trang_thai"], d["ban"])) if d else "chưa có lượt mở", len(r["cho"]), ", ".join(r["cho"]) or "—",
        len(r["mo_khac"])), file=sys.stderr if not a.ra else sys.stdout)
    if d and d.get("gop_y"):
        print("Góp ý mới nhất của chủ nhà: «%s»" % d["gop_y"])


def cmd_phuong_an(a):
    """Dựng ảnh bảng + chú thích; máy chủ soát (tất định) rồi gửi MỘT tin ảnh vào chat riêng chủ nhà. --thu: chỉ soát + dựng."""
    pa = json.load(open(a.tep, encoding="utf-8"))
    pa = pa.get("mau_phuong_an", pa) if isinstance(pa, dict) and "cho" in pa else pa
    s = goi("phuong-an", {"phuong_an": pa, "thu": True})
    if s.get("_ma_http") and not s.get("loi"):
        sys.exit("Máy chủ từ chối: %s" % s)
    if s.get("loi") and not isinstance(s.get("loi"), list):
        sys.exit("⛔ %s" % s["loi"])
    loi = list(s.get("loi") or [])
    chuan = s.get("phuong_an") or pa
    xem = goi("duyet-luot-xem")
    ct = xem.get("viec") or {}
    # Đo khuôn từng câu hỏi trước (khuôn tin mục 5) — chủ nhà OK xong không vỡ lúc áp.
    for x in chuan.get("hoi") or []:
        if x["ma"] not in ct:
            continue
        ns = dl_ns_hoi(x, ct[x["ma"]], s.get("id"), True, None, None)
        ns.rieng = False   # chỉ đo khuôn chữ; lối riêng cho việc nhóm chỉ mở lúc áp
        r = cmd_gui(ns)
        if not r.get("ok"):
            loi.append("%s: câu hỏi vỡ khuôn tin — %s" % (x["ma"], r.get("loi")))
    if loi:
        print("⛔ Phương án bị từ chối, CHƯA gửi:")
        for x in loi:
            print("  - " + x)
        sys.exit(1)
    dl_ma, ban = "DL%s" % s["id"], s["ban_sau"]
    hang = dl_dong(chuan, ct)
    anh = dl_anh(hang, "Phương án dự kiến — %d việc đang chờ" % len(hang),
                 "%s Reply tin này: gõ OK = duyệt hết · hoặc góp ý từng mục theo STT/mã" % TEN_CHU_NHA, "Duyệt lượt %s · bản %s" % (dl_ma, ban))
    chu = dl_chu_thich(chuan, ct, dl_ma, ban)
    if a.ra:
        goc, duoi = os.path.splitext(a.ra)
        for i, b in enumerate(anh):
            open(a.ra if i == 0 else "%s-%d%s" % (goc, i + 1, duoi), "wb").write(b)
    if a.thu:
        print("[THỬ — chưa gửi] %s bản %s · %d ảnh · chú thích %d ký tự%s" % (dl_ma, ban, len(anh), do_dai_thay(chu), " · ảnh: " + a.ra if a.ra else ""))
        print(chu)
        return
    r = goi("phuong-an", {"phuong_an": chuan, "text": chu, "anh": [base64.b64encode(b).decode() for b in anh]})
    print(json.dumps(r, ensure_ascii=False))
    if not r.get("ok"):
        sys.exit(1)


def cmd_ap_phuong_an(a):
    """Áp lượt chủ nhà đã OK. Máy chủ (một giao dịch) gộp → khởi động → bỏ / để sau; CLI gửi từng câu «cần hỏi lại» qua
    cmd_gui rồi ghi ap-hoi (chạy lại không gửi trùng); xong hết thì ap-xong (máy chủ báo chủ nhà). --thu: chỉ in."""
    r = goi("ap-phuong-an", {"thu": a.thu})
    if not r.get("ok"):
        sys.exit(r.get("loi") or "Áp hỏng: %s" % r)
    kq = r["ket_qua"]
    print("%sLượt DL%s bản %s · khởi động: %s · gộp: %s · bỏ: %s · để sau: %s" % (
        "(thử: chưa đổi gì) " if a.thu else "", r["id"], r["ban"], ", ".join(kq["khoi_dong"]) or ("(sẽ: %s)" % ", ".join(
            x["ma"] for x in r["phuong_an"].get("lam") or []) if a.thu else "—"),
        "; ".join("%s → %s" % (", ".join(g["phu"]), g["chinh"]) for g in kq["gop"]) or "—", ", ".join(kq["bo"]) or "—",
        ", ".join(kq["de_sau"]) or "—"))
    if kq.get("bo_qua"):
        print("Không còn chờ nên không khởi động: " + ", ".join(kq["bo_qua"]))
    import tempfile
    for x in r["hoi"]:
        anh = dl_anh_viec(x["viec"], r["id"], os.path.join(tempfile.gettempdir(), "dl-hoi-%s.png" % x["ma"])) if x["ai"] == "chu-nha" else None
        print("— câu hỏi %s → %s:" % (x["ma"], "chat riêng %s" % TEN_CHU_NHA if anh else "NHÓM (sếp)" + (", Reply tin gốc" if x.get("trong_nhom") else "")))
        g = cmd_gui(dl_ns_hoi(x, x["viec"], r["id"], a.thu, anh, x.get("trong_nhom")))
        if anh and os.path.exists(anh):
            os.remove(anh)
        print("   ", json.dumps({k: v for k, v in g.items() if k != "chu"}, ensure_ascii=False))
        if not g.get("ok"):
            sys.exit("⛔ Gửi câu hỏi %s hỏng — sửa rồi chạy lại ap-phuong-an (câu đã gửi không gửi lại)." % x["ma"])
        if not a.thu:
            h = goi("ap-hoi", {"id": r["id"], "ma": x["ma"]})
            if not h.get("ok"):
                sys.exit("⛔ Ghi đã-gửi câu %s hỏng: %s" % (x["ma"], h.get("loi")))
    if a.thu:
        return
    x = goi("ap-xong", {"id": r["id"]})
    print("Đã khép DL%s%s" % (r["id"], " — đã báo chủ nhà" if x.get("gui") else " — ⚠ báo chủ nhà hỏng: %s" % (x.get("loi") or "xem nhật ký máy chủ")))


def main():
    p = argparse.ArgumentParser(description="CLI bot nhận việc oHa")
    s = p.add_subparsers(dest="lenh", required=True)
    x = s.add_parser("moi", help="tin sếp chưa đọc + lời /clitell")
    x.add_argument("--json", action="store_true")
    x.set_defaults(f=cmd_moi)
    x = s.add_parser("da-doc", help="gắn đã đọc ĐÚNG id kho")
    x.add_argument("--id", required=True)
    x.set_defaults(f=cmd_da_doc)
    x = s.add_parser("canh", help="con canh nền: có tin mới thì thoát")
    x.add_argument("--phut", type=int, default=110)
    x.add_argument("--giay", type=int, default=60)
    x.add_argument("--nhac-phut", type=int, default=15, help="lượt duyệt y nguyên quá ngần này phút thì báo lại")
    x.set_defaults(f=cmd_canh)
    x = s.add_parser("gui", help="gửi tin theo khuôn (lối gửi DUY NHẤT)")
    x.add_argument("--ma")
    x.add_argument("--tieu-de", required=True)
    x.add_argument("--noi-dung")
    x.add_argument("--hoi", help='"1. Câu? 1A Có · 1B Không 2. …"')
    x.add_argument("--xac-nhan", help="tên người cần Reply 1A = Đã đọc")
    x.add_argument("--cuoi", help="dòng cuối tự viết, bắt đầu 👉")
    x.add_argument("--anh", action="append")
    x.add_argument("--nhan-anh", action="append")
    x.add_argument("--tep", help="gửi kèm 1 tài liệu (PDF…) bằng sendDocument; chữ tin thành chú thích tệp")
    x.add_argument("--chu-tep", help="tên tệp người nhận thấy (mặc định = tên tệp gốc)")
    x.add_argument("--mo-ta", help="mô tả 4 mục ghi lên thẻ khi cấp mã mới")
    x.add_argument("--tt", choices=TRANG_THAI)
    x.add_argument("--nhom")
    x.add_argument("--reply", type=int)
    x.add_argument("--rieng", action="store_true")
    x.add_argument("--rieng-that", action="store_true",
                   help="dự án «tin riêng về nhóm» (TUNG): thật cần hỏi riêng chủ nhà thì dùng cờ này thay --rieng")
    x.add_argument("--thu", action="store_true")
    x.set_defaults(f=cmd_gui)
    x = s.add_parser("tao-viec")
    x.add_argument("--tieu-de", required=True)
    x.add_argument("--noi-dung")
    x.add_argument("--ma", help="oHa-ddmmyyyy (cấp số tiếp trong ngày gốc) hoặc oHa-ddmmyyyy-NN (mã cũ Task-… tự quy đổi)")
    x.add_argument("--tin-goc", type=int)
    x.add_argument("--gan", help="message_id gắn vào việc, cách nhau dấu phẩy")
    x.add_argument("--chat")
    x.add_argument("--tt", choices=TRANG_THAI)
    x.add_argument("--nguoi-giao")
    x.add_argument("--giao-luc", help="dd/mm/yyyy HH:MM giờ VN")
    x.set_defaults(f=cmd_tao_viec)
    x = s.add_parser("trang-thai")
    x.add_argument("--ma", required=True)
    x.add_argument("--tt", required=True, choices=TRANG_THAI)
    x.set_defaults(f=cmd_trang_thai)
    for ten in ("ghi", "chuyen"):
        x = s.add_parser(ten, help="ghi dòng tình hình lên thẻ" if ten == "ghi" else "đổi trạng thái + ghi")
        x.add_argument("--ma", required=True)
        x.add_argument("--noi-dung", required=(ten == "ghi"), default="")
        if ten == "chuyen":
            x.add_argument("--tt", required=True, choices=TRANG_THAI)
            x.add_argument("--cho", help="tên người đang chờ")
        x.set_defaults(f=cmd_ghi)
    x = s.add_parser("keo", help="kéo sổ việc về .claude/sep-viec/SO-VIEC.md")
    x.set_defaults(f=cmd_keo)
    x = s.add_parser("anh")
    x.add_argument("--id", type=int, required=True)
    x.set_defaults(f=cmd_anh)
    x = s.add_parser("clitell-tra")
    x.add_argument("--id", type=int, required=True)
    x.add_argument("--chu", required=True)
    x.add_argument("--thu", action="store_true")
    x.set_defaults(f=cmd_clitell_tra)
    x = s.add_parser("dat-webhook")
    x.set_defaults(f=cmd_dat_webhook)
    x = s.add_parser("menu", help="khai menu «/» qua máy chủ (không đụng webhook)")
    x.add_argument("--xem", action="store_true", help="đọc lại menu từng phạm vi (getMyCommands qua máy chủ)")
    x.set_defaults(f=cmd_menu)
    x = s.add_parser("duyet-luot", help="7e: gom lượt + việc đang chờ + mẫu phương án ra JSON")
    x.add_argument("--id", type=int)
    x.add_argument("--ra")
    x.set_defaults(f=cmd_duyet_luot)
    x = s.add_parser("phuong-an", help="7e: soát + dựng ảnh bảng + gửi phương án vào chat riêng chủ nhà")
    x.add_argument("--tep", required=True)
    x.add_argument("--thu", action="store_true")
    x.add_argument("--ra", help="lưu ảnh bảng ra tệp .png")
    x.set_defaults(f=cmd_phuong_an)
    x = s.add_parser("ap-phuong-an", help="7e: áp lượt chủ nhà đã OK")
    x.add_argument("--thu", action="store_true")
    x.set_defaults(f=cmd_ap_phuong_an)
    x = s.add_parser("webhook-info")
    x.set_defaults(f=cmd_webhook_info)
    x = s.add_parser("xoa")
    x.add_argument("--tin")
    x.add_argument("--ma")
    x.add_argument("--clitell")
    x.add_argument("--dl", help="id lượt duyệt thử")
    x.set_defaults(f=cmd_xoa)
    x = s.add_parser("nhap")
    x.add_argument("tep")
    x.set_defaults(f=cmd_nhap)
    x = s.add_parser("nhip")
    x.set_defaults(f=cmd_nhip)
    x = s.add_parser("quet-nhac")
    x.add_argument("--thu", action="store_true")
    x.set_defaults(f=cmd_quet_nhac)
    a = p.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()
