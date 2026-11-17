//
//  ifixadminApp.swift
//  ifixadmin
//
//  Created on 24/07/26.
//

import SwiftUI
import SwiftData

@main
struct ifixadminApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CalendarEvent.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Vale para o que o SwiftUI formata sozinho — DatePicker,
                // sobretudo. O resto passa por AppLocale.
                .environment(\.locale, AppLocale.current)
        }
        .modelContainer(sharedModelContainer)
    }
}
