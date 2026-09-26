#if os(iOS)
import SwiftUI

@MainActor public final class AppViewModel: ObservableObject {
    @Published public var active = false
    @Published public var status = "Parado"
    @Published public var latency = "--"
    @Published public var recommendations = 0
    @Published public var capturedFrames = 0
    @Published public var sentFrames = 0
    @Published public var analysisState = "AGUARDANDO CAPTURA"
    @Published public var settings = AppSettings()
    @Published public var apiKey = ""
    @Published public var showingKeyPrompt = false

    private var pipeline: GroqAnalysisPipeline?
    private var capture: CaptureManager?
    private let keychain = KeychainStore.shared

    public init() {
        apiKey = keychain.readGroqKey() ?? ""
        showingKeyPrompt = apiKey.isEmpty
    }

    public func saveKey() {
        let clean = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if keychain.saveGroqKey(clean) {
            apiKey = clean
            showingKeyPrompt = false
        }
    }

    public func removeKey() {
        _ = keychain.deleteGroqKey()
        apiKey = ""
        showingKeyPrompt = true
    }

    public func toggle() {
        Task { @MainActor in
            if active {
                await capture?.stop()
                active = false
                status = "Parado"
                return
            }

            guard #available(iOS 27.0, *) else {
                status = "Captura real exige iOS 27 ou superior"
                return
            }
            guard let key = keychain.readGroqKey(), !key.isEmpty else {
                showingKeyPrompt = true
                return
            }

            let diagnostics = Diagnostics()
            let realPipeline = GroqAnalysisPipeline(
                vision: GroqVisionService(configuration: .init(apiKey: key)),
                diagnostics: diagnostics,
                minRequestInterval: 1.0
            )
            let realCapture = ScreenCaptureKitAdapter { data, timestamp in
                Task {
                    await realPipeline.ingest(imageData: data, timestamp: timestamp)
                    let metrics = await realPipeline.metrics
                    let captured = await realPipeline.capturedFrames
                    let sent = await realPipeline.sentFrames
                    let state = await realPipeline.state
                    let recommendation = await realPipeline.latestRecommendation
                    await MainActor.run {
                        self.capturedFrames = captured
                        self.sentFrames = sent
                        self.analysisState = state.state.rawValue
                        self.latency = String(format: "%.0f ms", metrics.totalMs)
                        if recommendation != nil { self.recommendations += 1 }
                    }
                }
            }

            pipeline = realPipeline
            capture = realCapture
            do {
                try await realCapture.start()
                await realPipeline.initializeSession()
                active = true
                analysisState = "SYSTEM_INITIALIZED"
                status = "Captura iniciada — aguardando frames"
            } catch {
                status = "Captura não iniciada: \(error.localizedDescription)"
                pipeline = nil
                capture = nil
                analysisState = "CAPTURA NÃO INICIADA"
            }
        }
    }
}

public struct ContentView: View {
    @StateObject private var vm = AppViewModel()
    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("STATUS") {
                    Label(vm.active ? "Sistema ativo" : "Sistema parado", systemImage: vm.active ? "checkmark.circle.fill" : "stop.circle")
                        .foregroundStyle(vm.active ? .green : .secondary)
                    Label(vm.status, systemImage: "rectangle.dashed.and.paperclip")
                    Label(vm.analysisState, systemImage: "waveform.path.ecg")
                    Label("IA \(vm.active ? "analisando" : "em espera")", systemImage: "brain.head.profile")
                    HStack { Text("LATÊNCIA"); Spacer(); Text(vm.latency) }
                    HStack { Text("FRAMES CAPTURADOS"); Spacer(); Text("\(vm.capturedFrames)") }
                    HStack { Text("FRAMES ENVIADOS"); Spacer(); Text("\(vm.sentFrames)") }
                    HStack { Text("ORIENTAÇÕES"); Spacer(); Text("\(vm.recommendations)") }
                }
                Section {
                    Button(vm.active ? "PARAR ANÁLISE" : "INICIAR ANÁLISE", action: vm.toggle)
                        .buttonStyle(.borderedProminent)
                }
                Section("CONFIGURAÇÕES") {
                    Toggle("Voz", isOn: $vm.settings.voiceEnabled)
                    Picker("Frequência", selection: $vm.settings.frequency) {
                        Text("Baixa").tag("low")
                        Text("Balanceada").tag("balanced")
                        Text("Alta").tag("high")
                    }
                    Toggle("Modo econômico", isOn: $vm.settings.economyMode)
                    Button("Alterar chave da IA") { vm.showingKeyPrompt = true }
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("eFootball Assistant")
            .sheet(isPresented: $vm.showingKeyPrompt) { APIKeyPrompt(vm: vm) }
        }
    }
}

private struct APIKeyPrompt: View {
    @ObservedObject var vm: AppViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Chave da IA") {
                    SecureField("Cole sua chave Groq", text: $vm.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("A chave será guardada somente no Keychain deste iPhone. Ela não será incluída no código nem enviada ao projeto.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("Salvar chave", action: vm.saveKey)
                        .disabled(vm.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Configurar IA")
            .interactiveDismissDisabled(vm.apiKey.isEmpty)
        }
    }
}
#endif
