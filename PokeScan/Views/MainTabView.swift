import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab = 0
    @ObservedObject var dataManager = DataManager.shared
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Fotocamera Scanner Hi-Tech
            ScannerView(onFinishScanning: {
                withAnimation {
                    selectedTab = 1
                }
            })
            .tabItem {
                Label("Scansione", systemImage: "viewfinder.circle.fill")
            }
            .tag(0)
            
            // Tab 2: Collezioni
            CollectionsListView(onSelectCollectionToScan: {
                withAnimation {
                    selectedTab = 0
                }
            })
            .tabItem {
                Label("Collezioni", systemImage: "rectangle.stack.fill")
            }
            .badge(dataManager.activeCollection?.totalCards ?? 0)
            .tag(1)
            
            // Tab 3: Impostazioni
            SettingsView()
                .tabItem {
                    Label("Impostazioni", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(PokeTheme.neonCyan)
    }
}
