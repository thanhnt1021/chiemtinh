-- Nâng cấp kho D1 21/10/2026 (W47, thẻ ChicHub Task-21102026-08): @nguyclaudebot nhận việc NHIỀU dự án.
-- Anh Thành 21/10 «1A 2A 3B»: nguy nhận việc oHa + Tùng + anh Tân + Đạt; chat riêng anh ↔ nguy chọn dự án theo chủ đề.
-- CHỈ THÊM: một bảng mới + cột du_an (mặc định 'oHa' → mọi dòng cũ vẫn là của oHa) + chỉ mục + dòng dự án mới.
-- Không xoá / không đổi dữ liệu oHa. Chạy MỘT lần sau khi đã sao lưu (wrangler d1 export oha-db --remote).
CREATE TABLE IF NOT EXISTS bnv_du_an (
  ma TEXT PRIMARY KEY,                       -- = tiền tố mã thẻ (TUNG → TUNG-ddmmyyyy-NN), chỉ chữ cái
  ten TEXT NOT NULL,
  chat_chinh TEXT,                           -- nhóm Telegram chính của dự án
  chat_phu TEXT NOT NULL DEFAULT '[]',       -- JSON: nhóm nội bộ khác
  sep TEXT NOT NULL DEFAULT '[]',            -- JSON: id người được /viec ngoài chủ nhà
  bat INTEGER NOT NULL DEFAULT 0,            -- 0 = bot bỏ qua nhóm + chat riêng của dự án (chờ chuyển giao)
  chu_de_rieng INTEGER,                      -- 3B: message_thread_id chủ đề của dự án trong chat riêng chủ nhà
  rieng_vao_nhom INTEGER NOT NULL DEFAULT 0, -- 1 = tin máy gửi «--rieng» vẫn vào nhóm (trừ rieng_that)
  bi_danh TEXT NOT NULL DEFAULT '[]',        -- JSON: chữ gõ sau lệnh trong chat riêng, vd «/viec tung …»
  thu_muc TEXT,                              -- thư mục dự án trên máy nhà (chỉ để tra)
  tao_luc INTEGER NOT NULL
);
ALTER TABLE bnv_viec ADD COLUMN du_an TEXT NOT NULL DEFAULT 'oHa';
ALTER TABLE bnv_tin ADD COLUMN du_an TEXT NOT NULL DEFAULT 'oHa';
ALTER TABLE bnv_clitell ADD COLUMN du_an TEXT NOT NULL DEFAULT 'oHa';
ALTER TABLE bnv_duyet_luot ADD COLUMN du_an TEXT NOT NULL DEFAULT 'oHa';
CREATE INDEX IF NOT EXISTS bnv_viec_du_an ON bnv_viec(du_an, ngay);
CREATE INDEX IF NOT EXISTS bnv_tin_du_an ON bnv_tin(du_an, can_bao, claude_doc_luc);

-- Ba nhóm việc ngoài chuyển từ bot ChicHub (src/lib/task-dev/ma-the.mjs NHOM_VIEC_NGOAI) — để TẮT tới lượt chuyển giao.
INSERT OR IGNORE INTO bnv_du_an(ma, ten, chat_chinh, bat, rieng_vao_nhom, bi_danh, thu_muc, tao_luc) VALUES
  ('TUNG', 'nhóm Bạn Tùng', '-5325766797', 0, 1, '["tung"]', '~/PycharmProjects/tung', CAST(strftime('%s','now') AS INTEGER)),
  ('ANHTAN', 'anh Tân group', '-5377179172', 0, 0, '["anhtan"]', '~/PycharmProjects/anhtan', CAST(strftime('%s','now') AS INTEGER)),
  ('DAT', 'nhóm Đạt (Meta Testing)', '-5508701709', 0, 0, '["dat"]', '~/PycharmProjects/dat', CAST(strftime('%s','now') AS INTEGER));

-- Thẻ con canh trưởng của từng dự án (mục 7c): Reply tin nhắc không mã → ghi vào đây, không bao giờ đóng.
INSERT OR IGNORE INTO bnv_viec(ma, ngay, stt, tieu_de, noi_dung, trang_thai, tao_luc, cap_nhat, nguon, du_an)
SELECT ma || '-CANH', '-', 0, 'Con canh trưởng — sổ tin tổng hợp, cảnh báo của máy',
       'Thẻ hệ thống vĩnh viễn: Reply vào tin nhắc / cảnh báo của máy đều ghi vào đây.', 'dang-lam',
       CAST(strftime('%s','now') AS INTEGER), CAST(strftime('%s','now') AS INTEGER), 'he-thong', ma
FROM bnv_du_an WHERE ma IN ('TUNG', 'ANHTAN', 'DAT');
