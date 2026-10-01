import Foundation

extension String {
    func extractMentionsAndRest() -> (mentions: [String], rest: String) {
        var mentions: [String] = []
        let words = self.components(separatedBy: .whitespacesAndNewlines)
        var restStartIndex = self.startIndex
        
        for word in words {
            if word.isEmpty {
                continue
            }
            if word.hasPrefix("@") {
                mentions.append(word)
                if let range = self[restStartIndex...].range(of: word) {
                    restStartIndex = range.upperBound
                }
            } else {
                break
            }
        }
        
        let rest = String(self[restStartIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (mentions, rest)
    }
}

let test1 = "@user1 @user2 hello"
print(test1.extractMentionsAndRest())

let test2 = "   @user1 \n @user2 \n\n hello @user3"
print(test2.extractMentionsAndRest())

let test3 = "@user1"
print(test3.extractMentionsAndRest())

let test4 = "hello @user1"
print(test4.extractMentionsAndRest())

