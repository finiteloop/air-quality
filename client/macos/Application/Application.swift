// Copyright 2020 Bret Taylor

import Cocoa

class ApplicationDelegate: NSObject, NSApplicationDelegate {
    var _controller: ApplicationWindowController
    
    override init() {
        _controller = ApplicationWindowController()
        super.init()
        self._createMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        _controller.window?.setFrameAutosaveName("Air")
        _controller.window?.makeKeyAndOrderFront(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    private func _createMenu() {
        let applicationName = Bundle.main.infoDictionary![kCFBundleNameKey! as String] as! String
        let mainMenu = NSMenu(title: applicationName)

        @discardableResult
        func addMenu(title: String, items: Array<NSMenuItem>) -> NSMenu {
            let menu = NSMenu(title: title)
            for item in items {
                menu.addItem(item)
            }
            mainMenu.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = menu
            return menu
        }

        addMenu(title: applicationName, items: self._applicationMenu())
        addMenu(title: NSLocalizedString("View", comment: "View menu"), items: self._viewMenu())
        NSApplication.shared.windowsMenu = addMenu(title: NSLocalizedString("Window", comment: "Window menu"), items: self._windowMenu())
        NSApplication.shared.helpMenu = addMenu(title: NSLocalizedString("Help", comment: "Help menu"), items: self._helpMenu())
        NSApplication.shared.mainMenu = mainMenu
    }
    
    private func _applicationMenu() -> Array<NSMenuItem> {
        let applicationName = Bundle.main.infoDictionary![kCFBundleNameKey! as String] as! String
        return [
            NSMenuItem(title: String(format: NSLocalizedString("About %@", comment: "About <Application> menu item"), applicationName), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""),
            NSMenuItem.separator(),
            {() -> NSMenuItem in
                let title = NSLocalizedString("Services", comment: "Services menu item")
                let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                let servicesMenu = NSMenu(title: title)
                menuItem.submenu = servicesMenu
                NSApplication.shared.servicesMenu = servicesMenu
                return menuItem
            }(),
            NSMenuItem.separator(),
            NSMenuItem(title: String(format: NSLocalizedString("Hide %@", comment: "Hide <Application> menu item"), applicationName), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"),
            {() -> NSMenuItem in
                let menuItem = NSMenuItem(title: NSLocalizedString("Hide Others", comment: "Show All menu item"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
                menuItem.keyEquivalentModifierMask = [.command, .option]
                return menuItem
            }(),
            NSMenuItem(title: NSLocalizedString("Show All", comment: "Show All menu item"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""),
            NSMenuItem.separator(),
            NSMenuItem(title: String(format: NSLocalizedString("Quit %@", comment: "Quit <Application> menu item"), applicationName), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"),
        ]
    }
    
    private func _viewMenu() -> Array<NSMenuItem> {
        return [
            NSMenuItem(title: NSLocalizedString("Enter Full Screen", comment: "Enter Full Screen menu item"), action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f"),
        ]
    }

    private func _windowMenu() -> Array<NSMenuItem> {
        return [
            NSMenuItem(title: NSLocalizedString("Minimize", comment: "Minimize menu item"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"),
            NSMenuItem(title: NSLocalizedString("Zoom", comment: "Zoom menu item"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""),
        ]
    }

    private func _helpMenu() -> Array<NSMenuItem> {
        let applicationName = Bundle.main.infoDictionary![kCFBundleNameKey! as String] as! String
        return [
            NSMenuItem(title: String(format: NSLocalizedString("%@ Help", comment: "<Application> Help menu item"), applicationName), action: #selector(NSApplication.showHelp(_:)), keyEquivalent: "?"),
        ]
    }
}

class ApplicationWindowController: NSWindowController, NSToolbarDelegate, MapControllerDelegate {
    init() {
        let mapController = MapController()
        super.init(window: NSWindow(contentViewController: mapController))
        self.window?.title = NSLocalizedString("Air Quality Index", comment: "Title of main map displaying AQI by location")
        let toolbar = NSToolbar(identifier: self.className)
        toolbar.delegate = self
        self.window?.toolbar = toolbar
        self.window?.titleVisibility = .hidden
        mapController.mapControllerDelagate = self

        // Auto-update every 10 minutes
        Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { (timer) in
            if let map = self.window?.contentViewController as? MapController {
                map.downloadSensorData(interactive: false)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            NSToolbarItem.Identifier("Location"),
            NSToolbarItem.Identifier("Search"),
            NSToolbarItem.Identifier("Refresh"),
        ]
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            NSToolbarItem.Identifier.flexibleSpace,
            NSToolbarItem.Identifier.space,
            NSToolbarItem.Identifier("Location"),
            NSToolbarItem.Identifier("Search"),
            NSToolbarItem.Identifier("Refresh"),
            NSToolbarItem.Identifier("Progress"),
            NSToolbarItem.Identifier.flexibleSpace,
        ]
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier.rawValue {
        case "Search":
            let search = NSSearchField(frame: NSMakeRect(0, 0, 300, 10))
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = NSLocalizedString("Search", comment: "Search the map")
            item.view = search
            return item
        case "Refresh":
            let label = NSLocalizedString("Refresh", comment: "Refresh the sensor data on the map")
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = label
            item.toolTip = label
            item.action = #selector(self._refresh)
            let button = NSButton(image: NSImage(named: NSImage.refreshTemplateName)!, target: nil, action: item.action)
            button.bezelStyle = .texturedRounded
            button.sizeToFit()
            item.view = button
            return item
        case "Progress":
            let label = NSLocalizedString("Download Progress", comment: "Progress of new sensor data download")
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = label
            item.toolTip = label
            let progress = NSProgressIndicator()
            progress.wantsLayer = true
            progress.style = .spinning
            progress.isIndeterminate = false
            progress.minValue = 0
            progress.maxValue = 1
            progress.doubleValue = 0
            progress.controlSize = .small
            progress.isDisplayedWhenStopped = true
            progress.isHidden = true
            item.view = progress
            return item
        case "Location":
            let label = NSLocalizedString("Current Location", comment: "Center the map on the user's current location")
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = label
            item.toolTip = label
            item.action = #selector(self._currentLocation)
            let image = NSImage(imageLiteralResourceName: "Location")
            image.isTemplate = true
            let button = NSButton(image: image, target: nil, action: item.action)
            button.bezelStyle = .texturedRounded
            button.sizeToFit()
            item.view = button
            return item
        default:
            return nil
        }
    }

    func mapControllerDownloadStarted(_ mapController: MapController, interactive: Bool) {
        if let indicator = self._progressIndicator() {
            indicator.doubleValue = 0
            indicator.isHidden = !interactive
        }
    }
    
    func mapControllerDownloading(_ mapController: MapController, interactive: Bool, progess: Float) {
        if let indicator = self._progressIndicator() {
            indicator.doubleValue = Double(progess)
        }
    }
    
    func mapControllerDownloadCompleted(_ mapController: MapController, interactive: Bool, withError error: Error?) {
        if let indicator = self._progressIndicator() {
            indicator.doubleValue = 1
            indicator.isHidden = true
        }
        if error != nil,
           let window = self.window,
           interactive {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = NSLocalizedString("Unable to download new air quality data", comment: "Error message when new map data cannot be downloaded")
            alert.informativeText = NSLocalizedString("There may be a problem with your internet connection or a temporary problem with the air quality server.", comment: "Error message description when new map data cannot be downloaded")
            alert.beginSheetModal(for: window, completionHandler: nil)
        }
    }
    
    @objc private func _refresh(_ button: NSButton?) {
        if let map = self.window?.contentViewController as? MapController {
            map.downloadSensorData(interactive: true)
        }
    }
    
    @objc private func _currentLocation(_ button: NSButton?) {
        if let map = self.window?.contentViewController as? MapController {
            if !map.centerMapOnCurrentLocation(),
               let window = self.window {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = NSLocalizedString("Cannot determine current location", comment: "Error message when current location cannot be detected")
                alert.informativeText = NSLocalizedString("Ensure WiFi is enabled. If you continue to observe this problem, ensure this application has access to Location Services in your Security & Privacy system preferences.", comment: "Error message description when current location cannot be detected")
                alert.beginSheetModal(for: window, completionHandler: nil)
            }
        }
    }
    
    private func _toolbarItem(_ identifier: String) -> NSToolbarItem? {
        if let toolbar = self.window?.toolbar {
            for item in toolbar.items {
                if item.itemIdentifier.rawValue == identifier {
                    return item
                }
            }
        }
        return nil
    }
    
    private func _progressIndicator() -> NSProgressIndicator? {
        if let item = self._toolbarItem("Progress") {
            return item.view as? NSProgressIndicator
        }
        return nil
    }
}
