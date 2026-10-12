import astro00_lib as lib

def get_dominant_planets_logic(chart_data):
    """Tìm hành tinh trội (Logic phễu 4 bước: Số lượng -> Chặt -> Cá nhân -> Tổng Orb)"""
    candidates = lib.CORE_PLANETS
    p_pos = chart_data["planets"]
    core_targets = lib.CORE_PLANETS
    planet_stats = {}

    for p in candidates:
        if p not in p_pos: continue
        stats = {'count': 0, 'aspects': []}
        for target in core_targets:
            if target not in p_pos: continue
            if p == target: continue
            asp = lib.check_aspect(p_pos[p]['lon'], p_pos[target]['lon'])
            if asp:
                # --- CẬP NHẬT: Bỏ qua góc Minor (Semisextile, Quincunx) khi tính điểm ---
                if asp['type'] == 'Minor': continue

                stats['count'] += 1
                stats['aspects'].append({'target': target, 'orb_round': asp['orb_round'], 'type': asp['type']})
        planet_stats[p] = stats

    if not planet_stats: return []

    def get_orb_sum(p_name):
        return sum(a['orb_round'] for a in planet_stats[p_name]['aspects'])

    # Bước 1: Max Count
    max_count = max(s['count'] for s in planet_stats.values())
    group_1 = [p for p in planet_stats if planet_stats[p]['count'] == max_count]

    if len(group_1) == 1:
        p = group_1[0]
        return [{"name": p, "stats": planet_stats[p], "total_orb": get_orb_sum(p), "reason": "Số lượng góc nhiều nhất"}]

    # Bước 2: Tightest Orb
    p_min_orbs = {}
    for p in group_1:
        asps = planet_stats[p]['aspects']
        p_min_orbs[p] = min(a['orb_round'] for a in asps) if asps else 999

    global_min_orb = min(p_min_orbs.values())
    group_2 = [p for p in group_1 if p_min_orbs[p] == global_min_orb]

    if len(group_2) == 1:
        p = group_2[0]
        return [{"name": p, "stats": planet_stats[p], "total_orb": get_orb_sum(p), "reason": "Góc chặt nhất nhỏ hơn"}]

    # Bước 3: Personal Planet Priority
    personal_planets = lib.PERSONAL_PLANETS
    has_personal = {}
    for p in group_2:
        tightest = [a for a in planet_stats[p]['aspects'] if a['orb_round'] == global_min_orb]
        flag = False
        for a in tightest:
            if (p in personal_planets) or (a['target'] in personal_planets):
                flag = True;
                break
        has_personal[p] = flag

    group_3 = [p for p in group_2 if has_personal[p]]
    current = group_3 if (0 < len(group_3) < len(group_2)) else group_2

    # Bước 4: Total Orb (Ascending)
    final_list = []
    for p in current:
        total = get_orb_sum(p)
        final_list.append({"name": p, "stats": planet_stats[p], "total_orb": total, "reason": f"Tổng Orb: {total}"})

    final_list.sort(key=lambda x: x['total_orb'])
    return final_list


def get_dominant_houses_sorted(chart_data):
    """Tính điểm nhà trội (>=4), trả về list sorted High->Low"""
    scores = {h: 0 for h in range(1, 13)}
    cusps = chart_data["cusps"]
    for p, info in chart_data["planets"].items():
        if p == "Asc": continue
        if p in lib.PLANET_POINTS:
            h = lib.get_house_of_planet(info['lon'], cusps)
            scores[h] += lib.PLANET_POINTS[p]
    dom = [(h, s) for h, s in scores.items() if s >= 4]
    dom.sort(key=lambda x: x[1], reverse=True)
    return dom
