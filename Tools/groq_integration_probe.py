#!/usr/bin/env python3
import json, os, sys, time, urllib.error, urllib.request

MODEL=os.environ.get("GROQ_MODEL","qwen/qwen3.8-27b")
IMAGE_URL=os.environ.get("GROQ_TEST_IMAGE_URL")
KEY=os.environ.get("GROQ_API_KEY")
if not KEY or not IMAGE_URL: raise SystemExit("GROQ_API_KEY ou GROQ_TEST_IMAGE_URL ausente")
HEADERS={"Authorization":f"Bearer {KEY}","Content-Type":"application/json","User-Agent":"efoootboll-groq-integration-probe/1.0"}
report={"model_configured":MODEL,"secret_present":bool(KEY),"models_endpoint":None,"vision_test":None}
def get_models():
 req=urllib.request.Request("https://api.groq.com/openai/v1/models",headers={"Authorization":f"Bearer {KEY}","User-Agent":HEADERS["User-Agent"]})
 try:
  with urllib.request.urlopen(req,timeout=30) as r: data=json.loads(r.read().decode()); ids=[x.get("id") for x in data.get("data",[])]; return {"http_status":r.status,"model_id_list_returned":len(ids),"configured_model_listed":MODEL in ids,"configured_model":MODEL}
 except urllib.error.HTTPError as e:
  body=e.read().decode(errors="replace")[:1000]; return {"http_status":e.code,"error_body":body}
 except Exception as e:return {"error_type":type(e).__name__,"error":str(e)}
report["models_endpoint"]=get_models()
prompt="Inspect this eFootball gameplay screenshot. Return JSON only with visible_players_count, ball_visible, free_space_visible, game_context, confidence, and a short Portuguese recommendation. Do not invent details."
body={"model":MODEL,"temperature":0,"max_completion_tokens":300,"response_format":{"type":"json_object"},"messages":[{"role":"user","content":[{"type":"text","text":prompt},{"type":"image_url","image_url":{"url":IMAGE_URL}}]}]}
req=urllib.request.Request("https://api.groq.com/openai/v1/chat/completions",data=json.dumps(body).encode(),headers=HEADERS,method="POST")
started=time.perf_counter()
try:
 with urllib.request.urlopen(req,timeout=60) as r:
  envelope=json.loads(r.read().decode()); content=envelope["choices"][0]["message"]["content"]; parsed=json.loads(content); report["vision_test"]={"http_status":r.status,"latency_ms":round((time.perf_counter()-started)*1000,2),"json_raw_content":content,"json_validated":parsed}
except urllib.error.HTTPError as e:
 body=e.read().decode(errors="replace")[:2000]; report["vision_test"]={"http_status":e.code,"latency_ms":round((time.perf_counter()-started)*1000,2),"error_body":body}
except Exception as e: report["vision_test"]={"error_type":type(e).__name__,"error":str(e),"latency_ms":round((time.perf_counter()-started)*1000,2)}
print(json.dumps(report,ensure_ascii=False,indent=2))
if report["vision_test"].get("http_status") != 200: sys.exit(1)
