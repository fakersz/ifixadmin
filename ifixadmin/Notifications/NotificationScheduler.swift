//
//  NotificationScheduler.swift
//  ifixadmin
//

import Foundation
import UserNotifications

enum NotificationScheduler {

    // MARK: - Texto da notificação
    //
    // Genérico de propósito: nada do compromisso aparece na tela bloqueada.
    // Para mostrar o título real, troque `body` por `event.title` em `schedule`.

    static let genericTitle = "Lembrete"
    static let genericBody = "Você tem um compromisso chegando."

    /// Quantos minutos antes do início a notificação dispara.
    static let leadMinutes = 15

    // MARK: - Permissão

    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    // MARK: - Quando disparar

    /// Momento em que a notificação deve tocar, ou `nil` quando já passou.
    ///
    /// Se faltar menos que `leadMinutes` para o compromisso, avisa na hora
    /// exata do início em vez de desistir do lembrete.
    static func fireDate(
        forEventStartingAt start: Date,
        now: Date = .now,
        leadMinutes: Int = leadMinutes
    ) -> Date? {
        guard start > now else { return nil }
        let early = start.addingTimeInterval(TimeInterval(-leadMinutes * 60))
        return early > now ? early : start
    }

    // MARK: - Agendar / cancelar

    static func schedule(for event: CalendarEvent) async {
        cancel(for: event)

        guard !event.isDone,
              let fireDate = fireDate(forEventStartingAt: event.startDate)
        else { return }

        guard await isAuthorized() else { return }

        let content = UNMutableNotificationContent()
        content.title = genericTitle
        content.body = genericBody
        content.sound = .default

        if let coverURL = CoverImage.url(),
           let attachment = try? UNNotificationAttachment(
               identifier: "cover", url: coverURL, options: nil
           ) {
            content.attachments = [attachment]
        }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: event.notificationID, content: content, trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancel(for event: CalendarEvent) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [event.notificationID])
    }

    /// Reagenda tudo de uma vez — útil depois de recuperar a permissão.
    static func rescheduleAll(_ events: [CalendarEvent]) async {
        for event in events {
            await schedule(for: event)
        }
    }
}

// MARK: - Notificação com o app aberto

/// Sem isso o iOS engole a notificação enquanto o app está em primeiro plano,
/// o que torna o teste bem mais chato.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func register() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
