---
description: Chủ nhà gõ /tatmay trên bot oHa — sắp tắt máy: cất hết việc dở, dừng thợ, ghi sổ rồi báo
---

Lời «⚙ LỆNH MÁY … /tatmay» tới qua con canh / `moi` (skill bot-nhan-viec mục 7f). CLI là `python3 scripts/sep-viec/sep_viec.py`.
Máy sắp tắt — làm nhanh, theo thứ tự, không mở việc mới.

1. Báo nhận ngay: `clitell-tra --id <id lệnh> --chu "Đã nhận /tatmay — đang cất việc dở, chờ báo xong hãy tắt máy."`
2. **Dừng thợ**: liệt kê mọi tiến trình nền / thợ (subagent) phiên này đang chạy. Thợ đang sửa tệp → nhắn thợ ghi lại
   chỗ dừng (tệp, bước, lệnh chạy tiếp) rồi dừng; tiến trình nền (dev server, trình duyệt thử…) → tắt, ghi PID đã tắt.
   Không commit / deploy dở dang để kịp tắt — việc chưa xong thì để nguyên, ghi rõ.
3. **Cất việc dở lên thẻ**: mỗi thẻ đang làm (`keo` rồi đọc `.claude/sep-viec/SO-VIEC.md`, trạng thái `dang-lam` /
   `sep-da-tra-loi`) → `ghi --ma <mã> --noi-dung "Tắt máy: đã tới <bước>; còn <việc>; mở máy làm tiếp từ <bước>"`.
   Ghi TÌNH HÌNH ngắn, không chép nguyên văn.
4. **Ghi sổ** `.claude/sep-viec/SO-TAT-MAY.md` (ghi đè): giờ tắt · từng việc dở (mã thẻ, bước tiếp theo, tệp đang sửa,
   lệnh chạy tiếp) · thợ đã dừng + chỗ dừng · PID đã tắt · lời chủ chưa trả. `/momay` đọc đúng tệp này.
5. Báo xong: `clitell-tra --id <id lệnh> --chu "Đã cất N việc dở, dừng M thợ — tắt máy được. Mở máy gõ /momay."`
   (≤6 dòng, ≤600 ký tự). Bật lại con canh NỀN như thường (`canh`) — để `/momay` hoặc lời chủ vẫn tới được nếu chưa tắt.
