import json, sys, os, re, urllib.request

prompt = open('/workspace/mr-do-player/minimax_review_prompt.txt').read()
payload = {
    'model': 'MiniMax-M3',
    'messages': [{'role': 'user', 'content': prompt}],
    'max_tokens': 24000,
    'temperature': 0.3
}

req = urllib.request.Request(
    'https://api.minimax.io/v1/chat/completions',
    data=json.dumps(payload).encode(),
    headers={
        'Authorization': f"Bearer {os.environ['MINIMAX_API_KEY']}",
        'Content-Type': 'application/json'
    }
)
resp = urllib.request.urlopen(req, timeout=300)
data = json.loads(resp.read())

if data.get('base_resp', {}).get('status_code', 0) != 0:
    print('ERROR:', json.dumps(data, indent=2)[:500])
    sys.exit(1)

content = data['choices'][0]['message']['content']
usage = data.get('usage', {})
sys.stderr.write('USAGE: ' + json.dumps(usage) + '\n')

clean = re.sub(r'<think>.*?</think>', '', content, flags=re.DOTALL).strip()
if not clean or len(clean) < 100:
    clean = content

with open('/workspace/mr-do-player/minimax_review_result.md', 'w') as f:
    f.write(clean)
print(f'OK: {len(clean)} chars written')
