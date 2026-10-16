//
//  NovoAgendamentoView.swift
//  CliniQi
//

import EventKit
import SwiftUI

struct NovoAgendamentoView: View {
    var dataInicial: Date = .now

    @Environment(AgendaStore.self) private var agenda
    @Environment(\.dismiss) private var dismiss

    @State private var paciente = ""
    @State private var tipo = Agendamento.tiposSugeridos[0]
    @State private var inicio = Date.now
    @State private var duracaoMinutos = 60
    @State private var calendarID: String?
    @State private var observacoes = ""
    @State private var errorMessage: String?
    @State private var salvando = false

    private let duracoes = [15, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            Group {
                if agenda.fonte != .nenhuma {
                    form
                } else {
                    ScrollView {
                        AgendaAccessCard().padding(16)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Novo Agendamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if salvando {
                        ProgressView()
                    } else {
                        Button("Salvar", action: salvar)
                            .disabled(!podeSalvar)
                    }
                }
            }
            .alert(
                "Não foi possível agendar",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear(perform: configurarValoresIniciais)
            .task {
                // Garante a lista de agendas do Google ao abrir direto pela Home.
                if agenda.fonte == .google, agenda.calendariosEditaveis.isEmpty {
                    await agenda.carregarCalendarios()
                    if calendarID == nil { calendarID = agenda.calendarioPadrao?.id }
                }
            }
        }
    }

    private var form: some View {
        Form {
            Section("Paciente") {
                TextField("Nome do paciente", text: $paciente)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)

                Picker("Tipo", selection: $tipo) {
                    ForEach(Agendamento.tiposSugeridos, id: \.self) { Text($0).tag($0) }
                }
            }

            Section("Horário") {
                DatePicker("Início", selection: $inicio, displayedComponents: [.date, .hourAndMinute])
                    .environment(\.locale, Locale(identifier: "pt_BR"))

                Picker("Duração", selection: $duracaoMinutos) {
                    ForEach(duracoes, id: \.self) { minutos in
                        Text(Self.formatarDuracao(minutos)).tag(minutos)
                    }
                }
            }

            Section {
                Picker("Agenda", selection: $calendarID) {
                    ForEach(agenda.calendariosEditaveis) { calendario in
                        Label {
                            Text(calendario.titulo)
                        } icon: {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(calendario.cor)
                        }
                        .tag(Optional(calendario.id))
                    }
                }
            } header: {
                Text("Agenda")
            } footer: {
                if agenda.fonte == .google {
                    Text("Salvo direto no Google Agenda de \(agenda.googleAuth.email ?? "sua conta").")
                } else {
                    Text("Salvo na agenda do iPhone. Conecte sua conta Google na aba Agenda para gravar direto no Google Agenda.")
                }
            }

            Section("Observações") {
                TextField("Opcional", text: $observacoes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
    }

    private var podeSalvar: Bool {
        agenda.fonte != .nenhuma
            && !paciente.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func configurarValoresIniciais() {
        guard calendarID == nil else { return }
        calendarID = agenda.calendarioPadrao?.id
        inicio = Self.proximoHorario(em: dataInicial)
    }

    private func salvar() {
        salvando = true
        Task {
            defer { salvando = false }
            do {
                try await agenda.criar(
                    paciente: paciente,
                    tipo: tipo,
                    inicio: inicio,
                    duracao: TimeInterval(duracaoMinutos * 60),
                    observacoes: observacoes,
                    calendarioID: calendarID
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Próxima hora cheia no dia escolhido (ou 9h, se o dia não for hoje).
    static func proximoHorario(em dia: Date) -> Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(dia) {
            let proximaHora = calendar.date(byAdding: .hour, value: 1, to: .now) ?? .now
            return calendar.dateInterval(of: .hour, for: proximaHora)?.start ?? proximaHora
        }
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dia) ?? dia
    }

    static func formatarDuracao(_ minutos: Int) -> String {
        switch minutos {
        case ..<60: "\(minutos) min"
        case 60: "1 hora"
        default: minutos % 60 == 0 ? "\(minutos / 60) horas" : "\(minutos / 60)h\(minutos % 60)"
        }
    }
}
