import os
file_path = r'C:\Users\XPS\Downloads\bems_farms_final\bems_farms_final\lib\features\auth\data\repositories\auth_repository.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("Uri.parse('/auth/google')", "Uri.parse('\/auth/google')")
content = content.replace("Uri.parse('/auth/apple')", "Uri.parse('\/auth/apple')")
content = content.replace("Uri.parse('\/auth/google')", "Uri.parse('\/auth/google')")
content = content.replace("Uri.parse('\/auth/apple')", "Uri.parse('\/auth/apple')")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Fixed URIs')
