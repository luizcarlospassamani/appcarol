import CryptoKit
import Foundation

final class LocalPersistenceService {
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let databaseURL: URL
    private let sessionURL: URL

    init() {
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AppCarol", isDirectory: true)
        try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)

        databaseURL = baseURL.appendingPathComponent("database.json")
        sessionURL = baseURL.appendingPathComponent("session.json")
    }

    func loadDatabase() -> PersistedDatabase {
        guard let data = try? Data(contentsOf: databaseURL) else {
            return .empty
        }
        return (try? decoder.decode(PersistedDatabase.self, from: data)) ?? .empty
    }

    func saveDatabase(_ database: PersistedDatabase) {
        guard let data = try? encoder.encode(database) else { return }
        try? data.write(to: databaseURL, options: .atomic)
    }

    func loadSession() -> SessionState {
        guard let data = try? Data(contentsOf: sessionURL) else {
            return SessionState(currentUserID: nil)
        }
        return (try? decoder.decode(SessionState.self, from: data)) ?? SessionState(currentUserID: nil)
    }

    func saveSession(_ session: SessionState) {
        guard let data = try? encoder.encode(session) else { return }
        try? data.write(to: sessionURL, options: .atomic)
    }

    func hashPassword(_ password: String) -> String {
        let digest = SHA256.hash(data: Data(password.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
