//
//  AppLocale.swift
//  ifixadmin
//
//  O app é escrito inteiramente em português, mas o bundle não declara
//  pt-BR como idioma suportado — então o Foundation formata datas usando
//  o idioma de desenvolvimento (inglês) e a tela vira uma salada:
//  "July 2026" embaixo de "Hoje".
//
//  Fixar o locale aqui resolve num lugar só. Se um dia o app for
//  traduzido, é este arquivo que sai.
//

import Foundation

enum AppLocale {
    static let current = Locale(identifier: "pt_BR")

    /// Calendário com o locale do app, para nomes de dia e primeiro dia da semana.
    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = current
        return calendar
    }
}

extension Date {
    /// "15:30"
    var appTimeText: String {
        formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(AppLocale.current))
    }

    /// "julho de 2026"
    var appMonthYearText: String {
        formatted(.dateTime.month(.wide).year().locale(AppLocale.current))
    }

    /// "qua., 24 de jul."
    var appShortDateText: String {
        formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(AppLocale.current))
    }

    /// "quarta-feira, 24 de jul."
    var appLongDateText: String {
        formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(AppLocale.current))
    }

    /// "24"
    var appDayNumberText: String {
        formatted(.dateTime.day().locale(AppLocale.current))
    }
}
