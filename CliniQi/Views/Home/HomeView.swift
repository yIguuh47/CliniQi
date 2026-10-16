//
//  HomeView.swift
//  CliniQi
//

import SwiftUI

struct HomeView: View {
    var onNovoOrcamento: () -> Void
    var onNovoAgendamento: () -> Void
    var onVerAgenda: () -> Void = {}

    var profissional = HomeSampleData.profissional
    var orcamentos = HomeSampleData.orcamentosRecentes

    @Environment(AgendaStore.self) private var agenda

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                quickActions
                agendaSection
                orcamentosSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .refreshable { await agenda.atualizar(.now) }
        .task(id: agenda.fonte) { await agenda.carregar(.now) }
        .background(Color(.systemGroupedBackground))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Olá, \(profissional)")
                    .font(.system(size: 30, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Que bom ver você de volta!")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            HStack(spacing: 16) {
                avatar
                Button {} label: {
                    Image(systemName: "bell")
                        .font(.system(size: 20))
                        .foregroundStyle(EMEBrand.ink)
                }
                .accessibilityLabel("Notificações")
            }
        }
    }

    private var avatar: some View {
        Text(iniciais)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(EMEBrand.ink)
            .frame(width: 44, height: 44)
            .background(Circle().fill(EMEBrand.sand))
            .overlay(Circle().strokeBorder(EMEBrand.accent, lineWidth: 2).padding(-3))
    }

    private var iniciais: String {
        let nome = profissional
            .replacingOccurrences(of: "Dra. ", with: "")
            .replacingOccurrences(of: "Dr. ", with: "")
        return nome.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            QuickActionCard(
                icon: "doc",
                iconColor: EMEBrand.accent,
                title: "Novo Orçamento",
                subtitle: "Criar orçamento personalizado rápido",
                action: onNovoOrcamento
            )
            QuickActionCard(
                icon: "calendar",
                iconColor: .accentColor,
                title: "Novo Agendamento",
                subtitle: "Marcar nova consulta ou retorno",
                action: onNovoAgendamento
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var agendaSection: some View {
        let hoje = agenda.agendamentos(on: .now)

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Agenda de Hoje", action: onVerAgenda)

            if agenda.fonte == .nenhuma {
                AgendaAccessCard()
            } else if hoje.isEmpty {
                Text(agenda.jaCarregou(.now) ? "Nenhuma consulta para hoje." : "Carregando agenda…")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
            } else {
                ForEach(hoje) { item in
                    Button(action: onVerAgenda) {
                        AgendamentoRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var orcamentosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Orçamentos Recentes")
            ForEach(orcamentos) { item in
                OrcamentoResumoRow(item: item)
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
            Spacer()
            Button("Ver todos", action: action)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
        }
    }
}

private struct QuickActionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(iconColor))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(EMEBrand.paper)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct OrcamentoResumoRow: View {
    let item: OrcamentoResumo

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(item.paciente) - \(item.mesAno)")
                    .font(.system(size: 17, weight: .medium))

                HStack(spacing: 6) {
                    chip(item.status.rawValue, background: EMEBrand.sand)
                    if item.pdfGerado {
                        chip("Gerado", background: Color(.systemGray5))
                    }
                }

                Text(CurrencyFormatter.currency(item.valor))
                    .font(.system(size: 17))
            }
            Spacer()
            Image(systemName: "doc.richtext")
                .font(.system(size: 26))
                .foregroundStyle(EMEBrand.accent)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func chip(_ text: String, background: Color) -> some View {
        Text(text)
            .font(.system(size: 13))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(background))
    }
}

#Preview {
    HomeView(onNovoOrcamento: {}, onNovoAgendamento: {})
        .environment(AgendaStore())
}
