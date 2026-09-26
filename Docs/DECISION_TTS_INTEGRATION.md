# Integração Groq → FrameAnalysis → DecisionEngine → TTS

## Fluxo integrado

A resposta JSON real registrada em `Tests/Fixtures/groq_real_response.json` é decodificada por `GroqResponseAdapter` e convertida para `VisionAIResult`/`FrameAnalysis`. O `GroqVisionService` usa esse mesmo adaptador na resposta efetiva da API; o `GroqAnalysisPipeline` constrói a análise com timestamp e encaminha-a ao `DecisionCoordinator`, que chama o `DecisionEngine`.

A fixture real contém contagem e flags visuais, mas não coordenadas. A conversão preserva oito jogadores, bola observada e um espaço observado sem inventar coordenadas ou entidades. O contexto bruto `live_play` permanece `.unknown`, pois não pertence aos casos existentes no enum; o escopo desta etapa não amplia o modelo.

Somente uma decisão válida produzida pelo `DecisionEngine`, com confiança aceita pelo próprio engine e prioridade mínima `.medium`, pode prosseguir. O `RecommendationEngine` aplica cooldown de 2,5 segundos à mesma frase independentemente da prioridade. `VoiceEngine.speak` informa se a fala foi despachada, e o pipeline registra latência de decisão e latência de despacho de voz.

## Diagnóstico

Cada decisão registra `timestamp`, `groq_latency_ms`, jogadores observados, flag da bola, quantidade de espaços, recebimento e texto da recomendação, decisão, `decision_ms`, `voice_dispatch_ms`, `tts_triggered` e motivo de bloqueio (`no_decision`, `priority`, `cooldown` ou `voice_disabled`).

## Teste automatizado

`RealGroqPipelineTests` lê a fixture do teste HTTP 200 e executa a mesma sequência de adaptação usada pelo serviço, seguida de `FrameAnalysis`, `DecisionEngine`, `DecisionCoordinator`, `RecommendationEngine`, `VoiceEngine` e `Diagnostics`. A fixture não dispara uma chamada de rede à Groq: o teste isola a integração dos componentes usando o JSON real armazenado. O callback de voz é apenas uma sonda para contar despachos; não substitui o engine de voz. O teste verifica conversão, decisão média, acionamento único, cooldown, diagnóstico e recusa de fala quando a confiança é insuficiente.

O relatório do probe registrou latência Groq de **854,50 ms**. No teste offline, o valor medido pelo probe é anexado ao diagnóstico; `decision_ms` e `voice_dispatch_ms` são medidos localmente. A confirmação de despacho ao `AVSpeechSynthesizer` é testável pelo callback e pelo código de produção, mas a audição física/saída de áudio precisa de um dispositivo e não foi medida pelo runner.

## Componentes e limites

Reais nesta integração: `GroqVisionService`, `GroqResponseAdapter`, modelos `VisionAIResult`/`FrameAnalysis`, `GroqAnalysisPipeline`, `DecisionEngine`, `DecisionCoordinator`, `RecommendationEngine`, `VoiceEngine` e `Diagnostics`.

Continuam disponíveis para demonstração/testes offline: `MockCaptureManager`, `MockFrameProcessor` e `MockAIService`. A interface ainda instancia `MockCaptureManager` e `AnalysisPipeline` na tela principal; esta etapa não mudou a captura nem o wiring da tela. `ScreenCaptureKitAdapter` continua sendo código real, mas seu picker/filtro e a ativação pela interface permanecem trabalho pendente fora deste escopo.

A chave continua fora do código: `GroqVisionService` recebe a configuração por injeção e o app existente armazena a chave no Keychain. Nenhum segredo foi adicionado ao projeto.
