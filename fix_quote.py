with open("Packages/NetworkClient/Sources/NetworkClient/DTOs/Misskey/MisskeyNote+Translate.swift", "r") as f:
    code = f.read()

code = code.replace("""                tags: [],
                quote: nil,
                quotesCount: nil,
            )""", """                tags: [],
                quote: nil,
                quotesCount: nil,
                quoteApproval: nil
            )""")

with open("Packages/NetworkClient/Sources/NetworkClient/DTOs/Misskey/MisskeyNote+Translate.swift", "w") as f:
    f.write(code)
