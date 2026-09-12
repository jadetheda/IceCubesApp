import urllib.request, json

req = urllib.request.Request(
    'https://oekakiskey.com/api/ap/show',
    data=b'{"uri": "https://mastodon.social/@jadetheda"}',
    headers={'Content-Type': 'application/json'}
)
try:
    resp = urllib.request.urlopen(req).read()
    data = json.loads(resp)
    print(data['type'])
    print(data['object']['username'])
except Exception as e:
    print(e)
