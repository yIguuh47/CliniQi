//
//  AgendaComponents.swift
//  CliniQi
//

import EventKit
import AuthenticationServices
import EventKitUI
import SwiftUI

struct AgendamentoRow: View {
    let item: Agendamento
    var mostraAgenda = false

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(item.destaque ? EMEBrand.accent : EMEBrand.taupeBox.opacity(0.7))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(item.horario) - \(item.paciente)")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let tipo = item.tipo {
                    if item.destaque {
                        Text(tipo)
                            .font(.system(size: 14))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 6).fill(EMEBrand.sand))
                    } else {
                        Text(tipo)
                            .font(.system(size: 14))
                    }
                }

                if mostraAgenda {
                    HStack(spacing: 6) {
                        Circle().fill(item.corAgenda).frame(width: 8, height: 8)
                        Text("\(item.intervalo) · \(item.agenda)")
                            .lineLimit(1)
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }
}

/// Cartão para conectar a agenda: Google Agenda (direto pela conta) ou agenda do iPhone.
struct AgendaAccessCard: View {
    @Environment(AgendaStore.self) private var agenda
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Conecte sua agenda", systemImage: "calendar.badge.plus")
                .font(.system(size: 17, weight: .semibold))

            Text("Entre com sua conta Google para ver e criar consultas direto no Google Agenda.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GoogleSignInButton()

            Button {
                if agenda.iphone.access == .denied {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } else {
                    Task { await agenda.usarAgendaDoIPhone() }
                }
            } label: {
                Text(agenda.iphone.access == .denied ? "Liberar agenda do iPhone em Ajustes" : "Usar agenda do iPhone")
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(EMEBrand.paper))
    }
}

/// Botão "Entrar com Google": abre o login do Google e conecta a agenda.
struct GoogleSignInButton: View {
    @Environment(AgendaStore.self) private var agenda
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @State private var conectando = false

    var body: some View {
        Button {
            conectando = true
            Task {
                await agenda.conectarGoogle { url, scheme in
                    try await webAuthenticationSession.authenticate(using: url, callbackURLScheme: scheme)
                }
                conectando = false
            }
        } label: {
            HStack(spacing: 10) {
                if conectando {
                    ProgressView().tint(.white)
                } else {
                    Text("G")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(.white))
                }
                Text("Entrar com Google")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(conectando)
    }
}

/// Conta Google conectada, com opção de desconectar.
struct GoogleAccountMenu: View {
    @Environment(AgendaStore.self) private var agenda
    @State private var confirmando = false

    var body: some View {
        Menu {
            Section(agenda.googleAuth.email ?? "Conta Google") {
                Button("Desconectar Google", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    confirmando = true
                }
            }
        } label: {
            Image(systemName: "person.crop.circle.badge.checkmark")
        }
        .accessibilityLabel("Conta Google")
        .confirmationDialog("Desconectar o Google Agenda?", isPresented: $confirmando, titleVisibility: .visible) {
            Button("Desconectar", role: .destructive) {
                Task { await agenda.desconectarGoogle() }
            }
        } message: {
            Text("Os eventos continuam no Google; o app só deixa de acessá-los.")
        }
    }
}

/// Detalhes de um evento do Google, com atalhos para abrir no Google Agenda ou apagar.
struct AgendamentoDetailView: View {
    let item: Agendamento

    @Environment(AgendaStore.self) private var agenda
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var confirmandoExclusao = false
    @State private var erro: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Paciente", value: item.paciente)
                    if let tipo = item.tipo {
                        LabeledContent("Tipo", value: tipo)
                    }
                    LabeledContent("Data", value: item.inicio.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "pt_BR"))))
                    LabeledContent("Horário", value: item.intervalo)
                    LabeledContent("Agenda") {
                        HStack(spacing: 6) {
                            Circle().fill(item.corAgenda).frame(width: 8, height: 8)
                            Text(item.agenda)
                        }
                    }
                }

                if let observacoes = item.observacoes, !observacoes.isEmpty {
                    Section("Observações") {
                        Text(observacoes)
                    }
                }

                Section {
                    if case let .google(_, _, link?) = item.origem {
                        Button("Abrir no Google Agenda", systemImage: "arrow.up.right.square") {
                            openURL(link)
                        }
                    }
                    Button("Apagar agendamento", systemImage: "trash", role: .destructive) {
                        confirmandoExclusao = true
                    }
                }
            }
            .navigationTitle("Agendamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .confirmationDialog("Apagar este agendamento do Google Agenda?", isPresented: $confirmandoExclusao, titleVisibility: .visible) {
                Button("Apagar", role: .destructive) {
                    Task {
                        do {
                            try await agenda.apagar(item)
                            dismiss()
                        } catch {
                            erro = error.localizedDescription
                        }
                    }
                }
            }
            .alert("Não foi possível apagar", isPresented: Binding(get: { erro != nil }, set: { if !$0 { erro = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(erro ?? "")
            }
        }
    }
}

/// Editor nativo do iOS para ver, editar ou apagar um evento (as mudanças vão para o Google).
struct EventEditView: UIViewControllerRepresentable {
    let event: EKEvent
    let store: EKEventStore
    let onDone: () -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDone: () -> Void

        init(onDone: @escaping () -> Void) { self.onDone = onDone }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onDone()
        }
    }
}
