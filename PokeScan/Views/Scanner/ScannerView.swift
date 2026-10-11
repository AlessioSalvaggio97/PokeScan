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
            
            // Maschera scura cinematografica
            LinearGradient(
                colors: [
                    Color.black.opacity(0.65),
                    Color.clear,
                    Color.black.opacity(0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                // Header superiore con Dynamic Island Toast
                topBarView
                
                Spacer()
                
                // Mirino Ottico Laser Hi-Tech
                ScannerHUDView(
                    isTargetLocked: recognitionService.currentCard != nil,
                    isWaitingForNewCard: recognitionService.isWaitingForNewCard
                )
                
                Spacer()
                
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
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                } else if recognitionService.isWaitingForNewCard {
                    waitingForNewCardBanner
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
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
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                toastMessage = name
                showSaveToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeOut) {
                    showSaveToast = false
                }
            }
        }
    }
    
    // MARK: - Sotto-viste Top Bar & Dynamic Toast
    
    private var topBarView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Selettore Collezione Corrente Glassmorphic
                Button(action: {
                    showCollectionPicker = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(PokeTheme.neonYellow)
                        Text(dataManager.activeCollection?.name ?? "Seleziona Collezione")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .glassPanel(cornerRadius: 20, borderColor: PokeTheme.neonYellow)
                }
                
                Spacer()
                
                // Pulsante Torcia
                Button(action: {
                    cameraManager.toggleTorch()
                }) {
                    Image(systemName: cameraManager.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(cameraManager.isTorchOn ? PokeTheme.neonYellow : .white)
                        .padding(10)
                        .glassPanel(cornerRadius: 20, borderColor: cameraManager.isTorchOn ? PokeTheme.neonYellow : Color.white.opacity(0.2))
                }
                
                // Pulsante "Termina Scansione" con Neon Glow
                Button(action: {
                    recognitionService.commitCurrentCardIfPresent()
                    cameraManager.stopSession()
                    onFinishScanning?()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.circle.fill")
                        Text("Termina")
                            .font(.system(size: 14, weight: .black))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.95, green: 0.15, blue: 0.25), Color(red: 0.8, green: 0.05, blue: 0.15)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .neonGlow(color: PokeTheme.neonRed, radius: 8)
                }
            }
            .padding(.horizontal, 16)
            
            // Dynamic Toast (Notifica tipo Dynamic Island Apple)
            if showSaveToast {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(PokeTheme.neonYellow)
                    
                    Text("+1 Salvata:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(toastMessage)
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(PokeTheme.neonGreen)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassPanel(cornerRadius: 22, borderColor: PokeTheme.neonGreen)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.top, 10)
    }
    
    private var bottomStatusView: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "tray.full.fill")
                    .foregroundColor(PokeTheme.neonCyan)
                Text("\(dataManager.activeCollection?.totalCards ?? 0) carte")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassPanel(cornerRadius: 16, borderColor: PokeTheme.neonCyan)
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(PokeTheme.neonGreen)
                    .frame(width: 8, height: 8)
                    .neonGlow(color: PokeTheme.neonGreen, radius: 4)
                
                Text("BULK SCAN 60 FPS")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(PokeTheme.neonGreen)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassPanel(cornerRadius: 16, borderColor: PokeTheme.neonGreen)
        }
    }
    
    private var waitingForNewCardBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PokeTheme.neonGreen.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(PokeTheme.neonGreen)
                    .neonGlow(color: PokeTheme.neonGreen, radius: 8)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("CARTA ACQUISITA ✓")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.white)
                Text("Rimuovi la carta o inquadra la successiva...")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
            }
            
            Spacer()
            
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 20))
                .foregroundColor(PokeTheme.neonYellow)
                .neonGlow(color: PokeTheme.neonYellow, radius: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassPanel(cornerRadius: 18, borderColor: PokeTheme.neonGreen)
    }
}
