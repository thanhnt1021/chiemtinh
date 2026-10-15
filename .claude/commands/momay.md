---
description: Chủ nhà gõ /momay trên bot oHa — vừa mở máy: đọc sổ, chạy tiếp việc dở rồi báo
---

Lời «⚙ LỆNH MÁY … /momay» tới qua con canh / `moi` (skill bot-nhan-viec mục 7f). CLI là `python3 scripts/sep-viec/sep_viec.py`.

1. Báo nhận: `clitell-tra --id <id lệnh> --chu "Đã nhận /momay — đang đọc sổ, chạy tiếp việc dở."`
2. **Đọc sổ**: `.claude/sep-viec/SO-TAT-MAY.md` (lần `/tatmay` trước) → `keo` (sổ việc mới nhất) → `moi` (tin dồn lúc máy tắt;
   xử theo `.claude/commands/check-viec-sep.md`, mục duyệt lượt / lời CLI làm trước).
3. **Chạy tiếp việc dở** theo sổ, từng việc một: đối chiếu thẻ (`SO-VIEC.md`) — thẻ đã Xong / huỷ trong lúc máy tắt thì bỏ;
   còn lại làm tiếp từ đúng bước ghi trong sổ, thợ cần thì giao lại kèm chỗ dừng. Ghi `ghi --ma <mã> --noi-dung "Mở máy: làm tiếp từ …"`.
4. Không có sổ (tắt máy không qua `/tatmay`) → dựa `SO-VIEC.md`: thẻ `dang-lam` / `sep-da-tra-loi` là việc dở; không rõ
   bước nào thì hỏi chủ bằng `clitell-tra`, không đoán.
5. Đổi tên sổ đã dùng thành `.claude/sep-viec/SO-TAT-MAY-<ddmmyyyy-HHMM>.md` (khỏi đọc lại lần sau). Bật con canh NỀN (`canh`).
6. Báo: `clitell-tra --id <id lệnh> --chu "Đã mở lại: chạy tiếp N việc (<mã>…), M tin dồn đã xử."` (≤6 dòng, ≤600 ký tự).
