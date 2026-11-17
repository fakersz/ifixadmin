//
//  CalendarEvent.swift
//  ifixadmin
//

import Foundation
import SwiftData

@Model
final class CalendarEvent {
    var title: String
    var startDate: Date
    var durationMinutes: Int
    var notes: String
    var isDone: Bool
    var createdAt: Date

    /// Identificador estável da notificação. Não dá para usar
    /// `persistentModelID`: ele muda de temporário para definitivo ao salvar,
    /// e aí o cancelamento erraria o alvo.
    var notificationID: String = UUID().uuidString

    /// A categoria é guardada como `String` para manter o schema do SwiftData
    /// estável mesmo que novos casos sejam adicionados ao enum depois.
    private var categoryRaw: String

    init(
        title: String,
        startDate: Date,
        durationMinutes: Int = 60,
        notes: String = "",
        category: EventCategory = .other,
        isDone: Bool = false
    ) {
        self.title = title
        self.startDate = startDate
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.categoryRaw = category.rawValue
        self.isDone = isDone
        self.createdAt = .now
        self.notificationID = UUID().uuidString
    }

    var category: EventCategory {
        get { EventCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var endDate: Date {
        startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    /// Dois compromissos conflitam quando se sobrepõem no tempo.
    /// Encostar (um termina exatamente quando o outro começa) não é conflito.
    func overlaps(_ other: CalendarEvent) -> Bool {
        guard other.persistentModelID != persistentModelID else { return false }
        return startDate < other.endDate && other.startDate < endDate
    }
}
