//  JSONValue.swift
//  Kiểu JSON tổng quát, KHÔNG MẤT DỮ LIỆU — dùng cho những nhánh trong vault có hình
//  dạng bất quy tắc (dict lồng dict, list lẫn kiểu). Nhờ nó mà mọi file trong
//  `Resources/Data/text/` đều decode được 100% mà không phải bịa struct cho từng nhánh.
//
//  Quy ước đặt tên khoá: giữ NGUYÊN tên tiếng Việt không dấu của vault (mo_ta, du_lieu…)
//  để đối chiếu 1-1 với file JSON gốc.

import Foundation

public enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case integer(Int)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int.self) { self = .integer(v); return }
        if let v = try? c.decode(Double.self) { self = .number(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([JSONValue].self) { self = .array(v); return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Giá trị JSON lạ")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v):  try c.encode(v)
        case .number(let v):  try c.encode(v)
        case .integer(let v): try c.encode(v)
        case .bool(let v):    try c.encode(v)
        case .array(let v):   try c.encode(v)
        case .object(let v):  try c.encode(v)
        case .null:           try c.encodeNil()
        }
    }

    // MARK: - Truy cập tiện lợi

    public subscript(key: String) -> JSONValue? {
        if case .object(let o) = self { return o[key] }
        return nil
    }
    public subscript(index: Int) -> JSONValue? {
        if case .array(let a) = self, index >= 0, index < a.count { return a[index] }
        return nil
    }
    public var stringValue: String? {
        switch self {
        case .string(let v):  return v
        case .integer(let v): return String(v)
        case .number(let v):  return String(v)
        case .bool(let v):    return String(v)
        default: return nil
        }
    }
    public var intValue: Int? {
        switch self {
        case .integer(let v): return v
        case .number(let v):  return Int(v)
        case .string(let v):  return Int(v)
        default: return nil
        }
    }
    public var arrayValue: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    public var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }

    /// Gom mọi chuỗi con (đệ quy) — dùng cho tìm kiếm toàn văn trong vault.
    public var allStrings: [String] {
        switch self {
        case .string(let v): return [v]
        case .array(let a):  return a.flatMap { $0.allStrings }
        case .object(let o): return o.values.flatMap { $0.allStrings }
        default: return []
        }
    }

    /// Đếm số phần tử "bản ghi" — mảng thì đếm phần tử, còn lại tính 1.
    public var recordCount: Int {
        if case .array(let a) = self { return a.count }
        if case .null = self { return 0 }
        return 1
    }
}
