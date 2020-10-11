// Copyright 2018 Bret Taylor

import Cocoa

autoreleasepool {() -> () in
    let app = NSApplication.shared
    let delegate = ApplicationDelegate()
    app.delegate = delegate
    app.run()
}
