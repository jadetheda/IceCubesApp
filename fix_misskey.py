with open("Packages/NetworkClient/Sources/NetworkClient/DTOs/Misskey/MisskeyNote+Translate.swift", "r") as f:
    code = f.read()

code = code.replace("private let fediverseDateFormatterWithFraction: ISO8601DateFormatter =", "nonisolated(unsafe) private let fediverseDateFormatterWithFraction: ISO8601DateFormatter =")
code = code.replace("private let fediverseDateFormatterStandard: ISO8601DateFormatter =", "nonisolated(unsafe) private let fediverseDateFormatterStandard: ISO8601DateFormatter =")

code = code.replace("""
                favourited: renote.myReaction != nil,
                reblogged: false, // will be handled by UI layer if it's the current user's reblog
                bookmarked: false,
""", """
                favourited: renote.myReaction != nil,
                reblogged: false, // will be handled by UI layer if it's the current user's reblog
                pinned: false,
                bookmarked: false,
""")

with open("Packages/NetworkClient/Sources/NetworkClient/DTOs/Misskey/MisskeyNote+Translate.swift", "w") as f:
    f.write(code)
