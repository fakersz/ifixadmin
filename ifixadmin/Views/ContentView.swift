//
//  ContentView.swift
//  ifixadmin
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CalendarEvent.startDate) private var events: [CalendarEvent]

    @State private var selectedDate = AppLocale.calendar.startOfDay(for: .now)
    @State private var editingEvent: CalendarEvent?
    @State private var isCreatingEvent = false

    private var calendar: Calendar { AppLocale.calendar }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MonthGridView(selectedDate: $selectedDate, events: events)

                Divider()

                DayAgendaView(
                    day: selectedDate,
                    events: events,
                    onSelect: { editingEvent = $0 },
                    onDelete: delete(_:),
                    onUseSlot: createEvent(inSlot:)
                )

                QuickAddBar(referenceDate: selectedDate, onSubmit: insert(_:))
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCreatingEvent = true
                    } label: {
                        Label("Novo compromisso", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hoje") {
                        withAnimation { selectedDate = calendar.startOfDay(for: .now) }
                    }
                    .disabled(calendar.isDateInToday(selectedDate))
                }
            }
            .sheet(item: $editingEvent) { event in
                EventEditorView(event: event)
            }
            .sheet(isPresented: $isCreatingEvent) {
                EventEditorView(event: nil, defaultDate: suggestedStartForNewEvent())
            }
            .task {
                NotificationPresenter.shared.register()
                await NotificationScheduler.requestAuthorization()
                // Recupera lembretes perdidos: permissão negada e depois
                // concedida, ou notificações limpas pelo sistema.
                await NotificationScheduler.rescheduleAll(events)
            }
        }
    }

    private var navigationTitle: String {
        if calendar.isDateInToday(selectedDate) { return "Hoje" }
        if calendar.isDateInTomorrow(selectedDate) { return "Amanhã" }
        return selectedDate.appLongDateText
    }

    // MARK: - Ações

    private func insert(_ parsed: ParsedEvent) {
        let event = CalendarEvent(
            title: parsed.title,
            startDate: parsed.startDate,
            durationMinutes: parsed.durationMinutes,
            category: parsed.category
        )
        context.insert(event)
        withAnimation {
            selectedDate = calendar.startOfDay(for: parsed.startDate)
        }
        Task { await NotificationScheduler.schedule(for: event) }
    }

    private func delete(_ event: CalendarEvent) {
        NotificationScheduler.cancel(for: event)
        withAnimation { context.delete(event) }
    }

    private func createEvent(inSlot slot: FreeSlot) {
        isCreatingEvent = false
        editingEvent = nil
        let event = CalendarEvent(
            title: "",
            startDate: slot.start,
            durationMinutes: min(slot.minutes, 60)
        )
        context.insert(event)
        editingEvent = event
    }

    /// Ao criar manualmente, começa no primeiro buraco livre do dia escolhido.
    private func suggestedStartForNewEvent() -> Date {
        if let slot = ScheduleAnalyzer.firstSlot(fitting: 60, on: selectedDate, events: events) {
            return slot.start
        }
        return calendar.date(
            bySettingHour: ScheduleAnalyzer.dayStartHour, minute: 0, second: 0, of: selectedDate
        ) ?? selectedDate
    }
}

#Preview {
    ContentView()
        .modelContainer(for: CalendarEvent.self, inMemory: true)
}
