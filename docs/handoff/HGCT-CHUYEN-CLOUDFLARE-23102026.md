# HGCT-23102026-01 — Chuyển Hạt Giống Chiêm Tinh từ VPS HostHatch sang Cloudflare

> Thẻ: **HGCT-23102026-01** · anh Thành giao 08:09 23/10/2026.
> Tệp này để anh thả vào dự án HGCT trên VPS (`/root/hgct`), cho Claude CLI ở đó đọc, soi lại với mã thật rồi làm.

## 1. Mong muốn của anh (nguyên văn)

«lên 1 task cho tao, tổng hợp lại mong muốn chuyển đổi dự án hatgiongchiemtinh từ server hosthatch VPS sang Cloudflares. để tao add vào dự án đó, cho claude cli đọc xem có gì không ổn, hoặc cần làm gì. sau đó trả lời về bên này bằng 1 file md là có thể làm được. check xem github thanhnt.1021@gmail.com đã có dự án ấy chưa, để nếu chưa thì báo con claude cli của dự án đó đẩy lên luôn nhé.»

Diễn giải: bỏ VPS HostHatch, web hatgiongchiemtinh.com (và demo) chạy trên Cloudflare; khách vẫn đặt dịch vụ → trả tiền SePay → nhận PDF qua email như bây giờ, không đứt đoạn.

## 2. Đã kiểm gì (23/10/2026, từ máy Mac của anh)

- **GitHub thanhnt1021: CHƯA có dự án.** 18 repo, không có repo nào tên hgct / hatgiong.
- Mã đang nằm ở **`hentaiikidd/hgct`** (riêng tư, nhánh `main`, lần đẩy cuối **27/07/2026**, commit `ff14d3e`). Tài khoản thanhnt1021 không phải cộng tác viên của repo này.
- **Không vào được VPS** `185.197.30.234:52847` (user `hgct`): chìa `~/.ssh/hgct` bị từ chối. Vì vậy chưa biết trên VPS có mã mới hơn bản GitHub 27/07 không → Claude CLI trên VPS phải kiểm (bước 0).
- Tên miền đã ở Cloudflare (NS `vick` / `ariella.ns.cloudflare.com`, đang đi proxy), web trả 200 → phần DNS chuyển nhẹ.
- Phân tích bên dưới đọc từ bản GitHub 27/07.

## 3. Hiện trạng trên VPS (theo mã)

- Next.js 15.5 + React 19, `output: 'standalone'`, chạy trong Docker (`infra/docker-compose.yml`): Postgres 16, `hgct-prod`, `hgct-demo`, sidecar cron, `docker-socket-proxy` (admin bot khởi động lại container).
- 68 route API, Prisma 13 bảng trên Postgres `zodiacdb`.
- Sinh báo cáo: tính lá số → lấy KB → gọi OpenRouter (tới 32.000 token, vài phút) → dựng PDF bằng Chromium → gửi mail SMTP Hostinger → báo Telegram.
- Cron 4 việc: `/api/cron/order-check` (mỗi phút), `cleanup`, `kb-sync` (Google Sheets → KB), `retention`.

## 4. Chỗ KHÔNG chạy thẳng được trên Cloudflare Workers (phải xử)

| Thành phần | Vì sao vướng | Hướng xử |
|---|---|---|
| `swisseph` (tính lá số) — `src/lib/astrology/calculations.ts`, `constants.ts`, `transit-stubs.ts` | Là mô-đun C biên dịch sẵn cho Linux, Worker không nạp được | Chạy trong **Cloudflare Containers** (giữ nguyên mã), hoặc thay bằng bản WebAssembly của Swiss Ephemeris rồi đối chiếu kết quả từng hành tinh/nhà với bản cũ |
| Chromium + puppeteer (PDF, ảnh OG, xem trước) — `src/lib/pdf/generator.ts`, `job-queue.ts`, `api/og` | Worker không chạy trình duyệt; `generator.ts` còn gọi `execFileSync` | **Browser Rendering** của Cloudflare (`@cloudflare/puppeteer`), hoặc để trong Container |
| Ghi đĩa: `/var/hgct/pdfs`, avatar, `imgs` — `reportProcessor.ts`, `api/pdf/[id]`, `api/user/avatar`, `api/profiles`, `cron/cleanup` | Worker không có ổ đĩa | Chuyển sang **R2**; chép toàn bộ PDF cũ lên R2 trước khi tắt VPS |
| Việc nền chạy vài phút: `processReport()` bắn rồi quên (`reportProcessor.ts:444`), bộ nhớ job `global.__hgctJobs` + `setInterval` watchdog (`src/lib/jobs.ts:39,396,408`) | Worker tắt khi trả lời xong, không giữ bộ nhớ, không có `setInterval` | **Queues** hoặc **Workflows** chạy job; trạng thái job chỉ lấy từ DB; watchdog chuyển thành Cron Trigger |
| Gửi mail `nodemailer` SMTP — `src/lib/email.ts` | Worker không mở SMTP kiểu nodemailer | **Cloudflare Email Service** hoặc API gửi mail (Resend…); giữ nguyên mẫu thư |
| Postgres trong Docker | Cloudflare không chạy Postgres | Giữ Postgres ở nơi khác (Neon / Supabase) nối qua **Hyperdrive** — ít sửa nhất; chuyển sang D1 thì phải viết lại phần Prisma |
| Cron sidecar + crontab | — | **Cron Triggers** (mỗi phút gọi order-check như cũ) |
| `docker-socket-proxy` + `src/lib/docker.ts` (admin bot restart container) | Không còn Docker | Bỏ lệnh restart trong admin bot hoặc đổi thành lệnh khởi động lại Container |
| `geo-tz` (đọc tệp dữ liệu múi giờ), `googleapis` (gói rất nặng) | Dữ liệu đọc từ đĩa + làm phình gói vượt hạn 10 MB của Worker | Tra múi giờ ở Container hoặc API; Sheets gọi REST thẳng bằng `fetch` |
| `public/` 78 MB (`vh99` 30 MB, `fonts` 26 MB, `chart-symbols` 21 MB) | Ảnh tĩnh quá cỡ cho gói Worker | Để ở Static Assets / R2 |
| Next.js trên Worker | Cần bộ chuyển `@opennextjs/cloudflare`; `runtime='nodejs'` ở 5 route phải soát lại | Dựng thử demo trước |

## 5. Phương án

- **5A (đề xuất) — chia hai:** giao diện + API nhẹ lên Workers (OpenNext); phần nặng (swisseph, Chromium, job AI dài) gói nguyên Docker hiện có thành **Cloudflare Containers**; Postgres sang Neon/Supabase qua Hyperdrive; tệp sang R2; mail qua Email Service; cron qua Cron Triggers. Sửa mã vừa phải, tính lá số giữ y hệt.
- **5B — dời trọn Docker sang Cloudflare Containers:** sửa ít nhất, nhưng vẫn cần Postgres bên ngoài + R2 cho tệp; gần như chỉ là đổi chỗ chạy.
- **5C — viết lại thuần Workers + D1 + Swiss Ephemeris WebAssembly:** sạch nhất về lâu dài nhưng nhiều việc nhất, rủi ro lệch kết quả lá số.

## 6. Việc Claude CLI trên VPS làm (theo thứ tự)

0. So mã trên VPS với GitHub: `git status`, `git log origin/main..HEAD`, `git fetch && git log HEAD..origin/main`. Có thay đổi chưa đẩy thì commit + đẩy lên `hentaiikidd/hgct` trước.
1. **Đẩy dự án lên GitHub thanhnt1021** (anh đã dặn): tạo repo riêng tư `thanhnt1021/hgct`, đẩy đủ nhánh + lịch sử (`git push --mirror`), trước đó chạy gitleaks để không lộ khoá. VPS chưa có quyền vào tài khoản thanhnt1021 thì báo anh mời quyền hoặc thêm deploy key.
2. Đọc lại bảng mục 4 với mã thật trên VPS, bổ sung chỗ bảng này bỏ sót (mã trên VPS có thể mới hơn 27/07).
3. Đo dung lượng thật: DB (`pg_database_size`), `/var/hgct/pdfs`, avatar — để ước chi phí R2 / Postgres ngoài.
4. Sao lưu đủ trước khi động: `pg_dump` + toàn bộ `/var/hgct` lưu **hai nơi** (VPS + máy khác/R2), `ls -la` kiểm cả hai.
5. Dựng **demo** trên Cloudflare theo phương án anh chọn (demo.hatgiongchiemtinh.com), chạy thử đủ 4 dịch vụ (sự nghiệp, tình duyên, cặp đôi, vận hạn): PDF, email, SePay webhook, Telegram, cron order-check.
6. Đối chiếu kết quả lá số demo với prod trên cùng 5 bộ ngày giờ sinh (vị trí hành tinh, nhà, điểm vận hạn phải khớp).
7. Chuyển prod: tạm dừng nhận đơn → chép DB + PDF lần cuối → đổi webhook SePay + webhook 2 bot Telegram sang địa chỉ mới → mở lại. VPS giữ chạy thêm ít nhất 7 ngày để lùi về nếu cần.
8. Báo anh trước bước 7 — CHƯA được tự chuyển prod khi anh chưa duyệt.

## 7. Kết luận

**Làm được.** Khó nhất là ba chỗ: tính lá số (`swisseph`), dựng PDF (Chromium) và job AI chạy vài phút — đều có lối trên Cloudflare (Containers / Browser Rendering / Queues). Phương án 5A giữ y kết quả lá số và sửa mã vừa phải.

## 8. Câu cần anh chọn (Reply gõ mã)

1. Phương án? **1A** chia hai Workers + Containers (đề xuất) · **1B** dời trọn Docker sang Containers · **1C** viết lại thuần Workers + D1
2. Cơ sở dữ liệu để đâu? **2A** Postgres ngoài (Neon/Supabase) qua Hyperdrive (đề xuất) · **2B** tạm giữ Postgres trên VPS, chỉ dời web · **2C** chuyển hẳn sang D1
3. Repo GitHub? **3A** tạo `thanhnt1021/hgct` và đẩy bản đầy đủ, giữ `hentaiikidd/hgct` làm dự phòng (đề xuất) · **3B** chuyển hẳn quyền sở hữu repo sang thanhnt1021
