import SwiftUI

public struct CollectionPickerModalView: View {
    @ObservedObject var dataManager = DataManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var newCollectionName = ""
    @State private var isCreating = false
    
    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Collezione Attiva per la Scansione")) {
                    ForEach(dataManager.collections) { col in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(col.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("\(col.totalCards) carte salvate")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if dataManager.activeCollectionId == col.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dataManager.selectActiveCollection(col.id)
                            dismiss()
                        }
                    }
                }
                
                Section(header: Text("Crea Nuova Collezione")) {
                    if isCreating {
                        HStack {
                            TextField("Nome (es: Bulk Scarlatto)", text: $newCollectionName)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("Salva") {
                                if !newCollectionName.trimmingCharacters(in: .whitespaces).isEmpty {
                                    _ = dataManager.createCollection(name: newCollectionName)
                                    newCollectionName = ""
                                    isCreating = false
                                    dismiss()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        Button(action: {
                            isCreating = true
                        }) {
                            Label("Crea Nuova Collezione", systemImage: "plus.circle.fill")
                                .foregroundColor(.blue)
                                .font(.body.weight(.semibold))
                        }
                    }
                }
            }
            .navigationTitle("Seleziona Collezione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
