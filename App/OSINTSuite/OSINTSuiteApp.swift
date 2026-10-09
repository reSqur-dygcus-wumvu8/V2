import SwiftUI
import FeatureHome
import FeatureAcquerir
import FeatureCapitaliser
import FeatureExploiter
import FeatureGerer

/// Point d'entrée de l'application OSINT Suite (macOS, iOS, iPadOS).
@main
struct OSINTSuiteApp: App {
    var body: some Scene {
        WindowGroup {
            AccueilView()
        }
        // Fenêtres multiples sur macOS et iPadOS.
        #if os(macOS)
        Window("Acquérir", id: "acquerir") { AcquerirView() }
        Window("Capitaliser", id: "capitaliser") { CapitaliserView() }
        Window("Exploiter", id: "exploiter") { ExploiterView() }
        Window("Gérer", id: "gerer") { GererView() }
        #endif
    }
}
