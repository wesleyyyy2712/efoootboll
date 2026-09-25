#!/usr/bin/env python3
import base64, json, os, sys, time, urllib.request

MODEL = os.environ.get("GROQ_MODEL", "qwen/qwen3.8-27b")
IMAGE = sys.argv[1]
KEY = os.environ.get("GROQ_API_KEY")
if not KEY:
    raise SystemExit("GROQ_API_KEY ausente")
raw = open(IMAGE, "rb").read()
mime = "image/png" if IMAGE.lower().endswith(".png") else "image/jpeg"
prompt = '''Analyze this eFootball gameplay screenshot and return ONLY valid JSON. Use exactly this structure: {"ball": {"x": 0, "y": 0} or null, "controlledPlayer": object or null, "teammates": [], "opponents": [], "freeSpaces": [], "gameContext": "attack|defense|transition|unknown", "confidence": 0, "recommendation": {"type": "forward_pass|lateral_space|pressure_warning|recover|none", "priority": 1, "message": ""} or null}. Player objects must contain position x/y normalized 0..1, boundingBox x/y/width/height normalized 0..1, team user/opponent, confidence 0..1, isFree boolean, and velocity x/y or null. Do not invent players or the ball when not visible. Use empty arrays or null when uncertain. Recommendation message must be short Portuguese.'''
body = {"model": MODEL, "temperature": 0, "max_completion_tokens": 900, "response_format": {"type": "json_object"}, "messages": [{"role": "user", "content": [{"type": "text", "text": prompt}, {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{base64.b64encode(raw).decode()}"}}]}]}
request = urllib.request.Request("https://api.groq.com/openai/v1/chat/completions", data=json.dumps(body).encode(), headers={"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}, method="POST")
started = time.perf_counter()
with urllib.request.urlopen(request, timeout=60) as response:
    envelope = json.loads(response.read().decode())
latency_ms = round((time.perf_counter() - started) * 1000, 2)
raw_content = envelope["choices"][0]["message"]["content"]
parsed = json.loads(raw_content)
required = ["ball", "controlledPlayer", "teammates", "opponents", "freeSpaces", "gameContext", "confidence", "recommendation"]
missing = [x for x in required if x not in parsed]
for field in ("teammates", "opponents", "freeSpaces"):
    if not isinstance(parsed.get(field), list): missing.append(field + "_array")
if not isinstance(parsed.get("confidence"), (int, float)): missing.append("confidence_number")
identified = len(parsed.get("teammates", [])) + len(parsed.get("opponents", [])) + (1 if parsed.get("ball") else 0)
possible = len(parsed.get("teammates", [])) + len(parsed.get("opponents", [])) + (1 if parsed.get("ball") else 0)
missing_pct = 100.0 if possible == 0 else 0.0
recommendation = parsed.get("recommendation") or {}
if not recommendation.get("message"):
    if parsed.get("gameContext") == "attack" and parsed.get("freeSpaces"):
        decision = "Espaço disponível para avançar"
    elif parsed.get("gameContext") == "defense":
        decision = "Organize a defesa"
    else:
        decision = None
else:
    decision = recommendation["message"]
report = {"model": MODEL, "image": IMAGE, "latency_ms": latency_ms, "json_raw_content": raw_content, "json_validated": parsed, "validation": {"valid": not missing, "missing_fields": missing}, "identified": {"teammates": parsed.get("teammates", []), "opponents": parsed.get("opponents", []), "controlledPlayer": parsed.get("controlledPlayer"), "ball": parsed.get("ball"), "freeSpaces": parsed.get("freeSpaces", []), "unidentified_information_percent": missing_pct}, "decision_engine": {"recommendation": decision, "source": "Groq recommendation" if recommendation.get("message") else "local fallback rule"}, "tts": {"status": "not_run_in_GitHub_runner", "note": "AVSpeechSynthesizer is executed in the iOS app; this report validates the text passed to TTS."}, "errors": []}
print(json.dumps(report, ensure_ascii=False, indent=2))
