const fs = require('fs');
const path = '/app/applet/IceCubesApp/Resources/Localization/Localizable.xcstrings';
const data = JSON.parse(fs.readFileSync(path, 'utf8'));

const stringsToAdd = {
  "settings.experimental.title": "Experimental Features",
  "settings.hide-seen.title": "Hide Seen Posts",
  "settings.hide-seen.threshold": "Detection Threshold (Seconds)",
  "settings.hide-seen.liked-only": "Only Detect Liked Posts",
  "settings.hide-seen.require-media": "Require Media to Load",
  "settings.hide-seen.include-boosts": "Hide Boosts of Seen Posts",
  "settings.hide-seen.show-header-button": "Show Button in Header",
  "settings.hide-seen.enabled": "Enable Hide Seen Posts"
};

for (const [key, value] of Object.entries(stringsToAdd)) {
  if (!data.strings[key]) {
    data.strings[key] = {
      extractionState: "manual",
      localizations: {
        en: {
          stringUnit: {
            state: "translated",
            value: value
          }
        }
      }
    };
  }
}

fs.writeFileSync(path, JSON.stringify(data, null, 2));
console.log("Updated localization strings successfully.");
