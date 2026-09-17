import json

with open('IceCubesApp/Resources/Localization/Localizable.xcstrings', 'r') as f:
    data = json.load(f)

data['strings']['settings.other.loop-video'] = {
    'extractionState': 'manual',
    'localizations': {
        'en': {
            'stringUnit': {
                'state': 'translated',
                'value': 'Loop videos'
            }
        }
    }
}

with open('IceCubesApp/Resources/Localization/Localizable.xcstrings', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
