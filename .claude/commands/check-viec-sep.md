---
description: Xử lý việc sếp dồn từ bot nhận việc oHa (moi → xử → da-doc → bật lại con canh)
---

Làm đúng 5 bước, CLI là `python3 scripts/sep-viec/sep_viec.py`. Mã việc dự án là `oHa-ddmmyyyy-NN` (mã cũ `Task-…` sếp gõ
lại vẫn nhận — CLI và máy chủ tự quy đổi sang `oHa-`).

0. **Duyệt lượt** (`moi` / con canh in dòng «📋 DUYỆT LƯỢT DLn (<trạng thái>)» — chủ nhà gõ `/lam` trần) — làm TRƯỚC, theo trạng thái:
   - `cho-may` / `gop-y` → `duyet-luot --ra /tmp/dl.json` → đọc từng việc đang chờ (nội dung, tin, góp ý mới nhất) → xếp MỖI việc
     vào ĐÚNG MỘT nhóm trong `mau_phuong_an`: `lam` {ma, du_kien} · `hoi` {ma, ai: `sep` (nội dung/kinh doanh) | `chu-nha`
     (hệ thống/kỹ thuật), cau «1. …? 1A … · 1B …»} · `gop` {chinh, phu[], vi_sao} · `bo` / `de_sau` CHỈ khi chủ nhà góp ý bảo thế →
     `phuong-an --tep /tmp/dl.json --thu --ra /tmp/dl.png` (mở ảnh bằng Read) → `phuong-an --tep /tmp/dl.json` (gửi chat riêng chủ nhà).
   - `cho-chu-nha` → chờ chủ nhà Reply (OK hoặc góp ý), không làm gì.
   - `da-ok` / `dang-ap` → `ap-phuong-an --thu` rồi `ap-phuong-an` → làm các việc vừa khởi động như việc mới đã nhận.
     Việc được hỏi vẫn CHỜ — hỏi không phải cho làm. Thợ (subagent) chỉ được `--thu` (cổng chặn).

1. `moi` → mục «📨 LỜI CHỦ GỬI THẲNG VÀO CLI» (nếu có) coi như chủ gõ trong cửa sổ này, xử TRƯỚC; trả chủ bằng
   `clitell-tra --id <id> --chu "…"` (≤6 dòng, ≤600 ký tự). Mở ảnh/tệp in ra bằng Read. Cần toàn cảnh: `keo` rồi đọc
   `.claude/sep-viec/SO-VIEC.md`. Trong mục đó có hai loại dòng máy (bộ lệnh chung, skill bot-nhan-viec mục 7f):
   - **«⚙ LỆNH MÁY»** `/tatmay` · `/momay` → làm ĐÚNG `.claude/commands/tatmay.md` · `.claude/commands/momay.md`.
   - **«🗂 SỔ DỒN»** (chủ gõ `/lamdi` hoặc lịch gom mỗi 2 giờ 8h–22h) = **Sổ dồn**: chạy `moi` lấy id (các lời trong sổ đã được
     bật cờ chưa đọc nên `moi` in ra đủ) rồi xử TỪNG mục như bước 2 — không gộp trả một câu chung; xử xong mục nào
     `da-doc --id` đúng mục đó. Báo chủ một dòng `clitell-tra` khi xong cả sổ.
   Dòng «⏸ Máy đang TẠM DỪNG» (chủ gõ `/pause`, hoặc lịch 23h) → chỉ xử lời CLI; việc thẻ để tới `/khoidong` (hoặc 7h sáng).
2. Từng tin:
   - **việc mới** (mã thẻ `cho-xac-nhan`) → nhận: `trang-thai --ma <mã> --tt dang-lam`, làm theo luật dự án.
   - **dòng «▶ Chủ nhà cho làm»** (chủ gõ `/lam <mã>` · `/lam tatca` · áp lượt) → việc đã sang `dang-lam`, làm luôn.
   - **câu trả lời** (Reply vào tin bot, mã lựa chọn `1A 2B` hoặc «Ý khác») → làm tiếp đúng việc đó.
   - **tin sửa** (`ĐÃ SỬA «cũ» → «mới»`) → so bản cũ/mới; đang làm theo bản cũ thì sửa.
   - **tin thường không mã** → tự quyết: đúng là việc thì `tao-viec --ma oHa-<ngày giao gốc ddmmyyyy> --tin-goc <message_id> --gan <message_id>`.
   - Không rõ → hỏi chủ nhà (nhắn riêng: `gui --rieng …`), KHÔNG đoán, KHÔNG hỏi trong nhóm sếp.
3. `da-doc --id <id kho đã xử>` — đích danh, không có «đánh dấu hết».
4. Ghi diễn biến lên thẻ: `ghi --ma <mã> --noi-dung "<tình hình ngắn>"` / `chuyen --ma <mã> --tt <trạng thái>`; báo sếp chỉ qua
   `gui --ma <mã> …` (`--thu` trước). Bật lại con canh NỀN (run_in_background, timeout 7200000):
   `python3 scripts/sep-viec/sep_viec.py canh` — quên bật là lỡ việc.
5. `keo` cập nhật sổ; ghi «xử lý xong việc gì» vào sổ tiếp tục của phiên.
