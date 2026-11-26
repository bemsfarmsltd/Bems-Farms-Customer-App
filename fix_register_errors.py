import os
file_register = r'C:\Users\XPS\Downloads\bems_farms_final\bems_farms_final\lib\features\auth\presentation\pages\register_page.dart'
with open(file_register, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix the double-call syntax error
bad_error_code = "ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error,))(error.toString().replaceFirst('Exception: ', ''));"
good_error_code = "ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error,));"
content = content.replace(bad_error_code, good_error_code)

# 2. Add missing imports if they don't exist
imports_to_add = """
import 'package:bems_farms/features/auth/data/repositories/token_storage.dart';
import 'package:bems_farms/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:bems_farms/features/home/presentation/pages/main_nav_page.dart';
"""
if 'token_storage.dart' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';" + imports_to_add)

# 3. Fix "Not a constant expression" for MainNavPage and OnboardingPage
# If those pages don't have const constructors, I can just remove the 'const' keyword
content = content.replace('const MainNavPage()', 'MainNavPage()')
content = content.replace('const OnboardingPage()', 'OnboardingPage()')

with open(file_register, 'w', encoding='utf-8') as f:
    f.write(content)
print("Done fixing register_page.dart")
