const fs = require('fs');
const data = JSON.parse(fs.readFileSync('./IceCubesApp/Resources/Localization/Localizable.xcstrings', 'utf8'));
console.log(data.strings["settings.push.duplicate.button.fix"]?.localizations?.en?.stringUnit?.value);
console.log(data.strings["settings.push.duplicate.title"]?.localizations?.en?.stringUnit?.value);
console.log(data.strings["settings.push.duplicate.footer"]?.localizations?.en?.stringUnit?.value);
