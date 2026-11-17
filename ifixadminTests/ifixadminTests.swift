//
//  ifixadminTests.swift
//  ifixadminTests
//
//  Created on 24/07/26.
//

import Testing
import Foundation
import SwiftData
@testable import ifixadmin

// MARK: - Interpretação de texto

@Suite("QuickAddParser")
struct QuickAddParserTests {

    /// Calendário e "agora" fixos, para os testes não dependerem do relógio.
    /// Quarta-feira, 15 de julho de 2026, 10:00.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        calendar.locale = Locale(identifier: "pt_BR")
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 10, minute: 0))!
    }

    private func parse(_ text: String) -> ParsedEvent? {
        QuickAddParser.parse(text, now: now, calendar: calendar)
    }

    @Test("extrai título, dia e hora de uma frase completa")
    func fullSentence() throws {
        let parsed = try #require(parse("Dentista amanhã às 15h"))

        #expect(parsed.title == "Dentista")
        #expect(parsed.category == .health)
        #expect(calendar.component(.day, from: parsed.startDate) == 16)
        #expect(calendar.component(.hour, from: parsed.startDate) == 15)
        #expect(parsed.foundExplicitDay)
        #expect(parsed.foundExplicitTime)
    }

    @Test("entende duração explícita sem confundir com horário")
    func durationDoesNotEatTheClock() throws {
        let parsed = try #require(parse("Reunião hoje às 14h por 2h"))

        #expect(parsed.title == "Reunião")
        #expect(calendar.component(.hour, from: parsed.startDate) == 14)
        #expect(parsed.durationMinutes == 120)
    }

    @Test("aceita minutos na duração")
    func durationInMinutes() throws {
        let parsed = try #require(parse("Ligar pro banco hoje às 16h por 45min"))
        #expect(parsed.durationMinutes == 45)
        #expect(parsed.category == .personal)
    }

    @Test("duração combinada 1h30")
    func compoundDuration() throws {
        let parsed = try #require(parse("Academia hoje às 18h por 1h30"))
        #expect(parsed.durationMinutes == 90)
    }

    @Test("horário sem dia, já passado, cai para amanhã")
    func pastTimeRollsOver() throws {
        // São 10:00; "às 9h" só pode ser amanhã.
        let parsed = try #require(parse("Café às 9h"))
        #expect(calendar.component(.day, from: parsed.startDate) == 16)
        #expect(calendar.component(.hour, from: parsed.startDate) == 9)
    }

    @Test("horário sem dia, ainda por vir, fica hoje")
    func futureTimeStaysToday() throws {
        let parsed = try #require(parse("Café às 16h"))
        #expect(calendar.component(.day, from: parsed.startDate) == 15)
    }

    @Test("dia da semana aponta para a próxima ocorrência")
    func weekdayGoesForward() throws {
        // 15/07/2026 é quarta; a próxima sexta é dia 17.
        let parsed = try #require(parse("Cinema sexta às 20h"))
        #expect(calendar.component(.day, from: parsed.startDate) == 17)
        #expect(parsed.category == .social)
    }

    @Test("mesmo dia da semana de hoje vai para a semana seguinte")
    func sameWeekdayJumpsAWeek() throws {
        let parsed = try #require(parse("Revisão quarta às 11h"))
        #expect(calendar.component(.day, from: parsed.startDate) == 22)
    }

    @Test("depois de amanhã soma dois dias")
    func dayAfterTomorrow() throws {
        let parsed = try #require(parse("Prova depois de amanhã às 8h"))
        #expect(calendar.component(.day, from: parsed.startDate) == 17)
        #expect(parsed.title == "Prova")
        #expect(parsed.category == .study)
    }

    @Test("data numérica no formato dia/mês")
    func numericDate() throws {
        let parsed = try #require(parse("Voo 12/08 às 6h30"))
        #expect(calendar.component(.day, from: parsed.startDate) == 12)
        #expect(calendar.component(.month, from: parsed.startDate) == 8)
        #expect(calendar.component(.hour, from: parsed.startDate) == 6)
        #expect(calendar.component(.minute, from: parsed.startDate) == 30)
        #expect(parsed.category == .travel)
    }

    @Test("data por extenso com mês nomeado")
    func namedMonth() throws {
        let parsed = try #require(parse("Aniversário da Ana dia 3 de setembro"))
        #expect(calendar.component(.day, from: parsed.startDate) == 3)
        #expect(calendar.component(.month, from: parsed.startDate) == 9)
        #expect(parsed.category == .social)
    }

    @Test("data no passado do mês corrente pula para o mês seguinte")
    func pastDayNumberRollsToNextMonth() throws {
        // Hoje é 15/07; "dia 2" só pode ser agosto.
        let parsed = try #require(parse("Pagar conta dia 2"))
        #expect(calendar.component(.day, from: parsed.startDate) == 2)
        #expect(calendar.component(.month, from: parsed.startDate) == 8)
    }

    @Test("meio-dia e meia-noite")
    func fixedTimeWords() throws {
        #expect(calendar.component(.hour, from: try #require(parse("Almoço meio-dia")).startDate) == 12)
        #expect(calendar.component(.hour, from: try #require(parse("Dormir meia-noite")).startDate) == 0)
    }

    @Test("período do dia como último recurso")
    func periodOfDay() throws {
        let parsed = try #require(parse("Mercado amanhã de tarde"))
        #expect(calendar.component(.hour, from: parsed.startDate) == 14)
        #expect(parsed.category == .personal)
    }

    @Test("sem hora explícita num dia futuro usa o horário padrão")
    func defaultHourOnFutureDay() throws {
        let parsed = try #require(parse("Consulta amanhã"))
        #expect(calendar.component(.hour, from: parsed.startDate) == QuickAddParser.defaultHour)
        #expect(parsed.foundExplicitTime == false)
        #expect(parsed.foundExplicitDay)
    }

    @Test("sem duração usa o padrão")
    func defaultDuration() throws {
        let parsed = try #require(parse("Reunião amanhã às 10h"))
        #expect(parsed.durationMinutes == QuickAddParser.defaultDurationMinutes)
    }

    @Test("acentos e maiúsculas não atrapalham")
    func accentInsensitive() throws {
        let a = try #require(parse("MÉDICO AMANHÃ ÀS 15H"))
        let b = try #require(parse("medico amanha as 15h"))
        #expect(a.startDate == b.startDate)
        #expect(a.category == .health)
        #expect(b.category == .health)
    }

    @Test("texto sem título nenhum é rejeitado")
    func titleIsRequired() {
        #expect(parse("amanhã às 15h") == nil)
        #expect(parse("   ") == nil)
        #expect(parse("") == nil)
    }

    @Test("horário inválido não é tratado como hora")
    func invalidClockIsIgnored() throws {
        // 99h não é hora válida; deve sobrar no título.
        let parsed = try #require(parse("Teste 99h amanhã"))
        #expect(parsed.title.contains("99h"))
        #expect(parsed.foundExplicitTime == false)
    }

    @Test("categoria cai em .other quando nada casa")
    func unknownCategory() throws {
        let parsed = try #require(parse("Xyzabc amanhã às 10h"))
        #expect(parsed.category == .other)
    }
}

// MARK: - Análise da agenda

@Suite("ScheduleAnalyzer")
@MainActor
struct ScheduleAnalyzerTests {

    /// Precisa ser guardado: se o container morrer, o contexto é resetado e os
    /// modelos inseridos nele viram inutilizáveis (crash ao ler qualquer campo).
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: CalendarEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }

    private var day: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 15))!
    }

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    /// Cria já inserido no contexto, para ter `persistentModelID` estável.
    private func event(_ title: String, _ hour: Int, _ minute: Int = 0, minutes: Int = 60) -> CalendarEvent {
        insert(CalendarEvent(title: title, startDate: at(hour, minute), durationMinutes: minutes))
    }

    private func insert(_ event: CalendarEvent) -> CalendarEvent {
        container.mainContext.insert(event)
        return event
    }

    @Test("detecta sobreposição")
    func detectsOverlap() throws {
        let a = event("A", 10, minutes: 60)      // 10:00–11:00
        let b = event("B", 10, 30, minutes: 60)  // 10:30–11:30

        #expect(a.overlaps(b))
        #expect(ScheduleAnalyzer.conflictingIDs(in: [a, b]).count == 2)
    }

    @Test("encostar não é conflito")
    func backToBackIsFine() throws {
        let a = event("A", 10, minutes: 60)  // 10:00–11:00
        let b = event("B", 11, minutes: 60)  // 11:00–12:00

        #expect(a.overlaps(b) == false)
        #expect(ScheduleAnalyzer.conflictingIDs(in: [a, b]).isEmpty)
    }

    @Test("um compromisso não conflita consigo mesmo")
    func noSelfConflict() throws {
        let a = event("A", 10)

        #expect(a.overlaps(a) == false)
        #expect(ScheduleAnalyzer.conflictingIDs(in: [a]).isEmpty)
    }

    @Test("dia vazio devolve a janela inteira como livre")
    func emptyDayIsAllFree() {
        let slots = ScheduleAnalyzer.freeSlots(on: day, events: [], calendar: calendar)
        let expected = (ScheduleAnalyzer.dayEndHour - ScheduleAnalyzer.dayStartHour) * 60

        #expect(slots.count == 1)
        #expect(slots.first?.minutes == expected)
    }

    @Test("buracos entre compromissos")
    func gapsBetweenEvents() {
        let events = [event("A", 10), event("B", 14)]
        let slots = ScheduleAnalyzer.freeSlots(on: day, events: events, calendar: calendar)

        #expect(slots.count == 3)
        #expect(slots[0].minutes == 120) // 08:00–10:00
        #expect(slots[1].minutes == 180) // 11:00–14:00
        #expect(slots[2].minutes == 420) // 15:00–22:00
    }

    @Test("buracos curtos demais são descartados")
    func tinyGapsAreDropped() {
        let events = [
            event("A", 10, minutes: 60),      // 10:00–11:00
            event("B", 11, 15, minutes: 645)  // 11:15–22:00
        ]
        let slots = ScheduleAnalyzer.freeSlots(on: day, events: events, calendar: calendar)

        // O buraco de 15min entre 11:00 e 11:15 não deve aparecer.
        #expect(slots.allSatisfy { $0.minutes >= ScheduleAnalyzer.minimumSlotMinutes })
        #expect(slots.count == 1)
    }

    @Test("compromissos sobrepostos não geram buraco negativo")
    func overlappingEventsDoNotBreakSlots() {
        let events = [
            event("A", 10, minutes: 120),    // 10:00–12:00
            event("B", 10, 30, minutes: 30)  // 10:30–11:00, contido no anterior
        ]
        let slots = ScheduleAnalyzer.freeSlots(on: day, events: events, calendar: calendar)

        #expect(slots.allSatisfy { $0.end > $0.start })
        #expect(slots.count == 2) // 08:00–10:00 e 12:00–22:00
    }

    @Test("encontra o primeiro buraco que cabe")
    func firstFittingSlot() throws {
        let events = [event("A", 9, 30, minutes: 30)] // 09:30–10:00

        // 08:00–09:30 tem 90min: cabe 60, não cabe 300.
        let short = try #require(ScheduleAnalyzer.firstSlot(fitting: 60, on: day, events: events, calendar: calendar))
        #expect(calendar.component(.hour, from: short.start) == 8)

        let long = try #require(ScheduleAnalyzer.firstSlot(fitting: 300, on: day, events: events, calendar: calendar))
        #expect(calendar.component(.hour, from: long.start) == 10)
    }

    @Test("resumo do dia")
    func daySummary() {
        let events = [event("A", 10, minutes: 60), event("B", 14, minutes: 30)]
        let summary = ScheduleAnalyzer.summary(for: day, events: events, calendar: calendar)

        #expect(summary.eventCount == 2)
        #expect(summary.busyMinutes == 90)
        #expect(summary.conflictCount == 0)
        #expect(summary.isEmpty == false)
    }

    @Test("resumo de dia vazio")
    func emptyDaySummary() {
        let summary = ScheduleAnalyzer.summary(for: day, events: [], calendar: calendar)

        #expect(summary.isEmpty)
        #expect(summary.dominantCategory == nil)
        #expect(summary.busyMinutes == 0)
    }

    @Test("eventos de outros dias são ignorados")
    func filtersByDay() throws {
        let otherDay = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        let events = [
            event("Hoje", 10),
            insert(CalendarEvent(
                title: "Amanhã",
                startDate: try #require(calendar.date(bySettingHour: 10, minute: 0, second: 0, of: otherDay))
            ))
        ]

        #expect(ScheduleAnalyzer.events(events, on: day, calendar: calendar).count == 1)
    }
}

// MARK: - Notificações

@Suite("NotificationScheduler")
struct NotificationSchedulerTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func minutes(_ value: Int) -> TimeInterval { TimeInterval(value * 60) }

    @Test("avisa com a antecedência configurada")
    func firesEarly() throws {
        let start = now.addingTimeInterval(minutes(60))
        let fire = try #require(NotificationScheduler.fireDate(forEventStartingAt: start, now: now))

        #expect(fire == start.addingTimeInterval(-minutes(NotificationScheduler.leadMinutes)))
        #expect(fire > now)
    }

    @Test("compromisso mais próximo que a antecedência avisa na hora exata")
    func firesAtStartWhenTooClose() throws {
        // Faltam 5min, mas a antecedência é de 15: não dá para avisar no passado.
        let start = now.addingTimeInterval(minutes(5))
        let fire = try #require(NotificationScheduler.fireDate(forEventStartingAt: start, now: now))

        #expect(fire == start)
    }

    @Test("compromisso que já passou não gera lembrete")
    func noNotificationForPastEvents() {
        #expect(NotificationScheduler.fireDate(forEventStartingAt: now.addingTimeInterval(-minutes(1)), now: now) == nil)
        #expect(NotificationScheduler.fireDate(forEventStartingAt: now, now: now) == nil)
    }

    @Test("o disparo nunca cai no passado")
    func neverSchedulesInThePast() {
        for offset in 1...120 {
            guard let fire = NotificationScheduler.fireDate(
                forEventStartingAt: now.addingTimeInterval(minutes(offset)), now: now
            ) else {
                Issue.record("deveria agendar para um compromisso futuro (+\(offset)min)")
                continue
            }
            #expect(fire > now)
        }
    }

    @Test("cada compromisso tem um identificador próprio")
    func uniqueNotificationIDs() {
        let a = CalendarEvent(title: "A", startDate: .now)
        let b = CalendarEvent(title: "B", startDate: .now)

        #expect(a.notificationID != b.notificationID)
        #expect(a.notificationID.isEmpty == false)
    }

    @Test("a capa é gerada e vira um arquivo de verdade")
    func coverImageIsWritten() throws {
        CoverImage.invalidate()
        let url = try #require(CoverImage.url())

        #expect(FileManager.default.fileExists(atPath: url.path))
        let size = try #require(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
        #expect(size > 0)
    }
}

// MARK: - Modelo

@Suite("CalendarEvent")
struct CalendarEventTests {

    @Test("fim é calculado a partir da duração")
    func endDate() {
        let start = Date(timeIntervalSince1970: 0)
        let event = CalendarEvent(title: "X", startDate: start, durationMinutes: 90)

        #expect(event.endDate.timeIntervalSince(start) == 90 * 60)
    }

    @Test("categoria sobrevive à ida e volta pelo armazenamento")
    func categoryRoundTrip() {
        let event = CalendarEvent(title: "X", startDate: .now, category: .health)
        #expect(event.category == .health)

        event.category = .travel
        #expect(event.category == .travel)
    }

    @Test("formatação de duração")
    func durationText() {
        #expect(45.asDurationText == "45min")
        #expect(60.asDurationText == "1h")
        #expect(90.asDurationText == "1h30")
        #expect(125.asDurationText == "2h05")
        #expect(0.asDurationText == "0min")
    }

    @Test("categoria inferida por palavra-chave")
    func inferredCategory() {
        #expect(EventCategory.inferred(from: "Consulta com o dentista") == .health)
        #expect(EventCategory.inferred(from: "reunião de sprint") == .work)
        #expect(EventCategory.inferred(from: "Voo para Lisboa") == .travel)
        #expect(EventCategory.inferred(from: "assunto qualquer") == .other)
    }
}
