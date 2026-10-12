def get_midpoint(lon1, lon2):
    """Tính trung điểm của cung ngắn nhất giữa 2 góc."""
    diff = abs(lon1 - lon2)
    mid = (lon1 + lon2) / 2.0
    
    # Nếu khoảng cách > 180, điểm trung bình hiện tại nằm ở cung dài
    # -> Cần đảo 180 độ để về cung ngắn
    if diff > 180:
        mid += 180.0
    
    return mid % 360.0

def calculate_composite_chart(cA, cB):
    """
    Tạo dữ liệu Composite (Midpoint) từ 2 chart A và B.
    Cấu trúc trả về y hệt cấu trúc của Natal Chart để tái sử dụng hàm vẽ.
    """
    if not cA or not cB: return None
    
    composite = {
        "jd": 0, # Dummy
        "cusps": [],
        "angles": {},
        "planets": {},
        "meta": {"type": "Composite"},
        "info": {
            "local_time": "Composite Chart",
            "ut_time": "N/A",
            "lst": "N/A",
            "lat_lon": "Midpoint Method",
            "house_sys": "Composite Cusps"
        }
    }
    
    # 1. Tính Midpoint Planets
    all_planets = set(cA["planets"].keys()) | set(cB["planets"].keys())
    for p in all_planets:
        if p in cA["planets"] and p in cB["planets"]:
            lon1 = cA["planets"][p]["lon"]
            lon2 = cB["planets"][p]["lon"]
            mid_lon = get_midpoint(lon1, lon2)
            
            # Tốc độ: Tính trung bình
            speed1 = cA["planets"][p].get("speed", 0)
            speed2 = cB["planets"][p].get("speed", 0)
            
            composite["planets"][p] = {
                "lon": mid_lon,
                "lat": 0, 
                "speed": (speed1 + speed2) / 2
            }
            
    # 2. Tính Midpoint Angles (Asc, MC, Vertex)
    for angle in ["Asc", "MC", "Vertex"]:
        if angle in cA["angles"] and angle in cB["angles"]:
            a1 = cA["angles"][angle]
            a2 = cB["angles"][angle]
            mid_a = get_midpoint(a1, a2)
            composite["angles"][angle] = mid_a
            # Cập nhật lại vào planets để hàm vẽ hiển thị được AC/MC
            composite["planets"][angle] = {"lon": mid_a, "speed": 0, "lat": 0}

    # 3. Tính Midpoint Cusps (1-12)
    cuspsA = cA["cusps"]
    cuspsB = cB["cusps"]
    
    real_cuspsA = cuspsA[1:] if len(cuspsA) == 13 else cuspsA
    real_cuspsB = cuspsB[1:] if len(cuspsB) == 13 else cuspsB
    
    comp_cusps = []
    comp_cusps.append(0.0) # Dummy 0 element for 1-based index support
    
    for i in range(12):
        c1 = real_cuspsA[i]
        c2 = real_cuspsB[i]
        mid_c = get_midpoint(c1, c2)
        comp_cusps.append(mid_c)
        
    composite["cusps"] = comp_cusps
    
    return composite
