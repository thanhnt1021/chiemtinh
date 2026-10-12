import io
import base64
import math
import matplotlib

matplotlib.use('Agg')
from matplotlib.figure import Figure
from matplotlib.backends.backend_agg import FigureCanvasAgg as FigureCanvas
import matplotlib.patches as patches
import matplotlib.lines as lines
import matplotlib.patheffects as path_effects
import astro00_lib as lib
from .styles import *


def draw_custom_symbol(ax, x, y, symbol, color):
    cx, cy = x + 0.5, y + 0.5
    size = 0.36

    if symbol == '⚺':  # Semisextile
        y_base = cy + size / 2 - 0.05
        x_base_left = cx - size / 2
        x_base_right = cx + size / 2
        ax.add_line(lines.Line2D([x_base_left, x_base_right], [y_base, y_base], color=color, linewidth=2))
        x_tip, y_tip = cx, y_base
        y_top = cy - size / 2 + 0.05
        x_left, x_right = cx - size / 2, cx + size / 2
        ax.add_line(lines.Line2D([x_tip, x_left], [y_tip, y_top], color=color, linewidth=2))
        ax.add_line(lines.Line2D([x_tip, x_right], [y_tip, y_top], color=color, linewidth=2))

    elif symbol == '⚻':  # Quincunx
        y_bar = cy - size / 2
        x_base_left = cx - size / 2
        x_base_right = cx + size / 2
        ax.add_line(lines.Line2D([x_base_left, x_base_right], [y_bar, y_bar], color=color, linewidth=2))
        y_tip = y_bar + 0.01
        y_bottom = cy + size / 2 - 0.05
        x_left, x_right = cx - size / 2, cx + size / 2
        ax.add_line(lines.Line2D([cx, x_left], [y_tip, y_bottom], color=color, linewidth=2))
        ax.add_line(lines.Line2D([cx, x_right], [y_tip, y_bottom], color=color, linewidth=2))


def draw_cell(ax, x, y, text=None, sub_text_tr=None, sub_text_bl=None, bg_color='white',
              border_style='normal', text_color='black', font_size=12,
              is_bold=False, font_family=None, draw_sextile_manual=False, sextile_color='blue',
              custom_border_color=None, custom_border_width=None,
              custom_symbol=None,
              text_scale=1.0,
              text_stroke_width=None):
    GAP = 0.04
    SQUARE_SIZE = 1.0 - 2 * GAP
    FONT_ORB = 9
    FONT_REAL_ORB = 7

    lw, ls, ec = 0.5, '-', '#d1d5db'
    if custom_border_color and custom_border_width:
        ec, lw = custom_border_color, custom_border_width
    elif border_style == 'bold':
        lw, ec = 2.5, 'black'
    elif border_style == 'blue_bold':
        lw, ec = 3.0, '#2563eb'
    elif border_style == 'red_bold':
        lw, ec = 3.0, '#dc2626'
    elif border_style == 'blue_bold_soft':
        lw, ec = 2.0, '#60a5fa'
    elif border_style == 'red_bold_soft':
        lw, ec = 2.0, '#f87171'
    elif border_style == 'dashed':
        ls, lw, ec = (0, (8, 7)), 1.0, '#8e8e8e'

    rect = patches.Rectangle((x + GAP, y + GAP), SQUARE_SIZE, SQUARE_SIZE, linewidth=lw, edgecolor=ec,
                             facecolor=bg_color, linestyle=ls)
    ax.add_patch(rect)

    if custom_symbol:
        draw_custom_symbol(ax, x, y, custom_symbol, text_color)
    elif draw_sextile_manual:
        cx, cy = x + 0.5, y + 0.5;
        r = 0.12
        line_kw = {'color': sextile_color, 'linewidth': 1.2, 'solid_capstyle': 'round'}
        ax.plot([cx, cx], [cy - r, cy + r], **line_kw)
        dx = r * 0.866;
        dy = r * 0.5
        ax.plot([cx - dx, cx + dx], [cy - dy, cy + dy], **line_kw)
        ax.plot([cx - dx, cx + dx], [cy + dy, cy - dy], **line_kw)
    elif text == '□':
        cx, cy = x + 0.5, y + 0.5;
        s = 0.36
        ax.add_patch(
            patches.Rectangle((cx - s / 2, cy - s / 2), s, s, linewidth=1.5, edgecolor=text_color, facecolor='none'))
    elif text == '△':
        cx, cy = x + 0.5, y + 0.5 + 0.04;
        r = 0.22
        verts = [(cx, cy - r), (cx + r * 0.866, cy + r * 0.5), (cx - r * 0.866, cy + r * 0.5)]
        ax.add_patch(patches.Polygon(verts, closed=True, linewidth=1.5, edgecolor=text_color, facecolor='none'))
    elif text:
        fw = 'bold' if is_bold else 'normal'
        if text in ['☉', '☽']: fw = 'bold'
        final_font_size = font_size * text_scale
        kw = {'ha': 'center', 'va': 'center', 'fontsize': final_font_size, 'fontweight': fw, 'color': text_color}
        if font_family: kw['fontname'] = font_family
        txt_obj = ax.text(x + 0.5, y + 0.5, text, **kw)
        if text_stroke_width:
            txt_obj.set_path_effects([
                path_effects.withStroke(linewidth=text_stroke_width, foreground=text_color)
            ])

    if sub_text_tr:
        ax.text(x + SQUARE_SIZE - 0.05, y + GAP + 0.05, sub_text_tr, ha='right', va='top', fontsize=FONT_ORB,
                color='gray')
    if sub_text_bl:
        ax.text(x + GAP + 0.05, y + GAP + SQUARE_SIZE - 0.025, sub_text_bl, ha='left', va='bottom',
                fontsize=FONT_REAL_ORB, color='gray')


def draw_aspect_grid_image(chart_data_A, chart_data_B=None, is_synastry=False, show_real_orb=False, analysis_data=None,
                           is_current_sky=False):
    DPI = 100
    FONT_SYM = 26
    FONT_HEADER = 12
    FONT_PLANET = 21

    NATAL_OBJS = ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto",
                  "True Node", "Chiron", "Vertex", "Asc", "MC"]
    SYNASTRY_OBJS = ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto",
                     "Asc", "True Node", "Chiron", "Vertex"]

    if is_synastry:
        OBJS = SYNASTRY_OBJS
    else:
        if is_current_sky:
            # Current Sky: Loại bỏ Asc và MC khỏi danh sách
            OBJS = [p for p in NATAL_OBJS if p not in ["Asc", "MC"]]
        else:
            OBJS = NATAL_OBJS

    CORE_COUNT_OBJS = ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]
    SPECIAL_POINTS = {"True Node", "Chiron", "Vertex"}
    ASC_INDEX = 10

    planets_A = [p for p in OBJS if p in chart_data_A["planets"]]

    if is_synastry:
        planets_B = [p for p in OBJS if p in chart_data_B["planets"]]
        ROWS, COLS = len(planets_A), len(planets_B)
        LEFT_HEADER_COLS, TOP_HEADER_ROWS = 5, 4
        W_UNITS, H_UNITS = COLS + LEFT_HEADER_COLS, ROWS + TOP_HEADER_ROWS
    else:
        N = len(planets_A)
        # Nếu là Current Sky, chỉ vẽ 1 cột Header (Symbol), bỏ cột đếm số lượng
        if is_current_sky:
            LEFT_HEADER_COLS = 1
        else:
            LEFT_HEADER_COLS = 2

        HEADER_GAP = 0.5
        W_UNITS, H_UNITS = N + LEFT_HEADER_COLS + HEADER_GAP, N

    UNIT_INCH = 0.6
    FIG_W, FIG_H = W_UNITS * UNIT_INCH, H_UNITS * UNIT_INCH

    fig = Figure(figsize=(FIG_W, FIG_H), dpi=DPI)
    fig.subplots_adjust(left=0.01, right=0.99, top=0.99, bottom=0.01)
    ax = fig.add_subplot(111)
    ax.axis('off')
    ax.set_xlim(0, W_UNITS)
    ax.set_ylim(0, H_UNITS)
    ax.invert_yaxis()

    if is_synastry:
        scores_A = analysis_data.get("scores_A", {}) if analysis_data else {}
        scores_B = analysis_data.get("scores_B", {}) if analysis_data else {}
        dom_A = analysis_data.get("dominant_A") if analysis_data else None
        dom_B = analysis_data.get("dominant_B") if analysis_data else None
        acc_planet = analysis_data.get("accompanying") if analysis_data else None

        for c, pB in enumerate(planets_B):
            col_x = c + LEFT_HEADER_COLS
            info = chart_data_B["planets"][pB]
            z_idx, _, _, z_deg = lib.get_zodiac(info['lon'])
            bg_head = BG_HEADER_EXT if OBJS.index(pB) > ASC_INDEX else BG_HEADER_STD

            draw_cell(ax, col_x, 0, text=lib.ZODIAC_SYMBOLS[z_idx], bg_color=bg_head, text_color='#4b5563',
                      is_bold=True, font_size=FONT_HEADER)
            draw_cell(ax, col_x, 1, text=f"{int(z_deg)}°\n{int((z_deg % 1) * 60)}'", bg_color=bg_head,
                      text_color='gray', font_size=9)

            if pB in scores_B:
                score = scores_B[pB]["count"]
                is_winner = (pB == dom_B)
                is_acc = (acc_planet and acc_planet["owner"] == "B" and acc_planet["name"] == pB)
                text_col, font_sz, is_bd, b_sty = '#dc2626', FONT_HEADER, False, 'normal'
                if is_winner:
                    font_sz, is_bd, b_sty = FONT_PLANET + 2, True, 'red_bold'
                elif is_acc:
                    font_sz, is_bd, b_sty = FONT_PLANET, True, 'red_bold_soft'
                if pB == 'Asc': text_col, is_bd, b_sty = 'black', False, 'normal'
                draw_cell(ax, col_x, 2, text=str(score), bg_color='white', text_color=text_col, font_size=font_sz,
                          is_bold=is_bd, border_style=b_sty)
            else:
                draw_cell(ax, col_x, 2, bg_color='white')

            t_scale = 1.0
            t_stroke = None
            if pB not in ['Asc', 'Vertex']:
                t_stroke = 0.5
                if pB == 'Mercury':
                    t_scale = 1.15
                else:
                    t_scale = 1.10

            draw_cell(ax, col_x, 3, text=lib.PLANET_SYMBOLS.get(pB, pB), bg_color=bg_head, text_color='#dc2626',
                      is_bold=True, font_size=FONT_PLANET, custom_border_color='black', custom_border_width=1.75,
                      text_scale=t_scale, text_stroke_width=t_stroke)

        for r, pA in enumerate(planets_A):
            row_y = r + TOP_HEADER_ROWS
            info = chart_data_A["planets"][pA]
            z_idx, _, _, z_deg = lib.get_zodiac(info['lon'])
            bg_head = BG_HEADER_EXT if OBJS.index(pA) > ASC_INDEX else BG_HEADER_STD

            draw_cell(ax, 0, row_y, text=pA[:3], bg_color=bg_head, text_color='black', font_size=10)
            draw_cell(ax, 1, row_y, text=lib.ZODIAC_SYMBOLS[z_idx], bg_color=bg_head, text_color='#4b5563',
                      is_bold=True, font_size=FONT_HEADER)
            draw_cell(ax, 2, row_y, text=f"{int(z_deg)}°{int((z_deg % 1) * 60)}'", bg_color=bg_head, text_color='gray',
                      font_size=9)

            if pA in scores_A:
                score = scores_A[pA]["count"]
                is_winner = (pA == dom_A)
                is_acc = (acc_planet and acc_planet["owner"] == "A" and acc_planet["name"] == pA)
                text_col, font_sz, is_bd, b_sty = '#1d4ed8', FONT_HEADER, False, 'normal'
                if is_winner:
                    font_sz, is_bd, b_sty = FONT_PLANET + 2, True, 'blue_bold'
                elif is_acc:
                    font_sz, is_bd, b_sty = FONT_PLANET, True, 'blue_bold_soft'
                if pA == 'Asc': text_col, is_bd, b_sty = 'black', False, 'normal'
                draw_cell(ax, 3, row_y, text=str(score), bg_color='white', text_color=text_col, font_size=font_sz,
                          is_bold=is_bd, border_style=b_sty)
            else:
                draw_cell(ax, 3, row_y, bg_color='white')

            t_scale = 1.0
            t_stroke = None
            if pA not in ['Asc', 'Vertex']:
                t_stroke = 0.5
                if pA == 'Mercury':
                    t_scale = 1.15
                else:
                    t_scale = 1.10

            draw_cell(ax, 4, row_y, text=lib.PLANET_SYMBOLS.get(pA, pA), bg_color=bg_head, text_color='#1d4ed8',
                      is_bold=True, font_size=FONT_PLANET, custom_border_color='black', custom_border_width=1.75,
                      text_scale=t_scale, text_stroke_width=t_stroke)

            for c, pB in enumerate(planets_B):
                col_x = c + LEFT_HEADER_COLS
                is_ext = (OBJS.index(pA) > ASC_INDEX) or (OBJS.index(pB) > ASC_INDEX)
                asp = lib.check_aspect(chart_data_A["planets"][pA]['lon'], chart_data_B["planets"][pB]['lon'])

                show_symbol = False
                if asp:
                    if asp['type'] == 'Minor':
                        show_symbol = False
                    elif (pA in SPECIAL_POINTS or pB in SPECIAL_POINTS) and asp['orb'] > 3.0:
                        show_symbol = False
                    else:
                        show_symbol = True

                if not show_symbol:
                    draw_cell(ax, col_x, row_y, bg_color=BG_GRID_EMPTY_EXT if is_ext else BG_EMPTY)
                    continue

                bg = BG_GRID_FILLED_EXT if is_ext else BG_FILLED
                color = COLOR_CONJUNCTION if asp['aspect'] == 'Conjunction' else (
                    COLOR_OPPOSITION if asp['aspect'] == 'Opposition' else (
                        COLOR_HARD if asp['type'] == 'Hard' else COLOR_SOFT))
                b_style = 'bold' if asp['orb'] < 1.0 else ('dashed' if asp['orb'] > 6.5 else 'normal')
                real_orb_str = f"{int(asp['orb'])}°{int((asp['orb'] - int(asp['orb'])) * 60)}'" if show_real_orb else None
                tr_text = None if is_synastry else str(math.floor(asp['orb']))

                draw_cell(ax, col_x, row_y, text=asp['symbol'] if asp['symbol'] != '⚹' else None, sub_text_tr=tr_text,
                          sub_text_bl=real_orb_str, bg_color=bg, text_color=color, border_style=b_style, is_bold=True,
                          font_size=FONT_SYM, draw_sextile_manual=(asp['symbol'] == '⚹'), sextile_color=color)
    else:
        # --- NATAL / CURRENT SKY GRID ---
        total_aspects = {}
        max_count = 0
        candidates = [p for p in CORE_COUNT_OBJS if p in chart_data_A["planets"]]
        for o in candidates:
            cnt = sum(1 for t in candidates if o != t and lib.check_aspect(chart_data_A["planets"][o]['lon'],
                                                                           chart_data_A["planets"][t]['lon']) and
                      lib.check_aspect(chart_data_A["planets"][o]['lon'], chart_data_A["planets"][t]['lon'])[
                          'type'] != 'Minor')
            total_aspects[o] = cnt
            if cnt > max_count: max_count = cnt

        for r, p_row in enumerate(planets_A):
            sym_row = lib.PLANET_SYMBOLS.get(p_row, p_row)
            count_txt, count_color, is_top = "", 'black', False

            # Chỉ tính toán màu sắc cho cột số lượng nếu KHÔNG PHẢI Current Sky
            if not is_current_sky and p_row in CORE_COUNT_OBJS:
                c_val = total_aspects.get(p_row, 0)
                count_txt = str(c_val)
                if c_val == max_count and max_count > 0: is_top = True; count_color = '#dc2626'

            # VẼ HEADER HÀNG DỌC (CỘT 0 VÀ 1)
            if is_current_sky:
                # Nếu Current Sky: Chỉ vẽ cột Symbol (cột 0)
                draw_cell(ax, 0, r, text=sym_row, bg_color=BG_HEADER_STD, text_color=count_color, is_bold=is_top,
                          font_size=FONT_PLANET)
            else:
                # Nếu Natal: Vẽ cột Count (0) và Symbol (1)
                draw_cell(ax, 0, r, text=count_txt, bg_color=BG_HEADER_STD, text_color=count_color, is_bold=is_top,
                          font_size=FONT_HEADER)
                draw_cell(ax, 1, r, text=sym_row, bg_color=BG_HEADER_STD, text_color=count_color, is_bold=is_top,
                          font_size=FONT_PLANET)

            max_c = r if not (p_row == 'MC' and planets_A[r - 1] == 'Asc') else r - 1
            grid_start_x = LEFT_HEADER_COLS + HEADER_GAP

            for c in range(max_c + 1):
                col_x = grid_start_x + c
                p_col = planets_A[c]
                if c == max_c:
                    draw_cell(ax, col_x, r, text=sym_row, bg_color=BG_HEADER_STD, text_color='black', is_bold=True,
                              font_size=FONT_PLANET)
                    continue

                asp = lib.check_aspect(chart_data_A["planets"][p_row]['lon'], chart_data_A["planets"][p_col]['lon'])
                show_symbol = False
                if asp:
                    if (p_row in SPECIAL_POINTS or p_col in SPECIAL_POINTS) and asp['orb'] > 3.0:
                        show_symbol = False
                    else:
                        show_symbol = True

                if not show_symbol:
                    draw_cell(ax, col_x, r, bg_color=BG_EMPTY)
                    continue

                color = COLOR_CONJUNCTION if asp['aspect'] == 'Conjunction' else (
                    COLOR_OPPOSITION if asp['aspect'] == 'Opposition' else (COLOR_HARD if asp['type'] == 'Hard' else (
                        COLOR_MINOR if asp['type'] == 'Minor' else COLOR_SOFT)))
                real_orb_str = f"{int(asp['orb'])}°{int((asp['orb'] - int(asp['orb'])) * 60)}'" if show_real_orb else None
                symbol_txt = asp['symbol']
                is_sextile = (symbol_txt == '⚹')
                is_minor_custom = (symbol_txt in ['⚺', '⚻'])

                draw_cell(ax, col_x, r, text=symbol_txt if not (is_sextile or is_minor_custom) else None,
                          sub_text_tr=str(int(round(asp['orb']))), sub_text_bl=real_orb_str, bg_color=BG_FILLED,
                          text_color=color, border_style='normal', is_bold=True, font_size=FONT_SYM,
                          draw_sextile_manual=is_sextile, sextile_color=color,
                          custom_symbol=symbol_txt if is_minor_custom else None)

    output = io.BytesIO()
    FigureCanvas(fig).print_png(output)
    return base64.b64encode(output.getvalue()).decode('utf-8')
