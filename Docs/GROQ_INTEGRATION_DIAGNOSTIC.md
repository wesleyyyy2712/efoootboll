# Diagnóstico da integração Groq

A documentação oficial atual confirma:

- `qwen/qwen3.8-27b` é um identificador válido e listado como modelo preview na Groq.
- O modelo aceita **text, images**, Vision, JSON Object Mode e JSON Schema Mode.
- A documentação de Vision orienta usar `https://api.groq.com/openai/v1/chat/completions`.
- O conteúdo da mensagem é uma lista com um item `text` e um item `image_url`.
- Uma imagem local pode ser enviada como data URL `data:image/jpeg;base64,...` ou `data:image/png;base64,...`.
- Uma imagem por URL também é aceita; a documentação indica limite de 20 MB e até três imagens.
- A lista de modelos pode ser consultada em `https://api.groq.com/openai/v1/models`.

A página de modelos/vision atualmente identifica `qwen/qwen3.8-27b` como modelo multimodal disponível para Vision. Não há outro modelo de visão listado na página oficial de Vision consultada.

A documentação oficial de erros define HTTP 403 como restrição de permissão. A documentação de Model Permissions explica que um modelo bloqueado no nível da organização ou projeto retorna 403. O corpo observado no GitHub Actions foi `error code: 1010`, que não corresponde aos exemplos de `model_permission_blocked_org` ou `model_permission_blocked_project` documentados. Portanto, o probe também consulta `/models`, envia User-Agent explícito e registra o corpo do erro, sem registrar a chave.

O workflow verifica `GROQ_API_KEY` apenas com `test -n` e imprime `GROQ_API_KEY_PRESENT=true`; o valor nunca é impresso. Depois executa uma única requisição Vision usando a mesma imagem pública e grava apenas o relatório sanitizado como artifact.

Fontes:

- https://console.groq.com/docs/vision
- https://console.groq.com/docs/model/qwen/qwen3.8-27b
- https://console.groq.com/docs/models
- https://console.groq.com/docs/errors
- https://console.groq.com/docs/model-permissions
- https://developers.cloudflare.com/support/troubleshooting/http-status-codes/cloudflare-1xxx-errors/error-1010/
