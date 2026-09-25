import json
import os

path = '/D/IceCubesApp/IceCubesApp/Resources/Localization/Localizable.xcstrings'

with open(path, 'r', encoding='utf-8') as f:
    catalog = json.load(f)

# Delete the wrong keys if they exist
wrong_keys = ['Portrait rows limit', 'Landscape rows limit']
for key in wrong_keys:
    if key in catalog.get('strings', {}):
        del catalog['strings'][key]

keys_to_inject = {
    'settings.display.custom-emojis-layout.portrait-rows-limit': 'Portrait rows limit',
    'settings.display.custom-emojis-layout.landscape-rows-limit': 'Landscape rows limit'
}

supported_langs = set()
for key, string_obj in catalog.get('strings', {}).items():
    localizations = string_obj.get('localizations', {})
    for lang in localizations:
        supported_langs.add(lang)

for key, translation in keys_to_inject.items():
    if key not in catalog['strings']:
        catalog['strings'][key] = {'localizations': {}, 'extractionState': 'manual'}
    
    for lang in supported_langs:
        catalog['strings'][key]['localizations'][lang] = {
            'stringUnit': {
                'state': 'translated',
                'value': translation
            }
        }

with open(path, 'w', encoding='utf-8') as f:
    json.dump(catalog, f, indent=2, ensure_ascii=False)
    f.write('\n')

print("Successfully injected keys into Localizable.xcstrings")
