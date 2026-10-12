//  VaultLoader.swift
//  Nạp 14 file JSON nội dung + 8 bảng Markdown từ bundle (`Resources/Data/`).
//
//  Bundle iOS làm PHẲNG cây thư mục tài nguyên: `Resources/Data/text/cung.json`
//  vào bundle thành `cung.json` ở gốc. `resourceURL(_:)` dò cả 2 cách để chắc ăn.
//
//  Tất cả nạp LƯỜI (lazy) + có bộ nhớ đệm: `cap-cung.json` nặng 631 KB, không nên
//  đọc lúc khởi động app.

import Foundation

public enum VaultLoadError: Error, CustomStringConvertible {
    case notFound(String)
    case decodeFailed(String, String)

    public var description: String {
        switch self {
        case .notFound(let f): return "Không tìm thấy \(f) trong bundle"
        case .decodeFailed(let f, let m): return "Decode lỗi \(f): \(m)"
        }
    }
}

/// Tên 14 file JSON nội dung đã nhồi vào bundle.
public enum VaultFileName: String, CaseIterable, Sendable {
    case capCung          = "cap-cung"
    case cauHinh          = "cau-hinh"
    case cung             = "cung"
    case dangBanDo        = "dang-ban-do"
    case diemTamLinh      = "diem-tam-linh"
    case gocHop           = "goc-hop"
    case hanhTinh         = "hanh-tinh"
    case luongNguyen      = "luong-nguyen"
    case ngheNghiep       = "nghe-nghiep"
    case ngoaiHinh        = "ngoai-hinh"
    case nguyenToTinhChat = "nguyen-to-tinh-chat"
    case nha              = "nha"
    case synastry         = "synastry"
    case transit          = "transit"

    /// Nhãn tiếng Việt để in trong báo cáo kiểm tra.
    public var nhan: String {
        switch self {
        case .capCung:          return "66 cặp cung"
        case .cauHinh:          return "8 cấu hình"
        case .cung:             return "12 cung"
        case .dangBanDo:        return "9 dạng bản đồ"
        case .diemTamLinh:      return "điểm tâm linh"
        case .gocHop:           return "góc hợp"
        case .hanhTinh:         return "hành tinh"
        case .luongNguyen:      return "lưỡng nguyên"
        case .ngheNghiep:       return "nghề nghiệp"
        case .ngoaiHinh:        return "ngoại hình"
        case .nguyenToTinhChat: return "nguyên tố – tính chất"
        case .nha:              return "12 nhà"
        case .synastry:         return "synastry"
        case .transit:          return "transit"
        }
    }
}

/// 8 bảng Markdown trích từ ảnh chụp buổi học.
public enum VaultTableName: String, CaseIterable, Sendable {
    case ba3TinhChat        = "bang-3-tinh-chat"
    case bon4NguyenTo       = "bang-4-nguyen-to"
    case gocLeCaseBuoi7     = "bang-goc-le-case-buoi7"
    case gocTransitBuoi7    = "bang-goc-transit-case-buoi7"
    case hanhTinhTroiTheme  = "bang-hanh-tinh-troi-va-theme-quan-he"
    case traoDoiNangLuong   = "bang-trao-doi-nang-luong-oha"
    case synastryPlanetHouse = "bang-tuong-tac-synastry-planets-in-houses"
    case bietDanhHanhTinh   = "biet-danh-nguyen-mau-hanh-tinh-oha"
}

public final class VaultLoader: @unchecked Sendable {

    public static let shared = VaultLoader()

    private let bundle: Bundle
    private let lock = NSLock()
    private var cache: [String: Any] = [:]

    public init(bundle: Bundle = .main) { self.bundle = bundle }

    // MARK: - Tìm file trong bundle

    /// Dò URL của tài nguyên: thử cây thư mục con trước, rồi tới gốc bundle
    /// (Xcode làm phẳng thư mục khi copy theo kiểu "Copy Bundle Resources").
    public func resourceURL(_ name: String, ext: String, subdir: String) -> URL? {
        if let u = bundle.url(forResource: name, withExtension: ext, subdirectory: subdir) { return u }
        if let u = bundle.url(forResource: name, withExtension: ext, subdirectory: "Data/\(subdir)") { return u }
        if let u = bundle.url(forResource: name, withExtension: ext) { return u }
        return nil
    }

    public func data(_ name: String, ext: String, subdir: String) throws -> Data {
        guard let url = resourceURL(name, ext: ext, subdir: subdir) else {
            throw VaultLoadError.notFound("\(name).\(ext)")
        }
        return try Data(contentsOf: url)
    }

    // MARK: - Nạp có kiểu

    private func load<T: Decodable>(_ file: VaultFileName, as type: T.Type) throws -> T {
        let key = "\(file.rawValue)|\(String(describing: type))"
        lock.lock(); let hit = cache[key] as? T; lock.unlock()
        if let hit { return hit }

        let raw = try data(file.rawValue, ext: "json", subdir: "text")
        do {
            let value = try JSONDecoder().decode(T.self, from: raw)
            lock.lock(); cache[key] = value; lock.unlock()
            return value
        } catch {
            throw VaultLoadError.decodeFailed(file.rawValue + ".json", String(describing: error))
        }
    }

    /// Nạp NGUYÊN VĂN dạng `JSONValue` — không mất mảnh dữ liệu nào.
    public func raw(_ file: VaultFileName) throws -> JSONValue {
        try load(file, as: JSONValue.self)
    }

    public func signs()          throws -> VaultSignsFile          { try load(.cung, as: VaultSignsFile.self) }
    public func houses()         throws -> VaultHousesFile         { try load(.nha, as: VaultHousesFile.self) }
    public func planets()        throws -> VaultPlanetsFile        { try load(.hanhTinh, as: VaultPlanetsFile.self) }
    public func signPairs()      throws -> VaultSignPairsFile      { try load(.capCung, as: VaultSignPairsFile.self) }
    public func configurations() throws -> VaultConfigurationsFile { try load(.cauHinh, as: VaultConfigurationsFile.self) }
    public func chartShapes()    throws -> VaultChartShapesFile    { try load(.dangBanDo, as: VaultChartShapesFile.self) }
    public func elements()       throws -> VaultElementsFile       { try load(.nguyenToTinhChat, as: VaultElementsFile.self) }
    public func appearance()     throws -> VaultAppearanceFile     { try load(.ngoaiHinh, as: VaultAppearanceFile.self) }
    public func polarity()       throws -> VaultPolarityFile       { try load(.luongNguyen, as: VaultPolarityFile.self) }
    public func spiritual()      throws -> VaultSpiritualFile      { try load(.diemTamLinh, as: VaultSpiritualFile.self) }
    public func aspects()        throws -> VaultAspectsFile        { try load(.gocHop, as: VaultAspectsFile.self) }
    public func synastry()       throws -> VaultSynastryFile       { try load(.synastry, as: VaultSynastryFile.self) }
    public func transit()        throws -> VaultTransitFile        { try load(.transit, as: VaultTransitFile.self) }
    public func career()         throws -> VaultCareerFile         { try load(.ngheNghiep, as: VaultCareerFile.self) }

    // MARK: - Bảng Markdown

    public func markdown(_ table: VaultTableName) throws -> String {
        let raw = try data(table.rawValue, ext: "md", subdir: "anh")
        return String(decoding: raw, as: UTF8.self)
    }

    // MARK: - Tự kiểm

    public struct FileCheck: Sendable {
        public let file: String
        public let nhan: String
        public let bytes: Int
        /// Số bản ghi của nhánh dữ liệu chính (mảng lớn nhất trong file).
        public let soBanGhi: Int
        /// Diễn giải cách đếm (mảng nào).
        public let cachDem: String
        public let rawOK: Bool
        public let typedOK: Bool
        public let loi: String?
    }

    /// Nạp & kiểm TẤT CẢ file. Trả về bảng kết quả để in ra (dùng cho test/CLI).
    public func selfCheck() -> [FileCheck] {
        var out: [FileCheck] = []
        for f in VaultFileName.allCases {
            var bytes = 0
            var rawOK = false, typedOK = false
            var count = 0, how = "—"
            var err: String? = nil
            do {
                let d = try data(f.rawValue, ext: "json", subdir: "text")
                bytes = d.count
                _ = try raw(f)
                rawOK = true
                let (c, h) = try typedCount(f)
                count = c; how = h; typedOK = true
            } catch {
                err = String(describing: error)
            }
            out.append(FileCheck(file: f.rawValue + ".json", nhan: f.nhan, bytes: bytes,
                                 soBanGhi: count, cachDem: how,
                                 rawOK: rawOK, typedOK: typedOK, loi: err))
        }
        return out
    }

    private func typedCount(_ f: VaultFileName) throws -> (Int, String) {
        switch f {
        case .cung:             return (try signs().duLieu.count, "du_lieu")
        case .nha:              return (try houses().duLieu.count, "du_lieu")
        case .hanhTinh:         return (try planets().duLieu.count, "du_lieu")
        case .capCung:          return (try signPairs().duLieu.count, "du_lieu")
        case .cauHinh:          return (try configurations().duLieu.count, "du_lieu")
        case .dangBanDo:        return (try chartShapes().duLieu.count, "du_lieu")
        case .diemTamLinh:      return (try spiritual().duLieu.count, "du_lieu")
        case .nguyenToTinhChat:
            let e = try elements(); return (e.nguyenTo.count + e.tinhChat.count, "nguyen_to + tinh_chat")
        case .ngoaiHinh:
            let a = try appearance(); return (a.theoCungAC.count + a.theoHanhTinh.count, "theo_cung_AC + theo_hanh_tinh")
        case .luongNguyen:      return (try polarity().sauTrucDoiDinh.count, "sau_truc_doi_dinh")
        case .gocHop:
            let g = try aspects(); return (g.viDuLeTuBuoiHoc2.count + g.dienGiaiBaLoaiGoc.count,
                                           "vi_du_le_tu_buoi_hoc_2 + dien_giai_ba_loai_goc")
        case .synastry:
            let s = try synastry(); return (s.capCaNhanXCaNhan.count + s.capCaNhanXVongNgoai.count,
                                            "luan_hanh_tinh_ca_nhan_x_ca_nhan + _x_vong_ngoai")
        case .transit:
            let t = try transit(); return (t.bangChuKyHoiVi.bang.count + t.mocDaiHanDoiNguoi.bang.count,
                                           "bang_chu_ky_hoi_vi + moc_dai_han_doi_nguoi")
        case .ngheNghiep:
            let c = try career(); return (c.maTranNghe.count + c.comboBoSo.count,
                                          "ma_tran_nghe + combo_bo_so")
        }
    }

    public struct TableCheck: Sendable {
        public let file: String
        public let bytes: Int
        public let soDong: Int
        public let loi: String?
    }

    public func selfCheckTables() -> [TableCheck] {
        VaultTableName.allCases.map { t in
            do {
                let s = try markdown(t)
                return TableCheck(file: t.rawValue + ".md", bytes: s.utf8.count,
                                  soDong: s.split(separator: "\n", omittingEmptySubsequences: false).count,
                                  loi: nil)
            } catch {
                return TableCheck(file: t.rawValue + ".md", bytes: 0, soDong: 0,
                                  loi: String(describing: error))
            }
        }
    }
}
