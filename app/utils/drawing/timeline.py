import io
import base64
import math
import numpy as np
import matplotlib
matplotlib.use('Agg')
from matplotlib.figure import Figure
from matplotlib.backends.backend_agg import FigureCanvasAgg as FigureCanvas
import matplotlib.patches as patches
import astro00_lib as lib
from datetime import datetime, timedelta, date

def draw_sextile_custom_black(ax, x, y, size=0.08, fig_w=12, fig_h=10):
    """Vẽ kí hiệu Lục Hợp hình hoa thị chuẩn, bù trừ co giãn trục X để 3 đường bằng nhau."""
    x_range = 1.2
    y_range = ax.get_ylim()[0] - ax.get_ylim()[1]
    unit_scale_x = fig_w / x_range
    unit_scale_y = fig_h / abs(y_range)
    ratio = unit_scale_y / unit_scale_x

    # Đường 1: Dọc (Chuẩn theo trục Y)
    ax.plot([x, x], [y - size, y + size], color='black', lw=1.5, solid_capstyle='round', zorder=10)

    # Tính toán độ dài hiển thị. dx phải nhân thêm ratio để bù trừ độ dãn ngang của trục X
    dx = (size * math.cos(math.radians(30))) * ratio
    dy = size * math.sin(math.radians(30))

    # Đường 2: Chéo huyền
    ax.plot([x - dx, x + dx], [y - dy, y + dy], color='black', lw=1.5, solid_capstyle='round', zorder=10)
    # Đường 3: Chéo sắc
    ax.plot([x - dx, x + dx], [y + dy, y - dy], color='black', lw=1.5, solid_capstyle='round', zorder=10)

def create_detailed_timeline_image(natal_chart, start_date, end_date, house_list):
    """Vẽ biểu đồ Timeline vận hạn chi tiết (Kí hiệu hoa thị chuẩn cho Lục Hợp)."""

    # 1. SCALE THỜI GIAN (X: 0 -> 1)
    total_days = (end_date - start_date).days
    if total_days <= 0: total_days = 1

    def get_x(dt_obj):
        if isinstance(dt_obj, str):
            dt_obj = datetime.strptime(dt_obj, "%d/%m/%Y").date()
        days_diff = (dt_obj - start_date).days
        return days_diff / total_days

    # 2. CHUẨN BỊ DỮ LIỆU CÁC DÒNG
    rows_data = []
    outer_planets = ["Pluto", "Neptune", "Uranus", "Saturn", "Jupiter"]
    core_planets = ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]

    # CÁC MỐC GIỚI HẠN QUAN TRỌNG CHO LOGIC HIỂN THỊ "E"
    # Mốc E đầu: 31 ngày trước Start
    limit_early_e = start_date - timedelta(days=31)
    
    # Mốc E cuối: 31 ngày sau ngày 1 của tháng chứa End Date
    # Logic chuẩn mo-v8.17: Ngày mùng 1 của tháng chứa End Date + 31 ngày
    first_day_of_end_month = date(end_date.year, end_date.month, 1)
    limit_late_e = first_day_of_end_month + timedelta(days=31)

    for h_num in house_list:
        rows_data.append({"type": "separator", "label": f"NHÀ {h_num}"})

        # --- BƯỚC 1: HÀNH TINH TRANSIT VÀO/RA NHÀ ---
        for p_outer in outer_planets:
            periods = []
            res_h = lib.find_return_times(p_outer, start_date.strftime("%d/%m/%Y"), natal_chart)

            # Check xem hành tinh có đang ở sẵn trong nhà ngay từ ngày bắt đầu không
            jd_start = lib.swe.julday(start_date.year, start_date.month, start_date.day, 0)
            lat, lon = natal_chart["meta"]["lat"], natal_chart["meta"]["lon"]
            pos_at_start = lib.get_p_pos(jd_start, p_outer, lat, lon)
            cusps_raw = natal_chart["cusps"]
            cusps = list(cusps_raw)[1:] if len(cusps_raw) == 13 else list(cusps_raw)
            c_start, c_end = cusps[h_num - 1], cusps[h_num % 12]

            if lib.is_in_house_zone(pos_at_start, c_start, c_end):
                found_exit = None
                for r in res_h:
                    if r["house"] == h_num: # Tìm điểm RA (end) gần nhất
                        found_exit = datetime.strptime(r["end"]["d"], "%d/%m/%Y").date()
                        break
                periods.append({
                    "start": start_date, "end": min(found_exit, end_date) if found_exit else end_date,
                    "is_clamped_start": True, "is_clamped_end": (not found_exit) or (found_exit >= end_date),
                    "exacts": [], "type": "entry"
                })

            for r in res_h:
                if r["house"] == h_num:
                    s_d = datetime.strptime(r["start"]["d"], "%d/%m/%Y").date()
                    e_d = datetime.strptime(r["end"]["d"], "%d/%m/%Y").date()
                    if start_date < s_d < end_date:
                        periods.append({
                            "start": s_d, "end": min(e_d, end_date),
                            "is_clamped_start": False, "is_clamped_end": e_d >= end_date,
                            "exacts": [], "type": "entry"
                        })

            if periods:
                sym_t = lib.PLANET_SYMBOLS.get(p_outer, "")
                rows_data.append({
                    "type": "house_entry", "full_label": f"{sym_t}=H{h_num}", "periods": periods
                })

        # --- BƯỚC 2: HÀNH TINH TRONG NHÀ GẦN ĐỈNH NHẤT ---
        p_near = lib.get_natal_planet_near_cusp(natal_chart, h_num)
        if p_near and p_near in core_planets:
            for p_outer in outer_planets:
                for asp_name in lib.MAJOR_ASPECTS:
                    # Quét rộng hơn về quá khứ và tương lai 30 ngày để bắt E ở rìa
                    # Dùng phạm vi rộng hơn start/end một chút để không sót E
                    scan_start_str = (start_date - timedelta(days=30)).strftime("%d/%m/%Y")
                    # lib.find_exact_aspect_times tự động quét tới một giới hạn, nhưng ta nên lọc sau
                    res_a = lib.find_exact_aspect_times(p_outer, p_near, asp_name, scan_start_str, natal_chart)
                    
                    valid_periods = []
                    for r in res_a:
                        s_d = datetime.strptime(r["start"]["d"], "%d/%m/%Y").date()
                        e_d = datetime.strptime(r["end"]["d"], "%d/%m/%Y").date()
                        
                        # Chỉ lấy period nếu nó giao thoa với khoảng hiển thị (bao gồm cả vùng đệm E)
                        # Vùng đệm E là [limit_early_e, limit_late_e]
                        if not (e_d < limit_early_e or s_d > limit_late_e):
                            ex_list = []
                            has_early_e = False
                            has_late_e = False
                            
                            for hit in r["exact_hits"]:
                                hit_date = datetime.strptime(hit["d"], "%d/%m/%Y").date()
                                
                                # Logic E đỏ:
                                # 1. Nếu nằm trong khoảng view chính: Thêm vào ex_list để vẽ vạch
                                if start_date <= hit_date <= end_date:
                                    ex_list.append(hit_date)
                                
                                # 2. Nếu nằm trong vùng Early E
                                if limit_early_e <= hit_date < start_date:
                                    has_early_e = True
                                
                                # 3. Nếu nằm trong vùng Late E (Tính từ End Date đến Limit Late)
                                if end_date < hit_date <= limit_late_e:
                                    has_late_e = True

                            # Nếu period có dính líu đến vùng view chính (hoặc kẹp giữa)
                            # Hoặc nếu nó chứa E ở rìa -> Vẫn cần render để hiện chữ E
                            is_clamped_start = s_d <= start_date
                            is_clamped_end = e_d >= end_date
                            
                            # Chỉ append nếu period thực sự đè lên timeline hoặc có E cần hiện
                            if (is_clamped_start and is_clamped_end) or \
                               (s_d >= start_date and s_d <= end_date) or \
                               (e_d >= start_date and e_d <= end_date) or \
                               has_early_e or has_late_e:
                                   
                                   valid_periods.append({
                                       "start": max(s_d, start_date), "end": min(e_d, end_date),
                                       "is_clamped_start": is_clamped_start, 
                                       "is_clamped_end": is_clamped_end,
                                       "exacts": ex_list, 
                                       "has_early_e": has_early_e,
                                       "has_late_e": has_late_e,
                                       "type": "aspect"
                                   })

                    if valid_periods:
                        sym_t = lib.PLANET_SYMBOLS.get(p_outer, "")
                        sym_asp = lib.ASPECTS_DEF[asp_name]["symbol"]
                        sym_n = lib.PLANET_SYMBOLS.get(p_near, "")
                        rows_data.append({
                            "type": "aspect", "full_label": f"{sym_t}{sym_asp}{sym_n}", "periods": valid_periods
                        })

        # --- BƯỚC 3: CHỦ TINH ĐỈNH NHÀ ---
        p_ruler = lib.get_house_ruler_planet(natal_chart, h_num)
        if p_ruler and p_ruler in core_planets:
            if p_ruler == p_near: continue
            for p_outer in outer_planets:
                for asp_name in lib.MAJOR_ASPECTS:
                    scan_start_str = (start_date - timedelta(days=30)).strftime("%d/%m/%Y")
                    res_a = lib.find_exact_aspect_times(p_outer, p_ruler, asp_name, scan_start_str, natal_chart)
                    valid_periods = []
                    for r in res_a:
                        s_d = datetime.strptime(r["start"]["d"], "%d/%m/%Y").date()
                        e_d = datetime.strptime(r["end"]["d"], "%d/%m/%Y").date()
                        
                        if not (e_d < limit_early_e or s_d > limit_late_e):
                            ex_list = []
                            has_early_e = False
                            has_late_e = False
                            
                            for hit in r["exact_hits"]:
                                hit_date = datetime.strptime(hit["d"], "%d/%m/%Y").date()
                                if start_date <= hit_date <= end_date:
                                    ex_list.append(hit_date)
                                if limit_early_e <= hit_date < start_date:
                                    has_early_e = True
                                if end_date < hit_date <= limit_late_e:
                                    has_late_e = True

                            is_clamped_start = s_d <= start_date
                            is_clamped_end = e_d >= end_date
                            
                            if (is_clamped_start and is_clamped_end) or \
                               (s_d >= start_date and s_d <= end_date) or \
                               (e_d >= start_date and e_d <= end_date) or \
                               has_early_e or has_late_e:
                                   
                                   valid_periods.append({
                                       "start": max(s_d, start_date), "end": min(e_d, end_date),
                                       "is_clamped_start": is_clamped_start, 
                                       "is_clamped_end": is_clamped_end,
                                       "exacts": ex_list, 
                                       "has_early_e": has_early_e,
                                       "has_late_e": has_late_e,
                                       "type": "aspect"
                                   })

                    if valid_periods:
                        sym_t = lib.PLANET_SYMBOLS.get(p_outer, "")
                        sym_asp = lib.ASPECTS_DEF[asp_name]["symbol"]
                        sym_n = lib.PLANET_SYMBOLS.get(p_ruler, "")
                        rows_data.append({
                            "type": "aspect", "full_label": f"{sym_t}{sym_asp}{sym_n}", "periods": valid_periods
                        })

    # 3. VẼ BIỂU ĐỒ
    ROW_HEIGHT = 0.7
    EXTRA_HOUSE_GAP = 0.5
    total_rows = len(rows_data)
    num_separators = sum(1 for r in rows_data if r["type"] == "separator")
    fig_h = max(4, (total_rows * ROW_HEIGHT) + (num_separators * EXTRA_HOUSE_GAP) + 3.0)

    fig = Figure(figsize=(12, fig_h), dpi=100)
    ax = fig.add_subplot(111)

    ax.set_xlim(-0.15, 1.05)
    ax.set_ylim(-2.2, total_rows * 0.9)
    ax.invert_yaxis()
    ax.axis('off')

    # TITLE
    ax.text(0.45, -1.8, f"{start_date.strftime('%d/%m/%Y')} - {end_date.strftime('%d/%m/%Y')}",
            ha='center', va='center', fontweight='black', fontsize=18, color='black',
            bbox=dict(facecolor='white', edgecolor='black', boxstyle='round,pad=0.4', lw=2))

    # TIMELINE CHÍNH
    TL_Y = 0.0
    ax.plot([0, 1.02], [TL_Y, TL_Y], color='black', lw=3.5, zorder=5)
    ax.annotate('', xy=(1.04, TL_Y), xytext=(1.02, TL_Y), arrowprops=dict(arrowstyle='->', color='black', lw=3.5))

    curr = start_date
    while curr <= end_date:
        # LOGIC MỚI: CHỈ HIỂN THỊ TEXT/TICK VÀO NGÀY MÙNG 1 CỦA THÁNG
        if curr.day == 1:
            x = get_x(curr)
            ax.plot([x, x], [TL_Y - 0.12, TL_Y + 0.12], color='black', lw=2, zorder=6)
            ax.text(x, TL_Y - 0.2, f"{curr.day}/{curr.month}", ha='center', va='bottom', fontsize=11,
                    fontweight='black', zorder=10)
            ax.text(x, TL_Y - 0.6, f"{curr.year}", ha='center', va='bottom', fontsize=9, color='gray', zorder=10)
        
        # Tự động nhảy đến ngày mùng 1 của tháng tiếp theo
        if curr.month == 12:
            curr = date(curr.year + 1, 1, 1)
        else:
            curr = date(curr.year, curr.month + 1, 1)

    # VẼ DỮ LIỆU TỪNG DÒNG
    current_y_offset = 1.2
    for idx, row in enumerate(rows_data):
        y = current_y_offset

        if row["type"] == "separator":
            ax.text(-0.02, y, row["label"], fontweight='black', fontsize=12, color='blue', va='center', ha='right',
                    bbox=dict(facecolor='white', edgecolor='blue', boxstyle='round,pad=0.2', lw=1.5))
            current_y_offset += (ROW_HEIGHT * 0.5)
            continue

        full_txt = row["full_label"]
        first_p = row["periods"][0]
        label_x = -0.015 if first_p["is_clamped_start"] else get_x(first_p["start"]) - 0.015

        if "⚹" in full_txt:
            p1, p2 = full_txt[0], full_txt[2:]
            ax.text(label_x, y, p2, color='black', fontsize=18, ha='right', va='center')
            draw_sextile_custom_black(ax, label_x - 0.026, y, size=0.06, fig_w=12, fig_h=fig_h)
            ax.text(label_x - 0.035, y, p1, color='black', fontsize=18, ha='right', va='center')
        else:
            ax.text(label_x, y, full_txt, color='black', fontsize=18, ha='right', va='center')

        # VẼ CÁC ĐOẠN THỜI GIAN
        for p in row["periods"]:
            x1 = get_x(p["start"])
            x2 = 1.04 if p["is_clamped_end"] else get_x(p["end"])

            ax.annotate('', xy=(x2, y), xytext=(x1, y),
                        arrowprops=dict(arrowstyle='->', color='#888888', ls='--', lw=1.5))

            m_v_x = 0 if p["is_clamped_start"] else x1
            ax.plot([m_v_x, m_v_x], [y - 0.15, y + 0.15], color='gray', lw=4, zorder=4)

            if not p["is_clamped_start"]:
                ax.text(x1, TL_Y + 0.2, f"{p['start'].day}/{p['start'].month}", rotation=90, fontsize=7, color='blue',
                        ha='center', va='top', fontweight='bold', bbox=dict(facecolor='white', edgecolor='none', pad=0.2), zorder=20)
                ax.plot([x1, x1], [TL_Y, y], color='blue', ls=':', lw=0.7, alpha=0.4, zorder=1)

            if not p["is_clamped_end"]:
                ax.text(x2, TL_Y + 0.2, f"{p['end'].day}/{p['end'].month}", rotation=90, fontsize=7, color='blue',
                        ha='center', va='top', fontweight='bold', bbox=dict(facecolor='white', edgecolor='none', pad=0.2), zorder=20)
                ax.plot([x2, x2], [TL_Y, y], color='blue', ls=':', lw=0.7, alpha=0.4, zorder=1)

            for ex in p["exacts"]:
                xe = get_x(ex)
                ax.plot([xe, xe], [TL_Y, y], color='red', ls='--', lw=0.8, alpha=0.8, zorder=40)
                ax.text(xe, TL_Y + 0.2, f"{ex.day}/{ex.month}", rotation=90, fontsize=7, color='red', fontweight='black',
                        ha='center', va='top', bbox=dict(facecolor='white', edgecolor='none', pad=0.2), zorder=50)
                ax.text(xe, y, 'E', color='red', fontweight='black', fontsize=10, ha='center', va='center',
                        bbox=dict(facecolor='white', edgecolor='none', pad=0.1, alpha=1.0), zorder=60)

            if p.get("has_early_e") and p["is_clamped_start"]:
                ax.text(0.015, y, 'E', color='red', fontweight='black', fontsize=10, ha='left', va='center',
                        bbox=dict(facecolor='white', edgecolor='none', pad=0.1), zorder=60)
            
            if p.get("has_late_e") and p["is_clamped_end"]:
                ax.text(1.03, y, 'E', color='red', fontweight='black', fontsize=10, ha='left', va='center',
                        bbox=dict(facecolor='white', edgecolor='none', pad=0.1), zorder=60)

        current_y_offset += (ROW_HEIGHT + EXTRA_HOUSE_GAP) if (idx + 1 < len(rows_data) and rows_data[idx + 1]["type"] == "separator") else ROW_HEIGHT

    fig.subplots_adjust(left=0.03, right=0.97, top=0.98, bottom=0.02)
    output = io.BytesIO()
    FigureCanvas(fig).print_png(output)
    return base64.b64encode(output.getvalue()).decode('utf-8')
