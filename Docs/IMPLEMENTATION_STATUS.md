# Estado objetivo da implementação

## Realmente implementado

A integração Groq agora está conectada por `GroqAnalysisPipeline`: recebe JPEG, aplica cooldown de requisições, chama `GroqVisionService`, valida o envelope HTTP e converte os schemas detalhado ou de resumo por `GroqResponseAdapter` para `FrameAnalysis`, usa `DecisionEngine`, aplica prioridade mínima/cooldown e despacha TTS. O JSON real do probe HTTP 200 é usado em teste automatizado offline.

O `DecisionCoordinator` registra timestamp, latência Groq, contagens e flags observadas, recomendação recebida, decisão, latência da decisão, latência de despacho da voz, resultado do acionamento de TTS e motivo de bloqueio. O cooldown também se aplica a recomendações de prioridade alta.

`ScreenCaptureKitAdapter` recebe `CMSampleBuffer`, extrai `CVPixelBuffer` e converte para JPEG com `PixelBufferEncoder`. A API de captura continua sendo um ponto que precisa do picker sistêmico para fornecer o `SCContentFilter`.

`VideoReplayService.run` extrai frames de um vídeo com `AVAssetImageGenerator`, chama o pipeline Groq de forma sequencial e aguarda cada análise. O relatório mede frames lidos/processados, latência média/máxima, FPS e erros.

O schema padronizado inclui bola, jogador controlado, companheiros, adversários, bounding boxes, espaços livres, contexto e recomendação tipada. `TemporalTracker` e `SpaceEstimator` fornecem a arquitetura de tracking, velocidade e estimativa de espaços sem inventar observações.

O painel `DebugOverlay` mostra bounding boxes quando fornecidas, marcadores, espaços, recomendação, latência e FPS.

## O que continua mock ou stub

`MockCaptureManager`, `MockFrameProcessor` e `MockAIService` permanecem para testes offline e demonstração do fluxo. A tela inicial ainda instancia `MockCaptureManager` e `AnalysisPipeline`; o novo pipeline Groq é disponibilizado por injeção e exercitado pelo teste com o JSON real, mas sua ativação pela UI não foi alterada nesta etapa. Os mocks não devem ser usados como prova de detecção real.

O detector local de jogadores/bola ainda é uma interface (`ObjectDetector`), porque não há um modelo treinado específico de eFootball no projeto. A detecção visual real do caminho atual é feita pelo provider multimodal Groq quando uma imagem é enviada. A qualidade dessa detecção não foi declarada como validada sem screenshot real.

O adapter ScreenCaptureKit contém a conversão real para JPEG, mas o acionamento do `SCContentSharingPicker` e a entrega do `SCContentFilter` precisam ser ligados no target de app iOS real.

## Modelo Groq

O provider usa por padrão `qwen/qwen3.8-27b`, que a documentação da Groq lista como multimodal e compatível com imagens e JSON mode. Fonte: https://console.groq.com/docs/vision

## Testar uma imagem

No Mac/Linux, com a chave fora do projeto:

```bash
export GROQ_API_KEY='sua-chave'
python3 Tools/groq_single_image_test.py gameplay.jpg
```

No app iOS, a chave é carregada do Keychain depois de ser digitada na primeira abertura. O teste da imagem deve validar se o JSON retornado tem o schema esperado e se as coordenadas estão no intervalo 0..1.

## Testar um vídeo

No Xcode, importe um arquivo de vídeo local e chame:

```swift
let service = VideoReplayService()
let report = try await service.run(url: videoURL, pipeline: pipeline, everyNthFrame: 15)
```

Use `everyNthFrame` alto no primeiro teste. A Groq não deve receber todos os frames. O cooldown do pipeline também impede chamadas muito próximas. O relatório deve ser salvo junto com a versão do app e o modelo usado.

## Arquivos principais modificados ou adicionados

- `Models/Domain.swift`: schema padronizado.
- `Services/GroqVisionService.swift`: chamada multimodal e JSON estruturado.
- `Engine/GroqPipeline.swift`: Groq → FrameAnalysis → decisão → recomendação → TTS.
- `Services/PixelBufferEncoder.swift`: CVPixelBuffer → JPEG.
- `Services/ScreenCaptureKitAdapter.swift`: captura → JPEG.
- `Services/ReplayService.swift`: vídeo → frames → pipeline.
- `Engine/VisionTracking.swift`: interfaces de detector, tracking e espaços.
- `UI/DebugOverlay.swift`: debug visual e métricas.
- `Tests/EFootballAssistantTests/GroqPipelineTests.swift`: testes offline do mapeamento.

## Dependências restantes

Ainda depende de Xcode/iPhone: compilar, configurar o picker do ScreenCaptureKit, validar permissões, testar captura do eFootball, medir bateria/temperatura e executar uma imagem/vídeo real. A precisão dos jogadores/bola depende da imagem e do modelo; não há um modelo local treinado de eFootball incluído.
