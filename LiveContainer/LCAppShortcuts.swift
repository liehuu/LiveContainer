//
//  LCAppShortcuts.swift
//  LiveContainer
//
//  App Shortcuts provider compiled into the MAIN APP BINARY.
//
//  Why this file has to live in the main app target:
//  The refresh shortcut used to come only from the dylibified SideStore
//  (SideStoreApp.framework), whose upstream AppShortcutsProvider is compiled
//  into that framework binary. AppIntents resolves the provider named in the
//  main bundle's Metadata.appintents against the MAIN APP binary, never finds
//  the type there, and fails with "Couldn't find AppShortcutsProvider".
//  Declaring the provider here puts the type where the system looks for it.
//
//  The intent itself is deliberately a plain AppIntent (NOT a
//  CustomIntentMigratedAppIntent): it must not depend on the legacy SiriKit
//  class "RefreshAllIntent", which only exists once SideStoreApp.framework has
//  been loaded. That dependency is why a cold launch failed with a generic
//  internal error while a warm launch got further.
//

import AppIntents
import SideStore

@available(iOS 17.0, *)
public struct LCRefreshAllAppsIntent: AppIntent, ForegroundContinuableIntent {
    public static var title: LocalizedStringResource { "Refresh All Apps" }

    public static var description: IntentDescription {
        IntentDescription("Refreshes your sideloaded apps to prevent them from expiring.")
    }

    public init() {}

    public func perform() async throws -> some IntentResult {
        try await RefreshHandler.shared.startRefresh()
        return .result(dialog: "All apps have been refreshed.")
    }
}

@available(iOS 17.0, *)
public struct LiveContainerShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LCRefreshAllAppsIntent(),
            phrases: [
                "Refresh all apps in \(.applicationName)",
                "Refresh my \(.applicationName) apps"
            ],
            shortTitle: "Refresh All Apps",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}
