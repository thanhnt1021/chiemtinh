-- Kho bot nhận việc oHa (D1). Hợp đồng: skill bot-nhan-viec references/hop-dong.md (bản gọn, 2 bảng tin/viec)
-- + bảng clitell (mục 7d) + bảng moc (nhịp tim, mốc con canh, sổ đếm lượt AI, câu mặc định máy tắt).
-- Dùng chung kho D1 `oha-db` với dự án khác → mọi bảng mang tiền tố bnv_ (bot nhận việc).
CREATE TABLE IF NOT EXISTS bnv_tin (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  chat_id TEXT NOT NULL, message_id INTEGER NOT NULL,
  luc INTEGER NOT NULL, tu_id TEXT, tu_ten TEXT, la_bot INTEGER NOT NULL DEFAULT 0,
  noi_dung TEXT NOT NULL DEFAULT '', reply_to INTEGER, media_group TEXT, anh TEXT,
  ma_viec TEXT, sua_luc INTEGER, raw TEXT, nhan_luc INTEGER NOT NULL,
  can_bao INTEGER NOT NULL DEFAULT 0,
  claude_doc_luc INTEGER,
  ban_truoc TEXT,
  nhac_luc INTEGER,                         -- mục 7c: mốc đã nhắc chủ nhà (giành lượt bằng UPDATE có điều kiện)
  UNIQUE(chat_id, message_id)
);
CREATE INDEX IF NOT EXISTS bnv_tin_ma ON bnv_tin(ma_viec);
CREATE INDEX IF NOT EXISTS bnv_tin_chua_doc ON bnv_tin(can_bao, claude_doc_luc);

CREATE TABLE IF NOT EXISTS bnv_viec (
  ma TEXT PRIMARY KEY, ngay TEXT NOT NULL, stt INTEGER NOT NULL,
  tieu_de TEXT NOT NULL, noi_dung TEXT NOT NULL DEFAULT '', nguoi_giao TEXT, giao_luc INTEGER,
  trang_thai TEXT NOT NULL, tin_goc INTEGER, tao_luc INTEGER NOT NULL, cap_nhat INTEGER NOT NULL,
  nguon TEXT,                               -- 'he-thong' = thẻ con canh trưởng (mục 7c), không bao giờ đóng
  chuyen_sang TEXT                          -- mục 7e: việc phụ đã gộp vào việc này (trạng thái 'da-chuyen')
);

CREATE TABLE IF NOT EXISTS bnv_clitell (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  chu TEXT NOT NULL, noi_tiep TEXT, chat_id TEXT NOT NULL, message_id INTEGER NOT NULL,
  bot_tin TEXT NOT NULL DEFAULT '[]', tao_luc INTEGER NOT NULL, nhan_luc INTEGER,
  UNIQUE(chat_id, message_id)
);

-- Mục 7e: lượt duyệt /lam. trang_thai: cho-may → cho-chu-nha → gop-y → … → da-ok → dang-ap → da-ap.
-- lich_su = JSON các bản + góp ý; ket_qua = JSON {khoi_dong, bo_qua, gop, bo, de_sau, hoi_da_gui}.
CREATE TABLE IF NOT EXISTS bnv_duyet_luot (
  id INTEGER PRIMARY KEY, trang_thai TEXT NOT NULL, ban INTEGER NOT NULL DEFAULT 0, phuong_an TEXT,
  message_id INTEGER, gop_y TEXT, lich_su TEXT NOT NULL DEFAULT '[]', ket_qua TEXT, yeu_cau_chat TEXT, yeu_cau_mid INTEGER,
  tao_luc INTEGER NOT NULL, cap_nhat INTEGER NOT NULL
);
-- Chỉ Reply lên ĐÚNG tin phương án mới là duyệt.
CREATE TABLE IF NOT EXISTS bnv_duyet_luot_tin (
  chat_id TEXT NOT NULL, message_id INTEGER NOT NULL, dl_id INTEGER NOT NULL, ban INTEGER NOT NULL,
  PRIMARY KEY(chat_id, message_id)
);

CREATE TABLE IF NOT EXISTS bnv_moc (khoa TEXT PRIMARY KEY, gia_tri INTEGER NOT NULL);

INSERT OR IGNORE INTO bnv_viec(ma, ngay, stt, tieu_de, noi_dung, trang_thai, tao_luc, cap_nhat, nguon)
VALUES ('oHa-CANH', '-', 0, 'Con canh trưởng — sổ tin tổng hợp, cảnh báo của máy',
        'Thẻ hệ thống vĩnh viễn: Reply vào tin nhắc / cảnh báo của máy đều ghi vào đây.', 'dang-lam',
        CAST(strftime('%s','now') AS INTEGER), CAST(strftime('%s','now') AS INTEGER), 'he-thong');
