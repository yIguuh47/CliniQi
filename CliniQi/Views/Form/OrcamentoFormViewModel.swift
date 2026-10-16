//
//  OrcamentoFormViewModel.swift
//  CliniQi
//

import Foundation
import Observation

struct ProcedimentoDraft: Identifiable, Equatable {
    let id: UUID
    var texto: String

    init(id: UUID = UUID(), texto: String) {
        self.id = id
        self.texto = texto
    }
}

struct PlanoDraft: Equatable {
    var titulo: String
    var subtitulo: String
    var procedimentos: [ProcedimentoDraft]
    var focoTratamento: String
    var numParcelas: Int
    var valorParcela: Double
    var valorPix: Double

    init(_ plano: PlanoTratamento) {
        titulo = plano.titulo
        subtitulo = plano.subtitulo
        procedimentos = plano.procedimentos.map { ProcedimentoDraft(texto: $0) }
        if procedimentos.isEmpty {
            procedimentos = [ProcedimentoDraft(texto: "")]
        }
        focoTratamento = plano.focoTratamento
        numParcelas = plano.numParcelas
        valorParcela = plano.valorParcela
        valorPix = plano.valorPix
    }

    func toPlano() -> PlanoTratamento {
        PlanoTratamento(
            titulo: titulo.trimmingCharacters(in: .whitespacesAndNewlines),
            subtitulo: subtitulo.trimmingCharacters(in: .whitespacesAndNewlines),
            procedimentos: procedimentos.map(\.texto),
            focoTratamento: focoTratamento.trimmingCharacters(in: .whitespacesAndNewlines),
            numParcelas: max(numParcelas, 1),
            valorParcela: valorParcela,
            valorPix: valorPix
        )
    }
}

@Observable
final class OrcamentoFormViewModel {
    var nomePaciente: String
    var mesAno: String
    var planoA: PlanoDraft
    var planoB: PlanoDraft
    var errorMessage: String?

    init(orcamento: Orcamento = .preview) {
        nomePaciente = orcamento.nomePaciente
        mesAno = orcamento.mesAno
        planoA = PlanoDraft(orcamento.planoA)
        planoB = PlanoDraft(orcamento.planoB)
    }

    var orcamento: Orcamento {
        Orcamento(
            nomePaciente: nomePaciente.trimmingCharacters(in: .whitespacesAndNewlines),
            mesAno: mesAno.trimmingCharacters(in: .whitespacesAndNewlines),
            planoA: planoA.toPlano(),
            planoB: planoB.toPlano()
        )
    }

    var canGenerate: Bool {
        !orcamento.nomePaciente.isEmpty && !orcamento.mesAno.isEmpty
    }

    @MainActor
    func generatePDF() -> URL? {
        errorMessage = nil

        guard canGenerate else {
            errorMessage = "Informe o nome da paciente e o mês/ano para gerar o PDF."
            return nil
        }

        guard let url = PDFService.generateOrcamentoPDF(orcamento: orcamento) else {
            errorMessage = "Não foi possível gerar o PDF. Tente novamente."
            return nil
        }

        return url
    }
}
