//
//  AppDelegate.swift
//  Mox
//
//  Created by Christopher Lloyd on 2026.08.15.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore = SettingsStore()
    lazy var engineManager = EngineManager(settingsStore: settingsStore)
    lazy var taskStore = TaskStore { [weak engineManager] in engineManager?.client }
    private var preferencesController: PreferencesWindowController?
    private var terminationPending = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.mainMenu?.items.first?.submenu?.item(withTitle: "Preferences…")?.target = self
        NSApp.mainMenu?.items.first?.submenu?.item(withTitle: "Preferences…")?.action = #selector(showPreferences(_:))
        if let controller = NSApp.windows.first?.contentViewController as? ViewController {
            controller.configure(engineManager: engineManager, taskStore: taskStore, settingsStore: settingsStore)
        }
        Task {
            await engineManager.start()
            if engineManager.state == .ready { taskStore.startPolling() }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        taskStore.stopPolling()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminationPending else { return .terminateLater }
        terminationPending = true
        taskStore.stopPolling()
        Task {
            await engineManager.stop()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    @objc func showPreferences(_ sender: Any?) {
        if preferencesController == nil {
            preferencesController = PreferencesWindowController(settingsStore: settingsStore) { [weak self] settings in
                guard let self else { return }
                try self.settingsStore.save(settings)
                Task {
                    await self.engineManager.restart()
                    if self.engineManager.state == .ready { self.taskStore.startPolling() }
                }
            }
        }
        preferencesController?.showWindow(sender)
        preferencesController?.window?.makeKeyAndOrderFront(sender)
    }
}
