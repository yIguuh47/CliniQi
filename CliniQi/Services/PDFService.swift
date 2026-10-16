//
//  PDFService.swift
//  CliniQi
//

import PDFKit
import SwiftUI

@MainActor
final class PDFService {
    private init() {}

    static func generateOrcamentoPDF(orcamento: Orcamento) -> URL? {
        guard let template = EMETemplate.document, template.pageCount >= 3 else {
            return nil
        }

        let pageSize = EMETemplate.pageSize
        let fileName = "Orcamento_\(FileNameSanitizer.sanitize(orcamento.nomePaciente)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let bounds = CGRect(origin: .zero, size: pageSize)

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Orçamento — \(orcamento.nomePaciente)",
            kCGPDFContextAuthor as String: EMEBrand.name,
            kCGPDFContextCreator as String: "CliniQi"
        ]

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)

        do {
            try pdfRenderer.writePDF(to: url) { context in
                for index in 0..<3 {
                    context.beginPage()

                    if let templatePage = template.page(at: index) {
                        EMETemplate.draw(templatePage, in: context.cgContext, dest: bounds)
                        EMETemplate.eraseConnector(pageIndex: index, in: context.cgContext, dest: bounds)
                    }

                    if index < 2 {
                        let plano = index == 0 ? orcamento.planoA : orcamento.planoB
                        overlayImage(
                            for: OrcamentoDataOverlay(
                                nomePaciente: orcamento.nomePaciente,
                                mesAno: orcamento.mesAno,
                                plano: plano,
                                isPlanoA: index == 0
                            )
                        )?.draw(in: bounds)
                    }
                }
            }
            return url
        } catch {
            return nil
        }
    }

    private static func overlayImage<V: View>(for view: V) -> UIImage? {
        let renderer = ImageRenderer(
            content: view
                .frame(width: EMETemplate.pageSize.width, height: EMETemplate.pageSize.height)
                .background(Color.clear)
                .environment(\.colorScheme, .light)
        )
        renderer.proposedSize = ProposedViewSize(
            width: EMETemplate.pageSize.width,
            height: EMETemplate.pageSize.height
        )
        renderer.isOpaque = false
        renderer.scale = 3
        return renderer.uiImage
    }
}
