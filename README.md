# PokéScan - Scanner di Carte Pokémon Bulk per iPhone 16

PokéScan è un'applicazione nativa iOS in **SwiftUI** e **Apple Vision**, ottimizzata per la scansione continua ad altissima velocità di carte Pokémon bulk, salvataggio in collezioni ed esportazione in fogli di calcolo **Microsoft Excel (.xlsx)** con miniature e simboli di espansione incorporati.

---

## ⚡ Caratteristiche Principali

1. **Riconoscimento Ultra-Rapido (~30-50 ms)**:
   - Sfrutta il Neural Engine di Apple (A18 su iPhone 16) con `VNRecognizeTextRequest` a 60 FPS.
   - Nessun costo API o token: funziona al 100% in locale e offline.
   - Legge le sigle ufficiali moderne (es. `SCR`, `SVI`, `PAL`, `SSP`, `151`) e le frazioni matematiche di Sole e Luna / vintage (es. `045/149`).

2. **Flusso di Scansione Continua a Zero Frizione**:
   - Inquadra la carta -> Il riepilogo appare istantaneamente in basso.
   - Di default la variante è impostata su **Regular**. Con un tap rapido puoi selezionare **Reverse** o **Foil**.
   - **Auto-Commit**: Se passi alla carta successiva o resti fermo per 3 secondi, la carta precedente viene salvata automaticamente nella collezione attiva con feedback aptico e notifica visiva.

3. **Gestione Collezioni**:
   - Scegli o crea una collezione prima di avviare la scansione (es. *"Bulk Scarlatto & Violetto"*, *"Doppioni Scambio"*, *"Scatola 1"*).
   - Visualizzazione statistiche: Totale carte, suddivisione Regular / Reverse / Foil, carte uniche.

4. **Esportazione Excel (.xlsx) Nativa con Immagini**:
   - Genera direttamente sul dispositivo un file `.xlsx` standard OpenXML.
   - Incorpora nelle celle:
     - **Miniatura reale della carta**
     - **Nome della carta**
     - **Simbolo reale dell'espansione**
     - **Nome espansione**
     - **Numero carta (es. 045/198)**
     - **Rarità (Comune, Non comune, Rara, ecc.)**
     - **Versione (Regular / Reverse / Foil)**
     - **Lingua (IT / EN)**
     - **Data di scansione**
   - Condivisione immediata tramite Share Sheet di iOS (AirDrop, File, WhatsApp, Mail).

5. **Catalogo Offline Integrato**:
   - 193 Set Pokémon indicizzati in Italiano e Inglese (`sets_catalog.json`).
   - 143 Simboli grafici PNG ufficiali inclusi nell'app (`symbols/`).

