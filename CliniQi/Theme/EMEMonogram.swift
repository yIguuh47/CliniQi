//
//  EMEMonogram.swift
//  CliniQi
//

import SwiftUI

struct EMEMonogram: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addPath(stroke(in: rect, offset: 0.02))
        path.addPath(stroke(in: rect, offset: 0.34))
        return path
    }

    private func stroke(in rect: CGRect, offset: CGFloat) -> Path {
        let w = rect.width
        let h = rect.height
        let x = offset * w

        var path = Path()
        path.move(to: CGPoint(x: x + w * 0.16, y: h * 0.90))
        path.addCurve(
            to: CGPoint(x: x + w * 0.18, y: h * 0.10),
            control1: CGPoint(x: x - w * 0.08, y: h * 0.64),
            control2: CGPoint(x: x + w * 0.40, y: h * 0.36)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.38, y: h * 0.88),
            control1: CGPoint(x: x - w * 0.04, y: h * -0.04),
            control2: CGPoint(x: x + w * 0.50, y: h * 0.52)
        )
        return path
    }
}

struct EMELogoMark: View {
    var size: CGFloat = 28
    var inverted: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(inverted ? EMEBrand.paper : EMEBrand.taupe)

            EMEMonogram()
                .stroke(
                    inverted ? EMEBrand.taupe : EMEBrand.paper,
                    style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round, lineJoin: .round)
                )
                .padding(size * 0.22)
        }
        .frame(width: size, height: size)
    }
}

struct EMEWatermark: View {
    var body: some View {
        EMEMonogram()
            .stroke(
                EMEBrand.watermark,
                style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 168, height: 176)
            .opacity(0.7)
    }
}
