import io
import base64
import numpy as np
import matplotlib

matplotlib.use('Agg')
from matplotlib.figure import Figure
from matplotlib.backends.backend_agg import FigureCanvasAgg as FigureCanvas
import matplotlib.patches as patches
import astro00_lib as lib
from .styles import *
from .helpers import get_element_color, optimize_planet_positions_by_house, draw_spindle


def check_arc_collision(arc1, arc2, buffer=2.0):
    s1, e1 = arc1['start'], arc1['end']
    s2, e2 = arc2['start'], arc2['end']

    def norm(deg):
        return deg % 360

    def is_in_arc(p, s, e):
        p = norm(p)
        if s <= e:
            return s <= p <= e
        else:
            return p >= s or p <= e

    s1_buf = norm(s1 - buffer)
    e1_buf = norm(e1 + buffer)
    if is_in_arc(s2, s1_buf, e1_buf) or is_in_arc(e2, s1_buf, e1_buf): return True
    if is_in_arc(s1_buf, s2, e2) or is_in_arc(e1_buf, s2, e2): return True
    return False


def create_natal_chart_image(chart_data, name, hide_houses=False, transit_data=None, transit_mode='single',
                             static_aries_asc=False):
    # --- BƯỚC 1: TÍNH TOÁN R_OUTER ---
    R_ZODIAC_OUTER = 9.5
    R_OUTER = 11.5

    precalc_lanes = None
    precalc_sorted_planets = None

    if transit_mode == 'outer_cycle' and transit_data:
        LANE_BASE_R = R_ZODIAC_OUTER + 0.5
        LANE_HEIGHT = 0.5
        sorted_planets = []
        for p_name, data in transit_data.items():
            sorted_planets.append({
                'name': p_name,
                'sym': lib.PLANET_SYMBOLS.get(p_name, '?'),
                'start': data['start'], 'end': data['end'], 'len': data['len'],
                'A': data['A'], 'B': data['B']
            })
        sorted_planets.sort(key=lambda x: x['len'], reverse=True)
        lanes = []
        for p in sorted_planets:
            assigned_idx = -1
            for idx, lane_objs in enumerate(lanes):
                collision = False
                for existing in lane_objs:
                    if check_arc_collision(p, existing):
                        collision = True;
                        break
                if not collision:
                    assigned_idx = idx;
                    break
            if assigned_idx == -1:
                lanes.append([])
                assigned_idx = len(lanes) - 1
            lanes[assigned_idx].append(p)
            p['lane_idx'] = assigned_idx
        precalc_lanes = lanes
        precalc_sorted_planets = sorted_planets
        calculated_outer = LANE_BASE_R + (len(lanes) * LANE_HEIGHT) + 0.5
        R_OUTER = max(11.5, calculated_outer)

    # --- BƯỚC 2: DRAWING ---
    scale_factor = R_OUTER / 11.5
    fig_size = min(12 * scale_factor, 20)

    fig = Figure(figsize=(fig_size, fig_size), dpi=100)
    ax = fig.add_subplot(111, projection='polar')

    ax.set_theta_zero_location('E')
    ax.set_theta_direction(1)
    ax.grid(False)
    ax.set_yticklabels([]);
    ax.set_xticklabels([])
    ax.spines['polar'].set_visible(False)

    if not chart_data: return None

    # --- LOGIC XOAY MỚI ---
    if static_aries_asc:
        # Nếu bật chế độ này: Ép 0 độ (Bạch Dương) nằm ở vị trí 9h (180 độ hình học)
        # 180 - 0 = 180 (Pi)
        asc_deg = 0
    else:
        asc_deg = chart_data["angles"]["Asc"]

    ax.set_theta_offset(np.deg2rad(180 - asc_deg))

    R0, R_CENTER_DOT, R_INNER_RING = 0.0, 0.05, 1.4
    R_ASPECT_TIP, R_MID, R_PLANET = 5.25, 5.5, 8.0
    R_ZODIAC_INNER = 8.0

    # 3. VẼ NỀN
    theta = np.linspace(0, 2 * np.pi, 100)
    ax.fill_between(theta, R0, R_ASPECT_TIP, color=BG_COLOR_1)
    ax.fill_between(theta, R_ASPECT_TIP, R_MID, color=BG_COLOR_1)
    ax.fill_between(theta, R_MID, R_PLANET, color=BG_COLOR_2)
    ax.fill_between(theta, R_ZODIAC_INNER, R_ZODIAC_OUTER, color=BG_COLOR_1)
    ax.fill_between(theta, R_ZODIAC_OUTER, R_OUTER, color=BG_COLOR_2)

    circle_radii = [R_MID, R_PLANET, 8.15, 9.35, R_ZODIAC_OUTER]
    for r in circle_radii: ax.plot(theta, [r] * 100, color='black', linewidth=0.5)

    ax.plot(theta, [R_INNER_RING] * 100, color='gray', linewidth=1.0, linestyle=':')
    ax.fill_between(theta, 0, R_CENTER_DOT, color='black')

    # 4. VẼ ZODIAC
    for i in range(12):
        rad_start = np.deg2rad(i * 30)
        rad_mid = np.deg2rad(i * 30 + 15)
        elem_color = get_element_color(i)
        ax.bar(rad_mid, 9.35 - 8.15, width=np.deg2rad(30), bottom=8.15, color=elem_color, edgecolor='none')
        ax.plot([rad_start, rad_start], [R_ZODIAC_INNER, R_ZODIAC_OUTER], color='white', linewidth=0.5)
        ax.text(rad_mid, (R_ZODIAC_INNER + R_ZODIAC_OUTER) / 2, lib.ZODIAC_SYMBOLS[i],
                ha='center', va='center', fontsize=25, fontweight='bold', color=BG_COLOR_1)

    # 5. VẼ HOUSE CUSPS (CHỈ VẼ NẾU KHÔNG ẨN - TRONG CURRENT SKY SẼ ẨN)
    cusps = chart_data["cusps"][1:] if len(chart_data["cusps"]) == 13 else chart_data["cusps"]

    if not hide_houses:
        angle_indices = [0, 3, 6, 9]
        for i, deg in enumerate(cusps):
            rad = np.deg2rad(deg)
            if i in angle_indices:
                ax.plot([rad, rad], [R_INNER_RING, R_PLANET], color='black', linewidth=2.5)
                ax.plot([rad, rad], [R_ZODIAC_OUTER, R_ZODIAC_OUTER + 0.2], color='black', linewidth=1.5)
                label_txt = ["AC", "IC", "DC", "MC"][i // 3]
                ax.text(rad, R_ZODIAC_OUTER + 1, label_txt, ha='center', va='center', fontsize=20, fontweight='bold',
                        color='black')
            else:
                ax.plot([rad, rad], [R_MID, R_PLANET], color='black', linewidth=0.5)

            next_deg = cusps[(i + 1) % 12]
            mid = (deg + next_deg) / 2 if next_deg > deg else (deg + next_deg + 360) / 2
            ax.text(np.deg2rad(mid), R_MID + 0.35, str(i + 1), fontsize=10, fontweight='bold', color='gray',
                    ha='center')
    else:
        # Nếu ẩn House nhưng vẫn muốn vẽ vạch chia độ (tùy chọn)
        # Ở đây ta giữ sạch sẽ theo yêu cầu của Vận Hạn Chung (chỉ hiện Zodiac và Planet)
        pass

    # 6. VẼ PLANETS
    p_list = []
    for p_name, info in chart_data["planets"].items():
        if p_name not in lib.PLANET_SYMBOLS or p_name == "Lilith": continue
        # Nếu đang Static Aries (Current Sky), ẩn Asc/MC khỏi vòng tròn
        if static_aries_asc and p_name in ['Asc', 'MC']: continue
        if p_name in ['Asc', 'MC']: continue
        p_list.append({'name': p_name, 'lon': info['lon'], 'sym': lib.PLANET_SYMBOLS[p_name]})

    # Nếu đang mode Static Aries, ta giả lập cusps đều 30 độ bắt đầu từ 0 để xếp hành tinh cho đẹp
    if static_aries_asc:
        draw_cusps = [i * 30 for i in range(12)]
    else:
        draw_cusps = cusps

    lanes_natal = [7.3, 6.2]
    optimized_planets = optimize_planet_positions_by_house(p_list, draw_cusps, lanes=lanes_natal)

    for p in optimized_planets:
        true_rad = np.deg2rad(p['lon'])
        disp_rad = np.deg2rad(p['disp_lon'])
        r_pos = p['disp_r']
        ax.plot([true_rad, true_rad], [R_MID, R_MID - 0.2], color='blue', linewidth=1.5)
        ax.plot([true_rad, true_rad], [R_PLANET, R_PLANET - 0.2], color='blue', linewidth=1.5)
        f_size = 20
        if p['name'] in ["Vertex", "Chiron", "True Node", "Lilith"]: f_size = 14
        ax.text(disp_rad, r_pos, p['sym'], fontsize=f_size, fontweight='bold', color='black', ha='center', va='center')

    # 7. VẼ ASPECT LINES
    NON_PLANETS = ["Asc", "MC", "True Node", "Chiron", "Lilith", "Vertex"]
    all_objs = {k: v['lon'] for k, v in chart_data["planets"].items() if k in lib.PLANET_SYMBOLS}
    keys = list(all_objs.keys())

    for i in range(len(keys)):
        for j in range(i + 1, len(keys)):
            p1, p2 = keys[i], keys[j]
            if p1 in NON_PLANETS or p2 in NON_PLANETS: continue
            asp = lib.check_aspect(all_objs[p1], all_objs[p2])
            if asp:
                r1, r2 = np.deg2rad(all_objs[p1]), np.deg2rad(all_objs[p2])
                if asp['aspect'] == 'Conjunction':
                    col = COLOR_CONJUNCTION
                elif asp['aspect'] == 'Opposition':
                    col = COLOR_OPPOSITION
                elif asp['type'] == 'Hard':
                    col = COLOR_HARD
                elif asp['type'] == 'Minor':
                    col = COLOR_MINOR
                else:
                    col = COLOR_SOFT

                if asp['aspect'] == 'Conjunction':
                    lw = 4.0 if asp['orb'] < 2 else 2.0
                    alpha = 0.8 if asp['orb'] < 3 else 0.4
                    ax.plot([r1, r2], [R_ASPECT_TIP, R_ASPECT_TIP], color='black', linewidth=lw + 1.5, alpha=alpha)
                    ax.plot([r1, r2], [R_ASPECT_TIP, R_ASPECT_TIP], color=col, linewidth=lw, alpha=alpha)
                else:
                    max_orb = lib.ASPECTS_DEF[asp['aspect']]['orb']
                    orb_ratio = 1.0 - (asp['orb'] / max_orb)
                    if orb_ratio < 0: orb_ratio = 0
                    alpha = 0.4 + 0.4 * orb_ratio
                    draw_spindle(ax, r1, r2, R_ASPECT_TIP, col, max_width=0.25, alpha=alpha, orb_ratio=orb_ratio)

    # 8. TRANSIT (Giữ nguyên logic cũ nếu có)
    if transit_data:
        if transit_mode == 'single':
            R_ROOT_BASE, R_ROOT_TIP, R_TEXT_POS = R_ZODIAC_OUTER, R_ZODIAC_OUTER + 0.5, R_ZODIAC_OUTER + 0.5 + 1.5
            t_planets = []
            for p_name, info in transit_data["planets"].items():
                if p_name not in lib.PLANET_SYMBOLS: continue
                if p_name in ['Asc', 'MC', 'Lilith']: continue
                t_planets.append({'name': p_name, 'lon': info['lon'], 'sym': lib.PLANET_SYMBOLS[p_name]})
            dummy_cusps = [i * 30 for i in range(12)]
            opt_trans = optimize_planet_positions_by_house(t_planets, dummy_cusps, lanes=[R_TEXT_POS])
            for p in opt_trans:
                true_rad, disp_rad = np.deg2rad(p['lon']), np.deg2rad(p['disp_lon'])
                ax.plot([true_rad, true_rad], [R_ROOT_BASE, R_ROOT_TIP], color=COLOR_MINOR, linewidth=2.0)
                ax.plot([true_rad, disp_rad], [R_ROOT_TIP, R_TEXT_POS - 0.3], color=COLOR_MINOR, linewidth=0.5,
                        linestyle=':')
                f_size = 20 if p['name'] not in ["Vertex", "Chiron", "True Node", "Lilith"] else 14
                ax.text(disp_rad, R_TEXT_POS, p['sym'], fontsize=f_size, fontweight='bold', color=COLOR_MINOR,
                        ha='center', va='center')

        elif transit_mode == 'outer_cycle' and precalc_sorted_planets:
            R_TRANSIT_BASE, R_TRANSIT_TIP, R_TRANSIT_TEXT = R_ZODIAC_OUTER, R_ZODIAC_OUTER + 0.5, R_ZODIAC_OUTER + 1.5
            p_base_list = [{'name': p['name'], 'lon': p['A'], 'sym': p['sym']} for p in precalc_sorted_planets]
            opt_base = optimize_planet_positions_by_house(p_base_list, [i * 30 for i in range(12)],
                                                          lanes=[R_TRANSIT_TEXT])
            for p in opt_base:
                true_rad, disp_rad = np.deg2rad(p['lon']), np.deg2rad(p['disp_lon'])
                ax.plot([true_rad, true_rad], [R_TRANSIT_BASE, R_TRANSIT_TIP], color=COLOR_MINOR, linewidth=2.0)
                ax.plot([true_rad, disp_rad], [R_TRANSIT_TIP, R_TRANSIT_TEXT - 0.3], color=COLOR_MINOR, linewidth=0.5,
                        linestyle=':')
                f_size = 20 if p['name'] not in ["Vertex", "Chiron", "True Node", "Lilith"] else 14
                ax.text(disp_rad, R_TRANSIT_TEXT, p['sym'], fontsize=f_size, fontweight='bold', color=COLOR_MINOR,
                        ha='center', va='center')

            LANE_BASE_R, LANE_HEIGHT, TICK_LEN = 11.5 + 0.5, 0.5, 0.2
            for p in precalc_sorted_planets:
                r_lane = LANE_BASE_R + (p['lane_idx'] * LANE_HEIGHT)
                start_rad, end_rad = np.deg2rad(p['start']), np.deg2rad(p['end'])
                if p['end'] < p['start']:
                    w1, w2 = np.deg2rad(360 - p['start']), np.deg2rad(p['end'])
                    ax.bar(start_rad + w1 / 2, 0.05, width=w1, bottom=r_lane, color=COLOR_MINOR, edgecolor='none',
                           alpha=0.8)
                    ax.bar(0 + w2 / 2, 0.05, width=w2, bottom=r_lane, color=COLOR_MINOR, edgecolor='none', alpha=0.8)
                else:
                    ax.bar(start_rad + (end_rad - start_rad) / 2, 0.05, width=end_rad - start_rad, bottom=r_lane,
                           color=COLOR_MINOR, edgecolor='none', alpha=0.8)
                rad_A, rad_B = np.deg2rad(p['A']), np.deg2rad(p['B'])
                ax.plot([rad_A, rad_A], [r_lane, r_lane - TICK_LEN], color=COLOR_MINOR, linewidth=0.8)
                ax.plot([rad_B, rad_B], [r_lane, r_lane - TICK_LEN], color=COLOR_MINOR, linewidth=0.8)

    title_suffix = ""
    if transit_data:
        title_suffix = " & TRANSITS" if transit_mode == 'single' else " & OUTER CYCLES"
    ax.set_title(f"NATAL CHART: {name.upper()}{title_suffix}", y=1.08, fontsize=18, fontweight='bold')

    output = io.BytesIO()
    FigureCanvas(fig).print_png(output)
    return base64.b64encode(output.getvalue()).decode('utf-8')
