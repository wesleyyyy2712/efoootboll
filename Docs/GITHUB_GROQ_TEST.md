# Teste real da Groq pelo GitHub Actions

O workflow manual `Groq Vision single-image test` usa o Secret `GROQ_API_KEY` configurado no repositório. A chave não é impressa, salva em arquivo ou incluída no relatório.

O workflow baixa uma imagem pública real de gameplay, chama uma única vez o modelo `qwen/qwen3.8-27b`, valida o JSON, registra jogadores, bola, espaços, recomendação e latência, e publica `groq-report.json` como artifact.

O `AVSpeechSynthesizer` não roda no runner Linux; o relatório registra essa limitação. O texto produzido é o texto que será encaminhado ao TTS no app iOS.
