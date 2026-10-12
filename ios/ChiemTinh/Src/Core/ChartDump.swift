//  ChartDump.swift
//  Sinh JSON kết quả tính toán, ĐÚNG CÙNG ĐỊNH DẠNG với `tools/dump_python.py`,
//  để đối chiếu Swift vs Python từng con số.

import Foundation

public struct HarnessCase {
    public var id: String
    public var dob: String
    public var tob: String
    public var lat: Double
    public var lon: Double
    public var tz: String?
    public var manualOffset: String?
    public var ghiChu: String?
}

public enum ChartDump {

    /// Đọc `cases.json` (cùng file mà phía Python dùng).
    public static func loadCases(from data: Data) -> [HarnessCase] {
        guard let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return [] }
        return arr.map { d in
            HarnessCase(id: d["id"] as? String ?? "?",
                        dob: d["dob"] as? String ?? "",
                        tob: d["tob"] as? String ?? "",
                        lat: (d["lat"] as? NSNumber)?.doubleValue ?? 0,
                        lon: (d["lon"] as? NSNumber)?.doubleValue ?? 0,
                        tz: d["tz"] as? String,
                        manualOffset: d["manual_offset"] as? String,
                        ghiChu: d["ghi_chu"] as? String)
        }
    }

    /// In số thực đủ 17 chữ số có nghĩa → không mất độ chính xác khi qua JSON.
    @inline(__always) static func num(_ v: Double) -> String {
        if v.isNaN || v.isInfinite { return "null" }
        return String(format: "%.17g", v)
    }

    @inline(__always) static func str(_ s: String) -> String {
        var out = "\""
        for ch in s.unicodeScalars {
            switch ch {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            case "\r": out += "\\r"
            default:
                if ch.value < 0x20 { out += String(format: "\\u%04x", ch.value) }
                else { out.unicodeScalars.append(ch) }
            }
        }
        return out + "\""
    }

    public static func runAll(cases: [HarnessCase]) -> String {
        var parts: [String] = []
        for c in cases {
            guard let ch = AstroCore.calculateChart(dobStr: c.dob, tobStr: c.tob,
                                                    lat: c.lat, lon: c.lon,
                                                    tzStr: c.tz, manualOffset: c.manualOffset) else {
                parts.append("{\(str("id")):\(str(c.id)),\(str("error")):\(str("calculate_chart trả về None"))}")
                continue
            }
            var s = "{"
            s += "\(str("id")):\(str(c.id)),"
            s += "\(str("jd")):\(num(ch.jd)),"
            s += "\(str("cusps_len")):\(ch.cusps.count),"
            s += "\(str("cusps")):[" + ch.cusps.map { num($0) }.joined(separator: ",") + "],"
            s += "\(str("angles")):{"
                + ["Asc", "MC", "Vertex"].map { "\(str($0)):\(num(ch.angles[$0] ?? .nan))" }.joined(separator: ",")
                + "},"
            s += "\(str("planet_order")):[" + ch.planetOrder.map { str($0) }.joined(separator: ",") + "],"
            s += "\(str("planets")):{"
                + ch.planetOrder.map { name -> String in
                    let p = ch.planets[name]!
                    return "\(str(name)):{\(str("lon")):\(num(p.lon)),\(str("lat")):\(num(p.lat)),\(str("speed")):\(num(p.speed))}"
                }.joined(separator: ",")
                + "},"
            s += "\(str("info")):{"
                + "\(str("local_time")):\(str(ch.info.localTime)),"
                + "\(str("ut_time")):\(str(ch.info.utTime)),"
                + "\(str("lst")):\(str(ch.info.lst)),"
                + "\(str("lat_lon")):\(str(ch.info.latLon)),"
                + "\(str("house_sys")):\(str(ch.info.houseSys))"
                + "},"
            s += "\(str("meta")):{"
                + "\(str("lat")):\(num(ch.meta.lat)),"
                + "\(str("lon")):\(num(ch.meta.lon)),"
                + "\(str("tz")):\(ch.meta.tz.map { str($0) } ?? "null"),"
                + "\(str("offset_used")):\(num(ch.meta.offsetUsed))"
                + "}"
            s += "}"
            parts.append(s)
        }
        let meta = "{\(str("swe_version_c")):\(str(SwissEph.version())),"
            + "\(str("ephe_path")):\(str(Bundle.main.resourcePath ?? "?"))}"
        return "{\(str("meta")):\(meta),\(str("results")):[" + parts.joined(separator: ",") + "]}"
    }
}
