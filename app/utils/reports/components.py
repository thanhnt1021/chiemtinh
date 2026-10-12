import astro00_lib as lib


def generate_element_matrix_html(chart_data):
    """
    Tạo 1 bảng duy nhất kết hợp Phân Bố và Tổng Điểm.
    Tối ưu hóa hiển thị trên Mobile và Desktop (Equal cells).
    """
    COLORS = {
        "Fire": "#e94031",
        "Earth": "#65c846",
        "Air": "#eeab41",
        "Water": "#2341f2"
    }

    scores = [[0] * 3 for _ in range(4)]
    symbols_grid = [[[] for _ in range(3)] for _ in range(4)]
    p_pos = chart_data["planets"]
    display_objects = list(lib.PLANET_POINTS.keys()) + ["True Node", "Chiron", "Vertex", "MC"]

    for p in display_objects:
        if p in p_pos:
            lon = p_pos[p]['lon']
            z_idx, _, _, _ = lib.get_zodiac(lon)
            r, c = lib.ZODIAC_MATRIX[z_idx]
            if p in lib.PLANET_POINTS:
                scores[r][c] += lib.PLANET_POINTS[p]
            sym = lib.PLANET_SYMBOLS.get(p, p)
            symbols_grid[r][c].append(sym)

    row_names = ["Fire", "Earth", "Air", "Water"]
    col_totals = [0] * 3

    # CSS Responsive & Fixed Sizes
    # w-[20%] giúp 5 cột luôn bằng nhau (100% / 5)
    # h-16 (64px) là độ cao vừa đủ thoáng nhưng không quá to trên điện thoại
    header_col_style = "w-[20%] border border-gray-300 dark:border-gray-600 bg-gray-100 dark:bg-gray-700 font-bold text-[10px] md:text-xs text-gray-800 dark:text-gray-200 text-center"
    label_col_style = "w-[20%] font-extrabold border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-[10px] md:text-xs text-center"
    cell_style = "h-16 md:h-20 border border-gray-300 dark:border-gray-600 text-center align-middle bg-white dark:bg-gray-800"
    total_cell_style = "border border-gray-300 dark:border-gray-600 bg-gray-100 dark:bg-gray-700 text-center align-middle font-bold text-xs md:text-sm"

    html = "<div class='flex justify-center mb-8 px-1'>"
    # table-fixed là mấu chốt để ép các cột bằng nhau chặn chặn
    html += "<table class='border-collapse border border-gray-300 dark:border-gray-600 shadow-sm table-fixed w-full max-w-[340px] md:max-w-[450px]'>"

    html += f"""
    <thead>
        <tr class='h-8 md:h-10'>
            <th class='{label_col_style}'></th>
            <th class='{header_col_style}'>Cardinal</th>
            <th class='{header_col_style}'>Fixed</th>
            <th class='{header_col_style}'>Mutable</th>
            <th class='{header_col_style}'>Total</th>
        </tr>
    </thead>
    <tbody>
    """

    for r in range(4):
        el_name = row_names[r]
        el_color = COLORS[el_name]

        html += f"<tr class='h-16 md:h-20'>"
        # Label Nguyên tố (Màu cố định)
        html += f"<td class='{label_col_style}' style='color: {el_color} !important;'>{el_name}</td>"

        row_score_total = 0
        for c in range(3):
            syms = symbols_grid[r][c]
            row_score_total += scores[r][c]
            col_totals[c] += scores[r][c]

            # Planet Symbols
            content = f"<div class='flex flex-wrap items-center justify-center gap-1 md:gap-1.5 px-0.5'>"
            for s in syms:
                content += f"<span class='text-[11px] md:text-sm font-bold' style='color: {el_color} !important;'>{s}</span>"
            content += "</div>"

            html += f"<td class='{cell_style}'>{content}</td>"

        # Cột Total hàng (Màu theo nguyên tố)
        html += f"<td class='{total_cell_style}' style='color: {el_color} !important;'>{row_score_total}</td></tr>"

    # Hàng Totals dưới cùng
    html += f"<tr class='h-8 md:h-10 bg-gray-100 dark:bg-gray-700'><td class='{label_col_style}'>Total</td>"
    for c in range(3):
        html += f"<td class='{total_cell_style} text-gray-800 dark:text-gray-200'>{col_totals[c]}</td>"

    # Cell góc dưới phải
    html += "<td class='bg-gray-100 dark:bg-gray-700'></td></tr>"
    html += "</tbody></table></div>"

    return html


def generate_info_html(chart_data, profile):
    info = chart_data.get("info", {})
    addr_parts = profile['loc']['address'].split(',')
    country = addr_parts[-1].strip() if len(addr_parts) > 0 else ""
    city = ", ".join(addr_parts[:-1]).strip() if len(addr_parts) > 1 else addr_parts[0].strip()

    html = f"""
    <div class='mb-4 text-center'>
        <details class='group'>
            <summary class='inline-block cursor-pointer bg-gray-200 hover:bg-gray-300 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 font-bold py-1 px-3 rounded text-xs select-none'>
                Xem thông tin chi tiết (Show Time) <span class='ml-1 text-[10px] group-open:rotate-180 inline-block transition-transform'>▼</span>
            </summary>
            <div class='mt-2 text-xs border border-gray-300 dark:border-gray-600 rounded p-2 bg-gray-50 dark:bg-gray-800 text-left mx-auto max-w-md'>
                <div class='grid grid-cols-1 gap-y-1 text-gray-800 dark:text-gray-200'>
    """

    def row(l, v):
        return f"<div><span class='font-bold text-gray-600 dark:text-gray-400'>{l}:</span> <span class='font-medium'>{v}</span></div>"

    html += row("Date of Birth (local time)", info.get('local_time', ''))
    html += row("Universal Time (UT/GMT)", info.get('ut_time', ''))
    html += row("Local Sidereal Time (LST)", info.get('lst', ''))
    html += row("House system", info.get('house_sys', 'Placidus'))
    html += row("Latitude, Longitude", info.get('lat_lon', ''))
    html += row("City", city)
    html += row("Country", country)
    html += """
                </div>
            </div>
        </details>
    </div>
    """
    return html
