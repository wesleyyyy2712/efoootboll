# Teste Groq — imagem única e replay controlado

A documentação atual da Groq lista `qwen/qwen3.8-27b` como modelo multimodal, com entrada de texto e imagem, JSON mode e limite de 20 MB para imagem por URL/data URL. Fonte: https://console.groq.com/docs/vision

O projeto contém `Tools/groq_single_image_test.py`. Ele lê somente `GROQ_API_KEY` do ambiente, nunca grava a chave e faz uma única requisição para uma imagem local.

```bash
export GROQ_API_KEY='sua-chave-fora-do-repositorio'
python3 Tools/groq_single_image_test.py gameplay.jpg
```

No iOS, `GroqVisionService` devolve `VisionAIResult`, que é decodificado por `Codable`; `GroqAnalysisPipeline` converte o resultado para `FrameAnalysis`, aplica regras de decisão, prioridade, cooldown e TTS. `VideoReplayService.run` repete esse fluxo para frames amostrados de um vídeo.

Sem uma imagem ou vídeo real, não é possível confirmar a precisão visual. Também não se deve usar o provider para vídeo contínuo antes de medir latência, limites, custo e privacidade.
