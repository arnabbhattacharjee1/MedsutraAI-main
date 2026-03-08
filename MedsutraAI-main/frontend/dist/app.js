// Configuration
const CONFIG = {
    API_ENDPOINT: 'YOUR_API_GATEWAY_URL', // Replace with actual API Gateway URL
    MAX_HISTORY: 50,
    LANGUAGES: ['English', 'Hindi', 'Tamil', 'Telugu', 'Bengali', 'Marathi'],
    DEMO_CREDENTIALS: {
        userId: 'test user',
        password: 'test',
        role: 'Oncologist'
    }
};

// Multilingual AI responses
const AI_RESPONSES = {
    'English': {
        'PT001': 'Analysis for Raj Kumar: Stage IIIB Lung Cancer shows moderate response to combined chemotherapy and radiation. Tumor markers indicate 15% reduction. Recommend continuing current protocol with close monitoring of respiratory function. Consider immunotherapy as next-line treatment if progression occurs.',
        'PT002': 'Analysis for Priya Verma: Stage IIA Breast Cancer post-lumpectomy shows excellent prognosis. Hormone receptor positive status indicates good response to endocrine therapy. Continue tamoxifen for 5 years. Regular mammography every 6 months recommended.',
        'PT003': 'Analysis for Amit Singh: Stage IV Pancreatic Cancer with metastasis. Focus on palliative care and quality of life. Pain management protocol effective. Family support and counseling essential. Consider clinical trials for advanced therapies.',
        'PT004': 'Analysis for Sneha Patel: Stage IIIC Ovarian Cancer post-surgery. CA-125 levels decreasing but remain elevated. Continue aggressive platinum-based chemotherapy. Monitor for ascites and pleural effusion. Consider PARP inhibitor maintenance therapy.',
        'PT005': 'Analysis for Vikram Sharma: Stage IIB Prostate Cancer with favorable Gleason score. Active surveillance appropriate given slow progression. PSA levels stable at 6.2 ng/mL. Continue quarterly monitoring. Discuss treatment options if PSA doubling time decreases.',
        'PT006': 'Analysis for Divya Iyer: Stage IA Melanoma with excellent prognosis post-excision. Clear margins achieved. No evidence of lymph node involvement. Annual dermatology follow-up sufficient. Educate on sun protection and self-examination.'
    },
    'Hindi': {
        'PT001': 'राज कुमार का विश्लेषण: स्टेज IIIB फेफड़ों का कैंसर कीमोथेरेपी और रेडिएशन से मध्यम प्रतिक्रिया दिखा रहा है। ट्यूमर मार्कर में 15% कमी। वर्तमान उपचार जारी रखें और श्वसन क्रिया की निगरानी करें। यदि बीमारी बढ़ती है तो इम्यूनोथेरेपी पर विचार करें।',
        'PT002': 'प्रिया वर्मा का विश्लेषण: स्टेज IIA स्तन कैंसर सर्जरी के बाद उत्कृष्ट पूर्वानुमान। हार्मोन रिसेप्टर पॉजिटिव स्थिति अच्छी प्रतिक्रिया दर्शाती है। 5 वर्षों तक टैमोक्सीफेन जारी रखें। हर 6 महीने में मैमोग्राफी की सिफारिश।',
        'PT003': 'अमित सिंह का विश्लेषण: स्टेज IV अग्नाशय का कैंसर मेटास्टेसिस के साथ। उपशामक देखभाल और जीवन की गुणवत्ता पर ध्यान दें। दर्द प्रबंधन प्रभावी है। परिवार का समर्थन और परामर्श आवश्यक। उन्नत उपचार के लिए क्लिनिकल ट्रायल पर विचार करें।',
        'PT004': 'स्नेहा पटेल का विश्लेषण: स्टेज IIIC डिम्बग्रंथि का कैंसर सर्जरी के बाद। CA-125 स्तर घट रहे हैं लेकिन ऊंचे हैं। आक्रामक प्लैटिनम-आधारित कीमोथेरेपी जारी रखें। जलोदर की निगरानी करें। PARP अवरोधक रखरखाव चिकित्सा पर विचार करें।',
        'PT005': 'विक्रम शर्मा का विश्लेषण: स्टेज IIB प्रोस्टेट कैंसर अनुकूल ग्लीसन स्कोर के साथ। धीमी प्रगति को देखते हुए सक्रिय निगरानी उपयुक्त है। PSA स्तर 6.2 ng/mL पर स्थिर। त्रैमासिक निगरानी जारी रखें।',
        'PT006': 'दिव्या अय्यर का विश्लेषण: स्टेज IA मेलेनोमा सर्जरी के बाद उत्कृष्ट पूर्वानुमान। स्पष्ट मार्जिन प्राप्त। लिम्फ नोड की कोई भागीदारी नहीं। वार्षिक त्वचा विशेषज्ञ फॉलो-अप पर्याप्त। सूर्य संरक्षण पर शिक्षित करें।'
    },
    'Tamil': {
        'PT001': 'ராஜ் குமாருக்கான பகுப்பாய்வு: நிலை IIIB நுரையீரல் புற்றுநோய் கீமோதெரபி மற்றும் கதிர்வீச்சுக்கு மிதமான பதிலைக் காட்டுகிறது। கட்டி குறிப்பான்கள் 15% குறைப்பைக் குறிக்கின்றன. சுவாச செயல்பாட்டை கண்காணித்து தற்போதைய சிகிச்சையைத் தொடரவும்.',
        'PT002': 'பிரியா வர்மாவுக்கான பகுப்பாய்வு: நிலை IIA மார்பக புற்றுநோய் அறுவை சிகிச்சைக்குப் பிறகு சிறந்த முன்கணிப்பு. ஹார்மோன் ஏற்பி நேர்மறை நிலை நல்ல பதிலைக் குறிக்கிறது. 5 ஆண்டுகளுக்கு டமாக்ஸிஃபென் தொடரவும்.',
        'PT003': 'அமித் சிங்குக்கான பகுப்பாய்வு: நிலை IV கணைய புற்றுநோய் மெட்டாஸ்டாசிஸுடன். நோய் தணிப்பு பராமரிப்பு மற்றும் வாழ்க்கைத் தரத்தில் கவனம் செலுத்தவும். வலி மேலாண்மை பயனுள்ளதாக உள்ளது.',
        'PT004': 'ஸ்னேகா படேலுக்கான பகுப்பாய்வு: நிலை IIIC கருப்பை புற்றுநோய் அறுவை சிகிச்சைக்குப் பிறகு. CA-125 அளவுகள் குறைகின்றன ஆனால் உயர்ந்ததாகவே உள்ளன. தீவிர பிளாட்டினம் அடிப்படையிலான கீமோதெரபியைத் தொடரவும்.',
        'PT005': 'விக்ரம் சர்மாவுக்கான பகுப்பாய்வு: நிலை IIB புரோஸ்டேட் புற்றுநோய் சாதகமான க்ளீசன் மதிப்பெண்ணுடன். மெதுவான முன்னேற்றத்தைக் கருத்தில் கொண்டு செயலில் கண்காணிப்பு பொருத்தமானது.',
        'PT006': 'திவ்யா ஐயருக்கான பகுப்பாய்வு: நிலை IA மெலனோமா அறுவை சிகிச்சைக்குப் பிறகு சிறந்த முன்கணிப்பு. தெளிவான விளிம்புகள் அடையப்பட்டன. நிணநீர் முனை ஈடுபாடு இல்லை.'
    },
    'Telugu': {
        'PT001': 'రాజ్ కుమార్ విశ్లేషణ: స్టేజ్ IIIB ఊపిరితిత్తుల క్యాన్సర్ కీమోథెరపీ మరియు రేడియేషన్‌కు మితమైన ప్రతిస్పందన చూపిస్తోంది. ట్యూమర్ మార్కర్లు 15% తగ్గుదలను సూచిస్తున్నాయి. శ్వాసకోశ పనితీరును పర్యవేక్షిస్తూ ప్రస్తుత చికిత్సను కొనసాగించండి.',
        'PT002': 'ప్రియా వర్మ విశ్లేషణ: స్టేజ్ IIA రొమ్ము క్యాన్సర్ శస్త్రచికిత్స తర్వాత అద్భుతమైన రోగ నిరూపణ. హార్మోన్ రిసెప్టర్ పాజిటివ్ స్థితి మంచి ప్రతిస్పందనను సూచిస్తుంది. 5 సంవత్సరాల పాటు టామోక్సిఫెన్ కొనసాగించండి.',
        'PT003': 'అమిత్ సింగ్ విశ్లేషణ: స్టేజ్ IV క్లోమ క్యాన్సర్ మెటాస్టాసిస్‌తో. ఉపశమన సంరక్షణ మరియు జీవిత నాణ్యతపై దృష్టి పెట్టండి. నొప్పి నిర్వహణ ప్రభావవంతంగా ఉంది.',
        'PT004': 'స్నేహా పటేల్ విశ్లేషణ: స్టేజ్ IIIC అండాశయ క్యాన్సర్ శస్త్రచికిత్స తర్వాత. CA-125 స్థాయిలు తగ్గుతున్నాయి కానీ ఎక్కువగానే ఉన్నాయి. దూకుడు ప్లాటినం-ఆధారిత కీమోథెరపీని కొనసాగించండి.',
        'PT005': 'విక్రమ్ శర్మ విశ్లేషణ: స్టేజ్ IIB ప్రోస్టేట్ క్యాన్సర్ అనుకూలమైన గ్లీసన్ స్కోర్‌తో. నెమ్మదిగా పురోగతిని పరిగణనలోకి తీసుకుంటే క్రియాశీల పర్యవేక్షణ తగినది.',
        'PT006': 'దివ్య అయ్యర్ విశ్లేషణ: స్టేజ్ IA మెలనోమా శస్త్రచికిత్స తర్వాత అద్భుతమైన రోగ నిరూపణ. స్పష్టమైన అంచులు సాధించబడ్డాయి. శోషరస కణుపు ప్రమేయం లేదు.'
    },
    'Bengali': {
        'PT001': 'রাজ কুমারের বিশ্লেষণ: স্টেজ IIIB ফুসফুসের ক্যান্সার কেমোথেরাপি এবং রেডিয়েশনে মাঝারি প্রতিক্রিয়া দেখাচ্ছে। টিউমার মার্কার 15% হ্রাস নির্দেশ করে। শ্বাসযন্ত্রের কার্যকারিতা পর্যবেক্ষণ করে বর্তমান চিকিৎসা চালিয়ে যান।',
        'PT002': 'প্রিয়া ভার্মার বিশ্লেষণ: স্টেজ IIA স্তন ক্যান্সার অস্ত্রোপচারের পরে চমৎকার পূর্বাভাস। হরমোন রিসেপ্টর পজিটিভ অবস্থা ভাল প্রতিক্রিয়া নির্দেশ করে। 5 বছরের জন্য ট্যামোক্সিফেন চালিয়ে যান।',
        'PT003': 'অমিত সিংহের বিশ্লেষণ: স্টেজ IV অগ্ন্যাশয় ক্যান্সার মেটাস্টেসিস সহ। উপশমকারী যত্ন এবং জীবনযাত্রার মানের উপর ফোকাস করুন। ব্যথা ব্যবস্থাপনা কার্যকর।',
        'PT004': 'স্নেহা প্যাটেলের বিশ্লেষণ: স্টেজ IIIC ডিম্বাশয়ের ক্যান্সার অস্ত্রোপচারের পরে। CA-125 মাত্রা হ্রাস পাচ্ছে কিন্তু উচ্চ রয়ে গেছে। আক্রমণাত্মক প্ল্যাটিনাম-ভিত্তিক কেমোথেরাপি চালিয়ে যান।',
        'PT005': 'বিক্রম শর্মার বিশ্লেষণ: স্টেজ IIB প্রোস্টেট ক্যান্সার অনুকূল গ্লিসন স্কোর সহ। ধীর অগ্রগতি বিবেচনা করে সক্রিয় নজরদারি উপযুক্ত।',
        'PT006': 'দিব্যা আইয়ারের বিশ্লেষণ: স্টেজ IA মেলানোমা অস্ত্রোপচারের পরে চমৎকার পূর্বাভাস। পরিষ্কার মার্জিন অর্জিত। লিম্ফ নোড জড়িত নেই।'
    },
    'Marathi': {
        'PT001': 'राज कुमारचे विश्लेषण: स्टेज IIIB फुफ्फुसाचा कर्करोग केमोथेरपी आणि रेडिएशनला मध्यम प्रतिसाद दर्शवितो. ट्यूमर मार्कर 15% घट दर्शवितात. श्वसन कार्याचे निरीक्षण करत सध्याचे उपचार सुरू ठेवा.',
        'PT002': 'प्रिया वर्माचे विश्लेषण: स्टेज IIA स्तन कर्करोग शस्त्रक्रियेनंतर उत्कृष्ट रोगनिदान. हार्मोन रिसेप्टर पॉझिटिव्ह स्थिती चांगला प्रतिसाद दर्शवते. 5 वर्षांसाठी टॅमॉक्सिफेन सुरू ठेवा.',
        'PT003': 'अमित सिंगचे विश्लेषण: स्टेज IV स्वादुपिंडाचा कर्करोग मेटास्टॅसिससह. उपशामक काळजी आणि जीवन गुणवत्तेवर लक्ष केंद्रित करा. वेदना व्यवस्थापन प्रभावी आहे.',
        'PT004': 'स्नेहा पटेलचे विश्लेषण: स्टेज IIIC अंडाशयाचा कर्करोग शस्त्रक्रियेनंतर. CA-125 पातळी कमी होत आहे परंतु उच्च राहिली आहे. आक्रमक प्लॅटिनम-आधारित केमोथेरपी सुरू ठेवा.',
        'PT005': 'विक्रम शर्माचे विश्लेषण: स्टेज IIB प्रोस्टेट कर्करोग अनुकूल ग्लीसन स्कोअरसह. मंद प्रगती लक्षात घेता सक्रिय निरीक्षण योग्य आहे.',
        'PT006': 'दिव्या अय्यरचे विश्लेषण: स्टेज IA मेलेनोमा शस्त्रक्रियेनंतर उत्कृष्ट रोगनिदान. स्पष्ट मार्जिन प्राप्त. लिम्फ नोड सहभाग नाही.'
    }
};

// Demo patient data
const DEMO_PATIENTS = [
    {
        id: 'PT001',
        name: 'Raj Kumar',
        diagnosis: 'Lung Cancer',
        risk: 'high',
        age: 58,
        lastVisit: '2026-03-05',
        avatar: '👨',
        stage: 'Stage IIIB',
        treatment: 'Chemotherapy + Radiation',
        oncologist: 'Dr. Sharma',
        nextAppointment: '2026-03-15',
        notes: 'Patient responding well to current treatment protocol. Tumor markers showing improvement. Continue monitoring respiratory function.'
    },
    {
        id: 'PT002',
        name: 'Priya Verma',
        diagnosis: 'Breast Cancer',
        risk: 'medium',
        age: 45,
        lastVisit: '2026-03-06',
        avatar: '👩',
        stage: 'Stage IIA',
        treatment: 'Lumpectomy + Hormone Therapy',
        oncologist: 'Dr. Mehta',
        nextAppointment: '2026-03-20',
        notes: 'Post-surgical recovery excellent. Hormone therapy initiated. Regular mammography scheduled every 6 months.'
    },
    {
        id: 'PT003',
        name: 'Amit Singh',
        diagnosis: 'Pancreatic Cancer',
        risk: 'critical',
        age: 62,
        lastVisit: '2026-03-07',
        avatar: '👨',
        stage: 'Stage IV',
        treatment: 'Palliative Chemotherapy',
        oncologist: 'Dr. Kumar',
        nextAppointment: '2026-03-10',
        notes: 'Advanced stage with metastasis. Focus on palliative care and pain management. Family counseling recommended.'
    },
    {
        id: 'PT004',
        name: 'Sneha Patel',
        diagnosis: 'Ovarian Cancer',
        risk: 'high',
        age: 52,
        lastVisit: '2026-03-04',
        avatar: '👩',
        stage: 'Stage IIIC',
        treatment: 'Surgery + Chemotherapy',
        oncologist: 'Dr. Reddy',
        nextAppointment: '2026-03-18',
        notes: 'Post-operative recovery ongoing. CA-125 levels elevated but decreasing. Continue aggressive chemotherapy protocol.'
    },
    {
        id: 'PT005',
        name: 'Vikram Sharma',
        diagnosis: 'Prostate Cancer',
        risk: 'medium',
        age: 67,
        lastVisit: '2026-03-03',
        avatar: '👨',
        stage: 'Stage IIB',
        treatment: 'Active Surveillance',
        oncologist: 'Dr. Gupta',
        nextAppointment: '2026-04-03',
        notes: 'Slow-growing tumor. PSA levels stable. Continue active surveillance with quarterly monitoring.'
    },
    {
        id: 'PT006',
        name: 'Divya Iyer',
        diagnosis: 'Melanoma',
        risk: 'low',
        age: 38,
        lastVisit: '2026-03-08',
        avatar: '👩',
        stage: 'Stage IA',
        treatment: 'Surgical Excision',
        oncologist: 'Dr. Nair',
        nextAppointment: '2026-06-08',
        notes: 'Early detection. Complete excision successful. No evidence of metastasis. Regular skin checks recommended.'
    }
];

// State management
let conversationHistory = [];
let currentLanguage = 'English';
let isProcessing = false;
let currentUser = null;

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
    loadConversation();
    loadUser();
    setupEventListeners();
    console.log('MedSutra AI initialized');
});

// Event listeners
function setupEventListeners() {
    const chatInput = document.getElementById('chatInput');
    if (chatInput) {
        chatInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                sendMessage();
            }
        });
    }

    // Language selector
    const languageBtn = document.getElementById('languageBtn');
    if (languageBtn) {
        languageBtn.addEventListener('click', toggleLanguage);
    }
}

// Scroll to section
function scrollTo(selector) {
    const element = document.querySelector(selector);
    if (element) {
        element.scrollIntoView({ behavior: 'smooth' });
    }
}

// Send message to AI
async function sendMessage() {
    const input = document.getElementById('chatInput');
    const message = input.value.trim();
    
    if (!message || isProcessing) return;
    
    isProcessing = true;
    input.value = '';
    input.disabled = true;

    // Add user message
    addMessage(message, 'user');
    
    // Add to history
    conversationHistory.push({
        role: 'user',
        content: message,
        timestamp: new Date().toISOString()
    });
    
    // Show typing indicator
    const typingId = showTypingIndicator();
    
    try {
        // Call API
        const response = await fetch(CONFIG.API_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                message: message,
                conversation_history: conversationHistory,
                language: currentLanguage
            })
        });
        
        if (!response.ok) {
            throw new Error(`API error: ${response.status}`);
        }
        
        const data = await response.json();
        
        // Remove typing indicator
        removeTypingIndicator(typingId);
        
        // Add AI response
        addMessage(data.response || data.message, 'ai');
        
        // Add to history
        conversationHistory.push({
            role: 'assistant',
            content: data.response || data.message,
            timestamp: new Date().toISOString()
        });
        
        // Save conversation
        saveConversation();
        
    } catch (error) {
        console.error('Error:', error);
        removeTypingIndicator(typingId);
        addMessage('Sorry, I encountered an error. Please try again or contact support.', 'ai');
    } finally {
        isProcessing = false;
        input.disabled = false;
        input.focus();
    }
}

// Add message to chat
function addMessage(text, type) {
    const chatMessages = document.getElementById('chatMessages');
    if (!chatMessages) return;
    
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${type}-message`;
    
    const avatar = document.createElement('div');
    avatar.className = 'message-avatar';
    avatar.textContent = type === 'user' ? '👤' : '🤖';
    
    const content = document.createElement('div');
    content.className = 'message-content';
    
    const label = document.createElement('strong');
    label.textContent = type === 'user' ? 'You' : 'MedSutra AI';
    
    const textContent = document.createElement('p');
    textContent.textContent = text;
    
    content.appendChild(label);
    content.appendChild(textContent);
    
    messageDiv.appendChild(avatar);
    messageDiv.appendChild(content);
    
    chatMessages.appendChild(messageDiv);
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

// Show typing indicator
function showTypingIndicator() {
    const chatMessages = document.getElementById('chatMessages');
    if (!chatMessages) return null;
    
    const typingDiv = document.createElement('div');
    typingDiv.className = 'message ai-message typing-indicator';
    typingDiv.id = 'typing-' + Date.now();
    
    const avatar = document.createElement('div');
    avatar.className = 'message-avatar';
    avatar.textContent = '🤖';
    
    const content = document.createElement('div');
    content.className = 'message-content';
    content.innerHTML = '<p>Thinking...</p>';
    
    typingDiv.appendChild(avatar);
    typingDiv.appendChild(content);
    
    chatMessages.appendChild(typingDiv);
    chatMessages.scrollTop = chatMessages.scrollHeight;
    
    return typingDiv.id;
}

// Remove typing indicator
function removeTypingIndicator(id) {
    if (!id) return;
    const indicator = document.getElementById(id);
    if (indicator) {
        indicator.remove();
    }
}

// Quick action
function askQuestion(question) {
    const input = document.getElementById('chatInput');
    if (input) {
        input.value = question;
        sendMessage();
    }
}

// Clear chat
function clearChat() {
    if (confirm('Are you sure you want to clear the chat history?')) {
        conversationHistory = [];
        const chatMessages = document.getElementById('chatMessages');
        if (chatMessages) {
            chatMessages.innerHTML = `
                <div class="message ai-message">
                    <div class="message-avatar">🤖</div>
                    <div class="message-content">
                        <strong>MedSutra AI</strong>
                        <p>Chat cleared. How can I assist you today?</p>
                    </div>
                </div>
            `;
        }
        saveConversation();
    }
}

// Voice input (placeholder)
function startVoice() {
    alert('Voice input feature coming soon!');
}

// Language toggle
function toggleLanguage() {
    const currentIndex = CONFIG.LANGUAGES.indexOf(currentLanguage);
    const nextIndex = (currentIndex + 1) % CONFIG.LANGUAGES.length;
    currentLanguage = CONFIG.LANGUAGES[nextIndex];
    
    const languageBtn = document.getElementById('languageBtn');
    if (languageBtn) {
        languageBtn.textContent = `🌐 ${currentLanguage}`;
    }
    
    // Show notification
    if (currentUser) {
        const languageNames = {
            'English': 'English',
            'Hindi': 'हिंदी',
            'Tamil': 'தமிழ்',
            'Telugu': 'తెలుగు',
            'Bengali': 'বাংলা',
            'Marathi': 'मराठी'
        };
        
        addMessage(`Language changed to ${languageNames[currentLanguage]} (${currentLanguage}). AI analysis will now be provided in ${currentLanguage}.`, 'ai');
    }
}

// Save conversation to localStorage
function saveConversation() {
    try {
        const data = {
            history: conversationHistory.slice(-CONFIG.MAX_HISTORY),
            language: currentLanguage,
            timestamp: new Date().toISOString()
        };
        localStorage.setItem('medsutra_conversation', JSON.stringify(data));
    } catch (error) {
        console.error('Error saving conversation:', error);
    }
}

// Load conversation from localStorage
function loadConversation() {
    try {
        const saved = localStorage.getItem('medsutra_conversation');
        if (saved) {
            const data = JSON.parse(saved);
            conversationHistory = data.history || [];
            currentLanguage = data.language || 'English';
            
            // Update language button
            const languageBtn = document.getElementById('languageBtn');
            if (languageBtn) {
                languageBtn.textContent = `🌐 ${currentLanguage}`;
            }
            
            // Optionally restore messages to UI
            // restoreMessages();
        }
    } catch (error) {
        console.error('Error loading conversation:', error);
    }
}

// Restore messages to UI (optional)
function restoreMessages() {
    const chatMessages = document.getElementById('chatMessages');
    if (!chatMessages || conversationHistory.length === 0) return;
    
    chatMessages.innerHTML = '';
    
    conversationHistory.forEach(msg => {
        const type = msg.role === 'user' ? 'user' : 'ai';
        addMessage(msg.content, type);
    });
}

// Export for debugging
window.MedSutraAI = {
    sendMessage,
    clearChat,
    askQuestion,
    startVoice,
    getHistory: () => conversationHistory,
    getLanguage: () => currentLanguage
};

// Login functions
function showLogin() {
    const modal = document.getElementById('loginModal');
    if (modal) {
        modal.classList.add('show');
    }
}

function closeLogin() {
    const modal = document.getElementById('loginModal');
    if (modal) {
        modal.classList.remove('show');
    }
}

function handleLogin(event) {
    event.preventDefault();
    
    const userId = document.getElementById('userId').value.trim();
    const password = document.getElementById('password').value;
    const role = document.getElementById('role').value.trim();
    
    // Validate credentials
    if (userId === CONFIG.DEMO_CREDENTIALS.userId && 
        password === CONFIG.DEMO_CREDENTIALS.password && 
        role === CONFIG.DEMO_CREDENTIALS.role) {
        
        // Set current user
        currentUser = {
            userId: userId,
            role: role,
            loginTime: new Date().toISOString()
        };
        
        // Save to localStorage
        localStorage.setItem('medsutra_user', JSON.stringify(currentUser));
        
        // Update UI
        updateUserUI();
        
        // Close modal
        closeLogin();
        
        // Show success message
        addMessage(`Welcome back, ${userId}! You are logged in as ${role}.`, 'ai');
        
    } else {
        alert('Invalid credentials. Please use the demo credentials provided.');
    }
}

function updateUserUI() {
    if (!currentUser) return;
    
    // Hide login button
    const loginBtn = document.getElementById('loginBtn');
    if (loginBtn) {
        loginBtn.style.display = 'none';
    }
    
    // Show user info
    const userInfo = document.getElementById('userInfo');
    const userName = document.getElementById('userName');
    const userRole = document.getElementById('userRole');
    
    if (userInfo && userName && userRole) {
        userName.textContent = currentUser.userId;
        userRole.textContent = currentUser.role;
        userInfo.classList.add('show');
    }
    
    // Show patient dashboard
    showPatientDashboard();
    
    // Show AI assistant
    const aiSection = document.getElementById('ai-assistant');
    if (aiSection) {
        aiSection.style.display = 'block';
    }
    
    // Hide hero section
    const heroSection = document.getElementById('heroSection');
    if (heroSection) {
        heroSection.style.display = 'none';
    }
}

function logout() {
    if (confirm('Are you sure you want to logout?')) {
        currentUser = null;
        localStorage.removeItem('medsutra_user');
        
        // Show login button
        const loginBtn = document.getElementById('loginBtn');
        if (loginBtn) {
            loginBtn.style.display = 'block';
        }
        
        // Hide user info
        const userInfo = document.getElementById('userInfo');
        if (userInfo) {
            userInfo.classList.remove('show');
        }
        
        // Hide patient dashboard
        const dashboard = document.getElementById('patientDashboard');
        if (dashboard) {
            dashboard.classList.remove('show');
        }
        
        // Hide AI assistant
        const aiSection = document.getElementById('ai-assistant');
        if (aiSection) {
            aiSection.style.display = 'none';
        }
        
        // Show hero section
        const heroSection = document.getElementById('heroSection');
        if (heroSection) {
            heroSection.style.display = 'block';
        }
        
        // Clear chat
        clearChat();
        
        addMessage('You have been logged out successfully.', 'ai');
    }
}

function loadUser() {
    try {
        const saved = localStorage.getItem('medsutra_user');
        if (saved) {
            currentUser = JSON.parse(saved);
            updateUserUI();
        }
    } catch (error) {
        console.error('Error loading user:', error);
    }
}

// Close modal on outside click
window.addEventListener('click', (event) => {
    const loginModal = document.getElementById('loginModal');
    const reportModal = document.getElementById('reportModal');
    
    if (event.target === loginModal) {
        closeLogin();
    }
    
    if (event.target === reportModal) {
        closeReport();
    }
});

// Patient Dashboard Functions
function showPatientDashboard() {
    const dashboard = document.getElementById('patientDashboard');
    if (dashboard) {
        dashboard.classList.add('show');
        renderPatients();
    }
}

function renderPatients() {
    const grid = document.getElementById('patientsGrid');
    if (!grid) return;
    
    grid.innerHTML = '';
    
    DEMO_PATIENTS.forEach(patient => {
        const tile = createPatientTile(patient);
        grid.appendChild(tile);
    });
}

function createPatientTile(patient) {
    const tile = document.createElement('div');
    tile.className = `patient-tile risk-${patient.risk}`;
    
    const riskLabel = {
        'critical': 'Critical Risk',
        'high': 'High Risk',
        'medium': 'Medium Risk',
        'low': 'Low Risk'
    }[patient.risk];
    
    const riskIcon = {
        'critical': '🔴',
        'high': '🟠',
        'medium': '🟡',
        'low': '🟢'
    }[patient.risk];
    
    tile.innerHTML = `
        <div class="patient-header">
            <div class="patient-info">
                <h3>${patient.name}</h3>
                <div class="patient-id">ID: ${patient.id} • Age: ${patient.age}</div>
            </div>
            <div class="patient-avatar">${patient.avatar}</div>
        </div>
        <div class="patient-diagnosis">
            <div class="diagnosis-label">Diagnosis</div>
            <div class="diagnosis-value">${patient.diagnosis}</div>
        </div>
        <div class="patient-risk ${patient.risk}">
            <span>${riskIcon}</span>
            <span>${riskLabel}</span>
        </div>
        <div class="patient-actions">
            <button class="patient-action-btn" onclick="viewPatient('${patient.id}')">📋 View</button>
            <button class="patient-action-btn" onclick="analyzePatient('${patient.id}')">🤖 Analyze</button>
        </div>
    `;
    
    return tile;
}

function viewPatient(patientId) {
    const patient = DEMO_PATIENTS.find(p => p.id === patientId);
    if (patient) {
        showPatientReport(patient);
    }
}

function showPatientReport(patient) {
    const modal = document.getElementById('reportModal');
    const content = document.getElementById('reportContent');
    
    if (!modal || !content) return;
    
    const riskLabel = {
        'critical': 'Critical Risk',
        'high': 'High Risk',
        'medium': 'Medium Risk',
        'low': 'Low Risk'
    }[patient.risk];
    
    content.innerHTML = `
        <div class="report-header">
            <h2 class="report-title">${patient.avatar} ${patient.name}</h2>
            <div class="report-meta">Patient ID: ${patient.id} • Age: ${patient.age} • Last Visit: ${patient.lastVisit}</div>
        </div>
        
        <div class="report-section">
            <h3>📋 Diagnosis Information</h3>
            <div class="report-field">
                <span class="report-label">Primary Diagnosis</span>
                <span class="report-value">${patient.diagnosis}</span>
            </div>
            <div class="report-field">
                <span class="report-label">Cancer Stage</span>
                <span class="report-value">${patient.stage}</span>
            </div>
            <div class="report-field">
                <span class="report-label">Risk Level</span>
                <span class="risk-badge ${patient.risk}">${riskLabel}</span>
            </div>
        </div>
        
        <div class="report-section">
            <h3>💊 Treatment Plan</h3>
            <div class="report-field">
                <span class="report-label">Current Treatment</span>
                <span class="report-value">${patient.treatment}</span>
            </div>
            <div class="report-field">
                <span class="report-label">Oncologist</span>
                <span class="report-value">${patient.oncologist}</span>
            </div>
            <div class="report-field">
                <span class="report-label">Next Appointment</span>
                <span class="report-value">${patient.nextAppointment}</span>
            </div>
        </div>
        
        <div class="report-section">
            <h3>📝 Clinical Notes</h3>
            <div class="report-notes">
                <p>${patient.notes}</p>
            </div>
        </div>
        
        <div style="display: flex; gap: 1rem; margin-top: 2rem;">
            <button class="btn-primary" style="flex: 1;" onclick="analyzePatient('${patient.id}'); closeReport();">
                🤖 AI Analysis
            </button>
            <button class="btn-secondary" style="flex: 1;" onclick="closeReport()">
                Close
            </button>
        </div>
    `;
    
    modal.classList.add('show');
}

function closeReport() {
    const modal = document.getElementById('reportModal');
    if (modal) {
        modal.classList.remove('show');
    }
}

function analyzePatient(patientId) {
    const patient = DEMO_PATIENTS.find(p => p.id === patientId);
    if (patient) {
        scrollTo('#ai-assistant');
        
        // Get AI response in current language
        const response = AI_RESPONSES[currentLanguage]?.[patientId] || AI_RESPONSES['English'][patientId];
        
        // Add user question
        addMessage(`Analyze ${patient.name}'s cancer risk and treatment options`, 'user');
        
        // Simulate AI thinking
        setTimeout(() => {
            addMessage(response, 'ai');
        }, 1000);
    }
}

function refreshDashboard() {
    renderPatients();
    addMessage('Patient dashboard refreshed successfully.', 'ai');
}

function addPatient() {
    alert('Add patient feature coming soon! This will integrate with your EMR system.');
}
