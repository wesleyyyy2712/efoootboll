# Viabilidade e limites

O MVP é viável como app auxiliar, com captura de display autorizada pelo usuário. A implementação recomendada para versões atuais é ScreenCaptureKit no iOS 27+, com `SCContentSharingPicker`, `SCStream` e `UIBackgroundModes=screen-capture`.

O app não incorpora o eFootball, não deve modificar o jogo e não pode presumir um overlay livre sobre outro app. A orientação principal deve ser por áudio. O processamento recomendado é local: frames, tracking, contexto, prioridade e TTS. A IA remota deve receber apenas resumo estruturado e ter timeout/fallback.

A captura real e a assinatura exigem Mac/Xcode e um iPhone compatível. O pacote entregue contém `MockCaptureManager` e `MockFrameProcessor` para validar o fluxo sem fingir que a captura real já foi testada.

Referências oficiais:

- https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios
- https://developer.apple.com/documentation/screencapturekit
- https://developer.apple.com/documentation/xcode/configuring-background-execution-modes
- https://developer.apple.com/documentation/vision/tracking-multiple-objects-or-rectangles-in-video
- https://developer.apple.com/documentation/coreml
- https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer
- https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution
