//
//  OrcamentoFormView.swift
//  CliniQi
//

import SwiftUI

struct OrcamentoFormView: View {
    @State private var viewModel = OrcamentoFormViewModel()
    @State private var generatedPDFURL: URL?
    @State private var isSharing = false
    @State private var selectedTab: FormTab = .formulario

    private let brazilianCurrency = FloatingPointFormatStyle<Double>.Currency(code: "BRL")
        .locale(Locale(identifier: "pt_BR"))

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Seção", selection: $selectedTab) {
                    ForEach(FormTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Group {
                    switch selectedTab {
                    case .formulario:
                        formContent
                    case .previa:
                        previewContent
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Orçamento")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                generateButton
            }
            .alert(
                "Não foi possível gerar",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $isSharing) {
                if let generatedPDFURL {
                    ShareSheet(items: [generatedPDFURL]) {
                        isSharing = false
                    }
                    .ignoresSafeArea()
                    .presentationDetents([.medium, .large])
                }
            }
        }
    }
}

private extension OrcamentoFormView {
    enum FormTab: String, CaseIterable, Identifiable {
        case formulario
        case previa

        var id: String { rawValue }

        var title: String {
            switch self {
            case .formulario: "Formulário"
            case .previa: "Prévia"
            }
        }
    }

    var formContent: some View {
        let model = Bindable(viewModel)

        return Form {
            Section("Paciente") {
                TextField("Nome da paciente", text: model.nomePaciente)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)

                TextField("Mês / Ano", text: model.mesAno)
                    .textInputAutocapitalization(.words)
            }

            PlanoEditorSection(
                title: "Plano A",
                draft: model.planoA,
                currencyStyle: brazilianCurrency
            )

            PlanoEditorSection(
                title: "Plano B",
                draft: model.planoB,
                currencyStyle: brazilianCurrency
            )
        }
    }

    var previewContent: some View {
        ScrollView {
            VStack(spacing: 28) {
                pagePreview(title: viewModel.orcamento.planoA.titulo.uppercased()) {
                    OrcamentoPageView(
                        nomePaciente: viewModel.orcamento.nomePaciente,
                        mesAno: viewModel.orcamento.mesAno,
                        plano: viewModel.orcamento.planoA,
                        pageIndex: 0
                    )
                }
                pagePreview(title: viewModel.orcamento.planoB.titulo.uppercased()) {
                    OrcamentoPageView(
                        nomePaciente: viewModel.orcamento.nomePaciente,
                        mesAno: viewModel.orcamento.mesAno,
                        plano: viewModel.orcamento.planoB,
                        pageIndex: 1
                    )
                }
                pagePreview(title: "MARCA") {
                    TemplatePageBackground(pageIndex: 2)
                        .frame(width: EMETemplate.pageSize.width, height: EMETemplate.pageSize.height)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    func pagePreview<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        let page = content()

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .tracking(1.2)

            GeometryReader { proxy in
                let scale = proxy.size.width / EMETemplate.pageSize.width

                page
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(
                        width: EMETemplate.pageSize.width * scale,
                        height: EMETemplate.pageSize.height * scale,
                        alignment: .topLeading
                    )
            }
            .aspectRatio(
                EMETemplate.pageSize.width / EMETemplate.pageSize.height,
                contentMode: .fit
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        }
    }

    var generateButton: some View {
        Button {
            generateAndShare()
        } label: {
            Label("Gerar e Exportar PDF", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    func generateAndShare() {
        guard let url = viewModel.generatePDF() else { return }
        generatedPDFURL = url
        isSharing = true
    }
}

struct PlanoEditorSection: View {
    let title: String
    @Binding var draft: PlanoDraft
    let currencyStyle: FloatingPointFormatStyle<Double>.Currency

    var body: some View {
        Section(title) {
            TextField("Título", text: $draft.titulo)
            TextField("Descrição do plano", text: $draft.subtitulo, axis: .vertical)
                .lineLimit(2...4)

            ForEach($draft.procedimentos) { $procedimento in
                HStack(alignment: .top) {
                    TextField("Procedimento", text: $procedimento.texto, axis: .vertical)
                        .lineLimit(2...5)

                    if draft.procedimentos.count > 1 {
                        Button(role: .destructive) {
                            draft.procedimentos.removeAll { $0.id == procedimento.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remover procedimento")
                    }
                }
            }

            Button {
                draft.procedimentos.append(ProcedimentoDraft(texto: ""))
            } label: {
                Label("Adicionar procedimento", systemImage: "plus")
            }

            TextField("Foco do tratamento", text: $draft.focoTratamento, axis: .vertical)
                .lineLimit(2...4)

            Stepper(value: $draft.numParcelas, in: 1...24) {
                Text("Parcelas: \(draft.numParcelas)x")
            }

            TextField("Valor da parcela", value: $draft.valorParcela, format: currencyStyle)
                .keyboardType(.decimalPad)

            TextField("Valor no Pix", value: $draft.valorPix, format: currencyStyle)
                .keyboardType(.decimalPad)
        }
    }
}

#Preview {
    OrcamentoFormView()
}
