//
//  DayAgendaView.swift
//  ifixadmin
//

import SwiftUI
import SwiftData

struct DayAgendaView: View {
    let day: Date
    let events: [CalendarEvent]
    let onSelect: (CalendarEvent) -> Void
    let onDelete: (CalendarEvent) -> Void
    let onUseSlot: (FreeSlot) -> Void

    private var dayEvents: [CalendarEvent] {
        ScheduleAnalyzer.events(events, on: day)
    }

    private var conflicting: Set<PersistentIdentifier> {
        ScheduleAnalyzer.conflictingIDs(in: dayEvents)
    }

    private var summary: DaySummary {
        ScheduleAnalyzer.summary(for: day, events: events)
    }

    var body: some View {
        List {
            Section {
                SummaryStrip(summary: summary)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if dayEvents.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Dia livre",
                        systemImage: "sparkles",
                        description: Text("Escreva algo como “Dentista amanhã às 15h” no campo abaixo.")
                    )
                }
            } else {
                Section("Compromissos") {
                    ForEach(dayEvents) { event in
                        EventRow(
                            event: event,
                            hasConflict: conflicting.contains(event.persistentModelID)
                        )
                        .contentShape(.rect)
                        .onTapGesture { onSelect(event) }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onDelete(event)
                            } label: {
                                Label("Apagar", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            let slots = ScheduleAnalyzer.freeSlots(on: day, events: events)
            if !slots.isEmpty && !dayEvents.isEmpty {
                Section("Horários livres") {
                    ForEach(slots) { slot in
                        Button {
                            onUseSlot(slot)
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.tint)
                                Text("\(slot.start.appTimeText) – \(slot.end.appTimeText)")
                                Spacer()
                                Text(slot.minutes.asDurationText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Resumo

private struct SummaryStrip: View {
    let summary: DaySummary

    var body: some View {
        HStack(spacing: 12) {
            metric(
                value: "\(summary.eventCount)",
                caption: summary.eventCount == 1 ? "compromisso" : "compromissos"
            )
            Divider().frame(height: 28)
            metric(value: summary.busyMinutes.asDurationText, caption: "ocupado")
            Divider().frame(height: 28)
            metric(value: summary.freeMinutes.asDurationText, caption: "livre")

            if summary.conflictCount > 0 {
                Divider().frame(height: 28)
                metric(
                    value: "\(summary.conflictCount)",
                    caption: summary.conflictCount == 1 ? "conflito" : "conflitos",
                    symbol: "exclamationmark.triangle.fill",
                    tint: .orange
                )
            }
        }
    }

    private func metric(
        value: String,
        caption: String,
        symbol: String? = nil,
        tint: Color = .primary
    ) -> some View {
        VStack(spacing: 2) {
            Group {
                if let symbol {
                    Label(value, systemImage: symbol)
                } else {
                    Text(value)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .contentTransition(.numericText())

            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                // Com a coluna de conflito visível sobra pouca largura, e
                // "compromissos" quebrava no meio da palavra.
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Linha de compromisso

private struct EventRow: View {
    let event: CalendarEvent
    let hasConflict: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(event.startDate.appTimeText)
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                Text(event.durationMinutes.asDurationText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 58, alignment: .trailing)

            RoundedRectangle(cornerRadius: 2)
                .fill(event.category.tint)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title.isEmpty ? "Sem título" : event.title)
                    .font(.body)
                    .strikethrough(event.isDone)
                    .foregroundStyle(event.isDone ? .secondary : .primary)

                HStack(spacing: 6) {
                    Label(event.category.label, systemImage: event.category.symbol)
                        .font(.caption2)
                        .foregroundStyle(event.category.tint)

                    if hasConflict {
                        Label("Conflito", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}
