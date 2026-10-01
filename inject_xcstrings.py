import json
import os

filepath = 'IceCubesApp/Resources/Localization/Localizable.xcstrings'
with open(filepath, 'r', encoding='utf-8') as f:
    data = json.load(f)

langs = set()
for key, item in data['strings'].items():
    if 'localizations' in item:
        for lang in item['localizations'].keys():
            langs.add(lang)

en_values = {
    'settings.experimental.hide-seen-posts.enabled': 'Enable Hide Seen Posts',
    'settings.experimental.hide-seen-posts.threshold': 'Hide after being seen for %1$.1fs',
    'settings.experimental.hide-seen-posts.liked-only': 'Hide Only Liked Posts',
    'settings.experimental.hide-seen-posts.include-boosts': 'Include Boosts',
    'settings.experimental.hide-seen-posts.show-in-header': 'Show in Timeline Header',
    'settings.experimental.hide-seen-posts.is-toggle': 'Display as a Toggle'
}

translations = {
    'es': {
        'settings.experimental.hide-seen-posts.enabled': 'Habilitar Ocultar publicaciones vistas',
        'settings.experimental.hide-seen-posts.threshold': 'Ocultar después de ser visto por %1$.1fs',
        'settings.experimental.hide-seen-posts.liked-only': 'Ocultar solo publicaciones que te gustaron',
        'settings.experimental.hide-seen-posts.include-boosts': 'Incluir impulsos',
        'settings.experimental.hide-seen-posts.show-in-header': 'Mostrar en el encabezado de la línea de tiempo',
        'settings.experimental.hide-seen-posts.is-toggle': 'Mostrar como un interruptor'
    },
    'fr': {
        'settings.experimental.hide-seen-posts.enabled': 'Activer Masquer les publications vues',
        'settings.experimental.hide-seen-posts.threshold': 'Masquer après avoir été vu pendant %1$.1fs',
        'settings.experimental.hide-seen-posts.liked-only': 'Masquer uniquement les publications aimées',
        'settings.experimental.hide-seen-posts.include-boosts': 'Inclure les partages',
        'settings.experimental.hide-seen-posts.show-in-header': 'Afficher dans l\'en-tête du fil',
        'settings.experimental.hide-seen-posts.is-toggle': 'Afficher comme un interrupteur'
    },
    'de': {
        'settings.experimental.hide-seen-posts.enabled': 'Gesehene Beiträge ausblenden aktivieren',
        'settings.experimental.hide-seen-posts.threshold': 'Ausblenden, nachdem es für %1$.1fs gesehen wurde',
        'settings.experimental.hide-seen-posts.liked-only': 'Nur gelikte Beiträge ausblenden',
        'settings.experimental.hide-seen-posts.include-boosts': 'Boosts einschließen',
        'settings.experimental.hide-seen-posts.show-in-header': 'In der Timeline-Kopfzeile anzeigen',
        'settings.experimental.hide-seen-posts.is-toggle': 'Als Schalter anzeigen'
    },
    'it': {
        'settings.experimental.hide-seen-posts.enabled': 'Abilita Nascondi i post visti',
        'settings.experimental.hide-seen-posts.threshold': 'Nascondi dopo essere stato visto per %1$.1fs',
        'settings.experimental.hide-seen-posts.liked-only': 'Nascondi solo i post piaciuti',
        'settings.experimental.hide-seen-posts.include-boosts': 'Includi i boost',
        'settings.experimental.hide-seen-posts.show-in-header': 'Mostra nell\'intestazione della cronologia',
        'settings.experimental.hide-seen-posts.is-toggle': 'Mostra come interruttore'
    },
    'ja': {
        'settings.experimental.hide-seen-posts.enabled': '既読の投稿を隠すを有効にする',
        'settings.experimental.hide-seen-posts.threshold': '%1$.1f秒後に隠す',
        'settings.experimental.hide-seen-posts.liked-only': 'お気に入りの投稿のみ隠す',
        'settings.experimental.hide-seen-posts.include-boosts': 'ブーストを含める',
        'settings.experimental.hide-seen-posts.show-in-header': 'タイムラインのヘッダーに表示する',
        'settings.experimental.hide-seen-posts.is-toggle': 'トグルとして表示する'
    }
}

for key, en_text in en_values.items():
    if key not in data['strings']:
        data['strings'][key] = {
            "extractionState": "manual",
            "localizations": {}
        }
    
    localizations = data['strings'][key]['localizations']
    
    for lang in langs:
        if lang == 'en' or lang == 'en-GB':
            localizations[lang] = {
                "stringUnit": {
                    "state": "translated",
                    "value": en_text
                }
            }
        elif lang in translations and key in translations[lang]:
            localizations[lang] = {
                "stringUnit": {
                    "state": "needs_review",
                    "value": translations[lang][key]
                }
            }
        else:
            localizations[lang] = {
                "stringUnit": {
                    "state": "needs_review",
                    "value": en_text
                }
            }

with open(filepath, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
