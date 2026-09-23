import json
import os

path = '/D/IceCubesApp/IceCubesApp/Resources/Localization/Localizable.xcstrings'

with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

translations = {
  "settings.content.media.embed-metadata.title": {
    "en-GB": "Exported photo metadata",
    "fr": "Métadonnées de la photo exportée",
    "es": "Metadatos de foto exportada",
    "de": "Exportierte Foto-Metadaten",
    "it": "Metadati della foto esportata",
    "pt-BR": "Metadados da foto exportada",
    "nl": "Geëxporteerde fotometadata",
    "ja": "エクスポートされた写真のメタデータ",
    "ko": "내보낸 사진 메타데이터",
    "zh-Hans": "导出的照片元数据",
    "zh-Hant": "匯出的相片中繼資料",
    "be": "Метададзеныя экспартаванага фота",
    "ca": "Metadades de la foto exportada",
    "eu": "Esportatutako argazkien metadatuak",
    "nb": "Eksporterte bildemetadata",
    "pl": "Metadane wyeksportowanego zdjęcia",
    "tr": "Dışa aktarılan fotoğraf meta verileri",
    "uk": "Метадані експортованого фото"
  },
  "settings.content.media.embed-metadata.footer": {
    "en-GB": "Select what post information should be embedded into the EXIF metadata of photos when you save them to your library.",
    "fr": "Sélectionnez quelles informations de la publication doivent être intégrées aux métadonnées EXIF des photos lors de leur enregistrement dans votre bibliothèque.",
    "es": "Selecciona qué información de la publicación debe incrustarse en los metadatos EXIF de las fotos al guardarlas en tu biblioteca.",
    "de": "Wähle aus, welche Beitragsinformationen in die EXIF-Metadaten von Fotos eingebettet werden sollen, wenn du sie in deiner Mediathek speicherst.",
    "it": "Seleziona quali informazioni del post devono essere incorporate nei metadati EXIF delle foto quando le salvi nella tua libreria.",
    "pt-BR": "Selecione quais informações da publicação devem ser incorporadas aos metadados EXIF das fotos quando você as salva em sua biblioteca.",
    "nl": "Selecteer welke berichtinformatie moet worden ingesloten in de EXIF-metadata van foto's wanneer u ze in uw bibliotheek opslaat.",
    "ja": "ライブラリに保存する際、写真のEXIFメタデータに埋め込む投稿情報を選択してください。",
    "ko": "라이브러리에 저장할 때 사진의 EXIF 메타데이터에 포함할 게시물 정보를 선택하세요.",
    "zh-Hans": "选择在保存照片到图库时，哪些帖子信息应嵌入到照片的 EXIF 元数据中。",
    "zh-Hant": "選擇在將相片儲存至圖庫時，應將哪些貼文資訊嵌入至相片的 EXIF 中繼資料內。",
    "be": "Выберыце, якая інфармацыя аб публікацыі павінна быць убудавана ў EXIF-метададзеныя фатаграфій пры іх захаванні ў вашу бібліятэку.",
    "ca": "Selecciona quina informació de la publicació s'ha d'incrustar a les metadades EXIF de les fotos quan les desis a la teva biblioteca.",
    "eu": "Hautatu argazkien EXIF metadatuetan zein argitalpen-informazio txertatu behar den zure liburutegian gordetzean.",
    "nb": "Velg hvilken innleggsinformasjon som skal bygges inn i EXIF-metadataene til bilder når du lagrer dem i biblioteket ditt.",
    "pl": "Wybierz, jakie informacje o poście mają być osadzone w metadanych EXIF zdjęć podczas zapisywania ich w bibliotece.",
    "tr": "Fotoğrafları kitaplığınıza kaydederken fotoğrafların EXIF meta verilerine hangi gönderi bilgilerinin gömüleceğini seçin.",
    "uk": "Виберіть, яка інформація про допис має бути вбудована в EXIF-метадані фотографій під час їх збереження до вашої бібліотеки."
  },
  "settings.content.media.embed-post-url": {
    "en-GB": "Embed Post URL",
    "fr": "Intégrer l'URL de la publication",
    "es": "Incrustar URL de la publicación",
    "de": "Beitrags-URL einbetten",
    "it": "Incorpora URL del post",
    "pt-BR": "Incorporar URL da publicação",
    "nl": "Bericht-URL insluiten",
    "ja": "投稿URLを埋め込む",
    "ko": "게시물 URL 포함",
    "zh-Hans": "嵌入帖子 URL",
    "zh-Hant": "嵌入貼文 URL",
    "be": "Убудаваць URL публікацыі",
    "ca": "Incrustar URL de la publicació",
    "eu": "Txertatu argitalpenaren URLa",
    "nb": "Bygg inn innleggs-URL",
    "pl": "Osadź adres URL posta",
    "tr": "Gönderi URL'sini Göm",
    "uk": "Вбудувати URL-адресу допису"
  },
  "settings.content.media.embed-post-text": {
    "en-GB": "Embed Post Text",
    "fr": "Intégrer le texte de la publication",
    "es": "Incrustar texto de la publicación",
    "de": "Beitragstext einbetten",
    "it": "Incorpora testo del post",
    "pt-BR": "Incorporar texto da publicação",
    "nl": "Berichttekst insluiten",
    "ja": "投稿テキストを埋め込む",
    "ko": "게시물 텍스트 포함",
    "zh-Hans": "嵌入帖子文本",
    "zh-Hant": "嵌入貼文文字",
    "be": "Убудаваць тэкст публікацыі",
    "ca": "Incrustar text de la publicació",
    "eu": "Txertatu argitalpenaren testua",
    "nb": "Bygg inn innleggstekst",
    "pl": "Osadź tekst posta",
    "tr": "Gönderi Metnini Göm",
    "uk": "Вбудувати текст допису"
  },
  "settings.content.media.embed-post-tags": {
    "en-GB": "Embed Post Tags",
    "fr": "Intégrer les tags de la publication",
    "es": "Incrustar etiquetas de la publicación",
    "de": "Beitrags-Tags einbetten",
    "it": "Incorpora tag del post",
    "pt-BR": "Incorporar tags da publicação",
    "nl": "Berichttags insluiten",
    "ja": "投稿タグを埋め込む",
    "ko": "게시물 태그 포함",
    "zh-Hans": "嵌入帖子标签",
    "zh-Hant": "嵌入貼文標籤",
    "be": "Убудаваць тэгі публікацыі",
    "ca": "Incrustar etiquetes de la publicació",
    "eu": "Txertatu argitalpenaren etiketak",
    "nb": "Bygg inn innleggstagger",
    "pl": "Osadź tagi posta",
    "tr": "Gönderi Etiketlerini Göm",
    "uk": "Вбудувати теги допису"
  }
}

if "strings" not in data:
    data["strings"] = {}

for key, langs in translations.items():
    if key not in data["strings"]:
        data["strings"][key] = {
            "extractionState": "manual",
            "localizations": {}
        }
    
    if "localizations" not in data["strings"][key]:
        data["strings"][key]["localizations"] = {}
        
    for lang, value in langs.items():
        data["strings"][key]["localizations"][lang] = {
            "stringUnit": {
                "state": "translated",
                "value": value
            }
        }

with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write('\n')

print('Successfully updated Localizable.xcstrings')
