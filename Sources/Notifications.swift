import Foundation
import UserNotifications

@MainActor
final class NotificationScheduler: ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    init() {
        refreshSettings()
    }

    func requestPermissionIfNeeded() async {
        refreshSettings()
        guard authorizationStatus == .notDetermined else { return }
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            authorizationStatus = granted ? .authorized : .denied
        } catch {
            authorizationStatus = .denied
        }
    }

    func refreshSettings() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    func rescheduleNotifications(for patient: Patient) {
        cancelNotifications(for: patient.id)
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }

        let leadCount = patient.medication == .teste ? 20 : 8
        let now = Date()
        let center = UNUserNotificationCenter.current()

        for offset in 1...leadCount {
            let triggerDate = now.addingTimeInterval(patient.medication.interval * Double(offset))
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: triggerDate
            )

            let content = UNMutableNotificationContent()
            content.title = "Paciente \(patient.name)"
            content.body = "\(patient.medication.rawValue) | Quarto \(patient.room)"
            content.sound = .default
            content.threadIdentifier = patient.id

            let request = UNNotificationRequest(
                identifier: notificationIdentifier(for: patient.id, index: offset),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )

            center.add(request)
        }
    }

    func cancelNotifications(for patientID: String) {
        let identifiers = (1...24).map { notificationIdentifier(for: patientID, index: $0) }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func notificationIdentifier(for patientID: String, index: Int) -> String {
        "\(patientID)-notification-\(index)"
    }
}
