---
name: ui-ux
description: Kích hoạt khi làm, sửa hoặc soát giao diện web (nhất là web vận hành nội bộ dày thông tin) — màn, bảng, form, hộp thoại, cảnh báo, dashboard, bản điện thoại, trạng thái rỗng/lỗi/tải, nhãn nút, viết phiếu có phần UI, hỏi chủ nhà chọn phương án giao diện. Trigger vi: sửa giao diện, làm gọn màn, duyệt màn, soát UI, dày thông tin, ít bấm, cảnh báo, bảng, form, dashboard, điện thoại, nhãn tiếng Việt. Trigger en: UI, UX, layout, table, form, dialog, alert, banner, dashboard, responsive, empty state, design review, usability test.
---

# UI/UX — luật đúc từ 12 sách, dùng cho mọi dự án web

> Chưng cất 08/10/2026 từ một đợt đọc trọn 12 sách + đối chiếu skill UI UX Pro Max + soát 15 màn thật của một web vận hành. Bỏ hết tên riêng dự án; số đo giữ nguyên vì đã kiểm trên màn thật.
> **Token màu/chữ/khoảng cách của từng dự án nằm ở `docs/DESIGN.md` (SSOT)** — skill này nói *dùng thế nào*, không thay DESIGN.md. Bản điện thoại cảm giác native (safe area, chống zoom, bottom nav): skill `mobile-webapp`.

## Khi nào dùng
- Thêm/sửa màn, bảng, form, hộp thoại, badge, cảnh báo, dashboard, bản điện thoại.
- Viết phiếu Kỹ sư có phần UI, duyệt màn trước deploy, hỏi chủ nhà chọn A/B giao diện.
- KHÔNG dùng cho: trang bán hàng/landing, "chọn phong cách" màu/font theo ngành, đổi token DESIGN.md (đó là đổi hiến pháp → DECISIONS).

## 6 tư tưởng xương sống (nhớ 6 câu là đủ 80%)
1. **Người ngồi cả ngày → dày được nhưng có thứ bậc.** "Gọn" = không bắt tìm, KHÔNG phải ít dữ liệu, **cấm xoá trường**; việc hằng ngày ≤ 1 lần đổi trang.
2. **Đừng bắt người dùng nghĩ.** Tên trang = chữ vừa bấm, chữ khoá đứng đầu, cắt ≥ 50% chữ thừa, ≤ 6 lựa chọn thì bày thành chip.
3. **Máy gánh, người duyệt.** Điền sẵn, 1 gợi ý tốt nhất + lý do, Enter là áp.
4. **Trạng thái nằm trên đối tượng; không hỏi, không chặn.** Việc đảo được → làm ngay + Hoàn tác; việc chạm ra ngoài (gửi đối tác, nhắn tin, ghi sheet) → xem trước + hoãn 5 giây có Huỷ.
5. **Số có so sánh, nhấn 1–2 thứ.** Mọi KPI kèm delta/cùng kỳ; chỉ việc kẹt/trễ mới có màu; ≤ 2 mức cảnh báo.
6. **Nghiệm thu bằng nhìn người thật dùng.** 3 người ≤ 50 phút; thử phác thảo trước khi code màn khó; sửa nhỏ nhất trước, rối thì BỚT trước khi thêm.

## Quy trình khi nhận việc UI
1. **Viết bài toán bằng việc của người dùng** (không viết sẵn giải pháp) + định vị persona + kiểu màn (Bảng · Chi tiết · Form · Hàng chờ duyệt). Mở đúng nhóm luật ở `references/luat.md`.
2. **Đo TRƯỚC khi sửa** bằng script (Playwright boundingBox), không bằng mắt: px tới dòng dữ liệu đầu, số dòng thấy @1440×900, số nút đặc, phần tử < 24/44px, chữ < 11px, tràn ngang.
3. **Đổi bố cục → lập bảng "trường/nút cũ → chỗ mới"** đủ 100% + cột "thứ bị chìm".
4. **Màn đổi lớn → ≥ 2 phác thảo KHÁC HẲN bố cục**, mỗi cái trả lời đúng 1 câu hỏi; nghe người dùng kể ca thật ≥ 15 phút rồi mới cho xem.
5. **Thi công theo mẫu** `references/mau-dung.md`; chữ/màu/khoảng cách lấy từ DESIGN.md.
6. **Duyệt trước deploy** bằng `references/kiem-duyet.md`: chụp TRƯỚC/SAU 1440 + 390 (điện thoại kết luận bằng Safari iPhone thật), ghi số lên ảnh, khoanh đỏ, che dữ liệu cá nhân.

## Số đo bắt buộc (vi phạm = chưa đạt)
| Đo | Ngưỡng |
|---|---|
| Dòng dữ liệu đầu tính từ đỉnh | desktop ≤ 400px @1440×900 · điện thoại ≤ 600px @390 |
| Dải/thanh thường trực | ≤ 1 thanh, ≤ 40px desktop / 44px điện thoại; nội dung = chip `Tên · số` |
| Nút đặc / màn | 1 (hành động kế tiếp) |
| Mức cảnh báo thị giác / màn | ≤ 2 (đỏ gấp · hổ phách trong ngày); xám = thông tin |
| Chữ | ≥ 11px; thang 11·12·13·14·16·18·22; ≤ 4 cỡ/màn |
| Vùng chạm | điện thoại ≥ 44×44 cách ≥ 8px; desktop ≥ 24×24 (WCAG 2.5.8) |
| Khoảng cách | thang 4·8·12·16·24·32·48; ngoài nhóm ≥ 2× trong nhóm |
| Tương phản | chữ ≥ 4.5:1 cả sáng lẫn tối (đo bằng script) |
| Phản hồi | nút đổi trạng thái ≤ 100ms; kết quả/khung chờ ≤ 400ms; > 1s quay + tên bước; > 10s ước lượng + Huỷ |
| Dashboard | vừa 1 màn 1440×900 không cuộn; KPI nào cũng có ≥ 1 so sánh |
| Chữ mô tả đầu trang | ≤ 1 dòng ≤ 75 ký tự hoặc ⓘ; câu chào = 0 |

## Luật chủ nhà đã chốt (áp mọi dự án, chi tiết `references/quy-trinh-va-tin.md`)
- **Nhãn nút/chip MỚI viết tiếng Việt**; rê chuột → tooltip «tên tiếng Anh — 1 câu giải thích»; chỗ không rê được (điện thoại) → **ⓘ tròn ≥ 24px** cạnh nhãn, bấm ra cùng nội dung. Nhãn cũ/thuật ngữ ngành giữ.
- **Cảnh báo đỏ không đứng thành dải đầu trang**: gộp thành chip trong MỘT thanh thông báo (desktop ghim đáy; điện thoại chip dưới header).
- **Tin hỏi qua chat (Telegram…) KHÔNG nút bấm**: câu đánh số, lựa chọn mã `1A/1B`, người trả lời Reply gõ mã; mỗi câu 1 ảnh có nhãn.
- **Một luồng · hai cửa · MỘT trạng thái** (14C) cho việc hỏi–đáp qua chat: thẻ việc là nguồn sự thật, tin gốc là bản chiếu tự sửa theo thẻ, Reply và nút web ghi vào cùng một hàm.
- **Phiếu UI ba bước** (cả ba đều Opus Medium — Fable chỉ khi chủ nhà bảo, ghi dòng `ANH-CHO-FABLE:` vào brief): Kỹ sư viết → Thợ xây phản biện → Thợ xây thi công; câu cần chủ nhà chốt gửi **ảnh riêng, 1 ảnh/câu**, tạm chọn phương án đề xuất để không chặn thi công.

## Tham chiếu
- `references/luat.md` — bộ luật cuối 70 điều A1–I13 (bố cục · bảng · nút · phản hồi · form · số · điện thoại · chữ-màu · nghiệm thu), mỗi điều có cách kiểm + nguồn sách.
- `references/mau-dung.md` — mẫu dựng: khung trang, thẻ số, bảng + ô phải, chi tiết, form/hộp thoại, cảnh báo, rỗng/tải, dashboard, hàng chờ duyệt gợi ý máy, điện thoại.
- `references/kiem-duyet.md` — checklist trước deploy + 17 mục truy cập WCAG 2.2 + 7 câu Norman + ca ngồi xem người dùng (Krug).
- `references/sach.md` — 12 sách: mỗi cuốn đóng góp gì, đọc cuốn nào trước.
- `references/quy-trinh-va-tin.md` — phiếu UI 3 bước, khuôn câu hỏi gửi ảnh riêng chủ nhà, tin chat không nút + Reply mã, mẫu 14C, nhãn Việt/tooltip Anh/ⓘ.
