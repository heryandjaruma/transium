//
//  transiumApp.swift
//  transium
//
//  Created by Heryan Djaruma on 10/08/26.
//

import SwiftUI
import SwiftData

@main
struct transiumApp: App {
    init() {
        if AppEnvironment.DEV_MODE {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: transiumSchema.models)
    }
}

enum transiumSchema {
    static let models: [any PersistentModel.Type] = [
        LocalAuthIdentity.self,
        LocalProfile.self
    ]
}
