-- Nâng cấp kho D1 21/10/2026 (thẻ ChicHub Task-21102026-08): sổ nhóm lạ — nhóm có bot mà chưa gắn dự án.
-- CHỈ THÊM một bảng mới. Chỉ lưu mã + tên nhóm, không lưu nội dung tin.
CREATE TABLE IF NOT EXISTS bnv_nhom_la (
  chat_id TEXT PRIMARY KEY,
  ten TEXT NOT NULL DEFAULT '',
  lan_dau INTEGER NOT NULL,
  lan_cuoi INTEGER NOT NULL,
  so_tin INTEGER NOT NULL DEFAULT 1
);
