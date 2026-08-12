import Foundation
let urls = ["https://denden.world/system/media_attachments/files/117/073/332/642/322/887/original/05e447891271dcc4.mp4"]
let allExts = urls.compactMap { URL(string: $0)?.pathExtension.lowercased() }
print(allExts)
