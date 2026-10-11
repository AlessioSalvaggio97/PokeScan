import SwiftUI

public struct ScannerView: View {
    @StateObject private var cameraManager = CameraManager()
    @ObservedObject private var recognitionService = CardRecognitionService.shared
    @ObservedObject private var dataManager = DataManager.shared
    
    @State private var showCollectionPicker = false
    @State private var showSaveToast = false
    @State private var toastMessage = ""
    
    public var onFinishScanning: (() -> Void)?
    
    public var body: some View {
        ZStack {
            // Preview Telecamera a tutto schermo
            CameraPreviewView(captureSession: cameraManager.captureSession)
                .ignoresSafeArea()
            
            // Maschera scura con mirino di puntamento centrale
            VStack {
                // Header superiore
                topBarView
                
                Spacer()
                
                // Mirino ottico per centrare la carta
                cardReticleView
                
                Spacer()
                
                // Notifica toast a comparsa quando una carta viene salvata
                if showSaveToast {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(toastMessage)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.bottom, 8)
                }
                
                // Banner riepilogo carta inquadrata in basso
                if let card = recognitionService.currentCard {
                    ScannedCardBannerView(
                        card: card,
                        countdown: recognitionService.autoSaveCountdown,
                        onSelectVariant: { variant in
                            recognitionService.setVariant(variant)
                        },
                        onCommit: {
                            recognitionService.commitCurrentCardIfPresent()
                        },
                        onDiscard: {
                            recognitionService.discardCurrentCard()
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    // Barra inferiore di stato
                    bottomStatusView
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showCollectionPicker) {
            CollectionPickerModalView()
        }
        .onAppear {
            cameraManager.frameDelegate = recognitionService
            cameraManager.checkPermissionsAndSetup()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onReceive(recognitionService.$lastCommittedCardName) { name in
            guard let name = name else { return }
            withAnimation(.spring()) {
                toastMessage = "+1 Salvata: \(name)"
                showSaveToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    showSaveToast = false
                }
            }
        }
    }
    
    // MARK: - Sotto-viste
    
    private var topBarView: some View {
        HStack(spacing: 12) {
            // Selettore Collezione Corrente
            Button(action: {
                showCollectionPicker = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.yellow)
                    Text(dataManager.activeCollection?.name ?? "Seleziona Collezione")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.65))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            
            Spacer()
            
            // Torcia
            Button(action: {
                cameraManager.toggleTorch()
            }) {
                Image(systemName: cameraManager.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.system(size: 16))
                    .foregroundColor(cameraManager.isTorchOn ? .yellow : .white)
                    .padding(10)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Circle())
            }
            
            // Pulsante "Termina Scansione"
            Button(action: {
                recognitionService.commitCurrentCardIfPresent()
                cameraManager.stopSession()
                onFinishScanning?()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "stop.circle.fill")
                    Text("Termina")
                        .font(.system(size: 14, weight: .bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
    
    private var cardReticleView: some View {
        VStack(spacing: 12) {
            ZStack {
                // Riquadro guida proporzione carta Pokémon (63 x 88 mm ~ rapporto 1 : 1.4)
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        Color.white.opacity(0.35),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                    )
                    .frame(width: 250, height: 350)
                
                // Angolari evidenziati
                CornerBrackets(width: 250, height: 350)
                    .stroke(Color.yellow, lineWidth: 3)
                    .frame(width: 250, height: 350)
                
                // Indicatore mirino striscia inferiore
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "viewfinder")
                            .foregroundColor(.yellow.opacity(0.8))
                        Text("Sigla & Numero")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.yellow.opacity(0.9))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(6)
                    .padding(.bottom, 12)
                }
                .frame(width: 250, height: 350)
            }
            
            Text("Inquadra la carta nel mirino")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.5))
                .cornerRadius(12)
        }
    }
    
    private var bottomStatusView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("\(dataManager.activeCollection?.totalCards ?? 0) carte salvate")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(20)
            
            Spacer()
            
            Text("Bulk Mode Attivo")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.15))
                .cornerRadius(12)
        }
    }
}

// Angolari decorativi per il mirino
struct CornerBrackets: Shape {
    let width: CGFloat
    let height: CGFloat
    let length: CGFloat = 24
    
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Alto Sinistra
        p.move(to: CGPoint(x: 0, y: length))
        p.addLine(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: length, y: 0))
        
        // Alto Destra
        p.move(to: CGPoint(x: width - length, y: 0))
        p.addLine(to: CGPoint(x: width, y: 0))
        p.addLine(to: CGPoint(x: width, y: length))
        
        // Basso Sinistra
        p.move(to: CGPoint(x: 0, y: height - length))
        p.addLine(to: CGPoint(x: 0, y: height))
        p.addLine(to: CGPoint(x: length, y: height))
        
        // Basso Destra
        p.move(to: CGPoint(x: width - length, y: height))
        p.addLine(to: CGPoint(x: width, y: height))
        p.addLine(to: CGPoint(x: width, y: height - length))
        
        return p
    }
}
