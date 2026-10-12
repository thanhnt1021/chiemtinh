import astro00_lib as lib
from app.utils.drawing import draw_aspect_grid_image
from .components import generate_info_html, generate_element_matrix_html
from .logic import get_dominant_planets_logic, get_dominant_houses_sorted


def generate_natal_report(data, profile, show_real_orb=False):
    html = generate_info_html(data, profile)

    # Title style
    title_cls = "title-auto-scale font-bold text-lg mb-2 text-center text-gray-800 dark:text-white uppercase tracking-wide whitespace-nowrap overflow-hidden"

    # 1. PLANET POSITIONS
    html += f"<h3 class='{title_cls}'>VỊ TRÍ HÀNH TINH</h3>"
    html += "<div class='overflow-x-auto mb-8'><table class='w-full max-w-sm mx-auto text-xs border-collapse border-b border-gray-200 dark:border-gray-700'>"
    html += "<thead class='bg-gray-50 dark:bg-gray-700 text-gray-500 dark:text-gray-300 uppercase tracking-wider'><tr><th class='px-2 py-1 text-left'>Hành tinh</th><th class='px-2 py-1 text-center'>Cung</th><th class='px-2 py-1 text-center'>Độ</th><th class='px-2 py-1 text-center'>Nhà</th></tr></thead><tbody class='divide-y divide-gray-100 dark:divide-gray-700 text-gray-800 dark:text-gray-200'>"

    cusps = data["cusps"]
    disp = ["Asc", "Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto",
            "True Node", "Chiron", "Vertex"]

    for p in disp:
        if p not in data["planets"]: continue
        info = data["planets"][p]
        _, z_code, _, z_deg = lib.get_zodiac(info['lon'])
        z_idx, _, _, _ = lib.get_zodiac(info['lon'])
        z_sym = lib.ZODIAC_SYMBOLS[z_idx]
        h = lib.get_house_of_planet(info['lon'], cusps) if p != "Asc" else 1
        d_str = f"{int(z_deg)}°{int((z_deg % 1) * 60)}'"
        p_sym = lib.PLANET_SYMBOLS.get(p, p)

        col_p = f"<div class='flex items-center gap-2'><span class='font-bold text-blue-600 dark:text-blue-400 text-sm w-4 text-center'>{p_sym}</span> <span class='font-medium'>{p}</span></div>"
        col_s = f"<span class='font-bold text-gray-600 dark:text-gray-400 text-sm'>{z_sym}</span>"

        html += f"<tr class='hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors'><td class='px-2 py-1 border-r dark:border-gray-700'>{col_p}</td><td class='px-2 py-1 border-r dark:border-gray-700 text-center'>{col_s}</td><td class='text-center px-2 py-1 border-r dark:border-gray-700'>{d_str}</td><td class='text-center px-2 py-1'>{h}</td></tr>"
    html += "</tbody></table></div>"

    # === CORE (ĐÃ CẬP NHẬT THÀNH 3 DÒNG CĂN GIỮA) ===
    def get_core_html(c):
        a = c["angles"]["Asc"];
        _, an, _, _ = lib.get_zodiac(a)
        s = c["planets"]["Sun"]["lon"];
        _, sn, _, _ = lib.get_zodiac(s)
        m = c["planets"]["Moon"]["lon"];
        _, mn, _, _ = lib.get_zodiac(m)

        return f"""
        <div class='flex flex-col items-center justify-center space-y-1 mb-6 text-sm text-center mx-auto'>
            <div class='text-gray-800 dark:text-gray-200'><span class='font-bold text-blue-600 dark:text-blue-400'>AC</span> {an}</div>
            <div class='text-gray-800 dark:text-gray-200'><span class='font-bold text-orange-500'>Sun</span> {sn}</div>
            <div class='text-gray-800 dark:text-gray-200'><span class='font-bold text-yellow-500'>Moon</span> {mn}</div>
        </div>
        """

    html += f"<h3 class='{title_cls}'>LÕI</h3>"
    html += get_core_html(data)

    html += f"<h3 class='{title_cls}'>BẢNG NGUYÊN TỐ - TÍNH CHẤT</h3>" + generate_element_matrix_html(data)

    dom_houses = get_dominant_houses_sorted(data)
    html += f"<h3 class='{title_cls}'>NHÀ TRỘI CÁ NHÂN</h3>"
    html += f"<div class='mb-8 text-center bg-gray-50 dark:bg-gray-800 p-2 rounded border border-gray-200 dark:border-gray-700 mx-auto max-w-lg'><p class='text-lg font-bold text-purple-600 dark:text-purple-400 tracking-wider'>{', '.join([f'H{h}' for h, s in dom_houses]) if dom_houses else 'Không có'}</p></div>"

    # --- ASPECT GRID ---
    grid_img_b64 = draw_aspect_grid_image(data, is_synastry=False, show_real_orb=show_real_orb)
    html += f"<h3 class='{title_cls}'>Bảng góc hợp của bản đồ sao</h3>"
    html += f"<div class='mb-8 text-center'><img src='data:image/png;base64,{grid_img_b64}' class='max-w-full h-auto mx-auto rounded border border-gray-200 dark:border-gray-700' /></div>"

    # LIST DOMINANT PLANETS
    dom_planets = get_dominant_planets_logic(data)
    dom_planets.sort(key=lambda x: x['total_orb'])

    html += f"<h3 class='{title_cls}'>HÀNH TINH TẠO NHIỀU GÓC NHẤT</h3>"
    html += "<div class='bg-yellow-50 dark:bg-gray-800 p-4 rounded border border-yellow-200 dark:border-yellow-900 mb-8 mx-auto max-w-3xl text-center'>"
    if dom_planets:
        html += "<div class='flex flex-col gap-1 items-center'>"
        for d in dom_planets:
            p_name = d['name'].upper()
            p_sym = lib.PLANET_SYMBOLS.get(d['name'], '')
            html += f"<div class='text-xl font-extrabold text-red-600 dark:text-red-400'>{p_name} ({p_sym})</div>"
        html += "</div>"
    else:
        html += "<p class='text-gray-500 dark:text-gray-400'>Không xác định.</p>"
    html += "</div>"

    p_pos = data["planets"];
    core = lib.CORE_PLANETS;
    personal = lib.PERSONAL_PLANETS
    temp_asps = [];
    min_orb_inner = 999
    for i in range(len(core)):
        for j in range(i + 1, len(core)):
            p1, p2 = core[i], core[j]
            if (p1 not in personal) and (p2 not in personal): continue
            if p1 in p_pos and p2 in p_pos:
                asp = lib.check_aspect(p_pos[p1]['lon'], p_pos[p2]['lon'])
                if asp:
                    if asp['type'] == 'Minor': continue
                    temp_asps.append({**asp, "p1": p1, "p2": p2})
                    if asp['orb_round'] < min_orb_inner: min_orb_inner = asp['orb_round']
    final_inners = [a for a in temp_asps if a['orb_round'] == min_orb_inner]

    html += f"<h3 class='{title_cls}'>GÓC INNER CHẶT NHẤT</h3>"
    html += "<div class='bg-green-50 dark:bg-gray-800 p-4 rounded border border-green-200 dark:border-green-900 mx-auto max-w-md'>"
    if final_inners:
        html += "<div class='space-y-2'>"
        for a in final_inners:
            html += f"<div class='flex items-center font-bold text-gray-700 dark:text-gray-300 border-b border-green-100 dark:border-gray-700 pb-1 last:border-0 text-sm'>"
            html += f"<div class='flex items-center w-2/3'><span class='text-lg w-6 text-center'>{lib.PLANET_SYMBOLS.get(a['p1'], '')}</span> <span class='mr-1'>{a['p1']}</span> - <span class='text-lg w-6 text-center ml-1'>{lib.PLANET_SYMBOLS.get(a['p2'], '')}</span> <span>{a['p2']}</span></div>"
            html += f"<span class='text-green-700 dark:text-green-400 bg-green-100 dark:bg-green-900 px-2 py-0.5 rounded text-xs whitespace-nowrap ml-2'>{a['name_vn']} {a['orb_round']}°</span></div>"
        html += "</div>"
    else:
        html += "<p class='text-center text-gray-500 dark:text-gray-400'>Không có góc Inner nào.</p>"
    html += "</div>"
    return html
