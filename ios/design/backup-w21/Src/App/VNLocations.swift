//  VNLocations.swift
//  Danh sách địa điểm tạm thời (lượt sau sẽ thay bằng tìm kiếm địa danh).
//  Toạ độ lấy tròn 4 chữ số thập phân.

import Foundation

public struct PlaceOption: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let lat: Double
    public let lon: Double
    public let tz: String
}

public enum VNLocations {
    public static let all: [PlaceOption] = [
        PlaceOption(id: "hanoi",    name: "Hà Nội",              lat: 21.0285, lon: 105.8542, tz: "Asia/Ho_Chi_Minh"),
        PlaceOption(id: "haiphong", name: "Hải Phòng",           lat: 20.8449, lon: 106.6881, tz: "Asia/Ho_Chi_Minh"),
        PlaceOption(id: "vinh",     name: "Vinh (Nghệ An)",      lat: 18.6733, lon: 105.6922, tz: "Asia/Ho_Chi_Minh"),
        PlaceOption(id: "hue",      name: "Huế",                 lat: 16.4637, lon: 107.5909, tz: "Asia/Ho_Chi_Minh"),
        PlaceOption(id: "danang",   name: "Đà Nẵng",             lat: 16.0544, lon: 108.2022, tz: "Asia/Ho_Chi_Minh"),
        PlaceOption(id: "quynhon",  name: "Quy Nhơn",            lat: 13.7829, lon: 109.2196, tz: "Asia/Ho_Chi_Minh"),
        PlaceOption(id: "bmt",      name: "Buôn Ma Thuột",       lat: 12.6667, lon: 108.0500, tz: "Asia/Ho_Chi_Minh"),
        PlaceOption(id: "nhatrang", name: "Nha Trang",           lat: 12.2388, lon: 109.1967, tz: "Asia/Ho_Chi_Minh"),
        PlaceOption(id: "dalat",    name: "Đà Lạt",              lat: 11.9404, lon: 108.4583, tz: "Asia/Ho_Chi_Minh"),
        PlaceOption(id: "hcm",      name: "TP. Hồ Chí Minh",     lat: 10.7769, lon: 106.7009, tz: "Asia/Ho_Chi_Minh"),
        PlaceOption(id: "cantho",   name: "Cần Thơ",             lat: 10.0452, lon: 105.7469, tz: "Asia/Ho_Chi_Minh"),
        PlaceOption(id: "camau",    name: "Cà Mau",              lat: 9.1769,  lon: 105.1524, tz: "Asia/Ho_Chi_Minh")
    ]
}
