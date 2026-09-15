import re

with open('Packages/AppAccount/Sources/AppAccount/AppAccountsManager.swift', 'r') as f:
    content = f.read()

content = re.sub(
    r'@AppStorage\("latestCurrentAccountKey", store: UserPreferences\.sharedDefault\)\n\s*public static var latestCurrentAccountKey: String = ""',
    '''public static var latestCurrentAccountKey: String {
    get { UserPreferences.sharedDefault?.string(forKey: "latestCurrentAccountKey") ?? "" }
    set { UserPreferences.sharedDefault?.set(newValue, forKey: "latestCurrentAccountKey") }
  }''',
    content
)

content = re.sub(
    r'@AppStorage\("previousAccountKey", store: UserPreferences\.sharedDefault\)\n\s*public static var previousAccountKey: String = ""',
    '''public static var previousAccountKey: String {
    get { UserPreferences.sharedDefault?.string(forKey: "previousAccountKey") ?? "" }
    set { UserPreferences.sharedDefault?.set(newValue, forKey: "previousAccountKey") }
  }''',
    content
)

with open('Packages/AppAccount/Sources/AppAccount/AppAccountsManager.swift', 'w') as f:
    f.write(content)

