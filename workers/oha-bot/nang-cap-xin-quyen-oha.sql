-- Xin quyền cho hook máy Mac (Task-20102026-02, ChicHub): câu Reply «1A/1B» của anh Thành vào tin hỏi quyền
-- mang «Mã xin phép: XQ-…». Hook đọc qua GET /xin-quyen?ma=… (khoá XIN_QUYEN_KHOA). Không vào luồng oHa.
CREATE TABLE IF NOT EXISTS bnv_xin_quyen (
  ma TEXT PRIMARY KEY, tra_loi TEXT, chu TEXT, chat_id TEXT, message_id INTEGER, tu_id TEXT, luc INTEGER NOT NULL
);
