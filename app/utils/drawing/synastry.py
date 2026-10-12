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


def create_synastry_chart_image(cA, cB, nA, nB):
    fig = Figure(figsize=(12, 12), dpi=100)
    ax = fig.add_subplot(111, projection='polar')

    ax.set_theta_zero_location('E')
    ax.set_theta_direction(1)
    ax.grid(False)
    ax.set_yticklabels([]);
    ax.set_xticklabels([]);
    ax.spines['polar'].set_visible(False)

    if not cA or not cB: return None

    offset = 180 - cA["angles"]["Asc"]
    ax.set_theta_offset(np.deg2rad(offset))

    R0, R_CENTER, R_A_OUT, R_B_OUT = 0.0, 4.0, 6.0, 8.0
    R_ZODIAC_OUTER, R_OUTER = 9.5, 11.5

    theta = np.linspace(0, 2 * np.pi, 100)
    ax.fill_between(theta, R0, R_CENTER, color=BG_COLOR_1)
    ax.fill_between(theta, R_CENTER, R_A_OUT, color=BG_COLOR_2)
    ax.fill_between(theta, R_A_OUT, R_B_OUT, color=BG_COLOR_2)
    ax.fill_between(theta, R_B_OUT, R_ZODIAC_OUTER, color=BG_COLOR_1)
    ax.fill_between(theta, R_ZODIAC_OUTER, R_OUTER, color=BG_COLOR_2)

    borders = [R_CENTER, R_A_OUT, R_B_OUT, 8.15, 9.35, R_ZODIAC_OUTER]
    for r in borders: ax.plot(theta, [r] * 100, color='black', linewidth=0.5)

    for i in range(12):
        rad_start = np.deg2rad(i * 30)
        rad_mid = np.deg2rad(i * 30 + 15)
        elem_color = get_element_color(i)
        ax.bar(rad_mid, 9.35 - 8.15, width=np.deg2rad(30), bottom=8.15, color=elem_color, edgecolor='none')
        ax.plot([rad_start, rad_start], [R_B_OUT, R_ZODIAC_OUTER], color='white', linewidth=0.5)
        ax.text(rad_mid, (R_B_OUT + R_ZODIAC_OUTER) / 2, lib.ZODIAC_SYMBOLS[i],
                ha='center', va='center', fontsize=25, fontweight='bold', color=BG_COLOR_1)

    angle_indices = [0, 3, 6, 9]
    cuspsA = cA["cusps"][1:] if len(cA["cusps"]) == 13 else cA["cusps"]
    for i, deg in enumerate(cuspsA):
        rad = np.deg2rad(deg)
        lw = 2.5 if i in angle_indices else 0.5
        ax.plot([rad, rad], [R_CENTER, R_A_OUT], color=COLOR_A, linewidth=lw, alpha=0.6)
        num_rad = np.deg2rad(deg + 3.0)
        ax.text(num_rad, R_CENTER + 0.25, str(i + 1), fontsize=9, fontweight='bold', color=COLOR_A, ha='center',
                va='center')

    cuspsB = cB["cusps"][1:] if len(cB["cusps"]) == 13 else cB["cusps"]
    for i, deg in enumerate(cuspsB):
        rad = np.deg2rad(deg)
        lw = 2.5 if i in angle_indices else 0.5
        ax.plot([rad, rad], [R_A_OUT, R_B_OUT], color=COLOR_B, linewidth=lw, alpha=0.6)
        num_rad = np.deg2rad(deg + 3.0)
        ax.text(num_rad, R_B_OUT - 0.25, str(i + 1), fontsize=9, fontweight='bold', color=COLOR_B, ha='center',
                va='center')

    def draw_angle_labels(chart, color_lbl):
        angles = chart["angles"]
        ac, mc = angles["Asc"], angles["MC"]
        dc, ic = (ac + 180) % 360, (mc + 180) % 360
        lbls = [(ac, "AC"), (ic, "IC"), (dc, "DC"), (mc, "MC")]
        for deg, txt in lbls:
            rad = np.deg2rad(deg)
            ax.plot([rad, rad], [R_ZODIAC_OUTER, R_ZODIAC_OUTER + 0.2], color=color_lbl, linewidth=1.5)
            ax.text(rad, R_ZODIAC_OUTER + 0.7, txt, ha='center', va='center', fontsize=20, fontweight='bold',
                    color=color_lbl)
    # VẼ ĐỈNH 4 nhà AC-IC-DC-MC
    # draw_angle_labels(cA, COLOR_A)

    p_list_A = []
    for k, v in cA["planets"].items():
        if k not in lib.PLANET_SYMBOLS: continue
        if k == "Lilith": continue
        if k in ['Asc', 'MC']: continue
        p_list_A.append({'name': k, 'lon': v['lon'], 'sym': lib.PLANET_SYMBOLS[k]})
    lanes_A = [5.4, 4.6]
    opt_A = optimize_planet_positions_by_house(p_list_A, cA["cusps"], lanes=lanes_A)
    for p in opt_A:
        true_rad = np.deg2rad(p['lon'])
        disp_rad = np.deg2rad(p['disp_lon'])
        r_pos = p['disp_r']
        ax.plot([true_rad, true_rad], [R_A_OUT, R_A_OUT - 0.1], color=COLOR_A, linewidth=1.5)
        ax.plot([true_rad, true_rad], [R_CENTER, R_CENTER + 0.1], color=COLOR_A, linewidth=1.5)
        f_size = 20
        if p['name'] in ["Vertex", "Chiron", "True Node", "Lilith"]: f_size = 15
        ax.text(disp_rad, r_pos, p['sym'], fontsize=f_size, fontweight='bold', color=COLOR_A, ha='center', va='center')

    p_list_B = []
    for k, v in cB["planets"].items():
        if k not in lib.PLANET_SYMBOLS: continue
        if k == "Lilith": continue
        if k in ['Asc', 'MC']: continue
        p_list_B.append({'name': k, 'lon': v['lon'], 'sym': lib.PLANET_SYMBOLS[k]})
    lanes_B = [7.4, 6.6]
    opt_B = optimize_planet_positions_by_house(p_list_B, cB["cusps"], lanes=lanes_B)
    for p in opt_B:
        true_rad = np.deg2rad(p['lon'])
        disp_rad = np.deg2rad(p['disp_lon'])
        r_pos = p['disp_r']
        ax.plot([true_rad, true_rad], [R_A_OUT, R_A_OUT + 0.1], color=COLOR_B, linewidth=1.5)
        ax.plot([true_rad, true_rad], [R_B_OUT, R_B_OUT - 0.1], color=COLOR_B, linewidth=1.5)
        f_size = 18
        if p['name'] in ["Vertex", "Chiron", "True Node", "Lilith"]: f_size = 13
        ax.text(disp_rad, r_pos, p['sym'], fontsize=f_size, fontweight='bold', color=COLOR_B, ha='center', va='center')

    # --- CẬP NHẬT: Vẽ Aspect Lines với Orb chặt hơn và chặn điểm ảo ---
    NON_PLANETS = ["Asc", "MC", "True Node", "Chiron", "Lilith", "Vertex"]

    # Bộ Orb siêu chặt cho Synastry Chart
    SYNASTRY_CHART_ORBS = {
        "Conjunction": 5.0,
        "Opposition": 5.0,
        "Square": 5.0,
        "Trine": 5.0,
        "Sextile": 3.0,
        "Semisextile": 1.5,
        "Quincunx": 1.5
    }

    # Lấy toàn bộ objects
    all_A = {k: v['lon'] for k, v in cA["planets"].items() if k in lib.PLANET_SYMBOLS}
    all_B = {k: v['lon'] for k, v in cB["planets"].items() if k in lib.PLANET_SYMBOLS}

    for pA_name, lA in all_A.items():
        for pB_name, lB in all_B.items():

            # --- 1. CHẶN ĐIỂM ẢO (Không vẽ đường nối) ---
            if pA_name in NON_PLANETS or pB_name in NON_PLANETS:
                continue

            # --- 2. GỌI check_aspect VỚI ORB TÙY BIẾN ---
            asp = lib.check_aspect(lA, lB, custom_orbs=SYNASTRY_CHART_ORBS)

            if asp:
                r1, r2 = np.deg2rad(lA), np.deg2rad(lB)

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
                    ax.plot([r1, r2], [R_CENTER, R_CENTER], color='black', linewidth=lw + 1.5, alpha=alpha)
                    ax.plot([r1, r2], [R_CENTER, R_CENTER], color=col, linewidth=lw, alpha=alpha)
                else:
                    # Lấy max orb từ bộ custom để tính độ mờ
                    max_orb = SYNASTRY_CHART_ORBS.get(asp['aspect'], 10.0)
                    orb_ratio = 1.0 - (asp['orb'] / max_orb)
                    if orb_ratio < 0: orb_ratio = 0
                    alpha = 0.4 + 0.4 * orb_ratio

                    draw_spindle(ax, r1, r2, R_CENTER, col, max_width=0.18, alpha=alpha, orb_ratio=orb_ratio)

    ax.set_title(f"SYNASTRY: {nA} & {nB}", y=1.08, fontsize=18, fontweight='bold')

    output = io.BytesIO()
    FigureCanvas(fig).print_png(output)
    return base64.b64encode(output.getvalue()).decode('utf-8')
