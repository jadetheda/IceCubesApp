import urllib.request, json
req = urllib.request.Request(
    'https://misskey.io/api/users/show',
    data=b'{"username": "admin"}',
    headers={'Content-Type': 'application/json'}
)
try:
    resp = urllib.request.urlopen(req).read()
    print("Success")
except urllib.error.HTTPError as e:
    print(e.code, e.read())
except Exception as e:
    print(e)
