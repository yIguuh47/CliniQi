//
//  EMETemplate.swift
//  CliniQi
//

import PDFKit
import SwiftUI
import UIKit

enum EMETemplate {
    static let resourceName = "EMEOrcamentoTemplate"
    static let pageSize = CGSize(width: 595.5, height: 842.25)

    static var document: PDFDocument? {
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "pdf") {
            return PDFDocument(url: url)
        }
        return nil
    }

    static func page(_ index: Int) -> PDFPage? {
        document?.page(at: index)
    }

    static func previewImage(page index: Int, scale: CGFloat = 2) -> UIImage? {
        guard let page = page(index) else { return nil }
        let size = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            draw(page, in: context.cgContext, dest: CGRect(origin: .zero, size: size))
            eraseConnector(pageIndex: index, in: context.cgContext, dest: CGRect(origin: .zero, size: size))
        }
    }

    static func draw(_ page: PDFPage, in context: CGContext, dest: CGRect) {
        guard let cgPage = page.pageRef else { return }
        let media = page.bounds(for: .mediaBox)

        context.saveGState()
        context.translateBy(x: dest.minX, y: dest.maxY)
        context.scaleBy(x: dest.width / media.width, y: -(dest.height / media.height))
        context.translateBy(x: -media.minX, y: -media.minY)
        context.drawPDFPage(cgPage)
        context.restoreGState()
    }

    /// Apaga o conector (linha + bolinha) fixo do template; o overlay o redesenha
    /// logo acima dos valores, acompanhando a altura da lista de procedimentos.
    static func eraseConnector(pageIndex: Int, in context: CGContext, dest: CGRect) {
        guard let line = OverlayLayout.templateConnector(pageIndex: pageIndex) else { return }
        let sx = dest.width / pageSize.width
        let sy = dest.height / pageSize.height
        let cover = line.insetBy(dx: -1, dy: -1)
        let cardX = OverlayLayout.cardMinX

        func fill(_ rect: CGRect, _ color: UIColor) {
            context.setFillColor(color.cgColor)
            context.fill(CGRect(
                x: dest.minX + rect.minX * sx,
                y: dest.minY + rect.minY * sy,
                width: rect.width * sx,
                height: rect.height * sy
            ))
        }

        context.saveGState()
        fill(CGRect(x: cover.minX, y: cover.minY, width: cardX - cover.minX, height: cover.height), sandColor)
        fill(CGRect(x: cardX, y: cover.minY, width: cover.maxX - cardX, height: cover.height), paperColor)
        context.restoreGState()
    }

    private static let sandColor = UIColor(red: 232 / 255, green: 223 / 255, blue: 214 / 255, alpha: 1)
    private static let paperColor = UIColor(red: 255 / 255, green: 250 / 255, blue: 245 / 255, alpha: 1)
    static let connectorColor = Color(red: 182 / 255, green: 153 / 255, blue: 135 / 255)
}

enum OverlayLayout {
    static let page = EMETemplate.pageSize

    static let nameChip = CGRect(x: 92, y: 94.2, width: 318, height: 22.8)
    static let dateChip = CGRect(x: 448, y: 94.2, width: 94, height: 22.8)

    static let subtitle = CGRect(x: 145, y: 348, width: 248, height: 52)
    static let proceduresA = CGRect(x: 135.5, y: 414, width: 250, height: 72)
    static let financialA = CGRect(x: 135.5, y: 488, width: 220, height: 52)
    static let focusA = CGRect(x: 412, y: 452, width: 172, height: 62)
    static let focusB = CGRect(x: 406, y: 434, width: 176, height: 56)

    static let proceduresB = CGRect(x: 135.5, y: 512, width: 310, height: 48)
    static let financialB = CGRect(x: 168, y: 564, width: 220, height: 52)

    /// Borda esquerda do cartão claro do template.
    static let cardMinX: CGFloat = 123
    /// Conector original do template (linha + bolinha à direita).
    static let connectorA = CGRect(x: 104.25, y: 522.5, width: 62, height: 2)
    static let connectorB = CGRect(x: 104.75, y: 510.75, width: 74.25, height: 2.25)

    static func templateConnector(pageIndex: Int) -> CGRect? {
        switch pageIndex {
        case 0: connectorA
        case 1: connectorB
        default: nil
        }
    }
}

struct TemplatePageBackground: View {
    let pageIndex: Int

    var body: some View {
        Group {
            if let image = EMETemplate.previewImage(page: pageIndex) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: EMETemplate.pageSize.width, height: EMETemplate.pageSize.height)
            } else {
                EMEBrand.sand
                    .frame(width: EMETemplate.pageSize.width, height: EMETemplate.pageSize.height)
            }
        }
    }
}
