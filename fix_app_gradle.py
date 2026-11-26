import os
file = r'C:\Users\XPS\Downloads\bems_farms_final\bems_farms_final\android\app\build.gradle.kts'
content = open(file, 'r', encoding='utf-8').read()
content = content.replace('id("kotlin-android")', 'id("kotlin-android")\n    id("com.google.gms.google-services")')
open(file, 'w', encoding='utf-8').write(content)
