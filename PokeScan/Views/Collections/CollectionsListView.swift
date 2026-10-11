import SwiftUI

public struct CollectionsListView: View {
    @ObservedObject var dataManager = DataManager.shared
    @State private var showCreateDialog = false
    @State private var newName = ""
    
    public var onSelectCollectionToScan: (() -> Void)?
    
    public var body: some View {
        NavigationStack {
            ZStack {
                PokeTheme.bgDark.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(dataManager.collections) { col in
                            NavigationLink(destination: CollectionDetailView(collectionId: col.id)) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(dataManager.activeCollectionId == col.id ? PokeTheme.neonCyan.opacity(0.2) : Color.white.opacity(0.08))
                                            .frame(width: 48, height: 48)
                                        
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(dataManager.activeCollectionId == col.id ? PokeTheme.neonCyan : .white.opacity(0.6))
                                            .neonGlow(color: dataManager.activeCollectionId == col.id ? PokeTheme.neonCyan : Color.clear, radius: 6)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack(spacing: 8) {
                                            Text(col.name)
                                                .font(.system(size: 17, weight: .black))
                                                .foregroundColor(.white)
                                            
                                            if dataManager.activeCollectionId == col.id {
                                                Text("ATTIVA")
                                                    .font(.system(size: 9, weight: .black))
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 3)
                                                    .background(PokeTheme.neonCyan)
                                                    .foregroundColor(.black)
                                                    .cornerRadius(5)
                                                    .neonGlow(color: PokeTheme.neonCyan, radius: 4)
                                            }
                                        }
                                        
                                        HStack(spacing: 8) {
                                            Text("\(col.totalCards) carte")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(Color.white.opacity(0.8))
                                            Text("•")
                                                .foregroundColor(.white.opacity(0.4))
                                            Text("\(col.reverseCount) rev")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(PokeTheme.neonPurple)
                                            Text("•")
                                                .foregroundColor(.white.opacity(0.4))
                                            Text("\(col.foilCount) foil")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(PokeTheme.neonYellow)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .padding(16)
                                .glassPanel(
                                    cornerRadius: 18,
                                    borderColor: dataManager.activeCollectionId == col.id ? PokeTheme.neonCyan : Color.white.opacity(0.12)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    dataManager.selectActiveCollection(col.id)
                                } label: {
                                    Label("Imposta come Attiva per Scansione", systemImage: "star.fill")
                                }
                                
                                Button(role: .destructive) {
                                    dataManager.deleteCollection(id: col.id)
                                } label: {
                                    Label("Elimina Collezione", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                }
            }
            .navigationTitle("Le Mie Collezioni")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateDialog = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Nuova")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(PokeTheme.neonCyan)
                        .foregroundColor(.black)
                        .cornerRadius(16)
                        .neonGlow(color: PokeTheme.neonCyan, radius: 4)
                    }
                }
            }
            .alert("Nuova Collezione", isPresented: $showCreateDialog) {
                TextField("Nome Collezione (es: Bulk 151)", text: $newName)
                Button("Annulla", role: .cancel) { newName = "" }
                Button("Crea") {
                    if !newName.trimmingCharacters(in: .whitespaces).isEmpty {
                        _ = dataManager.createCollection(name: newName)
                        newName = ""
                    }
                }
            } message: {
                Text("Inserisci un nome per la nuova collezione di carte bulk.")
            }
        }
    }
}
