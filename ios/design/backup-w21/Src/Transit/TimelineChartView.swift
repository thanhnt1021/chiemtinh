//  TimelineChartView.swift
//  Vẽ "BIỂU ĐỒ CHU KỲ VẬN HẠN CHI TIẾT" bằng SwiftUI `Canvas`
//  — thay ảnh PNG matplotlib của web (`app/utils/drawing/timeline.py:200-297`).
//
//  GIỮ ĐỦ MỌI THÔNG TIN web hiển thị:
//    • trục thời gian ngang + vạch mốc ngày 1 mỗi tháng (ngày/tháng + năm)
//    • mỗi dòng 1 dải: vạch bắt đầu (xanh lá = vào nhà, xám = tạo góc), mũi tên tới cuối
//    • nhãn ngày bắt đầu / kết thúc (chỉ khi KHÔNG bị cắt), đường dóng xuống trục
//    • mốc "E" (góc chính xác) màu đỏ + đường dóng, kể cả E rơi ngoài rìa (đầu/cuối)
//    • nhãn "NHÀ n" ngăn nhóm
//  KHÁC web: nhãn nằm ở cột trái cố định thay vì bám mép dải — để đọc được trên màn hình dọc.

import SwiftUI

public struct TimelineChartView: View {
    public let data: TimelineData
    /// Bề rộng vùng vẽ dải (không tính cột nhãn). Cho cuộn ngang khi quá hẹp.
    public var plotWidth: CGFloat = 720

    private let gutter: CGFloat = 86
    private let rowH: CGFloat = 30
    private let sepH: CGFloat = 26
    private let axisH: CGFloat = 52
    private let padTop: CGFloat = 12

    public init(data: TimelineData, plotWidth: CGFloat = 720) {
        self.data = data
        self.plotWidth = plotWidth
    }

    private var contentHeight: CGFloat {
        padTop + axisH + data.rows.reduce(0) { $0 + ($1.kind == .separator ? sepH : rowH) } + 16
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Canvas { ctx, size in draw(ctx: ctx, size: size) }
                .frame(width: gutter + plotWidth + 28, height: contentHeight)
                .padding(.vertical, Theme.Space.sm)
        }
        .background(Theme.Colors.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }

    // MARK: - Vẽ

    private func px(_ v: Double) -> CGFloat { gutter + CGFloat(min(max(v, 0), 1.06)) * plotWidth }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let axisY = padTop + axisH * 0.72

        // ----- Trục thời gian -----
        var axis = Path()
        axis.move(to: CGPoint(x: gutter, y: axisY))
        axis.addLine(to: CGPoint(x: gutter + plotWidth + 12, y: axisY))
        ctx.stroke(axis, with: .color(Theme.Colors.textPrimary), lineWidth: 2)
        // mũi tên
        var head = Path()
        head.move(to: CGPoint(x: gutter + plotWidth + 20, y: axisY))
        head.addLine(to: CGPoint(x: gutter + plotWidth + 12, y: axisY - 4))
        head.addLine(to: CGPoint(x: gutter + plotWidth + 12, y: axisY + 4))
        head.closeSubpath()
        ctx.fill(head, with: .color(Theme.Colors.textPrimary))

        // ----- Vạch mốc ngày 1 mỗi tháng (timeline.py:228-241) -----
        var cur = CivilDateTime(year: data.start.year, month: data.start.month, day: 1)
        if cur < data.start { cur = nextMonth(cur) }
        while cur <= data.end {
            let x = px(data.x(cur))
            var tick = Path()
            tick.move(to: CGPoint(x: x, y: axisY - 5))
            tick.addLine(to: CGPoint(x: x, y: axisY + 5))
            ctx.stroke(tick, with: .color(Theme.Colors.textSecondary), lineWidth: 1.4)
            ctx.draw(Text("\(cur.day)/\(cur.month)").font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textPrimary),
                     at: CGPoint(x: x, y: axisY + 14), anchor: .center)
            ctx.draw(Text(String(cur.year)).font(Theme.Fonts.numericSmall)
                        .foregroundColor(Theme.Colors.textMuted),
                     at: CGPoint(x: x, y: axisY + 28), anchor: .center)
            cur = nextMonth(cur)
        }

        // ----- Các dòng -----
        var y = padTop + axisH
        for row in data.rows {
            if row.kind == .separator {
                ctx.draw(Text(row.label).font(Theme.Fonts.caps)
                            .foregroundColor(Theme.Colors.accent),
                         at: CGPoint(x: 8, y: y + sepH / 2), anchor: .leading)
                var line = Path()
                line.move(to: CGPoint(x: gutter, y: y + sepH / 2))
                line.addLine(to: CGPoint(x: gutter + plotWidth, y: y + sepH / 2))
                ctx.stroke(line, with: .color(Theme.Colors.separator), lineWidth: 1)
                y += sepH
                continue
            }

            let cy = y + rowH / 2
            ctx.draw(Text(row.label).font(.system(size: 17))
                        .foregroundColor(Theme.Colors.textPrimary),
                     at: CGPoint(x: gutter - 8, y: cy), anchor: .trailing)

            for p in row.periods {
                let x1 = p.isClampedStart ? px(0) : px(data.x(p.start))
                let x2 = p.isClampedEnd ? px(1.04) : px(data.x(p.end))

                // dải đứt nét + mũi tên
                var bar = Path()
                bar.move(to: CGPoint(x: x1, y: cy))
                bar.addLine(to: CGPoint(x: x2, y: cy))
                ctx.stroke(bar, with: .color(Theme.Colors.textMuted),
                           style: StrokeStyle(lineWidth: 1.4, dash: [4, 3]))
                var arrow = Path()
                arrow.move(to: CGPoint(x: x2, y: cy))
                arrow.addLine(to: CGPoint(x: x2 - 6, y: cy - 3.5))
                arrow.addLine(to: CGPoint(x: x2 - 6, y: cy + 3.5))
                arrow.closeSubpath()
                ctx.fill(arrow, with: .color(Theme.Colors.textMuted))

                // vạch đứng đánh dấu bắt đầu (timeline.py:266-270)
                let barColor: Color = (row.kind == .houseEntry)
                    ? Theme.Colors.success : Theme.Colors.textSecondary
                var mark = Path()
                mark.move(to: CGPoint(x: x1, y: cy - 7))
                mark.addLine(to: CGPoint(x: x1, y: cy + 7))
                ctx.stroke(mark, with: .color(barColor), lineWidth: 3.5)

                if !p.isClampedStart { dropLine(ctx, x: x1, from: axisY, to: cy,
                                                color: Theme.Colors.aspectSoft, label: dm(p.start)) }
                if !p.isClampedEnd { dropLine(ctx, x: x2, from: axisY, to: cy,
                                              color: Theme.Colors.aspectSoft, label: dm(p.end)) }

                // mốc E (góc chính xác)
                for ex in p.exacts {
                    let xe = px(data.x(ex))
                    dropLine(ctx, x: xe, from: axisY, to: cy,
                             color: Theme.Colors.danger, label: dm(ex))
                    ctx.draw(Text("E").font(Theme.Fonts.caps)
                                .foregroundColor(Theme.Colors.danger),
                             at: CGPoint(x: xe, y: cy - 10), anchor: .center)
                }
                if p.hasEarlyE && p.isClampedStart {
                    ctx.draw(Text("E").font(Theme.Fonts.caps).foregroundColor(Theme.Colors.danger),
                             at: CGPoint(x: px(0) + 4, y: cy - 10), anchor: .leading)
                }
                if p.hasLateE && p.isClampedEnd {
                    ctx.draw(Text("E").font(Theme.Fonts.caps).foregroundColor(Theme.Colors.danger),
                             at: CGPoint(x: px(1.04) + 2, y: cy - 10), anchor: .leading)
                }
            }
            y += rowH
        }
    }

    private func dropLine(_ ctx: GraphicsContext, x: CGFloat, from: CGFloat, to: CGFloat,
                          color: Color, label: String) {
        var p = Path()
        p.move(to: CGPoint(x: x, y: from))
        p.addLine(to: CGPoint(x: x, y: to))
        ctx.stroke(p, with: .color(color.opacity(0.45)),
                   style: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
        ctx.draw(Text(label).font(Theme.Fonts.numericSmall).foregroundColor(color),
                 at: CGPoint(x: x, y: from - 10), anchor: .center)
    }

    private func dm(_ d: CivilDateTime) -> String { "\(d.day)/\(d.month)" }

    private func nextMonth(_ d: CivilDateTime) -> CivilDateTime {
        d.month == 12 ? CivilDateTime(year: d.year + 1, month: 1, day: 1)
                      : CivilDateTime(year: d.year, month: d.month + 1, day: 1)
    }
}
