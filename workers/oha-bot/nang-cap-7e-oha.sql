-- Nâng cấp kho D1 thật 12/10/2026 (W05): mục 7e (/lam duyệt lượt) + đổi mã việc Task- → oHa- (founder chốt).
-- Chạy MỘT lần sau khi đã backup bảng bnv_. Thứ tự: bảng/cột mới → đổi mã ở mọi bảng có cột mã.
CREATE TABLE IF NOT EXISTS bnv_duyet_luot (
  id INTEGER PRIMARY KEY, trang_thai TEXT NOT NULL, ban INTEGER NOT NULL DEFAULT 0, phuong_an TEXT,
  message_id INTEGER, gop_y TEXT, lich_su TEXT NOT NULL DEFAULT '[]', ket_qua TEXT, yeu_cau_chat TEXT, yeu_cau_mid INTEGER,
  tao_luc INTEGER NOT NULL, cap_nhat INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS bnv_duyet_luot_tin (
  chat_id TEXT NOT NULL, message_id INTEGER NOT NULL, dl_id INTEGER NOT NULL, ban INTEGER NOT NULL,
  PRIMARY KEY(chat_id, message_id)
);
ALTER TABLE bnv_viec ADD COLUMN chuyen_sang TEXT;
UPDATE bnv_viec SET ma = 'oHa-' || substr(ma, 6) WHERE ma LIKE 'Task-%';
UPDATE bnv_tin SET ma_viec = 'oHa-' || substr(ma_viec, 6) WHERE ma_viec LIKE 'Task-%';
UPDATE bnv_moc SET khoa = 'mac_dinh:oHa-' || substr(khoa, 15) WHERE khoa LIKE 'mac_dinh:Task-%';
