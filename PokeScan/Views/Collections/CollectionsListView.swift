import SwiftUI

public struct CollectionsListView: View {
    @ObservedObject var dataManager = DataManager.shared
    @State private var showCreateDialog = false
    @State private var newName = ""
    
    public var onSelectCollectionToScan: (() -> Void)?
    
    public var body: some View {
        NavigationStack {
            List {
                ForEach(dataManager.collections) { col in
                    NavigationLink(destination: CollectionDetailView(collectionId: col.id)) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(dataManager.activeCollectionId == col.id ? Color.blue.opacity(0.15) : Color(.systemGray6))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(dataManager.activeCollectionId == col.id ? .blue : .secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(col.name)
                                        .font(.system(size: 16, weight: .bold))
                                    
                                    if dataManager.activeCollectionId == col.id {
                                        Text("ATTIVA")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                    }
                                }
                                
                                Text("\(col.totalCards) carte  •  \(col.reverseCount) reverse  •  \(col.foilCount) foil")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            dataManager.selectActiveCollection(col.id)
                        } label: {
                            Label("Imposta Attiva", systemImage: "star.fill")
                        }
                        .tint(.blue)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let col = dataManager.collections[index]
                        dataManager.deleteCollection(id: col.id)
                    }
                }
            }
            .navigationTitle("Le Mie Collezioni")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateDialog = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
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
