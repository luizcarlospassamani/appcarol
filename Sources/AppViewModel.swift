import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var users: [AppUser] = []
    @Published private(set) var patients: [Patient] = []
    @Published private(set) var history: [PatientHistoryRecord] = []
    @Published var currentUser: AppUser?
    @Published var activeSheet: Patient?
    @Published var authErrorMessage: String?
    @Published var patientErrorMessage: String?
    @Published var notificationScheduler = NotificationScheduler()

    private let persistence = LocalPersistenceService()

    init() {
        let database = persistence.loadDatabase()
        users = database.users
        patients = database.patients
        history = database.history

        let session = persistence.loadSession()
        currentUser = users.first(where: { $0.id == session.currentUserID })
    }

    var activePatients: [Patient] {
        patients
            .filter { !$0.isDeleted && !$0.isResolved }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var resolvedPatients: [Patient] {
        patients
            .filter { !$0.isDeleted && $0.isResolved }
            .sorted { ($0.resolvedAt ?? .distantPast) > ($1.resolvedAt ?? .distantPast) }
    }

    func signIn(email: String, password: String) {
        guard !email.isEmpty, !password.isEmpty else {
            authErrorMessage = AppValidationError.missingFields.localizedDescription
            return
        }

        let hashed = persistence.hashPassword(password)
        guard let user = users.first(where: { $0.email.lowercased() == email.lowercased() && $0.passwordHash == hashed }) else {
            authErrorMessage = AppValidationError.invalidCredentials.localizedDescription
            return
        }

        currentUser = user
        authErrorMessage = nil
        persistSession()
    }

    func register(name: String, email: String, password: String) {
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty else {
            authErrorMessage = AppValidationError.missingFields.localizedDescription
            return
        }

        guard !users.contains(where: { $0.email.lowercased() == email.lowercased() }) else {
            authErrorMessage = AppValidationError.emailAlreadyExists.localizedDescription
            return
        }

        let user = AppUser(
            id: UUID().uuidString,
            fullName: name,
            email: email,
            passwordHash: persistence.hashPassword(password),
            createdAt: Date()
        )

        users.append(user)
        currentUser = user
        authErrorMessage = nil
        persistDatabase()
        persistSession()
    }

    func logout() {
        currentUser = nil
        persistSession()
    }

    func createPatient(from draft: PatientDraft) {
        guard let user = currentUser else { return }
        guard validatePatientDraft(draft) else { return }

        let patient = Patient(
            id: UUID().uuidString,
            name: draft.name,
            room: draft.room,
            sector: draft.sector,
            medication: draft.medication,
            createdAt: Date(),
            createdByUserID: user.id,
            updatedAt: Date(),
            updatedByUserID: user.id,
            isResolved: false,
            resolvedAt: nil,
            resolvedByUserID: nil,
            isDeleted: false
        )

        patients.append(patient)
        addHistoryEntries(for: patient, oldDraft: nil, newDraft: draft, userID: user.id)
        persistDatabase()
        notificationScheduler.rescheduleNotifications(for: patient)
        patientErrorMessage = nil
    }

    func updatePatient(_ patient: Patient, with draft: PatientDraft) {
        guard let user = currentUser else { return }
        guard validatePatientDraft(draft) else { return }
        guard let index = patients.firstIndex(where: { $0.id == patient.id }) else {
            patientErrorMessage = AppValidationError.patientNotFound.localizedDescription
            return
        }

        let original = patients[index]
        patients[index].name = draft.name
        patients[index].room = draft.room
        patients[index].sector = draft.sector
        patients[index].medication = draft.medication
        patients[index].updatedAt = Date()
        patients[index].updatedByUserID = user.id

        addHistoryEntries(for: patients[index], oldDraft: PatientDraft(patient: original), newDraft: draft, userID: user.id)
        persistDatabase()
        notificationScheduler.rescheduleNotifications(for: patients[index])
        patientErrorMessage = nil
    }

    func resolvePatient(_ patient: Patient) {
        guard let user = currentUser else { return }
        guard let index = patients.firstIndex(where: { $0.id == patient.id }) else { return }

        patients[index].isResolved = true
        patients[index].resolvedAt = Date()
        patients[index].resolvedByUserID = user.id
        patients[index].updatedAt = Date()
        patients[index].updatedByUserID = user.id

        history.append(
            PatientHistoryRecord(
                id: UUID().uuidString,
                patientID: patient.id,
                field: "status",
                oldValue: "Ativo",
                newValue: "Resolvido",
                changedAt: Date(),
                userID: user.id
            )
        )

        persistDatabase()
        notificationScheduler.cancelNotifications(for: patient.id)
    }

    func deletePatient(_ patient: Patient) throws {
        guard let user = currentUser else { return }
        guard patient.createdByUserID == user.id else {
            throw AppValidationError.deleteNotAllowed
        }
        guard let index = patients.firstIndex(where: { $0.id == patient.id }) else {
            throw AppValidationError.patientNotFound
        }

        patients[index].isDeleted = true
        patients[index].updatedAt = Date()
        patients[index].updatedByUserID = user.id

        history.append(
            PatientHistoryRecord(
                id: UUID().uuidString,
                patientID: patient.id,
                field: "deleted",
                oldValue: "false",
                newValue: "true",
                changedAt: Date(),
                userID: user.id
            )
        )

        persistDatabase()
        notificationScheduler.cancelNotifications(for: patient.id)
    }

    func historyRecords(for patientID: String? = nil, filters: ManagementFilters) -> [PatientHistoryRecord] {
        let scopedPatients = filteredPatients(filters: filters, includeResolved: true, includeDeleted: true)
        let allowedIDs = Set(scopedPatients.map(\.id))

        return history
            .filter { record in
                if let patientID, record.patientID != patientID {
                    return false
                }
                return allowedIDs.contains(record.patientID)
            }
            .sorted { $0.changedAt > $1.changedAt }
    }

    func userName(for id: String) -> String {
        users.first(where: { $0.id == id })?.fullName ?? "Usuário removido"
    }

    func filteredPatients(filters: ManagementFilters, includeResolved: Bool = false, includeDeleted: Bool = false) -> [Patient] {
        patients
            .filter { patient in
                if !includeDeleted && patient.isDeleted { return false }
                if !includeResolved && patient.isResolved { return false }
                if let room = filters.room, !room.isEmpty, patient.room != room { return false }
                if let sector = filters.sector, patient.sector != sector { return false }
                if let medication = filters.medication, patient.medication != medication { return false }
                return true
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func validatePatientDraft(_ draft: PatientDraft) -> Bool {
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !draft.room.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            patientErrorMessage = AppValidationError.missingFields.localizedDescription
            return false
        }
        return true
    }

    private func addHistoryEntries(for patient: Patient, oldDraft: PatientDraft?, newDraft: PatientDraft, userID: String) {
        let changes: [(String, String, String)] = [
            ("name", oldDraft?.name ?? "", newDraft.name),
            ("room", oldDraft?.room ?? "", newDraft.room),
            ("sector", oldDraft?.sector.rawValue ?? "", newDraft.sector.rawValue),
            ("medication", oldDraft?.medication.rawValue ?? "", newDraft.medication.rawValue)
        ]

        for change in changes where change.1 != change.2 {
            history.append(
                PatientHistoryRecord(
                    id: UUID().uuidString,
                    patientID: patient.id,
                    field: change.0,
                    oldValue: change.1,
                    newValue: change.2,
                    changedAt: Date(),
                    userID: userID
                )
            )
        }
    }

    private func persistDatabase() {
        persistence.saveDatabase(
            PersistedDatabase(
                users: users,
                patients: patients,
                history: history
            )
        )
    }

    private func persistSession() {
        persistence.saveSession(SessionState(currentUserID: currentUser?.id))
    }
}

struct ManagementFilters {
    var room: String?
    var sector: HospitalSector?
    var medication: MedicationType?
}
