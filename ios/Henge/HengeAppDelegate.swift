import UIKit

/// The app's UIKit delegate, for what SwiftUI's App cannot express.
final class HengeAppDelegate: NSObject, UIApplicationDelegate {
    /// Before iOS 27 the external display scene connects through Info.plist's
    /// external-display role entries (ExternalDisplaySceneDelegate); iOS 16+
    /// offers the non-interactive role, iOS 13–15 the plain one.
    /// With the SwiftUI lifecycle UIKit asks here for the application role only, never for those
    /// ones, with or without the plist entry; this records what it is asked so a device log shows it.
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        HengeLog.log("display", "scene configuration asked for role \(session.role.rawValue)")
        // Two external-display roles: the non-interactive one is iOS 16, the
        // plain one is what iOS 13–15 offers. Their raw values are fixed strings,
        // so comparing those keeps both working at one deployment floor.
        let role = session.role.rawValue
        if (role == "UIWindowSceneSessionRoleExternalDisplayNonInteractive"
            || role == "UIWindowSceneSessionRoleExternalDisplay"),
           LegacyExternalDisplay.offeredToAppDelegate {
            config.delegateClass = ExternalDisplaySceneDelegate.self
        }
        return config
    }

    /// iOS says this when memory is tight. A jetsam kill follows with no callback of its own, so this
    /// is the last warning the log can show; the footprint beside it says how close the process was.
    /// It is what tells a memory kill apart from a crash when the log simply stops.
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        HengeLog.log("memory", "iOS sent a memory warning")
        HengeLog.logFootprint("memory-warning")
    }
}
