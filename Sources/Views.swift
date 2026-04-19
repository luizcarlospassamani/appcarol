import Charts
import SwiftUI
import UserNotifications

struct RootView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        Group {
            if viewModel.currentUser == nil {
                LoginView()
            } else {
                MainTabView()
            }
        }
        .frame(minWidth: 1100, minHeight: 720)
    }
}

struct LoginView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var isRegisterMode = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.teal.opacity(0.9), Color.blue.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("AppCarol")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Gestão de pacientes, medicação e histórico com validação local no Mac.")
                        .foregroundStyle(.white.opacity(0.9))
                }

                VStack(alignment: .leading, spacing: 16) {
                    Picker("Modo", selection: $isRegisterMode) {
                        Text("Login").tag(false)
                        Text("Cadastro").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if isRegisterMode {
                        TextField("Nome completo", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    TextField("E-mail", text: $email)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Senha", text: $password)
                        .textFieldStyle(.roundedBorder)

                    if let message = viewModel.authErrorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button(isRegisterMode ? "Criar conta" : "Entrar") {
                        if isRegisterMode {
                            viewModel.register(name: name, email: email, password: password)
                        } else {
                            viewModel.signIn(email: email, password: password)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(28)
                .frame(width: 420)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .padding()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            PatientsView()
                .tabItem {
                    Label("Pacientes", systemImage: "cross.case")
                }

            ManagementView()
                .tabItem {
                    Label("Gerencial", systemImage: "chart.xyaxis.line")
                }
        }
    }
}

struct PatientsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showingNewPatientSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                notificationBanner

                if let message = viewModel.patientErrorMessage {
                    Text(message)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .foregroundStyle(.red)
                }

                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.activePatients) { patient in
                            PatientCard(patient: patient)
                        }

                        if viewModel.activePatients.isEmpty {
                            ContentUnavailableView(
                                "Nenhum paciente ativo",
                                systemImage: "bed.double",
                                description: Text("Cadastre um paciente para iniciar os lembretes de medicação.")
                            )
                            .padding(.top, 60)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Pacientes")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Novo paciente") {
                        showingNewPatientSheet = true
                    }

                    Button("Logout") {
                        viewModel.logout()
                    }
                }
            }
            .sheet(isPresented: $showingNewPatientSheet) {
                PatientEditorView(mode: .create, patient: nil)
            }
            .task {
                await viewModel.notificationScheduler.requestPermissionIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var notificationBanner: some View {
        switch viewModel.notificationScheduler.authorizationStatus {
        case .authorized, .provisional:
            Label("Notificações locais autorizadas", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
        case .denied:
            Label("Permissão de notificação negada. Ative nas configurações para validar os alertas.", systemImage: "bell.slash.fill")
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
        default:
            Label("Solicitando permissão para notificações locais...", systemImage: "bell.badge")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
        }
    }
}

struct PatientCard: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let patient: Patient

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(patient.name)
                        .font(.title3.bold())
                    Text("Quarto \(patient.room)")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(patient.sector.rawValue)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.12), in: Capsule())
            }

            HStack {
                Label(patient.medication.rawValue, systemImage: "pills.fill")
                Spacer()
                Text("Intervalo \(patient.medication.intervalLabel)")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            HStack {
                Button("Editar") {
                    viewModel.activeSheet = patient
                }
                .buttonStyle(.bordered)

                Button("Resolvido") {
                    viewModel.resolvePatient(patient)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.teal.opacity(0.28), lineWidth: 1.5)
        )
        .sheet(item: $viewModel.activeSheet) { patient in
            PatientEditorView(mode: .edit, patient: patient)
        }
    }
}

struct PatientEditorView: View {
    enum Mode {
        case create
        case edit
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AppViewModel

    let mode: Mode
    let patient: Patient?

    @State private var draft = PatientDraft()
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Dados do paciente") {
                    TextField("Nome do paciente", text: $draft.name)
                    TextField("Quarto", text: $draft.room)
                    Picker("Setor", selection: $draft.sector) {
                        ForEach(HospitalSector.allCases) { sector in
                            Text(sector.rawValue).tag(sector)
                        }
                    }
                    Picker("Medicação", selection: $draft.medication) {
                        ForEach(MedicationType.allCases) { medication in
                            Text("\(medication.rawValue) (\(medication.intervalLabel))").tag(medication)
                        }
                    }
                }

                if let patient {
                    Section("Histórico recente") {
                        ForEach(viewModel.historyRecords(for: patient.id, filters: ManagementFilters()).prefix(6)) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(record.field): \(record.oldValue) -> \(record.newValue)")
                                    .font(.subheadline.weight(.medium))
                                Text("\(viewModel.userName(for: record.userID)) • \(record.changedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                if let deleteError {
                    Section {
                        Text(deleteError)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(mode == .create ? "Novo paciente" : "Editar paciente")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        save()
                    }
                }

                if mode == .edit, let patient {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Excluir") {
                            do {
                                try viewModel.deletePatient(patient)
                                dismiss()
                            } catch {
                                deleteError = error.localizedDescription
                            }
                        }
                    }
                }
            }
            .onAppear {
                if let patient {
                    draft = PatientDraft(patient: patient)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 520)
    }

    private func save() {
        switch mode {
        case .create:
            viewModel.createPatient(from: draft)
            if viewModel.patientErrorMessage == nil {
                dismiss()
            }
        case .edit:
            if let patient {
                viewModel.updatePatient(patient, with: draft)
                if viewModel.patientErrorMessage == nil {
                    dismiss()
                }
            }
        }
    }
}

struct ManagementView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var filters = ManagementFilters()

    private var filteredPatients: [Patient] {
        viewModel.filteredPatients(filters: filters, includeResolved: true)
    }

    private var chartData: [(Date, Int)] {
        let grouped = Dictionary(grouping: filteredPatients) {
            Calendar.current.startOfDay(for: $0.createdAt)
        }
        return grouped
            .map { ($0.key, $0.value.count) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    filterPanel
                    chartPanel
                    historyPanel
                }
                .padding()
            }
            .navigationTitle("Tela gerencial")
        }
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Filtros")
                .font(.title3.bold())

            HStack {
                TextField("Quarto", text: Binding(
                    get: { filters.room ?? "" },
                    set: { filters.room = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)

                Picker("Setor", selection: Binding(
                    get: { filters.sector },
                    set: { filters.sector = $0 }
                )) {
                    Text("Todos").tag(HospitalSector?.none)
                    ForEach(HospitalSector.allCases) { sector in
                        Text(sector.rawValue).tag(HospitalSector?.some(sector))
                    }
                }

                Picker("Medicação", selection: Binding(
                    get: { filters.medication },
                    set: { filters.medication = $0 }
                )) {
                    Text("Todas").tag(MedicationType?.none)
                    ForEach(MedicationType.allCases) { medication in
                        Text(medication.rawValue).tag(MedicationType?.some(medication))
                    }
                }
            }
        }
        .padding(20)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var chartPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pacientes por dia")
                .font(.title3.bold())

            Chart(chartData, id: \.0) { item in
                BarMark(
                    x: .value("Dia", item.0, unit: .day),
                    y: .value("Pacientes", item.1)
                )
                .foregroundStyle(.teal.gradient)
            }
            .frame(height: 260)

            if chartData.isEmpty {
                Text("Os filtros atuais não retornaram pacientes.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Histórico completo")
                .font(.title3.bold())

            ForEach(viewModel.historyRecords(filters: filters)) { record in
                if let patient = viewModel.filteredPatients(filters: filters, includeResolved: true, includeDeleted: true)
                    .first(where: { $0.id == record.patientID }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(patient.name) • \(record.field)")
                            .font(.headline)
                        Text("De: \(record.oldValue.isEmpty ? "vazio" : record.oldValue)")
                        Text("Para: \(record.newValue.isEmpty ? "vazio" : record.newValue)")
                        Text("\(viewModel.userName(for: record.userID)) • \(record.changedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)

                    Divider()
                }
            }
        }
        .padding(20)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
