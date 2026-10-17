import Foundation
import Testing

/// Checks the app's build configuration as it ends up in the compiled bundle.
///
/// The project file is maintained without Xcode's UI, so these values are
/// verified here instead of being assumed.
struct AppConfigurationTests {
    @Test("Bundle identifier is com.ironflow.app")
    func bundleIdentifier() {
        #expect(Bundle.main.bundleIdentifier == "com.ironflow.app")
    }

    @Test("Development language is Brazilian Portuguese")
    func developmentLanguage() {
        #expect(Bundle.main.developmentLocalization == "pt-BR")
    }

    @Test("Display name is Iron Flow")
    func displayName() {
        let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        #expect(displayName == "Iron Flow")
    }

    /// The app is dark only. This key makes the system draw everything dark, whatever the device
    /// setting: the screens, the launch screen, alerts, menus, sheets and the keyboard. It is read here
    /// from the Debug build; the CI reads it again from the Release build.
    @Test("The app is dark only: UIUserInterfaceStyle is Dark")
    func appIsDarkOnly() {
        let style = Bundle.main.object(forInfoDictionaryKey: "UIUserInterfaceStyle") as? String
        #expect(style == "Dark")
    }
}
