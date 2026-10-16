//
//  OrcamentoPageView.swift
//  CliniQi
//

import SwiftUI

struct OrcamentoPageView: View {
    let nomePaciente: String
    let mesAno: String
    let plano: PlanoTratamento
    var pageIndex: Int = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            TemplatePageBackground(pageIndex: pageIndex)
            OrcamentoDataOverlay(
                nomePaciente: nomePaciente,
                mesAno: mesAno,
                plano: plano,
                isPlanoA: pageIndex == 0
            )
        }
        .frame(width: EMETemplate.pageSize.width, height: EMETemplate.pageSize.height)
        .environment(\.colorScheme, .light)
    }
}

struct OrcamentoDataOverlay: View {
    let nomePaciente: String
    let mesAno: String
    let plano: PlanoTratamento
    let isPlanoA: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            chipText(nomePaciente, in: OverlayLayout.nameChip)
            chipText(mesAno, in: OverlayLayout.dateChip)

            subtitleText
                .frame(width: OverlayLayout.subtitle.width, alignment: .leading)
                .offset(x: OverlayLayout.subtitle.minX, y: OverlayLayout.subtitle.minY)

            // Valores fluem abaixo dos procedimentos: mantêm a posição do template
            // e só descem quando a lista de procedimentos ultrapassa esse espaço.
            VStack(alignment: .leading, spacing: 0) {
                proceduresBlock
                    .frame(width: proceduresRect.width, alignment: .leading)
                    .frame(
                        minHeight: financialRect.minY - proceduresRect.minY - 20,
                        alignment: .topLeading
                    )

                connector
                    .padding(.leading, connectorRect.minX - proceduresRect.minX)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                financialBlock
                    .frame(width: financialRect.width, alignment: .leading)
                    .padding(.leading, financialRect.minX - proceduresRect.minX)
            }
            .offset(x: proceduresRect.minX, y: proceduresRect.minY)

            focusText
                .frame(width: focusRect.width, height: focusRect.height, alignment: .center)
                .offset(x: focusRect.minX, y: focusRect.minY)
        }
        .frame(width: OverlayLayout.page.width, height: OverlayLayout.page.height)
        .background(Color.clear)
    }

    private var proceduresRect: CGRect {
        isPlanoA ? OverlayLayout.proceduresA : OverlayLayout.proceduresB
    }

    private var financialRect: CGRect {
        isPlanoA ? OverlayLayout.financialA : OverlayLayout.financialB
    }

    private var connectorRect: CGRect {
        OverlayLayout.templateConnector(pageIndex: isPlanoA ? 0 : 1) ?? OverlayLayout.connectorA
    }

    /// Linha com bolinha que aponta para os valores, sempre logo acima deles.
    private var connector: some View {
        HStack(spacing: 0) {
            Rectangle()
                .frame(width: connectorRect.width - 2, height: 0.6)
            Circle()
                .frame(width: 2, height: 2)
        }
        .foregroundStyle(EMETemplate.connectorColor)
        .frame(height: 2)
    }

    private var focusRect: CGRect {
        isPlanoA ? OverlayLayout.focusA : OverlayLayout.focusB
    }

    private func chipText(_ text: String, in rect: CGRect) -> some View {
        Text(text)
            .font(EMEBrand.sans(10, weight: .medium))
            .foregroundStyle(EMEBrand.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: rect.width, height: rect.height, alignment: .leading)
            .offset(x: rect.minX, y: rect.minY)
    }

    private var subtitleText: some View {
        Text(plano.subtitulo)
            .font(EMEBrand.sans(10, weight: .italic))
            .foregroundStyle(EMEBrand.taupe)
            .lineSpacing(1.5)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var proceduresBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(plano.procedimentosVisiveis.enumerated()), id: \.offset) { _, raw in
                let item = ProcedimentoDisplay(raw: raw)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.titulo)
                        .font(EMEBrand.sans(9, weight: .demiBold))
                        .foregroundStyle(EMEBrand.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    if let detalhe = item.detalhe {
                        Text(detalhe)
                            .font(EMEBrand.sans(8.5, weight: .italic))
                            .foregroundStyle(EMEBrand.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var financialBlock: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(plano.parcelaFormatada)
                .font(EMEBrand.sans(12, weight: .bold))
                .foregroundStyle(EMEBrand.ink)

            Text("ou")
                .font(EMEBrand.sans(10, weight: .regular))
                .foregroundStyle(EMEBrand.ink)

            Text(plano.pixFormatado)
                .font(EMEBrand.sans(12, weight: .bold))
                .foregroundStyle(EMEBrand.ink)
        }
    }

    private var focusText: some View {
        VStack(spacing: 5) {
            Text("esse plano foi pensado para tratar:")
                .font(EMEBrand.sans(7.5, weight: .italic))

            Text(plano.focoTratamento)
                .font(EMEBrand.sans(8.5, weight: .bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 10)
    }
}

struct ProcedimentoDisplay: Equatable {
    let titulo: String
    let detalhe: String?

    init(raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let open = trimmed.firstIndex(of: "("),
            let close = trimmed.lastIndex(of: ")"),
            open < close
        else {
            titulo = trimmed
            detalhe = nil
            return
        }

        titulo = String(trimmed[..<open]).trimmingCharacters(in: .whitespaces)
        let innerStart = trimmed.index(after: open)
        detalhe = String(trimmed[innerStart..<close]).trimmingCharacters(in: .whitespaces)
    }
}

#Preview("Plano A") {
    OrcamentoPageView(
        nomePaciente: Orcamento.preview.nomePaciente,
        mesAno: Orcamento.preview.mesAno,
        plano: Orcamento.preview.planoA,
        pageIndex: 0
    )
}

#Preview("Plano B") {
    OrcamentoPageView(
        nomePaciente: Orcamento.preview.nomePaciente,
        mesAno: Orcamento.preview.mesAno,
        plano: Orcamento.preview.planoB,
        pageIndex: 1
    )
}

#Preview("Marca") {
    TemplatePageBackground(pageIndex: 2)
        .frame(width: EMETemplate.pageSize.width, height: EMETemplate.pageSize.height)
}
