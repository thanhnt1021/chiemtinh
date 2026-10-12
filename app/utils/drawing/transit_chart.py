import io
import base64
import numpy as np
import matplotlib
matplotlib.use('Agg')
from matplotlib.figure import Figure
from matplotlib.backends.backend_agg import FigureCanvasAgg as FigureCanvas
import astro00_lib as lib
from .styles import *
from .helpers import get_element_color, optimize_planet_positions_by_house, draw_spindle

def create_natal_transit_chart(natal_data, transit_data, name, date_str):
    fig = Figure(figsize=(12, 12), dpi=100)
    ax = fig.add_subplot(111, projection='polar')

    ax.set_theta_zero_location('E')
    ax.set_theta_direction(1)
    ax.grid(False)
    ax.set_yticklabels([]); ax.set_xticklabels([])
    ax.spines['polar'].set_visible(False)

    if not natal_data: return None

    # --- CẤU HÌNH BÁN KÍNH ---
    R_INNER = 6.0
    R_PLANET = 8.0
    R_ZODIAC_INNER = 8.0
    R_ZODIAC_OUTER = 9.5 # Vòng tròn Zodiac kết thúc ở đây
    
    # Transit Settings
    R_TRANS_TICK_START = R_ZODIAC_OUTER
    R_TRANS_TICK_END = R_ZODIAC_OUTER + 0.5  # Đỉnh rễ thò ra 0.5
    R_TRANS_TEXT = R_ZODIAC_OUTER + 1.5      # Vị trí chữ cách đỉnh rễ ~1.0 (Tổng 1.5 từ vành đai)
    
    # Màu xanh lá cây cho Transit (Lấy từ COLOR_MINOR)
    COLOR_TRANSIT = COLOR_MINOR 

    # 1. SETUP GÓC NHÌN THEO NATAL ASC
    asc_deg = natal_data["angles"]["Asc"]
    ax.set_theta_offset(np.deg2rad(180 - asc_deg))

    # 2. VẼ NỀN (GIỐNG NATAL)
    theta = np.linspace(0, 2 * np.pi, 100)
    # Vùng Natal
    ax.fill_between(theta, 0, R_INNER, color='white')
    ax.fill_between(theta, R_INNER, R_PLANET, color=BG_COLOR_2)
    
    # Vùng Zodiac
    ax.fill_between(theta, R_ZODIAC_INNER, R_ZODIAC_OUTER, color=BG_COLOR_1)

    # Các vòng tròn biên
    circle_radii = [R_INNER, R_PLANET, 8.15, 9.35, R_ZODIAC_OUTER]
    for r in circle_radii: ax.plot(theta, [r] * 100, color='black', linewidth=0.5)

    # 3. VẼ ZODIAC (CUNG HOÀNG ĐẠO)
    for i in range(12):
        rad_start = np.deg2rad(i * 30)
        rad_mid = np.deg2rad(i * 30 + 15)
        elem_color = get_element_color(i)
        ax.bar(rad_mid, 9.35 - 8.15, width=np.deg2rad(30), bottom=8.15, color=elem_color, edgecolor='none')
        ax.plot([rad_start, rad_start], [R_ZODIAC_INNER, R_ZODIAC_OUTER], color='white', linewidth=0.5)
        ax.text(rad_mid, (R_ZODIAC_INNER + R_ZODIAC_OUTER) / 2, lib.ZODIAC_SYMBOLS[i],
                ha='center', va='center', fontsize=14, fontweight='bold', color=BG_COLOR_1)

    # 4. VẼ HOUSE CUSPS (NATAL)
    cusps = natal_data["cusps"][1:] if len(natal_data["cusps"]) == 13 else natal_data["cusps"]
    for i, deg in enumerate(cusps):
        rad = np.deg2rad(deg)
        lw = 2.0 if i in [0, 3, 6, 9] else 0.5
        ax.plot([rad, rad], [R_INNER, R_PLANET], color='black', linewidth=lw)
        # Số nhà
        next_deg = cusps[(i + 1) % 12]
        mid = (deg + next_deg) / 2 if next_deg > deg else (deg + next_deg + 360) / 2
        ax.text(np.deg2rad(mid), 5.8, str(i + 1), fontsize=8, color='gray', ha='center')

    # 5. VẼ NATAL PLANETS (BÊN TRONG)
    p_list_natal = []
    for p_name, info in natal_data["planets"].items():
        if p_name not in lib.PLANET_SYMBOLS: continue
        if p_name in ['Asc', 'MC']: continue
        p_list_natal.append({'name': p_name, 'lon': info['lon'], 'sym': lib.PLANET_SYMBOLS[p_name]})

    lanes_natal = [7.3, 6.5]
    opt_natal = optimize_planet_positions_by_house(p_list_natal, cusps, lanes=lanes_natal)

    for p in opt_natal:
        true_rad = np.deg2rad(p['lon'])
        disp_rad = np.deg2rad(p['disp_lon'])
        r_pos = p['disp_r']
        # Kẻ vạch nối từ vị trí thật
        ax.plot([true_rad, true_rad], [R_INNER, R_INNER + 0.3], color='blue', linewidth=1)
        # Kẻ vạch nối đến text
        ax.plot([true_rad, disp_rad], [R_INNER + 0.3, r_pos - 0.2], color='blue', linewidth=0.5)
        
        f_size = 18
        if p['name'] in ["Vertex", "Chiron", "True Node", "Lilith"]: f_size = 12
        ax.text(disp_rad, r_pos, p['sym'], fontsize=f_size, fontweight='bold', color='black', ha='center', va='center')

    # 6. VẼ TRANSIT PLANETS (BÊN NGOÀI - MÀU XANH LÁ)
    if transit_data:
        p_list_trans = []
        for p_name, info in transit_data["planets"].items():
            if p_name not in lib.PLANET_SYMBOLS: continue
            if p_name in ['Asc', 'MC', 'Vertex']: continue # Thường không xem trục transit
            p_list_trans.append({'name': p_name, 'lon': info['lon'], 'sym': lib.PLANET_SYMBOLS[p_name]})
        
        # Tối ưu vị trí hiển thị vòng ngoài (Dùng hàm cũ nhưng map vào bán kính lớn)
        # Tạo cusps giả đều nhau để thuật toán phân bố hoạt động tốt trên vòng tròn mở
        dummy_cusps = [i*30 for i in range(12)] 
        
        # Chỉ dùng 1 lane duy nhất ở ngoài
        lanes_trans = [R_TRANS_TEXT] 
        opt_trans = optimize_planet_positions_by_house(p_list_trans, dummy_cusps, lanes=lanes_trans)

        for p in opt_trans:
            true_rad = np.deg2rad(p['lon'])
            disp_rad = np.deg2rad(p['disp_lon'])
            r_pos = p['disp_r']

            # A. VẼ ĐỈNH RỄ (Tick Mark) - Thò ra từ vòng Zodiac
            # Từ R_ZODIAC_OUTER (9.5) đến R_TRANS_TICK_END (10.0)
            ax.plot([true_rad, true_rad], [R_TRANS_TICK_START, R_TRANS_TICK_END], 
                    color=COLOR_TRANSIT, linewidth=2.0) # Đậm, màu xanh lá

            # B. VẼ ĐƯỜNG DẪN MỎNG (nếu bị dịch chuyển)
            if abs(true_rad - disp_rad) > 0.01:
                 ax.plot([true_rad, disp_rad], [R_TRANS_TICK_END, r_pos - 0.3], 
                         color=COLOR_TRANSIT, linewidth=0.5, linestyle=':')

            # C. VẼ SYMBOL HÀNH TINH
            f_size = 18
            if p['name'] in ["Vertex", "Chiron", "True Node", "Lilith"]: f_size = 14
            
            # Tô màu nền trắng nhỏ dưới chữ để đỡ bị rối nếu đè vạch
            ax.text(disp_rad, r_pos, p['sym'], fontsize=f_size, fontweight='bold', 
                    color=COLOR_TRANSIT, ha='center', va='center')


    # 7. TIÊU ĐỀ
    ax.set_title(f"{name} (Inner) & Transits (Outer - Green)", y=1.08, fontsize=16, fontweight='bold')

    output = io.BytesIO()
    FigureCanvas(fig).print_png(output)
    return base64.b64encode(output.getvalue()).decode('utf-8')
