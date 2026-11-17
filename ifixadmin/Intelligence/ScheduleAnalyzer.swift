//
//  ScheduleAnalyzer.swift
//  ifixadmin
//
//  Análises locais em cima da agenda: conflitos, buracos livres e resumo do dia.
//

import Foundation
import SwiftData

struct FreeSlot: Identifiable {
    let start: Date
    let end: Date

    var id: Date { start }
    var minutes: Int { Int(end.timeIntervalSince(start) / 60) }
}

struct DaySummary {
    var eventCount: Int
    var busyMinutes: Int
    var freeMinutes: Int
    var conflictCount: Int
    var dominantCategory: EventCategory?

    var isEmpty: Bool { eventCount == 0 }
}

enum ScheduleAnalyzer {
    /// Início e fim do "dia útil" considerado ao procurar horários livres.
    static let dayStartHour = 8
    static let dayEndHour = 22
    /// Buracos menores que isso não são sugeridos.
    static let minimumSlotMinutes = 30

    static func events(_ events: [CalendarEvent], on day: Date, calendar: Calendar = .current) -> [CalendarEvent] {
        events
            .filter { calendar.isDate($0.startDate, inSameDayAs: day) }
            .sorted { $0.startDate < $1.startDate }
    }

    /// IDs dos compromissos que se sobrepõem a pelo menos um outro.
    static func conflictingIDs(in events: [CalendarEvent]) -> Set<PersistentIdentifier> {
        var result: Set<PersistentIdentifier> = []
        let sorted = events.sorted { $0.startDate < $1.startDate }
        for (index, event) in sorted.enumerated() {
            for other in sorted[(index + 1)...] {
                // Ordenado por início: se este já começa depois do fim,
                // nenhum dos seguintes vai sobrepor.
                guard other.startDate < event.endDate else { break }
                if event.overlaps(other) {
                    result.insert(event.persistentModelID)
                    result.insert(other.persistentModelID)
                }
            }
        }
        return result
    }

    /// Espaços vagos do dia, já descontando os compromissos existentes.
    static func freeSlots(
        on day: Date,
        events: [CalendarEvent],
        calendar: Calendar = .current
    ) -> [FreeSlot] {
        let dayEvents = self.events(events, on: day, calendar: calendar)
        guard
            let windowStart = calendar.date(bySettingHour: dayStartHour, minute: 0, second: 0, of: day),
            let windowEnd = calendar.date(bySettingHour: dayEndHour, minute: 0, second: 0, of: day)
        else { return [] }

        var slots: [FreeSlot] = []
        var cursor = windowStart

        for event in dayEvents {
            if event.startDate > cursor {
                append(&slots, from: cursor, to: min(event.startDate, windowEnd))
            }
            cursor = max(cursor, event.endDate)
            if cursor >= windowEnd { break }
        }
        if cursor < windowEnd {
            append(&slots, from: cursor, to: windowEnd)
        }
        return slots
    }

    private static func append(_ slots: inout [FreeSlot], from start: Date, to end: Date) {
        guard end > start else { return }
        let slot = FreeSlot(start: start, end: end)
        guard slot.minutes >= minimumSlotMinutes else { return }
        slots.append(slot)
    }

    /// Primeiro horário livre capaz de acomodar a duração pedida.
    static func firstSlot(
        fitting minutes: Int,
        on day: Date,
        events: [CalendarEvent],
        calendar: Calendar = .current
    ) -> FreeSlot? {
        freeSlots(on: day, events: events, calendar: calendar)
            .first { $0.minutes >= minutes }
    }

    static func summary(for day: Date, events: [CalendarEvent], calendar: Calendar = .current) -> DaySummary {
        let dayEvents = self.events(events, on: day, calendar: calendar)
        let busy = dayEvents.reduce(0) { $0 + $1.durationMinutes }
        let free = freeSlots(on: day, events: events, calendar: calendar)
            .reduce(0) { $0 + $1.minutes }

        let counts = Dictionary(grouping: dayEvents, by: \.category)
            .mapValues(\.count)
        let dominant = counts.max { lhs, rhs in
            lhs.value == rhs.value ? lhs.key.rawValue > rhs.key.rawValue : lhs.value < rhs.value
        }?.key

        return DaySummary(
            eventCount: dayEvents.count,
            busyMinutes: busy,
            freeMinutes: free,
            conflictCount: conflictingIDs(in: dayEvents).count,
            dominantCategory: dayEvents.isEmpty ? nil : dominant
        )
    }
}

extension Int {
    /// 90 -> "1h30", 45 -> "45min", 120 -> "2h"
    var asDurationText: String {
        let hours = self / 60
        let minutes = self % 60
        switch (hours, minutes) {
        case (0, let m): return "\(m)min"
        case (let h, 0): return "\(h)h"
        case (let h, let m): return "\(h)h\(String(format: "%02d", m))"
        }
    }
}
