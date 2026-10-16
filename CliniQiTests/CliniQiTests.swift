//
//  CliniQiTests.swift
//  CliniQiTests
//
//  Created by Igor on 18/08/26.
//

import PDFKit
import Testing
@testable import CliniQi

struct CurrencyFormatterTests {
    @Test func formatsDecimalInBrazilianLocale() {
        #expect(CurrencyFormatter.decimal(379.26) == "379,26")
        #expect(CurrencyFormatter.decimal(280) == "280,00")
    }

    @Test func formatsCurrencyInBrazilianLocale() {
        let pixA = CurrencyFormatter.currency(3_579)
        let pixB = CurrencyFormatter.currency(2_700)

        #expect(pixA.contains("3.579,00"))
        #expect(pixB.contains("2.700,00"))
        #expect(pixA.contains("R$"))
    }
}

struct OrcamentoModelTests {
    @Test func previewMatchesClinicSample() {
        let orcamento = Orcamento.preview

        #expect(orcamento.nomePaciente == "Sheila Postigo")
        #expect(orcamento.mesAno == "Abril / 2026")
        #expect(orcamento.planoA.titulo == "plano a")
        #expect(orcamento.planoA.procedimentos.count == 2)
        #expect(orcamento.planoA.numParcelas == 10)
        #expect(orcamento.planoA.valorParcela == 379.26)
        #expect(orcamento.planoA.valorPix == 3_579)
        #expect(orcamento.planoB.titulo == "plano b")
        #expect(orcamento.planoB.procedimentos.count == 1)
        #expect(orcamento.planoB.valorParcela == 280)
        #expect(orcamento.planoB.valorPix == 2_700)
        #expect(orcamento.planoA.parcelaFormatada == "10x de 379,26")
        #expect(orcamento.planoB.pixFormatado.contains("2.700,00"))
    }

    @Test func procedimentoDisplaySplitsRegionDetails() {
        let display = ProcedimentoDisplay(
            raw: "Reestruturação de Terço Médio da Face (Malar e Arco Zigomático | Bigode Chinês)"
        )

        #expect(display.titulo == "Reestruturação de Terço Médio da Face")
        #expect(display.detalhe == "Malar e Arco Zigomático | Bigode Chinês")
    }

    @Test func procedimentoDisplayKeepsNestedParentheses() {
        let display = ProcedimentoDisplay(
            raw: "Reestruturação e Contorno de Terço Inferior da Face (Mandíbula | Pré Jowl (bulldog) | Mento (queixo))"
        )

        #expect(display.titulo == "Reestruturação e Contorno de Terço Inferior da Face")
        #expect(display.detalhe == "Mandíbula | Pré Jowl (bulldog) | Mento (queixo)")
    }

    @Test func fileNameSanitizerKeepsReadableSlug() {
        #expect(FileNameSanitizer.sanitize("Sheila Postigo") == "Sheila_Postigo")
        #expect(FileNameSanitizer.sanitize("   ") == "Orcamento")
    }
}

struct OrcamentoFormViewModelTests {
    @Test func buildsOrcamentoFromDrafts() {
        let viewModel = OrcamentoFormViewModel(orcamento: .preview)
        viewModel.nomePaciente = "  Ana Silva  "
        viewModel.planoA.procedimentos.append(ProcedimentoDraft(texto: "  "))

        let orcamento = viewModel.orcamento

        #expect(orcamento.nomePaciente == "Ana Silva")
        #expect(orcamento.planoA.procedimentosVisiveis.count == 2)
        #expect(viewModel.canGenerate)
    }

    @Test @MainActor
    func rejectsGenerationWithoutPatientName() {
        let viewModel = OrcamentoFormViewModel(orcamento: .preview)
        viewModel.nomePaciente = " "

        #expect(!viewModel.canGenerate)
        #expect(viewModel.generatePDF() == nil)
        #expect(viewModel.errorMessage != nil)
    }
}

@MainActor
struct PDFServiceTests {
    @Test
    func generatePDFCreatesThreeA4Pages() throws {
        let url = try #require(PDFService.generateOrcamentoPDF(orcamento: .preview))
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(url.pathExtension == "pdf")
        #expect(url.lastPathComponent.contains("Sheila_Postigo"))

        let document = try #require(PDFDocument(url: url))
        #expect(document.pageCount == 3)

        let page = try #require(document.page(at: 0))
        let bounds = page.bounds(for: .mediaBox)
        #expect(abs(bounds.width - EMETemplate.pageSize.width) < 1)
        #expect(abs(bounds.height - EMETemplate.pageSize.height) < 1)
    }

    @Test
    func templateExistsInBundle() {
        #expect(EMETemplate.document?.pageCount == 3)
    }
}
