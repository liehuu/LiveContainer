//
//  LCAppShortcuts.swift
//  LiveContainer
//
//  The AppShortcutsProvider behind the "Refresh All Apps" shortcut.
//
//  Why this file belongs to the main app target:
//  AppIntents reads Metadata.appintents out of the MAIN BUNDLE and resolves the
//  AppShortcutsProvider named there against the MAIN APP executable. The shortcut
//  used to come solely from the dylibified SideStore, whose provider type is
//  compiled into SideStoreApp.framework -- AppIntents never finds that and reports
//  "Couldn't find AppShortcutsProvider". Xcode emits a target's metadata
//  automatically once a provider is part of that target's sources.
//
//  The refresh itself still runs inside SideStore.framework, which owns the XPC
//  plumbing that launches the LiveProcess extension. On a cold launch from a
//  shortcut that framework has not been loaded yet, so we dlopen() it on demand
//  and drive it through the C entry points exported by SideStore/SideStore.swift.
//  That keeps this file free of any module dependency: the main app is otherwise
//  a pure C/Objective-C target, and importing SideStore from it does not build.
//

import Foundation
import AppIntents
import Darwin

@available(iOS 16.0, *)
public struct LCRefreshAllAppsIntent: AppIntent {
    public static var title: LocalizedStringResource { "Refresh All Apps" }
    public static var description: IntentDescription {
        IntentDescription("Refreshes your sideloaded apps to prevent them from expiring.")
    }

    public init() {}

    public func perform() async throws -> some IntentResult {
        try await LCSideStoreBridge.refreshAllApps()
        return .result(dialog: "All apps have been refreshed.")
    }
}

@available(iOS 16.0, *)
public struct LiveContainerShortcutsProvider: AppShortcutsProvider {
    // appShortcuts is an @AppShortcutsBuilder property: the entries are listed
    // directly. Wrapping them in an array literal makes the builder try to feed
    // the array to buildBlock(_: AppShortcut) and fails with
    // "cannot convert value of type '[AppShortcut]' to expected argument type 'AppShortcut'".
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LCRefreshAllAppsIntent(),
            phrases: [
                "Refresh all apps in \(.applicationName)",
                "Refresh my \(.applicationName) apps"
            ]
        )
    }
}

enum LCSideStoreBridgeError: LocalizedError {
    case frameworkMissing
    case loadFailed(String)
    case entryPointMissing
    case alreadyRunning
    case timedOut

    var errorDescription: String? {
        switch self {
        case .frameworkMissing:
            return "SideStore.framework is not bundled with this app."
        case .loadFailed(let detail):
            return "SideStore.framework could not be loaded: \(detail)"
        case .entryPointMissing:
            return "SideStore.framework does not export the refresh entry points."
        case .alreadyRunning:
            return "Another refresh is already in progress."
        case .timedOut:
            return "The refresh did not finish in time."
        }
    }
}

enum LCSideStoreBridge {
    private typealias StartFn = @convention(c) () -> Int32
    private typealias IsRunningFn = @convention(c) () -> Int32

    /// How long the shortcut waits for the background refresh before giving up.
    private static let timeout: TimeInterval = 15 * 60
    private static let pollInterval: UInt64 = 500_000_000 // 0.5s

    static func refreshAllApps() async throws {
        let framework = Bundle.main.bundlePath + "/Frameworks/SideStore.framework/SideStore"
        guard FileManager.default.fileExists(atPath: framework) else {
            throw LCSideStoreBridgeError.frameworkMissing
        }

        // RTLD_NOLOAD first so an already-loaded framework is reused rather than
        // having its Objective-C classes registered twice.
        var handle = dlopen(framework, RTLD_NOLOAD)
        if handle == nil {
            handle = dlopen(framework, RTLD_NOW)
        }
        guard let handle else {
            let detail = dlerror().map { String(cString: $0) } ?? "unknown error"
            throw LCSideStoreBridgeError.loadFailed(detail)
        }

        guard let startSym = dlsym(handle, "LCRefreshAllAppsStart"),
              let runningSym = dlsym(handle, "LCRefreshAllAppsIsRunning") else {
            throw LCSideStoreBridgeError.entryPointMissing
        }

        let start = unsafeBitCast(startSym, to: StartFn.self)
        let isRunning = unsafeBitCast(runningSym, to: IsRunningFn.self)

        // 1 means a refresh is already running; report it instead of racing it.
        if start() == 1 {
            throw LCSideStoreBridgeError.alreadyRunning
        }

        let deadline = Date().addingTimeInterval(timeout)
        while isRunning() != 0 {
            if Date() > deadline {
                throw LCSideStoreBridgeError.timedOut
            }
            try await Task.sleep(nanoseconds: pollInterval)
        }
    }
}
