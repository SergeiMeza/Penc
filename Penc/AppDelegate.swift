//
//  AppDelegate.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 31.10.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Cocoa
import Foundation
import ApplicationServices
import Silica
import Sparkle

let WINDOW_ADJECENT_RESIZE_DETECTION_SIZE: CGFloat = 10

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, KeyboardListenerDelegate, PreferencesDelegate, NSMenuDelegate {
    
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    let preferencesWindowController = PreferencesWindowController.freshController()
    let aboutWindow = NSWindow(contentViewController: AboutViewController.freshController())
    var updater = SUUpdater()
    var disabledGlobally = false
    let keyboardListener = KeyboardListener()
    var activation: Activation? = nil
    var focusedWindow: SIWindow? = nil
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        Logger.shared.info("Booting...")
        
        let launcherAppId = "com.denizgurkaynak.PencLauncher"
        let runningApps = NSWorkspace.shared.runningApplications
        let isLauncherRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
        if isLauncherRunning {
            Logger.shared.debug("Launcher is running, killing it...")
            DistributedNotificationCenter.default().post(name: .killLauncher, object: Bundle.main.bundleIdentifier!)
        }
        
        if let button = self.statusItem.button {
            button.image = NSImage(named:"penc-menu-icon")
        }
        
        Logger.shared.info("Checking accessibility permissions...")
        
        if checkAccessibilityPermissions() {
            setupMenu()
            Preferences.shared.setDelegate(self)
            self.keyboardListener.setDelegate(self)
            
            self.setupAboutWindow()
            self.onPreferencesChanged()
            
            Logger.shared.info("Boot successful")
        } else {
            let warnAlert = NSAlert();
            warnAlert.messageText = "Accessibility permissions needed";
            warnAlert.informativeText = "Penc relies upon having permission to 'control your computer'. If the permission prompt did not appear automatically, go to System Preferences, Security & Privacy, Accessibility, and add Penc to the list of allowed apps. Then relaunch Penc."
            warnAlert.layout()
            warnAlert.runModal()
            NSApplication.shared.terminate(self)
        }
    }
    
    func checkAccessibilityPermissions() -> Bool {
        if AXIsProcessTrusted() {
            Logger.shared.info("We're trusted accessibility client")
            return true
        } else {
            let options = NSDictionary(object: kCFBooleanTrue, forKey: kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString) as CFDictionary
            let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
            Logger.shared.warn("We're NOT trusted accessibility client, manual check result: \(accessibilityEnabled)")
            return accessibilityEnabled
        }
    }
    
    func setupMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        let aboutMenuItem = NSMenuItem(title: "About Penc", action: #selector(AppDelegate.openAboutWindow(_:)), keyEquivalent: "")
        menu.addItem(aboutMenuItem)
        
        let checkForUpdatesMenuItem = NSMenuItem(title: "Check for updates", action: #selector(AppDelegate.checkForUpdates(_:)), keyEquivalent: "")
        menu.addItem(checkForUpdatesMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let disableToggleMenuItem = NSMenuItem(title: "Disable", action: #selector(AppDelegate.toggleDisable(_:)), keyEquivalent: "")
        disableToggleMenuItem.tag = 1
        menu.addItem(disableToggleMenuItem)
        
        let disableAppToggleMenuItem = NSMenuItem(title: "Disable for current app", action: #selector(AppDelegate.toggleDisableApp(_:)), keyEquivalent: "")
        disableAppToggleMenuItem.isEnabled = false
        disableAppToggleMenuItem.tag = 2
        menu.addItem(disableAppToggleMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let preferencesMenuItem = NSMenuItem(title: "Preferences...", action: #selector(AppDelegate.openPreferencesWindow(_:)), keyEquivalent: ",")
        menu.addItem(preferencesMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitMenuItem)
        
        self.statusItem.menu = menu
        self.statusItem.menu?.delegate = self
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        let disableToggleMenuItem = menu.item(withTag: 1)
        disableToggleMenuItem!.title = self.disabledGlobally ? "Enable" : "Disable"
        
        let disableAppToggleMenuItem = menu.item(withTag: 2)
        if let app = NSWorkspace.shared.frontmostApplication {
            if let appName = app.localizedName, let appBundleId = app.bundleIdentifier {
                if Preferences.shared.disabledApps.contains(appBundleId) {
                    disableAppToggleMenuItem!.title = "Enable for \"\(appName)\""
                } else {
                    disableAppToggleMenuItem!.title = "Disable for \"\(appName)\""
                }
                
                disableAppToggleMenuItem!.isEnabled = true
            }
        } else {
            disableAppToggleMenuItem!.title = "Disable for current app"
            disableAppToggleMenuItem!.isEnabled = false
        }
    }
    
    @objc func toggleDisable(_ sender: Any?) {
        self.disabledGlobally = !self.disabledGlobally
        Logger.shared.info(self.disabledGlobally ? "Disabled globally" : "Enabled globally")
    }
    
    @objc func toggleDisableApp(_ sender: Any?) {
        if let app = NSWorkspace.shared.frontmostApplication {
            if let appBundleId = app.bundleIdentifier {
                if Preferences.shared.disabledApps.contains(appBundleId) {
                    let i = Preferences.shared.disabledApps.firstIndex(of: appBundleId)
                    Preferences.shared.disabledApps.remove(at: i!)
                    Logger.shared.info("Enabled back for \(appBundleId)")
                } else {
                    Preferences.shared.disabledApps.append(appBundleId)
                    Logger.shared.info("Disabled for \(appBundleId)")
                }
                
                Preferences.shared.disabledApps = Preferences.shared.disabledApps
            }
        }
    }
    
    func setupAboutWindow() {
        self.aboutWindow.titleVisibility = .hidden
        self.aboutWindow.styleMask.remove(.resizable)
        self.aboutWindow.styleMask.remove(.miniaturizable)
    }
    
    @objc func openAboutWindow(_ sender: Any?) {
        self.aboutWindow.makeKeyAndOrderFront(self.aboutWindow)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    @objc func openPreferencesWindow(_ sender: Any?) {
        self.preferencesWindowController.showWindow(self)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func onPreferencesChanged() {
        let preferences = Preferences.shared
        self.keyboardListener.activationModifierKey = preferences.activationModifierKey
        self.keyboardListener.secondActivationModifierKeyPress = Double(preferences.activationSensitivity)
        self.keyboardListener.holdActivationModifierKeyTimeout = Double(preferences.holdDuration)
        
        OverlayWindowPool.shared.forEach { (poolItem) in
            poolItem.gesture.swipeDetectionVelocityThreshold = preferences.swipeDetectionVelocityThreshold
            poolItem.gesture.reverseScroll = preferences.reverseScroll
        }
    }
    
    func onActivationStarted() {
        guard !self.disabledGlobally else {
            Logger.shared.info("Not gonna activate, Penc is disabled globally")
            NSSound.beep()
            return
        }
        
        var focusedWindow = SIWindow.focused()
        // If focused window is finder's desktop window, ignore
        if focusedWindow?.title() == nil {
            if let focusedApp = focusedWindow?.app() {
                if focusedApp.title() == "Finder" {
                    Logger.shared.debug("Desktop is focused, ignoring")
                    focusedWindow = nil
                }
            }
        }
        
        do {
            self.activation = try Activation()
        } catch {
            Logger.shared.info("Not gonna activate: \(error.localizedDescription)")
            NSSound.beep()
            return
        }

        self.focusedWindow = focusedWindow
        
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func onKeyDownWhileActivated(pressedKeys: Set<UInt16>) {
        self.activation?.onKeyDown(pressedKeys: pressedKeys)
    }
    
    func onActivationCompleted() {
        guard self.activation != nil else { return }
        self.activation!.complete()
        self.activation = nil
        self.focusedWindow?.focusThisWindowOnly()
    }
    
    func onActivationAborted() {
        guard self.activation != nil else { return }
        self.activation!.abort()
        self.activation = nil
        self.focusedWindow?.focusThisWindowOnly()
    }
    
    @objc func checkForUpdates(_ sender: Any?) {
        Logger.shared.info("Checking for updates")
        self.updater.checkForUpdates(nil)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
}



