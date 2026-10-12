import astro00_lib as lib
from app.utils.drawing import draw_aspect_grid_image
from .components import generate_info_html, generate_element_matrix_html
from .logic import get_dominant_houses_sorted

def generate_synastry_report(cA, cB, pA, pB, show_real_orb=False):
    """
    Trả về 3 biến: report_html, grid_img_b64, theme_html
    """
    nA, nB = pA['name'], pB['name']
    title_cls = "title-auto-scale font-bold text-lg mb-2 text-center text-gray-800 dark:text-white uppercase tracking-wide whitespace-nowrap overflow-hidden"

    # --- 1. LÕI VÀ NHÀ TRỘI CÁ NHÂN ---
    def get_core(c):
        a = c["angles"]["Asc"]
        _, an, _, _ = lib.get_zodiac(a)
        s = c["planets"]["Sun"]["lon"]
        _, sn, _, _ = lib.get_zodiac(s)
        m = c["planets"]["Moon"]["lon"]
        _, mn, _, _ = lib.get_zodiac(m)
        return f"<span class='font-bold text-blue-600 dark:text-blue-400'>AC</span> {an}<br><span class='font-bold text-orange-500'>Sun</span> {sn}<br><span class='font-bold text-yellow-500'>Moon</span> {mn}"

    domA = get_dominant_houses_sorted(cA)
    domB = get_dominant_houses_sorted(cB)
    txtA = ", ".join([f"H{h}" for h, s in domA]) if domA else "Không có"
    txtB = ", ".join([f"H{h}" for h, s in domB]) if domB else "Không có"

    # Header Info
    html = f"<div class='grid grid-cols-2 gap-2 md:gap-4 mb-4'><div><h4 class='font-bold text-center text-blue-600 dark:text-blue-400 mb-2 border-b dark:border-gray-700 pb-1 text-sm whitespace-nowrap overflow-hidden text-ellipsis'>{nA}</h4>{generate_info_html(cA, pA)}</div><div><h4 class='font-bold text-center text-red-600 dark:text-red-400 mb-2 border-b dark:border-gray-700 pb-1 text-sm whitespace-nowrap overflow-hidden text-ellipsis'>{nB}</h4>{generate_info_html(cB, pB)}</div></div>"

    html += f"<h3 class='{title_cls}'>1. LÕI VÀ NHÀ TRỘI CÁ NHÂN</h3>"
    html += f"<div class='grid grid-cols-2 gap-2 mb-6 text-sm text-gray-800 dark:text-gray-200'><div class='bg-gray-50 dark:bg-gray-800 p-2 rounded text-center h-full flex flex-col justify-between border dark:border-gray-700'><div class='mb-2'><p class='font-bold mb-1 text-xs'>{nA}</p><p class='text-xs mb-1'>{get_core(cA)}</p></div><div class='border-t dark:border-gray-600 pt-1'><p class='text-xs'>Nhà trội:<br><span class='font-bold text-purple-600 dark:text-purple-400'>{txtA}</span></p></div></div><div class='bg-gray-50 dark:bg-gray-800 p-2 rounded text-center h-full flex flex-col justify-between border dark:border-gray-700'><div class='mb-2'><p class='font-bold mb-1 text-xs'>{nB}</p><p class='text-xs mb-1'>{get_core(cB)}</p></div><div class='border-t dark:border-gray-600 pt-1'><p class='text-xs'>Nhà trội:<br><span class='font-bold text-purple-600 dark:text-purple-400'>{txtB}</span></p></div></div></div>"

    # --- 2. BẢNG TƯƠNG TÁC NHÀ ---
    html += f"<h3 class='{title_cls}'>2. BẢNG TƯƠNG TÁC NHÀ</h3>"

    name_style = "display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; word-break: break-word; font-size: 0.75rem; line-height: 1.1;"
    header_col_style = "width: 80px; min-width: 80px;"

    html += f"""
    <div class='overflow-x-auto mb-6'>
        <table class='w-full max-w-lg mx-auto text-xs border-collapse border-b border-gray-200 dark:border-gray-700'>
            <thead class='bg-gray-50 dark:bg-gray-700 text-gray-500 dark:text-gray-300 uppercase'>
                <tr>
                    <th class='px-1 py-1 text-left' style='min-width: 60px;'>HÀNH TINH</th>
                    <th class='px-1 py-1 text-center' style='width: 40px;'>ĐIỂM</th>
                    <th class='px-1 py-1 text-center border-l border-gray-200 dark:border-gray-600' style='{header_col_style}'>
                        <div style='font-size: 0.65rem; color: gray;'>KÍCH HOẠT NHÀ CỦA</div>
                        <div class="text-blue-600 dark:text-blue-400" style='{name_style}'>{nA}</div>
                    </th>
                    <th class='px-1 py-1 text-center border-l border-gray-200 dark:border-gray-600' style='{header_col_style}'>
                        <div style='font-size: 0.65rem; color: gray;'>KÍCH HOẠT NHÀ CỦA</div>
                        <div class="text-red-600 dark:text-red-400" style='{name_style}'>{nB}</div>
                    </th>
                </tr>
            </thead>
            <tbody class='divide-y divide-gray-100 dark:divide-gray-700 text-gray-800 dark:text-gray-200'>
    """

    sAB = {h: 0 for h in range(1, 13)}
    sBA = {h: 0 for h in range(1, 13)}
    occ = set()

    for p in lib.PLANET_ORDER:
        if p not in cA["planets"] or p not in cB["planets"]: continue
        pts = lib.PLANET_POINTS.get(p, 1)
        hB = lib.get_house_of_planet(cA["planets"][p]['lon'], cB["cusps"])
        sAB[hB] += pts
        occ.add(hB)
        hA = lib.get_house_of_planet(cB["planets"][p]['lon'], cA["cusps"])
        sBA[hA] += pts
        occ.add(hA)
        p_sym = lib.PLANET_SYMBOLS.get(p, '')

        html += f"<tr class='hover:bg-gray-50 dark:hover:bg-gray-800'>"
        html += f"<td class='px-1 py-1 font-medium whitespace-nowrap'><span class='text-black dark:text-white font-bold w-4 inline-block text-center'>{p_sym}</span> {p}</td>"
        html += f"<td class='px-1 py-1 text-center'>{pts}</td>"
        html += f"<td class='px-1 py-1 text-center border-l border-gray-200 dark:border-gray-600'>H{hA}</td>"
        html += f"<td class='px-1 py-1 text-center border-l border-gray-200 dark:border-gray-600'>H{hB}</td></tr>"

    html += "</tbody></table></div>"

    # --- 3. NHÀ ĐƯỢC KÍCH HOẠT NHIỀU ---
    actA = sorted([(h, s) for h, s in sBA.items() if s >= 4], key=lambda x: x[1], reverse=True)
    actB = sorted([(h, s) for h, s in sAB.items() if s >= 4], key=lambda x: x[1], reverse=True)

    def make_list(lst):
        if not lst: return "Không"
        return "".join(
            [f"<div class='mb-1 last:mb-0 border-b border-gray-200 dark:border-gray-600 pb-1 last:border-0 last:pb-0'>H{h} ({s}đ)</div>" for
             h, s in lst])

    html += f"<h3 class='{title_cls}'>3. NHÀ ĐƯỢC KÍCH HOẠT NHIỀU</h3>"
    html += f"<div class='grid grid-cols-2 gap-2 mb-6'><div class='bg-blue-50 dark:bg-gray-800 p-2 rounded text-xs text-center border border-blue-100 dark:border-blue-900 flex flex-col h-full'><p class='font-bold mb-2 pb-1 border-b border-blue-200 dark:border-blue-800 text-gray-800 dark:text-gray-200'>{nA} được kích hoạt</p><div class='font-medium text-blue-800 dark:text-blue-300 flex-grow flex flex-col justify-start'>{make_list(actA)}</div></div><div class='bg-red-50 dark:bg-gray-800 p-2 rounded text-xs text-center border border-red-100 dark:border-red-900 flex flex-col h-full'><p class='font-bold mb-2 pb-1 border-b border-red-200 dark:border-red-800 text-gray-800 dark:text-gray-200'>{nB} được kích hoạt</p><div class='font-medium text-red-800 dark:text-red-300 flex-grow flex flex-col justify-start'>{make_list(actB)}</div></div></div>"

    # --- 4. NHÀ TRỘI CỦA MỐI QUAN HỆ ---
    total_scores = []
    for h in range(1, 13):
        s = sAB[h] + sBA[h]
        if s >= 4: total_scores.append((h, s))
    total_scores.sort(key=lambda x: x[1], reverse=True)
    final_houses = []
    if total_scores:
        limit_idx = min(3, len(total_scores))
        final_houses = total_scores[:limit_idx]
        if len(total_scores) > 3:
            threshold_score = total_scores[2][1]
            for i in range(3, len(total_scores)):
                if total_scores[i][1] == threshold_score: final_houses.append(total_scores[i])
                elif total_scores[i][1] < threshold_score: break

    html += f"<h3 class='{title_cls}'>4. NHÀ TRỘI CỦA MỐI QUAN HỆ</h3>"
    if final_houses:
        list_html = "".join([
                                f"<div class='flex justify-between px-4 py-1 border-b border-pink-200 dark:border-pink-900 last:border-0'><span>H{h}</span><span class='font-bold'>{s}đ</span></div>"
                                for h, s in final_houses])
        html += f"<div class='mb-6 max-w-xs mx-auto'><div class='bg-pink-50 dark:bg-gray-800 p-2 rounded text-xs border border-pink-200 dark:border-pink-900'><p class='font-bold mb-2 pb-1 border-pink-300 dark:border-pink-800 text-center text-pink-700 dark:text-pink-400'>Xếp hạng (Cao xuống thấp)</p><div class='font-medium text-pink-800 dark:text-pink-300'>{list_html}</div></div></div>"
    else:
        html += "<p class='mb-6 text-center text-sm text-gray-500 dark:text-gray-400'>Không có nhà nào >= 4 điểm.</p>"

    # --- 5. NHÀ TRỐNG ---
    empty = sorted(list(set(range(1, 13)) - occ))
    ind_dom = set([x[0] for x in domA]).union(set([x[0] for x in domB]))
    sp_empty = sorted(list(set(empty).intersection(ind_dom)))

    html += f"<h3 class='{title_cls}'>5. NHÀ TRỐNG</h3><div class='text-center text-xs mb-4 space-y-2 text-gray-800 dark:text-gray-200'><p>Tất cả nhà trống: {', '.join([f'H{h}' for h in empty]) if empty else 'Không có'}</p><p>Nhà trống cần chú ý: <span class='text-red-500 font-bold'>{', '.join([f'H{h}' for h in sp_empty]) if sp_empty else 'Không có'}</span></p></div>"

    # --- THEME CALCULATION ---
    analysis_res = lib.analyze_synastry_grid(cA, cB)
    grid_img_b64 = draw_aspect_grid_image(cA, cB, is_synastry=True, show_real_orb=show_real_orb,
                                          analysis_data=analysis_res)

    dom_A = analysis_res["dominant_A"]
    dom_B = analysis_res["dominant_B"]
    acc = analysis_res["accompanying"]
    sub_themes_list = analysis_res.get("sub_themes", [])
    global_shrink = (acc is not None)

    # --- THEME RENDER LOGIC ---
    def render_theme_col(planet_name, is_A, acc_data, do_shrink):
        color_cls = "text-blue-600 dark:text-blue-400" if is_A else "text-red-600 dark:text-red-400"
        sym = lib.PLANET_SYMBOLS.get(planet_name, "")

        if do_shrink:
            icon_cls = "text-3xl md:text-4xl"
            text_cls = "text-sm md:text-base"
            icon_box_cls = "h-10 w-10"
        else:
            icon_cls = "text-4xl md:text-5xl"
            text_cls = "text-lg md:text-xl"
            icon_box_cls = "h-14 w-14"

        has_acc = False
        k_name = ""
        k_sym = ""

        if acc_data and ((is_A and acc_data["owner"] == "A") or (not is_A and acc_data["owner"] == "B")):
            has_acc = True
            k_name = acc_data["name"]
            k_sym = lib.PLANET_SYMBOLS.get(k_name, "")

        if not has_acc:
            dummy_html = ""
            if do_shrink:
                dummy_html = "<div class='text-[8px] font-bold text-transparent mt-0.5 select-none'>(TÍNH THÊM)</div>"

            return f"""
            <div class='p-4 h-32 flex flex-col items-center justify-start pt-5 border rounded bg-white dark:bg-gray-800 shadow-sm border-gray-200 dark:border-gray-700'>
                <div class="{icon_box_cls} flex items-center justify-center {icon_cls} font-bold {color_cls} mb-1 leading-none">{sym}</div>
                <div class="{text_cls} font-bold text-gray-700 dark:text-gray-300">{planet_name}</div>
                {dummy_html}
            </div>
            """
        else:
            if is_A:
                return f"""
                <div class='h-32 flex border rounded bg-white dark:bg-gray-800 shadow-sm border-gray-200 dark:border-gray-700 overflow-hidden'>
                    <div class="w-1/2 flex flex-col items-center justify-start pt-5">
                        <div class="{icon_box_cls} flex items-center justify-center {icon_cls} font-bold {color_cls} mb-1 leading-none">{k_sym}</div>
                        <div class="{text_cls} font-bold text-gray-700 dark:text-gray-300">{k_name}</div>
                        <div class="text-[8px] font-bold text-gray-400 mt-0.5 uppercase">(TÍNH THÊM)</div>
                    </div>
                    <div class="w-1/2 flex flex-col items-center justify-start pt-5">
                        <div class="{icon_box_cls} flex items-center justify-center {icon_cls} font-bold {color_cls} mb-1 leading-none">{sym}</div>
                        <div class="{text_cls} font-bold text-gray-700 dark:text-gray-300">{planet_name}</div>
                        <div class="text-[8px] font-bold text-transparent mt-0.5 select-none">(TÍNH THÊM)</div>
                    </div>
                </div>
                """
            else:
                return f"""
                <div class='h-32 flex border rounded bg-white dark:bg-gray-800 shadow-sm border-gray-200 dark:border-gray-700 overflow-hidden'>
                    <div class="w-1/2 flex flex-col items-center justify-start pt-5">
                        <div class="{icon_box_cls} flex items-center justify-center {icon_cls} font-bold {color_cls} mb-1 leading-none">{sym}</div>
                        <div class="{text_cls} font-bold text-gray-700 dark:text-gray-300">{planet_name}</div>
                        <div class="text-[8px] font-bold text-transparent mt-0.5 select-none">(TÍNH THÊM)</div>
                    </div>
                    <div class="w-1/2 flex flex-col items-center justify-start pt-5">
                        <div class="{icon_box_cls} flex items-center justify-center {icon_cls} font-bold {color_cls} mb-1 leading-none">{k_sym}</div>
                        <div class="{text_cls} font-bold text-gray-700 dark:text-gray-300">{k_name}</div>
                        <div class="text-[8px] font-bold text-gray-400 mt-0.5 uppercase">(TÍNH THÊM)</div>
                    </div>
                </div>
                """

    html_theme = f"<div class='mt-2'><div class='grid grid-cols-2 gap-2 md:gap-4 max-w-xl mx-auto'>"
    html_theme += f"<div><h4 class='font-bold text-center text-xs text-gray-500 dark:text-gray-400 mb-2 uppercase tracking-wide'>Hành tinh trội của {nA}</h4>{render_theme_col(dom_A, True, acc, global_shrink)}</div>"
    html_theme += f"<div><h4 class='font-bold text-center text-xs text-gray-500 dark:text-gray-400 mb-2 uppercase tracking-wide'>Hành tinh trội của {nB}</h4>{render_theme_col(dom_B, False, acc, global_shrink)}</div>"
    html_theme += "</div>"

    if sub_themes_list:
        html_theme += f"<div class='mt-6 pt-4 border-t border-gray-200 dark:border-gray-700 max-w-xl mx-auto'>"
        html_theme += f"<h3 class='{title_cls} mb-4'>THEME PHỤ CỦA MỐI QUAN HỆ</h3>"
        html_theme += f"<div class='border border-gray-300 dark:border-gray-600 rounded overflow-hidden'>"

        for idx, pair in enumerate(sub_themes_list):
            p1, p2 = pair
            sym1 = lib.PLANET_SYMBOLS.get(p1, "")
            sym2 = lib.PLANET_SYMBOLS.get(p2, "")
            border_cls = "border-b border-gray-300 dark:border-gray-600 border-b-2" if idx < len(sub_themes_list) - 1 else ""

            row_html = f"""
            <div class='bg-white dark:bg-gray-800 p-3 flex flex-col items-center justify-center {border_cls}'>
                <div class='flex items-center gap-3 mb-1'>
                    <span class='text-2xl font-bold text-black dark:text-white'>{sym1}</span>
                    <span class='text-xl text-gray-400 font-bold'>—</span>
                    <span class='text-2xl font-bold text-black dark:text-white'>{sym2}</span>
                </div>
                <div class='text-xs font-bold text-gray-600 dark:text-gray-300 uppercase tracking-wider'>
                    {p1} - {p2}
                </div>
            </div>
            """
            html_theme += row_html

        html_theme += "</div></div>"

    html_theme += "</div>"

    return html, grid_img_b64, html_theme
