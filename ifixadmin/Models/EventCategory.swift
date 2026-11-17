//
//  EventCategory.swift
//  ifixadmin
//

import SwiftUI

/// Categoria de um compromisso. Define cor, ícone e as palavras-chave usadas
/// para adivinhar a categoria a partir do texto digitado pelo usuário.
enum EventCategory: String, Codable, CaseIterable, Identifiable {
    case work
    case health
    case study
    case social
    case travel
    case personal
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .work: "Trabalho"
        case .health: "Saúde"
        case .study: "Estudos"
        case .social: "Social"
        case .travel: "Viagem"
        case .personal: "Pessoal"
        case .other: "Outro"
        }
    }

    var symbol: String {
        switch self {
        case .work: "briefcase.fill"
        case .health: "heart.fill"
        case .study: "book.fill"
        case .social: "person.2.fill"
        case .travel: "airplane"
        case .personal: "house.fill"
        case .other: "calendar"
        }
    }

    var tint: Color {
        switch self {
        case .work: .blue
        case .health: .pink
        case .study: .purple
        case .social: .orange
        case .travel: .teal
        case .personal: .green
        case .other: .gray
        }
    }

    /// Termos (já sem acento e em minúsculas) que sugerem esta categoria.
    var keywords: [String] {
        switch self {
        case .work:
            ["reuniao", "meeting", "call", "cliente", "trabalho", "entrevista",
             "apresentacao", "daily", "sprint", "deploy", "projeto", "chefe", "equipe"]
        case .health:
            ["medico", "dentista", "consulta", "exame", "academia", "treino",
             "terapia", "psicologo", "fisioterapia", "vacina", "remedio", "corrida"]
        case .study:
            ["aula", "prova", "estudar", "curso", "faculdade", "trabalho de",
             "seminario", "tcc", "licao", "revisao", "leitura"]
        case .social:
            ["aniversario", "festa", "jantar", "almoco", "cafe", "encontro",
             "bar", "cinema", "show", "churrasco", "casamento"]
        case .travel:
            ["voo", "viagem", "aeroporto", "hotel", "embarque", "check-in",
             "onibus", "rodoviaria", "passagem"]
        case .personal:
            ["mercado", "banco", "compras", "casa", "faxina", "cabeleireiro",
             "barbeiro", "correios", "conta", "pagar"]
        case .other:
            []
        }
    }

    /// Adivinha a categoria a partir de um texto livre. Cai em `.other`
    /// quando nada casa — nunca inventa uma categoria.
    static func inferred(from text: String) -> EventCategory {
        let haystack = text.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                    locale: Locale(identifier: "pt_BR"))
        for category in allCases where category != .other {
            if category.keywords.contains(where: { haystack.contains($0) }) {
                return category
            }
        }
        return .other
    }
}
