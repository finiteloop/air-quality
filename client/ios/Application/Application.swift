// Copyright 2020 Bret Taylor

import UIKit

@main
class ApplicationDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = ApplicationController()
            self.window = window
            window.makeKeyAndVisible()
        }
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        if let applicationController = self.window?.rootViewController as? ApplicationController {
            applicationController.refreshStaleSensorData()
        }
    }
}

class ApplicationController: UINavigationController {
    private var _firstView = true

    init() {
        super.init(rootViewController: MapController())
        self.title = Bundle.main.infoDictionary![kCFBundleNameKey as String] as? String
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// If sensor data is stale, re-download it from the server.
    func refreshStaleSensorData() {
        if let mapController = self.viewControllers.first as? MapController {
            mapController.refreshStaleSensorData()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if _firstView && !UserDefaults.standard.bool(forKey: "loaded") {
            self.present(HelpController(), animated: true, completion: nil)
            UserDefaults.standard.setValue(true, forKey: "loaded")
        }
        _firstView = false
    }
}
