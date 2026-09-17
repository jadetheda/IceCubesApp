import json

path = './IceCubesApp/Resources/Localization/Localizable.xcstrings'
with open(path, 'r') as f:
    data = json.load(f)

data['strings']['status.action.download-all-images'] = {
    "extractionState": "manual",
    "localizations": {
        "en": {
            "stringUnit": {
                "state": "translated",
                "value": "Download all images"
            }
        }
    }
}

with open(path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
