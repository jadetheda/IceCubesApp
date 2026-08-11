const fs = require('fs');

function patchTimeline(file) {
    let content = fs.readFileSync(file, 'utf8');
    content = content.replace(/\s*\.onReceive\(NotificationCenter\.default\.publisher\(for: \.statusBarTapped\)\) \{ _ in\s+if let previous = viewModel\.handleScrollToTopTrigger\(\) \{\s+DispatchQueue\.main\.asyncAfter\(deadline: \.now\(\) \+ 0\.1\) \{\s+scrollToIdAnimated = previous\s+\}\s+\}\s+\}/, '');
    fs.writeFileSync(file, content);
}
patchTimeline('Packages/Timeline/Sources/Timeline/View/TimelineListView.swift');
