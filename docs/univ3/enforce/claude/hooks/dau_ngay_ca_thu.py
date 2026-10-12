#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""dau_ngay_ca_thu.py — bộ ca thử MẢNG B của phiếu P085 (bộ nhận diện lệnh đầu-ngày).

Phủ AC15 (dựng lại ca sáng 09/09) · AC16 (8 ca nhận diện, ca ⑧ là nguyên văn prompt
founder) · AC17 (cây quyết định gõ lần hai) · AC17b (hai nơi tra `.map` ra cùng một số) ·
AC19 (SessionStart chỉ NHẮC, không tự mở) · AC24a (cấm cờ riêng theo tên dự án).

Chạy HOÀN TOÀN trong hộp cát: `WSEQ_ROOT` trỏ thư mục tạm, nhật ký trỏ tệp tạm. Sổ số
THẬT đang phục vụ worker sống — không đụng một byte.
"""
import importlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import tokenize

HOOKS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HOOKS)
KQ = []
US = "\037"


def ca(ten, dat, chi_tiet=""):
    KQ.append((ten, bool(dat)))
    print("%s %-70s %s" % ("✅ ĐẠT " if dat else "❌ TRƯỢT", ten, chi_tiet))


def ma_khong_comment_string(ma_nguon: str) -> str:
    """Xoá mọi COMMENT + STRING (kể cả docstring nhiều dòng) khỏi `ma_nguon`, giữ
    nguyên số dòng. WHY (W102, 15/09/2026): ca W15-5 dò `deny/ask/exit(2)` bằng
    `re.search` thẳng trên text thô -> bắt oan CHÍNH CHỮ "deny" nằm trong một dòng
    chú thích kể chuyện về tiến trình KHÁC (`nhai_lai_gate`), không phải nhánh
    `deny` thật trong hàm đang xét. Dùng `tokenize` (không phải string strip tay)
    vì docstring có thể chứa `#` và trải nhiều dòng — cắt bằng regex dễ ăn nhầm.
    """
    dong = ma_nguon.splitlines(keepends=True)
    try:
        for tok in tokenize.generate_tokens(io.StringIO(ma_nguon).readline):
            if tok.type not in (tokenize.COMMENT, tokenize.STRING):
                continue
            (sl, sc), (el, ec) = tok.start, tok.end
            if sl == el:
                d = dong[sl - 1]
                dong[sl - 1] = d[:sc] + " " * (ec - sc) + d[ec:]
            else:
                dong[sl - 1] = dong[sl - 1][:sc]
                for i in range(sl, el - 1):
                    dong[i] = "\n"
                dong[el - 1] = " " * ec + dong[el - 1][ec:]
    except tokenize.TokenizeError:
        pass
    return "".join(dong)


def hop_cat():
    goc = os.path.realpath(tempfile.mkdtemp(prefix="dau-ngay-ca-thu-"))
    os.makedirs(os.path.join(goc, "counter"))
    os.makedirs(os.path.join(goc, "kho"))
    return goc


def nap(goc, nhat_ky):
    os.environ["WSEQ_ROOT"] = os.path.join(goc, "counter")
    M = importlib.reload(importlib.import_module("mo_phien_gate"))
    M.NHAT_KY = nhat_ky
    return M


def wseq(goc, *dt, project="HopCat"):
    r = subprocess.run(["bash", os.path.join(HOOKS, "wseq.sh")] + list(dt),
                       capture_output=True, text=True,
                       env=dict(os.environ, WSEQ_ROOT=os.path.join(goc, "counter"),
                                WSEQ_PROJECT=project))
    return (r.stdout or "").strip()


def bam(p):
    import hashlib
    try:
        return hashlib.sha256(open(p, "rb").read()).hexdigest()
    except OSError:
        return ""


def main():
    goc = hop_cat()
    nhat_ky = os.path.join(goc, "mo-phien.log")
    kho = os.path.join(goc, "kho")
    C = os.path.join(goc, "counter")
    try:
        M = nap(goc, nhat_ky)

        # ── AC16 — tám ca nhận diện, ca ⑧ là NGUYÊN VĂN prompt founder gõ 09:18 ────
        ca16 = [("skill đầu ngày:", "việc hôm nay, skill đầu ngày:", True),
                ("đầu ngày nhé", "đầu ngày nhé", True),
                ("/dau-ngay", "/dau-ngay", True),
                ("sod (đầu câu)", "sod", True),
                ("mai đầu ngày mình làm tiếp", "mai đầu ngày mình làm tiếp", False),
                ("chưa đầu ngày mà", "chưa đầu ngày mà", False),
                ("đầu ngày hôm qua anh đã bảo rồi?", "đầu ngày hôm qua anh đã bảo rồi?", False)]
        tot = all(M.can_dau_ngay(p) == m for _t, p, m in ca16)
        ca("AC16 bảy ca nhận/không nhận", tot,
           "; ".join("%s=%s" % (t, M.can_dau_ngay(p)) for t, p, _m in ca16[:3]))
        goc_prompt = ""
        try:
            sj = json.load(open(os.path.expanduser(
                "~/.claude/so-lenh/EtsyFulfillChichub/2026-09-09/.so.json"), encoding="utf-8"))
            goc_prompt = "\n".join((sj["muc"]["L01"].get("gach") or []))
        except Exception:
            pass
        if goc_prompt:
            p8 = "việc hôm nay, skill đầu ngày: " + goc_prompt
            ca("AC16 ⑧ CHÍ TỬ — nguyên văn prompt 09:18 (có ? · nếu×4 · không · chưa · hôm qua)",
               M.can_dau_ngay(p8) is True, "%d ký tự" % len(p8))
        else:
            ca("AC16 ⑧ CHÍ TỬ — nguyên văn prompt 09:18", False, "không đọc được sổ lệnh thật")

        # ── AC15 — dựng lại ĐÚNG ca sáng 09/09 ────────────────────────────────────
        open(os.path.join(C, "HopCat.dau-ngay"), "w").write("2026-09-08 07:14:47\n1\n")
        open(os.path.join(C, "HopCat.seq"), "w").write("2026-09-08\n131\n")
        M.hom_nay_vn = lambda: "2026-09-09"          # đồng hồ giả: sáng hôm sau
        # W102 (15/09/2026): tầng vỏ `wseq.sh` đọc đồng hồ THẬT — không ép cùng ngày với
        # đồng hồ giả trên thì `moc != nay` không bao giờ khớp lại, nhánh "đã mở ngày rồi"
        # (AC17 a/b/c/d) không đường nào tới được. Xem `wseq.sh` biến `WSEQ_HOM_NAY_VN`.
        os.environ["WSEQ_HOM_NAY_VN"] = "2026-09-09"
        os.makedirs(os.path.join(goc, "HopCat"), exist_ok=True)
        # CHỈ GỌI MỘT LẦN: bản cũ gọi `xu_ly_dau_ngay` hai lần liền (dòng đầu là code
        # chết `kho if False else ...` luôn trỏ cùng path) — với đồng hồ giả CHƯA ép khớp
        # tầng vỏ, lệch ngày làm cả hai lần đều rơi nhánh "MỞ NGÀY MỚI" nên không lộ ra.
        # Ép khớp xong thì lệnh gọi thứ hai (giả gõ "đầu ngày" LẦN NHÌ ngay tức khắc) sẽ
        # đúng lẽ rơi vào nhánh "Hỏi lại founder" — phá luôn AC15. Gọi đúng MỘT LẦN mới
        # đúng ý AC15 ("mốc 2026-09-08 + gõ lệnh MỘT LẦN -> MỞ NGÀY MỚI").
        cau = M.xu_ly_dau_ngay(os.path.join(goc, "HopCat"))
        moc = open(os.path.join(C, "HopCat.dau-ngay")).read().split()[0]
        so = wseq(goc, "next", "viec-sang-hom-sau", "W?? việc sáng hôm sau")
        ca("AC15 mốc `2026-09-08` + gõ lệnh -> MỞ NGÀY MỚI, in dòng xác nhận",
           "MỞ NGÀY LÀM VIỆC MỚI" in cau and moc != "2026-09-08", cau.splitlines()[0][:70])
        ca("AC15 `wseq next` ngay sau đó trả về W01", so == "W01", "trả về %s" % so)

        # ── AC17 — cây quyết định khi gõ LẦN HAI trong ngày ───────────────────────
        h1 = bam(os.path.join(C, "HopCat.dau-ngay"))
        s1 = bam(os.path.join(C, "HopCat.seq"))
        cau_b = M.xu_ly_dau_ngay(os.path.join(goc, "HopCat"))
        ca("AC17(b) chưa có dấu chốt ngày -> KHÔNG tự reset, in câu đề nghị HỎI founder",
           "Hỏi lại founder" in cau_b and bam(os.path.join(C, "HopCat.dau-ngay")) == h1
           and bam(os.path.join(C, "HopCat.seq")) == s1, cau_b.splitlines()[0][:70])
        with open(nhat_ky, "a", encoding="utf-8") as f:
            f.write("%s\tCHOT-NGAY sid=abc cwd=%s — da goi dung skill, go co\n"
                    % (time.strftime("%Y-%m-%d %H:%M:%S"), os.path.join(goc, "discord")))
        cau_c = M.xu_ly_dau_ngay(os.path.join(goc, "HopCat"))
        ca("AC17(c) dấu chốt ngày của DỰ ÁN KHÁC -> vẫn rơi vào nhánh hỏi",
           "Hỏi lại founder" in cau_c)
        with open(nhat_ky, "a", encoding="utf-8") as f:
            f.write("%s\tCHOT-NGAY sid=abc — da goi dung skill, go co\n"
                    % time.strftime("%Y-%m-%d %H:%M:%S"))
        cau_d = M.xu_ly_dau_ngay(os.path.join(goc, "HopCat"))
        ca("AC17(d) dấu CŨ chưa có `cwd=` -> rơi vào nhánh hỏi, KHÔNG đoán",
           "Hỏi lại founder" in cau_d)
        with open(nhat_ky, "a", encoding="utf-8") as f:
            f.write("%s\tCHOT-NGAY sid=abc cwd=%s — da goi dung skill, go co\n"
                    % (time.strftime("%Y-%m-%d %H:%M:%S"), os.path.join(goc, "HopCat")))
        # Chốt ngày ĐÓNG hết worker của phiên trước (founder C3: "tao luôn chốt ngày xong
        # mới mở đầu ngày"). Không đóng thì `busy_numbers` giữ chỗ W01 cho con còn chạy —
        # đúng luật chống hai worker cùng số, không phải lỗi.
        wseq(goc, "done", "viec-sang-hom-sau")
        cau_a = M.xu_ly_dau_ngay(os.path.join(goc, "HopCat"))
        phien = open(os.path.join(C, "HopCat.dau-ngay")).read().split()[-1]
        so2 = wseq(goc, "next", "viec-phien-hai", "W?? việc phiên hai")
        ca("AC17(a) có dấu chốt ngày ĐÚNG dự án -> mở dãy mới, `.map` ghi phiên 2, next=W01",
           "MỞ NGÀY LÀM VIỆC MỚI" in cau_a and phien == "2" and so2 == "W01",
           "phiên=%s · next=%s" % (phien, so2))

        # ── AC17b — hai nơi tra `.map` phải ra CÙNG MỘT SỐ ────────────────────────
        US = "\037"
        with open(os.path.join(C, "HopCat.map"), "a", encoding="utf-8") as f:
            ngay = open(os.path.join(C, "HopCat.seq")).read().split()[0]
            f.write(US.join(["W130", "viec-trung", "việc trùng bản ghi cũ",
                             "2026-09-09 08:00:00", "running", ngay, "2"]) + "\n")
            f.write(US.join(["W130", "viec-trung", "việc trùng bản ghi MỚI",
                             "2026-09-09 09:00:00", "running", ngay, "2"]) + "\n")
        d_wseq = wseq(goc, "get", "viec-trung")
        # W102 (15/09/2026): bản cũ tự viết mock lọc `.map` tay (chỉ khớp cột slug, KHÔNG
        # lọc ngày/phiên) — không gọi hàm SẢN XUẤT nào cả, nên dù wseq.sh và
        # worker_cap_enforce.py có LỆCH luật nhau thì ca thử vẫn không bắt được. Gọi đúng
        # hàm thật `_so_trong_so` (worker_cap_enforce.py:1237) — hàm này tự khai "y hệt
        # wseq.sh line_of_slug" trong docstring của nó; ca thử phải ĐO lời khai đó, không
        # tin suông.
        W = importlib.reload(importlib.import_module("worker_cap_enforce"))
        d_wce = W._so_trong_so(os.path.join(goc, "HopCat"), "viec-trung")
        ca("AC17b `.map` có hai dòng cùng W130 -> cả hai nơi tra đều lấy DÒNG CUỐI",
           bool(d_wseq) and d_wce == "W130", "wseq=%r · worker_cap=%r" % (d_wseq, d_wce))

        # ── W104 (15/09/2026) — CHE ĐƯỜNG THỨ BA của `so_worker()` ────────────────
        # Bệnh do thợ trước soi ra: `so_worker()` mở đường THỨ BA tự đọc `.map` bằng
        # luật RIÊNG (chỉ khớp slug, KHÔNG lọc ngày/phiên) — lệch với `wseq.sh
        # line_of_slug` và `_so_trong_so` mỗi khi khoá chính (slug, ngày, phiên) trượt.
        # Đo thật (script hộp cát riêng, TRƯỚC khi vá): đường 1&2 trả "", đường 3 (cũ)
        # trả "W07" của một dòng 5 NGÀY TRƯỚC — LỆCH, không ai biết. Ca dưới dựng lại
        # đúng ca đó TRONG bộ hồi quy này, xác nhận ĐƯỜNG DỰ PHÒNG đã bị vá GỌI LẠI
        # ĐÚNG hàm chính (không mở luật lỏng hơn) và không còn vồ nhầm số cũ.
        import re  # nạp SỚM: `main()` có `import re` cục bộ ở dưới, không nạp trước
                   # thì tên `re` bị coi LOCAL cho cả hàm -> dùng ở đây lỗi UnboundLocal.
        with open(os.path.join(C, "HopCat.map"), "a", encoding="utf-8") as f:
            f.write(US.join(["W07", "viec-w104-lech-ngay", "việc W104 lệch ngày cũ",
                             "2026-09-01 09:00:00", "running", "2026-09-01", "1"]) + "\n")
        r_wseq = subprocess.run(["bash", os.path.join(HOOKS, "wseq.sh"), "get",
                                 "viec-w104-lech-ngay"],
                                capture_output=True, text=True,
                                env=dict(os.environ, WSEQ_ROOT=C, WSEQ_PROJECT="HopCat"))
        d1_wseq, rc1_wseq = (r_wseq.stdout or "").strip(), r_wseq.returncode
        d2_wce = W._so_trong_so(os.path.join(goc, "HopCat"), "viec w104 lech ngay")
        os.environ["W104_VET_DUONG_DU_PHONG"] = "1"
        _buf = io.StringIO()
        try:
            with __import__("contextlib").redirect_stderr(_buf):
                d3_so_worker = W.so_worker(
                    (99, "sid", "viec w104 lech ngay", "cwd", "vung"),
                    os.path.join(goc, "HopCat"))
        finally:
            del os.environ["W104_VET_DUONG_DU_PHONG"]
        _vet = _buf.getvalue()
        ca("W104-1 khoá chính trượt (ngày/phiên lệch) -> đường 1 & đường 2 CÙNG rỗng",
           rc1_wseq != 0 and d1_wseq == "" and d2_wce == "",
           "wseq rc=%d %r · worker_cap=%r" % (rc1_wseq, d1_wseq, d2_wce))
        ca("W104-2 ca thử THẬT SỰ chạy vào đường dự phòng (dòng vết in ra)",
           "da chay vao duong du phong" in _vet and "viec-w104-lech-ngay" in _vet,
           _vet.strip()[:90])
        ca("W104-3 đường dự phòng KHÔNG còn vồ số cũ — trả CÙNG kết luận (rỗng) với "
           "đường 1 & 2, không phải `W07` giả",
           d3_so_worker != "W07" and not re.match(r"^W\d+$", d3_so_worker or ""),
           "đường3=%r" % d3_so_worker)

        # ── AC19 — SessionStart chỉ NHẮC, không tự mở ─────────────────────────────
        open(os.path.join(C, "HopCat.dau-ngay"), "w").write("2026-09-08 07:14:47\n1\n")
        h2 = bam(os.path.join(C, "HopCat.dau-ngay"))
        cau_ss, doi = M.buoc_ngay_lam_viec(os.path.join(goc, "HopCat"))
        ca("AC19 `SessionStart` mốc cũ + đồng hồ mới -> KHÔNG gọi `wseq dau-ngay`, chỉ NHẮC",
           doi is False and bam(os.path.join(C, "HopCat.dau-ngay")) == h2
           and 'gõ "đầu ngày"' in cau_ss, cau_ss[:80])

        # ── AC24(a) — cấm cờ riêng theo tên dự án ─────────────────────────────────
        import re
        ma = open(os.path.join(HOOKS, "mo_phien_gate.py"), encoding="utf-8").read()
        than = ma[ma.index("def buoc_ngay_lam_viec"):]
        hit = [d for d in than.splitlines()
               if re.search(r"EtsyFulfillChichub|chiemtinh|discord|iloveus|NHATRANGdream", d)]
        ca("AC24(a) mã mới KHÔNG có nhánh rẽ theo tên dự án", not hit, hit[:1])

        # ══ AC18 · AC18c — SỐ SAI DÃY: TỰ SỬA RỒI CHO QUA (W15, 09/09/2026) ═══════
        # Ca gốc: 13:49 hôm nay một vé xếp hàng được cấp **W134** trong khi dãy đang là
        # W01…W15 — founder bắt lỗi tại chỗ. Bộ ca dưới đây dựng lại đúng ca đó.
        import importlib as _il
        WCE = _il.reload(_il.import_module("worker_cap_enforce"))
        duan = os.path.join(goc, "HopCat")

        def dung_so(seq="2026-09-08\n131\n", moc="2026-09-08 07:14:47\n1\n"):
            open(os.path.join(C, "HopCat.dau-ngay"), "w").write(moc)
            open(os.path.join(C, "HopCat.seq"), "w").write(seq)
            open(os.path.join(C, "HopCat.map"), "w").write("")

        # ── W15-1 — CA GỐC: điều phối mở dãy mới W11…W13, vé xếp hàng xin `next` ──
        dung_so()
        for _sl, _so in (("viec-a", "W11"), ("viec-b", "W12"), ("viec-c", "W13")):
            wseq(goc, "adopt", _sl, _so, "viec")
        so_ve = wseq(goc, "next", "day-vinaway-len-demo-va-prod", "day Vinaway len demo")
        ca("W15-1 CA GỐC: vé xếp hàng nhận số ĐÚNG DÃY (W14), không phải W134",
           so_ve == "W14", "vé nhận %r · bộ đếm %r" % (so_ve, wseq(goc, "bo-dem")))

        # ── W15-1b — chứng minh lỗ CÓ THẬT: chạy lại y hệt trên BẢN SAO LƯU ───────
        cu_sh = "/tmp/backup-w15-09092026/wseq.sh"
        if os.path.isfile(cu_sh):
            dung_so()
            for _sl, _so in (("viec-a", "W11"), ("viec-b", "W12"), ("viec-c", "W13")):
                subprocess.run(["bash", cu_sh, "adopt", _sl, _so, "viec"],
                               capture_output=True, text=True,
                               env=dict(os.environ, WSEQ_ROOT=C, WSEQ_PROJECT="HopCat"))
            r = subprocess.run(["bash", cu_sh, "next", "day-vinaway-len-demo-va-prod", "x"],
                               capture_output=True, text=True,
                               env=dict(os.environ, WSEQ_ROOT=C, WSEQ_PROJECT="HopCat"))
            cu_so = (r.stdout or "").strip()
            ca("W15-1b BẢN SAO LƯU vẫn nhả số ngoài dãy -> lỗ có thật",
               cu_so not in ("", "W14"), "bản cũ nhả %r" % cu_so)

        # ── W15-2/3/4 — ba ca của §7B.7, mỗi ca một hộp cát SẠCH ─────────────────
        def mot_ca(go):
            dung_so()
            for i in range(1, 6):
                wseq(goc, "adopt", "viec-%d" % i, "W%02d" % i, "viec %d" % i)
            return WCE.chuan_hoa_so_day(go, duan)

        m1, b1 = mot_ca("W131 viec moi hoan toan")
        ca("W15-2 số VƯỢT DÃY (gõ W131, dãy đang ở W05) -> sửa về W06, việc vẫn chạy",
           m1.startswith("W06 ") and "W131" in b1, "%r | %s" % (m1, b1))
        m2, b2 = mot_ca("W03 viec khac han ten khac")
        ca("W15-3 số TRÙNG worker đang sống -> sửa về số kế tiếp W06",
           m2.startswith("W06 ") and bool(b2), "%r | %s" % (m2, b2))
        m3, b3 = mot_ca("W06 viec hop le binh thuong")
        ca("W15-4 số HỢP LỆ -> KHÔNG đụng gì",
           m3 == "W06 viec hop le binh thuong" and b3 == "", "%r | %r" % (m3, b3))

        # ── W15-5 — AC18c LỚP 1: mã cụm chuẩn hoá không có đường làm mất việc ────
        _ma = open(os.path.join(HOOKS, "worker_cap_enforce.py"), encoding="utf-8").read()
        _cum = _ma[_ma.index("def chuan_hoa_so_day"):_ma.index("def _ra_cho_qua")]
        # W102 (15/09/2026): dò trên bản đã LỌC SẠCH comment/string — bản thô bắt oan
        # dòng chú thích `# ... rồi \`nhai_lai_gate\` (tiến trình khác) \`deny\` ...` kể
        # chuyện về TIẾN TRÌNH KHÁC, không phải nhánh `deny` thật của hàm đang xét.
        _xau = [d for d in ma_khong_comment_string(_cum).splitlines()
                if re.search(r'deny|exit\(2\)|"ask"|sys\.exit\(2\)', d)]
        ca("W15-5 AC18c lớp 1: cụm chuẩn hoá số KHÔNG có `deny`/`ask`/`exit(2)`",
           not _xau, _xau[:1])

        # ── W15-6 — AC18c LỚP 2 (ca hành vi): chạy hook THẬT với ba payload ──────
        def chay_hook(desc):
            r = subprocess.run([sys.executable, os.path.join(HOOKS, "worker_cap_enforce.py")],
                               input=json.dumps({"hook_event_name": "PreToolUse",
                                                 "tool_name": "Agent", "cwd": duan,
                                                 "tool_input": {"description": desc,
                                                                "prompt": "GHI: /tmp\nviec"}}),
                               capture_output=True, text=True,
                               env=dict(os.environ, WSEQ_ROOT=C))
            return r.returncode, (r.stdout or "")
        _hv = []
        for _g in ("W131 viec vuot day", "W03 viec trung so", "W06 viec hop le"):
            dung_so()
            for i in range(1, 6):
                wseq(goc, "adopt", "viec-%d" % i, "W%02d" % i, "viec %d" % i)
            _hv.append(chay_hook(_g))
        ca("W15-6 AC18c lớp 2: cả BA input -> mã thoát 0, stdout không có `deny`/`ask`",
           all(m == 0 and '"deny"' not in o and '"ask"' not in o for m, o in _hv),
           " · ".join("ma=%d" % m for m, _o in _hv))
        # Lớp 2b — CẤM ĐẠT RỖNG: hai ca sai dãy phải THẬT SỰ đính `updatedInput` mang số
        # mới. Không có dòng này thì hook im re cũng "đạt", đúng kiểu trượt âm thầm mà
        # AC18c lớp 3 sinh ra để bắt.
        ca("W15-6b hai ca sai dãy phải đính `updatedInput` mang số đã sửa",
           all('"updatedInput"' in o and '"description": "W06 ' in o for _m, o in _hv[:2])
           and '"updatedInput"' not in _hv[2][1],
           "①%s ②%s ③%s" % tuple('có' if '"updatedInput"' in o else 'KHÔNG'
                                 for _m, o in _hv))

        # ── W15-7 — `adopt` ghi đủ CỘT PHIÊN, y hệt `next` ───────────────────────
        dung_so()
        wseq(goc, "adopt", "viec-x", "W02", "viec x")
        _c = open(os.path.join(C, "HopCat.map"), encoding="utf-8").read().rstrip("\n").split(US)
        ca("W15-7 `wseq adopt` ghi đủ 7 cột (có cột `phien`)", len(_c) >= 7, "%d cột" % len(_c))
    finally:
        shutil.rmtree(goc, ignore_errors=True)
    n = sum(1 for _t, d in KQ if d)
    print("-" * 90)
    print("Tổng: %d đạt / %d ca" % (n, len(KQ)))
    print("(đã xoá hộp cát — sổ số thật không bị đụng)")
    return 0 if n == len(KQ) else 1


if __name__ == "__main__":
    sys.exit(main())
