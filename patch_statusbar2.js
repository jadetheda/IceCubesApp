const fs = require('fs');
let content = fs.readFileSync('Packages/Explore/Sources/Explore/ExploreView.swift', 'utf8');
content = content.replace(/\s*\.onReceive\(NotificationCenter\.default\.publisher\(for: \.statusBarTapped\)\) \{ _ in\s+if let previous = handleScrollToTopTrigger\(\) \{\s+DispatchQueue\.main\.asyncAfter\(deadline: \.now\(\) \+ 0\.1\) \{\s+scrollToIdAnimated = previous\s+\}\s+\}\s+\}/, '');
fs.writeFileSync('Packages/Explore/Sources/Explore/ExploreView.swift', content);
