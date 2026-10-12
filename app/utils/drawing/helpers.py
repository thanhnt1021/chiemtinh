import math
import matplotlib.patches as patches
from .styles import *

def get_element_color(z_idx):
    rem = z_idx % 4
    if rem == 0: return COLOR_FIRE
    if rem == 1: return COLOR_EARTH
    if rem == 2: return COLOR_AIR
    if rem == 3: return COLOR_WATER
    return 'black'

def optimize_planet_positions_by_house(planets, cusps, lanes):
    """
    Thuật toán xếp hành tinh 2 vòng.
    """
    if not planets: return []

    house_groups = {i: [] for i in range(12)}
    real_cusps = list(cusps)
    if len(real_cusps) == 13: real_cusps = real_cusps[1:]

    for p in planets:
        h_idx = -1
        for i in range(12):
            c_curr = real_cusps[i]
            c_next = real_cusps[(i + 1) % 12]
            dist_p = (p['lon'] - c_curr) % 360
            size_h = (c_next - c_curr) % 360
            if dist_p < size_h:
                h_idx = i
                break
        if h_idx != -1:
            house_groups[h_idx].append(p)

    final_results = []

    BUFFER = 2.0
    MIN_DIST = 5.0

    for h_idx in range(12):
        group = house_groups[h_idx]
        if not group: continue

        c_start = real_cusps[h_idx]

        def get_rel_pos(p_lon):
            return (p_lon - c_start) % 360

        group.sort(key=lambda x: get_rel_pos(x['lon']))

        c_end = real_cusps[(h_idx + 1) % 12]
        house_width = (c_end - c_start) % 360

        lane_subgroups = {0: [], 1: []}

        for idx, p in enumerate(group):
            target_lane = 0 if (idx % 2 == 0) else 1
            if target_lane >= len(lanes): target_lane = 0
            lane_subgroups[target_lane].append(p)
            p['disp_r'] = lanes[target_lane]

        for l_idx in lane_subgroups:
            sub = lane_subgroups[l_idx]
            if not sub: continue

            rel_positions = []
            for p in sub:
                rel = get_rel_pos(p['lon'])
                rel_positions.append({'p': p, 'val': rel})

            for i in range(len(rel_positions)):
                curr = rel_positions[i]
                if i == 0:
                    if curr['val'] < BUFFER: curr['val'] = BUFFER
                else:
                    prev = rel_positions[i - 1]
                    if curr['val'] < prev['val'] + MIN_DIST:
                        curr['val'] = prev['val'] + MIN_DIST

            for i in range(len(rel_positions) - 1, -1, -1):
                curr = rel_positions[i]
                limit = house_width - BUFFER
                if curr['val'] > limit: curr['val'] = limit

                if i < len(rel_positions) - 1:
                    next_p = rel_positions[i + 1]
                    if curr['val'] > next_p['val'] - MIN_DIST:
                        curr['val'] = next_p['val'] - MIN_DIST

            for item in rel_positions:
                final_rel = item['val']
                final_abs = (c_start + final_rel) % 360
                item['p']['disp_lon'] = final_abs
                final_results.append(item['p'])

    return final_results

# --- HÀM VẼ GÓC DẠNG HÌNH THOI/THANH KIẾM (GIỮ NGUYÊN) ---
def draw_spindle(ax, theta1, theta2, radius, color, max_width=0.15, alpha=0.6, orb_ratio=1.0):
    """
    Vẽ hình dạng 'thanh kiếm': Thuôn nhọn ở 5% hai đầu, thân dày đều.
    """
    x1 = radius * math.cos(theta1);
    y1 = radius * math.sin(theta1)
    x2 = radius * math.cos(theta2);
    y2 = radius * math.sin(theta2)

    dx = x2 - x1;
    dy = y2 - y1
    length = math.sqrt(dx * dx + dy * dy)
    if length == 0: return

    nx = -dy / length;
    ny = dx / length
    width = max_width * (0.3 + 0.7 * orb_ratio)
    half_w = width / 2.0
    taper_ratio = 0.05

    xt1 = x1 + dx * taper_ratio;
    yt1 = y1 + dy * taper_ratio
    xt2 = x2 - dx * taper_ratio;
    yt2 = y2 - dy * taper_ratio

    def to_polar(x, y):
        r = math.sqrt(x * x + y * y)
        t = math.atan2(y, x)
        return t, r

    p1_t = theta1;
    p1_r = radius
    p2_t, p2_r = to_polar(xt1 + nx * half_w, yt1 + ny * half_w)
    p3_t, p3_r = to_polar(xt2 + nx * half_w, yt2 + ny * half_w)
    p4_t = theta2;
    p4_r = radius
    p5_t, p5_r = to_polar(xt2 - nx * half_w, yt2 - ny * half_w)
    p6_t, p6_r = to_polar(xt1 - nx * half_w, yt1 - ny * half_w)

    verts = [(p1_t, p1_r), (p2_t, p2_r), (p3_t, p3_r), (p4_t, p4_r), (p5_t, p5_r), (p6_t, p6_r)]

    poly = patches.Polygon(verts, closed=True, facecolor=color, edgecolor='black', linewidth=0.6, alpha=alpha, zorder=3)
    ax.add_patch(poly)
