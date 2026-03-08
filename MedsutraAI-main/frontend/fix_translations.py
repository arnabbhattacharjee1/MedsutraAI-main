#!/usr/bin/env python3
"""
Script to fix translation issues in templates/index.html
"""

# Read the HTML file
with open('templates/index.html', 'r', encoding='utf-8') as f:
    html_content = f.read()

# Add missing persona translations to all language dictionaries
persona_translations = {
    'hi': """                'persona-doctor': '👨‍⚕️ डॉक्टर / ऑन्कोलॉजिस्ट',
                'persona-patient': '👤 रोगी',
                'voice-listening': 'सुन रहा है...',
                'voice-transcript-title': 'वॉयस ट्रांसक्रिप्ट',""",
    'ta': """                'persona-doctor': '👨‍⚕️ மருத்துவர் / புற்றுநோய் மருத்துவர்',
                'persona-patient': '👤 நோயாளி',
                'voice-listening': 'கேட்கிறது...',
                'voice-transcript-title': 'குரல் டிரான்ஸ்கிரிப்ட்',""",
    'te': """                'persona-doctor': '👨‍⚕️ వైద్యుడు / ఆంకాలజిస్ట్',
                'persona-patient': '👤 రోగి',
                'voice-listening': 'వింటోంది...',
                'voice-transcript-title': 'వాయిస్ ట్రాన్స్‌క్రిప్ట్',""",
    'bn': """                'persona-doctor': '👨‍⚕️ ডাক্তার / অনকোলজিস্ট',
                'persona-patient': '👤 রোগী',
                'voice-listening': 'শুনছে...',
                'voice-transcript-title': 'ভয়েস ট্রান্সক্রিপ্ট',""",
    'mr': """                'persona-doctor': '👨‍⚕️ डॉक्टर / ऑन्कोलॉजिस्ट',
                'persona-patient': '👤 रुग्ण',
                'voice-listening': 'ऐकत आहे...',
                'voice-transcript-title': 'व्हॉइस ट्रान्सक्रिप्ट',""",
    'gu': """                'persona-doctor': '👨‍⚕️ ડૉક્ટર / ઓન્કોલોજિસ્ટ',
                'persona-patient': '👤 દર્દી',
                'voice-listening': 'સાંભળી રહ્યું છે...',
                'voice-transcript-title': 'વૉઇસ ટ્રાન્સક્રિપ્ટ',""",
    'kn': """                'persona-doctor': '👨‍⚕️ ವೈದ್ಯರು / ಆಂಕಾಲಜಿಸ್ಟ್',
                'persona-patient': '👤 ರೋಗಿ',
                'voice-listening': 'ಕೇಳುತ್ತಿದೆ...',
                'voice-transcript-title': 'ವಾಯ್ಸ್ ಟ್ರಾನ್ಸ್‌ಕ್ರಿಪ್ಟ್',""",
    'ml': """                'persona-doctor': '👨‍⚕️ ഡോക്ടർ / ഓങ്കോളജിസ്റ്റ്',
                'persona-patient': '👤 രോഗി',
                'voice-listening': 'കേൾക്കുന്നു...',
                'voice-transcript-title': 'വോയ്‌സ് ട്രാൻസ്ക്രിപ്റ്റ്',""",
    'pa': """                'persona-doctor': '👨‍⚕️ ਡਾਕਟਰ / ਓਨਕੋਲੋਜਿਸਟ',
                'persona-patient': '👤 ਮਰੀਜ਼',
                'voice-listening': 'ਸੁਣ ਰਿਹਾ ਹੈ...',
                'voice-transcript-title': 'ਵੌਇਸ ਟ੍ਰਾਂਸਕ੍ਰਿਪਟ',""",
}

# Check if translations are already present, if not add them
for lang_code, translations in persona_translations.items():
    # Find the language section
    lang_marker = f"{lang_code}: {{"
    if lang_marker in html_content:
        # Check if persona-doctor is already there
        if f"'{lang_code}'" in html_content and "'persona-doctor'" not in html_content.split(f"{lang_code}: {{")[1].split("}")[0]:
            # Add translations after the opening brace
            html_content = html_content.replace(
                f"{lang_code}: {{",
                f"{lang_code}: {{\n{translations}"
            )

with open('templates/index.html', 'w', encoding='utf-8') as f:
    f.write(html_content)

print("✓ Added missing persona translations to all languages")
print("\n✅ Translation fixes completed!")
print("\nThe UI language selector should now work properly for all elements.")
