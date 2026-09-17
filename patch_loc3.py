import json

path = './IceCubesApp/Resources/Localization/Localizable.xcstrings'
with open(path, 'r') as f:
    data = json.load(f)

if 'status.action.download-all-images' in data['strings']:
    del data['strings']['status.action.download-all-images']

data['strings']['status.action.download-media'] = {
    "extractionState": "manual",
    "localizations": {
        "en": {
            "stringUnit": {
                "state": "translated",
                "value": "Download media"
            }
        }
    }
}

data['strings']['status.action.download-all-media'] = {
    "extractionState": "manual",
    "localizations": {
        "en": {
            "stringUnit": {
                "state": "translated",
                "value": "Download all media"
            }
        }
    }
}

with open(path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
