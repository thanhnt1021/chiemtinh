//  ChartInteraction.swift
//  KHUNG TƯƠNG TÁC: phóng to / kéo / chạm cho mọi biểu đồ tròn.
//
//  Khác bản web (ảnh PNG tĩnh): ở đây zoom KHÔNG phóng ảnh raster mà đổi `unit`
//  của `WheelTransform` rồi vẽ lại vector -> nét luôn sắc ở mọi mức phóng.

import SwiftUI

/// Trạng thái khung nhìn dùng chung cho canvas + bắt chạm.
public struct ChartViewport {
    public var scale: CGFloat = 1
    public var offset: CGSize = .zero
    public static let minScale: CGFloat = 1.0
    public static let maxScale: CGFloat = 6.0
}

/// Bọc một canvas vẽ vector, cấp sẵn cử chỉ phóng to (pinch), kéo (drag),
/// chạm (tap) và chạm đúp để đặt lại. Có giới hạn + bật lại (snap-back).
public struct ZoomPanChart<Content: View>: View {
    @State private var steadyScale: CGFloat = 1
    @GestureState private var gestureScale: CGFloat = 1
    @State private var steadyOffset: CGSize = .zero
    @GestureState private var gestureOffset: CGSize = .zero

    private let content: (CGSize, ChartViewport) -> Content
    private let onTap: (CGPoint, CGSize, ChartViewport) -> Void

    public init(@ViewBuilder content: @escaping (CGSize, ChartViewport) -> Content,
                onTap: @escaping (CGPoint, CGSize, ChartViewport) -> Void = { _, _, _ in }) {
        self.content = content
        self.onTap = onTap
    }

    private var viewport: ChartViewport {
        ChartViewport(scale: steadyScale * gestureScale,
                      offset: CGSize(width: steadyOffset.width + gestureOffset.width,
                                     height: steadyOffset.height + gestureOffset.height))
    }

    /// Giới hạn kéo: tâm biểu đồ không được rời quá nửa khung ở mức phóng hiện tại.
    private func clamp(_ o: CGSize, size: CGSize, scale: CGFloat) -> CGSize {
        let limX = max(0, (scale - 1) * size.width / 2 + 24)
        let limY = max(0, (scale - 1) * size.height / 2 + 24)
        return CGSize(width: min(max(o.width, -limX), limX),
                      height: min(max(o.height, -limY), limY))
    }

    public var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let vp = ChartViewport(scale: min(max(viewport.scale, 0.6), ChartViewport.maxScale),
                                   offset: clamp(viewport.offset, size: size, scale: viewport.scale))
            content(size, vp)
                .contentShape(Rectangle())
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .updating($gestureScale) { v, s, _ in s = v }
                            .onEnded { v in
                                var s = steadyScale * v
                                // Bật lại về mức tối thiểu / tối đa nếu vượt biên.
                                s = min(max(s, ChartViewport.minScale), ChartViewport.maxScale)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    steadyScale = s
                                    steadyOffset = clamp(steadyOffset, size: size, scale: s)
                                }
                            },
                        DragGesture()
                            .updating($gestureOffset) { v, s, _ in s = v.translation }
                            .onEnded { v in
                                let raw = CGSize(width: steadyOffset.width + v.translation.width,
                                                 height: steadyOffset.height + v.translation.height)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    steadyOffset = clamp(raw, size: size, scale: steadyScale)
                                }
                            }
                    )
                )
                .simultaneousGesture(
                    SpatialTapGesture(count: 1).onEnded { v in onTap(v.location, size, vp) }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        if steadyScale > 1.05 { steadyScale = 1; steadyOffset = .zero }
                        else { steadyScale = 2.2 }
                    }
                }
        }
    }
}

// MARK: - Bắt chạm hành tinh

public enum ChartHitTest {
    /// Bán kính vùng chạm: 22 pt -> đường kính 44 pt đúng khuyến nghị HIG,
    /// dù ký hiệu vẽ ra chỉ ~14–20 pt.
    public static let touchRadius: CGFloat = 22
    /// Vòng nới lỏng lần 2 khi không có gì trong 22 pt.
    public static let fallbackRadius: CGFloat = 44

    /// Danh sách hành tinh nằm trong vùng chạm, gần nhất trước.
    ///
    /// Ở mức thu nhỏ nhất, 2 ký hiệu cùng lane chỉ cách nhau `MIN_DIST` = 5°
    /// (≈10 pt trên iPhone 6.1"), nên KHÔNG thể có 44 pt riêng cho từng ký hiệu.
    /// Cách xử lý: vùng chạm 44 pt vẫn giữ nguyên, nhưng trả về CẢ CỤM để giao diện
    /// cho người dùng chọn tiếp (chạm lại để xoay vòng, hoặc bấm chip tên).
    public static func candidates(at p: CGPoint,
                                  placements: [PlacedPlanet],
                                  transform: WheelTransform,
                                  limit: Int = 4) -> [String] {
        let scored = placements.map { pl -> (String, CGFloat) in
            let c = transform.point(lon: pl.dispLon, r: pl.dispR)
            return (pl.name, hypot(c.x - p.x, c.y - p.y))
        }
        .filter { $0.1 <= fallbackRadius }
        .sorted { $0.1 < $1.1 }
        return Array(scored.prefix(limit).map { $0.0 })
    }

    /// Trả về tên hành tinh gần điểm chạm nhất (nil nếu chạm vào chỗ trống).
    public static func planet(at p: CGPoint,
                              placements: [PlacedPlanet],
                              transform: WheelTransform) -> String? {
        candidates(at: p, placements: placements, transform: transform, limit: 1).first
    }

    /// Chạm lại vào cùng một cụm -> chuyển sang hành tinh kế tiếp trong cụm.
    public static func next(after current: String?, in cluster: [String]) -> String? {
        guard !cluster.isEmpty else { return nil }
        guard let c = current, let i = cluster.firstIndex(of: c) else { return cluster[0] }
        return cluster[(i + 1) % cluster.count]
    }
}
