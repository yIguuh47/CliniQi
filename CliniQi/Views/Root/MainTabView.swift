//
//  MainTabView.swift
//  CliniQi
//

import SwiftUI

struct MainTabView: View {
    enum Tab: CaseIterable {
        case inicio, agenda, orcamentos, pacientes

        var title: String {
            switch self {
            case .inicio: "Início"
            case .agenda: "Agenda"
            case .orcamentos: "Orçamentos"
            case .pacientes: "Pacientes"
            }
        }

        var icon: String {
            switch self {
            case .inicio: "house.fill"
            case .agenda: "calendar"
            case .orcamentos: "doc.text"
            case .pacientes: "person.2"
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: Tab = .inicio
    @State private var isShowingOrcamento = false
    @State private var isShowingNovoMenu = false
    @State private var agenda = AgendaStore()
    @State private var novoAgendamentoData: Date?

    var body: some View {
        Group {
            switch selectedTab {
            case .inicio:
                HomeView(
                    onNovoOrcamento: { isShowingOrcamento = true },
                    onNovoAgendamento: { novoAgendamentoData = .now },
                    onVerAgenda: { selectedTab = .agenda }
                )
            case .agenda:
                AgendaView(onNovoAgendamento: { novoAgendamentoData = $0 })
            case .orcamentos, .pacientes:
                EmBreveView(title: selectedTab.title, icon: selectedTab.icon)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            tabBar
        }
        .fullScreenCover(isPresented: $isShowingOrcamento) {
            OrcamentoFormView(onClose: { isShowingOrcamento = false })
        }
        .confirmationDialog("Criar", isPresented: $isShowingNovoMenu) {
            Button("Novo Orçamento") { isShowingOrcamento = true }
            Button("Novo Agendamento") { novoAgendamentoData = .now }
            Button("Cancelar", role: .cancel) {}
        }
        .sheet(item: $novoAgendamentoData) { data in
            NovoAgendamentoView(dataInicial: data)
        }
        .environment(agenda)
        .onChange(of: scenePhase) { _, phase in
            // Ao voltar para o app, busca novidades do Google Agenda.
            if phase == .active { Task { await agenda.atualizar(.now) } }
        }
        .alert(
            "Agenda",
            isPresented: Binding(get: { agenda.erro != nil && selectedTab != .agenda }, set: { if !$0 { agenda.erro = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(agenda.erro ?? "")
        }
    }

    private var tabBar: some View {
        HStack(alignment: .bottom, spacing: 0) {
            tabButton(.inicio)
            tabButton(.agenda)

            Button {
                isShowingNovoMenu = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(Color.accentColor))
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 10, y: 4)
            }
            .offset(y: -14)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Criar")

            tabButton(.orcamentos)
            tabButton(.pacientes)
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 12, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(_ tab: Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22))
                    .frame(height: 26)
                Text(tab.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selectedTab == tab ? Color.accentColor : EMEBrand.accent)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct EmBreveView: View {
    let title: String
    let icon: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                title,
                systemImage: icon,
                description: Text("Em breve.")
            )
            .navigationTitle(title)
        }
    }
}

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}

#Preview {
    MainTabView()
}
