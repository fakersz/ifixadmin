//
//  EventEditorView.swift
//  ifixadmin
//

import SwiftUI
import SwiftData

struct EventEditorView: View {
    /// `nil` cria um compromisso novo.
    let event: CalendarEvent?
    var defaultDate: Date = .now

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CalendarEvent.startDate) private var allEvents: [CalendarEvent]

    @State private var title = ""
    @State private var startDate = Date.now
    @State private var durationMinutes = 60
    @State private var category = EventCategory.other
    @State private var notes = ""
    @State private var isDone = false
    @State private var didLoad = false

    private static let durationOptions = [15, 30, 45, 60, 90, 120, 180, 240]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Título", text: $title)
                        .onChange(of: title) { _, newValue in
                            // Só sugere enquanto o usuário não escolheu nada manualmente.
                            guard category == .other else { return }
                            category = .inferred(from: newValue)
                        }

                    DatePicker("Início", selection: $startDate)

                    Picker("Duração", selection: $durationMinutes) {
                        ForEach(Self.durationOptions, id: \.self) { minutes in
                            Text(minutes.asDurationText).tag(minutes)
                        }
                    }
                }

                Section("Categoria") {
                    Picker("Categoria", selection: $category) {
                        ForEach(EventCategory.allCases) { option in
                            Label(option.label, systemImage: option.symbol).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                if let conflict = conflictingEvent {
                    Section {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Conflita com “\(conflict.title)”")
                                Text("\(conflict.startDate.appTimeText) – \(conflict.endDate.appTimeText)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }

                        if let slot = suggestedSlot {
                            Button {
                                startDate = slot.start
                            } label: {
                                Label(
                                    "Mover para \(slot.start.appTimeText)",
                                    systemImage: "wand.and.stars"
                                )
                            }
                        }
                    }
                }

                Section("Anotações") {
                    TextField("Opcional", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Toggle("Concluído", isOn: $isDone)
                }

                if let event {
                    Section {
                        Button(role: .destructive) {
                            NotificationScheduler.cancel(for: event)
                            context.delete(event)
                            dismiss()
                        } label: {
                            Label("Apagar compromisso", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(event == nil ? "Novo compromisso" : "Editar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) {
                        // Um compromisso criado a partir de um horário livre já
                        // foi inserido no contexto; cancelar precisa removê-lo.
                        if let event, event.title.isEmpty {
                            context.delete(event)
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 520)
        #endif
    }

    // MARK: - Conflito

    private var conflictingEvent: CalendarEvent? {
        let end = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
        return allEvents.first { other in
            other.persistentModelID != event?.persistentModelID
                && startDate < other.endDate
                && other.startDate < end
        }
    }

    private var suggestedSlot: FreeSlot? {
        let others = allEvents.filter { $0.persistentModelID != event?.persistentModelID }
        return ScheduleAnalyzer.firstSlot(fitting: durationMinutes, on: startDate, events: others)
    }

    // MARK: - Carregar / salvar

    private func load() {
        guard !didLoad else { return }
        didLoad = true

        guard let event else {
            startDate = defaultDate
            return
        }
        title = event.title
        startDate = event.startDate
        durationMinutes = Self.durationOptions.contains(event.durationMinutes)
            ? event.durationMinutes
            : 60
        category = event.category
        notes = event.notes
        isDone = event.isDone
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)

        let target = event ?? {
            let created = CalendarEvent(title: trimmed, startDate: startDate)
            context.insert(created)
            return created
        }()

        target.title = trimmed
        target.startDate = startDate
        target.durationMinutes = durationMinutes
        target.category = category
        target.notes = notes
        target.isDone = isDone

        // A data pode ter mudado — reagenda a partir dos valores novos.
        Task { await NotificationScheduler.schedule(for: target) }

        dismiss()
    }
}
