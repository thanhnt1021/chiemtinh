---
name: bot-nhan-viec
description: Kích hoạt khi dựng bot Telegram NHẬN VIỆC từ sếp / nhóm vận hành cho một dự án — mỗi việc có mã Task-ddmmyyyy-NN, sếp Reply tin bot là câu trả lời tự vào đúng việc, tin hỏi đánh số 1A/1B, máy tắt không mất tin, phiên Claude CLI mở ra tự thấy việc dồn. User thường nói "dựng bot nhận việc sếp", "nhóm giao việc qua Telegram", "bot nhận task kiểu ChicHub", "sếp nhắn nhóm là vào sổ việc", "con canh việc sếp", hoặc `sync uni` in khối «HỎI ANH: dự án này chưa có bot/nhóm nhận việc». Cũng dùng khi bot đã có mà Reply bị im / đẻ thẻ trùng / máy nhà tắt thì lỡ việc, hoặc sếp nhắn THOẠI mà thẻ ghi «[tin không có chữ]» (bot chưa nghe thoại), hoặc chủ nhà muốn «nhắn thẳng vào phiên Claude CLI đang chạy, khỏi tạo task» (lệnh /clitell), hoặc chủ nhà muốn «duyệt qua 1 lượt các task, cái nào làm được ngay / cần hỏi lại / gộp được, lên phương án gửi inbox riêng, tao OK hết mới làm» (lệnh /lam duyệt lượt), hoặc thêm/sửa một lệnh bot chạm phiên Claude CLI (/lamdi, /khac, /cho, /tatmay, /momay, /pause, /khoidong, /xoa) — mọi dự án phải giống nhau theo «Bộ lệnh chung» mục 7f, hoặc `sync uni` in «dự án X thiếu /…». Trigger en - task bot, boss task inbox, Telegram work queue, voice message transcription, message the running CLI session.
---

# Bot nhận việc sếp qua Telegram

> Chưng cất từ hai hệ đang chạy thật: bản đầy đủ (bảng việc trên web + nhóm vận hành nhiều người)
> và bản gọn (kho SQLite trên hosting PHP + CLI Python). Skill tự đủ: đọc xong là dựng được.
> Không có tên người, mã nhóm, khoá thật nào ở đây — chỉ TÊN biến và chỗ trống `<…>`.
> Cập nhật 15/10/2026: thêm mục 7f (BỘ LỆNH CHUNG chạm phiên Claude CLI — một bảng cho mọi dự án, trường `lenh_chung`
> trong tệp dấu, `sync uni` báo dự án thiếu lệnh); sửa 7d.1 (`/clitell` của chủ nhà trong nhóm chính cũng nhận).
> Cập nhật 12/10/2026 (lượt 3): thêm mục 7e (lệnh `/lam` = DUYỆT LƯỢT — máy rà mọi việc đang chờ, chia làm ngay / cần hỏi
> lại / gộp, gửi phương án vào chat riêng chủ nhà, chủ nhà OK hết mới làm; mọi dự án có bot nhận việc phải có).
> Cập nhật 12/10/2026 (lượt 2): thêm mục 7d (lệnh `/clitell` — chủ nhà nhắn thẳng phiên Claude CLI đang chạy, không đẻ thẻ;
> mọi dự án có bot nhận việc phải có).
> Cập nhật 12/10/2026: thêm mục 4b (tin thoại nghe ra chữ — mọi dự án có bot nhận việc phải có), 7c (nhắc lời chưa trả lời
> quá 15 phút + thẻ con canh trưởng vĩnh viễn).
> Cập nhật 09/10/2026: thêm luật 4.6 (`/viec` mọi nhóm), 4.9–4.12, 6.1 (`--nhom/--reply/--rieng`), mục 7 (cổng ghi thẻ, bỏ qua tin máy), 7b (máy nhà tắt, trợ lý AI).

## Khi nào dùng
- Dự án cần nơi sếp / người vận hành giao việc + trả lời câu hỏi cho phiên Claude, không lạc tin khi máy tắt.
- `sync-uni.sh check` in khối «⚠ HỎI ANH: dự án này chưa có bot/nhóm nhận việc» và anh chọn (a) dựng ngay.
- Bot đã có nhưng tin sếp trả lời hay bị lạc, không biết câu trả lời thuộc việc nào → áp lại luật ở mục 3–5.

Không dùng cho: bot bán hàng / chatbot khách (đó là bot sản phẩm), thêm lệnh vào menu bot (skill `bot-commands`).

## 1. Hình hệ thống (một chiều dữ liệu, không đường tắt)

```
Sếp nhắn / Reply / sửa tin / gõ /viec trong NHÓM
        │  Telegram đẩy update (webhook có secret, fail-closed)
        ▼
Máy chủ chạy 24/7: ghi MỌI tin vào kho trong MỘT giao dịch (hỏng → trả 500 để Telegram gửi lại)
   · Reply vào tin bot có mã → gắn việc · /viec → tạo việc · tin thường → chỉ lưu + cờ chưa đọc
        ▲  lối máy-máy (header token riêng, KHÁC secret webhook)
        │
Máy nhà: CLI  moi · da-doc · canh · gui · tao-viec · trang-thai · keo · anh
   · hook mở phiên: kéo sổ + in tin chưa đọc
   · con canh NỀN: có tin mới thì THOÁT → phiên Claude được gọi dậy
   · gửi tin cho sếp: CHỈ qua `gui` (máy chủ cấp/giữ mã + ghi tin vào kho)
```

Hai cách dựng máy chủ, cùng một hợp đồng (xem `references/hop-dong.md`):
- **Bản gọn** — hosting PHP/cPanel: `hook.php` + `api.php` + `lib.php` (ngoài `public_html`) + SQLite 2 bảng `tin`, `viec`.
- **Bản đầy đủ** — app web sẵn có (Next.js/Node + Postgres): route webhook + route `/api/<viec>` + bảng thẻ việc
  có cột trạng thái, nhãn, ảnh, dòng diễn biến; người vận hành xem/bấm trên web.

## 2. Mã việc
- Khuôn `Task-ddmmyyyy-NN`, ngày theo **giờ Việt Nam**, STT trong ngày từ `01` (quá 99 thì 3 chữ số). Regex `Task-\d{8}-\d{2,3}`.
- **Chỉ máy chủ cấp mã** (`MAX(stt)+1` trong ngày) — việc vào qua webhook lúc máy nhà tắt và việc máy nhà tạo không bao giờ trùng.
- **Việc của ngày trước GIỮ mã ngày cũ**: sếp báo 08/10, 09/10 mới xử → vẫn `Task-08102026-NN`. Hàm cấp mã lấy NGÀY từ
  `giao_luc` (lúc sếp giao), KHÔNG lấy `now()` — lỗi này đã xảy ra thật.
- Tin nào bot gửi sếp cũng mở đầu `[Task-…]`. Mã cũ khuôn khác thì CLI quy đổi, đừng bắt người gõ lại.

## 3. Trạng thái việc
Chọn một trong hai bộ, đừng trộn:

| Bộ gọn (5) | Bộ đầy đủ (8 cột bảng web) |
|---|---|
| `cho-xac-nhan` — sếp giao, chưa ai nhận | Mới giao |
| `cho-sep-tra-loi` — bot đã hỏi | Chờ Dev quyết · Chờ người dùng trả lời · Chờ người dùng thử |
| `sep-da-tra-loi` — **máy chủ tự đổi** khi sếp Reply | (Reply → thẻ tự về «Máy đang làm», nhãn «Có phản hồi mới») |
| `dang-lam` | Máy đang làm · Chờ Dev xác nhận |
| `xong` — chỉ tay | Đang chạy thử · Xong — **máy không tự vào**, trừ khi kèm nguyên văn câu Dev duyệt |

Luật chung:
- Cột «chờ người» LUÔN ghi tên người đang chờ; chờ nhiều người thì ai trả lời gạch tên người đó, đủ người mới chuyển cột.
- Mô tả việc đủ 4 mục, lời đời thường: **Chuyện gì · Cần gì · Đã làm tới đâu · Ai cần làm gì tiếp** (mục cuối khớp người ở đầu thẻ).
- Xong việc ghi **kết quả**: tóm tắt + cách tự kiểm + ảnh nghiệm thu (việc chạy ngầm thì con số chứng minh).
- Tin «chỉ cần biết» gửi xong → việc tự Xong; người nhận phản hồi tiếp thì việc tự mở lại.

## 4. Luật nhận tin (thứ tự trong webhook)
`lưu tin` → `nếu là bản sửa: đánh dấu sửa` → `trùng (Telegram gửi lại): bỏ` → `thử /viec` → `xử lý tin thường`.

1. **Reply vào tin bot có mã → gắn đúng việc.** Tra mã theo `message_id` tin được Reply trong kho; không có thì đọc mã
   trong chữ của tin đó. Đổi trạng thái chờ → đã trả lời; bot đáp «Đã nhận · Task-…» bằng Reply đúng tin.
2. **Reply có mã lựa chọn** (`1A 2B`) → ghi lượt chọn từng câu; **chữ ngoài mã = «Ý khác»** → ghi lên việc, hiện cạnh câu hỏi.
3. **Album ảnh** cùng `media_group_id` với tin đã gắn → gắn cùng việc, không đáp lại.
4. **Sửa tin đã gắn → chưa đọc lại**, giữ bản trước (`ban_truoc`) để CLI in `ĐÃ SỬA «cũ» → «mới»` (ca thật: «1A 2B» → «1A 2A»).
5. **Tin thường KHÔNG thành việc** (ca thật: «Quá vip r bạn» thành việc rác vì luật «≥15 ký tự là việc»). Chỉ lưu + cờ chưa
   đọc, bot im; Claude đọc rồi tự quyết, phải việc thì `tao-viec --ma <mã ngày gốc> --gan <message_id>`.
6. **`/viec` dùng được ở MỌI nhóm có bot, nhưng chỉ người trong danh sách gọi** (chủ nhà; bản gọn thêm sếp).
   Người khác gõ `/viec` → nuốt tin, bot im (đừng để lọt sang trợ lý AI). Không cần `@ten_bot`: bot tắt privacy nên đọc
   mọi tin nhóm (`/viec@bot_khac` thì bỏ). **`/viec` trần không treo**: bot gửi tin ForceReply (`selective`) «Gõ việc vào
   tin này», người gọi Reply (chữ + ảnh) → tạo thẻ. `/viec` Reply vào một tin = lấy chữ + ảnh/tệp của tin được Reply làm
   nội dung việc. Thẻ ghi nguồn «từ nhóm <tên>» + link tin lệnh. Chat riêng với chủ nhà: nhận như nhóm; người lạ chat
   riêng: bỏ, không lưu, không đáp. Nhận cả `/viec@ten_bot` và chú thích ảnh.
7. **Tin chủ nhà / Dev chỉ lưu**: không bật cờ chưa đọc, không đổi trạng thái, không «Đã nhận» (ngoại lệ: `/viec` của chủ nhà).
   Bản nhóm nhiều người: Reply của Dev trong nhóm = Dev nhắc người chờ, không tính là câu trả lời.
8. Tin của bot không bao giờ thành việc / chưa đọc.
9. **Ghi xong phải cho người gửi THẤY**: Reply tin việc ở BẤT KỲ chat nào (mọi nhóm có bot + chat riêng) → ghi lên thẻ
   → bot thả ✍ lên chính tin đó + Reply MỘT dòng «✍ Đã ghi vào thẻ <mã> · <link thẻ>». Ghi hỏng → Reply ngắn «Chưa ghi
   được vào thẻ — <lý do>», tuyệt đối không im (ca thật: người hỏi «sao nhắn mà bot không phản hồi, chỉ thấy react»).
   Reply mang mã lựa chọn (`1A 2B`) ghi được → thả ❤ (giữ ❤, không đè bằng ✍).
   **MỌI nhánh ghi thẻ đều phải thả** (ca thật 12/10: nhánh «Reply tin bot không mã» ghi thẻ + nhắn «Đã ghi» mà quên ✍ →
   chủ nhà hỏi «sao tin này không react»). Tin KHÔNG có chữ (sticker, thoại chưa nghe, ảnh trần) **không bao giờ tính là câu
   trả lời** của phiếu → ✍, không ❤ (ca thật: chữ thay «[tin không có chữ]» bị tính là trả lời câu 1 → ❤ nhầm). `/viec` tạo thẻ → ✍ lên tin lệnh +
   «✅ Đã lên thẻ <mã> · link»; Reply vào dòng đó vẫn ghi thêm vào thẻ.
   Muốn đọc cảm xúc người khác thả: bot phải là quản trị nhóm + webhook khai `message_reaction` (Telegram KHÔNG trả lại
   cảm xúc thả trước lúc bật).
10. **Tệp/ảnh gửi RỜI ngay sau tin việc tự gắn vào thẻ đó** — điện thoại không Reply kèm tệp được. Trong chat riêng chủ
   nhà: tệp tới trong vài phút sau tin việc → gắn thẻ vừa giao; chữ gõ ngay sau tệp = chú thích; gửi liền nhiều tệp gom
   MỘT dòng diễn biến; muốn tách thành việc khác thì Reply `/viec`. Thẻ phải tải lại được tệp đính kèm (CSV, PDF…), không
   chỉ ảnh.
11. **Reply vào tin máy KHÔNG gắn thẻ** (nhắc định kỳ, tổng kết, cảnh báo) trong nhóm vận hành: chữ có mã thẻ → vào thẻ đó;
   không có → gom về thẻ đang mở CÙNG LOẠI tin (Reply trước cùng loại, hoặc tên thẻ chứa từ khoá loại) — kể cả thẻ đã Xong
   trong ~14 ngày thì mở lại; chỉ khi không có mới tạo thẻ. Ca thật: mỗi ca nhắc tải CSV đẻ một thẻ mới thay vì gộp.
   Chỉ bật ở nhóm mà bot là người gửi chính; nhóm người ta bàn với nhau thì đừng tự đẻ thẻ.
12. **Bot đang ở nhóm có NGƯỜI NGOÀI** (xưởng, đối tác): nhóm đó nằm **danh sách riêng** tách khỏi nhóm nội bộ — không chạy
   lệnh bot, không vào sổ nội bộ; tin gửi vào bị lọc chữ tài chính nội bộ (lãi/lỗ, doanh thu, profit, số tiền) → chặn
   (`422`) chứ không gửi.

## 4b. Tin THOẠI — nghe ra chữ rồi đi đường như tin chữ (BẮT BUỘC mọi bot nhận việc)
Sếp / chủ nhà hay trả lời bằng thoại trên điện thoại. Bot không nghe → thẻ ghi «[tin không có chữ]», câu trả lời mất
(ca thật 12/10/2026: 6 thoại Reply vào 4 thẻ, cả 6 thành dòng trống). Luật:
1. **Nhận đủ 3 loại**: `message.voice` (ghi âm, `audio/ogg`), `message.audio` (tệp nhạc/ghi âm gửi dạng tệp), `message.video_note`
   (video tròn, `video/mp4`). Lấy `file_id` + `duration`; `getFile` → tải `https://api.telegram.org/file/bot<TOKEN>/<file_path>`.
   Telegram chỉ cho bot tải tệp **≤ 20 MB** — to hơn thì báo, đừng thử.
2. **Chuyển chữ bằng khoá ĐANG CÓ của dự án**, không tự đẻ khoá mới (thiếu thì hỏi chủ nhà ngay đầu việc). Đã đo trên
   thoại tiếng Việt thật (2–51 giây):
   - **Gemini** (`generateContent`, tệp kèm thẳng `inline_data` base64, `temperature: 0`) — `gemini-3.5-flash-lite` chép đúng
     nguyên văn, có dấu, 0,8–1,7 giây. Gói miễn phí có trần lượt/ngày/model → **xoay danh sách model** (hết lượt / 429 / lỗi →
     model sau) và đếm lượt CHUNG sổ với việc AI khác của dự án.
   - **Cloudflare Workers AI** (`@cf/openai/whisper*`) — được, dùng **khoá Cloudflare chung `~/.claude/cloudflare-deploy.env`** (có quyền Workers AI, xem skill `new-site`) TRƯỚC khoá riêng dự án; token phải có quyền *Workers AI*; token DNS/Zone thường
     trả «Authentication error». Proxy OpenAI-compatible (skill `cheapkeyai`) dùng được nếu proxy có model âm thanh.
   - Lời nhắc chép: «Chép NGUYÊN VĂN lời nói (chủ yếu tiếng Việt, có thể lẫn tiếng Anh, mã đơn, mã thẻ, mã lựa chọn kiểu 1A 2B).
     Có dấu, thêm dấu câu. Không giải thích, không tóm tắt. Không nghe ra lời nào thì trả chuỗi rỗng.» Bỏ phần `thought` nếu model trả.
3. **Chữ nghe được THAY chữ của tin**: `text = «🎤 (thoại 0:14) <lời>»` (+ xuống dòng + chú thích nếu tin có `caption`), rồi cho
   tin đi **lại từ đầu đúng thứ tự luật mục 4** — Reply vào thẻ, mã lựa chọn `1A 2B` trong lời, `/viec`, tệp rời, chat riêng.
   Không viết nhánh riêng cho thoại: nhánh riêng là chỗ luật mới của tin chữ quên áp sang.
4. **Không bao giờ im**: nghe hỏng (hết lượt, tệp quá to, tải lỗi, nghe ra rỗng) → chữ của tin thành
   «🎤 (thoại 0:14) thoại chưa nghe được — <lý do lời thường>» (vẫn đi đường cũ để thẻ có dấu), VÀ nhắn người gửi (chat riêng)
   + chủ nhà một dòng xin gõ lại bằng chữ.
5. **Nghe tốn 2–10 giây → trả Telegram `200` NGAY**, nghe + xử lý chạy nền (Next.js `after`, PHP `fastcgi_finish_request()`,
   worker hàng đợi). Webhook trả chậm thì Telegram gửi lại → nghe hai lần, ghi hai dòng. Chạy lại đường xử lý bằng cách tự
   gọi lại webhook kèm secret + một dấu riêng (vd header `x-<du-an>-thoai-da-nghe: 1`) → lượt sau bỏ các bước đã làm ở lượt
   đầu (chép tin sang hộp thư, đếm tin…) để khỏi chạy hai lần.
6. **Chỉ nghe nơi có việc**: chat riêng với bot, Reply vào tin bot, kênh giao việc của chủ nhà. Thoại vu vơ trong nhóm người
   ta bàn nhau → chỉ lưu như cũ, không tốn lượt AI.
7. **Lưu `file_id` của mọi tin có tệp** (kể cả thoại) vào kho tin — nghe hỏng còn nghe lại được. Lỡ không lưu: bot vẫn lấy lại
   được tệp nếu biết `message_id` — `forwardMessage` (im lặng, `disable_notification`) vào chính chat đó → bản chuyển tiếp
   trả về `voice.file_id` → `deleteMessage` ngay bản chuyển tiếp. Mã tin thoại = `message_id` tin Reply đã ghi trên thẻ.
8. Ca thử: ca 17–19 ở `references/ca-thu.md`. Mẫu PHP bản gọn: `references/mau-tep.md` §7.

## 5. Khuôn tin gửi sếp / nhóm (máy chủ đo, thiếu là chặn)
- Dòng đầu `[Task-…] tiêu đề` (≤70 ký tự, **in đậm** bằng `parse_mode: HTML`, tự `html.escape` phần chữ người viết).
- Thân **≤6 dòng, ≤600 ký tự, ≤1 link, ≤3 ảnh**. Dài hơn → ghi chi tiết lên việc, tin chỉ là mục lục + link việc.
- Lời đời thường: **cấm** đường dẫn tệp, tên hàm, mã commit, tên bảng, thuật ngữ («webhook, deploy, API»). Gọi đơn/việc bằng mã.
- Nhắc tên ai thì **in đậm** tên đó. Máy tự xưng «Trợ lý hệ thống», **cấm nhập vai người thật**.
- **Tin hỏi**: câu đánh số `1.` `2.`, mỗi lựa chọn mang mã `1A · 1B`; mỗi ảnh có **chữ in trên ảnh** (`--nhan-anh "1A · bản trước"`).
  Dòng cuối: «👉 Reply tin này, gõ mã lựa chọn (vd 1A 2B) hoặc nói thêm». **Không dùng nút bấm** — Dev đã chốt bỏ hẳn nút
  (08/10/2026), mọi câu trả lời đi bằng Reply gõ mã.
- **Tin «chỉ cần biết»**: vẫn xin xác nhận — «👉 **<tên>** Reply 1A = Đã đọc» (dòng này tính vào trần).
- Tin hỏi Dev / chủ nhà khi họ vắng → nhắn **riêng** (`<CHU_NHA_ID>`), không hỏi trong nhóm sếp.
- Trước khi gửi thật: `gui --thu` (in + đo, không gửi). Đọc lại tin mới nhất của người nhận — họ có thể vừa trả lời.

Mẫu (HTML):
```html
<b>[Task-08102026-04] Nghiệm thu chatbot bán hàng</b>

✅ Đã xong: đạt 48/50 yêu cầu, thử như khách thật trên iPhone và Android.
📎 Xem: 3 ảnh phía trên

<b>Sếp chọn giúp em:</b>
1. Duyệt nghiệm thu?  <b>1A</b> Duyệt · <b>1B</b> Cần sửa
2. Làm tiếp phần sau?  <b>2A</b> Làm luôn · <b>2B</b> Đợi sếp thử

👉 Sếp reply tin này, ví dụ: 1A 2A
```

## 6. Luật cứng «không mất việc»
1. Mọi tin máy gửi vào nhóm / chat riêng **chỉ qua MỘT lệnh CLI** (`gui`, bản đầy đủ là `tin`): máy chủ cấp/giữ mã +
   ghi tin bot vào kho kèm mã thẻ để Reply vào là vào ĐÚNG thẻ. Tin gửi ngoài lối này mà sếp Reply = Reply vào tin
   không mã = tin thường → **mất khỏi sổ việc** (ca thật: gói nghiệm thu gửi bằng `sendMessage` thẳng). Lệnh đó phải có:
   - `--nhom <id>` gửi vào nhóm KHÁC nhóm chính (chỉ nhóm trong danh sách nội bộ / danh sách người ngoài ở luật 12);
   - `--reply <message_id>` trả lời nối vào tin người hỏi (ca thật: tin gửi tay thiếu mã, ảnh, khuôn);
   - `--rieng` gửi chat riêng chủ nhà thành MỘT tin đầy đủ đúng khuôn tin việc (tiêu đề `[Task-…]` đậm, ảnh kèm nhãn,
     Reply vào là vào thẻ) — không nối dòng vào tin gom rồi để ảnh trôi rời (ca thật: thợ phải curl tay, chữ thô).
2. **Cấm gọi thẳng** `sendMessage/sendPhoto/sendMediaGroup/sendDocument` vào nhóm sếp. Ảnh/PDF lỡ gửi riêng thì caption ghi mã.
3. **Cổng tất định** PreToolUse(Bash) chặn lệnh có `send(Message|Photo|MediaGroup|Document)` + (`api.telegram.org` hoặc
   biến nhóm) mà không qua CLI / không có mã — mẫu ở `references/mau-tep.md`. Cổng chỉ soi chữ lệnh: script tự viết gọi
   Telegram bên trong vẫn lọt → luật 1 vẫn phải giữ.
4. Tin sếp chưa gắn việc mà đúng là việc → gắn bằng `tao-viec --ma <mã ngày gốc> --tin-goc <id> --gan <message_id>`.
5. `da-doc` CHỈ id đã xử lý xong, nêu đích danh — **không có «đánh dấu hết»**. `xoa` cũng nêu đích danh, cấm theo dải.
6. Không `drop_pending_updates`, không dùng `getUpdates` làm cơ chế chính (Telegram chỉ giữ 24 giờ, đụng 409 khi có webhook).
7. Khoá (`TG_BOT_TOKEN`, secret webhook, token lối máy) chỉ ở `.env`; kho + cấu hình nằm NGOÀI thư mục web công khai.

## 7. Phiên Claude CLI
- **Hook SessionStart** (`mo-phien`): `keo` + `moi`, in ≤6 dòng, nhắc bật con canh. Luôn `exit 0`.
- **Hook UserPromptSubmit**: câu chứa «check viec sep» (hoặc lệnh tương đương của dự án) → chèn quy trình + `moi`;
  câu khác chỉ đọc tệp trạng thái con canh (không gọi mạng), có id mới thì nhắc 1 lần mỗi bộ id.
- **Con canh** chạy NỀN (`run_in_background`, timeout 7200000): 60 giây/lượt, có tin chưa đọc mới thì in 1 dòng rồi THOÁT
  → phiên được gọi dậy; hết `--phut 110` thì thoát 0. Mỗi máy một con (tệp pid). **Xử lý xong PHẢI bật lại** — quên bật là lỡ việc.
- Quy trình xử lý (`.claude/commands/check-viec-sep.md`): `moi` → mở ảnh bằng Read → từng mục: việc mới / câu trả lời /
  tin sửa → `da-doc --id …` đúng mục đã xử → thả ❤ → bật lại canh → ghi «xong gì» vào sổ tiếp tục của dự án.
- **Bỏ qua ghi chú do chính máy viết**: con canh / `moi` không coi dòng «Cập nhật / Tình hình…» do máy tự ghi lên thẻ là
  tin chưa đọc (tự gắn đã-đọc). Phân biệt bằng nguồn: người thật luôn mang tên người; máy viết hộ phải mang cờ máy.
  Ca thật: con canh tự thoát 4 lần/giờ vì chính ghi chú của mình.
- Hook đọc lời chủ (thả ❤, cổng ghi thẻ) **bỏ qua lượt là thông báo máy** (`<task-notification>`, `[SYSTEM NOTIFICATION`,
  báo cáo thợ trích mã thẻ + «1A») — chỉ xét chữ chủ tự gõ, không thì cổng đòi ghi lại việc thợ đã ghi.
- **Quyết định chủ đưa ngay trong CLI phải ghi thẻ** — cổng tất định 3 chế độ (một tệp): UserPromptSubmit thấy mã thẻ +
  lời quyết («1A», «ừ», «chốt», «bỏ», «làm đi») → lưu mốc; Stop: từ mốc đó chưa chạy `ghi|chuyen --ma <đúng mã>` → CHẶN
  kết lượt (tối đa 3 lần/lượt, cửa thoát `khong-can-ghi-the: <lý do>`); PreToolUse(Bash): nội dung ghi có dấu chép
  nguyên văn → chỉ nhắc «ghi TÌNH HÌNH ngắn, đừng chép nguyên văn». Fail-open. Mẫu ở `references/mau-tep.md`.
- Gắn hook vào `.claude/settings.local.json` của dự án (CỘNG thêm, không ghi đè `permissions`), dùng `$CLAUDE_PROJECT_DIR`.

## 7b. Máy chủ nhân tắt — bot vẫn nhận việc, vẫn trả lời
- **Webhook nằm trên máy chủ 24/7, không nằm trên máy nhà** → máy nhà tắt, CLI không mở vẫn ghi đủ việc/Reply vào thẻ;
  mở máy là con canh kéo về. Đừng dựng bot kiểu long-polling trên máy nhà.
- **Con canh tự THOÁT khi có cập nhật** (để gọi phiên dậy) → xử lý xong PHẢI bật lại; quên bật = lỡ việc tới lần mở phiên sau.
- **Nhịp tim**: mọi lệnh CLI (con canh hỏi mỗi phút) gửi kèm header nhịp tim (vd `x-nhip-tim`); máy chủ ghi mốc cuối vào
  kho (một dòng, không cần bảng mới — webhook và lối máy có thể là hai tiến trình nên không giữ trong RAM được). Quá ~15
  phút không có nhịp = máy nhà tắt. Có biến ép tắt (`<TEN>_NHIP_TIM=tat`) để chạy ca thử.
- **Máy tắt + có người giục** (Reply tin việc, hoặc tag bot kèm mã thẻ): vẫn ghi thẻ như thường, nhưng dòng «Đã ghi vào
  thẻ» được THAY bằng câu mặc định «Hệ thống đang chạy nhiều việc nên việc này chưa xong, sẽ phản hồi khi xong.» — mỗi
  thẻ tối đa 1 lần / ~30 phút để người giục liên tục không bị lặp. `/viec` lúc máy tắt thêm «máy đang tắt, mở máy sẽ chạy».
- **Trợ lý AI trên máy chủ** (nếu dự án có, trả lời khi tag bot): **NÊN LÀM — đang triển khai ở bản gốc, chưa chốt**:
  trợ lý KHÔNG trả lời Reply vào tin việc (đó là câu trả lời cho thẻ, đã có dòng «Đã ghi vào thẻ»), và nếu trả lời thì
  ngắn. Bản gốc hiện còn: Reply tin việc có tag bot thì trợ lý vẫn trả lời; lúc máy tắt thì trợ lý im, chỉ câu mặc định.
  Thứ tự trong webhook: luồng thẻ việc (tin gom → `/viec` → tệp rời → câu mặc định máy tắt) chạy TRƯỚC trợ lý; trợ lý chỉ
  nhận tin mà luồng thẻ không nhận.

## 7c. Nhắc lời chưa trả lời + thẻ con canh trưởng (mọi dự án — chủ nhà chốt 12/10/2026)
- **Lượt quét định kỳ trên máy chủ**: lời người (sếp / chủ nhà / người vận hành) trên thẻ chưa Xong mà **quá 15 phút** máy
  chưa gửi tin nào sau nó, chưa ai đánh dấu đã đọc → MỘT tin riêng chủ nhà liệt kê các thẻ đó + link thẻ
  («Trợ lý hệ thống: N lời chưa được trả lời quá 15 phút»). Mỗi lời nhắc tối đa MỘT lần (giành lượt bằng UPDATE có điều kiện
  trên mốc «đã nhắc» của chính dòng lời đó). Ngưỡng là một hằng số có tên, đổi một chỗ; bản gốc đã đổi 10 → 15 phút.
- **Thẻ con canh trưởng**: một thẻ hệ thống **vĩnh viễn, không bao giờ đóng** (lệnh chuyển cột chặn cột Xong), là sổ cho mọi
  tin tổng hợp / cảnh báo của máy (tin nhắc ở trên, cảnh báo quá hạn…). Reply vào các tin đó → ghi vào thẻ này (không vào thẻ
  đầu tiên được nhắc trong tin — lỗi đã xảy ra thật). Tìm thẻ theo NGUỒN hệ thống (cột nguồn riêng), đừng ghi cứng mã thẻ
  trong mã; mã thẻ không mang ngày vì thẻ sống mãi.

## 7d. Lệnh `/clitell` — chủ nhà nhắn THẲNG phiên Claude CLI đang chạy (BẮT BUỘC mọi bot nhận việc)
Chủ nhà chốt 12/10/2026: «tao chỉ nhắn tin vào claude cli của session đang chạy… thay vì mỗi lần muốn nói gì lại phải tạo
task». Lời này là lời chủ gõ trong cửa sổ CLI, chỉ khác là gõ từ điện thoại — KHÔNG phải việc, KHÔNG đẻ thẻ.
1. **Ai / ở đâu**: chỉ CHỦ NHÀ — trong chat riêng với bot **VÀ trong nhóm chính** của dự án (nhóm giao việc nội bộ; nhóm có
   chủ đề thì chủ đề giao việc của chủ nhà). Ca thật 15/10/2026: hai bot chỉ nhận chat riêng, chủ nhà gõ `/clitell` trong nhóm →
   bot nuốt im, chủ nhà tưởng phiên đã nhận. Người KHÁC gõ `/clitell` trong nhóm → nuốt tin (không ghi lời, không lọt sang trợ lý AI
   hay luồng thẻ) nhưng bot **Reply MỘT dòng** «Lệnh /clitell chỉ <chủ nhà> dùng — lời này không chuyển vào phiên CLI», **cấm im**.
   Người lạ chat riêng vẫn theo luật 4.6 (bỏ, không đáp). Reply vào tin bot luồng này của người khác không phải lời CLI → để luồng
   sau xử như cũ. Nhận cả `/clitell@ten_bot` và chú thích ảnh.
2. **Ba cách gõ**: `/clitell <lời>` · Reply MỘT tin bất kỳ bằng `/clitell` (chữ tin được Reply đi kèm làm ngữ cảnh) · Reply tiếp
   vào tin bot CỦA LUỒNG NÀY (dòng xác nhận / lời CLI trả) không cần gõ lệnh = lời mới. Nhận ra tin bot của luồng bằng DẤU ĐẦU TIN
   cố định (vd `📨 CLI ·` và `🤖 Phiên CLI:`), soát dấu trước rồi mới tra kho — tin Reply thường không tốn lượt đọc kho.
   `/clitell` trần, không Reply → bot chỉ dẫn cách gõ, không ghi. Thoại Reply vào tin luồng này → nghe ra chữ (mục 4b) rồi đi như chữ.
3. **Thứ tự trong webhook**: `/clitell` đứng TRƯỚC mọi luồng thẻ việc (cả bước ghi quan hệ Reply) — Reply một tin việc bằng
   `/clitell` là nói với CLI, không phải trả lời thẻ. Cổng riêng chủ nhà nên không phụ thuộc công tắc «bot im trong nhóm».
4. **Kho**: một dòng mỗi lời, cờ «CLI đã nhận» rỗng = chưa nhận; ghi `chat`, `message_id` tin của chủ, mảng mã tin bot của lượt
   (để Reply tiếp tra ngược). Không cần bảng mới nếu dự án có sẵn bảng nhật ký dạng JSON (bản gốc dùng `sync_log` cùng chỗ nhịp
   tim); bản gọn SQLite thêm bảng `clitell(id, chu, chat_id, message_id, bot_tin, tao_luc, nhan_luc)`.
5. **Bot trả chủ MỘT dòng ngay**: con canh hỏi lối máy có gửi kèm dấu «đang nghe» (vd header `x-canh: 1`) → máy chủ ghi mốc;
   mốc ≤ 2 phút → «📨 CLI · Đã chuyển vào phiên Claude CLI đang chạy…»; không → «…chưa có phiên nào đang nghe — tin đã lưu, sẽ được
   đọc khi mở phiên». Đừng dùng nhịp tim chung (mọi lệnh CLI đều gửi) — nó không nói được con canh có đang chạy không.
6. **Con canh / `moi`**: lời chưa nhận in TRƯỚC hàng thẻ, mục riêng «📨 LỜI CHỦ GỬI THẲNG VÀO CLI — coi như chủ gõ trong cửa sổ
   này», nguyên văn từng dòng; con canh THOÁT ngay (phiên được gọi dậy) rồi báo lối máy `da-nhan` đúng id → máy chủ gắn cờ + thả 👀
   lên tin của chủ (chủ biết CLI đã đọc). Báo hỏng thì lần hỏi sau in lại — không mất lời. Lối máy lời CLI hỏng (máy chủ cũ) → coi
   như rỗng, hàng thẻ vẫn chạy.
7. **Trả lời chủ**: lệnh CLI riêng (bản gốc `clitell-tra --id <id> --chu "…"`) — Reply đúng tin của chủ, dấu `🤖 Phiên CLI:`,
   trần ≤ 6 dòng / ≤ 600 ký tự (máy chủ chặn `422`); chủ Reply vào đó là lời mới (cách 3). Việc cần làm dài → tạo thẻ như thường rồi báo
   bằng lệnh `tin`. Đây là lối gửi thứ hai được phép ngoài `tin` (luật 6.1) vì nó ghi mã tin bot vào kho y như `tin`.
8. **Menu «/»**: khai `/clitell` vào scope chat riêng chủ nhà (skill `bot-commands`), không hiện ở scope mặc định.
9. Ca thử 20–23 ở `references/ca-thu.md`. Thử thật xong ghi dấu: `sync-uni.sh bot-nhan-viec clitell-da-co`.

## 7e. Lệnh `/lam` = DUYỆT LƯỢT — máy rà việc đang chờ, chủ nhà OK hết mới làm (BẮT BUỘC mọi bot nhận việc)
Chủ nhà chốt 12/10/2026: «khi chạy cái này, sẽ duyệt qua 1 lượt các task … task nào dễ hiểu ready to do rồi, task nào chưa dễ
hiểu thì cần hỏi lại sếp hoặc tao, và những task nào có thể gộp. lên 1 phương án dự kiến rồi đưa vào inbox riêng cho tao …
khi nào tao oke hết rồi thì mới làm». Áp cho dự án có luồng «sếp chỉ giao input thô, chủ nhà bảo làm mới làm» (việc chờ chủ nhà
cho làm: trạng thái ghi nhận / nhãn «Làm sau»). Bản gốc: Nhà thuốc (bản gọn PHP/SQLite) — mẫu ở `references/duyet-luot.md`.
1. **Ai / ở đâu**: chỉ CHỦ NHÀ gõ `/lam` TRẦN (không mã, không Reply) — trong nhóm hay chat riêng. Người khác gõ → lưu, im.
   `/lam <mã>` · `/lam tatca` · Reply `/lam` vào câu ghi nhận GIỮ lối tắt chạy thẳng như cũ (bản đầy đủ: `/khoidong`).
2. **Máy chủ không phân loại** (cần hiểu chữ; bot không tăng phí AI): chỉ mở lượt `DLn` trạng thái `cho-may`, đáp ngay MỘT dòng
   «⏳ Đang duyệt lượt DLn — N việc đang chờ, phương án gửi chat riêng anh trong vài phút». Máy nhà tắt (nhịp tim cũ) → «📝 Đã ghi
   yêu cầu duyệt lượt — mở máy là duyệt, không mất» (trong nhóm có sếp: chỉ nói «hệ thống đang nhiều việc», không nói «máy tắt»).
   Không có việc chờ → «Không có việc nào đang chờ duyệt», không mở lượt. Đang có lượt mở → báo tình trạng lượt đó, không mở lượt thứ hai.
3. **Gọi phiên dậy**: lối máy `chua-doc` trả thêm `duyet_luot` (lượt ở `cho-may` · `gop-y` · `da-ok` · `dang-ap`) → con canh
   THOÁT, in «📋 DUYỆT LƯỢT DLn (<trạng thái>): <việc cần làm>»; báo lại khi trạng thái đổi hoặc quá `--nhac-phut` y nguyên.
   `moi` in dòng đó trên cùng.
4. **Phiên Claude xếp việc**: `duyet-luot` gom việc đang chờ (nội dung, tin góp ý, diễn biến, bản trước, góp ý mới nhất) +
   việc đang mở khác (đích gộp) ra JSON → phiên tự xếp MỖI việc đang chờ vào ĐÚNG MỘT nhóm: `lam` (rõ đầu vào + kết quả, kèm một
   dòng dự kiến) · `hoi` (`ai`: sếp — câu nội dung/kinh doanh; chủ nhà — câu hệ thống/kỹ thuật; câu đúng khuôn «1. …? 1A … · 1B …»)
   · `gop` (`chinh` + `phu[]` + vì sao; việc chính là việc chờ đã xếp làm/hỏi/để sau, hoặc việc đang mở khác) · `bo` / `de_sau`
   (CHỈ khi chủ nhà góp ý bảo thế).
5. **Gửi phương án** (`phuong-an --tep pa.json [--thu]`): máy chủ SOÁT tất định — mọi việc đang chờ có mặt đúng một lần, `ai`
   hợp lệ, câu hỏi đúng khuôn, việc chính hợp lệ — thiếu là từ chối, không gửi. CLI đo khuôn từng câu hỏi trước (khuôn tin mục 5)
   để chủ nhà OK xong không vỡ lúc áp. Tin = MỘT tin ẢNH vào chat RIÊNG chủ nhà: ảnh bảng «STT · Mã · Việc · Dự kiến / câu hỏi /
   gộp vào» chia khối theo nhóm (hàng tiêu đề màu nhóm), album ≤ 3 ảnh khi bảng dài; chú thích ≤ 1024 ký tự «📋 [DLn] Duyệt lượt ·
   bản b · N việc» + một dòng mỗi nhóm (mã, dài quá thì STT khớp ảnh) + «👉 Cần làm: **<chủ nhà>** — Reply tin này: gõ OK = duyệt hết ·
   hoặc góp ý từng mục». Tin bot ghi vào bảng tin phương án (chỉ Reply lên ĐÚNG tin này mới là duyệt — học thẻ duyệt C-HX L19).
6. **Chủ nhà Reply tin phương án**: CẢ tin chỉ là lời đồng ý (ok · oke · okay · duyệt · đồng ý · chốt · làm đi, kèm «hết» được)
   → `da-ok`; chữ khác (kể cả «ok nhưng 02 bỏ») = góp ý → `gop-y`, lưu nguyên văn, bot đáp «📝 Đã ghi góp ý — máy gửi bản b+1».
   Mỗi lần gửi là bản mới (`ban` +1, lịch sử bản + góp ý giữ trong lượt). Reply bản CŨ → nhắc Reply bản mới nhất, không đổi gì.
7. **Áp sau OK** (`ap-phuong-an`, máy chủ từ chối khi lượt chưa `da-ok`): máy chủ trong MỘT giao dịch: gộp (cách gộp thẻ Fulfill:
   mọi tin của việc phụ dời sang việc chính → Reply tin cũ tự vào việc chính; câu đáp / thẻ / mã phụ trỏ việc phụ cũng đổi; việc phụ
   sang «đã chuyển» kèm `chuyen_sang`; diễn biến hai bên ghi «Gộp … vào đây» + nguyên văn) → khởi động nhóm `lam` (đúng hàm khởi
   động có sẵn) → bỏ (việc đang chờ → huỷ; việc đang làm chỉ bỏ phần góp ý chờ) / để sau (ghi diễn biến) → lượt `dang-ap`. CLI gửi từng
   câu hỏi qua lối gửi DUY NHẤT (`gui`/`tin`, khuôn mục 5): hỏi sếp → NHÓM, Reply tin gốc; hỏi chủ nhà → chat riêng có ảnh bảng việc
   (máy chủ chỉ mở lối riêng cho việc nhóm khi câu nằm trong lượt đang áp). Gửi xong từng câu ghi lại (`ap-hoi`) — chạy lại không
   gửi trùng. Cuối cùng `ap-xong`: lượt `da-ap` + MỘT tin «✅ Đã làm theo phương án DLn» vào chat riêng (Reply tin phương án). Việc
   được hỏi vẫn chờ chủ nhà cho làm — hỏi không phải cho làm.
8. **Bảng mới** tạo theo `sqlite_master` (không tăng `user_version`) — thợ khác chạy song song cũng tăng số thì không giẫm nhau.
   Thợ (subagent) bị cổng chặn `phuong-an` / `ap-phuong-an` thật (chỉ `--thu` / kho thử). Lệnh hướng dẫn phiên: thêm mục «Duyệt lượt»
   vào `.claude/commands/check-viec-sep.md` (theo trạng thái lượt: cho-may/gop-y → duyet-luot + phuong-an · cho-chu-nha → chờ ·
   da-ok/dang-ap → ap-phuong-an rồi làm việc vừa khởi động).
9. Menu «/»: mô tả `/lam` = «Duyệt lượt việc đang chờ (/lam) · cho làm thẳng (/lam <mã> · /lam tatca)», scope chủ nhà. Ca thử 24–31
   ở `references/ca-thu.md`.

## 7f. BỘ LỆNH CHUNG chạm phiên Claude CLI (BẮT BUỘC mọi bot nhận việc — chủ nhà chốt 15/10/2026)
Chủ nhà 15/10/2026: «đồng bộ hết các task mà giao tiếp với Claude cli cho tất cả các dự án và các bot … mặc định rule sau này là
lệnh gì tương tác với claude cli đều đồng bộ hết». Bảng dưới tả đúng bản đang chạy ở bản gốc đầy đủ (Next.js + Postgres); chỗ
`<…>` mỗi dự án tự thay (bảng thẻ, máy chủ chạy lịch, tên chủ nhà, giờ lịch). Bản gọn PHP/SQLite: cùng hành vi, khác kho.
> ⛔ **Luật đồng bộ**: một dự án thêm / đổi lệnh chạm phiên CLI → CÙNG LƯỢT sửa bảng này ở SSOT + trường `lenh_chung` tệp dấu
> của dự án đó + nhắn phiên các dự án đã cài bot (đường `/clitell` / tin của dự án đó) làm theo — không chờ `sync uni` lần sau.

Bốn đường đi (cột «Đường»):
- **CLITELL** — một dòng kho lời CLI (mục 7d.4) → con canh thoát → phiên đọc «coi như chủ gõ trong cửa sổ này». Loại lời ghi trong
  dòng: `loi` (chủ gõ) · `tong-hop` (bản gom sổ dồn) · `lenh_may` (`tatmay` / `momay`).
- **CỜ** — một dòng trạng thái trong kho (như nhịp tim) mà con canh + lịch máy chủ đọc; không đánh thức phiên trực tiếp.
- **THẺ** — tạo / ghi / huỷ thẻ việc; con canh thấy mục chưa đọc thì đánh thức phiên như mọi lời trên thẻ.
- **MÁY CHỦ TRẢ** — máy chủ tự đọc kho rồi trả lời, không cần phiên; chủ Reply tin trả lời = lời vào đúng thẻ (đường THẺ).

| Lệnh | Mô tả menu «/» (dán nguyên, thay `<…>`) | Ai | Ở đâu | Đường | Phiên cần tệp lệnh |
|---|---|---|---|---|---|
| `/viec` | Giao việc mới, máy tạo thẻ | chủ nhà (+ danh sách luật 4.6) | mọi nhóm có bot + chat riêng chủ nhà | THẺ (luật 4.6). **Tối thượng**: tin mở đầu `/viec` luôn tạo thẻ, kể cả Reply vào tin CLI / tin gom / tin phương án | `check-viec-sep.md` (việc mới) |
| `/clitell` | Nhắn thẳng phiên Claude trên <máy nhà>, không tạo thẻ | chủ nhà | chat riêng + nhóm chính | CLITELL `loi` (mục 7d); Reply tin bot luồng này = lời mới; Reply bằng lệnh `/…` khác = gọi lệnh đó | `check-viec-sep.md` + CLI `clitell-tra` |
| `/lam` | Duyệt lượt việc đang chờ (/lam) · cho làm thẳng (/lam <mã> · /lam tatca) | chủ nhà | chat riêng + nhóm chính | CỜ lượt `DLn` (mục 7e) — `chua-doc` trả `duyet_luot` làm con canh thoát; `/lam <mã>` · `/lam tatca` · Reply `/lam` = máy chủ khởi động thẳng | `check-viec-sep.md` mục «Duyệt lượt» |
| `/lamdi` | Đẩy mọi trao đổi chưa làm trên các thẻ vào phiên Claude + gửi <chủ nhà> mỗi thẻ một tin | chủ nhà | chat riêng + nhóm chính | gỡ CỜ `/pause` → CLITELL `tong-hop` (sổ dồn = mọi lời người chưa mang cờ đã-đọc; chỉ ghi khi con canh đang nghe, bản cũ chưa nhận thì thay) → máy chủ gửi mỗi thẻ một tin. Lịch `<máy chủ>` gom cùng đường `<giờ>`/ngày, bỏ lượt khi `/pause` · sổ trống · CLI không nghe · còn bản chưa nhận | `check-viec-sep.md` mục «Sổ dồn»: chạy `moi` lấy id rồi xử TỪNG mục |
| `/khac` | Việc chưa xong đang chờ người khác — <chủ nhà> ngó và quyết hộ | chủ nhà | chat riêng + nhóm chính | MÁY CHỦ TRẢ một tin tóm + mỗi thẻ một tin (trần/lượt, gõ lại gửi tiếp); chủ Reply «#3 <lời>» vào tin tóm hoặc Reply tin thẻ → THẺ (ghi như lời chủ, ✍ + «Đã ghi vào thẻ») | không (đi đường mục chưa đọc) |
| `/cho` | Ảnh việc đang chờ: chờ <chủ nhà>, chờ người khác, chờ dùng thử | chủ nhà | chỉ chat riêng | MÁY CHỦ TRẢ mỗi thẻ đang chờ một tin, ba nhóm (chờ chủ nhà quyết/xác nhận · chờ người khác trả lời · chờ dùng thử); bỏ thẻ máy đang làm | không |
| `/tatmay` | Sắp tắt máy: phiên Claude cất hết việc dở, dừng thợ | chủ nhà | chat riêng + nhóm chính | CLITELL `lenh_may` với chữ «/tatmay — làm đúng `.claude/commands/tatmay.md`». **Con canh không nghe → KHÔNG lưu chờ**, bot báo «chưa chuyển» (một `/tatmay` cũ đọc lúc mở máy hôm sau sẽ dừng thợ sai lúc) | `.claude/commands/tatmay.md` |
| `/momay` | Vừa mở máy: phiên Claude đọc sổ, chạy tiếp việc dở | chủ nhà | chat riêng + nhóm chính | như `/tatmay` (không lưu chờ) | `.claude/commands/momay.md` |
| `/pause` | Tạm dừng máy tự làm việc tới /khoidong hoặc <giờ sáng> | chủ nhà | chat riêng + nhóm chính | CỜ tạm dừng: con canh vẫn hỏi (không tốn token) nhưng KHÔNG thoát, lịch gom bỏ lượt; việc mới vẫn ghi thẻ; bot trả người giục như lúc máy tắt (mục 7b); mẻ đang chạy không bị cắt. Lịch `<máy chủ>` tự `/pause` đêm, `/khoidong` sáng | không |
| `/khoidong` | Cho máy tự làm việc lại sau /pause, làm bù việc chờ | chủ nhà | chat riêng + nhóm chính | gỡ CỜ `/pause` + khởi động mọi thẻ «chờ khởi động» (việc người khác giao, nhãn «Làm sau») → con canh thấy mục chưa báo, thoát → phiên làm bù | không (đi đường `check-viec-sep.md`) |
| `/xoa` | Huỷ thẻ tạo nhầm: /xoa <mã thẻ> hoặc Reply /xoa vào tin của thẻ | chủ nhà | chat riêng + nhóm chính | THẺ xoá mềm (sang Xong + dấu huỷ; ẩn khỏi bảng và tin định kỳ; «Mở lại» được). Reply `/xoa` trần chỉ khi tin gắn ĐÚNG một thẻ, không đoán. Tối thượng như `/viec`. Chủ Reply «nhầm / huỷ / xoá» trong 10 phút sau `/viec` = tự huỷ | không |
| `/help` | Danh sách lệnh theo nhóm | mọi người (danh sách nội bộ) | mọi nơi bot nhận lệnh | MÁY CHỦ TRẢ; chữ sinh từ CHỖ KHAI LỆNH DUY NHẤT (cùng nguồn menu «/»): chủ nhà chat riêng thấy đủ, nơi khác chỉ lệnh chung | không |
| `/admin` `/today` `/runlist` | mức dùng tài khoản Claude · mức dùng hôm nay · bảng thợ đang chạy | chủ nhà | chat riêng | **CHỈ dự án gom số máy (bản gốc ChicHub)** — số chung cả máy nhà, dự án khác KHÔNG làm, không khai vào `lenh_chung` | — |

Luật chung cho cả bảng:
- **Một chỗ khai lệnh duy nhất** (mảng: tên · mô tả · ai · nhóm · hiện ở nhóm chính không) → sinh menu «/» từng scope (skill
  `bot-commands`: scope chat riêng chủ nhà đủ lệnh; scope `chat_member` (riêng chủ nhà trong nhóm chính) chỉ lệnh có «nhóm chính»
  — người khác trong nhóm vẫn thấy scope mặc định; scope mặc định chỉ lệnh mọi người: `/help` + lệnh nghiệp vụ riêng dự án) + chữ
  `/help`. Thêm lệnh là sửa đúng một chỗ.
- Cổng «chủ nhà» là MỘT hàm dùng chung (chat riêng chủ nhà HOẶC chủ nhà trong nhóm chính); đừng chép điều kiện vào từng lệnh.
  Các lệnh này đứng TRƯỚC mọi luồng thẻ việc và không phụ thuộc công tắc «bot im trong nhóm».
- Thứ tự trong webhook (bản gốc): nhóm có lối riêng (nhóm việc ngoài) → `/clitell` → `/tatmay` `/momay` → `/lam` + Reply tin phương án → `/lamdi` →
  `/khac` + Reply tin `/khac` → Reply tin danh sách → (`/viec` `/xoa` tối thượng) → lệnh chỉ-chat-riêng (`/cho` …) → luồng thẻ việc →
  trợ lý AI → `/help`.
- Nhận `/lenh@ten_bot`; `/lenh@bot_khac` bỏ. Lệnh chạm CLI lúc máy nhà tắt phải nói ĐÚNG loại: `/clitell` «đã lưu, mở phiên sẽ đọc» ·
  `/tatmay` `/momay` «chưa chuyển» · `/lamdi` «sổ giữ nguyên, CLI không nghe».
- Tệp dấu khai `lenh_chung` (mục 9) = các lệnh trong bảng dự án ĐÃ CÓ (bỏ dấu `/`). `sync-uni.sh check` in «dự án X thiếu /…» cho
  lệnh còn thiếu — chỉ nhắc, không đổi mã thoát.

## 8. Checklist dựng cho dự án mới (theo thứ tự)
0. Đọc `references/hop-dong.md` + `references/mau-tep.md`; chọn bản gọn (PHP/SQLite) hay bản đầy đủ (app web sẵn có).
1. `.env`: `TG_BOT_TOKEN`, `TG_CHAT_SEP`, `TG_WEBHOOK_SECRET`, `SEP_VIEC_TOKEN` (khác secret webhook), `TG_SEP_ID`,
   `TG_CHU_NHA_ID`, `SEP_VIEC_URL`. Sinh khoá `python3 -c "import secrets;print(secrets.token_hex(24))"` ghi thẳng vào
   `.env`, không in ra màn hình. Id người lấy từ cột `tu_id` của kho sau khi người đó nhắn 1 tin — không đoán theo tên hiện.
2. Bot + nhóm: @BotFather tạo bot → thêm vào nhóm → `/setprivacy` Disable (đo `getMe.can_read_all_group_messages=true`).
   Cần thả/đọc ❤ thì cho bot làm quản trị.
3. Máy chủ: webhook kiểm secret fail-closed, chỉ nhận nhóm trong danh sách (nội bộ / người ngoài tách riêng, luật 4.12), ghi trong một giao dịch, lỗi → 500; cấp mã theo ngày
   giao gốc; `parse_mode: HTML` cho cả chữ, chú thích ảnh, phần tử đầu album.
4. CLI + 2 hook + cổng chặn + lệnh `check-viec-sep.md`; `.gitignore` thêm `.claude/sep-viec/` và thư mục ảnh tải về.
5. Deploy theo luật deploy của dự án. Kiểm: webhook secret sai → `401`; lối máy không token → `401`; kho không truy cập được qua web.
6. `dat-webhook` (allowed_updates `message`, `edited_message`[, `message_reaction`]; KHÔNG bỏ tin chờ). `getWebhookInfo`:
   url đúng, `pending_update_count=0`, không `last_error_message`. 403/406 trên cPanel = ModSecurity chặn POST JSON.
7. Chạy **các ca thử bằng update giả** ở `references/ca-thu.md` (không gửi gì vào nhóm thật) — gồm ca thoại 17–19 (mục 4b) và
   ca `/clitell` 20–23 (mục 7d) và ca duyệt lượt 24–31 (mục 7e).
   Dọn bằng `xoa` nêu đích danh.
8. Thử thật một lần: báo trước sếp là tin thử → `gui --thu` → gửi → chủ nhà Reply trên điện thoại → kiểm như ca 3 → dọn.
9. Ghi tệp dấu `docs/bot-nhan-viec.json` (mục 9) + một dòng vào CLAUDE.md dự án: «mở phiên tự kéo việc sếp; gửi sếp chỉ qua CLI `gui`».

## 9. Tệp dấu dự án — `docs/bot-nhan-viec.json`
`sync-uni.sh check` đọc tệp này để biết có cần hỏi anh không. KHÔNG ghi khoá / mã nhóm vào đây.
```json
{ "trang_thai": "da-co", "bot": "@ten_bot", "nhom": "tên nhóm hiển thị", "cli": "scripts/sep-viec/sep_viec.py", "ghi_luc": "2026-10-09",
  "thoai": "da-co", "clitell": "da-co",
  "lenh_chung": ["viec","clitell","lam","lamdi","khac","cho","tatmay","momay","pause","khoidong","xoa","help"] }
```
- `lenh_chung` = lệnh của bảng mục 7f dự án đã có (không dấu `/`, không gồm `/admin` `/today` `/runlist`). Sửa tay được (mảng
  JSON), nhưng chỉ ghi lệnh đã chạy thật trên bot của dự án. Thiếu trường / thiếu lệnh → `sync uni` in «dự án X thiếu /…».
- `da-co` (đủ `bot` + `nhom`) hoặc `khong-can` → sync uni im.
- Không có tệp, hoặc `de-sau` → sync uni in khối hỏi mỗi lần check.
- Ghi bằng lệnh, đừng viết tay: `sync-uni.sh bot-nhan-viec khong-can|de-sau` ·
  `sync-uni.sh bot-nhan-viec da-co --bot @ten_bot --nhom "Tên nhóm"`.

## Những điều đừng làm
- Đừng gửi vào nhóm sếp bằng `curl`/script gọi API thẳng; đừng cấp mã ngày hôm nay cho việc hôm trước.
- Đừng để bot ghi xong mà im (phải ✍ + «Đã ghi vào thẻ <mã> · link»); đừng để Reply tin nhắc định kỳ đẻ thẻ mới mỗi ca.
- Đừng để con canh coi ghi chú do chính máy viết là tin mới; đừng để hook coi thông báo máy là lời chủ.
- Đừng gửi chữ tài chính nội bộ vào nhóm có người ngoài; đừng để chủ quyết trong CLI mà không ghi thẻ.
- Đừng biến tin thường thành việc; đừng nhận `/viec` chat riêng; đừng hỏi chủ nhà trong nhóm sếp.
- Đừng gửi tin chữ trơn dài, thiếu mã lựa chọn, ảnh không chữ; đừng dùng nút bấm thay Reply gõ mã.
- Đừng để `/clitell` đẻ thẻ hay lọt sang trợ lý AI; đừng báo chủ «đã chuyển vào phiên đang chạy» khi con canh không chạy.
- Đừng để tin thoại thành «[tin không có chữ]»; đừng nghe thoại trong lúc giữ Telegram chờ (trả 200 trước, nghe sau).
- Đừng thêm lệnh chạm phiên CLI ở một dự án mà không sửa bảng 7f + nhắn các dự án khác; đừng để `/clitell` của chủ nhà trong nhóm chính bị nuốt im.
- Đừng để `/lam` trần khởi động việc khi chủ nhà chưa OK phương án; đừng để máy chủ tự phân loại bằng AI; đừng coi «ok nhưng …» là OK.
- Đừng giả lập hỏng kho trên host thật (thử T3 ở cục bộ); đừng quên bật lại con canh.
