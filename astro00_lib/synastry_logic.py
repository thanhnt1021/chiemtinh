from .const import PERSONAL_PLANETS_SET
from .core import check_aspect


def analyze_synastry_grid(cA, cB):
    """
    Phân tích Synastry Grid theo các quy tắc Check Trội 1, 2, 3, 4.
    Trả về dữ liệu tính toán và thông tin người chiến thắng để vẽ và hiển thị.
    """

    # Danh sách hành tinh cần xét (Rows A & Cols B)
    # Theo yêu cầu: "chỉ tính tới cột/hàng AC".
    OBJS_IN_ORDER = ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto",
                     "Asc"]

    # Lọc những hành tinh có trong chart
    list_A = [p for p in OBJS_IN_ORDER if p in cA["planets"]]
    list_B = [p for p in OBJS_IN_ORDER if p in cB["planets"]]

    # Hàm tính Score cho 1 hành tinh (so với list đối phương)
    def calculate_score(p_name, p_lon, target_list, target_chart):
        stats = {
            "count": 0,
            "tight_count": 0,  # < 1.0
            "loose_count": 0,  # > 6.5 and <= 10.0
            "total_orb_round": 0,
            "total_orb_raw": 0.0,
            "is_personal": p_name in PERSONAL_PLANETS_SET
        }

        for target_name in target_list:
            if target_name not in target_chart["planets"]: continue
            target_lon = target_chart["planets"][target_name]["lon"]

            asp = check_aspect(p_lon, target_lon)
            if asp:
                # --- YÊU CẦU MỚI: Bỏ qua góc Minor (30, 150) khỏi bộ đếm ---
                if asp['type'] == 'Minor':
                    continue

                orb = asp["orb"]
                orb_round = int(orb)

                # --- CẬP NHẬT: Bỏ qua nếu Orb >= 10 ---
                if orb >= 10.0: continue

                stats["count"] += 1
                stats["total_orb_round"] += orb_round
                stats["total_orb_raw"] += orb

                if orb < 1.0:
                    stats["tight_count"] += 1

                # --- ĐÃ SỬA: Lấy > 6.5 (Thay vì >= 7.0 cũ) ---
                if 6.5 < orb <= 10.0:
                    stats["loose_count"] += 1

        return stats

    # 1. Tính toán Stats cho A
    scores_A = {}
    for p in list_A:
        scores_A[p] = calculate_score(p, cA["planets"][p]["lon"], list_B, cB)

    # 2. Tính toán Stats cho B
    scores_B = {}
    for p in list_B:
        scores_B[p] = calculate_score(p, cB["planets"][p]["lon"], list_A, cA)

    # ==========================================================================
    # HÀM GIẢI QUYẾT TIE-BREAKER (PHỄU LỌC 6 TẦNG)
    # ==========================================================================
    def solve_tie_breaker(candidates_dict, check_personal_at_level_4=True):
        if not candidates_dict: return None, "No candidates"

        current_candidates = list(candidates_dict.keys())

        # Level 1: Max Count
        max_count = max(candidates_dict[p]["count"] for p in current_candidates)
        group_1 = [p for p in current_candidates if candidates_dict[p]["count"] == max_count]
        if len(group_1) == 1: return group_1[0], "Max Count"

        # Level 2: Max Tight Count (<1)
        max_tight = max(candidates_dict[p]["tight_count"] for p in group_1)
        group_2 = [p for p in group_1 if candidates_dict[p]["tight_count"] == max_tight]
        if len(group_2) == 1: return group_2[0], "Max Tight Count"

        # Level 3: Min Loose Count (>6.5)
        min_loose = min(candidates_dict[p]["loose_count"] for p in group_2)
        group_3 = [p for p in group_2 if candidates_dict[p]["loose_count"] == min_loose]
        if len(group_3) == 1: return group_3[0], "Min Loose Count"

        # Level 4: Personal Planet (Check if required)
        group_4 = group_3  # Mặc định: Giữ nguyên danh sách hiện tại (Dành cho TH3)

        if check_personal_at_level_4:
            personal_in_group = [p for p in group_3 if candidates_dict[p]["is_personal"]]

            # --- TH1: Chỉ có 1 hành tinh cá nhân ---
            # -> Chốt luôn Winner (Kết thúc vòng lặp)
            if len(personal_in_group) == 1:
                return personal_in_group[0], "Unique Personal Planet"

            # --- TH2: Có > 1 hành tinh cá nhân ---
            # -> Lọc danh sách chỉ giữ lại các hành tinh cá nhân này.
            # -> Sau đó đi tiếp xuống Level 5 (Check Orb).
            if len(personal_in_group) > 1:
                group_4 = personal_in_group

            # --- TH3: Không có hành tinh cá nhân nào (len == 0) ---
            # -> Logic: Xử lý giống hệt luồng đi tiếp của TH2.
            # -> Nghĩa là: Không chốt winner ngay, mà mang danh sách hiện có (group_3) đi tiếp xuống Level 5 (Check Orb).
            # (Biến group_4 đã được gán = group_3 ở dòng đầu tiên, đảm bảo logic này).

        # Level 5: Min Total Orb Round
        min_orb_round = min(candidates_dict[p]["total_orb_round"] for p in group_4)
        group_5 = [p for p in group_4 if candidates_dict[p]["total_orb_round"] == min_orb_round]
        if len(group_5) == 1: return group_5[0], "Min Total Orb Round"

        # Level 5.2: Min Total Orb Raw
        final_winner = min(group_5, key=lambda p: candidates_dict[p]["total_orb_raw"])
        return final_winner, "Min Total Orb Raw"

    # ==========================================================================
    # THỰC HIỆN QUY TẮC CHECK TRỘI SỐ 1 (GLOBAL)
    # ==========================================================================
    candidates_A = {k: v for k, v in scores_A.items() if k != 'Asc'}
    candidates_B = {k: v for k, v in scores_B.items() if k != 'Asc'}

    winner_A, reason_A = solve_tie_breaker(candidates_A)
    winner_B, reason_B = solve_tie_breaker(candidates_B)

    # ==========================================================================
    # THỰC HIỆN LOGIC THEME & KÈM (QUY TẮC 2, 3, 4)
    # ==========================================================================
    final_theme_A = winner_A
    final_theme_B = winner_B
    accompanying_planet = None

    is_A_personal = scores_A[winner_A]["is_personal"]
    is_B_personal = scores_B[winner_B]["is_personal"]

    if is_A_personal or is_B_personal:
        pass
    else:
        # QUY TẮC 3: Cả 2 đều KHÔNG PHẢI Personal
        subset_A = {p: s for p, s in scores_A.items() if s["is_personal"]}
        subset_B = {p: s for p, s in scores_B.items() if s["is_personal"]}

        winner_A1, _ = solve_tie_breaker(subset_A, check_personal_at_level_4=False)
        winner_B1, _ = solve_tie_breaker(subset_B, check_personal_at_level_4=False)

        # QUY TẮC 4: Tìm hành tinh Kèm
        stat_A1 = subset_A[winner_A1]
        stat_B1 = subset_B[winner_B1]

        kem_winner = None
        if stat_A1["count"] > stat_B1["count"]:
            kem_winner = "A"
        elif stat_B1["count"] > stat_A1["count"]:
            kem_winner = "B"
        else:
            if stat_A1["tight_count"] > stat_B1["tight_count"]:
                kem_winner = "A"
            elif stat_B1["tight_count"] > stat_A1["tight_count"]:
                kem_winner = "B"
            else:
                if stat_A1["loose_count"] < stat_B1["loose_count"]:
                    kem_winner = "A"
                elif stat_B1["loose_count"] < stat_A1["loose_count"]:
                    kem_winner = "B"
                else:
                    if stat_A1["total_orb_round"] < stat_B1["total_orb_round"]:
                        kem_winner = "A"
                    elif stat_B1["total_orb_round"] < stat_A1["total_orb_round"]:
                        kem_winner = "B"
                    else:
                        if stat_A1["total_orb_raw"] <= stat_B1["total_orb_raw"]:
                            kem_winner = "A"
                        else:
                            kem_winner = "B"

        if kem_winner == "A":
            accompanying_planet = {"name": winner_A1, "owner": "A"}
        else:
            accompanying_planet = {"name": winner_B1, "owner": "B"}

    # ==========================================================================
    # TÌM THEME PHỤ (MUTUAL ASPECTS)
    # --- CẬP NHẬT: Sắp xếp theo thứ tự chuẩn Sun -> Pluto ---
    # ==========================================================================
    sub_themes = []
    found_pairs = set()

    # 1. Định nghĩa thứ tự chuẩn để sắp xếp
    SORT_ORDER = ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]

    # List kiểm tra (giống SORT_ORDER)
    check_list = SORT_ORDER

    # Định nghĩa Special Points để check (dù check_list không có, vẫn giữ logic an toàn)
    SPECIAL_POINTS = {"True Node", "Chiron", "Vertex"}

    for i in range(len(check_list)):
        for j in range(len(check_list)):
            pX = check_list[i]
            pY = check_list[j]

            # Bỏ qua trùng lặp
            if pX == pY: continue

            # Xác định cặp X-Y theo thứ tự chuẩn (Nguyên tắc 1)
            # Hành tinh nào có index nhỏ hơn trong SORT_ORDER thì đứng trước
            idx_X = SORT_ORDER.index(pX)
            idx_Y = SORT_ORDER.index(pY)

            if idx_X < idx_Y:
                pair_key = (pX, pY)
            else:
                pair_key = (pY, pX)

            if pair_key in found_pairs: continue

            # --- CẬP NHẬT: Điều kiện lọc Personal (ít nhất 1 trong 2 phải là Personal) ---
            is_X_personal = pX in PERSONAL_PLANETS_SET
            is_Y_personal = pY in PERSONAL_PLANETS_SET
            if not (is_X_personal or is_Y_personal):
                continue

            if pX not in cA["planets"] or pY not in cB["planets"]: continue
            if pY not in cA["planets"] or pX not in cB["planets"]: continue

            aspect_1 = check_aspect(cA["planets"][pX]["lon"], cB["planets"][pY]["lon"])
            aspect_2 = check_aspect(cA["planets"][pY]["lon"], cB["planets"][pX]["lon"])

            if aspect_1 and aspect_2:
                # --- NEW FILTER: Chỉ chấp nhận góc hiển thị trên Grid ---
                # 1. Loại bỏ góc Minor (Grid đang ẩn góc Minor)
                if aspect_1['type'] == 'Minor' or aspect_2['type'] == 'Minor':
                    continue

                # 2. Loại bỏ góc Special Point nếu Orb > 3
                is_sp1 = (pX in SPECIAL_POINTS) or (pY in SPECIAL_POINTS)
                if is_sp1 and aspect_1['orb'] > 3.0: continue

                is_sp2 = (pY in SPECIAL_POINTS) or (pX in SPECIAL_POINTS)
                if is_sp2 and aspect_2['orb'] > 3.0: continue
                # --------------------------------------------------------

                sub_themes.append(pair_key)
                found_pairs.add(pair_key)

    # Sắp xếp danh sách sub_themes (Nguyên tắc 2)
    # Xếp theo X trước, rồi đến Y
    sub_themes.sort(key=lambda pair: (SORT_ORDER.index(pair[0]), SORT_ORDER.index(pair[1])))

    return {
        "scores_A": scores_A,
        "scores_B": scores_B,
        "dominant_A": final_theme_A,
        "dominant_B": final_theme_B,
        "accompanying": accompanying_planet,
        "sub_themes": sub_themes
    }
