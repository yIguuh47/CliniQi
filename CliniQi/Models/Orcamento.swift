//
//  Orcamento.swift
//  CliniQi
//

import Foundation

struct PlanoTratamento: Equatable {
    var titulo: String
    var subtitulo: String
    var procedimentos: [String]
    var focoTratamento: String
    var numParcelas: Int
    var valorParcela: Double
    var valorPix: Double
}

struct Orcamento: Equatable {
    var nomePaciente: String
    var mesAno: String
    var planoA: PlanoTratamento
    var planoB: PlanoTratamento
}

extension PlanoTratamento {
    var procedimentosVisiveis: [String] {
        procedimentos
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var parcelaFormatada: String {
        "\(numParcelas)x de \(CurrencyFormatter.decimal(valorParcela))"
    }

    var pixFormatado: String {
        "\(CurrencyFormatter.currency(valorPix)) pix"
    }
}

extension Orcamento {
    static let preview = Orcamento(
        nomePaciente: "Sheila Postigo",
        mesAno: "Abril / 2026",
        planoA: PlanoTratamento(
            titulo: "plano a",
            subtitulo: "é um plano de tratamento personalizado para solucionar as suas queixas apresentadas",
            procedimentos: [
                "Reestruturação de Terço Médio da Face (Malar e Arco Zigomático | Bigode Chinês)",
                "Reestruturação e Contorno de Terço Inferior da Face (Mandíbula | Pré Jowl (bulldog) | Mento (queixo))"
            ],
            focoTratamento: "lifting facial • reestruturação facial • proporção equilibrada do perfil",
            numParcelas: 10,
            valorParcela: 379.26,
            valorPix: 3_579.00
        ),
        planoB: PlanoTratamento(
            titulo: "plano b",
            subtitulo: "é um plano de tratamento personalizado para solucionar apenas uma das queixas apresentadas",
            procedimentos: [
                "Reestruturação e Contorno de Terço Inferior da Face (Mandíbula | Pré Jowl (bulldog) | Mento (queixo))"
            ],
            focoTratamento: "contorno de terço inferior & proporção equilibrada do perfil",
            numParcelas: 10,
            valorParcela: 280.00,
            valorPix: 2_700.00
        )
    )
}
