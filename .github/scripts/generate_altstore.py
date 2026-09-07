import os
import json
import urllib.request
from datetime import datetime

repo = os.environ.get("GITHUB_REPOSITORY")
tag = os.environ.get("TAG_NAME")
token = os.environ.get("GITHUB_TOKEN")

if not repo or not tag:
    print("Missing GITHUB_REPOSITORY or TAG_NAME")
    exit(1)

req = urllib.request.Request(f"https://api.github.com/repos/{repo}/releases/tags/{tag}")
req.add_header("Authorization", f"Bearer {token}")
req.add_header("Accept", "application/vnd.github.v3+json")

try:
    with urllib.request.urlopen(req) as response:
        release_data = json.loads(response.read().decode())
except Exception as e:
    print(f"Error fetching release: {e}")
    exit(1)

notes = release_data.get("body", "No release notes.")
date = release_data.get("published_at", datetime.utcnow().isoformat() + "Z")

ipa_asset = None
for asset in release_data.get("assets", []):
    if asset["name"].endswith(".ipa"):
        ipa_asset = asset
        break

if not ipa_asset:
    print("No IPA asset found in this release!")
    exit(1)

download_url = ipa_asset["browser_download_url"]
size = ipa_asset["size"]

app_data = {
    "name": "Jade's Repository",
    "identifier": "com.jadetheda.icecubes.repo",
    "apps": [
        {
            "name": "Ice Cubes",
            "bundleIdentifier": "com.thomasricouard.IceCubesApp",
            "developerName": "Jade",
            "version": tag.lstrip('v'),
            "versionDate": date,
            "versionDescription": notes,
            "downloadURL": download_url,
            "localizedDescription": "A customized build of Ice Cubes for Mastodon.",
            "iconURL": f"https://raw.githubusercontent.com/{repo}/main/IceCubesApp/Assets.xcassets/Icon.appiconset/AppIcon.png",
            "tintColor": "FF0000",
            "size": size
        }
    ]
}

os.makedirs("repo", exist_ok=True)
with open("repo/apps.json", "w") as f:
    json.dump(app_data, f, indent=2)

print("Successfully generated repo/apps.json")
