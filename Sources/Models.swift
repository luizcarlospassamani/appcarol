import Foundation

struct AppUser: Identifiable, Codable, Hashable {
    let id: String
    var fullName: String
    var email: String
    var passwordHash: String
    let createdAt: Date
}

enum HospitalSector: String, Codable, CaseIterable, Identifiable {
    case admissao = "Admissão"
    case preParto = "Pré-parto"
    case enfermaria = "Enfermaria"
    case centroCirurgico = "Centro cirúrgico"
    case pendenciasGerais = "Pendências gerais"

    var id: String { rawValue }
}

enum MedicationType: String, Codable, CaseIterable, Identifiable {
    case misoprostol = "Misoprostol"
    case bcf = "BCF"
    case ctg = "CTG"
    case teste = "Teste"

    var id: String { rawValue }

    var interval: TimeInterval {
        switch self {
        case .misoprostol:
            return 4 * 60 * 60
        case .bcf:
            return 60 * 60
        case .ctg:
            return 3 * 60 * 60
        case .teste:
            return 60
        }
    }

    var intervalLabel: String {
        switch self {
        case .misoprostol:
            return "4h"
        case .bcf:
            return "1h"
        case .ctg:
            return "3h"
        case .teste:
            return "1 min"
        }
    }
}

struct Patient: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var room: String
    var sector: HospitalSector
    var medication: MedicationType
    let createdAt: Date
    let createdByUserID: String
    var updatedAt: Date
    var updatedByUserID: String
    var isResolved: Bool
    var resolvedAt: Date?
    var resolvedByUserID: String?
    var isDeleted: Bool
}

struct PatientHistoryRecord: Identifiable, Codable, Hashable {
    let id: String
    let patientID: String
    let field: String
    let oldValue: String
    let newValue: String
    let changedAt: Date
    let userID: String
}

struct SessionState: Codable {
    var currentUserID: String?
}

struct PersistedDatabase: Codable {
    var users: [AppUser]
    var patients: [Patient]
    var history: [PatientHistoryRecord]

    static let empty = PersistedDatabase(users: [], patients: [], history: [])
}

struct PatientDraft {
    var name: String = ""
    var room: String = ""
    var sector: HospitalSector = .admissao
    var medication: MedicationType = .misoprostol

    init() {}

    init(patient: Patient) {
        name = patient.name
        room = patient.room
        sector = patient.sector
        medication = patient.medication
    }
}

enum AppValidationError: LocalizedError {
    case invalidCredentials
    case emailAlreadyExists
    case missingFields
    case patientNotFound
    case deleteNotAllowed

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "E-mail ou senha inválidos."
        case .emailAlreadyExists:
            return "Já existe um cadastro com este e-mail."
        case .missingFields:
            return "Preencha todos os campos obrigatórios."
        case .patientNotFound:
            return "Paciente não encontrado."
        case .deleteNotAllowed:
            return "A exclusão só pode ser feita pelo usuário que criou o paciente."
        }
    }
}
