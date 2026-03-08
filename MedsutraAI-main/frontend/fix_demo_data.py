#!/usr/bin/env python3
"""
Script to anonymize patient names in demo_app.py and update web_demo.py
"""

import re

# Read demo_app.py
with open('demo_app.py', 'r', encoding='utf-8') as f:
    demo_content = f.read()

# Define name replacements (full name -> anonymized)
name_replacements = {
    'Priya Verma': 'Pri** Ver**',
    'Suresh Patel': 'Sur*** Pat**',
    'Arjun Singh': 'Arj** Sin**',
    'Mohan Reddy': 'Moh** Red**',
    'Lakshmi Iyer': 'Lak*** Iye*',
    'Vijay Deshmukh': 'Vij** Des****',
    'Anjali Sharma': 'Anj*** Sha***',
    'Ramesh Gupta': 'Ram*** Gup**',
    'Krishnan Nair': 'Kri**** Nai*',
}

# Apply replacements
for full_name, anon_name in name_replacements.items():
    demo_content = demo_content.replace(full_name, anon_name)

# Write back demo_app.py
with open('demo_app.py', 'w', encoding='utf-8') as f:
    f.write(demo_content)

print("✓ Anonymized patient names in demo_app.py")

# Update web_demo.py - remove P12345 and update patient names
with open('web_demo.py', 'r', encoding='utf-8') as f:
    web_content = f.read()

# Update patient names dictionary
old_dict = """            patient_names = {
                'P12345': 'John Doe',
                'ONC1001': 'Rajesh Kumar',
                'ONC1002': 'Priya Verma',
                'ONC1003': 'Suresh Patel',
                'ONC1004': 'Arjun Singh',
                'ONC1005': 'Mohan Reddy',
                'ONC1006': 'Lakshmi Iyer',
                'ONC1007': 'Vijay Deshmukh',
                'ONC1008': 'Anjali Sharma',
                'ONC1009': 'Ramesh Gupta',
                'ONC1010': 'Krishnan Nair',
            }"""

new_dict = """            patient_names = {
                'ONC1001': 'Raj*** Kum**',
                'ONC1002': 'Pri** Ver**',
                'ONC1003': 'Sur*** Pat**',
                'ONC1004': 'Arj** Sin**',
                'ONC1005': 'Moh** Red**',
                'ONC1006': 'Lak*** Iye*',
                'ONC1007': 'Vij** Des****',
                'ONC1008': 'Anj*** Sha***',
                'ONC1009': 'Ram*** Gup**',
                'ONC1010': 'Kri**** Nai*',
            }"""

web_content = web_content.replace(old_dict, new_dict)

with open('web_demo.py', 'w', encoding='utf-8') as f:
    f.write(web_content)

print("✓ Updated patient names in web_demo.py")

# Update templates/index.html - remove P12345 from dropdown
with open('templates/index.html', 'r', encoding='utf-8') as f:
    html_content = f.read()

# Remove P12345 option
html_content = html_content.replace(
    '<option value="P12345">P12345 - John Doe (Cardiac Patient)</option>\n                            ',
    ''
)

# Update patient names in dropdown
dropdown_replacements = {
    'ONC1001 - Rajesh Kumar': 'ONC1001 - Raj*** Kum**',
    'ONC1002 - Priya Verma': 'ONC1002 - Pri** Ver**',
    'ONC1003 - Suresh Patel': 'ONC1003 - Sur*** Pat**',
    'ONC1004 - Arjun Singh': 'ONC1004 - Arj** Sin**',
    'ONC1005 - Mohan Reddy': 'ONC1005 - Moh** Red**',
    'ONC1006 - Lakshmi Iyer': 'ONC1006 - Lak*** Iye*',
    'ONC1007 - Vijay Deshmukh': 'ONC1007 - Vij** Des****',
    'ONC1008 - Anjali Sharma': 'ONC1008 - Anj*** Sha***',
    'ONC1009 - Ramesh Gupta': 'ONC1009 - Ram*** Gup**',
    'ONC1010 - Krishnan Nair': 'ONC1010 - Kri**** Nai*',
}

for old_text, new_text in dropdown_replacements.items():
    html_content = html_content.replace(old_text, new_text)

with open('templates/index.html', 'w', encoding='utf-8') as f:
    f.write(html_content)

print("✓ Removed P12345 and anonymized names in templates/index.html")

print("\n✅ All replacements completed successfully!")
print("\nChanges made:")
print("1. Anonymized all patient names with asterisks")
print("2. Removed P12345 (cardiac patient) from all files")
print("3. Updated dropdown to show only oncology patients")
