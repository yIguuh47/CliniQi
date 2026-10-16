//
//  EMEBrandPageView.swift
//  CliniQi
//

import SwiftUI

struct EMEBrandPageView: View {
    var body: some View {
        ZStack {
            EMEBrand.sand

            VStack(spacing: 0) {
                Spacer(minLength: 72)

                VStack(spacing: 4) {
                    Text("e m e")
                        .font(EMEBrand.script(46))
                        .foregroundStyle(EMEBrand.ink)

                    Text("concept")
                        .font(EMEBrand.sans(11, weight: .regular))
                        .tracking(6)
                        .foregroundStyle(EMEBrand.ink)
                }

                Spacer(minLength: 48)

                EMEMonogram()
                    .stroke(
                        EMEBrand.cream,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 168, height: 186)

                Spacer(minLength: 56)

                footer

                Spacer(minLength: 64)
            }
            .padding(.horizontal, 48)
        }
        .frame(width: PDFPageMetrics.a4.width, height: PDFPageMetrics.a4.height)
        .environment(\.colorScheme, .light)
    }

    private var footer: some View {
        VStack(spacing: 22) {
            Text("movimento entre")
                .font(EMEBrand.script(28))
                .foregroundStyle(EMEBrand.taupe)

            HStack(alignment: .center, spacing: 18) {
                motto(top: "traço da", bottom: "essência")

                Text("&")
                    .font(EMEBrand.didot(54))
                    .foregroundStyle(EMEBrand.taupe.opacity(0.45))
                    .offset(y: 4)

                motto(top: "curva da", bottom: "expressão")
            }
        }
    }

    private func motto(top: String, bottom: String) -> some View {
        VStack(spacing: 2) {
            Text(top)
                .font(EMEBrand.script(13))
                .foregroundStyle(EMEBrand.paper)

            Text(bottom)
                .font(EMEBrand.script(26, bold: true))
                .foregroundStyle(EMEBrand.ink)
        }
        .frame(minWidth: 120)
    }
}

#Preview("Marca") {
    EMEBrandPageView()
}
