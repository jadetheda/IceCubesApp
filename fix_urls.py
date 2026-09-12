import re

with open("Packages/NetworkClient/Sources/NetworkClient/DTOs/Misskey/MisskeyNote+Translate.swift", "r") as f:
    code = f.read()

code = code.replace("public func toStatus(reblogged: Bool = false) -> Status {", "public func toStatus(reblogged: Bool = false, server: String = \"misskey\") -> Status {")
code = code.replace("public func toAccount() -> Account {", "public func toAccount(server: String = \"misskey\") -> Account {")
code = code.replace("public func toNotification() -> Models.Notification? {", "public func toNotification(server: String = \"misskey\") -> Models.Notification? {")
code = code.replace("func toStatus() -> Status {", "func toStatus(server: String = \"misskey\") -> Status {")

code = code.replace("let noteUrl = self.url ?? self.uri ?? \"https://misskey/\\(self.id)\"", "let noteUrl = self.url ?? self.uri ?? \"https://\\(server)/notes/\\(self.id)\"")
code = code.replace("let renoteUrl = renote.url ?? renote.uri ?? \"https://misskey/\\(renote.id)\"", "let renoteUrl = renote.url ?? renote.uri ?? \"https://\\(server)/notes/\\(renote.id)\"")

code = code.replace("let account = self.user.toAccount()", "let account = self.user.toAccount(server: server)")
code = code.replace("account: renote.user.toAccount()", "account: renote.user.toAccount(server: server)")
code = code.replace("account: user.toAccount()", "account: user.toAccount(server: server)")
code = code.replace("status: self.note?.toStatus()", "status: self.note?.toStatus(server: server)")

code = code.replace("\"https://\\(self.host ?? \"misskey\")/\\(safeUsername)\"", "\"https://\\(self.host ?? server)/@\\(safeUsername)\"")
code = code.replace("\"https://\\(host ?? \"example.com\")/placeholder.png\"", "\"https://\\(host ?? server)/placeholder.png\"")

with open("Packages/NetworkClient/Sources/NetworkClient/DTOs/Misskey/MisskeyNote+Translate.swift", "w") as f:
    f.write(code)
