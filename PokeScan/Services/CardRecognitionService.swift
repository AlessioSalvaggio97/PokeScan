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
    @Published public var autoSaveCountdown: Double = 0.0
    @Published public var scanCountThisSession: Int = 0
    
    private let visionQueue = DispatchQueue(label: "com.pokescan.vision", qos: .userInitiated)
    private var isBusy = false
    private var lastProcessTime: TimeInterval = 0
    private var autoSaveTimer: AnyCancellable?
    
    private var lastDetectedKey: String?
    private var frameStabilityCount = 0
    
    private init() {}
    
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
        
        // 2. ERA MODERNA (Scarlatto & Violetto / MegaEvoluzioni):
        //    ISPEZIONE MIRATA DEL RIQUADRO IN BASSO A SINISTRA (x <= 0.48, y <= 0.40)
        var detectedSetId: String?
        var detectedLocalId: String?
        var detectedTotalCards: String?
        var candidateSetIds: [String] = []
        var detectedLanguage = "IT"
        
        let allJoined = sortedDesc.map { $0.text }.joined(separator: " ")
        if let langMatch = allJoined.range(of: #"\b(IT|EN)\b"#, options: .regularExpression) {
            detectedLanguage = String(allJoined[langMatch]).uppercased()
        }
        
        let bottomLeftElements = sortedDesc.filter { $0.x <= 0.48 && $0.y <= 0.40 }
        let bottomLeftJoined = bottomLeftElements.map { $0.text }.joined(separator: " ")
        
        // A1. Cerca codice tra parentesi nel riquadro in basso a sinistra (es. "[SVI]", "[SCR]", "[ME02.5]")
        let bracketPattern = #"\[\s*([A-Za-z0-9.]{2,7})\s*\]"#
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
        
        // A2. Cerca token alfanumerici corrispondenti a sigle note nel riquadro in basso a sinistra (es. "SVI", "ASC", "SCR", "SSP")
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
        
        // A3. Fallback: cerca codice tra parentesi in tutta la carta
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
        
        // 3. ESTRAZIONE CARTE PROMO & FRAZIONE NUMERO / TOTALE
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
        
        // Cerca frazione numerica (es: "123/217", "045/149", "TG05/TG30", "GG12/GG70")
        if detectedLocalId == nil {
            let fracPattern = #"(?i)\b([A-Za-z]{0,2}\d{1,3})\s*/\s*(\d{1,3}|[A-Za-z]{0,2}\d{1,3})\b"#
            if let regex = try? NSRegularExpression(pattern: fracPattern) {
                let ns = allJoined as NSString
                if let m = regex.firstMatch(in: allJoined, range: NSRange(location: 0, length: ns.length)) {
                    let num = ns.substring(with: m.range(at: 1))
                    let total = ns.substring(with: m.range(at: 2))
                    
                    detectedLocalId = num
                    detectedTotalCards = total
                    
                    // 4. ERA PRE-SCARLATTO & VIOLETTO (Spada & Scudo, Sole & Luna, XY, ecc.)
                    //    Se non abbiamo rilevato un codice set moderno in basso a sinistra:
                    if detectedSetId == nil {
                        let candidates = SetCatalog.shared.findSetsByDenominator(total)
                        candidateSetIds = candidates.map { $0.id }
                        
                        if candidates.count == 1 {
                            detectedSetId = candidates[0].id
                        } else if candidates.count > 1 {
                            // MATCHING VISIVO MIRATO SUI SIMBOLI DEI CANDIDATI
                            let rightRect = CGRect(x: 0.68, y: 0.02, width: 0.28, height: 0.18)
                            let leftRect = CGRect(x: 0.04, y: 0.02, width: 0.28, height: 0.18)
                            
                            var matchedCandidate: String? = nil
                            var bestDistance: Float = 0.88 // Soglia per accettare somiglianza
                            
                            // Test zona destra (tipica di Sole & Luna / XY)
                            if let rightCG = cropPixelBuffer(pixelBuffer, normalizedRect: rightRect),
                               let resRight = SetCatalog.shared.matchBestCandidateSymbol(from: rightCG, among: candidateSetIds),
                               resRight.distance < bestDistance {
                                matchedCandidate = resRight.bestSetId
                                bestDistance = resRight.distance
                            }
                            
                            // Test zona sinistra (tipica di Spada & Scudo)
                            if let leftCG = cropPixelBuffer(pixelBuffer, normalizedRect: leftRect),
                               let resLeft = SetCatalog.shared.matchBestCandidateSymbol(from: leftCG, among: candidateSetIds),
                               resLeft.distance < bestDistance {
                                matchedCandidate = resLeft.bestSetId
                                bestDistance = resLeft.distance
                            }
                            
                            if let matched = matchedCandidate {
                                detectedSetId = matched
                            }
                        }
                    }
                }
            }
        }
        
        guard let localId = detectedLocalId else { return }
        
        let cardKey = "\(detectedSetId ?? "unk")_\(localId)_\(detectedPokemonName ?? "any")"
        if let current = currentCard, "\(current.setId)_\(current.localId)_\(current.name)" == cardKey {
            return
        }
        
        if lastDetectedKey == cardKey {
            frameStabilityCount += 1
        } else {
            lastDetectedKey = cardKey
            frameStabilityCount = 1
            return
        }
        
        guard frameStabilityCount >= 2 else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.handleDetectedCard(
                pokemonName: detectedPokemonName,
                setId: detectedSetId,
                localId: localId,
                totalCards: detectedTotalCards,
                candidateSetIds: candidateSetIds,
                language: detectedLanguage
            )
        }
    }
    
    private func handleDetectedCard(
        pokemonName: String?,
        setId: String?,
        localId: String,
        totalCards: String?,
        candidateSetIds: [String] = [],
        language: String
    ) {
        commitCurrentCardIfPresent()
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let initialName = pokemonName?.capitalized ?? "Carta \(localId)"
        let initialSetId = setId ?? candidateSetIds.first ?? "sv01"
        let setInfo = SetCatalog.shared.sets[initialSetId]
        let setName = setInfo?.localizedName(language: language) ?? initialSetId.uppercased()
        let symbolData = SetCatalog.shared.getSymbolData(for: initialSetId)
        
        // Carta temporanea mostrata all'istante
        let tempCard = PokemonCard(
            name: initialName,
            localId: localId,
            setId: initialSetId,
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
        self.startAutoSaveTimer()
        
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
                if var active = self.currentCard, active.localId == localId {
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
        currentCard = nil
        stopAutoSaveTimer()
    }
    
    public func discardCurrentCard() {
        currentCard = nil
        stopAutoSaveTimer()
    }
    
    public func setVariant(_ variant: CardVariant) {
        guard var card = currentCard else { return }
        card.variant = variant
        currentCard = card
        
        let haptic = UISelectionFeedbackGenerator()
        haptic.selectionChanged()
    }
    
    private func startAutoSaveTimer() {
        stopAutoSaveTimer()
        autoSaveCountdown = 3.0
        
        autoSaveTimer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.autoSaveCountdown > 0.1 {
                    self.autoSaveCountdown -= 0.1
                } else {
                    self.commitCurrentCardIfPresent()
                }
            }
    }
    
    private func stopAutoSaveTimer() {
        autoSaveTimer?.cancel()
        autoSaveTimer = nil
        autoSaveCountdown = 0.0
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
