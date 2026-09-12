import re

text = "Hello @user1! And @user2@example.com. <br>@user3 <br>@user4@domain.net!"
pattern = r"(^|\s|<br>)@([a-zA-Z0-9_]+)(?:@([a-zA-Z0-9_-]+(?:\.[a-zA-Z0-9_-]+)*))?"

for match in re.finditer(pattern, text):
    prefix = match.group(1)
    username = match.group(2)
    domain = match.group(3)
    print(f"Prefix: {prefix!r}, Username: {username}, Domain: {domain}")
text2 = "my email is test@example.com"
for match in re.finditer(pattern, text2):
    print("MATCHED:", match.groups())
