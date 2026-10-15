-- Nâng cấp kho D1 15/10/2026 (W32): mục 7f — bộ lệnh chung chạm phiên Claude CLI.
-- Chạy MỘT lần sau khi đã sao lưu các bảng bnv_. Chỉ đụng bảng bnv_* (kho oha-db dùng chung với trang oha.jst4.fun).
-- loai lời CLI: loi (chủ gõ /clitell) · tong-hop (sổ dồn /lamdi) · lenh_may (/tatmay /momay).
ALTER TABLE bnv_clitell ADD COLUMN loai TEXT NOT NULL DEFAULT 'loi';
-- Tin danh sách bot gửi (/khac /cho /lamdi): Reply vào tin tóm «#số lời» hoặc tin một thẻ → ghi đúng thẻ.
CREATE TABLE IF NOT EXISTS bnv_danh_sach (
  chat_id TEXT NOT NULL, message_id INTEGER NOT NULL, loai TEXT NOT NULL, ds TEXT NOT NULL DEFAULT '[]', tao_luc INTEGER NOT NULL,
  PRIMARY KEY(chat_id, message_id)
);
