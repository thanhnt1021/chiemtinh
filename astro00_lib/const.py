import swisseph as swe

# --- CONSTANTS GỐC ---
PLANET_IDS = {
    "Sun": swe.SUN, "Moon": swe.MOON, "Mercury": swe.MERCURY,
    "Venus": swe.VENUS, "Mars": swe.MARS, "Jupiter": swe.JUPITER,
    "Saturn": swe.SATURN, "Uranus": swe.URANUS, "Neptune": swe.NEPTUNE,
    "Pluto": swe.PLUTO, "True Node": swe.TRUE_NODE, "Chiron": swe.CHIRON,
    "Lilith": swe.MEAN_APOG
}
CORE_PLANETS = ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]
PERSONAL_PLANETS = ["Sun", "Moon", "Mercury", "Venus", "Mars"]
PERSONAL_PLANETS_SET = {"Sun", "Moon", "Mercury", "Venus", "Mars"}
PLANET_ORDER = ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]

# --- HÀNH TINH VÒNG NGOÀI (DÙNG RULE MỚI) ---
OUTER_PLANETS = ["Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]

# --- CÁC KHAI BÁO MỚI CHO GÓC TRANSIT ---
TRANSIT_PLANET_ORDER = ["Pluto", "Neptune", "Uranus", "Saturn", "Jupiter", "Mars", "Venus", "Mercury", "Moon", "Sun"]
NATAL_SPECIAL_POINTS = ["MC", "Asc", "Vertex", "Chiron", "South Node", "True Node"]
MAJOR_ASPECTS = ["Conjunction", "Sextile", "Square", "Trine", "Opposition"]

# Tạo danh sách mới RIÊNG cho Hồi Vị (Có thêm Chiron)
RETURN_PLANET_ORDER = ["Pluto", "Neptune", "Uranus", "Saturn", "Jupiter", "Mars", "Venus", "Mercury", "Moon", "Sun", "Chiron"]

# --- TIẾP TỤC CÁC HẰNG SỐ GỐC ---
FULL_OBJECTS_ORDER = ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto",
                      "True Node", "Chiron", "Vertex", "Asc", "MC"]

PLANET_SYMBOLS = {
    "Sun": "☉", "Moon": "☽", "Mercury": "☿", "Venus": "♀", "Mars": "♂",
    "Jupiter": "♃", "Saturn": "♄", "Uranus": "♅", "Neptune": "♆",
    "Pluto": "♇", "True Node": "☊", "Chiron": "⚷", "Vertex": "Vx",
    "Asc": "AC", "MC": "MC", "Lilith": "⚸", "South Node": "☋"
}

PLANET_POINTS = {
    "Asc": 4, "Sun": 4, "Moon": 4, "Mercury": 3, "Venus": 3, "Mars": 3,
    "Jupiter": 2, "Saturn": 2, "Uranus": 1, "Neptune": 1, "Pluto": 1
}
ZODIAC_SYMBOLS = ["♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐", "♑", "♒", "♓"]
ZODIAC_NAMES = ["Bạch Dương", "Kim Ngưu", "Song Tử", "Cự Giải", "Sư Tử", "Xử Nữ", "Thiên Bình", "Bọ Cạp", "Nhân Mã",
                "Ma Kết", "Bảo Bình", "Song Ngư"]
ZODIAC_CODES = ["Ari", "Tau", "Gem", "Can", "Leo", "Vir", "Lib", "Sco", "Sag", "Cap", "Aqu", "Pis"]
ZODIAC_MATRIX = {
    0: (0, 0), 1: (1, 1), 2: (2, 2), 3: (3, 0),
    4: (0, 1), 5: (1, 2), 6: (2, 0), 7: (3, 1),
    8: (0, 2), 9: (1, 0), 10: (2, 1), 11: (3, 2)
}
ELEMENT_NAMES = ["Fire", "Earth", "Air", "Water"]

ASPECTS_DEF = {
    "Conjunction": {"angle": 0, "orb": 10, "type": "Hard", "symbol": "☌", "name_vn": "Trùng", "color": "#000000"},
    "Semisextile": {"angle": 30, "orb": 3.0, "type": "Minor", "symbol": "⚺", "name_vn": "Bán Lục Hợp", "color": "#00cc00"},
    "Sextile": {"angle": 60, "orb": 6, "type": "Soft", "symbol": "⚹", "name_vn": "Lục Hợp", "color": "#0033ff"},
    "Square": {"angle": 90, "orb": 10, "type": "Hard", "symbol": "□", "name_vn": "Vuông Góc", "color": "#ff0000"},
    "Trine": {"angle": 120, "orb": 10, "type": "Soft", "symbol": "△", "name_vn": "Tam Hợp", "color": "#0033ff"},
    "Quincunx": {"angle": 150, "orb": 3.0, "type": "Minor", "symbol": "⚻", "name_vn": "Ngũ Chiếu", "color": "#00cc00"},
    "Opposition": {"angle": 180, "orb": 10, "type": "Hard", "symbol": "☍", "name_vn": "Đối Đỉnh", "color": "#ff0000"}
}

# --- BỔ SUNG CHỦ TINH ---
RULER_MAP = {
    "Bạch Dương": "Mars",
    "Kim Ngưu": "Venus",
    "Song Tử": "Mercury",
    "Cự Giải": "Moon",
    "Sư Tử": "Sun",
    "Xử Nữ": "Mercury",
    "Thiên Bình": "Venus",
    "Bọ Cạp": "Pluto",
    "Nhân Mã": "Jupiter",
    "Ma Kết": "Saturn",
    "Bảo Bình": "Uranus",
    "Song Ngư": "Neptune"
}

# --- CÁC NƯỚC CÓ PHÂN CHIA TIỂU BANG (Chuẩn Astrocom) ---
COUNTRIES_WITH_STATES = ['us', 'ca', 'au', 'br', 'in', 'mx']

# --- DANH SÁCH QUỐC GIA NHANH ---
COUNTRIES = [
    {"name": "Vietnam", "code": "vn"},
    {"name": "United States", "code": "us"},
    {"name": "United Kingdom", "code": "gb"},
    {"name": "Australia", "code": "au"},
    {"name": "Canada", "code": "ca"},
    {"name": "France", "code": "fr"},
    {"name": "Germany", "code": "de"},
    {"name": "Japan", "code": "jp"},
    {"name": "South Korea", "code": "kr"},
    {"name": "Russia", "code": "ru"},
    {"name": "India", "code": "in"},
    {"name": "Thailand", "code": "th"},
    {"name": "Singapore", "code": "sg"},
    {"name": "Toàn thế giới", "code": ""},
    {"name": "Khác...", "code": "other"}
]
