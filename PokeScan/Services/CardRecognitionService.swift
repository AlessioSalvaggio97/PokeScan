import Foundation
import Vision
import AVFoundation
import UIKit
import Combine

public class CardRecognitionService: ObservableObject, CameraFrameDelegate {
    public static let shared = CardRecognitionService()
    
    // Stato carta correntemente inquadrata nel banner
    @Published public var currentCard: PokemonCard?
    @Published public var isAnalyzing = false
    @Published public var lastCommittedCardName: String?
    @Published public var scanCountThisSession: Int = 0
    @Published public var isWaitingForNewCard = false
    
    private let visionQueue = DispatchQueue(label: "com.pokescan.vision", qos: .userInitiated)
    private var isBusy = false
    private var lastProcessTime: TimeInterval = 0
    
    // Tracking di stato e blocco anti-duplicati
    private var activeTrackingLocalId: String?
    private var activeTrackingSetId: String?
    private var lastCommittedLocalId: String?
    private var lastCommittedSetId: String?
    private var newCardCandidateLocalId: String?
    private var newCardStabilityCount = 0
    private var consecutiveEmptyFrames = 0
    
    private var lastDetectedKey: String?
    private var frameStabilityCount = 0
    
    private init() {}
    
    private func normalizeLocalId(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("O") && cleaned.dropFirst().allSatisfy({ $0.isNumber }) {
            cleaned = "0" + cleaned.dropFirst()
        }
        return cleaned
    }
    
    private func isMatchingLocalId(_ id1: String?, _ id2: String?) -> Bool {
        guard let id1 = id1, let id2 = id2 else { return false }
        let n1 = normalizeLocalId(id1)
        let n2 = normalizeLocalId(id2)
        if n1 == n2 { return true }
        if let i1 = Int(n1), let i2 = Int(n2) {
            return i1 == i2
        }
        return false
    }
    
    public func didCaptureFrame(_ sampleBuffer: CMSampleBuffer) {
        let now = Date().timeIntervalSince1970
        guard now - lastProcessTime > 0.22, !isBusy else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        lastProcessTime = now
        isBusy = true
        
        visionQueue.async { [weak self] in
            self?.processFrame(pixelBuffer)
        }
    }
    
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        let request = VNRecognizeTextRequest { [weak self] req, error in
            defer { self?.isBusy = false }
            guard let self = self, error == nil,
                  let observations = req.results as? [VNRecognizedTextObservation] else {
                return
            }
            self.analyzeObservations(observations, pixelBuffer: pixelBuffer)
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
    }
    
    /// Ritaglia una regione normalizzata Vision dal CVPixelBuffer e restituisce una CGImage
    private func cropPixelBuffer(
        _ pixelBuffer: CVPixelBuffer,
        normalizedRect: CGRect
    ) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ciImage.extent
        
        let pixelRect = CGRect(
            x: normalizedRect.origin.x * extent.width,
            y: normalizedRect.origin.y * extent.height,
            width: normalizedRect.width * extent.width,
            height: normalizedRect.height * extent.height
        )
        
        guard pixelRect.width > 10, pixelRect.height > 10, extent.contains(pixelRect) else {
            return nil
        }
        return ciContext.createCGImage(ciImage, from: pixelRect)
    }
    
    private func analyzeObservations(_ observations: [VNRecognizedTextObservation], pixelBuffer: CVPixelBuffer) {
        guard !observations.isEmpty else { return }
        
        struct TextElement {
            let text: String
            let x: CGFloat
            let y: CGFloat
            let box: CGRect
        }
        
        let elements = observations.compactMap { obs -> TextElement? in
            guard let top = obs.topCandidates(1).first else { return nil }
            let t = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return nil }
            return TextElement(text: t, x: obs.boundingBox.origin.x, y: obs.boundingBox.origin.y, box: obs.boundingBox)
        }
        guard !elements.isEmpty else { return }
        
        let sortedDesc = elements.sorted { $0.y > $1.y }
        
        // 1. RICONOSCIMENTO NOME POKÉMON (In alto, y >= 0.40)
        var detectedPokemonName: String? = nil
        let topElements = sortedDesc.filter { $0.y >= 0.40 }
        for item in topElements {
            if let name = cleanPokemonName(from: item.text), name.count >= 3 {
                detectedPokemonName = name
                break
            }
        }
        if detectedPokemonName == nil {
            for item in sortedDesc where item.y >= 0.20 {
                if let name = cleanPokemonName(from: item.text), name.count >= 3 {
                    detectedPokemonName = name
                    break
                }
            }
        }
        
        // ------------------------------------------------------------------
        // LOGICA DI RICONOSCIMENTO RIGOROSA:
        // if (parte_sinistra ha sigla)   -> cerca match sigla espansione -> cerca match numero
        // else (parte sinistra ha logo)  -> cerca match logo espansione  -> cerca match numero
        // ------------------------------------------------------------------
        var detectedSetId: String? = nil
        var detectedLocalId: String? = nil
        var detectedTotalCards: String? = nil
        var candidateSetIds: [String] = []
        var detectedLanguage = "IT"
        
        let allJoined = sortedDesc.map { $0.text }.joined(separator: " ")
        if let langMatch = allJoined.range(of: #"\b(IT|EN)\b"#, options: .regularExpression) {
            detectedLanguage = String(allJoined[langMatch]).uppercased()
        }
        
        let bottomElements = sortedDesc.filter { $0.y <= 0.40 }
        let bottomLeftElements = bottomElements.filter { $0.x <= 0.50 }
        let bottomLeftJoined = bottomLeftElements.map { $0.text }.joined(separator: " ")
        
        // 0. VERIFICA PROMO SPECIALI (SVP, SWSHP, SMP, XYP, BWP, DPP)
        let promoPattern = #"(?i)\b(SVP|SWSHP|SWSH|SMP|SM|XYP|XY|BWP|DPP)\s*(?:EN|IT)?\s*#?([A-Za-z0-9]{1,4})\b"#
        if let regex = try? NSRegularExpression(pattern: promoPattern) {
            let ns = allJoined as NSString
            if let m = regex.firstMatch(in: allJoined, range: NSRange(location: 0, length: ns.length)) {
                let prefix = ns.substring(with: m.range(at: 1)).lowercased()
                let pNum = ns.substring(with: m.range(at: 2))
                
                if prefix.contains("svp") { detectedSetId = "svp" }
                else if prefix.contains("swsh") { detectedSetId = "swshp" }
                else if prefix.contains("sm") { detectedSetId = "smp" }
                else if prefix.contains("xy") { detectedSetId = "xyp" }
                else if prefix.contains("bw") { detectedSetId = "bwp" }
                else if prefix.contains("dp") { detectedSetId = "dpp" }
                
                detectedLocalId = pNum
            }
        }
        
        if detectedSetId == nil {
            // STEP A: VERIFICA SE LA PARTE SINISTRA HA UNA SIGLA (Scarlatto e Violetto / MegaEvoluzioni)
            let bracketPattern = #"\[\s*([A-Za-z0-9.]{2,7})\s*\]"#
            
            // 1. Cerca codice tra parentesi nel riquadro in basso a sinistra (es. "[SVI]", "[ASC]", "[ME02.5]", "[SCR]")
            if let regex = try? NSRegularExpression(pattern: bracketPattern, options: .caseInsensitive) {
                let ns = bottomLeftJoined as NSString
                let matches = regex.matches(in: bottomLeftJoined, range: NSRange(location: 0, length: ns.length))
                for m in matches {
                    let code = ns.substring(with: m.range(at: 1))
                    if let setInfo = SetCatalog.shared.findSetByCode(code) {
                        detectedSetId = setInfo.id
                        break
                    }
                }
            }
            
            // 2. Cerca token alfanumerici corrispondenti a sigle note nella parte sinistra (es. "SVI", "ASC", "SCR", "SSP")
            if detectedSetId == nil {
                for item in bottomLeftElements {
                    let words = item.text.components(separatedBy: CharacterSet.alphanumerics.inverted)
                    for w in words where w.count >= 2 && w.count <= 6 {
                        if let setInfo = SetCatalog.shared.findSetByCode(w) {
                            detectedSetId = setInfo.id
                            break
                        }
                    }
                    if detectedSetId != nil { break }
                }
            }
            
            // 3. Fallback parentesi [SIGLA] in tutta la carta
            if detectedSetId == nil {
                if let regex = try? NSRegularExpression(pattern: bracketPattern, options: .caseInsensitive) {
                    let ns = allJoined as NSString
                    let matches = regex.matches(in: allJoined, range: NSRange(location: 0, length: ns.length))
                    for m in matches {
                        let code = ns.substring(with: m.range(at: 1))
                        if let setInfo = SetCatalog.shared.findSetByCode(code) {
                            detectedSetId = setInfo.id
                            break
                        }
                    }
                }
            }
            
            // -------------------------------------------------------------
            // RAMO 1: PARTE SINISTRA HA SIGLA -> CERCA MATCH NUMERO DI QUELLA ESPANSIONE
            // -------------------------------------------------------------
            if detectedSetId != nil {
                // Cerca frazione (es: "056/217", "056/165", "045/091")
                let fracPattern = #"(?i)\b([A-Za-z]{0,2}\d{1,3})\s*/\s*(\d{1,3})\b"#
                if let regex = try? NSRegularExpression(pattern: fracPattern) {
                    let ns = allJoined as NSString
                    if let m = regex.firstMatch(in: allJoined, range: NSRange(location: 0, length: ns.length)) {
                        detectedLocalId = ns.substring(with: m.range(at: 1))
                        detectedTotalCards = ns.substring(with: m.range(at: 2))
                    }
                }
                
                // Se non c'è frazione, cerca numero isolato negli elementi inferiori
                if detectedLocalId == nil {
                    for item in bottomElements where item.y <= 0.28 {
                        let words = item.text.components(separatedBy: CharacterSet.alphanumerics.inverted)
                        for w in words where w.count >= 1 && w.count <= 3 && w.allSatisfy({ $0.isNumber }) {
                            detectedLocalId = w
                            break
                        }
                        if detectedLocalId != nil { break }
                    }
                }
            }
            // -------------------------------------------------------------
            // RAMO 2: PARTE SINISTRA HA SIMBOLINO (Spada & Scudo, Sole & Luna, Pre-SV)
            // -------------------------------------------------------------
            else {
                // Cerca frazione numerica (es: "056/196", "123/202", "045/149", "TG05/TG30")
                let fracPattern = #"(?i)\b([A-Za-z]{0,2}\d{1,3})\s*/\s*(\d{1,3}|[A-Za-z]{0,2}\d{1,3})\b"#
                if let regex = try? NSRegularExpression(pattern: fracPattern) {
                    let ns = allJoined as NSString
                    if let m = regex.firstMatch(in: allJoined, range: NSRange(location: 0, length: ns.length)) {
                        let num = ns.substring(with: m.range(at: 1))
                        let total = ns.substring(with: m.range(at: 2))
                        
                        let candidates = SetCatalog.shared.findSetsByDenominator(total)
                        candidateSetIds = candidates.map { $0.id }
                        
                        if candidates.count == 1 {
                            // C'è un solo set con questo denominatore totale
                            detectedSetId = candidates[0].id
                            detectedLocalId = num
                            detectedTotalCards = total
                        } else if candidates.count > 1 {
                            // Multipli set candidati: CERCA MATCH LOGO DELL'ESPANSIONE
                            let leftRect = CGRect(x: 0.03, y: 0.02, width: 0.28, height: 0.18) // Logo a sinistra (Spada e Scudo)
                            let rightRect = CGRect(x: 0.68, y: 0.02, width: 0.28, height: 0.18) // Logo a destra (Sole e Luna / XY)
                            
                            var matchedCandidate: String? = nil
                            var bestDistance: Float = 0.88 // Soglia per accettare similarità visiva
                            
                            // Test logo a sinistra (Spada e Scudo)
                            if let leftCG = cropPixelBuffer(pixelBuffer, normalizedRect: leftRect),
                               let resLeft = SetCatalog.shared.matchBestCandidateSymbol(from: leftCG, among: candidateSetIds),
                               resLeft.distance < bestDistance {
                                matchedCandidate = resLeft.bestSetId
                                bestDistance = resLeft.distance
                            }
                            // Test logo a destra (Sole e Luna / XY)
                            if let rightCG = cropPixelBuffer(pixelBuffer, normalizedRect: rightRect),
                               let resRight = SetCatalog.shared.matchBestCandidateSymbol(from: rightCG, among: candidateSetIds),
                               resRight.distance < bestDistance {
                                matchedCandidate = resRight.bestSetId
                                bestDistance = resRight.distance
                            }
                            
                            if let matched = matchedCandidate {
                                detectedSetId = matched
                                detectedLocalId = num
                                detectedTotalCards = total
                            }
                        }
                    }
                }
            }
        }
        
        // ------------------------------------------------------------------
        // GATE DI SICUREZZA FONDAMENTALE:
        // La scansione procede SOLO ED ESCLUSIVAMENTE se:
        // 1) L'espansione è stata identificata con certezza (detectedSetId != nil)
        // 2) Il numero della carta per quell'espansione è stato trovato (detectedLocalId != nil).
        // Se manca l'espansione, IGNORA IL FRAME: evita che determinati numeri
        // vengano scambiati o confusi tra più carte diverse.
        // ------------------------------------------------------------------
        guard let setId = detectedSetId, let rawLocalId = detectedLocalId else {
            consecutiveEmptyFrames += 1
            // Se per almeno 3 frame consecutivi (~0.6-0.8s) non viene inquadrata alcuna carta:
            if consecutiveEmptyFrames >= 3 {
                lastDetectedKey = nil
                frameStabilityCount = 0
                newCardCandidateLocalId = nil
                newCardStabilityCount = 0
                if isWaitingForNewCard || lastCommittedLocalId != nil {
                    lastCommittedLocalId = nil
                    lastCommittedSetId = nil
                    DispatchQueue.main.async { [weak self] in
                        self?.isWaitingForNewCard = false
                    }
                }
            }
            return
        }
        
        // Carta rilevata nel frame corrente con Set e Numero confermati: azzera frame vuoti
        consecutiveEmptyFrames = 0
        let localId = normalizeLocalId(rawLocalId)
        
        // ------------------------------------------------------------------
        // CASO 1: SISTEMA IN BLOCCO POST-SALVATAGGIO (Anti-Duplicati)
        // ------------------------------------------------------------------
        if isWaitingForNewCard, let committedLocalId = lastCommittedLocalId {
            let isSameCard = isMatchingLocalId(localId, committedLocalId) && (lastCommittedSetId == nil || lastCommittedSetId == setId)
            if isSameCard {
                // La fotocamera sta ANCORA inquadrando la stessa carta: blocca e ignora!
                newCardCandidateLocalId = nil
                newCardStabilityCount = 0
                return
            } else {
                // Rilevato un numero diverso: verifica che sia stabile per almeno 2 frame
                if isMatchingLocalId(newCardCandidateLocalId, localId) {
                    newCardStabilityCount += 1
                } else {
                    newCardCandidateLocalId = localId
                    newCardStabilityCount = 1
                    return
                }
                
                guard newCardStabilityCount >= 2 else { return }
                
                // Nuova carta confermata! Sblocca il sistema
                lastCommittedLocalId = nil
                lastCommittedSetId = nil
                newCardCandidateLocalId = nil
                newCardStabilityCount = 0
                DispatchQueue.main.async { [weak self] in
                    self?.isWaitingForNewCard = false
                }
            }
        }
        
        // ------------------------------------------------------------------
        // CASO 2: CARTA GIÀ INQUADRATA SUL BANNER (In attesa di conferma utente)
        // ------------------------------------------------------------------
        if currentCard != nil {
            // Se la fotocamera sta ancora inquadrando la carta attiva, perfeziona i dettagli in-place (es. nome/set più nitido)
            if let activeId = activeTrackingLocalId, isMatchingLocalId(localId, activeId) {
                refineActiveCardIfNeeded(
                    detectedSetId: setId,
                    detectedPokemonName: detectedPokemonName,
                    totalCards: detectedTotalCards,
                    candidateSetIds: candidateSetIds,
                    language: detectedLanguage
                )
            }
            // Attende la conferma manuale dell'utente (tramite pulsante "Conferma" o "Scarta").
            // Ignora qualsiasi altra carta nel mirino finché l'utente non conferma o scarta.
            return
        }
        
        // ------------------------------------------------------------------
        // CASO 3: NUOVA CARTA DA AGGANCIARE (Richiede stabilità di 2 frame)
        // ------------------------------------------------------------------
        let cardKey = "\(setId)_\(localId)"
        if lastDetectedKey == cardKey {
            frameStabilityCount += 1
        } else {
            lastDetectedKey = cardKey
            frameStabilityCount = 1
            return
        }
        
        guard frameStabilityCount >= 2 else { return }
        
        // Nuova carta stabilizzata: imposta il tracking
        activeTrackingLocalId = localId
        activeTrackingSetId = setId
        
        DispatchQueue.main.async { [weak self] in
            self?.handleDetectedCard(
                pokemonName: detectedPokemonName,
                setId: setId,
                localId: localId,
                totalCards: detectedTotalCards,
                candidateSetIds: candidateSetIds,
                language: detectedLanguage
            )
        }
    }
    
    /// Perfeziona i metadati della carta attualmente mostrata nel banner senza ricrearla o duplicarla
    private func refineActiveCardIfNeeded(
        detectedSetId: String?,
        detectedPokemonName: String?,
        totalCards: String?,
        candidateSetIds: [String],
        language: String
    ) {
        let hasNewSet = (detectedSetId != nil && detectedSetId != activeTrackingSetId)
        guard hasNewSet || detectedPokemonName != nil else { return }
        
        if hasNewSet {
            activeTrackingSetId = detectedSetId
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, var card = self.currentCard else { return }
            var changed = false
            
            if let newSetId = detectedSetId, card.setId != newSetId {
                card.setId = newSetId
                let setInfo = SetCatalog.shared.sets[newSetId]
                card.setName = setInfo?.localizedName(language: language) ?? newSetId.uppercased()
                if let sym = SetCatalog.shared.getSymbolData(for: newSetId) {
                    card.symbolData = sym
                }
                changed = true
            }
            
            if let newName = detectedPokemonName?.capitalized, card.name.hasPrefix("Carta ") || (card.name != newName && !newName.isEmpty) {
                card.name = newName
                changed = true
            }
            
            if changed {
                self.currentCard = card
                
                Task {
                    let resolved = await TCGdexService.shared.resolveCard(
                        pokemonName: card.name,
                        setId: card.setId,
                        localId: card.localId,
                        totalCards: totalCards ?? card.totalCards,
                        candidateSetIds: candidateSetIds,
                        language: language
                    )
                    await MainActor.run {
                        if var active = self.currentCard, self.isMatchingLocalId(active.localId, card.localId) {
                            active.name = resolved.name
                            active.setId = resolved.setId
                            active.setName = resolved.setName
                            active.rarity = resolved.rarity
                            active.imageURL = resolved.imageURL
                            if let thumb = resolved.thumbnailData {
                                active.thumbnailData = thumb
                            }
                            if let sym = SetCatalog.shared.getSymbolData(for: resolved.setId) {
                                active.symbolData = sym
                            }
                            self.currentCard = active
                        }
                    }
                }
            }
        }
    }
    
    private func handleDetectedCard(
        pokemonName: String?,
        setId: String,
        localId: String,
        totalCards: String?,
        candidateSetIds: [String] = [],
        language: String
    ) {
        lastCommittedLocalId = nil
        lastCommittedSetId = nil
        isWaitingForNewCard = false
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let initialName = pokemonName?.capitalized ?? "Carta \(localId)"
        let setInfo = SetCatalog.shared.sets[setId]
        let setName = setInfo?.localizedName(language: language) ?? setId.uppercased()
        let symbolData = SetCatalog.shared.getSymbolData(for: setId)
        
        // Carta temporanea creata univocamente per il set identificato
        let tempCard = PokemonCard(
            name: initialName,
            localId: localId,
            setId: setId,
            setName: setName,
            totalCards: totalCards,
            rarity: "Comune",
            variant: .regular,
            language: language,
            imageURL: nil,
            thumbnailData: nil,
            symbolData: symbolData,
            scannedAt: Date()
        )
        
        self.currentCard = tempCard
        
        // RISOLUZIONE INTELLIGENTE & DISAMBIGUAZIONE CON TCGDEX
        Task {
            let resolved = await TCGdexService.shared.resolveCard(
                pokemonName: pokemonName,
                setId: setId,
                localId: localId,
                totalCards: totalCards,
                candidateSetIds: candidateSetIds,
                language: language
            )
            
            await MainActor.run {
                if var active = self.currentCard, self.isMatchingLocalId(active.localId, localId) {
                    active.name = resolved.name
                    active.setId = resolved.setId
                    active.setName = resolved.setName
                    active.rarity = resolved.rarity
                    active.imageURL = resolved.imageURL
                    if let thumb = resolved.thumbnailData {
                        active.thumbnailData = thumb
                    }
                    if let sym = SetCatalog.shared.getSymbolData(for: resolved.setId) {
                        active.symbolData = sym
                    }
                    self.currentCard = active
                }
            }
        }
    }
    
    public func commitCurrentCardIfPresent() {
        guard let card = currentCard else { return }
        DataManager.shared.addCardToActiveCollection(card)
        lastCommittedCardName = "\(card.name) (\(card.formattedNumber))"
        scanCountThisSession += 1
        
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        
        // Blocca la scansione sulla carta appena acquisita finché non viene rimossa o cambiata
        lastCommittedLocalId = card.localId
        lastCommittedSetId = card.setId
        activeTrackingLocalId = nil
        activeTrackingSetId = nil
        newCardCandidateLocalId = nil
        newCardStabilityCount = 0
        isWaitingForNewCard = true
        
        currentCard = nil
    }
    
    public func discardCurrentCard() {
        if let card = currentCard {
            lastCommittedLocalId = card.localId
            lastCommittedSetId = card.setId
            isWaitingForNewCard = true
        }
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
        
        activeTrackingLocalId = nil
        activeTrackingSetId = nil
        newCardCandidateLocalId = nil
        newCardStabilityCount = 0
        currentCard = nil
    }
    
    public func setVariant(_ variant: CardVariant) {
        guard var card = currentCard else { return }
        card.variant = variant
        currentCard = card
        
        let haptic = UISelectionFeedbackGenerator()
        haptic.selectionChanged()
    }
    
    /// Pulisce il testo della riga in alto per isolare il solo nome del Pokémon
    private func cleanPokemonName(from line: String) -> String? {
        var str = line
        // Rimuove HP/PS e numeri di salute (es: "HP 70", "PS 120", "150 HP")
        str = str.replacingOccurrences(of: #"(?i)\b(HP|PS|PV)\s*\d{2,3}\b"#, with: "", options: .regularExpression)
        str = str.replacingOccurrences(of: #"(?i)\b\d{2,3}\s*(HP|PS|PV)\b"#, with: "", options: .regularExpression)
        // Rimuove parole di stadio e prefissi comuni
        str = str.replacingOccurrences(of: #"(?i)\b(STAGE\s*\d|FASE\s*\d|BASE|POKEMON|POKÉMON|LV\.\d+|LIVELLO\s*\d+)\b"#, with: "", options: .regularExpression)
        str = str.replacingOccurrences(of: #"[^\w\s-]"#, with: "", options: .regularExpression)
        
        let words = str.split(separator: " ").filter { word in
            let w = String(word).trimmingCharacters(in: .whitespaces)
            return w.count >= 3 && !w.allSatisfy({ $0.isNumber })
        }
        
        if let firstWord = words.first {
            return String(firstWord)
        }
        return nil
    }
}
