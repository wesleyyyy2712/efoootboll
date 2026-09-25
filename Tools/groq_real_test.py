#!/usr/bin/env python3
import base64, json, os, sys, time, urllib.error, urllib.request

MODEL = os.environ.get("GROQ_MODEL", "qwen/qwen3.8-27b")
IMAGE = sys.argv[1]
OUTPUT = sys.argv[2] if len(sys.argv) > 2 else "groq-report.json"
KEY = os.environ.get("GROQ_API_KEY")
if not KEY:
    raise SystemExit("GROQ_API_KEY ausente")
raw = open(IMAGE, "rb").read()
mime = "image/png" if IMAGE.lower().endswith(".png") else "image/jpeg"
prompt = '''Analyze this eFootball gameplay screenshot and return ONLY valid JSON. Use exactly this structure: {"ball": {"x": 0, "y": 0} or null, "controlledPlayer": object or null, "teammates": [], "opponents": [], "freeSpaces": [], "gameContext": "attack|defense|transition|unknown", "confidence": 0, "recommendation": {"type": "forward_pass|lateral_space|pressure_warning|recover|none", "priority": 1, "message": ""} or null}. Player objects must contain position x/y normalized 0..1, boundingBox x/y/width/height normalized 0..1, team user/opponent, confidence 0..1, isFree boolean, and velocity x/y or null. Do not invent players or the ball when not visible. Use empty arrays or null when uncertain. Recommendation message must be short Portuguese.'''
body = {"model": MODEL, "temperature": 0, "max_completion_tokens": 900, "response_format": {"type": "json_object"}, "messages": [{"role": "user", "content": [{"type": "text", "text": prompt}, {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{base64.b64encode(raw).decode()}"}}]}]}
request = urllib.request.Request("https://api.groq.com/openai/v1/chat/completions", data=json.dumps(body).encode(), headers={"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}, method="POST")
started = time.perf_counter()
try:
    with urllib.request.urlopen(request, timeout=60) as response:
        envelope = json.loads(response.read().decode())
except urllib.error.HTTPError as error:
    detail = error.read().decode(errors="replace")
    try: detail = json.loads(detail)
    except Exception: detail = {"raw": detail[:2000]}
    report = {"status":"api_error", "model":MODEL, "image":IMAGE, "latency_ms":round((time.perf_counter()-started)*1000,2), "http_status":error.code, "error":detail, "json_raw_content":None, "json_validated":None, "identified":None, "decision_engine":None, "tts":{"status":"not_run_in_GitHub_runner"}, "limitations":["A API não retornou JSON; a análise visual não foi executada."]}
    with open(OUTPUT,"w") as file: json.dump(report,file,ensure_ascii=False,indent=2)
    print(json.dumps(report,ensure_ascii=False,indent=2)); sys.exit(1)
except Exception as error:
    report={"status":"transport_error","model":MODEL,"image":IMAGE,"latency_ms":round((time.perf_counter()-started)*1000,2),"error":{"type":type(error).__name__,"message":str(error)},"json_raw_content":None,"json_validated":None,"identified":None,"decision_engine":None,"tts":{"status":"not_run_in_GitHub_runner"}}
    with open(OUTPUT,"w") as file: json.dump(report,file,ensure_ascii=False,indent=2)
    print(json.dumps(report,ensure_ascii=False,indent=2)); sys.exit(1)
latency_ms = round((time.perf_counter() - started) * 1000, 2)
raw_content = envelope["choices"][0]["message"]["content"]
try:
    parsed = json.loads(raw_content)
except Exception as error:
    report={"status":"invalid_json","model":MODEL,"image":IMAGE,"latency_ms":latency_ms,"json_raw_content":raw_content,"json_validated":None,"error":{"type":type(error).__name__,"message":str(error)},"tts":{"status":"not_run_in_GitHub_runner"}}
    with open(OUTPUT,"w") as file: json.dump(report,file,ensure_ascii=False,indent=2)
    print(json.dumps(report,ensure_ascii=False,indent=2)); sys.exit(1)
required=["ball","controlledPlayer","teammates","opponents","freeSpaces","gameContext","confidence","recommendation"]
missing=[x for x in required if x not in parsed]
for field in ("teammates","opponents","freeSpaces"):
    if not isinstance(parsed.get(field),list): missing.append(field+"_array")
if not isinstance(parsed.get("confidence"),(int,float)): missing.append("confidence_number")
recommendation=parsed.get("recommendation") or {}
if recommendation.get("message"): decision=recommendation["message"]
elif parsed.get("gameContext")=="attack" and parsed.get("freeSpaces"): decision="Espaço disponível para avançar"
elif parsed.get("gameContext")=="defense": decision="Organize a defesa"
else: decision=None
report={"status":"success","model":MODEL,"image":IMAGE,"latency_ms":latency_ms,"json_raw_content":raw_content,"json_validated":parsed,"validation":{"valid":not missing,"missing_fields":missing},"identified":{"teammates":parsed.get("teammates",[]),"opponents":parsed.get("opponents",[]),"controlledPlayer":parsed.get("controlledPlayer"),"ball":parsed.get("ball"),"freeSpaces":parsed.get("freeSpaces",[]),"unidentified_information_percent":100.0 if not (parsed.get("teammates") or parsed.get("opponents") or parsed.get("ball")) else 0.0},"decision_engine":{"recommendation":decision,"source":"Groq recommendation" if recommendation.get("message") else "local fallback rule"},"tts":{"status":"not_run_in_GitHub_runner","note":"AVSpeechSynthesizer runs in the iOS app; this report validates the text passed to TTS."},"errors":[]}
with open(OUTPUT,"w") as file: json.dump(report,file,ensure_ascii=False,indent=2)
print(json.dumps(report,ensure_ascii=False,indent=2))
