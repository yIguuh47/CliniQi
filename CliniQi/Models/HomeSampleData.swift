//
//  HomeSampleData.swift
//  CliniQi
//

import Foundation

struct OrcamentoResumo: Identifiable, Equatable {
    enum Status: String {
        case aguardandoAprovacao = "Aguardando aprovação"
        case aprovado = "Aprovado"
        case recusado = "Recusado"
    }

    let id = UUID()
    var paciente: String
    var mesAno: String
    var status: Status
    var pdfGerado: Bool
    var valor: Double
}

// Dados de exemplo até o histórico de orçamentos ser persistido.
enum HomeSampleData {
    static let profissional = "Dra. Milene"

    static let orcamentosRecentes: [OrcamentoResumo] = [
        OrcamentoResumo(
            paciente: "Sheila Postigo",
            mesAno: "Abril / 2026",
            status: .aguardandoAprovacao,
            pdfGerado: true,
            valor: 3_579.00
        )
    ]
}
