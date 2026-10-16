//
//  CalendarService.swift
//  CliniQi
//

import EventKit
import Foundation
import Observation

/// Acesso à agenda do iPhone via EventKit. Quando a conta Google está adicionada
/// em Ajustes › Apps › Calendário › Contas, o próprio iOS sincroniza os eventos
/// com o Google Agenda nos dois sentidos.
@MainActor
@Observable
final class CalendarService {
    enum Access: Equatable {
        case notDetermined, granted, denied
    }

    private(set) var access: Access = .notDetermined
    private(set) var calendars: [EKCalendar] = []
    /// Incrementado a cada mudança na agenda (local ou vinda do Google) para as telas recarregarem.
    private(set) var revision = 0

    var selectedCalendarID: String? {
        didSet { UserDefaults.standard.set(selectedCalendarID, forKey: Self.selectedCalendarKey) }
    }

    let store = EKEventStore()
    private static let selectedCalendarKey = "agenda.selectedCalendarID"
    private var changeObserver: NSObjectProtocol?

    init() {
        selectedCalendarID = UserDefaults.standard.string(forKey: Self.selectedCalendarKey)
        updateAccess()
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        if access == .granted { reload() }
    }

    func requestAccess() async {
        do {
            _ = try await store.requestFullAccessToEvents()
        } catch {
            // O status abaixo reflete a resposta do usuário.
        }
        updateAccess()
        if access == .granted { reload() }
    }

    /// Pede ao iOS para buscar novidades das contas (Google, iCloud…).
    func refresh() {
        store.refreshSourcesIfNecessary()
        reload()
    }

    // MARK: - Agendas

    var selectedCalendar: EKCalendar? {
        if let id = selectedCalendarID, let calendar = store.calendar(withIdentifier: id),
           calendar.allowsContentModifications {
            return calendar
        }
        return googleCalendars.first(where: \.allowsContentModifications)
            ?? store.defaultCalendarForNewEvents
    }

    var writableCalendars: [EKCalendar] {
        calendars.filter(\.allowsContentModifications)
    }

    var googleCalendars: [EKCalendar] {
        calendars.filter(Self.isGoogle)
    }

    var hasGoogleAccount: Bool {
        !googleCalendars.isEmpty
    }

    static func isGoogle(_ calendar: EKCalendar) -> Bool {
        guard let source = calendar.source else { return false }
        let title = source.title.lowercased()
        return source.sourceType == .calDAV
            && (title.contains("gmail") || title.contains("google") || title.contains("@"))
            && !title.contains("icloud")
    }

    // MARK: - Eventos

    func events(on day: Date) -> [EKEvent] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return events(from: start, to: end)
    }

    func events(from start: Date, to end: Date) -> [EKEvent] {
        guard access == .granted else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    @discardableResult
    func createEvent(
        paciente: String,
        tipo: String,
        inicio: Date,
        duracao: TimeInterval,
        observacoes: String,
        calendar: EKCalendar?
    ) throws -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = AgendamentoTitle.compose(paciente: paciente, tipo: tipo)
        event.startDate = inicio
        event.endDate = inicio.addingTimeInterval(duracao)
        event.notes = observacoes.isEmpty ? nil : observacoes
        event.calendar = calendar ?? selectedCalendar
        event.addAlarm(EKAlarm(relativeOffset: -60 * 60))
        try store.save(event, span: .thisEvent, commit: true)
        reload()
        return event
    }

    // MARK: - Privado

    private func updateAccess() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: access = .granted
        case .notDetermined: access = .notDetermined
        default: access = .denied
        }
    }

    private func reload() {
        updateAccess()
        calendars = access == .granted
            ? store.calendars(for: .event).sorted { lhs, rhs in
                (lhs.source?.title ?? "", lhs.title) < (rhs.source?.title ?? "", rhs.title)
            }
            : []
        revision += 1
    }
}

/// Título dos eventos criados pelo app: "Paciente — Tipo". Eventos criados direto
/// no Google aparecem com o título inteiro e sem tipo.
enum AgendamentoTitle {
    static let separator = " — "

    static func compose(paciente: String, tipo: String) -> String {
        let paciente = paciente.trimmingCharacters(in: .whitespacesAndNewlines)
        let tipo = tipo.trimmingCharacters(in: .whitespacesAndNewlines)
        return tipo.isEmpty ? paciente : paciente + separator + tipo
    }

    static func split(_ title: String?) -> (paciente: String, tipo: String?) {
        let title = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = title.range(of: separator) else {
            return (title.isEmpty ? "Sem título" : title, nil)
        }
        return (String(title[..<range.lowerBound]), String(title[range.upperBound...]))
    }
}
