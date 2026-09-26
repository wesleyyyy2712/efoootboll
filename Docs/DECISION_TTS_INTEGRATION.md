# Integração Groq → FrameAnalysis → DecisionEngine → TTS

## Implementado

O JSON real obtido no teste HTTP 200 foi incorporado como fixture de teste. `GroqResponseAdapter` decodifica o JSON, converte `game_context` para `GameContext`, preserva a contagem real de jogadores, a flag real da bola e a flag real de espaço livre, e não inventa coordenadas quando o JSON não as fornece.

`DecisionCoordinator` recebe `FrameAnalysis`, chama `DecisionEngine`, usa a recomendação recebida apenas como fallback estruturado, filtra pela prioridade mínima `medium`, aplica `RecommendationEngine` para cooldown e chama `VoiceEngine` somente quando a recomendação é aceita.

O diagnóstico registra timestamp, latência Groq, quantidade observada de jogadores, bola observada, espaços observados, decisão, motivo de bloqueio por prioridade/cooldown e `tts_triggered`.

O `GroqAnalysisPipeline` existente agora usa o `DecisionCoordinator`. O sistema de captura não foi alterado nesta etapa.

## Resultado do teste automatizado

O fixture reproduz o JSON real:

```json
{
  "visible_players_count": 8,
  "ball_visible": true,
  "free_space_visible": true,
  "game_context": "live_play",
  "confidence": 0.95,
  "recommendation": "Use o botão 'Dash & Pressure' para recuperar a posse de bola e pressione o adversário."
}
```

O teste verifica:

- JSON → `GroqRealVisionResponse`;
- resposta → `FrameAnalysis`;
- contagem observada igual a 8;
- bola observada igual a `true`;
- espaço observado igual a 1;
- recomendação com prioridade média;
- `DecisionEngine` produz a decisão;
- `VoiceEngine` é acionado uma vez;
- diagnóstico contém `players=8`, `ball_detected=true` e `tts_triggered=true`;
- segunda recomendação igual é bloqueada pelo cooldown.

A latência Groq usada no teste é a medida real do probe: **854,50 ms**. A decisão e o acionamento do VoiceEngine são medidos localmente pelo teste; o TTS real de áudio depende do AVSpeechSynthesizer no iOS. O teste injeta apenas um observador para confirmar o acionamento, sem substituir o VoiceEngine de produção.

## Componentes reais e mocks

Reais nesta integração: `GroqResponseAdapter`, `FrameAnalysis`, `DecisionEngine`, `DecisionCoordinator`, `RecommendationEngine`, `VoiceEngine` e `Diagnostics`.

Continuam disponíveis somente para testes offline ou fallback: `MockCaptureManager`, `MockFrameProcessor` e `MockAIService`. Eles não são usados pelo teste do JSON real desta etapa.

Não foram alterados: captura real, `ScreenCaptureKitAdapter`, arquitetura de captura e formato do provider Groq.
