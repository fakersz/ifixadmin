//
//  QuickAddBar.swift
//  ifixadmin
//
//  Campo de entrada em linguagem natural, com pré-visualização do que
//  foi entendido antes de salvar.
//

import SwiftUI

struct QuickAddBar: View {
    let referenceDate: Date
    let onSubmit: (ParsedEvent) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    /// Interpreta usando o dia selecionado como "hoje", para que
    /// "às 15h" caia no dia que o usuário está olhando.
    private var preview: ParsedEvent? {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return QuickAddParser.parse(text, now: referenceNow, calendar: AppLocale.calendar)
    }

    /// O dia selecionado, mas preservando a hora atual quando é hoje.
    private var referenceNow: Date {
        let calendar = AppLocale.calendar
        if calendar.isDateInToday(referenceDate) { return .now }
        return calendar.date(bySettingHour: 0, minute: 1, second: 0, of: referenceDate) ?? referenceDate
    }

    var body: some View {
        VStack(spacing: 0) {
            if let preview {
                previewChip(for: preview)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)

                TextField("Dentista amanhã às 15h por 30min", text: $text)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(commit)
                    #if os(iOS)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.sentences)
                    #endif

                Button(action: commit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(preview == nil ? Color.secondary : Color.accentColor)
                .disabled(preview == nil)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.bar)
        .animation(.snappy, value: preview?.title)
    }

    private func previewChip(for parsed: ParsedEvent) -> some View {
        HStack(spacing: 8) {
            Label(parsed.category.label, systemImage: parsed.category.symbol)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(parsed.category.tint.opacity(0.15), in: .capsule)
                .foregroundStyle(parsed.category.tint)

            Text(parsed.startDate.appShortDateText)
                .font(.caption)

            Text(parsed.startDate.appTimeText)
                .font(.caption.weight(.semibold))
                .monospacedDigit()

            Text("· \(parsed.durationMinutes.asDurationText)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    private func commit() {
        guard let parsed = preview else { return }
        onSubmit(parsed)
        text = ""
        isFocused = false
    }
}
