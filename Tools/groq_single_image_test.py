#!/usr/bin/env python3
"""Single-image Groq vision smoke test. Never pass or commit the API key in this file."""
import base64, json, os, sys, urllib.request

if len(sys.argv) != 2:
    raise SystemExit("Uso: GROQ_API_KEY=... python3 Tools/groq_single_image_test.py gameplay.jpg")
key = os.environ.get("GROQ_API_KEY")
if not key:
    raise SystemExit("Defina GROQ_API_KEY no ambiente; a chave não é lida de arquivo nem salva.")
path=sys.argv[1]
raw=open(path,"rb").read(); mime="image/png" if path.lower().endswith(".png") else "image/jpeg"
body={"model":"qwen/qwen3.8-27b","temperature":0,"max_completion_tokens":700,"response_format":{"type":"json_object"},"messages":[{"role":"user","content":[{"type":"text","text":"Analyze this eFootball gameplay screenshot. Return JSON with visible players normalized x/y, team user/opponent, confidence, isFree, ball x/y, context attack/defense/transition/unknown, overall confidence, and a short Portuguese recommendation. Do not invent objects not visible."},{"type":"image_url","image_url":{"url":f"data:{mime};base64,{base64.b64encode(raw).decode()}"}}]}]}
req=urllib.request.Request("https://api.groq.com/openai/v1/chat/completions",data=json.dumps(body).encode(),headers={"Authorization":f"Bearer {key}","Content-Type":"application/json"},method="POST")
with urllib.request.urlopen(req,timeout=30) as response: print(response.read().decode())
