import os
file = r'C:\Users\XPS\Downloads\bems_farms_final\bems_farms_final\android\settings.gradle.kts'
content = open(file, 'r', encoding='utf-8').read()
content = content.replace('id("org.jetbrains.kotlin.android") version "2.2.20" apply false', 'id("org.jetbrains.kotlin.android") version "2.2.20" apply false\n    id("com.google.gms.google-services") version "4.4.2" apply false')
open(file, 'w', encoding='utf-8').write(content)
