# Relatório do probe isolado da integração Groq

**Execução:** https://github.com/wesleyyyy2712/efoootboll/actions/runs/36202983576  
**Modelo:** `qwen/qwen3.8-27b`  
**Secret:** presente no runner (`GROQ_API_KEY_PRESENT=true`), sem revelar o valor.  
**Imagem:** a mesma imagem pública real de gameplay usada no teste anterior, enviada nesta execução por URL HTTPS.  
**Pipeline do app:** não alterado; este foi um probe exclusivo da camada Groq.

## Verificações

A consulta `GET https://api.groq.com/openai/v1/models` retornou **HTTP 200**, 11 identificadores, e confirmou que `qwen/qwen3.8-27b` está listado para esta chave/projeto.

A única chamada multimodal do probe usou:

```text
POST https://api.groq.com/openai/v1/chat/completions
model: qwen/qwen3.8-27b
content: text + image_url HTTPS
response_format: {"type":"json_object"}
```

A chamada retornou **HTTP 200** em **854,50 ms**.

## JSON bruto recebido

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

## JSON validado

O JSON foi decodificado com sucesso. Os campos foram encontrados e os tipos básicos foram aceitos pelo probe.

## Interpretação

- Jogadores visíveis relatados: **8**.
- Bola: **visível**, segundo o modelo.
- Espaço livre: **visível**, sem localização estruturada neste probe mínimo.
- Contexto: `live_play`; esse valor é descritivo, mas não é um dos valores estritos do schema do app (`attack`, `defense`, `transition`, `unknown`). O adaptador do app deve normalizar valores desconhecidos para `unknown` ou ampliar o enum deliberadamente em uma alteração futura.
- Confiança informada: **0,95**.
- Recomendação textual: **“Use o botão 'Dash & Pressure' para recuperar a posse de bola e pressione o adversário.”**

Este resultado comprova que a integração HTTP e o suporte de imagem estão funcionando com este Secret, endpoint, modelo e formato de URL. Não comprova ainda a precisão de bounding boxes, posições X/Y, identidade dos jogadores ou espaços livres localizados, pois o prompt deste probe pediu contagens e flags, não coordenadas.

## Diagnóstico do 403/1010 anterior

O erro anterior foi **HTTP 403** com corpo `error code: 1010`. A documentação oficial da Groq define 403 como restrição de permissão. A documentação de permissões de modelos explica que bloqueios de organização/projeto também retornam 403, mas os códigos documentados para esses casos são `model_permission_blocked_org` e `model_permission_blocked_project`.

O probe atual confirmou três fatos: o Secret chega ao runner, o modelo está listado para esse Secret/projeto e uma chamada multimodal ao endpoint retorna 200. A combinação que funcionou incluiu `User-Agent` explícito e `image_url` HTTPS, enquanto a tentativa anterior usou data URL base64 e não tinha User-Agent explícito. Portanto, não é possível atribuir causalidade isolada a apenas uma dessas diferenças; o fato comprovado é que a integração agora retorna 200 com o formato documentado de URL.

## Fontes oficiais

- https://console.groq.com/docs/vision
- https://console.groq.com/docs/model/qwen/qwen3.8-27b
- https://console.groq.com/docs/model/qwen/qwen3.6-27b
- https://console.groq.com/docs/models
- https://console.groq.com/docs/errors
- https://console.groq.com/docs/model-permissions
- https://developers.cloudflare.com/support/troubleshooting/http-status-codes/cloudflare-1xxx-errors/error-1010/
