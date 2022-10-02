//
//  TabulaApp.swift
//  Tabula
//
//  Created by Mason on 10/1/22.
//

import SwiftUI

@main
struct TabulaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(isPreview: false)
        }
    }
}
