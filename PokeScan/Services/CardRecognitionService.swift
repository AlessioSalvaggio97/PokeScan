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
    
    // Cache per evitare re-trigger continui sulla stessa carta identica
    private var lastDetectedKey: String?
    private var frameStabilityCount = 0
    
    private init() {}
    
    public func didCaptureFrame(_ sampleBuffer: CMSampleBuffer) {
        let now = Date().timeIntervalSince1970
        // Elabora massimo 4 frame al secondo (ogni 250ms) per efficienza energetica
        guard now - lastProcessTime > 0.25, !isBusy else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        lastProcessTime = now
        isBusy = true
        
        visionQueue.async { [weak self] in
            self?.processFrame(pixelBuffer)
        }
    }
    
    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        let request = VNRecognizeTextRequest { [weak self] req, error in
            defer { self?.isBusy = false }
            guard let self = self, error == nil,
                  let observations = req.results as? [VNRecognizedTextObservation] else {
                return
            }
            self.analyzeObservations(observations)
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false // Cruciale per non alterare codici come SVI o numeri
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
    }
    
    private func analyzeObservations(_ observations: [VNRecognizedTextObservation]) {
        var recognizedLines: [String] = []
        for obs in observations {
            if let topCandidate = obs.topCandidates(1).first {
                recognizedLines.append(topCandidate.string)
            }
        }
        
        guard !recognizedLines.isEmpty else { return }
        
        // Cerca pattern:
        // 1. Sigla set + numero (es: "SCR 045/142", "SVI 025/198", "PAL 001/193")
        // 2. Denominatore frazione (es: "045/149", "12/145" per Sole e Luna)
        var detectedSetId: String?
        var detectedLocalId: String?
        var detectedTotalCards: String?
        var detectedLanguage = "IT"
        
        let fullText = recognizedLines.joined(separator: " ")
        
        // Regex 1: Codice set e numero/totale (Scarlatto & Violetto, Spada & Scudo)
        // Esempi: "IT [SCR] 045/142", "EN SVI 025/198", "PAL 12/193"
        let patternModern = #"(?:(IT|EN)\s*)?(?:\[\s*)?([A-Za-z0-9.]{2,6})(?:\s*\])?\s*(\d{1,3})\s*/\s*(\d{1,3})"#
        if let regex = try? NSRegularExpression(pattern: patternModern, options: .caseInsensitive) {
            let nsText = fullText as NSString
            let matches = regex.matches(in: fullText, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                var lang: String?
                if match.range(at: 1).location != NSNotFound {
                    lang = nsText.substring(with: match.range(at: 1)).uppercased()
                }
                let code = nsText.substring(with: match.range(at: 2))
                let num = nsText.substring(with: match.range(at: 3))
                let total = nsText.substring(with: match.range(at: 4))
                
                if let setInfo = SetCatalog.shared.findSetByCode(code) {
                    detectedSetId = setInfo.id
                    detectedLocalId = num
                    detectedTotalCards = total
                    if let l = lang { detectedLanguage = l }
                    break
                }
            }
        }
        
        // Regex 2: Se non trovato set con sigla, cerca frazione numerica (Sole e Luna / XY / vintage)
        // Esempio: "45/149", "023/156"
        if detectedSetId == nil {
            let patternFraction = #"\b(\d{1,3})\s*/\s*(\d{1,3})\b"#
            if let regex = try? NSRegularExpression(pattern: patternFraction) {
                let nsText = fullText as NSString
                let matches = regex.matches(in: fullText, range: NSRange(location: 0, length: nsText.length))
                for match in matches {
                    let num = nsText.substring(with: match.range(at: 1))
                    let total = nsText.substring(with: match.range(at: 2))
                    
                    let candidates = SetCatalog.shared.findSetsByDenominator(total)
                    if let firstMatch = candidates.first {
                        detectedSetId = firstMatch.id
                        detectedLocalId = num
                        detectedTotalCards = total
                        break
                    }
                }
            }
        }
        
        guard let setId = detectedSetId, let localId = detectedLocalId else { return }
        
        let cardKey = "\(setId)_\(localId)"
        
        // Se la carta è la stessa già a schermo, non facciamo nulla
        if let current = currentCard, "\(current.setId)_\(current.localId)" == cardKey {
            return
        }
        
        // Verifichiamo stabilità per evitare falsi positivi
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
                setId: setId,
                localId: localId,
                totalCards: detectedTotalCards,
                language: detectedLanguage
            )
        }
    }
    
    private func handleDetectedCard(setId: String, localId: String, totalCards: String?, language: String) {
        // Se c'era già una carta nel banner, la salviamo AUTOMATICAMENTE prima di passare alla nuova!
        commitCurrentCardIfPresent()
        
        // Feedback aptico leggero
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let setInfo = SetCatalog.shared.sets[setId]
        let setName = setInfo?.localizedName(language: language) ?? setId.uppercased()
        let symbolData = SetCatalog.shared.getSymbolData(for: setId)
        
        // Crea una carta temporanea per mostrare il banner all'istante
        let newCard = PokemonCard(
            name: "Carta \(localId)",
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
        
        self.currentCard = newCard
        self.startAutoSaveTimer()
        
        // Arricchisce i dati in background con TCGdex (nome ufficiale, rarità, miniatura)
        Task {
            let details = await TCGdexService.shared.fetchCard(
                setId: setId,
                localId: localId,
                language: language
            )
            
            await MainActor.run {
                if var active = self.currentCard, active.setId == setId, active.localId == localId {
                    active.name = details.name
                    active.rarity = details.rarity
                    active.imageURL = details.imageURL
                    if let thumb = details.thumbnailData {
                        active.thumbnailData = thumb
                    }
                    self.currentCard = active
                }
            }
        }
    }
    
    /// Salva la carta corrente nella collezione attiva
    public func commitCurrentCardIfPresent() {
        guard let card = currentCard else { return }
        DataManager.shared.addCardToActiveCollection(card)
        lastCommittedCardName = "\(card.name) (\(card.formattedNumber))"
        scanCountThisSession += 1
        currentCard = nil
        stopAutoSaveTimer()
    }
    
    /// Scarta la carta senza salvarla
    public func discardCurrentCard() {
        currentCard = nil
        stopAutoSaveTimer()
    }
    
    /// Aggiorna la variante (Regular, Reverse, Foil) della carta corrente
    public func setVariant(_ variant: CardVariant) {
        guard var card = currentCard else { return }
        card.variant = variant
        currentCard = card
        
        let haptic = UISelectionFeedbackGenerator()
        haptic.selectionChanged()
    }
    
    private func startAutoSaveTimer() {
        stopAutoSaveTimer()
        autoSaveCountdown = 3.0 // 3 secondi prima del salvataggio automatico se fermi
        
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
}
