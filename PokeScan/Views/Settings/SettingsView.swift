import SwiftUI

public struct SettingsView: View {
    @AppStorage("card_language") private var cardLanguage = "IT"
    @AppStorage("auto_save_delay") private var autoSaveDelay = 3.0
    
    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Preferenze Scansione")) {
                    Picker("Lingua Carte Predefinita", selection: $cardLanguage) {
                        Text("Italiano (IT)").tag("IT")
                        Text("Inglese (EN)").tag("EN")
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Tempo Auto-Salvataggio")
                            Spacer()
                            Text(String(format: "%.1f sec", autoSaveDelay))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $autoSaveDelay, in: 1.5...5.0, step: 0.5)
                        Text("Tempo di attesa prima che la carta precedente venga salvata se non ne inquadri un'altra.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Motore Hardware & AI")) {
                    HStack {
                        Label("Riconoscimento", systemImage: "bolt.fill")
                        Spacer()
                        Text("Apple Vision (A18 Neural)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Latenza di Scansione", systemImage: "speedometer")
                        Spacer()
                        Text("~30-50 ms (Locale)")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Label("Catalogo Offline", systemImage: "internaldrive.fill")
                        Spacer()
                        Text("193 Set / 143 Simboli")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Esportazione Dati")) {
                    HStack {
                        Label("Formato File", systemImage: "doc.richtext.fill")
                        Spacer()
                        Text("Microsoft Excel (.xlsx)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Miniature e Simboli", systemImage: "photo.stack.fill")
                        Spacer()
                        Text("Incorporati nelle celle")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Informazioni PokéScan")) {
                    HStack {
                        Text("Versione")
                        Spacer()
                        Text("1.0.0 (Bulk Edition)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Database Carte")
                        Spacer()
                        Text("TCGdex API (Open Source)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Impostazioni")
        }
    }
}
