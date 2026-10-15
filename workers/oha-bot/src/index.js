// Bot nhận việc oHa — Cloudflare Worker + D1. Port bản gọn (PHP/SQLite) của skill bot-nhan-viec,
// giữ nguyên hợp đồng lối máy (references/hop-dong.md) để CLI scripts/sep-viec/sep_viec.py dùng chung.

// Founder chốt 12/10/2026: mã việc của dự án là `oHa-ddmmyyyy-NN`. Mã cũ `Task-…` (tin bot gửi trước ngày đổi, sếp gõ lại)
// vẫn nhận và quy đổi sang oHa- — thẻ trong kho đã đổi tên, đừng bắt người gõ lại.
const TIEN_TO = 'oHa';
const MA_RE = /(?:oHa|Task)-(?:\d{8}-\d{2,3}|CANH)/;
const doiMa = (s) => String(s ?? '').trim().replace(/^Task-/i, TIEN_TO + '-').replace(/^oha-/i, TIEN_TO + '-');
const maTrongChu = (s) => { const r = MA_RE.exec(String(s ?? '')); return r ? doiMa(r[0]) : null; };
const TRANG_THAI = ['cho-xac-nhan', 'cho-sep-tra-loi', 'sep-da-tra-loi', 'dang-lam', 'xong', 'huy', 'da-chuyen'];
const TT_DONG = ['xong', 'huy', 'da-chuyen'];
// 7e — việc «đang chờ chủ nhà cho làm» của bộ gọn = sếp giao, chưa ai nhận.
const TT_CHO = 'cho-xac-nhan';
const DL_MO = ['cho-may', 'cho-chu-nha', 'gop-y', 'da-ok', 'dang-ap'];
const DL_CAN_MAY = ['cho-may', 'gop-y', 'da-ok', 'dang-ap'];
const DL_NHOM = ['lam', 'hoi', 'gop', 'bo', 'de_sau'];
const DL_TEN_TT = { 'cho-may': 'chờ máy dựng phương án', 'cho-chu-nha': 'chờ anh duyệt', 'gop-y': 'máy đang sửa theo góp ý của anh',
  'da-ok': 'anh đã OK, chờ máy làm', 'dang-ap': 'máy đang làm theo phương án', 'da-ap': 'đã làm xong', huy: 'đã huỷ' };
// «OK» = CẢ tin chỉ là lời đồng ý. «ok nhưng 02 bỏ» là góp ý — quy tắc tất định, không đoán.
const DL_OK_RE = /^(?:ok|oke|okie|okay|okela|duyệt|đồng ý|chốt|làm đi|cứ làm đi|được|1a)(?:\s+(?:hết|tất cả|luôn|nhé|nha|đi))*[\s.!👍❤️\uFE0F]*$/iu;
const HOI_RE = /^1\.\s+\S.*?(?<![\p{L}\d])1A(?![\p{L}\d]).*?(?<![\p{L}\d])1B(?![\p{L}\d])/su;
const NGUONG_NHAC_GIAY = 15 * 60;      // mục 7c — đổi một chỗ
const MAY_TAT_SAU_GIAY = 15 * 60;      // mục 7b — quá ngần này không nhịp tim = máy nhà tắt
const MAC_DINH_CACH_GIAY = 30 * 60;    // câu mặc định máy tắt: mỗi thẻ tối đa 1 lần / 30 phút
const CANH_NGHE_GIAY = 120;            // mục 7d.5 — con canh hỏi trong 2 phút = đang nghe
const TEP_ROI_GIAY = 300;              // luật 4.10 — tệp gửi rời trong 5 phút sau tin việc
const CHU_THICH_GIAY = 120;
const DAU_FORCE = '✍ Gõ việc vào tin này';
const DAU_CLI = ['📨 CLI ·', '🤖 Phiên CLI:'];
const CAU_CLI_CHI_CHU = '📨 CLI · Lệnh này chỉ chủ nhà dùng được.';
const CAU_MAY_TAT = 'Hệ thống đang chạy nhiều việc nên việc này chưa xong, sẽ phản hồi khi xong.';
// 7f — lịch trên Cron Trigger sẵn có (*/5): skill không ghi giờ gốc → chọn 23h tạm dừng, 7h chạy lại, gom /lamdi mỗi 2 giờ 8h–22h.
const GIO_TAM_DUNG = 23;
const GIO_KHOI_DONG = 7;
const GIO_GOM = [8, 10, 12, 14, 16, 18, 20, 22];
const TRAN_THE_LUOT = 5;               // /khac /cho /lamdi: tối đa ngần này tin thẻ mỗi lượt, gõ lại gửi tiếp
const DS_HET_HAN_GIAY = 30 * 60;       // gõ lại /khac /cho sau ngần này thì gửi lại từ đầu
const HUY_NHAM_GIAY = 10 * 60;         // chủ Reply «nhầm / huỷ / xoá» trong 10 phút sau /viec = tự huỷ
const HUY_NHAM_RE = /^(?:nhầm|nham|huỷ|hủy|huy|xoá|xóa|xoa)(?:\s+(?:rồi|nhé|nha|đi|thẻ này|việc này))*[\s.!]*$/iu;

// 7f — CHỖ KHAI LỆNH DUY NHẤT: menu «/» từng scope + chữ /help sinh từ đây; thêm lệnh là sửa đúng mảng này.
// ai: chu = chủ nhà · ds = chủ nhà + sếp (luật 4.6) · moi = mọi người trong danh sách nội bộ.
// noi: rieng = chỉ chat riêng chủ nhà · chinh = chat riêng + nhóm chính · moi = mọi nơi bot nhận lệnh.
const dsLenh = (tenChu) => [
  { ten: 'viec', mo_ta: 'Giao việc mới, máy tạo thẻ', ai: 'ds', noi: 'moi', nhom: 'Giao việc' },
  { ten: 'xoa', mo_ta: 'Huỷ thẻ tạo nhầm: /xoa <mã thẻ> hoặc Reply /xoa vào tin của thẻ', ai: 'chu', noi: 'chinh', nhom: 'Giao việc' },
  { ten: 'clitell', mo_ta: 'Nhắn thẳng phiên Claude trên máy nhà, không tạo thẻ', ai: 'chu', noi: 'chinh', nhom: 'Phiên Claude CLI' },
  { ten: 'lamdi', mo_ta: `Đẩy mọi trao đổi chưa làm trên các thẻ vào phiên Claude + gửi ${tenChu} mỗi thẻ một tin`, ai: 'chu', noi: 'chinh', nhom: 'Phiên Claude CLI' },
  { ten: 'tatmay', mo_ta: 'Sắp tắt máy: phiên Claude cất hết việc dở, dừng thợ', ai: 'chu', noi: 'chinh', nhom: 'Phiên Claude CLI' },
  { ten: 'momay', mo_ta: 'Vừa mở máy: phiên Claude đọc sổ, chạy tiếp việc dở', ai: 'chu', noi: 'chinh', nhom: 'Phiên Claude CLI' },
  { ten: 'lam', mo_ta: 'Duyệt lượt việc đang chờ (/lam) · cho làm thẳng (/lam <mã> · /lam tatca)', ai: 'chu', noi: 'chinh', nhom: 'Cho máy làm' },
  { ten: 'pause', mo_ta: `Tạm dừng máy tự làm việc tới /khoidong hoặc ${GIO_KHOI_DONG}h sáng`, ai: 'chu', noi: 'chinh', nhom: 'Cho máy làm' },
  { ten: 'khoidong', mo_ta: 'Cho máy tự làm việc lại sau /pause, làm bù việc chờ', ai: 'chu', noi: 'chinh', nhom: 'Cho máy làm' },
  { ten: 'khac', mo_ta: `Việc chưa xong đang chờ người khác — ${tenChu} ngó và quyết hộ`, ai: 'chu', noi: 'chinh', nhom: 'Xem việc' },
  { ten: 'cho', mo_ta: `Ảnh việc đang chờ: chờ ${tenChu}, chờ người khác, chờ dùng thử`, ai: 'chu', noi: 'rieng', nhom: 'Xem việc' },
  { ten: 'help', mo_ta: 'Danh sách lệnh theo nhóm', ai: 'moi', noi: 'moi', nhom: 'Khác' },
];
// Tin danh sách bot tự gửi (/khac /cho /lamdi) không phải câu máy trả lời trên thẻ — 7c và «Máy hỏi gần nhất» phải bỏ qua.
const KHONG_DANH_SACH = 'NOT EXISTS (SELECT 1 FROM bnv_danh_sach d WHERE d.chat_id=b.chat_id AND d.message_id=b.message_id)';
const TEN_LENH = dsLenh('').map((l) => l.ten);
const LENH_RE = new RegExp(`^\\/(${TEN_LENH.join('|')})(?:@(\\w+))?(?:\\s+([\\s\\S]*))?$`, 'i');
const CHU_TAI_CHINH = /(lãi|lỗ|doanh thu|lợi nhuận|profit|revenue|\d[\d.,]*\s*(đ|vnđ|vnd|usd|\$)|\$\s*\d)/i;

const nowS = () => Math.floor(Date.now() / 1000);
const ds = (s) => String(s ?? '').split(',').map((x) => x.trim()).filter(Boolean);
const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const boThe = (s) => String(s ?? '').replace(/<[^>]+>/g, '').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
const json = (o, status = 200) => new Response(JSON.stringify(o), { status, headers: { 'content-type': 'application/json; charset=utf-8' } });
const OK = () => json({ ok: true });

function ngayVN(ts) {
  const d = new Date((ts + 7 * 3600) * 1000);
  const p = (n) => String(n).padStart(2, '0');
  return p(d.getUTCDate()) + p(d.getUTCMonth() + 1) + d.getUTCFullYear();
}

// Thẻ con canh trưởng tìm theo NGUỒN hệ thống (mục 7c), không ghi cứng mã.
async function maCanh(env) {
  const r = await env.DB.prepare("SELECT ma FROM bnv_viec WHERE nguon='he-thong' ORDER BY tao_luc LIMIT 1").first();
  return r?.ma || TIEN_TO + '-CANH';
}

function cauHinh(env) {
  return {
    chatSep: String(env.TG_CHAT_SEP || ''),
    noiBo: [String(env.TG_CHAT_SEP || ''), ...ds(env.TG_CHAT_NOI_BO)].filter(Boolean),
    ngoai: ds(env.TG_CHAT_NGOAI),
    sep: ds(env.TG_SEP_ID),
    chu: String(env.TG_CHU_NHA_ID || ''),
    botTen: String(env.TG_BOT_USERNAME || '').toLowerCase(),
    tenChu: String(env.TEN_CHU_NHA || 'chủ nhà'),
  };
}

// Ca thử trỏ TG_API_BASE về máy Telegram giả cục bộ → không tin nào lọt ra Telegram thật.
const tgGoc = (env) => String(env.TG_API_BASE || 'https://api.telegram.org').replace(/\/$/, '');

async function tg(env, method, body) {
  try {
    const r = await fetch(`${tgGoc(env)}/bot${env.TG_BOT_TOKEN}/${method}`, {
      method: 'POST',
      ...(body instanceof FormData ? { body } : { headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) }),
    });
    return await r.json();
  } catch (e) {
    return { ok: false, description: String(e) };
  }
}

const tha = (env, chat_id, message_id, emoji) =>
  tg(env, 'setMessageReaction', { chat_id, message_id, reaction: [{ type: 'emoji', emoji }] });

async function docMoc(env, khoa) {
  const r = await env.DB.prepare('SELECT gia_tri FROM bnv_moc WHERE khoa=?').bind(khoa).first();
  return r ? r.gia_tri : null;
}
const datMoc = (env, khoa, v) =>
  env.DB.prepare('INSERT INTO bnv_moc(khoa, gia_tri) VALUES(?,?) ON CONFLICT(khoa) DO UPDATE SET gia_tri=excluded.gia_tri').bind(khoa, v);

async function mayTat(env) {
  if (String(env.SEP_VIEC_NHIP_TIM || '').toLowerCase() === 'tat') return true;
  const m = await docMoc(env, 'nhip_tim');
  return !m || nowS() - m > MAY_TAT_SAU_GIAY;
}

// 7f — cờ /pause: mốc lúc bật (0 = không dừng). Con canh vẫn hỏi nhưng không gọi phiên dậy cho mục thẻ, lịch gom bỏ lượt.
const tamDung = async (env) => (await docMoc(env, 'tam_dung')) || 0;
// 7d.5 — con canh hỏi lối máy kèm x-canh trong 2 phút = có phiên đang nghe (nhịp tim chung không nói được điều này).
const canhNghe = async (env) => { const n = await docMoc(env, 'canh_nghe'); return !!n && nowS() - n <= CANH_NGHE_GIAY; };
// 7f — cổng chủ nhà DÙNG CHUNG cho mọi lệnh: chat riêng chủ nhà HOẶC chủ nhà trong nhóm chính.
const congChu = (ch, m) => String(m.from.id) === ch.chu && (m.chat.type === 'private' || String(m.chat.id) === ch.chatSep);
const gioVN = (ts) => new Date((ts + 7 * 3600) * 1000).toISOString().slice(11, 16);
const ngayGioVN = (ts) => { const d = new Date((ts + 7 * 3600) * 1000).toISOString(); return `${d.slice(8, 10)}/${d.slice(5, 7)} ${d.slice(11, 16)}`; };

// ---------- tệp / thoại ----------
function tepCua(m) {
  if (m.photo?.length) return m.photo[m.photo.length - 1].file_id;
  for (const k of ['document', 'audio', 'voice', 'video_note', 'video', 'animation', 'sticker'])
    if (m[k]?.file_id) return m[k].file_id;
  return null;
}
function thoaiCua(m) {
  for (const [k, mime] of [['voice', 'audio/ogg'], ['audio', 'audio/mpeg'], ['video_note', 'video/mp4']])
    if (m[k]?.file_id)
      return { id: m[k].file_id, giay: Math.round(m[k].duration || 0), mime: m[k].mime_type || mime, co: m[k].file_size || 0 };
  return null;
}
const dongHo = (s) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;

async function ngheThoai(env, t) {
  const dau = `🎤 (thoại ${dongHo(t.giay)})`;
  const hong = (l) => ({ dong: `${dau} thoại chưa nghe được — ${l}`, loi: l });
  if (t.co > 19 * 1024 * 1024) return hong('tệp quá 19 MB');
  const f = await tg(env, 'getFile', { file_id: t.id });
  const duong = f?.result?.file_path;
  if (!duong) return hong('Telegram không cho tải tệp');
  let bytes;
  try {
    const r = await fetch(`${tgGoc(env)}/file/bot${env.TG_BOT_TOKEN}/${duong}`);
    if (!r.ok) return hong('tải tệp thoại hỏng');
    bytes = new Uint8Array(await r.arrayBuffer());
  } catch {
    return hong('tải tệp thoại hỏng');
  }
  if (!env.AI) return hong('máy nghe chưa được bật');
  const nhac = 'Chép nguyên văn tiếng Việt có dấu, có thể lẫn tiếng Anh, mã đơn, mã thẻ, mã lựa chọn kiểu 1A 2B.';
  for (const model of ds(env.THOAI_MODELS || '@cf/openai/whisper-large-v3-turbo,@cf/openai/whisper')) {
    try {
      await demLuotAI(env);
      let out;
      if (model.includes('large-v3-turbo')) {
        let b64 = '';
        for (let i = 0; i < bytes.length; i += 0x8000) b64 += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
        out = await env.AI.run(model, { audio: btoa(b64), language: 'vi', task: 'transcribe', initial_prompt: nhac });
      } else {
        out = await env.AI.run(model, { audio: [...bytes] });
      }
      const chu = String(out?.text || '').trim();
      return chu ? { dong: `${dau} ${chu}`, loi: null } : hong('không nghe ra lời nào');
    } catch (e) {
      console.log('nghe hỏng', model, String(e));
    }
  }
  return hong('máy nghe đang bận hoặc hết lượt');
}

async function demLuotAI(env) {
  const k = 'ai_luot:' + ngayVN(nowS());
  await env.DB.prepare('INSERT INTO bnv_moc(khoa, gia_tri) VALUES(?,1) ON CONFLICT(khoa) DO UPDATE SET gia_tri=gia_tri+1').bind(k).run();
}

// ---------- câu lệnh ----------
function lenhCua(text, botTen) {
  const r = LENH_RE.exec(String(text || '').trim());
  if (!r) return null;
  if (r[2] && r[2].toLowerCase() !== botTen) return null;   // /viec@bot_khac → không phải lệnh của mình
  return { lenh: r[1].toLowerCase(), du: (r[3] || '').trim() };
}

function laLenhCli(m, botTen) {
  const rep = m.reply_to_message;
  const repChu = String(rep?.text ?? rep?.caption ?? '');
  return lenhCua(m.text ?? m.caption, botTen)?.lenh === 'clitell' || (!!rep?.from?.is_bot && DAU_CLI.some((d) => repChu.startsWith(d)));
}

function linkTin(chatId, mid) {
  const s = String(chatId);
  return s.startsWith('-100') ? `https://t.me/c/${s.slice(4)}/${mid}` : '';
}

// INSERT viec cấp mã MAX(stt)+1 theo NGÀY của giao_luc (giờ VN) — không bao giờ theo now().
function sqlTaoViec(env, v) {
  const ngay = v.ngay || ngayVN(v.giao_luc || nowS());
  const t = nowS();
  return env.DB.prepare(
    `INSERT INTO bnv_viec(ma, ngay, stt, tieu_de, noi_dung, nguoi_giao, giao_luc, trang_thai, tin_goc, tao_luc, cap_nhat)
     SELECT '${TIEN_TO}-'||?1||'-'||printf('%02d', COALESCE(MAX(stt),0)+1), ?1, COALESCE(MAX(stt),0)+1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?8
     FROM bnv_viec WHERE ngay=?1 RETURNING ma`
  ).bind(ngay, v.tieu_de, v.noi_dung || '', v.nguoi_giao ?? null, v.giao_luc ?? t, v.trang_thai || 'cho-xac-nhan', v.tin_goc ?? null, t);
}

function sqlTin(env, r, upsert = false) {
  const cot = 'chat_id, message_id, luc, tu_id, tu_ten, la_bot, noi_dung, reply_to, media_group, anh, ma_viec, raw, nhan_luc, can_bao';
  const maExpr = r.ma_viec_moi ? `(SELECT ma FROM bnv_viec WHERE ngay=?15 ORDER BY stt DESC LIMIT 1)` : '?11';
  const sau = upsert
    ? ` ON CONFLICT(chat_id, message_id) DO UPDATE SET noi_dung=excluded.noi_dung, ma_viec=excluded.ma_viec,
         can_bao=excluded.can_bao, raw=excluded.raw`
    : ' ON CONFLICT(chat_id, message_id) DO NOTHING';
  const st = env.DB.prepare(
    `INSERT INTO bnv_tin(${cot}) VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,${maExpr},?12,?13,?14)${sau}`
  );
  const b = [String(r.chat_id), r.message_id, r.luc, r.tu_id ?? null, r.tu_ten ?? null, r.la_bot ? 1 : 0, r.noi_dung || '',
    r.reply_to ?? null, r.media_group ?? null, r.anh ?? null, r.ma_viec ?? null, r.raw ?? null, nowS(), r.can_bao ? 1 : 0];
  if (r.ma_viec_moi) b.push(r.ma_viec_moi);
  return st.bind(...b);
}

// ---------- webhook ----------
async function webhook(req, env, ctx) {
  const sec = env.TG_WEBHOOK_SECRET;
  if (!sec || req.headers.get('x-telegram-bot-api-secret-token') !== sec) return new Response('unauthorized', { status: 401 });
  let upd;
  try {
    upd = await req.json();
  } catch {
    return OK();
  }
  if (upd.message_reaction) return OK();   // khai để Telegram gửi cảm xúc; bản gọn chưa dùng
  const m = upd.message || upd.edited_message;
  if (!m || !m.chat || !m.from) return OK();
  const ch = cauHinh(env);
  const chat = String(m.chat.id);
  const rieng = m.chat.type === 'private';
  // Người lạ gõ /clitell ở chat riêng: đáp một dòng từ chối (không lưu) thay vì im — người gõ biết lệnh không dành cho mình.
  if (rieng && String(m.from.id) !== ch.chu && !m.from.is_bot && !upd.edited_message && laLenhCli(m, ch.botTen))
    return json(traLoi(chat, m.message_id, CAU_CLI_CHI_CHU));
  if (rieng ? String(m.from.id) !== ch.chu : !ch.noiBo.includes(chat)) return OK();   // người lạ / nhóm ngoài danh sách: bỏ, không lưu
  try {
    const t = !upd.edited_message ? thoaiCua(m) : null;
    const coViec = rieng || m.reply_to_message?.from?.is_bot;
    if (t && !String(m.text || '').trim() && coViec) {
      // Luật 4b.5: trả 200 ngay, nghe nền. Lưu tin thô trước để Telegram gửi lại không nghe hai lần.
      const r = await sqlTin(env, coTin(m, `🎤 (thoại ${dongHo(t.giay)}) đang nghe…`, 0)).run();
      if (r.meta.changes > 0) ctx.waitUntil(ngheRoiXuLy(env, ctx, m, t));
      return OK();
    }
    const kq = await xuLy(env, ctx, m, { sua: !!upd.edited_message });
    return kq.traLoi ? json(kq.traLoi) : OK();
  } catch (e) {
    console.log('webhook lỗi', String(e?.stack || e));
    return new Response('loi kho', { status: 500 });   // Telegram gửi lại
  }
}

async function ngheRoiXuLy(env, ctx, m, t) {
  const kq = await ngheThoai(env, t);
  const m2 = { ...m, text: (kq.dong + (m.caption ? '\n' + m.caption : '')).trim(), _thoai_hong: !!kq.loi };
  delete m2.caption;
  try {
    const x = await xuLy(env, ctx, m2, { daNghe: true });
    if (x.traLoi) {
      const { method, ...body } = x.traLoi;
      await tg(env, method, body);
    }
  } catch (e) {
    console.log('xử lý thoại lỗi', String(e));
  }
  if (kq.loi) {
    const ch = cauHinh(env);
    const loi = `🎤 Thoại lúc nãy chưa nghe được (${kq.loi}) — nhờ gõ lại bằng chữ giúp em.`;
    const nguoi = String(m.from.id);
    if (nguoi !== ch.chu) await tg(env, 'sendMessage', { chat_id: nguoi, text: loi });
    await tg(env, 'sendMessage', { chat_id: ch.chu, text: loi });
  }
}

// Lượt nghe nền bị cắt giữa chừng (đã gặp khi thử) thì dòng thô kẹt «đang nghe…» — cron vớt lại, không để im.
async function ngheLai(env, ctx) {
  const rs = await env.DB.prepare(
    `SELECT raw FROM bnv_tin WHERE noi_dung LIKE '🎤 (thoại %) đang nghe…' AND nhan_luc < ? AND raw IS NOT NULL ORDER BY id LIMIT 3`
  ).bind(nowS() - 120).all();
  for (const r of rs.results || []) {
    const m = JSON.parse(r.raw);
    const t = thoaiCua(m);
    if (t) await ngheRoiXuLy(env, ctx, m, t);
  }
}

function coTin(m, noiDung, canBao, extra = {}) {
  return {
    chat_id: m.chat.id, message_id: m.message_id, luc: m.date || nowS(), tu_id: String(m.from.id),
    tu_ten: [m.from.first_name, m.from.last_name].filter(Boolean).join(' ') || m.from.username || '',
    la_bot: !!m.from.is_bot, noi_dung: noiDung, reply_to: m.reply_to_message?.message_id ?? null,
    media_group: m.media_group_id ?? null, anh: tepCua(m), raw: JSON.stringify(m).slice(0, 20000), can_bao: canBao, ...extra,
  };
}

function traLoi(chat_id, reply_to, text, extra = {}) {
  return { method: 'sendMessage', chat_id, text, parse_mode: 'HTML', reply_to_message_id: reply_to, ...extra };
}

async function xuLy(env, ctx, m, opt = {}) {
  const ch = cauHinh(env);
  const chat = String(m.chat.id);
  const rieng = m.chat.type === 'private';
  const tuId = String(m.from.id);
  const laSep = ch.sep.includes(tuId);
  const laChu = tuId === ch.chu;
  const laBot = !!m.from.is_bot;
  const text = String(m.text ?? m.caption ?? '');
  const coChu = text.trim() !== '' && !m._thoai_hong;
  const tep = tepCua(m);
  const t = nowS();
  const thoai = thoaiCua(m);
  // 4b.6: thoại ngoài luồng việc chỉ lưu, không tốn lượt nghe.
  const noiDung = text || (thoai ? `🎤 (thoại ${dongHo(thoai.giay)}) — chưa nghe vì ngoài luồng việc` : tep ? '[tin không có chữ]' : '');
  const db = env.DB;
  const run = (stmts) => db.batch(stmts);   // D1 batch = một giao dịch
  const phu = (p) => ctx.waitUntil(p);

  // 4.4 Sửa tin → chưa đọc lại, giữ bản trước.
  if (opt.sua) {
    const cu = await db.prepare('SELECT id, noi_dung FROM bnv_tin WHERE chat_id=? AND message_id=?').bind(chat, m.message_id).first();
    if (cu) {
      if (cu.noi_dung !== noiDung)
        await run([db.prepare(
          `UPDATE bnv_tin SET ban_truoc=noi_dung, noi_dung=?, sua_luc=?, raw=?,
             claude_doc_luc=CASE WHEN can_bao=1 THEN NULL ELSE claude_doc_luc END WHERE id=?`
        ).bind(noiDung, m.edit_date || t, JSON.stringify(m).slice(0, 20000), cu.id)]);
      return {};
    }
  }
  // Trùng (Telegram gửi lại) → bỏ. Lượt sau khi nghe thoại thì ghi đè dòng thô.
  if (!opt.daNghe) {
    const co = await db.prepare('SELECT 1 FROM bnv_tin WHERE chat_id=? AND message_id=?').bind(chat, m.message_id).first();
    if (co) return {};
  }
  const up = !!opt.daNghe;
  const ghiThuong = (canBao) => run([sqlTin(env, coTin(m, noiDung, canBao), up)]);
  if (laBot) {
    await ghiThuong(0);
    return {};
  }

  const lenh = lenhCua(text, ch.botTen);
  const rep = m.reply_to_message;
  const repBot = !!rep?.from?.is_bot;
  const repChu = String(rep?.text ?? rep?.caption ?? '');
  const nguon = rieng ? 'chat riêng chủ nhà' : `nhóm ${m.chat.title || chat}`;
  const tat = await mayTat(env);
  const dung = await tamDung(env);
  const giuc = tat || !!dung;   // 7f: lúc /pause bot trả người giục như lúc máy tắt (mục 7b)
  const chuDuoc = congChu(ch, m);
  const tenChu = esc(ch.tenChu);
  const cliLoi = (chu, loai = 'loi') => run([
    sqlTin(env, coTin(m, noiDung, 0), up),
    db.prepare('INSERT INTO bnv_clitell(chu, noi_tiep, chat_id, message_id, tao_luc, loai) VALUES(?,?,?,?,?,?) ON CONFLICT DO NOTHING')
      .bind(chu || '(không kèm lời — xem tin được Reply)', rep ? repChu.slice(0, 2000) : null, chat, m.message_id, t, loai),
  ]);
  const cauCli = async () => ((await canhNghe(env))
    ? '📨 CLI · Đã chuyển vào phiên Claude CLI đang chạy — phiên sẽ đọc trong khoảng 1 phút.'
    : '📨 CLI · Chưa có phiên nào đang nghe — tin đã lưu, sẽ được đọc khi mở phiên.');
  const dap = (s) => ({ traLoi: traLoi(chat, m.message_id, s) });

  // 7f — mọi lệnh của bảng đứng TRƯỚC luồng thẻ việc. Tin mở đầu bằng lệnh luôn là lệnh đó, kể cả Reply vào tin CLI /
  // tin gom / tin phương án (/viec /xoa tối thượng; Reply tin CLI bằng /… khác = gọi lệnh đó).
  if (lenh) {
    const l = dsLenh(ch.tenChu).find((x) => x.ten === lenh.lenh);
    const ten = '/' + l.ten;
    if (l.ai === 'chu' && !laChu) {
      await ghiThuong(0);
      if (l.ten === 'lam') return {};   // 7e.1: người khác gõ /lam → lưu, im
      return dap(['clitell', 'lamdi', 'tatmay', 'momay'].includes(l.ten)
        ? `📨 CLI · Lệnh ${ten} chỉ ${tenChu} dùng — lời này không chuyển vào phiên CLI.` : `ℹ Lệnh ${ten} chỉ ${tenChu} dùng.`);
    }
    if (l.ai === 'ds' && !(laChu || laSep)) {   // 4.6: người khác gõ /viec → nuốt, bot im
      await ghiThuong(0);
      return {};
    }
    if (l.ai === 'chu' && (l.noi === 'rieng' ? !rieng : !chuDuoc)) {
      await ghiThuong(0);
      return dap(`ℹ Lệnh ${ten} chỉ dùng trong ${l.noi === 'rieng' ? 'chat riêng với bot' : 'chat riêng với bot hoặc nhóm chính'}.`);
    }
    switch (l.ten) {
      case 'clitell': {   // 7d — lời CLI trả về đi theo chat_id + message_id của dòng bnv_clitell nên tự về đúng nơi gõ
        if (!lenh.du && !rep) {
          await ghiThuong(0);
          return dap('📨 CLI · Cách gõ: <b>/clitell lời nhắn</b>, hoặc Reply một tin bằng /clitell, hoặc Reply tiếp vào tin «📨 CLI ·» / «🤖 Phiên CLI:».');
        }
        await cliLoi(lenh.du);
        return dap(await cauCli());
      }
      case 'tatmay':
      case 'momay': {
        // Con canh không nghe → KHÔNG lưu chờ: một /tatmay cũ đọc lúc mở máy hôm sau sẽ dừng thợ sai lúc.
        if (!(await canhNghe(env))) {
          await ghiThuong(0);
          return dap(`📨 CLI · Chưa chuyển ${ten} — chưa có phiên Claude CLI nào đang nghe, lệnh không lưu chờ. Mở phiên rồi gõ lại.`);
        }
        await cliLoi(`${ten} — làm đúng .claude/commands/${l.ten}.md`, 'lenh_may');
        return dap(l.ten === 'tatmay'
          ? '📨 CLI · Đã chuyển /tatmay vào phiên Claude CLI đang chạy — phiên cất việc dở, dừng thợ rồi báo lại; chờ báo xong hãy tắt máy.'
          : '📨 CLI · Đã chuyển /momay vào phiên Claude CLI đang chạy — phiên đọc sổ, chạy tiếp việc dở rồi báo lại.');
      }
      case 'lamdi': {
        await ghiThuong(0);
        return dap((await lamDi(env, { chat, mid: m.message_id })).text);
      }
      case 'pause': {
        await run([sqlTin(env, coTin(m, noiDung, 0), up), ...(dung ? [] : [datMoc(env, 'tam_dung', t)])]);
        return dap(dung
          ? `⏸ Máy đã đang tạm dừng từ ${gioVN(dung)} — gõ /khoidong để chạy lại.`
          : `⏸ Đã tạm dừng máy tự làm việc tới /khoidong hoặc ${GIO_KHOI_DONG}h sáng. Việc mới vẫn ghi thẻ; việc đang chạy không bị cắt.`);
      }
      case 'khoidong': {
        const k = await khoiDong(env, await mucCho(env), `chủ nhà /khoidong ở ${nguon}`);
        await run([sqlTin(env, coTin(m, noiDung, 0), up), datMoc(env, 'tam_dung', 0), ...k.st]);
        return dap((dung ? '▶ Đã gỡ tạm dừng — máy tự làm việc lại.' : '▶ Máy đang không tạm dừng.')
          + (k.khoi_dong.length ? ` Đã cho làm: <b>${k.khoi_dong.join(', ')}</b>.` : ' Không có việc nào chờ khởi động.')
          + (tat ? (rieng ? ' Máy nhà đang tắt — mở máy là làm bù.' : ' Hệ thống đang nhiều việc, sẽ làm bù ngay khi rảnh.') : ''));
      }
      case 'khac':
      case 'cho': {
        await ghiThuong(0);
        const x = await guiDanhSach(env, l.ten, chat, m.message_id);
        return x ? dap(x) : {};
      }
      case 'help': {
        await ghiThuong(0);
        const du = rieng && laChu;   // chủ nhà chat riêng thấy đủ, nơi khác chỉ lệnh chung
        const nhom = {};
        for (const x of dsLenh(ch.tenChu).filter((x) => du || x.ai !== 'chu')) (nhom[x.nhom] ||= []).push(`/${x.ten} — ${esc(x.mo_ta)}`);
        return dap(Object.entries(nhom).map(([k, v]) => `<b>${k}</b>\n${v.join('\n')}`).join('\n\n')
          + (du ? '' : `\n\nLệnh của ${tenChu} xem trong chat riêng với bot.`));
      }
      case 'xoa': {   // 7f — tối thượng như /viec; Reply /xoa trần chỉ khi tin gắn ĐÚNG một thẻ, không đoán
        let mas = [];
        if (lenh.du) mas = [...lenh.du.matchAll(/(?:(?:oHa|Task)-)?(\d{8}-\d{2,3})/gi)].map((x) => `${TIEN_TO}-${x[1]}`);
        else if (rep) {
          const r = await db.prepare('SELECT ma_viec FROM bnv_tin WHERE chat_id=? AND message_id=?').bind(chat, rep.message_id).first();
          const trongChu = [...new Set([...repChu.matchAll(new RegExp(MA_RE.source, 'g'))].map((x) => doiMa(x[0])))];
          mas = r?.ma_viec ? [r.ma_viec] : trongChu.length === 1 ? trongChu : [];
        }
        if (!mas.length) {
          await ghiThuong(0);
          return dap('ℹ Không xác định được đúng một thẻ — gõ <b>/xoa oHa-ddmmyyyy-NN</b>, hoặc Reply /xoa vào tin của đúng một thẻ.');
        }
        const x = await huyThe(env, mas, `chủ nhà /xoa ở ${nguon}`);
        await run([sqlTin(env, coTin(m, noiDung, 0), up), ...x.st]);
        return dap(x.text);
      }
      case 'lam': {   // 7e — trần (không mã, không Reply) = mở lượt duyệt; /lam <mã> · /lam tatca · Reply /lam = cho làm thẳng
        const dungChu = dung ? ' Máy đang tạm dừng (/pause) — gõ /khoidong để máy chạy.' : '';
        if (!lenh.du && !rep) {
          const x = await dlYeuCau(env, chat, m.message_id, rieng, tat);
          await run([sqlTin(env, coTin(m, noiDung, 0), up), ...x.st]);
          return dap(x.text + dungChu);
        }
        let mas = [];
        if (/^(tatca|tất cả)$/i.test(lenh.du)) mas = await mucCho(env);
        else if (lenh.du) mas = [...lenh.du.matchAll(/(?:(?:oHa|Task)-)?(\d{8}-\d{2,3})/gi)].map((x) => `${TIEN_TO}-${x[1]}`);
        else {
          const r = await db.prepare('SELECT ma_viec FROM bnv_tin WHERE chat_id=? AND message_id=?').bind(chat, rep.message_id).first();
          const ma = r?.ma_viec || maTrongChu(repChu);
          if (ma) mas = [ma];
        }
        if (!mas.length) {
          await ghiThuong(0);
          return dap(lenh.du ? 'ℹ Không thấy mã việc nào trong lệnh — gõ <b>/lam oHa-ddmmyyyy-NN</b> hoặc <b>/lam tatca</b>.' : 'ℹ Không có việc nào đang chờ để cho làm.');
        }
        const k = await khoiDong(env, mas, `chủ nhà /lam ở ${nguon}`);
        await run([sqlTin(env, coTin(m, noiDung, 0, { ma_viec: mas.length === 1 ? mas[0] : null }), up), ...k.st]);
        return dap((k.khoi_dong.length ? `▶ Đã cho làm: <b>${k.khoi_dong.join(', ')}</b>.` : '▶ Không khởi động việc nào.')
          + (k.bo_qua.length ? ` Không còn chờ nên bỏ qua: ${k.bo_qua.join(', ')}.` : '')
          + (k.khoi_dong.length && tat ? (rieng ? ' Máy nhà đang tắt — mở máy là làm.' : ' Hệ thống đang nhiều việc, sẽ làm ngay khi rảnh.') : '')
          + dungChu);
      }
      case 'viec': {   // 4.6 — mọi nhóm có bot + chat riêng chủ nhà (bảng 7f); tối thượng
        let nd = lenh.du;
        let tepViec = tep;
        if (!nd && rep) {
          nd = repChu || (tepCua(rep) ? '[tệp đính kèm]' : '');
          tepViec = tepViec || tepCua(rep);
        }
        if (!nd) {
          await ghiThuong(0);
          return { traLoi: traLoi(chat, m.message_id, `${DAU_FORCE} (chữ + ảnh/tệp nếu có), em lên thẻ ngay.`, { reply_markup: { force_reply: true, selective: true } }) };
        }
        return taoViecTuTin(env, ctx, m, nd, tepViec, nguon, laSep, tat, up, dung);
      }
    }
  }

  // 7d — Reply tiếp vào tin bot của luồng CLI (không gõ lệnh) = lời mới, chỉ chủ nhà qua cổng chung.
  // Người khác Reply tin luồng này không phải lời CLI → để luồng sau xử như cũ (7d.1).
  if (repBot && chuDuoc && DAU_CLI.some((d) => repChu.startsWith(d))) {
    await cliLoi(text);
    return dap(await cauCli());
  }

  // 7e — chủ nhà Reply tin phương án duyệt lượt (chat riêng): đứng TRƯỚC luồng Reply tin có mã.
  if (rieng && laChu && repBot) {
    const dlt = await db.prepare('SELECT * FROM bnv_duyet_luot_tin WHERE chat_id=? AND message_id=?').bind(chat, rep.message_id).first();
    if (dlt) {
      const x = await dlTraLoi(env, m, dlt, m._thoai_hong);
      await run([sqlTin(env, coTin(m, noiDung, 0), up), ...x.st]);
      return { traLoi: traLoi(chat, m.message_id, x.text) };
    }
  }

  if (repBot && chuDuoc) {
    // 7f — Reply tin danh sách (/khac /cho /lamdi): tin tóm cần «#số lời», tin một thẻ thì cả tin là lời. Ghi như lời chủ
    // quyết hộ, bật cờ chưa đọc để con canh gọi phiên dậy (đường THẺ).
    const d = await db.prepare('SELECT loai, ds FROM bnv_danh_sach WHERE chat_id=? AND message_id=?').bind(chat, rep.message_id).first();
    if (d) {
      const mas = JSON.parse(d.ds || '[]');
      let ma = null;
      let loi = noiDung;
      if (d.loai.endsWith('-the') && mas.length === 1) ma = mas[0];
      else {
        const r = /^#\s*(\d{1,3})\s*[:.)\-–]?\s*([\s\S]+)$/u.exec(text.trim());
        if (r && mas[Number(r[1]) - 1]) [ma, loi] = [mas[Number(r[1]) - 1], r[2].trim()];
      }
      if (!ma) {
        await ghiThuong(0);
        return dap('ℹ Gõ <b>#số lời</b> (vd #2 cứ làm theo 1A) — số theo danh sách, hoặc Reply thẳng tin của thẻ.');
      }
      const v = await db.prepare('SELECT ma, trang_thai, nguon, chuyen_sang FROM bnv_viec WHERE ma=?').bind(ma).first();
      if (!v) {
        await ghiThuong(0);
        return dap(`Chưa ghi được vào thẻ — không tìm thấy thẻ ${esc(ma)}.`);
      }
      return ghiVaoThe(env, ctx, m, v, { coChu, laSep, laChu, tat: giuc, up, noiDung: loi, canBao: 1, quyetHo: true });
    }
    // 7f — chủ Reply «nhầm / huỷ / xoá» vào dòng «✅ Đã nhận» trong 10 phút sau /viec = tự huỷ thẻ vừa tạo.
    if (repChu.startsWith('✅ Đã nhận') && HUY_NHAM_RE.test(text.normalize('NFC').trim())) {
      const ma = maTrongChu(repChu);
      const v = ma && (await db.prepare('SELECT tao_luc FROM bnv_viec WHERE ma=?').bind(ma).first());
      if (v && t - v.tao_luc <= HUY_NHAM_GIAY) {
        const x = await huyThe(env, [ma], `chủ nhà Reply «${text.trim()}» trong 10 phút sau /viec`);
        await run([sqlTin(env, coTin(m, noiDung, 0, { ma_viec: ma }), up), ...x.st]);
        return dap(x.text);
      }
    }
  }

  if (repBot) {
    // ForceReply của /viec trần → tạo thẻ.
    if (repChu.startsWith(DAU_FORCE) && (laSep || laChu)) {
      return taoViecTuTin(env, ctx, m, coChu ? text : '[tin không có chữ]', tep, nguon, laSep, tat, up, dung);
    }
    // 4.1 Reply vào tin bot → tra mã theo message_id trong kho, không có thì đọc mã trong chữ; tin máy không mã → thẻ con canh trưởng.
    const r = await db.prepare('SELECT ma_viec FROM bnv_tin WHERE chat_id=? AND message_id=?').bind(chat, rep.message_id).first();
    const ma = r?.ma_viec || maTrongChu(repChu) || (await maCanh(env));
    let v = await db.prepare('SELECT ma, trang_thai, nguon, chuyen_sang FROM bnv_viec WHERE ma=?').bind(ma).first();
    // 7e: việc phụ đã gộp → Reply tin cũ của nó vào việc chính.
    if (v?.chuyen_sang) v = (await db.prepare('SELECT ma, trang_thai, nguon, chuyen_sang FROM bnv_viec WHERE ma=?').bind(v.chuyen_sang).first()) || v;
    if (!v) {
      await ghiThuong(laSep ? 1 : 0);
      return { traLoi: traLoi(chat, m.message_id, `Chưa ghi được vào thẻ — không tìm thấy thẻ ${esc(ma)}, em đã lưu tin để xử lý tay.`) };
    }
    return ghiVaoThe(env, ctx, m, v, { coChu, laSep, laChu, tat: giuc, up, noiDung });
  }

  // 4.3 Album cùng media_group với tin đã gắn → gắn cùng việc, không đáp.
  if (m.media_group_id) {
    const r = await db.prepare('SELECT ma_viec FROM bnv_tin WHERE chat_id=? AND media_group=? AND ma_viec IS NOT NULL LIMIT 1')
      .bind(chat, m.media_group_id).first();
    if (r) {
      await run([sqlTin(env, coTin(m, noiDung, laSep ? 1 : 0, { ma_viec: r.ma_viec }), up)]);
      return {};
    }
  }

  // 4.10 Tệp rời / chú thích ngay sau tin việc trong chat riêng chủ nhà → gắn thẻ đó.
  if (rieng && (laSep || laChu)) {
    const truoc = await db.prepare(
      `SELECT ma_viec, anh, nhan_luc FROM bnv_tin WHERE chat_id=? AND tu_id=? AND la_bot=0 AND message_id<? ORDER BY message_id DESC LIMIT 1`
    ).bind(chat, tuId, m.message_id).first();
    const gan = truoc?.ma_viec && truoc.ma_viec !== (await maCanh(env));
    const laTepRoi = tep && !text.trim() && gan && t - truoc.nhan_luc <= TEP_ROI_GIAY;
    const laChuThich = !tep && coChu && gan && truoc.anh && t - truoc.nhan_luc <= CHU_THICH_GIAY;
    if (laTepRoi || laChuThich) {
      const v = await db.prepare('SELECT ma, trang_thai, nguon FROM bnv_viec WHERE ma=?').bind(truoc.ma_viec).first();
      if (v) {
        // Gửi liền nhiều tệp: chỉ tệp đầu có dòng xác nhận, tệp sau chỉ ✍.
        const imLang = laTepRoi && truoc.anh && t - truoc.nhan_luc <= 60;
        return ghiVaoThe(env, ctx, m, v, { coChu: false, laSep, laChu, tat: giuc, up, noiDung, imLang, doiTrangThai: false });
      }
    }
  }

  // 4.5 Tin thường KHÔNG thành việc: chỉ lưu + cờ chưa đọc (tin sếp có nội dung).
  await ghiThuong(laSep && noiDung ? 1 : 0);
  return {};
}

async function taoViecTuTin(env, ctx, m, nd, tep, nguon, laSep, tat, up, dung = 0) {
  const chat = String(m.chat.id);
  const giao = m.date || nowS();
  const link = linkTin(chat, m.message_id);
  const dong1 = nd.split('\n')[0].trim();
  const tieuDe = dong1.length > 70 ? dong1.slice(0, 69) + '…' : dong1;
  const moTa = `${nd}\n\nNguồn: từ ${nguon}${link ? ' · ' + link : ''} · người giao ${m.from.first_name || m.from.id}`;
  const ngay = ngayVN(giao);
  const kq = await env.DB.batch([
    sqlTaoViec(env, { ngay, tieu_de: tieuDe || 'Việc mới', noi_dung: moTa, nguoi_giao: String(m.from.id), giao_luc: giao, tin_goc: m.message_id }),
    sqlTin(env, { ...coTin(m, String(m.text ?? m.caption ?? nd), laSep ? 1 : 0), anh: tep, ma_viec_moi: ngay }, up),
  ]);
  const ma = kq[0].results[0].ma;
  ctx.waitUntil(tha(env, chat, m.message_id, '✍'));
  const them = tat ? ' (máy đang tắt, mở máy sẽ chạy)' : dung ? ` (máy đang tạm dừng — chạy khi /khoidong hoặc ${GIO_KHOI_DONG}h sáng)` : '';
  return { traLoi: traLoi(chat, m.message_id, `✅ Đã nhận · ${ma} · Đã lên thẻ${them}`) };
}

async function ghiVaoThe(env, ctx, m, v, o) {
  const chat = String(m.chat.id);
  const t = nowS();
  const st = [sqlTin(env, coTin(m, o.noiDung, o.canBao ?? (o.laSep || !o.laChu ? 1 : 0), { ma_viec: v.ma }), o.up)];
  // Chỉ người (không phải chủ nhà thuần) trả lời mới đổi trạng thái chờ → đã trả lời; thẻ đã Xong thì mở lại.
  if (o.doiTrangThai !== false && (o.laSep || !o.laChu || o.quyetHo) && o.coChu && v.nguon !== 'he-thong' && ['cho-sep-tra-loi', 'xong', 'cho-xac-nhan'].includes(v.trang_thai)) {
    const moi = v.trang_thai === 'cho-xac-nhan' ? 'cho-xac-nhan' : 'sep-da-tra-loi';
    st.push(env.DB.prepare('UPDATE bnv_viec SET trang_thai=?, cap_nhat=? WHERE ma=?').bind(moi, t, v.ma));
  } else {
    st.push(env.DB.prepare('UPDATE bnv_viec SET cap_nhat=? WHERE ma=?').bind(t, v.ma));
  }
  let cauMacDinh = false;
  if (o.tat) {
    const k = 'mac_dinh:' + v.ma;
    const truoc = await docMoc(env, k);
    if (!truoc || t - truoc >= MAC_DINH_CACH_GIAY) {
      cauMacDinh = true;
      st.push(datMoc(env, k, t));
    }
  }
  await env.DB.batch(st);
  // 4.9: tin có chữ mang mã lựa chọn → ❤; còn lại ✍. Tin không chữ không bao giờ là câu trả lời.
  const chon = o.coChu && /\b\d[A-Da-d]\b/.test(String(m.text ?? m.caption ?? ''));
  ctx.waitUntil(tha(env, chat, m.message_id, chon ? '❤' : '✍'));
  if (o.imLang) return {};
  if (o.tat) return cauMacDinh ? { traLoi: traLoi(chat, m.message_id, CAU_MAY_TAT) } : {};
  return { traLoi: traLoi(chat, m.message_id, `✍ Đã nhận · ${v.ma} · Đã ghi vào thẻ`) };
}

// ---------- 7e duyệt lượt /lam ----------
// Dòng máy tự ghi lên thẻ (chat 'may', la_bot=1). canBao=1 chỉ cho lệnh của chủ nhà cần gọi phiên dậy (cho làm).
let demMay = 0;
function dongMay(env, ma, noiDung, canBao = 0) {
  demMay = (demMay + 1) % 1000;
  return sqlTin(env, { chat_id: 'may', message_id: -(Date.now() * 1000 + demMay), luc: nowS(), tu_ten: 'máy', la_bot: 1,
    noi_dung: String(noiDung), ma_viec: ma, can_bao: canBao });
}

async function mucCho(env) {
  const r = await env.DB.prepare('SELECT ma FROM bnv_viec WHERE trang_thai=? AND nguon IS NULL ORDER BY ngay, stt').bind(TT_CHO).all();
  return (r.results || []).map((x) => x.ma);
}
async function moKhac(env) {
  const r = await env.DB.prepare(
    `SELECT ma FROM bnv_viec WHERE trang_thai IN ('cho-sep-tra-loi','sep-da-tra-loi','dang-lam') AND nguon IS NULL ORDER BY ngay, stt`
  ).all();
  return (r.results || []).map((x) => x.ma);
}

function dlDoc(r) {
  if (!r) return null;
  const j = (s, md) => { try { return s ? JSON.parse(s) : md; } catch { return md; } };
  return { ...r, phuong_an: j(r.phuong_an, null), lich_su: j(r.lich_su, []), ket_qua: j(r.ket_qua, null) };
}
const dlCo = async (env, id) => dlDoc(await env.DB.prepare('SELECT * FROM bnv_duyet_luot WHERE id=?').bind(Number(id)).first());
const dlMo = async (env) => dlDoc(await env.DB.prepare(
  `SELECT * FROM bnv_duyet_luot WHERE trang_thai IN (${DL_MO.map(() => '?').join(',')}) ORDER BY id DESC LIMIT 1`
).bind(...DL_MO).first());
function dlDoi(env, id, o) {
  const k = Object.keys(o);
  const v = k.map((x) => (o[x] !== null && typeof o[x] === 'object' ? JSON.stringify(o[x]) : o[x]));
  return env.DB.prepare(`UPDATE bnv_duyet_luot SET ${k.map((x) => x + '=?').join(', ')}, cap_nhat=? WHERE id=?`).bind(...v, nowS(), id);
}

// /lam trần. Lượt đang mở → báo tình trạng, không đẻ lượt thứ hai. Máy chủ KHÔNG phân loại (không AI) — chỉ mở lượt cho máy nhà.
async function dlYeuCau(env, chat, mid, rieng, tat) {
  const d = await dlMo(env);
  if (d) {
    let s = `⏳ Lượt <b>DL${d.id}</b> đang mở${d.ban ? ` (bản ${d.ban})` : ''} — ${DL_TEN_TT[d.trang_thai]}.`;
    if (d.trang_thai === 'cho-chu-nha') s += ' Anh Reply tin phương án mới nhất trong chat riêng: gõ <b>OK</b> hoặc góp ý.';
    return { st: [], text: s };
  }
  const n = (await mucCho(env)).length;
  if (!n) return { st: [], text: '▶ Không có việc nào đang chờ duyệt.' };
  // id lượt = MAX+1 tính trước để câu đáp mang đúng số; UNIQUE id chặn hai lượt cùng số nếu hai tin tới cùng lúc.
  const r = await env.DB.prepare('SELECT COALESCE(MAX(id),0)+1 AS id FROM bnv_duyet_luot').first();
  const id = r.id;
  const st = [env.DB.prepare('INSERT INTO bnv_duyet_luot (id, trang_thai, yeu_cau_chat, yeu_cau_mid, tao_luc, cap_nhat) VALUES (?,?,?,?,?,?)')
    .bind(id, 'cho-may', chat, mid, nowS(), nowS())];
  if (tat)   // trong nhóm sếp đọc được: không nói «máy tắt», chỉ nói đang nhiều việc
    return { st, text: `📝 Đã ghi yêu cầu duyệt lượt <b>DL${id}</b> (${n} việc đang chờ). `
      + (rieng ? 'Máy nhà đang tắt — mở máy là duyệt ngay, yêu cầu không mất.' : 'Hệ thống đang nhiều việc, sẽ duyệt ngay khi rảnh — yêu cầu không mất.') };
  return { st, text: `⏳ Đang duyệt lượt <b>DL${id}</b> — ${n} việc đang chờ. Phương án (làm được ngay · cần hỏi lại · gộp) sẽ gửi vào `
    + `chat riêng anh ${esc(cauHinh(env).tenChu)} trong vài phút; anh OK hết thì máy mới làm.` };
}

const dlDem = (pa) => [['lam', 'làm ngay'], ['hoi', 'hỏi lại'], ['gop', 'gộp'], ['bo', 'bỏ'], ['de_sau', 'để sau']]
  .map(([k, t]) => [(pa?.[k] || []).length, t]).filter(([n]) => n).map(([n, t]) => `${n} ${t}`).join(' · ') || 'không có mục nào';

// Chủ nhà Reply tin phương án. Trả { st, text }.
async function dlTraLoi(env, m, tin, hong) {
  const d = await dlCo(env, tin.dl_id);
  const e = `<b>DL${d.id}</b>`;
  const chu = String(m.text ?? m.caption ?? '').normalize('NFC').trim();
  if (['da-ok', 'dang-ap', 'da-ap', 'huy'].includes(d.trang_thai))
    return { st: [], text: `ℹ Lượt ${e} ${DL_TEN_TT[d.trang_thai]} — tin này không đổi gì. Muốn duyệt lại thì gõ /lam.` };
  if (Number(tin.ban) < Number(d.ban))
    return { st: [], text: `ℹ Tin anh Reply là bản ${tin.ban} (cũ) của ${e} — anh Reply <b>bản ${d.ban}</b> mới nhất.` };
  if (hong) return { st: [], text: `🎤 Thoại chưa nghe được — anh gõ lại bằng chữ (OK hoặc góp ý) cho ${e} giúp em.` };
  const ls = d.lich_su;
  const loi = chu.replace(/^🎤 \(thoại [\d:]+\)\s*/, '');
  if (d.trang_thai === 'cho-chu-nha' && DL_OK_RE.test(loi)) {
    ls.push({ ban: Number(d.ban), luc: nowS(), ok: chu });
    return { st: [dlDoi(env, d.id, { trang_thai: 'da-ok', lich_su: ls })],
      text: `✅ Đã duyệt ${e} bản ${d.ban} — máy bắt đầu làm: ${dlDem(d.phuong_an)}.` + ((await mayTat(env)) ? ' Máy nhà đang tắt — mở máy là làm.' : '') };
  }
  const c = chu || '(ảnh/tệp)';
  const gop = d.trang_thai === 'gop-y' && d.gop_y ? d.gop_y + '\n' + c : c;   // góp tiếp trước khi có bản mới
  ls.push({ ban: Number(d.ban), luc: nowS(), gop_y: c });
  return { st: [dlDoi(env, d.id, { trang_thai: 'gop-y', gop_y: gop.slice(0, 4000), lich_su: ls })],
    text: `📝 Đã ghi góp ý cho ${e} bản ${d.ban} — máy sửa phương án rồi gửi <b>bản ${Number(d.ban) + 1}</b> vào đây.` };
}

// Khởi động (cho làm) đúng các mã còn đang chờ. Trả { st, khoi_dong, bo_qua }.
async function khoiDong(env, mas, nguon) {
  const st = []; const kd = []; const bq = [];
  for (const ma of [...new Set(mas)]) {
    const v = await env.DB.prepare('SELECT trang_thai, nguon FROM bnv_viec WHERE ma=?').bind(ma).first();
    if (!v || v.nguon || v.trang_thai !== TT_CHO) { bq.push(ma); continue; }
    st.push(env.DB.prepare('UPDATE bnv_viec SET trang_thai=?, cap_nhat=? WHERE ma=? AND trang_thai=?').bind('dang-lam', nowS(), ma, TT_CHO));
    st.push(dongMay(env, ma, `▶ Chủ nhà cho làm (${nguon})`, 1));
    kd.push(ma);
  }
  return { st, khoi_dong: kd, bo_qua: bq };
}

// ---------- 7f bộ lệnh chung ----------
// /xoa — xoá mềm: sang «huy» (bộ gọn = Xong + dấu huỷ), ẩn khỏi việc chờ / tin nhắc, lời chưa đọc gắn đã đọc; mở lại bằng CLI `chuyen`.
async function huyThe(env, mas, nguon) {
  const st = []; const huy = []; const bo = [];
  for (const ma of [...new Set(mas)]) {
    const v = await env.DB.prepare('SELECT trang_thai, nguon FROM bnv_viec WHERE ma=?').bind(ma).first();
    if (!v) { bo.push(`${ma} (không có)`); continue; }
    if (v.nguon) { bo.push(`${ma} (thẻ hệ thống, không huỷ)`); continue; }
    if (TT_DONG.includes(v.trang_thai)) { bo.push(`${ma} (đã ${v.trang_thai === 'huy' ? 'huỷ' : 'đóng'})`); continue; }
    st.push(env.DB.prepare('UPDATE bnv_viec SET trang_thai=?, cap_nhat=? WHERE ma=? AND trang_thai=?').bind('huy', nowS(), ma, v.trang_thai));
    st.push(env.DB.prepare('UPDATE bnv_tin SET claude_doc_luc=? WHERE ma_viec=? AND claude_doc_luc IS NULL').bind(nowS(), ma));
    st.push(dongMay(env, ma, `✖ Huỷ thẻ (${nguon}) — trạng thái trước: ${v.trang_thai}; mở lại: chuyen --ma ${ma} --tt ${v.trang_thai}`));
    huy.push(ma);
  }
  const text = (huy.length ? `🗑 Đã huỷ thẻ <b>${huy.join(', ')}</b> — ẩn khỏi việc đang chờ và tin nhắc, mở lại được.` : '🗑 Không huỷ thẻ nào.')
    + (bo.length ? ` Bỏ qua: ${esc(bo.join(', '))}.` : '');
  return { st, huy, text };
}

// Mỗi thẻ một tin vào chat; tin ghi vào kho kèm mã thẻ + bảng danh sách → Reply vào là lời chủ ghi đúng thẻ.
async function guiTinThe(env, chatId, hang, loai, replyTo) {
  let so = 0;
  for (const h of hang) {
    const r = await tg(env, 'sendMessage', { chat_id: chatId, text: h.html, parse_mode: 'HTML', link_preview_options: { is_disabled: true },
      ...(replyTo ? { reply_parameters: { message_id: replyTo, allow_sending_without_reply: true } } : {}) });
    if (!r.ok) { console.log('gửi tin thẻ hỏng', h.ma, r.description); continue; }
    await env.DB.batch([
      sqlTin(env, { chat_id: chatId, message_id: r.result.message_id, luc: r.result.date, tu_ten: 'bot', la_bot: 1, noi_dung: boThe(h.html), ma_viec: h.ma, can_bao: 0 }),
      env.DB.prepare('INSERT OR REPLACE INTO bnv_danh_sach(chat_id, message_id, loai, ds, tao_luc) VALUES(?,?,?,?,?)')
        .bind(String(chatId), r.result.message_id, loai + '-the', JSON.stringify([h.ma]), nowS()),
    ]);
    so++;
  }
  return so;
}

const trich = (s, n) => { const x = boThe(s).replace(/\s+/g, ' ').trim(); return x.length > n ? x.slice(0, n - 1) + '…' : x; };
const dauThe = (ma, tieuDe) => `<b>[${ma}] ${esc(trich(tieuDe, 70))}</b>`;

async function theTheo(env, tts) {
  const r = await env.DB.prepare(
    `SELECT v.ma, v.tieu_de, v.noi_dung, v.cap_nhat, v.trang_thai,
       (SELECT b.noi_dung FROM bnv_tin b WHERE b.ma_viec=v.ma AND b.la_bot=1 AND b.chat_id!='may' AND ${KHONG_DANH_SACH} ORDER BY b.id DESC LIMIT 1) AS bot_cuoi
     FROM bnv_viec v WHERE v.trang_thai IN (${tts.map(() => '?').join(',')}) AND v.nguon IS NULL ORDER BY v.cap_nhat`
  ).bind(...tts).all();
  return r.results || [];
}

// /khac · /cho — MÁY CHỦ TRẢ: một tin tóm (Reply «#số lời») + mỗi thẻ một tin, trần TRAN_THE_LUOT/lượt, gõ lại gửi tiếp.
async function guiDanhSach(env, loai, chat, mid) {
  const ch = cauHinh(env);
  const t = nowS();
  const nhom = loai === 'khac'
    ? [['Chờ người khác trả lời', await theTheo(env, ['cho-sep-tra-loi'])]]
    : [[`Chờ ${ch.tenChu} quyết / cho làm`, await theTheo(env, [TT_CHO])],
      ['Chờ người khác trả lời', await theTheo(env, ['cho-sep-tra-loi'])],
      ['Chờ dùng thử', null]];   // bộ trạng thái gọn (mục 3) không có cột «chờ dùng thử»
  const ds_ = nhom.flatMap(([ten, a]) => (a || []).map((v) => ({ ...v, nhomTen: ten })));
  if (!ds_.length) return loai === 'khac' ? 'ℹ Không có việc nào đang chờ người khác.' : 'ℹ Không có việc nào đang chờ.';
  const kTu = `ds_tiep:${loai}:${chat}`;
  const kLuc = `ds_luc:${loai}:${chat}`;
  let tu = (await docMoc(env, kTu)) || 0;
  if (tu >= ds_.length || t - ((await docMoc(env, kLuc)) || 0) > DS_HET_HAN_GIAY) tu = 0;
  if (tu === 0) {
    let stt = 0;
    const khoi = nhom.map(([ten, a]) => {
      if (a === null) return `<b>${esc(ten)}</b>: bộ trạng thái của oHa chưa có cột này`;
      const dong = a.map((v) => `#${++stt} ${v.ma} — ${esc(trich(v.tieu_de, 50))} (từ ${ngayGioVN(v.cap_nhat)})`);
      return `<b>${esc(ten)} (${a.length})</b>` + (dong.length ? '\n' + (dong.length > 30 ? [...dong.slice(0, 30), `…và ${dong.length - 30} thẻ nữa`] : dong).join('\n') : '');
    });
    const dau = loai === 'khac' ? `⏳ Việc chờ người khác — ${ds_.length} thẻ` : `📋 Việc đang chờ — ${ds_.length} thẻ`;
    const html = `<b>${dau}</b>\n\n${khoi.join('\n\n')}\n\n👉 ${esc(ch.tenChu)} Reply tin này: <b>#số lời</b> (vd #2 cứ làm theo 1A) — hoặc Reply tin từng thẻ.`;
    const r = await tg(env, 'sendMessage', { chat_id: chat, text: html, parse_mode: 'HTML', reply_parameters: { message_id: mid, allow_sending_without_reply: true } });
    if (!r.ok) return `Chưa gửi được danh sách — ${esc(r.description || 'Telegram lỗi')}.`;
    await env.DB.batch([
      sqlTin(env, { chat_id: chat, message_id: r.result.message_id, luc: r.result.date, tu_ten: 'bot', la_bot: 1, noi_dung: boThe(html), can_bao: 0 }),
      env.DB.prepare('INSERT OR REPLACE INTO bnv_danh_sach(chat_id, message_id, loai, ds, tao_luc) VALUES(?,?,?,?,?)')
        .bind(chat, r.result.message_id, loai, JSON.stringify(ds_.map((v) => v.ma)), t),
    ]);
  }
  const den = Math.min(tu + TRAN_THE_LUOT, ds_.length);
  await guiTinThe(env, chat, ds_.slice(tu, den).map((v, i) => ({ ma: v.ma, html: [
    dauThe(v.ma, v.tieu_de),
    `#${tu + i + 1} · ⏳ ${esc(v.nhomTen)} · từ ${ngayGioVN(v.cap_nhat)}`,
    v.bot_cuoi ? `Máy hỏi gần nhất: «${esc(trich(v.bot_cuoi, 160))}»` : `Nội dung: «${esc(trich(v.noi_dung, 160))}»`,
    `👉 Reply tin này: lời ${esc(ch.tenChu)} ghi vào thẻ`,
  ].join('\n') })), loai);
  await env.DB.batch([datMoc(env, kTu, den), datMoc(env, kLuc, t)]);
  const con = ds_.length - den;
  if (tu === 0 && !con) return null;
  return (tu ? `▶ Gửi tiếp thẻ #${tu + 1}–#${den} / ${ds_.length}.` : `▶ Đã gửi thẻ #1–#${den} / ${ds_.length}.`)
    + (con ? ` Còn ${con} thẻ — gõ lại /${loai} để gửi tiếp.` : ' Đã gửi hết.');
}

// Sổ dồn /lamdi = mọi lời NGƯỜI chưa mang cờ đã-đọc trên thẻ đang mở (thẻ còn chờ chủ nhà cho làm thì để /lam · /khoidong lo).
const SO_DON = `FROM bnv_tin t JOIN bnv_viec v ON v.ma=t.ma_viec
  WHERE t.la_bot=0 AND t.tu_id IS NOT NULL AND t.claude_doc_luc IS NULL AND v.trang_thai NOT IN ('xong','huy','da-chuyen','${TT_CHO}')
    AND (t.noi_dung NOT LIKE '/%' OR t.noi_dung LIKE '/viec%')`;

// /lamdi (chủ gõ) · lịch gom (tuLich). Gỡ cờ /pause → một dòng CLITELL `tong-hop` (chỉ khi con canh đang nghe; bản cũ chưa
// nhận thì thay) + bật cờ chưa đọc cho các lời đó để `moi` in ra có id → gửi chủ nhà mỗi thẻ một tin.
async function lamDi(env, o = {}) {
  const ch = cauHinh(env);
  const t = nowS();
  const st = [];
  const dung = await tamDung(env);
  if (o.tuLich && dung) return { text: 'bỏ lượt: đang tạm dừng' };
  if (!o.tuLich && dung) st.push(datMoc(env, 'tam_dung', 0));
  const go = !o.tuLich && dung ? ' Đã gỡ tạm dừng.' : '';
  const xong = async (text) => { if (st.length) await env.DB.batch(st); return { text }; };
  const rs = (await env.DB.prepare(`SELECT t.id, t.ma_viec, t.tu_ten, t.noi_dung, v.tieu_de ${SO_DON} ORDER BY t.id`).all()).results || [];
  if (!rs.length) return xong('📨 CLI · Không có trao đổi nào chưa làm trên các thẻ — sổ trống.' + go);
  const maxId = rs[rs.length - 1].id;
  // Lịch chỉ gom khi có lời mới từ lượt gom trước — không thì mỗi 2 giờ lại gửi chủ nhà cùng mấy tin thẻ cũ.
  if (o.tuLich && maxId <= ((await docMoc(env, 'lamdi_moc')) || 0)) return { text: 'bỏ lượt: không có lời mới' };
  const theo = {};
  for (const r of rs) (theo[r.ma_viec] ||= { tieu_de: r.tieu_de, loi: [] }).loi.push(r);
  const mas = Object.keys(theo);
  if (!(await canhNghe(env))) return xong(`📨 CLI · Sổ giữ nguyên (${rs.length} lời / ${mas.length} thẻ), CLI không nghe — chưa có phiên Claude CLI nào chạy con canh; mở phiên rồi gõ lại /lamdi.` + go);
  if (o.tuLich && (await env.DB.prepare(`SELECT 1 FROM bnv_clitell WHERE loai='tong-hop' AND nhan_luc IS NULL LIMIT 1`).first()))
    return { text: 'bỏ lượt: còn bản sổ dồn chưa nhận' };
  const ids = rs.map((r) => r.id);
  const chu = `/lamdi — SỔ DỒN: ${rs.length} lời chưa làm trên ${mas.length} thẻ (${mas.join(', ')}). Làm đúng .claude/commands/check-viec-sep.md `
    + `mục «Sổ dồn»: chạy moi lấy id rồi xử TỪNG mục (id kho: ${ids.slice(0, 60).join(',')}${ids.length > 60 ? ',…' : ''}).`;
  st.push(env.DB.prepare(`DELETE FROM bnv_clitell WHERE loai='tong-hop' AND nhan_luc IS NULL`));
  st.push(env.DB.prepare('INSERT INTO bnv_clitell(chu, chat_id, message_id, tao_luc, loai) VALUES(?,?,?,?,?)')
    .bind(chu, String(o.chat || 'may'), o.mid || -(Date.now() * 1000 + Math.floor(Math.random() * 1000)), t, 'tong-hop'));
  st.push(env.DB.prepare(`UPDATE bnv_tin SET can_bao=1 WHERE id IN (SELECT t.id ${SO_DON} AND t.id<=?)`).bind(maxId));
  st.push(datMoc(env, 'lamdi_moc', maxId));
  await env.DB.batch(st);
  const tenChu = esc(ch.tenChu);
  const so = await guiTinThe(env, ch.chu, mas.slice(0, TRAN_THE_LUOT).map((ma) => {
    const x = theo[ma];
    const dong = x.loi.slice(-3).map((r) => `• <b>${esc(r.tu_ten || 'người gửi')}</b>: «${esc(trich(r.noi_dung, 100))}»`);
    return { ma, html: [dauThe(ma, x.tieu_de), `🗂 ${x.loi.length} lời chưa làm — đã đẩy vào phiên Claude:`, ...dong,
      ...(x.loi.length > 3 ? [`…và ${x.loi.length - 3} lời trước đó`] : []), `👉 Reply tin này: lời ${tenChu} ghi vào thẻ`].join('\n') };
  }), 'lamdi');
  return { text: `📨 CLI · Đã đẩy sổ dồn ${rs.length} lời / ${mas.length} thẻ vào phiên Claude CLI đang chạy; gửi ${tenChu} ${so} tin thẻ trong chat riêng`
    + (mas.length > TRAN_THE_LUOT ? ` (${mas.length - TRAN_THE_LUOT} thẻ còn lại chỉ có trong phiên)` : '') + '.' + go };
}

// Lịch trên Cron Trigger */5 sẵn có (không thêm trigger): mỗi việc chạy một lần trong giờ đó, giành lượt bằng mốc.
async function lich(env, ts) {
  const gio = Number(gioVN(ts).slice(0, 2));
  const ngay = Number(ngayVN(ts));
  const lanDau = async (khoa, gt) => {
    if ((await docMoc(env, khoa)) === gt) return false;
    await datMoc(env, khoa, gt).run();
    return true;
  };
  if (gio === GIO_TAM_DUNG && (await lanDau('lich_tam_dung', ngay)) && !(await tamDung(env))) await datMoc(env, 'tam_dung', ts).run();
  if (gio === GIO_KHOI_DONG && (await lanDau('lich_khoi_dong', ngay))) await datMoc(env, 'tam_dung', 0).run();
  if (GIO_GOM.includes(gio) && (await lanDau('lich_gom', ngay * 100 + gio))) console.log('lịch gom /lamdi:', (await lamDi(env, { tuLich: true })).text);
}

// Menu «/» sinh từ dsLenh (cùng nguồn chữ /help), đặt QUA máy chủ — máy nhà không gọi Telegram thẳng.
function phamViMenu(env) {
  const ch = cauHinh(env);
  const L = dsLenh(ch.tenChu);
  const lay = (f) => L.filter(f).map((l) => ({ command: l.ten, description: l.mo_ta.slice(0, 256) }));
  return [
    ['mặc định', { type: 'default' }, lay((l) => l.ai === 'moi')],
    ['mọi nhóm', { type: 'all_group_chats' }, lay((l) => l.ai !== 'chu')],
    ['chat riêng chủ nhà', { type: 'chat', chat_id: Number(ch.chu) }, lay(() => true)],
    ['chủ nhà trong nhóm chính', { type: 'chat_member', chat_id: Number(ch.chatSep), user_id: Number(ch.chu) }, lay((l) => l.ai !== 'chu' || l.noi === 'chinh')],
  ];
}
async function datMenu(env, xem) {
  const kq = [];
  for (const [ten, scope, commands] of phamViMenu(env)) {
    const r = xem ? await tg(env, 'getMyCommands', { scope }) : await tg(env, 'setMyCommands', { scope, commands });
    kq.push({ ten, ok: !!r.ok, lenh: xem ? (r.result || []).map((c) => c.command) : commands.map((c) => c.command), ...(r.ok ? {} : { loi: r.description }) });
  }
  return { ok: kq.every((x) => x.ok), pham_vi: kq };
}

// Việc «của nhóm»: có tin ở một nhóm (không phải chat riêng chủ nhà / dòng máy).
async function viecTrongNhom(env, ma) {
  const r = await env.DB.prepare(`SELECT chat_id FROM bnv_tin WHERE ma_viec=? AND chat_id NOT IN (?, 'may') AND chat_id LIKE '-%' LIMIT 1`)
    .bind(ma, cauHinh(env).chu).first();
  return r?.chat_id || null;
}

// Soát phương án (tất định — thiếu là từ chối). Mọi việc đang chờ phải có mặt ĐÚNG MỘT lần.
async function dlSoat(env, pa) {
  const cho = await mucCho(env);
  const khac = await moKhac(env);
  const loi = []; const dem = {}; const chuan = Object.fromEntries(DL_NHOM.map((k) => [k, []]));
  const s = (x) => String(x ?? '').normalize('NFC').trim();
  if (!pa || typeof pa !== 'object' || Array.isArray(pa)) return [chuan, ['phương án phải là object {lam,hoi,gop,bo,de_sau}']];
  for (const k of Object.keys(pa)) if (!DL_NHOM.includes(k)) loi.push(`nhóm lạ «${k}» (chỉ ${DL_NHOM.join(' · ')})`);
  const them = (ma, nhom) => {
    if (!cho.includes(ma)) { loi.push(`${ma || '(trống)'} (${nhom}) không phải việc đang chờ`); return; }
    (dem[ma] ||= []).push(nhom);
  };
  const mang = (x) => (Array.isArray(x) ? x : []);
  for (const [nhom, truong] of [['lam', 'du_kien'], ['bo', 'vi_sao'], ['de_sau', 'vi_sao']])
    for (const x of mang(pa[nhom])) {
      const ma = doiMa(s(x?.ma)); const chu = s(x?.[truong]);
      if (nhom === 'lam' && !chu) loi.push(`${ma}: thiếu dòng dự kiến làm gì (du_kien)`);
      them(ma, nhom);
      chuan[nhom].push({ ma, [truong]: chu });
    }
  for (const x of mang(pa.hoi)) {
    const ma = doiMa(s(x?.ma)); const ai = s(x?.ai); const cau = s(x?.cau);
    if (!['sep', 'chu-nha'].includes(ai)) loi.push(`${ma}: hỏi ai phải là sep | chu-nha`);
    if (!HOI_RE.test(cau)) loi.push(`${ma}: câu hỏi phải đúng khuôn «1. …? 1A … · 1B …»`);
    them(ma, 'hoi');
    chuan.hoi.push({ ma, ai, cau, tieu_de: s(x?.tieu_de).slice(0, 70) });
  }
  const xep = (ma) => (dem[ma] || []).filter((n) => ['lam', 'hoi', 'de_sau'].includes(n));
  for (const x of mang(pa.gop)) {
    const chinh = doiMa(s(x?.chinh));
    const phu = [...new Set(mang(x?.phu).map((p) => doiMa(s(p))).filter(Boolean))];
    if (!phu.length) loi.push(`gộp vào ${chinh}: thiếu việc phụ`);
    if (phu.includes(chinh)) loi.push(`gộp: ${chinh} vừa là việc chính vừa là việc phụ`);
    for (const p of phu) them(p, 'gop');
    chuan.gop.push({ chinh, phu, vi_sao: s(x?.vi_sao) });
  }
  for (const g of chuan.gop)   // việc chính: việc đang chờ đã xếp làm/hỏi/để sau, hoặc việc đang mở khác
    if (!(khac.includes(g.chinh) || (cho.includes(g.chinh) && xep(g.chinh).length)))
      loi.push(`gộp vào ${g.chinh}: việc chính phải là việc đang mở, hoặc việc đang chờ đã xếp làm/hỏi/để sau`);
  for (const [ma, d] of Object.entries(dem)) if (d.length > 1) loi.push(`${ma} nằm ${d.length} chỗ (${d.join(', ')}) — mỗi việc đúng một chỗ`);
  const thieu = cho.filter((m) => !dem[m]);
  if (thieu.length) loi.push(`chưa xếp ${thieu.length} việc đang chờ: ${thieu.join(', ')}`);
  if (!cho.length) loi.push('không có việc nào đang chờ');
  return [chuan, [...new Set(loi)]];
}

// Gộp kiểu Fulfill: mọi tin của việc phụ dời sang việc chính → Reply tin cũ của việc phụ tự vào việc chính.
async function gopViec(env, chinh, phu, viSao, nguon) {
  const st = []; const xong = [];
  if (!(await env.DB.prepare('SELECT 1 FROM bnv_viec WHERE ma=?').bind(chinh).first())) return { st, xong };
  const vs = viSao ? ' — ' + viSao : '';
  for (const p of phu) {
    const vp = await env.DB.prepare('SELECT * FROM bnv_viec WHERE ma=?').bind(p).first();
    if (!vp || p === chinh) continue;
    st.push(env.DB.prepare('UPDATE bnv_tin SET ma_viec=? WHERE ma_viec=?').bind(chinh, p));
    st.push(env.DB.prepare('UPDATE bnv_viec SET trang_thai=?, chuyen_sang=?, cap_nhat=? WHERE ma=?').bind('da-chuyen', chinh, nowS(), p));
    st.push(dongMay(env, p, `🔗 Gộp vào ${chinh} (${nguon})${vs}`));
    st.push(dongMay(env, chinh, `🔗 Gộp ${p} vào đây (${nguon})${vs} · tiêu đề: ${vp.tieu_de} · nội dung: ${String(vp.noi_dung || '').trim().slice(0, 600)}`));
    st.push(env.DB.prepare('UPDATE bnv_viec SET cap_nhat=? WHERE ma=?').bind(nowS(), chinh));
    xong.push(p);
  }
  return { st, xong };
}

// Áp lượt đã OK. Lần đầu: gộp → khởi động → bỏ / để sau, sang «dang-ap» (MỘT batch D1 = một giao dịch).
// Lần sau (CLI chết giữa chừng): không áp lại, chỉ trả các câu hỏi chưa gửi. thu = chỉ đọc.
async function dlAp(env, thu) {
  const d = await dlMo(env);
  if (!d || !['da-ok', 'dang-ap'].includes(d.trang_thai))
    return { loi: `⛔ Chưa có lượt nào chủ nhà đã OK${d ? ` (DL${d.id} đang «${d.trang_thai}»)` : ''}` };
  const pa = d.phuong_an || {};
  const kq = d.ket_qua || { khoi_dong: [], bo_qua: [], gop: [], bo: [], de_sau: [], hoi_da_gui: [] };
  const nguon = `duyệt lượt DL${d.id} bản ${d.ban}`;
  if (d.trang_thai === 'da-ok' && !thu) {
    const st = [env.DB.prepare(`UPDATE bnv_duyet_luot SET trang_thai='dang-ap', cap_nhat=? WHERE id=? AND trang_thai='da-ok'`).bind(nowS(), d.id)];
    for (const g of pa.gop || []) {
      const x = await gopViec(env, g.chinh, g.phu, g.vi_sao || '', nguon);
      st.push(...x.st);
      if (x.xong.length) kq.gop.push({ chinh: g.chinh, phu: x.xong });
    }
    const k = await khoiDong(env, (pa.lam || []).map((x) => x.ma), nguon);
    st.push(...k.st);
    kq.khoi_dong = k.khoi_dong; kq.bo_qua = k.bo_qua;
    for (const x of pa.lam || []) if (k.khoi_dong.includes(x.ma)) st.push(dongMay(env, x.ma, `▶ Dự kiến (${nguon}): ${x.du_kien}`));
    for (const x of pa.bo || []) {
      const v = await env.DB.prepare('SELECT trang_thai FROM bnv_viec WHERE ma=?').bind(x.ma).first();
      if (!v) continue;
      if (v.trang_thai === TT_CHO) st.push(env.DB.prepare('UPDATE bnv_viec SET trang_thai=?, cap_nhat=? WHERE ma=?').bind('huy', nowS(), x.ma));
      st.push(env.DB.prepare('UPDATE bnv_tin SET claude_doc_luc=? WHERE ma_viec=? AND claude_doc_luc IS NULL').bind(nowS(), x.ma));
      st.push(dongMay(env, x.ma, `✖ chủ nhà bỏ (${nguon})${x.vi_sao ? ' — ' + x.vi_sao : ''}`));
      kq.bo.push(x.ma);
    }
    for (const x of pa.de_sau || []) {
      st.push(dongMay(env, x.ma, `⏸ để sau (${nguon})${x.vi_sao ? ' — ' + x.vi_sao : ''}`));
      kq.de_sau.push(x.ma);
    }
    for (const x of pa.hoi || []) st.push(dongMay(env, x.ma, `❓ ${nguon} — hỏi ${x.ai === 'sep' ? 'sếp' : 'chủ nhà'}: ${x.cau}`));
    st.push(dlDoi(env, d.id, { ket_qua: kq }));
    await env.DB.batch(st);
  }
  const hoi = [];
  for (const x of pa.hoi || []) {
    if (kq.hoi_da_gui.includes(x.ma)) continue;
    const v = await env.DB.prepare('SELECT * FROM bnv_viec WHERE ma=?').bind(x.ma).first();
    if (!v) continue;
    hoi.push({ ...x, viec: v, trong_nhom: await viecTrongNhom(env, x.ma) });
  }
  return { ok: true, id: d.id, ban: d.ban, trang_thai: thu ? d.trang_thai : 'dang-ap', thu, phuong_an: pa, ket_qua: kq, hoi };
}

// Lối gửi riêng cho việc NHÓM chỉ mở khi việc đó nằm trong mục «hỏi chủ nhà» của lượt đang áp (thử: cả lượt đã OK).
async function dlChoHoiRieng(env, id, ma, thu) {
  const d = await dlCo(env, id);
  if (!d || !(d.trang_thai === 'dang-ap' || (thu && d.trang_thai === 'da-ok'))) return false;
  return (d.phuong_an?.hoi || []).some((x) => x.ma === ma && x.ai === 'chu-nha');
}

async function guiAnh(env, chatId, anh, chu, replyTo) {
  const fd = new FormData();
  fd.append('chat_id', chatId);
  if (replyTo) fd.append('reply_parameters', JSON.stringify({ message_id: Number(replyTo) }));
  const blob = (s) => new Blob([Uint8Array.from(atob(s), (c) => c.charCodeAt(0))], { type: 'image/png' });
  if (anh.length === 1) {
    fd.append('photo', blob(anh[0]), 'anh0.png');
    fd.append('caption', chu);
    fd.append('parse_mode', 'HTML');
    return tg(env, 'sendPhoto', fd);
  }
  fd.append('media', JSON.stringify(anh.map((_, i) => ({ type: 'photo', media: `attach://f${i}`, ...(i === 0 ? { caption: chu, parse_mode: 'HTML' } : {}) }))));
  anh.forEach((a, i) => fd.append(`f${i}`, blob(a), `anh${i}.png`));
  return tg(env, 'sendMediaGroup', fd);
}

// Gửi bản phương án: soát → ảnh vào chat riêng chủ nhà → ghi bảng tin phương án + bản +1.
async function dlGui(env, b) {
  const d = await dlMo(env);
  if (!d || !['cho-may', 'gop-y', 'cho-chu-nha'].includes(d.trang_thai))
    return json({ ok: false, loi: d ? `DL${d.id} đang «${d.trang_thai}» — không gửi phương án được` : 'chưa có lượt duyệt nào đang mở (/lam)' }, 409);
  const [chuan, loi] = await dlSoat(env, b.phuong_an);
  if (b.thu) return json({ ok: !loi.length, thu: true, id: d.id, ban_sau: d.ban + 1, loi, phuong_an: chuan });
  if (loi.length) return json({ ok: false, loi: loi.join('; '), ds_loi: loi }, 400);
  const anh = Array.isArray(b.anh) ? b.anh : [];
  const text = String(b.text || '');
  if (anh.length < 1 || anh.length > 3) return json({ ok: false, loi: 'cần 1–3 ảnh bảng phương án' }, 400);
  if (!text || boThe(text).length > 1024) return json({ ok: false, loi: 'chú thích trống hoặc quá 1024 ký tự' }, 400);
  const ch = cauHinh(env);
  const kq = await guiAnh(env, ch.chu, anh, text);
  if (!kq.ok) return json({ ok: false, loi: 'Telegram: ' + (kq.description || '?') }, 502);
  const ds_ = Array.isArray(kq.result) ? kq.result : [kq.result];
  const ban = d.ban + 1;
  const ls = d.lich_su; ls.push({ ban, luc: nowS(), gui: true });
  const st = [dlDoi(env, d.id, { trang_thai: 'cho-chu-nha', ban, phuong_an: chuan, message_id: ds_[0].message_id, gop_y: null, lich_su: ls })];
  for (const r of ds_) {
    st.push(env.DB.prepare('INSERT OR REPLACE INTO bnv_duyet_luot_tin (chat_id, message_id, dl_id, ban) VALUES (?,?,?,?)').bind(ch.chu, r.message_id, d.id, ban));
    st.push(sqlTin(env, { chat_id: ch.chu, message_id: r.message_id, luc: r.date, tu_ten: 'bot', la_bot: 1, noi_dung: boThe(text), media_group: r.media_group_id ?? null, can_bao: 0 }));
  }
  await env.DB.batch(st);
  return json({ ok: true, id: d.id, ban, message_ids: ds_.map((r) => r.message_id) });
}

async function dlXong(env, id) {
  const d = await dlCo(env, id);
  if (!d || d.trang_thai !== 'dang-ap') return json({ ok: false, loi: `lượt DL${id} không ở «dang-ap»` }, 409);
  const kq = d.ket_qua || {};
  const con = (d.phuong_an?.hoi || []).map((x) => x.ma).filter((m) => !(kq.hoi_da_gui || []).includes(m));
  if (con.length) return json({ ok: false, loi: `còn câu hỏi chưa gửi: ${con.join(', ')}` }, 400);
  const dong = [`✅ <b>Đã làm theo phương án DL${d.id}</b> (bản ${d.ban})`];
  const them = (t, a) => a?.length && dong.push(`${t}: ${a.join(', ')}`);
  them('▶ Khởi động', kq.khoi_dong);
  them('🔗 Gộp', (kq.gop || []).map((g) => `${g.phu.join(', ')} → ${g.chinh}`));
  them('❓ Đã hỏi', kq.hoi_da_gui);
  them('✖ Bỏ', kq.bo);
  them('⏸ Để sau', kq.de_sau);
  them('ℹ Không còn chờ nên không khởi động', kq.bo_qua);
  const ch = cauHinh(env);
  const r = await tg(env, 'sendMessage', { chat_id: ch.chu, text: dong.join('\n'), parse_mode: 'HTML', ...(d.message_id ? { reply_parameters: { message_id: d.message_id, allow_sending_without_reply: true } } : {}) });
  const st = [dlDoi(env, d.id, { trang_thai: 'da-ap' })];
  if (r.ok) st.push(sqlTin(env, { chat_id: ch.chu, message_id: r.result.message_id, luc: r.result.date, tu_ten: 'bot', la_bot: 1, noi_dung: boThe(dong.join('\n')), can_bao: 0 }));
  await env.DB.batch(st);
  return json({ ok: true, gui: !!r.ok });
}

// ---------- 7c quét lời chưa trả lời ----------
async function quetNhac(env, thu = false) {
  const t = nowS();
  const rs = await env.DB.prepare(
    `SELECT t.id, t.ma_viec, t.tu_ten, t.noi_dung FROM bnv_tin t JOIN bnv_viec v ON v.ma=t.ma_viec
     WHERE t.la_bot=0 AND t.tu_id IS NOT NULL AND t.claude_doc_luc IS NULL AND t.nhac_luc IS NULL
       AND t.nhan_luc < ? AND v.trang_thai NOT IN ('xong','huy','da-chuyen')
       AND NOT EXISTS (SELECT 1 FROM bnv_tin b WHERE b.ma_viec=t.ma_viec AND b.la_bot=1 AND b.chat_id!='may' AND b.luc > t.luc AND ${KHONG_DANH_SACH})
     ORDER BY t.id LIMIT 50`
  ).bind(t - NGUONG_NHAC_GIAY).all();
  const hang = rs.results || [];
  if (thu || !hang.length) return { ok: true, thu, so: hang.length, hang };
  const ids = hang.map((h) => h.id);
  const gianh = await env.DB.prepare(
    `UPDATE bnv_tin SET nhac_luc=? WHERE id IN (${ids.map(() => '?').join(',')}) AND nhac_luc IS NULL RETURNING id, ma_viec, tu_ten, noi_dung`
  ).bind(t, ...ids).all();
  const duoc = gianh.results || [];
  if (!duoc.length) return { ok: true, so: 0 };
  const theoThe = {};
  for (const h of duoc) (theoThe[h.ma_viec] ||= []).push(h);
  const the = Object.keys(theoThe);
  const dong = the.slice(0, 5).map((ma) => {
    const h = theoThe[ma][0];
    const trich = boThe(h.noi_dung).replace(/\s+/g, ' ').slice(0, 50);
    return `• ${ma} — <b>${esc(h.tu_ten || 'người gửi')}</b>: «${esc(trich)}»${theoThe[ma].length > 1 ? ` (+${theoThe[ma].length - 1})` : ''}`;
  });
  if (the.length > 5) dong.push(`• …và ${the.length - 5} thẻ khác`);
  const MA_CANH = await maCanh(env);
  const chu = `<b>[${MA_CANH}] Trợ lý hệ thống: ${duoc.length} lời chưa được trả lời quá 15 phút</b>\n\n${dong.join('\n')}`;
  const ch = cauHinh(env);
  const r = await tg(env, 'sendMessage', { chat_id: ch.chu, text: chu, parse_mode: 'HTML' });
  if (r.ok) await sqlTin(env, { chat_id: ch.chu, message_id: r.result.message_id, luc: r.result.date, tu_id: null, tu_ten: 'bot', la_bot: 1, noi_dung: boThe(chu), ma_viec: MA_CANH, can_bao: 0 }).run();
  return { ok: true, so: duoc.length, gui: !!r.ok };
}

// ---------- lối máy ----------
async function guiTin(env, b) {
  const ch = cauHinh(env);
  let chatId = ch.chatSep;
  if (b.rieng) chatId = ch.chu;
  else if (b.chat_id) {
    chatId = String(b.chat_id);
    if (!ch.noiBo.includes(chatId) && !ch.ngoai.includes(chatId) && chatId !== ch.chu) return json({ ok: false, loi: 'nhóm không nằm trong danh sách' }, 422);
  }
  if (!b.chu) return json({ ok: false, loi: 'thiếu chu' }, 400);
  const anh = Array.isArray(b.anh) ? b.anh : [];
  // Tài liệu (PDF hướng dẫn…) gửi bằng sendDocument; chữ tin thành chú thích tệp, Reply vào tệp vẫn về đúng thẻ.
  const tep = b.tep && typeof b.tep.b64 === 'string' ? { ten: String(b.tep.ten || 'tai-lieu.pdf').replace(/[\\/\r\n]/g, '_').slice(0, 120), b64: b.tep.b64 } : null;
  let ma = b.ma ? doiMa(b.ma) : null;
  if (ma && !b.thu) {
    const v = await env.DB.prepare('SELECT ma FROM bnv_viec WHERE ma=?').bind(ma).first();
    if (!v) return json({ ok: false, loi: `không có thẻ ${ma}` }, 404);
  }
  // 7e: gửi riêng chủ nhà một việc của NHÓM chỉ được khi câu đó nằm trong mục «hỏi chủ nhà» của lượt duyệt đang áp.
  if (ma && b.rieng && (await viecTrongNhom(env, ma)) && !(b.duyet_luot && (await dlChoHoiRieng(env, b.duyet_luot, ma, !!b.thu))))
    return json({ ok: false, loi: `${ma} là việc của nhóm — hỏi chủ nhà riêng chỉ qua lượt duyệt (/lam), hoặc hỏi ngay trong nhóm` }, 409);
  const html = b.html ? String(b.chu) : (() => {
    const d = String(b.chu).split('\n');
    return `<b>${esc(d[0])}</b>` + (d.length > 1 ? '\n' + esc(d.slice(1).join('\n')) : '');
  })();
  // Đo khuôn mục 5 TRƯỚC khi cấp mã / gửi.
  const loi = [];
  const dong = boThe(html.replace('{MA}', TIEN_TO + '-00000000-00')).split('\n');
  const dau = dong[0].trim();
  if (!new RegExp(`^\\[${TIEN_TO}-(\\d{8}-\\d{2,3}|CANH)\\]\\s+\\S`).test(dau)) loi.push(`dòng đầu phải là «[${TIEN_TO}-…] tiêu đề»`);
  if (dau.replace(/^\[[^\]]+\]\s*/, '').length > 70) loi.push('tiêu đề quá 70 ký tự');
  if (!/^<b>/.test(html.trim())) loi.push('dòng đầu phải in đậm');
  const than = dong.slice(1).filter((x) => x.trim());
  if (than.length > 6) loi.push(`thân ${than.length} dòng > 6`);
  const soKy = than.join('\n').length;
  if (soKy > 600) loi.push(`thân ${soKy} ký tự > 600`);
  if ((html.match(/https?:\/\//g) || []).length > 1) loi.push('quá 1 link');
  if (anh.length > 3) loi.push('quá 3 ảnh');
  if (tep && anh.length) loi.push('không gửi cùng lúc ảnh và tệp');
  if (tep && tep.b64.length > 66_000_000) loi.push('tệp quá 49 MB (giới hạn Telegram 50 MB)');
  if (!than.length || !than[than.length - 1].trim().startsWith('👉')) loi.push('dòng cuối phải là dòng «👉 …» xin trả lời');
  if (ch.ngoai.includes(chatId) && CHU_TAI_CHINH.test(boThe(html))) loi.push('nhóm có người ngoài: chặn chữ tài chính nội bộ');
  if (loi.length) return json({ ok: false, loi: loi.join('; ') }, 422);
  if (b.thu) return json({ ok: true, thu: true, chat: chatId === ch.chu ? 'rieng' : chatId === ch.chatSep ? 'nhom-chinh' : 'nhom-khac', ma: ma || '(sẽ cấp khi gửi)', chu: html, than_dong: than.length, than_ky_tu: soKy,
    ...(tep ? { tep: { ten: tep.ten, kb: Math.round((tep.b64.length * 3) / 4 / 1024) } } : {}) });

  if (!ma) {
    const dong1 = boThe(html).split('\n')[0].replace(/^\[[^\]]+\]\s*/, '').trim();
    const r = await sqlTaoViec(env, { tieu_de: b.tieu_de || dong1 || 'Việc máy gửi', noi_dung: b.noi_dung || '', giao_luc: nowS(), trang_thai: b.trang_thai || 'dang-lam' }).first();
    ma = r.ma;
  }
  const chu = html.replaceAll('{MA}', ma);
  const rp = b.reply_to ? { reply_parameters: { message_id: Number(b.reply_to), allow_sending_without_reply: true } } : {};
  let kq;
  if (tep) {
    const fd = new FormData();
    fd.append('chat_id', chatId);
    if (rp.reply_parameters) fd.append('reply_parameters', JSON.stringify(rp.reply_parameters));
    const loai = /\.pdf$/i.test(tep.ten) ? 'application/pdf' : 'application/octet-stream';
    fd.append('document', new Blob([Uint8Array.from(atob(tep.b64), (c) => c.charCodeAt(0))], { type: loai }), tep.ten);
    fd.append('caption', chu);
    fd.append('parse_mode', 'HTML');
    kq = await tg(env, 'sendDocument', fd);
  } else if (!anh.length) kq = await tg(env, 'sendMessage', { chat_id: chatId, text: chu, parse_mode: 'HTML', link_preview_options: { is_disabled: true }, ...rp });
  else {
    const fd = new FormData();
    fd.append('chat_id', chatId);
    if (rp.reply_parameters) fd.append('reply_parameters', JSON.stringify(rp.reply_parameters));
    const blob = (s) => new Blob([Uint8Array.from(atob(s), (c) => c.charCodeAt(0))], { type: 'image/png' });
    if (anh.length === 1) {
      fd.append('photo', blob(anh[0]), 'anh0.png');
      fd.append('caption', chu);
      fd.append('parse_mode', 'HTML');
      kq = await tg(env, 'sendPhoto', fd);
    } else {
      fd.append('media', JSON.stringify(anh.map((_, i) => ({ type: 'photo', media: `attach://f${i}`, ...(i === 0 ? { caption: chu, parse_mode: 'HTML' } : {}) }))));
      anh.forEach((a, i) => fd.append(`f${i}`, blob(a), `anh${i}.png`));
      kq = await tg(env, 'sendMediaGroup', fd);
    }
  }
  if (!kq.ok) return json({ ok: false, ma, loi: 'Telegram: ' + (kq.description || '?') }, 502);
  const ds_ = Array.isArray(kq.result) ? kq.result : [kq.result];
  const st = ds_.map((r) => sqlTin(env, {
    chat_id: chatId, message_id: r.message_id, luc: r.date, tu_id: String(r.from?.id || ''), tu_ten: 'bot', la_bot: 1,
    noi_dung: boThe(chu), media_group: r.media_group_id ?? null, anh: tepCua(r),
    ma_viec: ma, can_bao: 0, reply_to: b.reply_to ?? null,
  }));
  st.push(b.trang_thai && TRANG_THAI.includes(b.trang_thai)
    ? env.DB.prepare('UPDATE bnv_viec SET trang_thai=?, cap_nhat=? WHERE ma=? AND nguon IS NULL').bind(b.trang_thai, nowS(), ma)
    : env.DB.prepare('UPDATE bnv_viec SET cap_nhat=? WHERE ma=?').bind(nowS(), ma));
  await env.DB.batch(st);
  return json({ ok: true, ma, chat_id: chatId === ch.chu ? 'rieng' : chatId, message_ids: ds_.map((r) => r.message_id) });
}

async function luuUpdateCu(env, u) {
  const m = u.message || u.edited_message || u.channel_post;
  const ch = cauHinh(env);
  if (!m?.chat || !m.from) return 0;
  const chat = String(m.chat.id);
  if (!(ch.noiBo.includes(chat) || chat === ch.chu)) return 0;
  const r = await sqlTin(env, coTin(m, String(m.text ?? m.caption ?? (tepCua(m) ? '[tin không có chữ]' : '')), 0)).run();
  return r.meta.changes;
}

async function api(req, env) {
  const tok = env.SEP_VIEC_TOKEN;
  if (!tok || req.headers.get('x-sep-viec-token') !== tok) return json({ ok: false, loi: 'unauthorized' }, 401);
  const db = env.DB;
  const t = nowS();
  const nhip = [];
  if (req.headers.get('x-nhip-tim')) nhip.push(datMoc(env, 'nhip_tim', t));
  if (req.headers.get('x-canh') === '1') nhip.push(datMoc(env, 'canh_nghe', t));
  if (nhip.length) await db.batch(nhip);
  const act = new URL(req.url).searchParams.get('act') || '';
  let b = {};
  if (req.method === 'POST') {
    try { b = await req.json(); } catch { return json({ ok: false, loi: 'JSON hỏng' }, 400); }
  }
  const idsHopLe = (a) => Array.isArray(a) && a.length && a.every((x) => Number.isInteger(Number(x)));
  const trong = (a) => a.map(() => '?').join(',');

  switch (act) {
    case 'moc': {
      const r = await db.prepare('SELECT MAX(id) AS moc FROM bnv_tin').first();
      return json({ ok: true, moc: r?.moc || 0 });
    }
    case 'tat-ca': {
      const v = await db.prepare('SELECT * FROM bnv_viec ORDER BY ngay DESC, stt').all();
      const ti = await db.prepare('SELECT id, chat_id, message_id, luc, tu_ten, la_bot, noi_dung, reply_to, anh, ma_viec, sua_luc, ban_truoc, can_bao, claude_doc_luc FROM bnv_tin WHERE ma_viec IS NOT NULL ORDER BY id').all();
      return json({ ok: true, viec: v.results, tin: ti.results });
    }
    case 'chua-doc': {
      const r = await db.prepare(
        `SELECT t.id, t.chat_id, t.message_id, t.luc, t.tu_ten, t.noi_dung, t.reply_to, t.anh, t.ma_viec, t.sua_luc, t.ban_truoc,
                v.tieu_de, v.trang_thai
         FROM bnv_tin t LEFT JOIN bnv_viec v ON v.ma=t.ma_viec WHERE t.can_bao=1 AND t.claude_doc_luc IS NULL ORDER BY t.id`
      ).all();
      const dl = await dlMo(env);
      const duyet_luot = dl && DL_CAN_MAY.includes(dl.trang_thai)
        ? { id: dl.id, trang_thai: dl.trang_thai, ban: dl.ban, cap_nhat: dl.cap_nhat, gop_y: dl.gop_y } : null;
      return json({ ok: true, tin: r.results, duyet_luot, tam_dung: !!(await tamDung(env)) });
    }
    case 'duyet-luot-xem': {
      const d = b.id ? await dlCo(env, b.id) : await dlMo(env);
      const cho = await mucCho(env);
      const mo_khac = await moKhac(env);
      const ma = [...cho, ...mo_khac];
      const viec = {}; const tin = {};
      if (ma.length) {
        const v = await db.prepare(`SELECT ma, tieu_de, noi_dung, trang_thai, nguoi_giao, giao_luc, tin_goc FROM bnv_viec WHERE ma IN (${trong(ma)})`).bind(...ma).all();
        for (const x of v.results || []) viec[x.ma] = x;
      }
      if (cho.length) {
        const ti = await db.prepare(`SELECT id, chat_id, message_id, luc, tu_ten, la_bot, noi_dung, ma_viec, sua_luc, ban_truoc FROM bnv_tin WHERE ma_viec IN (${trong(cho)}) ORDER BY id`).bind(...cho).all();
        for (const x of ti.results || []) (tin[x.ma_viec] ||= []).push(x);
      }
      return json({ ok: true, dl: d, cho, mo_khac, viec, tin });
    }
    case 'phuong-an':
      return dlGui(env, b);
    case 'ap-phuong-an': {
      const r = await dlAp(env, !!b.thu);
      return r.loi ? json({ ok: false, loi: r.loi }, 409) : json(r);
    }
    case 'ap-hoi': {
      const d = await dlCo(env, b.id);
      if (!d || d.trang_thai !== 'dang-ap') return json({ ok: false, loi: 'lượt không ở «dang-ap»' }, 409);
      const ma = doiMa(b.ma);
      if (!(d.phuong_an?.hoi || []).some((x) => x.ma === ma)) return json({ ok: false, loi: `${ma} không nằm trong mục hỏi của lượt` }, 400);
      const kq = d.ket_qua;
      if (!kq.hoi_da_gui.includes(ma)) kq.hoi_da_gui.push(ma);
      await dlDoi(env, d.id, { ket_qua: kq }).run();
      return json({ ok: true });
    }
    case 'ap-xong':
      return dlXong(env, b.id);
    case 'da-doc': {
      if (!idsHopLe(b.ids)) return json({ ok: false, loi: 'ids rỗng hoặc hỏng — nêu đích danh' }, 400);
      const r = await db.prepare(`UPDATE bnv_tin SET claude_doc_luc=? WHERE id IN (${trong(b.ids)})`).bind(t, ...b.ids.map(Number)).run();
      return json({ ok: true, so: r.meta.changes });
    }
    case 'tao-viec': {
      if (!b.tieu_de) return json({ ok: false, loi: 'thiếu tieu_de' }, 400);
      if (b.trang_thai && !TRANG_THAI.includes(b.trang_thai)) return json({ ok: false, loi: 'trạng thái lạ' }, 422);
      const ma = String(b.ma || '');
      let ngay = null;
      const st = [];
      const day = /^(?:(?:oHa|Task)-)?(\d{8})(?:-(\d{2,3}))?$/i.exec(ma);
      if (ma && !day) return json({ ok: false, loi: `mã sai khuôn ${TIEN_TO}-ddmmyyyy[-NN]` }, 422);
      if (day?.[2]) {
        if (await db.prepare('SELECT 1 FROM bnv_viec WHERE ma=?').bind(`${TIEN_TO}-${day[1]}-${day[2]}`).first()) return json({ ok: false, loi: 'mã đã có' }, 409);
        st.push(db.prepare(`INSERT INTO bnv_viec(ma, ngay, stt, tieu_de, noi_dung, nguoi_giao, giao_luc, trang_thai, tin_goc, tao_luc, cap_nhat) VALUES(?,?,?,?,?,?,?,?,?,?,?) RETURNING ma`)
          .bind(`${TIEN_TO}-${day[1]}-${day[2]}`, day[1], Number(day[2]), b.tieu_de, b.noi_dung || '', b.nguoi_giao ?? null, b.giao_luc ?? t, b.trang_thai || 'cho-xac-nhan', b.tin_goc ?? null, t, t));
      } else {
        ngay = day ? day[1] : null;
        st.push(sqlTaoViec(env, { ngay, tieu_de: b.tieu_de, noi_dung: b.noi_dung, nguoi_giao: b.nguoi_giao, giao_luc: b.giao_luc ?? t, tin_goc: b.tin_goc, trang_thai: b.trang_thai }));
      }
      const r = await db.batch(st);
      const maMoi = r[0].results[0].ma;
      if (Array.isArray(b.gan) && b.gan.length) {
        const chat = String(b.chat_id || cauHinh(env).chatSep);
        await db.prepare(`UPDATE bnv_tin SET ma_viec=? WHERE chat_id=? AND message_id IN (${trong(b.gan)})`).bind(maMoi, chat, ...b.gan.map(Number)).run();
      }
      return json({ ok: true, ma: maMoi });
    }
    case 'gan-tin': {
      if (!b.ma || !idsHopLe(b.message_ids)) return json({ ok: false, loi: 'thiếu ma / message_ids' }, 400);
      b.ma = doiMa(b.ma);
      const chat = String(b.chat_id || cauHinh(env).chatSep);
      const r = await db.prepare(`UPDATE bnv_tin SET ma_viec=? WHERE chat_id=? AND message_id IN (${trong(b.message_ids)})`).bind(b.ma, chat, ...b.message_ids.map(Number)).run();
      return json({ ok: true, so: r.meta.changes });
    }
    case 'trang-thai':
    case 'ghi': {
      if (!b.ma) return json({ ok: false, loi: 'thiếu ma' }, 400);
      b.ma = doiMa(b.ma);
      const v = await db.prepare('SELECT ma, nguon FROM bnv_viec WHERE ma=?').bind(b.ma).first();
      if (!v) return json({ ok: false, loi: 'không có thẻ' }, 404);
      const tt = b.trang_thai;
      if (tt && !TRANG_THAI.includes(tt)) return json({ ok: false, loi: `trạng thái lạ — chỉ: ${TRANG_THAI.join(', ')}` }, 422);
      if (tt === 'xong' && v.nguon === 'he-thong') return json({ ok: false, loi: 'thẻ con canh trưởng không bao giờ đóng' }, 422);
      if (act === 'trang-thai' && !tt) return json({ ok: false, loi: 'thiếu trang_thai' }, 400);
      if (act === 'ghi' && !b.noi_dung) return json({ ok: false, loi: 'thiếu noi_dung' }, 400);
      const st = [db.prepare('UPDATE bnv_viec SET trang_thai=COALESCE(?, trang_thai), cap_nhat=? WHERE ma=?').bind(tt || null, t, b.ma)];
      // Dòng máy tự ghi mang cờ máy (la_bot=1, chat 'may') → con canh / moi không coi là tin mới.
      if (b.noi_dung)
        st.push(sqlTin(env, { chat_id: 'may', message_id: -(Date.now() * 1000 + Math.floor(Math.random() * 1000)), luc: t, tu_ten: 'máy', la_bot: 1, noi_dung: String(b.noi_dung), ma_viec: b.ma, can_bao: 0 }));
      await db.batch(st);
      return json({ ok: true });
    }
    case 'gui':
      return guiTin(env, b);
    case 'nhap': {
      if (!Array.isArray(b)) return json({ ok: false, loi: 'cần mảng update' }, 400);
      let so = 0;
      for (const u of b) so += await luuUpdateCu(env, u);
      return json({ ok: true, so });
    }
    case 'xoa': {
      const tin = Array.isArray(b.tin) ? b.tin.map(Number) : [];
      const ma = Array.isArray(b.ma) ? b.ma.map(doiMa) : [];
      const cli = Array.isArray(b.clitell) ? b.clitell.map(Number) : [];
      const dlx = Array.isArray(b.dl) ? b.dl.map(Number) : [];
      if (!tin.length && !ma.length && !cli.length && !dlx.length) return json({ ok: false, loi: 'nêu đích danh tin / ma / clitell / dl' }, 400);
      if (ma.includes(await maCanh(env))) return json({ ok: false, loi: 'không xoá thẻ con canh trưởng' }, 422);
      const st = [];
      if (tin.length) st.push(db.prepare(`DELETE FROM bnv_tin WHERE message_id IN (${trong(tin)})`).bind(...tin));
      if (ma.length) {
        st.push(db.prepare(`DELETE FROM bnv_tin WHERE chat_id='may' AND ma_viec IN (${trong(ma)})`).bind(...ma));
        st.push(db.prepare(`DELETE FROM bnv_viec WHERE ma IN (${trong(ma)})`).bind(...ma));
      }
      if (cli.length) st.push(db.prepare(`DELETE FROM bnv_clitell WHERE id IN (${trong(cli)})`).bind(...cli));
      if (dlx.length) {
        st.push(db.prepare(`DELETE FROM bnv_duyet_luot_tin WHERE dl_id IN (${trong(dlx)})`).bind(...dlx));
        st.push(db.prepare(`DELETE FROM bnv_duyet_luot WHERE id IN (${trong(dlx)})`).bind(...dlx));
      }
      const r = await db.batch(st);
      return json({ ok: true, so: r.map((x) => x.meta.changes) });
    }
    case 'clitell': {
      const r = await db.prepare('SELECT id, tao_luc AS luc, chu, noi_tiep, loai FROM bnv_clitell WHERE nhan_luc IS NULL ORDER BY id').all();
      return json({ ok: true, loi_cli: r.results, tam_dung: !!(await tamDung(env)) });
    }
    case 'clitell-da-nhan': {
      if (!idsHopLe(b.ids)) return json({ ok: false, loi: 'ids rỗng' }, 400);
      const r = await db.prepare(`UPDATE bnv_clitell SET nhan_luc=? WHERE id IN (${trong(b.ids)}) AND nhan_luc IS NULL RETURNING chat_id, message_id`).bind(t, ...b.ids.map(Number)).all();
      for (const x of r.results || []) if (x.chat_id !== 'may') await tha(env, x.chat_id, x.message_id, '👀');
      return json({ ok: true, so: (r.results || []).length });
    }
    case 'clitell-tra': {
      const c = await db.prepare('SELECT * FROM bnv_clitell WHERE id=?').bind(Number(b.id)).first();
      if (!c) return json({ ok: false, loi: 'không có lời này' }, 404);
      const chu = String(b.chu || '').trim();
      const dongs = chu.split('\n').filter((x) => x.trim()).length;
      if (!chu || dongs > 6 || chu.length > 600) return json({ ok: false, loi: `trần 6 dòng / 600 ký tự (đang ${dongs} dòng / ${chu.length} ký tự)` }, 422);
      const text = `${DAU_CLI[1]} ${esc(chu)}`;
      if (b.thu) return json({ ok: true, thu: true, chu: text });
      const kq = await tg(env, 'sendMessage', { chat_id: c.chat_id, text, parse_mode: 'HTML', reply_parameters: { message_id: c.message_id } });
      if (!kq.ok) return json({ ok: false, loi: 'Telegram: ' + (kq.description || '?') }, 502);
      const botTin = [...JSON.parse(c.bot_tin || '[]'), kq.result.message_id];
      await db.batch([
        db.prepare('UPDATE bnv_clitell SET bot_tin=? WHERE id=?').bind(JSON.stringify(botTin), c.id),
        sqlTin(env, { chat_id: c.chat_id, message_id: kq.result.message_id, luc: kq.result.date, tu_ten: 'bot', la_bot: 1, noi_dung: boThe(text), reply_to: c.message_id, can_bao: 0 }),
      ]);
      return json({ ok: true, message_id: kq.result.message_id });
    }
    case 'menu':
      return json(await datMenu(env, false));
    case 'menu-xem':
      return json(await datMenu(env, true));
    case 'quet-nhac':
      return json(await quetNhac(env, !!b.thu));
    case 'nhip': {
      return json({ ok: true, nhip_tim: await docMoc(env, 'nhip_tim'), canh_nghe: await docMoc(env, 'canh_nghe'), may_tat: await mayTat(env), tam_dung: await tamDung(env), ai_luot_hom_nay: (await docMoc(env, 'ai_luot:' + ngayVN(t))) || 0 });
    }
    default:
      return json({ ok: false, loi: 'act lạ' }, 404);
  }
}

export default {
  async fetch(req, env, ctx) {
    const p = new URL(req.url).pathname;
    if (req.method === 'POST' && (p === '/hook' || p === '/hook.php')) return webhook(req, env, ctx);
    if (p === '/api' || p === '/api.php') {
      try {
        return await api(req, env);
      } catch (e) {
        console.log('api lỗi', String(e?.stack || e));
        return json({ ok: false, loi: 'lỗi máy chủ' }, 500);
      }
    }
    return new Response('oha-bot', { status: 200 });
  },
  async scheduled(ev, env, ctx) {
    ctx.waitUntil(lich(env, Math.floor((ev?.scheduledTime || Date.now()) / 1000)).catch((e) => console.log('lịch lỗi', String(e))));
    ctx.waitUntil(quetNhac(env).catch((e) => console.log('quét nhắc lỗi', String(e))));
    ctx.waitUntil(ngheLai(env, ctx).catch((e) => console.log('nghe lại lỗi', String(e))));
  },
};
