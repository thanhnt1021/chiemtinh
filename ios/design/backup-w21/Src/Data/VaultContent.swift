//  VaultContent.swift
//  Struct `Codable` cho 14 file JSON nội dung (vault) nằm ở `Resources/Data/text/`.
//
//  NGUYÊN TẮC:
//   • Tên khoá giữ NGUYÊN chữ không dấu của file gốc (`mo_ta`, `du_lieu`, `nguon`…)
//     qua `CodingKeys`, để đối chiếu 1-1 với JSON.
//   • Nhánh nào hình dạng bất quy tắc thì để `JSONValue` — KHÔNG bỏ dữ liệu.
//   • File `mui-gio-vn.json` CỐ Ý KHÔNG nhồi vào bundle: founder chốt bảng múi giờ
//     dùng cho tính toán là bản trong `core.py` (đã port ở `AstroCore.getVietnamHistoricalOffset`).

import Foundation

// MARK: - Kiểu phụ dùng chung ------------------------------------------------

/// `nguon_chinh` khi thì là chuỗi, khi thì là mảng chuỗi.
public enum StringOrList: Codable, Hashable, Sendable {
    case one(String)
    case many([String])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .one(s); return }
        self = .many(try c.decode([String].self))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .one(let s):  try c.encode(s)
        case .many(let a): try c.encode(a)
        }
    }
    public var lines: [String] {
        switch self { case .one(let s): return [s]; case .many(let a): return a }
    }
}

// MARK: - 1. cung.json (12 cung hoàng đạo) -----------------------------------

public struct VaultZodiacSign: Codable, Hashable, Identifiable, Sendable {
    public var id: Int { so }
    public let so: Int
    public let ten: String
    public let kyHieu: String
    public let nguyenTo: String
    public let tinhChat: String
    public let chuTinh: String
    public let moTaChung: [String]
    public let suMenh: [String]
    public let nhuCauGoc: JSONValue?
    public let cacNhomBieuHien: [JSONValue]?
    public let nguon: String?
    public let ghiChuBienTap: String?

    enum CodingKeys: String, CodingKey {
        case so, ten, nguon
        case kyHieu = "ky_hieu"
        case nguyenTo = "nguyen_to"
        case tinhChat = "tinh_chat"
        case chuTinh = "chu_tinh"
        case moTaChung = "mo_ta_chung"
        case suMenh = "su_menh"
        case nhuCauGoc = "nhu_cau_goc"
        case cacNhomBieuHien = "cac_nhom_bieu_hien"
        case ghiChuBienTap = "ghi_chu_bien_tap"
    }
}

public struct VaultSignsFile: Codable, Sendable {
    public let moTa: String
    public let nguonChinh: StringOrList
    public let ghiChu: String?
    public let soBanGhi: Int
    public let duLieu: [VaultZodiacSign]
    enum CodingKeys: String, CodingKey {
        case moTa = "mo_ta", nguonChinh = "nguon_chinh", ghiChu = "ghi_chu"
        case soBanGhi = "so_ban_ghi", duLieu = "du_lieu"
    }
}

// MARK: - 2. nha.json (12 nhà) -----------------------------------------------

public struct VaultHouse: Codable, Hashable, Identifiable, Sendable {
    public var id: Int { so }
    public let so: Int
    public let ma: String
    public let linhVuc: [String]
    public let chiTiet: [String]
    public let goiYNghe: [String]
    public let nguon: String?
    public let trangThai: String?
    public let ghiChuGoc: String?
    enum CodingKeys: String, CodingKey {
        case so, ma, nguon
        case linhVuc = "linh_vuc", chiTiet = "chi_tiet", goiYNghe = "goi_y_nghe"
        case trangThai = "trang_thai", ghiChuGoc = "ghi_chu_goc"
    }
}

public struct VaultHousesFile: Codable, Sendable {
    public let moTa: String
    public let nguonChinh: StringOrList
    public let ghiChu: String?
    public let soBanGhi: Int
    public let duLieu: [VaultHouse]
    enum CodingKeys: String, CodingKey {
        case moTa = "mo_ta", nguonChinh = "nguon_chinh", ghiChu = "ghi_chu"
        case soBanGhi = "so_ban_ghi", duLieu = "du_lieu"
    }
}

// MARK: - 3. hanh-tinh.json (11 hành tinh) -----------------------------------

public struct VaultPlanet: Codable, Hashable, Identifiable, Sendable {
    public var id: Int { so }
    public let so: Int
    public let ten: String
    public let tenEn: String
    public let kyHieu: String
    public let tichCuc: [String]
    public let tieuCuc: [String]
    public let truyenDi: String?
    public let nhanVe: String?
    public let viDuTuongTac: [String]?
    public let trangThai: String?
    public let nguon: String?
    public let ghiChuBuoiHoc2: [String]?
    public let ghiChuBienTap: String?
    enum CodingKeys: String, CodingKey {
        case so, ten, nguon
        case tenEn = "ten_en", kyHieu = "ky_hieu"
        case tichCuc = "tich_cuc", tieuCuc = "tieu_cuc"
        case truyenDi = "truyen_di", nhanVe = "nhan_ve"
        case viDuTuongTac = "vi_du_tuong_tac", trangThai = "trang_thai"
        case ghiChuBuoiHoc2 = "ghi_chu_buoi_hoc_2", ghiChuBienTap = "ghi_chu_bien_tap"
    }
}

public struct VaultPlanetsFile: Codable, Sendable {
    public let moTa: String
    public let nguonChinh: StringOrList
    public let quyTacUngDung: JSONValue?
    public let soBanGhi: Int
    public let duLieu: [VaultPlanet]
    enum CodingKeys: String, CodingKey {
        case moTa = "mo_ta", nguonChinh = "nguon_chinh"
        case quyTacUngDung = "quy_tac_ung_dung", soBanGhi = "so_ban_ghi", duLieu = "du_lieu"
    }
}

// MARK: - 4. cap-cung.json (66 cặp cung) -------------------------------------

public struct VaultFamousPerson: Codable, Hashable, Sendable {
    public let tenVaNghe: String?
    public let viTri: String?
    enum CodingKeys: String, CodingKey { case tenVaNghe = "ten_va_nghe", viTri = "vi_tri" }
}

public struct VaultSignPair: Codable, Hashable, Identifiable, Sendable {
    public var id: String { idField }
    public let idField: String
    public let cung1: String
    public let cung2: String
    public let cung1So: Int
    public let cung2So: Int
    public let loaiGoc: String
    public let loaiGocEn: String
    public let doGoc: Int
    public let chuong: String?
    public let tieuDeGoc: String?
    public let luanGiai: [String]
    public let nguoiNoiTieng: [VaultFamousPerson]
    public let nguon: String?
    enum CodingKeys: String, CodingKey {
        case idField = "id"
        case cung1 = "cung_1", cung2 = "cung_2"
        case cung1So = "cung_1_so", cung2So = "cung_2_so"
        case loaiGoc = "loai_goc", loaiGocEn = "loai_goc_en"
        case doGoc = "do"
        case chuong, nguon
        case tieuDeGoc = "tieu_de_goc"
        case luanGiai = "luan_giai", nguoiNoiTieng = "nguoi_noi_tieng"
    }
}

public struct VaultSignPairsFile: Codable, Sendable {
    public let moTa: String
    public let nguonChinh: StringOrList
    public let soBanGhi: Int
    public let ketQuaDem: JSONValue?
    public let danNhapTungLoaiGoc: [JSONValue]?
    public let chuThichCuoiChuong: [JSONValue]?
    public let duLieu: [VaultSignPair]
    enum CodingKeys: String, CodingKey {
        case moTa = "mo_ta", nguonChinh = "nguon_chinh", soBanGhi = "so_ban_ghi"
        case ketQuaDem = "ket_qua_dem"
        case danNhapTungLoaiGoc = "dan_nhap_tung_loai_goc"
        case chuThichCuoiChuong = "chu_thich_cuoi_chuong"
        case duLieu = "du_lieu"
    }
}

// MARK: - 5. cau-hinh.json (8 cấu hình) --------------------------------------

public struct VaultConfiguration: Codable, Hashable, Identifiable, Sendable {
    public var id: Int { so }
    public let so: Int
    public let ten: String
    public let tenVi: String
    public let nhanBiet: String?
    public let tieuChiSo: JSONValue?
    public let dacDiem: [String]
    public let nguon: String?
    public let bienTheTheoTinhChat: [JSONValue]?
    public let hanhTinhDacBiet: JSONValue?
    public let bienTheTheoNguyenTo: [JSONValue]?
    enum CodingKeys: String, CodingKey {
        case so, ten, nguon
        case tenVi = "ten_vi", nhanBiet = "nhan_biet"
        case tieuChiSo = "tieu_chi_so", dacDiem = "dac_diem"
        case bienTheTheoTinhChat = "bien_the_theo_tinh_chat"
        case hanhTinhDacBiet = "hanh_tinh_dac_biet"
        case bienTheTheoNguyenTo = "bien_the_theo_nguyen_to"
    }
}

public struct VaultConfigurationsFile: Codable, Sendable {
    public let moTa: String
    public let nguonChinh: StringOrList
    public let ghiChuOrb: String?
    public let soBanGhi: Int
    public let duLieu: [VaultConfiguration]
    enum CodingKeys: String, CodingKey {
        case moTa = "mo_ta", nguonChinh = "nguon_chinh", ghiChuOrb = "ghi_chu_orb"
        case soBanGhi = "so_ban_ghi", duLieu = "du_lieu"
    }
}

// MARK: - 6. dang-ban-do.json (9 dạng bản đồ) --------------------------------

public struct VaultChartShape: Codable, Hashable, Identifiable, Sendable {
    public var id: Int { so }
    public let so: Int
    public let ten: String
    public let tenEn: String
    public let nhom: String
    public let nhanBiet: String?
    public let tieuChiSo: JSONValue?
    public let dacDiem: [String]
    public let nguon: String?
    public let hanhTinhDacBiet: JSONValue?
    public let trangThai: String?
    public let moTaTrangThai: String?
    enum CodingKeys: String, CodingKey {
        case so, ten, nhom, nguon
        case tenEn = "ten_en", nhanBiet = "nhan_biet", tieuChiSo = "tieu_chi_so"
        case dacDiem = "dac_diem", hanhTinhDacBiet = "hanh_tinh_dac_biet"
        case trangThai = "trang_thai", moTaTrangThai = "mo_ta_trang_thai"
    }
}

public struct VaultChartShapesFile: Codable, Sendable {
    public let moTa: String
    public let nguonChinh: StringOrList
    public let ghiChuThuatToan: String?
    public let soBanGhi: Int
    public let duLieu: [VaultChartShape]
    enum CodingKeys: String, CodingKey {
        case moTa = "mo_ta", nguonChinh = "nguon_chinh"
        case ghiChuThuatToan = "ghi_chu_thuat_toan", soBanGhi = "so_ban_ghi", duLieu = "du_lieu"
    }
}

// MARK: - 7. nguyen-to-tinh-chat.json (4 nguyên tố + 3 tính chất) ------------

public struct VaultElement: Codable, Hashable, Sendable {
    public let loai: String
    public let ten: String
    public let mucTieu: [String]?
    public let cachSong: [String]?
    public let dacDiem: [String]
    public let nguon: String?
    enum CodingKeys: String, CodingKey {
        case loai, ten, nguon
        case mucTieu = "muc_tieu", cachSong = "cach_song", dacDiem = "dac_diem"
    }
}

public struct VaultElementsFile: Codable, Sendable {
    public let moTa: String
    public let nguonChinh: StringOrList
    public let ghiChu: String?
    public let soBanGhi: Int
    public let nguyenTo: [VaultElement]
    public let tinhChat: [VaultElement]
    enum CodingKeys: String, CodingKey {
        case moTa = "mo_ta", nguonChinh = "nguon_chinh", ghiChu = "ghi_chu"
        case soBanGhi = "so_ban_ghi", nguyenTo = "nguyen_to", tinhChat = "tinh_chat"
    }
}

// MARK: - 8. ngoai-hinh.json -------------------------------------------------

public struct VaultAppearanceRow: Codable, Hashable, Sendable {
    public let cung: String?
    public let hanhTinh: String?
    public let dacDiem: String
    public let nguon: String?
    enum CodingKeys: String, CodingKey {
        case cung, nguon
        case hanhTinh = "hanh_tinh", dacDiem = "dac_diem"
    }
}

public struct VaultAppearanceFile: Codable, Sendable {
    public let moTa: String
    public let nguonChinh: StringOrList
    public let quyTrinhLuanNgoaiHinh: JSONValue?
    public let theoCungAC: [VaultAppearanceRow]
    public let theoHanhTinh: [VaultAppearanceRow]
    public let ghiChu: String?
    enum CodingKeys: String, CodingKey {
        case moTa = "mo_ta", nguonChinh = "nguon_chinh"
        case quyTrinhLuanNgoaiHinh = "quy_trinh_luan_ngoai_hinh"
        case theoCungAC = "theo_cung_AC", theoHanhTinh = "theo_hanh_tinh"
        case ghiChu = "ghi_chu"
    }
}

// MARK: - 9. luong-nguyen.json (6 trục đối đỉnh) -----------------------------

public struct VaultPolarityAxis: Codable, Hashable, Sendable {
    public let truc: String
    public let cung: String
    public let vietTat: String
    public let nha: String
    public let nhuCau: String
    public let dacDiemChung: [String]
    public let viDuHuongVaoRa: String?
    public let viDuBoTuc03: String?
    enum CodingKeys: String, CodingKey {
        case truc, cung, nha
        case vietTat = "viet_tat", nhuCau = "nhu_cau"
        case dacDiemChung = "dac_diem_chung"
        case viDuHuongVaoRa = "vi_du_huong_vao_ra"
        case viDuBoTuc03 = "vi_du_bo_tuc_03"
    }
}

public struct VaultPolarityFile: Codable, Sendable {
    public let moTa: String
    public let nguonChinh: StringOrList
    public let baQuyLuat: [JSONValue]
    public let soBanGhi: Int
    public let sauTrucDoiDinh: [VaultPolarityAxis]
    public let quyTacNuaTrenNuaDuoi: String?
    public let ungDung: [JSONValue]?
    enum CodingKeys: String, CodingKey {
        case moTa = "mo_ta", nguonChinh = "nguon_chinh"
        case baQuyLuat = "ba_quy_luat", soBanGhi = "so_ban_ghi"
        case sauTrucDoiDinh = "sau_truc_doi_dinh"
        case quyTacNuaTrenNuaDuoi = "quy_tac_nua_tren_nua_duoi"
        case ungDung = "ung_dung"
    }
}

// MARK: - 10. diem-tam-linh.json ---------------------------------------------

public struct VaultSpiritualPoint: Codable, Hashable, Sendable {
    public let ten: String
    public let tenKhac: JSONValue?
    public let chuDe: JSONValue?
    public let moTa: JSONValue?
    public let trongSynastry: JSONValue?
    public let cachCheckSynastry: JSONValue?
    public let nguon: String?
    enum CodingKeys: String, CodingKey {
        case ten, nguon
        case tenKhac = "ten_khac", chuDe = "chu_de", moTa = "mo_ta"
        case trongSynastry = "trong_synastry", cachCheckSynastry = "cach_check_synastry"
    }
}

public struct VaultSpiritualFile: Codable, Sendable {
    public let moTa: String
    public let nguonChinh: StringOrList
    public let disclaimer: String?
    public let luatChung: [String]
    public let orb: JSONValue?
    public let soBanGhi: Int
    public let duLieu: [VaultSpiritualPoint]
    public let diemLienQuanKhac: JSONValue?
    enum CodingKeys: String, CodingKey {
        case moTa = "mo_ta", nguonChinh = "nguon_chinh", disclaimer
        case luatChung = "luat_chung", orb, soBanGhi = "so_ban_ghi", duLieu = "du_lieu"
        case diemLienQuanKhac = "diem_lien_quan_khac"
    }
}

// MARK: - 11. goc-hop.json ---------------------------------------------------

public struct VaultAspectExample: Codable, Hashable, Sendable {
    public let cap: String
    public let chieu: JSONValue?
    public let y: JSONValue?
    public let nguon: String?
}

public struct VaultAspectTypeNote: Codable, Hashable, Sendable {
    public let loai: String
    public let dienGiai: JSONValue?
    public let nguon: String?
    enum CodingKeys: String, CodingKey { case loai, nguon, dienGiai = "dien_giai" }
}

public struct VaultAspectsFile: Codable, Sendable {
    public let moTa: String
    public let nguonChinh: StringOrList
    public let banChatGocHop: [String]
    public let quyTrinh2Buoc: [JSONValue]
    public let bangSoSanhMemCungTrung: JSONValue?
    public let dienGiaiBaLoaiGoc: [VaultAspectTypeNote]
    public let luuYQuanTrong: [String]
    public let viDuLeTuBuoiHoc2: [VaultAspectExample]
    public let ungDungXacDinhNangKhieu: JSONValue?
    enum CodingKeys: String, CodingKey {
        case moTa = "mo_ta", nguonChinh = "nguon_chinh"
        case banChatGocHop = "ban_chat_goc_hop"
        case quyTrinh2Buoc = "quy_trinh_2_buoc"
        case bangSoSanhMemCungTrung = "bang_so_sanh_mem_cung_trung"
        case dienGiaiBaLoaiGoc = "dien_giai_ba_loai_goc"
        case luuYQuanTrong = "luu_y_quan_trong"
        case viDuLeTuBuoiHoc2 = "vi_du_le_tu_buoi_hoc_2"
        case ungDungXacDinhNangKhieu = "ung_dung_xac_dinh_nang_khieu"
    }
}

// MARK: - 12. synastry.json --------------------------------------------------

public struct VaultSynastryPair: Codable, Hashable, Sendable {
    public let cap: String
    public let luan: JSONValue
    public let nguon: String?
}

public struct VaultSynastryFile: Codable, Sendable {
    public let moTa: String
    public let nguonChinh: StringOrList
    public let congCu: [String]
    public let orbSynastry: String?
    public let quyTrinh: [JSONValue]
    public let chiaKhoaHanhPhuc: [JSONValue]
    public let maTranKyHieu: JSONValue?
    public let capCaNhanXCaNhan: [VaultSynastryPair]
    public let capCaNhanXVongNgoai: [VaultSynastryPair]
    public let soBanGhi: JSONValue?
    enum CodingKeys: String, CodingKey {
        case moTa = "mo_ta", nguonChinh = "nguon_chinh", congCu = "cong_cu"
        case orbSynastry = "orb_synastry", quyTrinh = "quy_trinh"
        case chiaKhoaHanhPhuc = "chia_khoa_hanh_phuc"
        case maTranKyHieu = "ma_tran_ky_hieu"
        case capCaNhanXCaNhan = "luan_hanh_tinh_ca_nhan_x_ca_nhan"
        case capCaNhanXVongNgoai = "luan_hanh_tinh_ca_nhan_x_vong_ngoai"
        case soBanGhi = "so_ban_ghi"
    }
}

// MARK: - 13. transit.json ---------------------------------------------------

public struct VaultTransitFile: Codable, Sendable {
    public let moTa: String
    public let nguonChinh: StringOrList
    public let quyTacChung: String
    public let quanDiemDuBao: [String]
    public let hanChung: JSONValue
    public let hanRieng: JSONValue
    public let bangChuKyHoiVi: VaultTransitTable
    public let mocDaiHanDoiNguoi: VaultTransitTable
    public let timingVaPlanning: JSONValue?
    public let solarReturn: JSONValue?
    public let congCu: [String]?
    enum CodingKeys: String, CodingKey {
        case moTa = "mo_ta", nguonChinh = "nguon_chinh"
        case quyTacChung = "quy_tac_chung", quanDiemDuBao = "quan_diem_du_bao"
        case hanChung = "han_chung", hanRieng = "han_rieng"
        case bangChuKyHoiVi = "bang_chu_ky_hoi_vi"
        case mocDaiHanDoiNguoi = "moc_dai_han_doi_nguoi"
        case timingVaPlanning = "timing_va_planning"
        case solarReturn = "solar_return"
        case congCu = "cong_cu"
    }
}

/// Bảng con dùng chung trong `transit.json` (`bang_chu_ky_hoi_vi`, `moc_dai_han_doi_nguoi`).
public struct VaultTransitTable: Codable, Sendable {
    public let moTa: String?
    public let soBanGhi: Int
    public let bang: [JSONValue]
    public let nguon: String?
    enum CodingKeys: String, CodingKey {
        case moTa = "mo_ta", soBanGhi = "so_ban_ghi", bang, nguon
    }
}

// MARK: - 14. nghe-nghiep.json -----------------------------------------------

public struct VaultCareerMatrixRow: Codable, Hashable, Identifiable, Sendable {
    public var id: Int { so }
    public let so: Int
    public let cung: String
    public let nha: String
    public let hanhTinh: String
    public let tinhChat: String
    public let nghe: [String]
    public let nguon: String?
    enum CodingKeys: String, CodingKey {
        case so, cung, nha, nghe, nguon
        case hanhTinh = "hanh_tinh", tinhChat = "tinh_chat"
    }
}

public struct VaultCareerCombo: Codable, Hashable, Sendable {
    public let boSo: String
    public let yNghiaBoSo: String
    public let capNha: String?
    public let nha1: Int
    public let nha2: Int?
    public let nghe: [String]
    public let ngheNguyenVan: String?
    public let nguon: String?
    enum CodingKeys: String, CodingKey {
        case nghe, nguon
        case boSo = "bo_so", yNghiaBoSo = "y_nghia_bo_so", capNha = "cap_nha"
        case nha1 = "nha_1", nha2 = "nha_2", ngheNguyenVan = "nghe_nguyen_van"
    }
}

public struct VaultCareerFile: Codable, Sendable {
    public let moTa: String
    public let nguonChinh: StringOrList
    public let thangDiem: JSONValue?
    public let soBanGhi: JSONValue?
    public let quyTrinh: [JSONValue]
    public let maTranNghe: [VaultCareerMatrixRow]
    public let comboBoSo: [VaultCareerCombo]
    public let noiThemVeTienBac: JSONValue?
    enum CodingKeys: String, CodingKey {
        case moTa = "mo_ta", nguonChinh = "nguon_chinh"
        case thangDiem = "thang_diem", soBanGhi = "so_ban_ghi"
        case quyTrinh = "quy_trinh"
        case maTranNghe = "ma_tran_nghe_theo_cung_nha_hanh_tinh"
        case comboBoSo = "combo_bo_so"
        case noiThemVeTienBac = "noi_them_ve_tien_bac"
    }
}
