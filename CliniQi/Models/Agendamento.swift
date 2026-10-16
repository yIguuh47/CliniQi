//
//  Agendamento.swift
//  CliniQi
//

import EventKit
import SwiftUI

struct Agendamento: Identifiable, Equatable {
    enum Origem: Equatable {
        case iphone
        case google(calendarID: String, eventID: String, link: URL?)
    }

    let id: String
    var inicio: Date
    var fim: Date
    var diaInteiro: Bool
    var paciente: String
    var tipo: String?
    var observacoes: String?
    var agenda: String
    var corAgenda: Color
    var origem: Origem
    var destaque: Bool = false

    var horario: String {
        diaInteiro ? "Dia todo" : inicio.formatted(Self.horaFormat)
    }

    var intervalo: String {
        diaInteiro ? "Dia todo" : "\(inicio.formatted(Self.horaFormat)) – \(fim.formatted(Self.horaFormat))"
    }

    private static let horaFormat = Date.FormatStyle.dateTime
        .hour(.twoDigits(amPM: .omitted))
        .minute(.twoDigits)
}

extension Agendamento {
    init(event: EKEvent) {
        let partes = AgendamentoTitle.split(event.title)
        self.init(
            id: event.id,
            inicio: event.startDate,
            fim: event.endDate,
            diaInteiro: event.isAllDay,
            paciente: partes.paciente,
            tipo: partes.tipo,
            observacoes: event.notes,
            agenda: event.calendar?.title ?? "",
            corAgenda: event.calendar.map { Color(cgColor: $0.cgColor) } ?? EMEBrand.accent,
            origem: .iphone
        )
    }

    /// Ordena os eventos do dia e destaca o próximo atendimento (ou o atual).
    static func destacandoProximo(_ itens: [Agendamento], now: Date = .now) -> [Agendamento] {
        var itens = itens.sorted { ($0.diaInteiro ? 0 : 1, $0.inicio) < ($1.diaInteiro ? 0 : 1, $1.inicio) }
        if let index = itens.firstIndex(where: { !$0.diaInteiro && $0.fim > now }) {
            itens[index].destaque = true
        }
        return itens
    }

    static let tiposSugeridos = [
        "Avaliação",
        "Consulta de Retorno",
        "Procedimento",
        "Revisão",
        "Apresentação de Orçamento"
    ]
}

extension EKEvent: @retroactive Identifiable {
    public var id: String { calendarItemIdentifier + "|" + String(startDate.timeIntervalSince1970) }
}

extension Color {
    /// Cor no formato "#RRGGBB" (como a API do Google devolve).
    init?(hex: String?) {
        guard let hex, hex.hasPrefix("#"), hex.count == 7,
              let value = UInt32(hex.dropFirst(), radix: 16)
        else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
