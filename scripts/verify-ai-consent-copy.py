"""Verify rendered Hebrew notice against the single canonical payload.
Hash: SHA-256 of UTF-8 JSON, sorted keys, compact separators, no trailing newline.
"""
from pathlib import Path
import json, re, hashlib, xml.etree.ElementTree as ET
root = Path(__file__).resolve().parents[1]
raw = (root/'shared/ai-data-sharing-consent.json').read_bytes()
copy = json.loads(raw)
assert raw == json.dumps(copy,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()
assert copy['links'] == []
assert copy == json.loads((root/'web/src/ai-data-sharing-consent.json').read_text())
swift = (root/'ios/Localization.swift').read_text()
body = re.search(r'static let aiConsentBody = """\n(.*?)\n    """',swift,re.S)[1]
assert '\n'.join(line[4:] for line in body.split('\n')) == copy['body']
for key, name in [('title','Title'),('accept','AcceptAction'),('decline','DeclineAction')]:
    assert re.search(r'static let aiConsent'+name+r' = "(.*?)"',swift)[1] == copy[key]
assert (root/'android/app/src/main/res/raw/ai_consent.txt').read_text() == copy['body']
for path in (root/'android/app/src/main/res').glob('values*/strings.xml'):
    strings = {e.attrib.get('name'):e.text for e in ET.parse(path).getroot()}
    for key, name in [('title','title'),('accept','accept_action'),('decline','decline_action')]:
        if 'ai_consent_'+name in strings: assert strings['ai_consent_'+name] == copy[key], path
print('Three-platform rendered-copy parity passed. SHA-256:',hashlib.sha256(raw).hexdigest())
