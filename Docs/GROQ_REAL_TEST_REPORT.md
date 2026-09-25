# Relatório do teste real de visão Groq

**Execução:** GitHub Actions run 36202729109  
**URL:** https://github.com/wesleyyyy2712/efoootboll/actions/runs/36202729109  
**Imagem:** `gameplay.jpg`, baixada durante o workflow a partir de uma imagem pública real de gameplay do eFootball.  
**Modelo configurado:** `qwen/qwen3.8-27b`  
**Data:** 25 de setembro de 2026

## Resultado

O teste foi executado com o Secret `GROQ_API_KEY` do repositório. A requisição alcançou o endpoint da Groq, mas foi recusada antes de produzir uma resposta de modelo:

```text
HTTP 403
error code: 1010
```

A latência medida até a resposta de erro foi de **205,54 ms**.

## JSON bruto recebido

Não houve JSON de resposta do modelo. O corpo retornado pelo gateway foi:

```text
error code: 1010
```

## JSON validado

Não aplicável. Como a API não devolveu uma resposta de chat, nenhum JSON de visão pôde ser validado ou convertido para `FrameAnalysis`.

## Detecções

- Jogadores: **não identificados**, porque a inferência não foi executada.
- Bola: **não identificada**, porque a inferência não foi executada.
- Espaços: **não identificados**, porque a inferência não foi executada.
- Contexto: **não identificado**.
- Percentual de informações não identificadas: **100% por falha de transporte/autorização antes da inferência**. Isso não é uma medida de precisão visual do modelo.

## DecisionEngine e recomendação

Não foram executados. Sem `FrameAnalysis` válido não há base para uma recomendação responsável. Nenhuma recomendação deve ser considerada gerada neste teste.

## TTS

Não executado no runner Linux do GitHub Actions. O `AVSpeechSynthesizer` só deve ser validado dentro do app iOS. Como não houve recomendação, também não existia texto válido para enviar ao TTS.

## Verificação do modelo

A documentação oficial da Groq lista `qwen/qwen3.8-27b` como modelo multimodal, com entrada de imagens e JSON mode: https://console.groq.com/docs/vision

O modelo está configurado no workflow e foi enviado no campo `model`. Porém, esta execução não conseguiu confirmar a disponibilidade efetiva para este Secret/ambiente, porque o endpoint bloqueou a requisição com HTTP 403 antes da inferência.

## Limitação encontrada

O código `1010` veio do gateway com HTTP 403. Isso indica bloqueio de acesso no caminho usado pelo GitHub Actions, ou uma restrição de autorização/rede associada ao ambiente; não permite concluir que a visão do modelo falhou. Também não permite concluir que a chave está incorreta sem uma resposta específica da API.

O próximo teste deve ser feito a partir de um ambiente autorizado pela Groq, como uma máquina local/rede permitida, mantendo a chave somente em variável de ambiente. Depois que a chamada retornar JSON, o relatório poderá medir separadamente a qualidade da detecção de jogadores, bola e espaços.
