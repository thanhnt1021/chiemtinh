# app/utils/reports/transit.py
import astro00_lib as lib
from .components import generate_info_html, generate_element_matrix_html
from .logic import get_dominant_planets_logic, get_dominant_houses_sorted
from app.utils.drawing import draw_aspect_grid_image


def generate_current_sky_report(chart_data, show_real_orb=False):
    title_cls = "title-auto-scale font-bold text-lg mb-2 text-center text-gray-800 dark:text-white uppercase tracking-wide whitespace-nowrap overflow-hidden"
    html, disp = "", ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto",
                      "True Node", "Chiron", "Vertex"]
    html += f"<h3 class='{title_cls}'>VỊ TRÍ HÀNH TINH</h3>"
    html += "<div class='overflow-x-auto mb-8'><table class='w-full max-w-sm mx-auto text-xs border-collapse border-b border-gray-200 dark:border-gray-700'><thead class='bg-gray-50 dark:bg-gray-700 text-gray-500 dark:text-gray-300 uppercase tracking-wider'><tr><th class='px-2 py-1 text-left'>Hành tinh</th><th class='px-2 py-1 text-center'>Cung</th><th class='px-2 py-1 text-center'>Độ</th></tr></thead><tbody class='divide-y divide-gray-100 dark:divide-gray-700 text-gray-800 dark:text-gray-200'>"
    for p in disp:
        if p not in chart_data["planets"]: continue
        info = chart_data["planets"][p]
        _, _, _, z_deg = lib.get_zodiac(info['lon'])
        z_idx, _, _, _ = lib.get_zodiac(info['lon'])
        html += f"<tr class='hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors'><td class='px-2 py-1 border-r dark:border-gray-700'><div class='flex items-center gap-2'><span class='font-bold text-blue-600 dark:text-blue-400 text-sm w-4 text-center'>{lib.PLANET_SYMBOLS.get(p, p)}</span> <span class='font-medium'>{p}</span></div></td><td class='px-2 py-1 border-r dark:border-gray-700 text-center'><span class='font-bold text-gray-600 dark:text-gray-400 text-sm'>{lib.ZODIAC_SYMBOLS[z_idx]}</span></td><td class='text-center px-2 py-1'>{int(z_deg)}°{int((z_deg % 1) * 60)}'</td></tr>"
    html += "</tbody></table></div>"
    grid_img_b64 = draw_aspect_grid_image(chart_data, is_synastry=False, show_real_orb=show_real_orb,
                                          is_current_sky=True)
    html += f"<h3 class='{title_cls}'>Bảng góc hợp (Current Sky)</h3><div class='mb-8 text-center'><img src='data:image/png;base64,{grid_img_b64}' class='max-w-full h-auto mx-auto rounded border border-gray-200 dark:border-gray-700' /></div>"
    return html


def generate_transit_report(natal_data, transit_data, profile):
    html = generate_info_html(natal_data, profile)
    title_cls = "title-auto-scale font-bold text-lg mb-2 text-center text-gray-800 dark:text-white uppercase tracking-wide whitespace-nowrap overflow-hidden"
    html += f"<h3 class='{title_cls}'>VỊ TRÍ HÀNH TINH (NATAL vs TRANSIT)</h3>"
    html += f"<div class='overflow-x-auto mb-8'><table class='w-full max-w-3xl mx-auto text-xs border-collapse border-b border-gray-200 dark:border-gray-700'>"
    html += "<thead class='bg-gray-50 dark:bg-gray-700 text-gray-500 dark:text-gray-300 uppercase tracking-wider'><tr><th class='px-2 py-1 text-left border-r dark:border-gray-600'>Hành tinh</th><th class='px-2 py-1 text-center'>Cung (N)</th><th class='px-2 py-1 text-center'>Độ (N)</th><th class='px-2 py-1 text-center border-r dark:border-gray-600'>Nhà (N)</th><th class='px-2 py-1 text-center text-green-600 dark:text-green-400 border-l dark:border-gray-600'>Cung (Tx)</th><th class='px-2 py-1 text-center text-green-600 dark:text-green-400'>Độ (Tx)</th><th class='px-2 py-1 text-center text-green-600 dark:text-green-400'>Nhà (Tx)</th></tr></thead><tbody class='divide-y divide-gray-100 dark:divide-gray-700 text-gray-800 dark:text-gray-200'>"
    cusps, disp = natal_data["cusps"], ["Asc", "Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus",
                                        "Neptune", "Pluto", "True Node", "Chiron", "Vertex"]
    for p in disp:
        if p not in natal_data["planets"]: continue
        n_info = natal_data["planets"][p]
        _, n_z_idx, _, n_z_deg = lib.get_zodiac(n_info['lon'])
        n_h, n_sym, n_z_sym = (
            lib.get_house_of_planet(n_info['lon'], cusps) if p != "Asc" else 1), lib.PLANET_SYMBOLS.get(p, p), \
        lib.ZODIAC_SYMBOLS[n_z_idx]
        t_cols = "<td colspan='3' class='border-l dark:border-gray-600'></td>"
        if p in transit_data["planets"] and p not in ['Asc', 'MC', 'Vertex']:
            t_info = transit_data["planets"][p]
            _, t_z_idx, _, t_z_deg = lib.get_zodiac(t_info['lon'])
            t_cols = f"<td class='px-2 py-1 text-center border-l dark:border-gray-600 text-green-600 dark:text-green-400 font-bold'>{lib.ZODIAC_SYMBOLS[t_z_idx]}</td><td class='px-2 py-1 text-center text-green-600 dark:text-green-400'>{int(t_z_deg)}°{int((t_z_deg % 1) * 60)}'</td><td class='px-2 py-1 text-center text-green-600 dark:text-green-400 font-bold'>{lib.get_house_of_planet(t_info['lon'], cusps)}</td>"
        html += f"<tr class='hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors'><td class='px-2 py-1 border-r dark:border-gray-600 flex gap-2 items-center'><span class='text-blue-600 dark:text-blue-400 font-bold'>{n_sym}</span> <span>{p}</span></td><td class='px-2 py-1 text-center'>{n_z_sym}</td><td class='text-center px-2 py-1'>{int(n_z_deg)}°{int((n_z_deg % 1) * 60)}'</td><td class='text-center px-2 py-1 border-r dark:border-gray-600'>{n_h}</td>{t_cols}</tr>"
    html += "</tbody></table></div>"
    html += f"<h3 class='{title_cls}'>MA TRẬN NGUYÊN TỐ (NATAL)</h3>" + generate_element_matrix_html(natal_data)
    dom_houses = get_dominant_houses_sorted(natal_data)
    html += f"<h3 class='{title_cls}'>NHÀ TRỘI (NATAL)</h3><div class='mb-8 text-center bg-gray-50 dark:bg-gray-800 p-2 rounded border border-gray-200 dark:border-gray-700 mx-auto max-w-lg'><p class='text-lg font-bold text-purple-600 dark:text-purple-400'>{', '.join([f'H{h}' for h, s in dom_houses]) if dom_houses else 'None'}</p></div>"
    return html


def generate_personal_transit_report(natal_data, transit_data, profile, mode='single', aspects_1=None, aspects_2=None,
                                     transit_data_end=None):
    house_html = ""
    aspect_html = ""
    title_cls = "title-auto-scale font-bold text-lg mb-2 text-center text-gray-800 dark:text-white uppercase tracking-wide whitespace-nowrap overflow-hidden"

    def get_p_color(p_name):
        if p_name in ["Sun", "Mars", "Jupiter"]: return "text-red-600 dark:text-red-400"
        if p_name in ["Moon", "Neptune", "Pluto"]: return "text-blue-600 dark:text-blue-400"
        if p_name in ["Mercury", "Venus", "Uranus"]: return "text-green-600 dark:text-green-400"
        return "text-gray-900 dark:text-white"

    # --- PHẦN 1: TẠO HOUSE_HTML (Bảng Nhà) ---
    if mode == 'outer_cycle':
        disp = ["Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]
        col2_header = "NHÀ BẮT ĐẦU"
        col3_header = "NHÀ KẾT THÚC"
        col2_width = "w-auto"
        col3_width = "w-auto"
    else:
        disp = ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]
        col2_header = "NHÀ"
        col3_header = "THỜI GIAN"
        col2_width = "w-[20%]"
        col3_width = "w-[40%]"

    house_html += f"<h3 class='{title_cls}'>NHÀ TRANSIT</h3>"
    house_html += "<div class='mb-4'><table class='w-full max-w-[340px] mx-auto text-xs border-collapse border-b border-gray-200 dark:border-gray-700'>"
    house_html += f"<thead class='bg-gray-50 dark:bg-gray-700 text-gray-500 dark:text-gray-300 uppercase'><tr>"
    house_html += f"<th class='px-1 py-2 text-center w-[40%] text-green-600 dark:text-green-400 whitespace-nowrap'>HÀNH TINH</th>"
    house_html += f"<th class='px-1 py-2 text-center {col2_width} text-green-600 dark:text-green-400 whitespace-nowrap'>{col2_header}</th>"
    house_html += f"<th class='px-1 py-2 text-center {col3_width} text-green-600 dark:text-green-400 whitespace-nowrap'>{col3_header}</th></tr></thead>"
    house_html += "<tbody class='divide-y divide-gray-100 dark:divide-gray-700 text-gray-800 dark:text-gray-200'>"
    for p in disp:
        if p not in transit_data["planets"]: continue
        p_sym = lib.PLANET_SYMBOLS.get(p, p)
        house_start = lib.get_house_of_planet(transit_data["planets"][p]['lon'], natal_data['cusps'])

        house_html += f"<tr class='hover:bg-gray-50 dark:hover:bg-gray-800'><td class='px-0 py-2 border-r dark:border-gray-700 text-center'><div class='inline-flex items-center text-left w-[85px] pl-2'><span class='font-bold text-green-600 dark:text-green-400 text-base w-5 text-center mr-1'>{p_sym}</span><span class='font-medium text-green-600 dark:text-green-400'>{p}</span></div></td>"
        house_html += f"<td class='text-center px-0 py-2 border-r dark:border-gray-700 text-green-600 dark:text-green-400 font-bold'>{house_start}</td>"

        if mode == 'outer_cycle':
            house_end = "?"
            if transit_data_end and p in transit_data_end["planets"]:
                house_end = lib.get_house_of_planet(transit_data_end["planets"][p]['lon'], natal_data['cusps'])
            house_html += f"<td class='text-center px-0 py-2 text-green-600 dark:text-green-400 font-bold'>{house_end}</td>"
        else:
            house_html += f"<td class='text-center px-0 py-2'><a onclick=\"openNhaTransit('{p}')\" class='text-blue-600 dark:text-blue-400 underline cursor-pointer font-bold text-[10px] uppercase'>Xem</a></td>"

        house_html += "</tr>"
    house_html += "</tbody></table></div>"

    # --- PHẦN 2: TẠO ASPECT_HTML (Bảng Góc) ---
    if mode == 'single' and ((aspects_1 and len(aspects_1) > 0) or (aspects_2 and len(aspects_2) > 0)):
        aspect_html += f"<h3 class='{title_cls} mb-6'>GÓC TRANSIT</h3>"

        def render_aspect_area(title, a_list):
            if not a_list: return ""
            first_p = a_list[0]['n_p']
            is_point = first_p in lib.NATAL_SPECIAL_POINTS or first_p == "South Node"
            label = "ĐIỂM<br>CÁ NHÂN" if is_point else "HÀNH TINH<br>CÁ NHÂN"
            res = f"<h4 class='text-center font-bold text-gray-500 dark:text-gray-400 text-sm uppercase mb-2'>{title}</h4>"

            res += "<div class='mb-4'><table class='w-full max-w-md mx-auto border-collapse' style='table-layout: fixed;'>"
            res += "<thead class='bg-gray-50 dark:bg-gray-700 text-gray-500 dark:text-gray-300 uppercase'><tr style='vertical-align: top;'>"

            res += "<th class='px-0 py-2 text-center w-[28%] text-[10px] leading-tight'>HÀNH TINH<br>TRANSIT</th>"
            res += "<th class='px-0 py-2 text-center pr-1.5 w-[15%] text-[10px]'>GÓC</th>"
            res += f"<th class='px-0 py-2 text-center w-[28%] text-[10px] leading-tight'>{label}</th>"
            res += "<th class='px-0 py-1 text-center w-[15%] text-[10px]'>ĐỘ LỆCH<br><select onchange='filterAllAspects(this.value)' class='text-[9px] p-0 border border-gray-300 rounded bg-white dark:bg-gray-600 text-black dark:text-white font-bold h-4 w-10 mt-1'><option value='3'>< 3º</option><option value='2'>< 2º</option><option value='1'>< 1º</option><option value='0.5'>< 0.5º</option></select></th>"
            res += "<th class='px-0 py-2 text-center w-[14%] text-[10px] leading-tight'>GIAI ĐOẠN<br>TẠO GÓC</th></tr></thead>"
            res += "<tbody class='text-gray-500 dark:text-gray-400'>"

            for a in a_list:
                orb_cls = "font-black text-gray-700 dark:text-gray-300" if a['orb'] < 1.0 else ""

                def make_planet_cell(p_name, p_sym, padding_class):
                    disp_name = p_name.replace("True Node", "T.Node").replace("South Node", "S.Node")
                    p_col = get_p_color(p_name)
                    is_small = p_name in ["MC", "Vertex", "Asc"]
                    s_size = "text-[10px] opacity-70" if is_small else "text-xl"

                    html_cell = f"<div class='inline-flex items-center justify-start text-left w-[92px] {padding_class}'>"
                    html_cell += f"<span class='{s_size} font-black {p_col} w-6 flex-shrink-0 text-center mr-1.5' style='-webkit-text-stroke: 0.5px currentColor;'>{p_sym}</span>"
                    html_cell += f"<span class='font-medium text-[11px] sm:text-[12px] whitespace-nowrap'>{disp_name}</span></div>"
                    return html_cell

                res += f"<tr class='aspect-row leading-[1.1] hover:bg-gray-50 dark:hover:bg-gray-800' data-orb='{a['orb']}'>"
                res += f"<td class='px-0 py-[1px] text-center'>{make_planet_cell(a['t_p'], a['t_p_sym'], 'pl-2')}</td>"
                res += f"<td class='px-0 py-[1px] text-center pr-1.5'><span class='text-xl font-bold leading-none'>{a['asp_sym']}</span></td>"
                res += f"<td class='px-0 py-[1px] text-center'>{make_planet_cell(a['n_p'], a['n_p_sym'], 'pl-2.5')}</td>"
                res += f"<td class='px-0 py-[1px] text-center'><span class='text-[12px] {orb_cls}'>{a['orb_str']}</span></td>"
                res += f"<td class='px-0 py-[1px] text-center'><a onclick=\"openTra('{a['t_p']}','{a['asp_name']}','{a['n_p']}')\" class='text-blue-600 dark:text-blue-400 underline cursor-pointer font-bold text-[10px] uppercase'>Xem</a></td></tr>"

            res += "</tbody></table>"
            res += "<div class='h-[1px] bg-orange-400/30 dark:bg-orange-500/20 w-1/2 mx-auto mt-4 mb-4'></div>"
            return res

        aspect_html += render_aspect_area("Góc với các hành tinh", aspects_1)
        aspect_html += render_aspect_area("Góc với các điểm khác", aspects_2)

    return house_html, aspect_html
