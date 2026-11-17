//
//  MonthGridView.swift
//  ifixadmin
//

import SwiftUI

struct MonthGridView: View {
    @Binding var selectedDate: Date
    let events: [CalendarEvent]

    @State private var visibleMonth: Date = AppLocale.calendar.startOfDay(for: .now)

    private var calendar: Calendar { AppLocale.calendar }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            header

            HStack(spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(daysInGrid, id: \.self) { day in
                    DayCell(
                        day: day,
                        isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(day),
                        isInMonth: calendar.isDate(day, equalTo: visibleMonth, toGranularity: .month),
                        categories: categories(on: day)
                    )
                    .contentShape(.rect)
                    .onTapGesture {
                        withAnimation(.snappy) { selectedDate = day }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onAppear { visibleMonth = selectedDate }
        .onChange(of: selectedDate) { _, newValue in
            guard !calendar.isDate(newValue, equalTo: visibleMonth, toGranularity: .month) else { return }
            withAnimation(.snappy) { visibleMonth = newValue }
        }
    }

    private var header: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(visibleMonth.appMonthYearText)
                .font(.headline)
                .contentTransition(.numericText())

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
    }

    private func shiftMonth(by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: visibleMonth) else { return }
        withAnimation(.snappy) { visibleMonth = next }
    }

    private var weekdaySymbols: [String] {
        let symbols: [String] = calendar.shortWeekdaySymbols.map { String($0.prefix(3)).uppercased() }
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...]) + Array(symbols[..<offset])
    }

    /// Sempre 6 semanas, para a grade não mudar de altura ao trocar de mês.
    private var daysInGrid: [Date] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth),
            let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else { return [] }

        return (0..<42).compactMap {
            calendar.date(byAdding: .day, value: $0, to: firstWeek.start)
        }
    }

    private func categories(on day: Date) -> [EventCategory] {
        let found = events
            .filter { calendar.isDate($0.startDate, inSameDayAs: day) }
            .map(\.category)
        var seen: [EventCategory] = []
        for category in found where !seen.contains(category) {
            seen.append(category)
        }
        return Array(seen.prefix(3))
    }
}

private struct DayCell: View {
    let day: Date
    let isSelected: Bool
    let isToday: Bool
    let isInMonth: Bool
    let categories: [EventCategory]

    var body: some View {
        VStack(spacing: 3) {
            Text(day.appDayNumberText)
                .font(.callout)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(numberColor)
                .frame(width: 30, height: 30)
                .background {
                    if isSelected {
                        Circle().fill(.tint)
                    } else if isToday {
                        Circle().stroke(.tint, lineWidth: 1.5)
                    }
                }

            HStack(spacing: 3) {
                ForEach(categories) { category in
                    Circle()
                        .fill(category.tint)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity)
        .opacity(isInMonth ? 1 : 0.3)
    }

    private var numberColor: Color {
        if isSelected { return .white }
        if isToday { return .accentColor }
        return .primary
    }
}
