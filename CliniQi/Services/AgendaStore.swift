//
//  AgendaStore.swift
//  CliniQi
//

import EventKit
import Foundation
import Observation
import SwiftUI

/// Ponto único de acesso à agenda. Com a conta Google conectada, lê e grava direto
/// no Google Agenda (API); sem ela, usa a agenda do iPhone (EventKit).
@MainActor
@Observable
final class AgendaStore {
    enum Fonte: Equatable {
        case google, iphone, nenhuma
    }

    struct Calendario: Identifiable, Hashable {
        let id: String
        let titulo: String
        let conta: String
        let cor: Color
        let principal: Bool
    }

    let iphone: CalendarService
    let googleAuth: GoogleAuthService
    private let google: GoogleCalendarClient

    private(set) var googleCalendars: [GoogleCalendarClient.CalendarEntry] = []
    private(set) var carregando = false
    var erro: String?

    /// Eventos do Google por dia (início do dia).
    private var googleCache: [Date: [Agendamento]] = [:]

    var calendarioPadraoID: String? {
        didSet { UserDefaults.standard.set(calendarioPadraoID, forKey: Self.calendarioPadraoKey) }
    }

    private static let calendarioPadraoKey = "agenda.google.calendarioPadraoID"

    convenience init() {
        self.init(iphone: CalendarService(), googleAuth: GoogleAuthService())
    }

    init(iphone: CalendarService, googleAuth: GoogleAuthService) {
        self.iphone = iphone
        self.googleAuth = googleAuth
        self.google = GoogleCalendarClient(auth: googleAuth)
        calendarioPadraoID = UserDefaults.standard.string(forKey: Self.calendarioPadraoKey)
    }

    var fonte: Fonte {
        if googleAuth.isSignedIn { return .google }
        return iphone.access == .granted ? .iphone : .nenhuma
    }

    // MARK: - Conexão

    func conectarGoogle(using authenticate: GoogleAuthService.Authenticator) async {
        do {
            try await googleAuth.signIn(using: authenticate)
            googleCache = [:]
            await carregarCalendarios()
        } catch GoogleError.cancelled {
            // Usuário fechou a tela de login.
        } catch {
            erro = error.localizedDescription
        }
    }

    func desconectarGoogle() async {
        await googleAuth.signOut()
        googleCalendars = []
        googleCache = [:]
    }

    func usarAgendaDoIPhone() async {
        await iphone.requestAccess()
    }

    // MARK: - Leitura

    /// Agendamentos já carregados do dia (Google: do cache; iPhone: na hora).
    func agendamentos(on day: Date) -> [Agendamento] {
        switch fonte {
        case .google:
            return googleCache[Calendar.current.startOfDay(for: day)] ?? []
        case .iphone:
            _ = iphone.revision
            return Agendamento.destacandoProximo(iphone.events(on: day).map(Agendamento.init(event:)))
        case .nenhuma:
            return []
        }
    }

    func jaCarregou(_ day: Date) -> Bool {
        fonte != .google || googleCache[Calendar.current.startOfDay(for: day)] != nil
    }

    /// Busca a semana do dia no Google (no iPhone a leitura já é imediata).
    func carregar(_ day: Date, forcar: Bool = false) async {
        guard fonte == .google else { return }
        let calendar = Calendar.current
        let inicioDia = calendar.startOfDay(for: day)
        if !forcar, googleCache[inicioDia] != nil { return }

        let semana = calendar.dateInterval(of: .weekOfYear, for: inicioDia)
            ?? DateInterval(start: inicioDia, duration: 86_400)

        carregando = true
        defer { carregando = false }

        do {
            if googleCalendars.isEmpty { await carregarCalendarios() }
            let visiveis = googleCalendars.filter { $0.selected ?? true }
            let conta = googleAuth.email ?? "Google"

            let itens = try await withThrowingTaskGroup(of: [Agendamento].self) { group in
                for entry in visiveis {
                    group.addTask { [google] in
                        let eventos = try await google.events(calendarID: entry.id, from: semana.start, to: semana.end)
                        return eventos.compactMap { Self.agendamento(from: $0, calendar: entry, conta: conta) }
                    }
                }
                return try await group.reduce(into: [Agendamento]()) { $0 += $1 }
            }

            var porDia: [Date: [Agendamento]] = [:]
            var dia = semana.start
            while dia < semana.end {
                porDia[dia] = []
                dia = calendar.date(byAdding: .day, value: 1, to: dia) ?? semana.end
            }
            for item in itens {
                // Eventos de vários dias aparecem em cada dia que cobrem.
                var cursor = calendar.startOfDay(for: item.inicio)
                repeat {
                    if porDia[cursor] != nil { porDia[cursor]?.append(item) }
                    cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? item.fim
                } while cursor < item.fim
            }
            for (dia, lista) in porDia {
                googleCache[dia] = Agendamento.destacandoProximo(lista)
            }
            erro = nil
        } catch {
            erro = error.localizedDescription
        }
    }

    func atualizar(_ day: Date) async {
        switch fonte {
        case .google:
            googleCache = [:]
            await carregarCalendarios()
            await carregar(day, forcar: true)
        case .iphone:
            iphone.refresh()
        case .nenhuma:
            break
        }
    }

    // MARK: - Agendas disponíveis para criar eventos

    var calendariosEditaveis: [Calendario] {
        switch fonte {
        case .google:
            let conta = googleAuth.email ?? "Google"
            return googleCalendars.filter(\.isWritable).map {
                Calendario(id: $0.id, titulo: $0.title, conta: conta, cor: Color(hex: $0.backgroundColor) ?? EMEBrand.accent, principal: $0.primary == true)
            }
        case .iphone:
            return iphone.writableCalendars.map {
                Calendario(id: $0.calendarIdentifier, titulo: $0.title, conta: $0.source?.title ?? "", cor: Color(cgColor: $0.cgColor), principal: false)
            }
        case .nenhuma:
            return []
        }
    }

    var calendarioPadrao: Calendario? {
        let opcoes = calendariosEditaveis
        switch fonte {
        case .google:
            return opcoes.first { $0.id == calendarioPadraoID } ?? opcoes.first(where: \.principal) ?? opcoes.first
        case .iphone:
            let id = iphone.selectedCalendar?.calendarIdentifier
            return opcoes.first { $0.id == id } ?? opcoes.first
        case .nenhuma:
            return nil
        }
    }

    func carregarCalendarios() async {
        guard fonte == .google else { return }
        do {
            googleCalendars = try await google.calendars()
                .sorted { ($0.primary == true ? 0 : 1, $0.title) < ($1.primary == true ? 0 : 1, $1.title) }
        } catch {
            erro = error.localizedDescription
        }
    }

    // MARK: - Escrita

    func criar(
        paciente: String,
        tipo: String,
        inicio: Date,
        duracao: TimeInterval,
        observacoes: String,
        calendarioID: String?
    ) async throws {
        let titulo = AgendamentoTitle.compose(paciente: paciente, tipo: tipo)
        switch fonte {
        case .google:
            guard let calendarioID = calendarioID ?? calendarioPadrao?.id else { throw GoogleError.invalidResponse }
            _ = try await google.insertEvent(
                calendarID: calendarioID,
                title: titulo,
                notes: observacoes,
                start: inicio,
                end: inicio.addingTimeInterval(duracao)
            )
            calendarioPadraoID = calendarioID
            googleCache[Calendar.current.startOfDay(for: inicio)] = nil
            await carregar(inicio, forcar: true)
        case .iphone:
            try iphone.createEvent(
                paciente: paciente,
                tipo: tipo,
                inicio: inicio,
                duracao: duracao,
                observacoes: observacoes,
                calendar: calendarioID.flatMap { iphone.store.calendar(withIdentifier: $0) }
            )
            iphone.selectedCalendarID = calendarioID
        case .nenhuma:
            throw GoogleError.notSignedIn
        }
    }

    func apagar(_ item: Agendamento) async throws {
        guard case let .google(calendarID, eventID, _) = item.origem else { return }
        try await google.deleteEvent(calendarID: calendarID, eventID: eventID)
        await carregar(item.inicio, forcar: true)
    }

    /// Evento do iPhone correspondente (para abrir o editor nativo).
    func eventoDoIPhone(_ item: Agendamento) -> EKEvent? {
        iphone.events(on: item.inicio).first { $0.id == item.id }
    }

    // MARK: - Conversão

    private nonisolated static func agendamento(
        from event: GoogleCalendarClient.Event,
        calendar entry: GoogleCalendarClient.CalendarEntry,
        conta: String
    ) -> Agendamento? {
        guard let inicio = GoogleCalendarClient.date(from: event.start),
              let fim = GoogleCalendarClient.date(from: event.end)
        else { return nil }
        let partes = AgendamentoTitle.split(event.summary)
        return Agendamento(
            id: entry.id + "|" + event.id,
            inicio: inicio.date,
            fim: fim.date,
            diaInteiro: inicio.allDay,
            paciente: partes.paciente,
            tipo: partes.tipo,
            observacoes: event.description,
            agenda: entry.title,
            corAgenda: Color(hex: entry.backgroundColor) ?? EMEBrand.accent,
            origem: .google(calendarID: entry.id, eventID: event.id, link: event.htmlLink.flatMap(URL.init(string:)))
        )
    }
}
