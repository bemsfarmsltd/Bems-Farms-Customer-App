import os
file = r'C:\Users\XPS\Downloads\bems_farms_final\bems_farms_final\pubspec.yaml'
content = open(file, 'r', encoding='utf-8').read()
content = content.replace('google_sign_in: ^7.2.0', 'google_sign_in: ^6.2.1')
open(file, 'w', encoding='utf-8').write(content)
