# eFootball Assistant — MVP modular iOS

Projeto-base em Swift/SwiftUI para validar o fluxo `captura/replay → frame → processamento → detecção → análise → decisão → recomendação → áudio`.

## Configuração da chave Groq dentro do app

Na primeira abertura, o aplicativo exibe uma tela segura para o usuário colar a chave da IA. A chave é salva somente no Keychain do iPhone com `ThisDeviceOnly` e nunca é inserida no código, no `Info.plist`, no ZIP, no GitHub ou em logs. O usuário pode alterar/remover a chave em Configurações.

Para um produto distribuído publicamente, o ideal é usar um proxy backend próprio, pois uma chave presente em um app cliente pode ser extraída. O Keychain protege o armazenamento local, mas não é um segredo absoluto contra engenharia reversa.

## O que foi implementado

O pacote contém modelos de estado, pipeline de frames, `MockAIService`, `RemoteAIService`, provider de visão `GroqVisionService`, replay de vídeo com métricas, motor de decisão/prioridade, TTS, diagnóstico, painel de debug, UI inicial, configuração de captura, Keychain e testes.

## Estado real

O código é um **MVP técnico para abrir no Xcode**. O fluxo mock pode ser validado sem hardware, mas captura real, compilação, assinatura e desempenho precisam de Mac/Xcode e iPhone. Nenhum resultado de detecção visual real é declarado sem uma imagem/vídeo de gameplay e teste controlado.

## Abrir no Xcode

1. No Mac, abra `Package.swift` no Xcode ou crie um app iOS SwiftUI e adicione os arquivos de `Sources/EFootballAssistant`.
2. Configure o deployment target e adicione `ScreenCaptureKit`.
3. Configure `UIBackgroundModes` com `screen-capture` quando suportado pelo target.
4. Adicione as descrições de privacidade necessárias.
5. Teste em iPhone real, porque o simulador não comprova captura do display inteiro nem desempenho térmico.

## Teste Groq de uma imagem

O script `Tools/groq_single_image_test.py` faz uma única chamada usando `GROQ_API_KEY` do ambiente. No app, a chave vem do Keychain. Consulte `Docs/GROQ_SINGLE_IMAGE_TEST.md` e `Docs/KEYCHAIN_SETUP.md`.
