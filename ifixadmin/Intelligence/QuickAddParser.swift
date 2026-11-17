//
//  QuickAddParser.swift
//  ifixadmin
//
//  Interpreta frases em português ("Dentista amanhã às 15h por 30min")
//  e devolve um compromisso pronto para salvar.
//

import Foundation

struct ParsedEvent {
    var title: String
    var startDate: Date
    var durationMinutes: Int
    var category: EventCategory
    /// `true` quando o texto trazia dia explícito ("amanhã", "sexta", "12/08").
    var foundExplicitDay: Bool
    /// `true` quando o texto trazia horário explícito ("15h", "às 9", "meio-dia").
    var foundExplicitTime: Bool
}

enum QuickAddParser {
    static let defaultDurationMinutes = 60
    /// Horário usado quando o usuário diz o dia mas não a hora.
    static let defaultHour = 9

    static func parse(
        _ input: String,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ParsedEvent? {
        let words = input.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return nil }

        let keys = words.map(normalize)
        var consumed = Set<Int>()

        let duration = parseDuration(keys, consumed: &consumed) ?? defaultDurationMinutes
        let time = parseTime(keys, consumed: &consumed)
        let day = parseDay(keys, consumed: &consumed, now: now, calendar: calendar)

        let title = words.enumerated()
            .filter { !consumed.contains($0.offset) }
            .map(\.element)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-,;:"))
            .trimmingCharacters(in: .whitespaces)

        guard !title.isEmpty else { return nil }

        let start = resolveStart(day: day, time: time, now: now, calendar: calendar)

        return ParsedEvent(
            title: title.prefix(1).uppercased() + title.dropFirst(),
            startDate: start,
            durationMinutes: duration,
            category: .inferred(from: title),
            foundExplicitDay: day != nil,
            foundExplicitTime: time != nil
        )
    }

    // MARK: - Montagem da data final

    private static func resolveStart(
        day: Date?,
        time: (hour: Int, minute: Int)?,
        now: Date,
        calendar: Calendar
    ) -> Date {
        let baseDay = day ?? calendar.startOfDay(for: now)

        guard let time else {
            // Sem hora: se o dia é hoje, joga para a próxima hora cheia.
            // Se é um dia futuro, usa o horário padrão da manhã.
            if calendar.isDate(baseDay, inSameDayAs: now) {
                return nextRoundHour(after: now, calendar: calendar)
            }
            return calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: baseDay) ?? baseDay
        }

        let candidate = calendar.date(
            bySettingHour: time.hour, minute: time.minute, second: 0, of: baseDay
        ) ?? baseDay

        // "às 15h" digitado às 18h, sem dizer o dia, quer dizer amanhã.
        if day == nil, candidate <= now {
            return calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    private static func nextRoundHour(after date: Date, calendar: Calendar) -> Date {
        let next = calendar.date(byAdding: .hour, value: 1, to: date) ?? date
        return calendar.date(bySettingHour: calendar.component(.hour, from: next),
                             minute: 0, second: 0, of: next) ?? next
    }

    // MARK: - Duração

    /// Só considera duração quando vem precedida de "por" ou "durante",
    /// para não confundir "às 2h" (horário) com "por 2h" (duração).
    private static func parseDuration(_ keys: [String], consumed: inout Set<Int>) -> Int? {
        for index in keys.indices where keys[index] == "por" || keys[index] == "durante" {
            let next = index + 1
            guard next < keys.count, !consumed.contains(next),
                  let minutes = durationValue(keys[next]) else { continue }
            consumed.insert(index)
            consumed.insert(next)
            return minutes
        }
        return nil
    }

    /// "2h", "1h30", "45min", "90m", "2horas", "30minutos"
    private static func durationValue(_ key: String) -> Int? {
        if let range = key.range(of: "min") {
            guard let value = Int(key[key.startIndex..<range.lowerBound]) else { return nil }
            return value
        }
        if let range = key.range(of: "h") {
            guard let hours = Int(key[key.startIndex..<range.lowerBound]) else { return nil }
            let rest = key[range.upperBound...].prefix(while: \.isNumber)
            let minutes = rest.isEmpty ? 0 : (Int(rest) ?? 0)
            return hours * 60 + minutes
        }
        if key.hasSuffix("m"), let value = Int(key.dropLast()) { return value }
        return nil
    }

    // MARK: - Horário

    private static func parseTime(_ keys: [String], consumed: inout Set<Int>) -> (hour: Int, minute: Int)? {
        // 1) "as 15", "às 15h30" — o marcador libera números soltos.
        for index in keys.indices where keys[index] == "as" || keys[index] == "ao" {
            let next = index + 1
            guard next < keys.count, !consumed.contains(next),
                  let clock = clockValue(keys[next], allowBareNumber: true) else { continue }
            consumed.insert(index)
            consumed.insert(next)
            return clock
        }

        // 2) Palavras fixas.
        for index in keys.indices where !consumed.contains(index) {
            if keys[index].hasPrefix("meio") && keys[index].contains("dia") {
                consumed.insert(index)
                return (12, 0)
            }
            if keys[index].hasPrefix("meia") && keys[index].contains("noite") {
                consumed.insert(index)
                return (0, 0)
            }
        }

        // 3) Token com marcador próprio: "15h", "15h30", "15:30".
        for index in keys.indices where !consumed.contains(index) {
            guard let clock = clockValue(keys[index], allowBareNumber: false) else { continue }
            consumed.insert(index)
            return clock
        }

        // 4) Período do dia, como último recurso.
        for index in keys.indices where !consumed.contains(index) {
            switch keys[index] {
            case "manha", "cedo": consumed.insert(index); return (9, 0)
            case "tarde": consumed.insert(index); return (14, 0)
            case "noite": consumed.insert(index); return (19, 0)
            default: continue
            }
        }

        return nil
    }

    /// Converte "15h", "15h30", "15:30" e (opcionalmente) "15" em hora/minuto.
    private static func clockValue(_ key: String, allowBareNumber: Bool) -> (hour: Int, minute: Int)? {
        func validated(_ hour: Int, _ minute: Int) -> (Int, Int)? {
            guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
            return (hour, minute)
        }

        if key.contains(":") {
            let parts = key.split(separator: ":")
            guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
            return validated(hour, minute)
        }
        if let range = key.range(of: "h") {
            guard let hour = Int(key[key.startIndex..<range.lowerBound]) else { return nil }
            let rest = key[range.upperBound...].prefix(while: \.isNumber)
            let minute = rest.isEmpty ? 0 : (Int(rest) ?? 0)
            return validated(hour, minute)
        }
        if allowBareNumber, let hour = Int(key) {
            return validated(hour, 0)
        }
        return nil
    }

    // MARK: - Dia

    private static let weekdays: [(prefix: String, index: Int)] = [
        ("domingo", 1), ("segunda", 2), ("terca", 3), ("quarta", 4),
        ("quinta", 5), ("sexta", 6), ("sabado", 7)
    ]

    private static let months: [String: Int] = [
        "janeiro": 1, "fevereiro": 2, "marco": 3, "abril": 4, "maio": 5, "junho": 6,
        "julho": 7, "agosto": 8, "setembro": 9, "outubro": 10, "novembro": 11, "dezembro": 12
    ]

    private static func parseDay(
        _ keys: [String],
        consumed: inout Set<Int>,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        let today = calendar.startOfDay(for: now)

        // "depois de amanha" precisa ser testado antes de "amanha".
        for index in keys.indices where !consumed.contains(index) {
            guard keys[index] == "depois", index + 2 < keys.count,
                  keys[index + 1] == "de", keys[index + 2] == "amanha" else { continue }
            consumed.formUnion([index, index + 1, index + 2])
            return calendar.date(byAdding: .day, value: 2, to: today)
        }

        for index in keys.indices where !consumed.contains(index) {
            switch keys[index] {
            case "hoje":
                consumed.insert(index)
                return today
            case "amanha":
                consumed.insert(index)
                return calendar.date(byAdding: .day, value: 1, to: today)
            default:
                continue
            }
        }

        // Dias da semana: sempre a próxima ocorrência.
        for index in keys.indices where !consumed.contains(index) {
            guard let match = weekdays.first(where: { keys[index].hasPrefix($0.prefix) }) else { continue }
            consumed.insert(index)
            // Absorve o "feira" de "segunda-feira" escrito separado.
            if index + 1 < keys.count, keys[index + 1] == "feira" {
                consumed.insert(index + 1)
            }
            return nextOccurrence(ofWeekday: match.index, from: today, calendar: calendar)
        }

        // "dia 12", "12 de agosto", "12/08"
        for index in keys.indices where !consumed.contains(index) {
            if keys[index] == "dia", index + 1 < keys.count, let dayNumber = Int(keys[index + 1]) {
                consumed.formUnion([index, index + 1])
                var month: Int?
                if index + 3 < keys.count, keys[index + 2] == "de", let named = months[keys[index + 3]] {
                    consumed.formUnion([index + 2, index + 3])
                    month = named
                }
                return date(day: dayNumber, month: month, from: today, calendar: calendar)
            }
            if let dayNumber = Int(keys[index]), index + 2 < keys.count,
               keys[index + 1] == "de", let named = months[keys[index + 2]] {
                consumed.formUnion([index, index + 1, index + 2])
                return date(day: dayNumber, month: named, from: today, calendar: calendar)
            }
            if keys[index].contains("/") {
                let parts = keys[index].split(separator: "/")
                guard parts.count >= 2, let dayNumber = Int(parts[0]), let month = Int(parts[1]) else { continue }
                consumed.insert(index)
                return date(day: dayNumber, month: month, from: today, calendar: calendar)
            }
        }

        return nil
    }

    private static func nextOccurrence(ofWeekday weekday: Int, from today: Date, calendar: Calendar) -> Date {
        let current = calendar.component(.weekday, from: today)
        var delta = weekday - current
        if delta <= 0 { delta += 7 }
        return calendar.date(byAdding: .day, value: delta, to: today) ?? today
    }

    /// Monta uma data a partir de dia/mês, empurrando para o ano ou mês
    /// seguinte quando a data já passou.
    private static func date(day: Int, month: Int?, from today: Date, calendar: Calendar) -> Date? {
        guard (1...31).contains(day) else { return nil }
        var components = calendar.dateComponents([.year, .month], from: today)
        components.day = day
        if let month {
            guard (1...12).contains(month) else { return nil }
            components.month = month
        }
        guard let candidate = calendar.date(from: components) else { return nil }
        if candidate >= today { return candidate }
        let unit: Calendar.Component = month == nil ? .month : .year
        return calendar.date(byAdding: unit, value: 1, to: candidate)
    }

    // MARK: - Normalização

    private static func normalize(_ word: String) -> String {
        let folded = word.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                  locale: Locale(identifier: "pt_BR"))
        let keep = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ":/-"))
        return folded.trimmingCharacters(in: keep.inverted)
    }
}
