//  AstroConst.swift
//  Port 1-1 từ `app/astro00_lib/const.py` (bản REPO `73e2e63`, giống hệt bản local).
//  Thứ tự phần tử GIỮ NGUYÊN thứ tự khai báo trong Python (dict Python có thứ tự chèn).

import Foundation

public enum AstroConst {

    /// `const.py:4-10` — PLANET_IDS. Mảng có thứ tự vì `calculate_chart` lặp theo thứ tự dict.
    public static let planetIDs: [(name: String, id: Int32)] = [
        ("Sun", SwePlanet.sun),
        ("Moon", SwePlanet.moon),
        ("Mercury", SwePlanet.mercury),
        ("Venus", SwePlanet.venus),
        ("Mars", SwePlanet.mars),
        ("Jupiter", SwePlanet.jupiter),
        ("Saturn", SwePlanet.saturn),
        ("Uranus", SwePlanet.uranus),
        ("Neptune", SwePlanet.neptune),
        ("Pluto", SwePlanet.pluto),
        ("True Node", SwePlanet.trueNode),
        ("Chiron", SwePlanet.chiron),
        ("Lilith", SwePlanet.meanApog)
    ]

    public static let planetIDMap: [String: Int32] = {
        var m = [String: Int32]()
        for p in planetIDs { m[p.name] = p.id }
        return m
    }()

    /// `const.py:11`
    public static let corePlanets: [String] = [
        "Sun", "Moon", "Mercury", "Venus", "Mars",
        "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"
    ]
    /// `const.py:12-13`
    public static let personalPlanets: [String] = ["Sun", "Moon", "Mercury", "Venus", "Mars"]
    /// `const.py:14`
    public static let planetOrder: [String] = corePlanets
    /// `const.py:17`
    public static let outerPlanets: [String] = ["Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]
    /// `const.py:20`
    public static let transitPlanetOrder: [String] = [
        "Pluto", "Neptune", "Uranus", "Saturn", "Jupiter",
        "Mars", "Venus", "Mercury", "Moon", "Sun"
    ]
    /// `const.py:21`
    public static let natalSpecialPoints: [String] = [
        "MC", "Asc", "Vertex", "Chiron", "South Node", "True Node"
    ]
    /// `const.py:22`
    public static let majorAspects: [String] = [
        "Conjunction", "Sextile", "Square", "Trine", "Opposition"
    ]
    /// `const.py:25`
    public static let returnPlanetOrder: [String] = [
        "Pluto", "Neptune", "Uranus", "Saturn", "Jupiter",
        "Mars", "Venus", "Mercury", "Moon", "Sun", "Chiron"
    ]
    /// `const.py:28-29`
    public static let fullObjectsOrder: [String] = [
        "Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn",
        "Uranus", "Neptune", "Pluto", "True Node", "Chiron", "Vertex", "Asc", "MC"
    ]

    /// `const.py:31-36`
    public static let planetSymbols: [String: String] = [
        "Sun": "☉", "Moon": "☽", "Mercury": "☿", "Venus": "♀", "Mars": "♂",
        "Jupiter": "♃", "Saturn": "♄", "Uranus": "♅", "Neptune": "♆",
        "Pluto": "♇", "True Node": "☊", "Chiron": "⚷", "Vertex": "Vx",
        "Asc": "AC", "MC": "MC", "Lilith": "⚸", "South Node": "☋"
    ]

    /// `const.py:38-41`
    public static let planetPoints: [String: Int] = [
        "Asc": 4, "Sun": 4, "Moon": 4, "Mercury": 3, "Venus": 3, "Mars": 3,
        "Jupiter": 2, "Saturn": 2, "Uranus": 1, "Neptune": 1, "Pluto": 1
    ]

    /// `const.py:42`
    public static let zodiacSymbols: [String] = ["♈","♉","♊","♋","♌","♍","♎","♏","♐","♑","♒","♓"]
    /// `const.py:43-44`
    public static let zodiacNames: [String] = [
        "Bạch Dương", "Kim Ngưu", "Song Tử", "Cự Giải", "Sư Tử", "Xử Nữ",
        "Thiên Bình", "Bọ Cạp", "Nhân Mã", "Ma Kết", "Bảo Bình", "Song Ngư"
    ]
    /// `const.py:45`
    public static let zodiacCodes: [String] = [
        "Ari","Tau","Gem","Can","Leo","Vir","Lib","Sco","Sag","Cap","Aqu","Pis"
    ]
    /// `const.py:46-50` — (hàng Element, cột Quality)
    public static let zodiacMatrix: [Int: (row: Int, col: Int)] = [
        0: (0,0), 1: (1,1), 2: (2,2), 3: (3,0),
        4: (0,1), 5: (1,2), 6: (2,0), 7: (3,1),
        8: (0,2), 9: (1,0), 10: (2,1), 11: (3,2)
    ]
    /// `const.py:51`
    public static let elementNames: [String] = ["Fire", "Earth", "Air", "Water"]

    public struct AspectDef {
        public let name: String
        public let angle: Double
        public let orb: Double
        public let type: String
        public let symbol: String
        public let nameVN: String
        public let color: String
    }

    /// `const.py:53-61` — GIỮ ĐÚNG THỨ TỰ khai báo, vì `check_aspect` duyệt tuần tự
    /// và trả về góc ĐẦU TIÊN thoả điều kiện.
    public static let aspectsDef: [AspectDef] = [
        AspectDef(name: "Conjunction", angle: 0,   orb: 10,  type: "Hard",  symbol: "☌", nameVN: "Trùng",         color: "#000000"),
        AspectDef(name: "Semisextile", angle: 30,  orb: 3.0, type: "Minor", symbol: "⚺", nameVN: "Bán Lục Hợp",   color: "#00cc00"),
        AspectDef(name: "Sextile",     angle: 60,  orb: 6,   type: "Soft",  symbol: "⚹", nameVN: "Lục Hợp",       color: "#0033ff"),
        AspectDef(name: "Square",      angle: 90,  orb: 10,  type: "Hard",  symbol: "□", nameVN: "Vuông Góc",     color: "#ff0000"),
        AspectDef(name: "Trine",       angle: 120, orb: 10,  type: "Soft",  symbol: "△", nameVN: "Tam Hợp",       color: "#0033ff"),
        AspectDef(name: "Quincunx",    angle: 150, orb: 3.0, type: "Minor", symbol: "⚻", nameVN: "Ngũ Chiếu",     color: "#00cc00"),
        AspectDef(name: "Opposition",  angle: 180, orb: 10,  type: "Hard",  symbol: "☍", nameVN: "Đối Đỉnh",      color: "#ff0000")
    ]

    public static let aspectByName: [String: AspectDef] = {
        var m = [String: AspectDef]()
        for a in aspectsDef { m[a.name] = a }
        return m
    }()

    /// `const.py:64-77`
    public static let rulerMap: [String: String] = [
        "Bạch Dương": "Mars",   "Kim Ngưu": "Venus",
        "Song Tử": "Mercury",   "Cự Giải": "Moon",
        "Sư Tử": "Sun",         "Xử Nữ": "Mercury",
        "Thiên Bình": "Venus",  "Bọ Cạp": "Pluto",
        "Nhân Mã": "Jupiter",   "Ma Kết": "Saturn",
        "Bảo Bình": "Uranus",   "Song Ngư": "Neptune"
    ]
}
