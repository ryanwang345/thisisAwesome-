//
//  thisisAwesome_App.swift
//  thisisAwesome! Watch App
//
//  Created by Ryan Wang on 11/22/25.
//

import SwiftUI

@main
struct thisisAwesome__Watch_AppApp: App {
    @StateObject private var environment = WatchEnvironment()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(environment)
        }
    }
}
