//
//  AgendaView.swift
//  CliniQi
//

import EventKit
import SwiftUI

struct AgendaView: View {
    var onNovoAgendamento: (Date) -> Void

    @Environment(AgendaStore.self) private var agenda
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var editingEvent: EKEvent?
    @State private var detalhe: Agendamento?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if agenda.fonte == .nenhuma {
                        AgendaAccessCard()
                    } else {
                        WeekStrip(selectedDay: $selectedDay)

                        if agenda.fonte == .iphone {
                            GoogleConnectBanner()
                        }

                        if let erro = agenda.erro {
                            AgendaErrorBanner(message: erro)
                        }

                        dayEvents
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .refreshable { await agenda.atualizar(selectedDay) }
            .task(id: TaskKey(day: selectedDay, fonte: agenda.fonte)) {
                await agenda.carregar(selectedDay)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Agenda")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Hoje") {
                        withAnimation { selectedDay = Calendar.current.startOfDay(for: .now) }
                    }
                }
                if agenda.fonte == .google {
                    ToolbarItem(placement: .topBarTrailing) {
                        GoogleAccountMenu()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onNovoAgendamento(selectedDay)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Novo agendamento")
                    .disabled(agenda.fonte == .nenhuma)
                }
            }
            .sheet(item: $editingEvent) { event in
                EventEditView(event: event, store: agenda.iphone.store) {
                    editingEvent = nil
                    agenda.iphone.refresh()
                }
                .ignoresSafeArea()
            }
            .sheet(item: $detalhe) { item in
                AgendamentoDetailView(item: item)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private struct TaskKey: Equatable {
        let day: Date
        let fonte: AgendaStore.Fonte
    }

    private var dayEvents: some View {
        let itens = agenda.agendamentos(on: selectedDay)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "pt_BR"))).capitalizingFirstLetter)
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                if agenda.carregando {
                    ProgressView()
                }
            }

            if itens.isEmpty {
                if agenda.jaCarregou(selectedDay) {
                    ContentUnavailableView {
                        Label("Nenhuma consulta", systemImage: "calendar")
                    } description: {
                        Text("Não há eventos neste dia.")
                    } actions: {
                        Button("Agendar") { onNovoAgendamento(selectedDay) }
                            .buttonStyle(.bordered)
                    }
                    .padding(.top, 24)
                }
            } else {
                ForEach(itens) { item in
                    Button {
                        abrir(item)
                    } label: {
                        AgendamentoRow(item: item, mostraAgenda: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func abrir(_ item: Agendamento) {
        switch item.origem {
        case .google:
            detalhe = item
        case .iphone:
            editingEvent = agenda.eventoDoIPhone(item)
        }
    }
}

/// Convite para trocar a agenda do iPhone pela conexão direta com o Google.
private struct GoogleConnectBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Usando a agenda do iPhone. Conecte sua conta Google para ler e gravar direto no Google Agenda.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            GoogleSignInButton()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(EMEBrand.sand.opacity(0.6)))
    }
}

struct AgendaErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.system(size: 13))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.red.opacity(0.08)))
    }
}

private extension String {
    var capitalizingFirstLetter: String { prefix(1).uppercased() + dropFirst() }
}

private struct WeekStrip: View {
    @Binding var selectedDay: Date

    private let calendar = Calendar.current

    var body: some View {
        let days = weekDays
        VStack(spacing: 10) {
            HStack {
                Button { shiftWeek(-1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(selectedDay.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "pt_BR"))).capitalizingFirstLetter)
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                Button { shiftWeek(1) } label: { Image(systemName: "chevron.right") }
            }
            .foregroundStyle(EMEBrand.ink)

            HStack(spacing: 6) {
                ForEach(days, id: \.self) { day in
                    let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
                    let isToday = calendar.isDateInToday(day)
                    Button {
                        withAnimation(.snappy) { selectedDay = day }
                    } label: {
                        VStack(spacing: 4) {
                            Text(day.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "pt_BR"))).prefix(3).capitalized)
                                .font(.system(size: 12))
                            Text(day.formatted(.dateTime.day()))
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(isSelected ? .white : (isToday ? Color.accentColor : .primary))
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? EMEBrand.accent : Color(.secondarySystemGroupedBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var weekDays: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDay) else { return [selectedDay] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private func shiftWeek(_ value: Int) {
        if let day = calendar.date(byAdding: .weekOfYear, value: value, to: selectedDay) {
            withAnimation(.snappy) { selectedDay = day }
        }
    }
}
