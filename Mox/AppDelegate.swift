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
    private var aboutController: AboutWindowController?
    private var mainWindow: NSWindow?
    private var preferencesController: PreferencesWindowController?
    private var terminationPending = false
    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        mainWindow = NSApp.windows.first { $0.contentViewController is ViewController }
        guard !isRunningTests else { return }
        configureMenus()
        if let controller = mainWindow?.contentViewController as? ViewController {
            controller.configure(engineManager: engineManager, taskStore: taskStore, settingsStore: settingsStore)
        }
        Task {
            await engineManager.start()
            if engineManager.state == .ready { taskStore.startPolling() }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        guard !isRunningTests else { return }
        taskStore.stopPolling()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isRunningTests else { return .terminateNow }
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if mainWindow == nil {
                mainWindow = sender.windows.first { $0.contentViewController is ViewController }
            }
            sender.activate(ignoringOtherApps: true)
            mainWindow?.makeKeyAndOrderFront(nil)
        }
        return true
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

    @objc func showAbout(_ sender: Any?) {
        if aboutController == nil { aboutController = AboutWindowController() }
        aboutController?.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        aboutController?.window?.orderFrontRegardless()
    }

    private func configureMenus() {
        if let appMenu = NSApp.mainMenu?.items.first?.submenu {
            if let settingsItem = appMenu.item(withTitle: "Preferences…") ?? appMenu.item(withTitle: "Settings…") {
                settingsItem.title = "Settings…"
                settingsItem.target = self
                settingsItem.action = #selector(showPreferences(_:))
            }
        }
        guard let fileMenu = NSApp.mainMenu?.item(withTitle: "File")?.submenu else { return }
        fileMenu.removeAllItems()
        let add = NSMenuItem(title: "New Download…", action: #selector(ViewController.newDocument(_:)), keyEquivalent: "n")
        let torrent = NSMenuItem(title: "Add Torrent…", action: #selector(ViewController.openDocument(_:)), keyEquivalent: "o")
        let close = NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.items = [add, torrent, .separator(), close]
    }
}
