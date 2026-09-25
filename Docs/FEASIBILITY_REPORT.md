# Viabilidade técnica — MVP de análise de eFootball no iPhone

**Data da análise:** 25 de setembro de 2026  
**Escopo:** validar o fluxo `captura autorizada pelo iOS → processamento → visão computacional → decisão → orientação`, antes de construir uma interface extensa.

## Veredito

O MVP é **tecnicamente viável como um app auxiliar**, desde que seja desenhado como uma captura de tela iniciada e autorizada pelo usuário, sem incorporar o eFootball, sem modificar o jogo e sem depender de um overlay arbitrário por cima de outro app.

Para uma implementação alinhada às APIs atuais, o caminho principal deve ser **ScreenCaptureKit no iOS 27 ou posterior**, usando o seletor sistêmico de compartilhamento de conteúdo e o modo de execução em segundo plano `screen-capture`. A amostra oficial da Apple mostra captura de tela inteira, streaming de frames e continuidade quando o app deixa de estar em primeiro plano. [1] [2]

O primeiro protótipo deve provar apenas quatro pontos em um iPhone real:

1. o usuário consegue iniciar a captura da tela inteira;
2. o app continua recebendo frames enquanto o eFootball está em primeiro plano;
3. um detector/tracker identifica posições relevantes com estabilidade;
4. o app produz uma orientação curta por áudio sem interromper o fluxo da partida.

Isso ainda precisa ser testado em aparelho e versão de iOS compatíveis. A documentação não autoriza declarar o fluxo como funcional sem esse teste.

## Respostas às dez perguntas da primeira fase

### 1. Qual tecnologia de captura será utilizada?

**Tecnologia recomendada:** `ScreenCaptureKit`, com `SCContentSharingPicker` para o consentimento e a seleção de captura, `SCContentFilter` para representar o conteúdo escolhido e `SCStream` para receber os frames.

A amostra oficial para iOS 27 descreve dois modos: captura do display inteiro e captura do conteúdo do próprio app. Para este projeto, interessa o modo de **display inteiro**, pois o eFootball é um app separado. Os frames chegam pelo output do stream com tipo `.screen`. [1]

A alternativa histórica é ReplayKit com Broadcast Upload Extension. Ela entrega `CMSampleBuffer` a um `RPBroadcastSampleHandler`, mas a página atual da Apple marca essas APIs como **deprecated / no longer supported** nas versões documentadas. Portanto, ReplayKit deve ser tratado apenas como fallback de compatibilidade a ser validado, não como base do projeto novo. [3]

### 2. É possível receber a captura enquanto o eFootball está sendo executado?

**Em princípio, sim, com as condições do sistema:** o usuário deve iniciar e autorizar a captura pelo seletor oficial, escolher a captura do display inteiro e o app deve declarar o modo de fundo adequado. A amostra da Apple foi feita precisamente para streaming de tela no iOS e informa que o stream de captura de display inteiro continua quando o app deixa de estar em primeiro plano. [1]

O fluxo não será “eFootball dentro do aplicativo”. Será:

```text
Usuário inicia o app auxiliar
        ↓
Seletor sistêmico de compartilhamento
        ↓
Usuário autoriza captura do display inteiro
        ↓
Usuário volta ao eFootball
        ↓
ScreenCaptureKit entrega frames ao pipeline do app
```

A capacidade não deve ser presumida para qualquer versão do iOS ou dispositivo. O protótipo deve registrar versão do sistema, modelo do iPhone, orientação, taxa efetiva de frames e erros de interrupção.

### 3. Quais limitações existem para processamento em segundo plano?

Um app iOS comum tende a ser suspenso quando fica em segundo plano. A Apple oferece modos limitados e específicos; eles não constituem uma autorização geral para manter qualquer processamento contínuo. [4]

Para o caminho atual, a amostra do ScreenCaptureKit declara `screen-capture` em `UIBackgroundModes` para o stream sobreviver ao app deixar de estar em primeiro plano. Ela também declara `audio` quando precisa manter o tap de microfone ativo. [1] [4]

As limitações práticas são importantes:

- o usuário precisa iniciar a captura de forma explícita;
- a captura pode ser interrompida por ações do sistema, encerramento do broadcast/stream, bloqueio, troca de rota de áudio, pressão de memória ou outras condições do aparelho;
- o processamento não pode bloquear a entrega serial dos frames;
- rede, bateria, aquecimento e memória podem reduzir a taxa de análise;
- o app não deve depender de tarefas genéricas de background para fazer visão contínua; o modo declarado precisa corresponder à função real;
- a aprovação e a distribuição devem ser testadas com a configuração de capacidades e privacidade correta.

### 4. É possível manter a análise durante a partida?

**É plausível e é o objetivo do MVP, mas depende de validação no dispositivo.** A análise deve ocorrer dentro do processo/fluxo autorizado de captura enquanto a sessão estiver ativa. Não se deve prometer disponibilidade ininterrupta por toda a partida.

O design deve tolerar perda de frames e reinicialização:

- fila limitada, sem acumular frames antigos;
- descarte de frames quando o processamento estiver atrasado;
- estado de tracking que expira quando a confiança cai;
- re-detecção periódica;
- watchdog de captura e de inferência;
- orientação somente quando houver evidência suficiente;
- diagnóstico de início, pausa, retomada e término do stream.

### 5. Como o áudio poderá ser reproduzido?

A saída recomendada é **Text-to-Speech local** com `AVSpeechSynthesizer`, usando frases curtas e uma fila de baixa capacidade. A API converte utterances em fala, permite selecionar a voz e permite pausar, continuar e interromper a fila. [5]

A camada `VoiceEngine` deve controlar `AVAudioSession`, volume lógico, idioma, velocidade e política de interrupções. A fala deve ser curta — por exemplo, “direita”, “livre no meio”, “volta” — e deve cancelar uma recomendação velha quando uma nova de prioridade alta surgir.

O modo de saída mais confiável para o jogador é áudio local em fones. Não é seguro assumir que o som do jogo e a fala terão sempre o mesmo comportamento em todas as rotas, fones e configurações do usuário. Isso deve ser parte do teste do MVP.

### 6. Qual parte será processada localmente?

O caminho de baixa latência deve processar localmente:

- conversão/normalização dos frames;
- redução de resolução e seleção de frames;
- detecção inicial do campo, jogadores, bola e regiões relevantes;
- tracking entre frames;
- cálculo de distâncias, direção, pressão e espaço livre;
- filtragem temporal e confiança;
- motor de contexto e prioridade;
- deduplicação e cooldown das orientações;
- Text-to-Speech.

Vision oferece APIs para rastrear objetos ao longo de sequências de frames. A documentação recomenda executar o processamento fora da fila principal e atualizar periodicamente as detecções para recuperar objetos que surgiram ou foram perdidos. [6]

Core ML é apropriado para um detector específico do jogo, pois executa modelos no dispositivo usando CPU, GPU e Neural Engine, reduzindo dependência de rede e ajudando a responsividade e privacidade. [7]

### 7. Qual parte será enviada para a IA?

A primeira versão não deve enviar cada frame bruto para uma IA remota. Deve enviar, quando realmente necessário, um **resumo estruturado e pequeno** produzido localmente:

```json
{
  "timestamp": 0,
  "controlled_player": {"x": 0.52, "y": 0.61, "confidence": 0.91},
  "teammates": [{"x": 0.70, "y": 0.40, "distance": 0.24, "open": true}],
  "opponents": [{"x": 0.59, "y": 0.55, "distance": 0.12}],
  "ball": {"x": 0.56, "y": 0.59, "vx": 0.02, "vy": -0.01},
  "free_spaces": [{"x": 0.76, "y": 0.38, "score": 0.82}],
  "context": "attack",
  "confidence": 0.84
}
```

A IA externa pode então classificar a situação e escolher uma recomendação entre um vocabulário fechado. O aplicativo deve impor schema, timeout, limite de requisições, fallback e validação. A orientação falada nunca deve depender de texto livre sem filtragem.

Para o MVP, recomendo três modos intercambiáveis:

1. `MockAIService`: regras locais e respostas determinísticas;
2. `LocalAIService`: modelo Core ML para detecção/classificação;
3. `RemoteAIService`: apenas o resumo estruturado, não o vídeo contínuo, salvo evidência de que a latência e a privacidade são aceitáveis.

### 8. Qual será a latência estimada?

A Apple não fornece uma latência garantida para este caso. Os números abaixo são **metas de engenharia**, não resultados medidos:

- captura e enfileiramento: aproximadamente 10–80 ms;
- pré-processamento e tracking local: aproximadamente 10–80 ms;
- decisão local: aproximadamente 1–20 ms;
- chamada remota, se usada: aproximadamente 100–600+ ms, dependendo de rede e servidor;
- TTS: normalmente começa depois que a decisão é aceita, mas o tempo audível depende da rota e da fila de fala.

Assim, a meta inicial deve ser **100–250 ms até uma decisão local**, e **250–800+ ms com IA remota**. A arquitetura deve continuar útil sem rede, usando regras/MockAIService. O diagnóstico precisa medir separadamente captura, visão, decisão, rede e áudio; não exibir um único “XX ms” sem definir o que ele representa.

### 9. Qual arquitetura Swift/iOS deverá ser utilizada?

Recomendo Swift 6 com SwiftUI para a UI e concorrência estruturada para o pipeline. A captura deve ficar isolada atrás de protocolo para permitir teste com vídeo e imagens:

```text
App
├── UI
├── CaptureManager
│   └── ScreenCaptureKitAdapter
├── FrameProcessor
├── VisionEngine
├── PlayerTracker
├── BallTracker
├── GameStateAnalyzer
├── DecisionEngine
├── AIService
│   ├── MockAIService
│   ├── LocalAIService
│   └── RemoteAIService
├── RecommendationEngine
├── VoiceEngine
├── Settings
└── Diagnostics
```

Fluxo recomendado:

```text
SCStream
  → bounded frame buffer
  → resize / crop / frame sampling
  → detector + Vision/Core ML
  → temporal tracker
  → GameState
  → DecisionEngine
  → RecommendationEngine
  → VoiceEngine
```

A fila deve ser limitada e orientada ao frame mais recente. A UI não deve receber todos os frames. `GameState` deve conter timestamp, confiança e origem de cada observação para permitir replay e diagnóstico.

O modo de teste deve aceitar gravação ou sequência de imagens. O mesmo `FrameProcessor` usado no modo ao vivo deve consumir o arquivo de teste, evitando uma segunda implementação que produza resultados irreais.

### 10. Quais partes precisam de Mac/Xcode para compilação e assinatura?

É necessário um ambiente Apple com Xcode para criar, compilar e executar o app iOS em aparelho real, configurar entitlements/capabilities, assinar os targets e testar as APIs do sistema. A distribuição via TestFlight/App Store exige um registro do app, bundle ID, equipe de desenvolvimento e ativos de assinatura configurados no Xcode/Apple Developer. [8]

O projeto pode ser escrito e versionado fora do Mac, mas isso não substitui o ciclo de validação em Xcode e iPhone. Será necessário, no mínimo:

- projeto Xcode com target principal;
- target e configuração do ScreenCaptureKit;
- `UIBackgroundModes` correto, incluindo `screen-capture` quando aplicável;
- descrições de privacidade exigidas pelas APIs usadas;
- conta/equipe Apple para assinatura em aparelho e distribuição;
- aparelho físico compatível para validar captura de display inteiro e áudio;
- TestFlight para testes externos antes de qualquer declaração de produção.

## O que o MVP deve e não deve fazer

### Deve fazer

- iniciar captura com o seletor oficial;
- mostrar claramente quando a captura está ativa;
- processar um vídeo gravado como modo de teste;
- detectar um conjunto inicial controlado de elementos, não “entender todo o jogo” de imediato;
- gerar recomendações de um vocabulário fechado;
- tocar áudio curto com cooldown e prioridade;
- registrar latência, confiança, perda de frames e interrupções;
- operar com MockAIService quando a IA externa não estiver configurada.

### Não deve prometer

- captura sem consentimento do sistema;
- execução dentro do eFootball;
- overlay livre sobre outro app;
- análise contínua garantida em todos os modelos e versões do iOS;
- reconhecimento perfeito de todos os jogadores, bola, tática e contexto;
- latência fixa de rede;
- integração remota funcional antes de testar endpoint, autenticação, timeout e carga;
- uso de ReplayKit deprecated como solução de produção sem validação específica.

## Plano de implementação recomendado

### Etapa 0 — matriz de compatibilidade

Fixar a versão mínima de iOS e a lista de dispositivos. Como a amostra atual de captura de display inteiro da Apple exige iOS 27, decidir conscientemente se o MVP terá iOS 27+ ou uma rota de compatibilidade separada. [1]

### Etapa 1 — prova de captura

Criar um app mínimo sem IA: abrir seletor, selecionar display inteiro, receber frames, medir orientação/tamanho/taxa e salvar uma pequena amostra local. Testar com o eFootball em primeiro plano e documentar qualquer interrupção.

### Etapa 2 — replay determinístico

Alimentar o mesmo pipeline com vídeo ou imagens. Criar fixtures com cenas simples: ataque, jogador livre, pressão, passe lateral e perda de tracking.

### Etapa 3 — visão local

Implementar primeiro detecção/tracking simples e regras de confiança. O campo e as posições devem ser normalizados em coordenadas relativas. Reexecutar detecção periodicamente; usar tracking entre detecções para reduzir custo. [6]

### Etapa 4 — decisão e orientação

Adicionar `GameStateAnalyzer`, prioridades, cooldown e `MockAIService`. Só gerar voz para eventos que mudaram materialmente e passaram o limiar de confiança.

### Etapa 5 — áudio em partida real

Integrar `AVSpeechSynthesizer` e testar com alto-falante, fones Bluetooth e fones com fio, incluindo interrupções e volume do jogo. [5]

### Etapa 6 — IA externa opcional

Substituir o mock por `RemoteAIService` somente depois que o replay local for estável. Enviar dados mínimos, validar resposta por schema e manter fallback local quando houver timeout ou erro.

### Etapa 7 — UI e diagnóstico

Somente após a prova acima, construir a tela de status, configurações, diagnóstico, qualidade, modo econômico e contadores. A tela não deve mascarar falhas do pipeline.

## Riscos que precisam de teste explícito

- diferenças de captura entre versões do iOS 27 e modelos de iPhone;
- impacto térmico e de bateria após partidas longas;
- taxa real de frames entregue em resolução útil;
- perda de objetos por efeitos visuais, replay, menus e transições;
- áudio do jogo competindo com a orientação;
- interrupções por chamadas, gravação do sistema, bloqueio e troca de rota;
- políticas de distribuição e revisão aplicáveis a uma ferramenta que captura a tela de outro app;
- privacidade: imagens de gameplay e telemetria devem permanecer locais por padrão e ter consentimento claro para qualquer envio remoto.

## Conclusão

O caminho correto é construir primeiro um **protótipo técnico de captura de display inteiro + replay de vídeo + análise local + TTS**, não uma interface grande. Com ScreenCaptureKit e o modo `screen-capture` disponível no iOS 27, há uma rota oficial para testar o cenário em que o eFootball está em primeiro plano e o app auxiliar continua processando a captura autorizada. [1] [2] [4]

A viabilidade final depende de um teste em iPhone real. Se esse teste falhar por versão, dispositivo, interrupção ou desempenho, a alternativa segura é ajustar o alvo de iOS/dispositivo ou mudar o produto para um modo de análise de gravações/segundo dispositivo — não declarar que uma captura não validada funciona.

## Referências

[1]: https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios "Capturing screen content on iOS"

[2]: https://developer.apple.com/documentation/screencapturekit "ScreenCaptureKit"

[3]: https://developer.apple.com/documentation/replaykit/rpbroadcastsamplehandler "RPBroadcastSampleHandler"

[4]: https://developer.apple.com/documentation/xcode/configuring-background-execution-modes "Configuring background execution modes"

[5]: https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer "AVSpeechSynthesizer"

[6]: https://developer.apple.com/documentation/vision/tracking-multiple-objects-or-rectangles-in-video "Tracking Multiple Objects or Rectangles in Video"

[7]: https://developer.apple.com/documentation/coreml "Core ML"

[8]: https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution "Preparing your app for distribution"
