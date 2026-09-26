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

1. No Mac, abra `EFootballAssistant.xcodeproj`.
2. Selecione o target `EFootballAssistant` e escolha sua equipe Apple em **Signing & Capabilities**.
3. Troque `com.example.efootballassistant` por um Bundle ID disponível para sua conta.
4. Selecione seu iPhone como destino e deixe o Xcode gerar/usar o provisioning profile correspondente.
5. O projeto já inclui `Config/Info.plist` com `UIBackgroundModes=screen-capture` e `audio`, além da descrição de microfone.
6. O target mantém deployment target iOS 17; o caminho ScreenCaptureKit/picker exige iOS 27 ou superior e informa isso no app em versões anteriores.
7. Compile no Xcode. Para assinar externamente, use o Release archive/exportado pelo seu fluxo de assinatura.
8. Teste em iPhone real, porque o simulador não comprova captura do display inteiro nem desempenho térmico.

O GitHub Actions também executa um build sem assinatura do target iOS em `ios-app-build.yml`. A assinatura Apple não foi incluída no repositório.

## Teste Groq de uma imagem

O script `Tools/groq_single_image_test.py` faz uma única chamada usando `GROQ_API_KEY` do ambiente. No app, a chave vem do Keychain. Consulte `Docs/GROQ_SINGLE_IMAGE_TEST.md` e `Docs/KEYCHAIN_SETUP.md`.
