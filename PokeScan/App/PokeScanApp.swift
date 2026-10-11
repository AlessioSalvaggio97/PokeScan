import SwiftUI

@main
struct PokeScanApp: App {
    init() {
        // Pre-carica catalogo locale TCGdex all'avvio
        _ = SetCatalog.shared
        _ = DataManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
    }
}
