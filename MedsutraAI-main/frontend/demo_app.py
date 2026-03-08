"""
Clinical AI Capabilities - Demo Application

This demo showcases the Clinical_Summarizer component with sample patient data.
"""

import sys
from datetime import datetime
from typing import List

from src.models.clinical_document import ClinicalDocument, DocumentType, Clinician
from src.models.summarizer import SummarizerInput, SummaryType
from src.models.patient import Language
from src.services.clinical_summarizer import ClinicalSummarizer
from src.services.fhir_adapter import FHIRAdapter
from src.services.ontology_grounding import OntologyGroundingService
from src.services.explainability_generator import ExplainabilityGenerator
from src.models.fhir import PatientBundle, FHIRDocumentReference, FHIRResourceType


class MockFHIRAdapterDemo(FHIRAdapter):
    """Mock FHIR adapter with sample patient data for demo."""
    
    def __init__(self):
        self.base_url = "http://demo-fhir"
        self.timeout = 30
        self.retry_attempts = 3
        self._sample_data = self._create_sample_data()
    
    def _create_sample_data(self) -> dict:
        """Create sample patient data for demo."""
        return {
            "ONC1001": [
                {
                    "id": "ONC1001-DOC001",
                    "type": "11488-4",  # Discharge Summary
                    "content": """
ONCOLOGY DISCHARGE SUMMARY

Patient: Raj*** Kum** (ONC1001)
Date of Birth: 1968-03-12
Age: 58 years
Gender: Male

Admission Date: 2026-02-18
Discharge Date: 2026-02-27

Chief Complaint: Persistent cough and weight loss

History of Present Illness:
58-year-old male smoker (40 pack-years) presented with 3-month history of persistent cough,
hemoptysis, and unintentional weight loss of 15 kg. Patient reports progressive dyspnea on exertion.

Diagnosis:
Stage IIIB Non-Small Cell Lung Carcinoma (Adenocarcinoma)
ICD-10 Code: C34.9 (Malignant neoplasm of bronchus and lung, unspecified)

Tumor Characteristics:
- Location: Right upper lobe
- Size: 5.2 cm primary mass
- Lymph Node Involvement: Mediastinal nodes (N2)
- Metastasis: None detected (M0)
- Histology: Adenocarcinoma, moderately differentiated
- Molecular Testing: EGFR wild-type, ALK negative, PD-L1 50%

Treatment Plan:
1. Concurrent chemoradiation therapy
2. Immunotherapy with Pembrolizumab (PD-1 inhibitor)
3. Smoking cessation counseling
4. Pulmonary rehabilitation

Medications on Discharge:
- Carboplatin/Pemetrexed chemotherapy (scheduled)
- Pembrolizumab 200mg IV every 3 weeks
- Dexamethasone 4mg as needed
- Ondansetron 8mg for nausea

Prognosis: 5-year survival rate approximately 30-40% with treatment

Discharge Condition: Stable
                    """,
                },
                {
                    "id": "ONC1001-DOC002",
                    "type": "18842-5",  # Radiology Report
                    "content": """
CT CHEST WITH CONTRAST

Patient: Raj*** Kum** (ONC1001)
Exam Date: 2026-02-18

FINDINGS:
- Right upper lobe: 5.2 cm spiculated mass with central cavitation
- Mediastinal lymphadenopathy: Multiple enlarged nodes (largest 2.8 cm)
- No pleural effusion
- No distant metastases identified

IMPRESSION:
Right upper lobe mass with mediastinal lymph node involvement
Highly suspicious for primary lung malignancy, Stage IIIB
                    """,
                },
            ],
            "ONC1002": [
                {
                    "id": "ONC-DOC001",
                    "type": "11488-4",  # Discharge Summary
                    "content": """
ONCOLOGY DISCHARGE SUMMARY

Patient: Pri** Ver** (ONC1002)
Admission Date: 2026-02-20
Discharge Date: 2026-02-28
Date of Birth: 1981-07-22
Age: 44 years
Gender: Female

Chief Complaint: Right breast mass detected on routine screening mammography

History of Present Illness:
44-year-old female presented to oncology clinic following abnormal screening mammography.
Patient reported no breast pain, nipple discharge, or palpable lumps. Family history 
significant for maternal breast cancer at age 52.

Diagnostic Workup:
- Screening mammography revealed spiculated mass in right breast upper outer quadrant
- BI-RADS Category 5 (Highly suggestive of malignancy)
- Core needle biopsy performed
- Pathology confirmed invasive ductal carcinoma

Diagnosis:
Stage II Invasive Ductal Carcinoma of Right Breast
ICD-10 Code: C50.9 (Malignant neoplasm of breast, unspecified)

Tumor Characteristics:
- Histology: Invasive Ductal Carcinoma
- Grade: Moderately differentiated (Grade 2)
- Tumor Size: 2.8 cm
- Lymph Node Status: 1 of 3 sentinel nodes positive
- Hormone Receptor Status: ER positive (85%), PR positive (70%)
- HER2 Status: Negative (IHC 1+)
- Ki-67 Proliferation Index: 18%
- Molecular Subtype: Luminal A

Treatment Plan:
1. Surgical Management:
   - Breast-conserving surgery (lumpectomy) with sentinel lymph node biopsy
   - Clear surgical margins achieved
   - Oncotype DX testing ordered to guide chemotherapy decision

2. Adjuvant Therapy:
   - Radiation therapy to right breast (recommended post-surgery)
   - Hormone therapy: Tamoxifen 20mg daily for 5-10 years
   - Chemotherapy: Decision pending Oncotype DX score

3. Supportive Care:
   - Genetic counseling and BRCA testing recommended
   - Fertility preservation discussion completed
   - Psycho-oncology referral provided

Medications on Discharge:
- Tamoxifen 20mg daily (to start after completion of chemotherapy if indicated)
- Ondansetron 8mg as needed for nausea
- Acetaminophen 500mg as needed for pain

Follow-up:
- Medical Oncology: 1 week (Oncotype DX results discussion)
- Radiation Oncology: 2 weeks
- Surgical Oncology: 2 weeks (wound check)
- Genetic Counseling: 4 weeks

Prognosis:
With appropriate treatment, 5-year survival rate for Stage II ER+/PR+/HER2- breast 
cancer is approximately 90-95%. Patient counseled on importance of adherence to 
hormone therapy and regular surveillance.

Discharge Condition: Stable, ambulatory, tolerating oral intake
                    """,
                },
                {
                    "id": "ONC-DOC002",
                    "type": "11525-3",  # Lab Report
                    "content": """
ONCOLOGY LABORATORY REPORT

Patient: Pri** Ver** (ONC1002)
Collection Date: 2026-02-21
Ordering Physician: Dr. Sharma, Medical Oncology

TUMOR MARKERS:
- CA 15-3: 48 U/mL (ELEVATED) [Normal: <30 U/mL]
- CEA: 3.2 ng/mL (NORMAL) [Normal: <5.0 ng/mL]

COMPLETE BLOOD COUNT:
- WBC: 6.8 K/uL (NORMAL) [4.5-11.0]
- Hemoglobin: 12.8 g/dL (NORMAL) [12.0-16.0]
- Hematocrit: 38.5% (NORMAL) [36.0-46.0]
- Platelets: 285 K/uL (NORMAL) [150-400]
- Neutrophils: 65% (NORMAL)
- Lymphocytes: 28% (NORMAL)

COMPREHENSIVE METABOLIC PANEL:
- Glucose: 92 mg/dL (NORMAL)
- BUN: 14 mg/dL (NORMAL)
- Creatinine: 0.9 mg/dL (NORMAL)
- eGFR: >90 mL/min (NORMAL)
- Sodium: 140 mEq/L (NORMAL)
- Potassium: 4.2 mEq/L (NORMAL)
- Calcium: 9.5 mg/dL (NORMAL)
- Total Protein: 7.2 g/dL (NORMAL)
- Albumin: 4.1 g/dL (NORMAL)
- AST: 28 U/L (NORMAL)
- ALT: 32 U/L (NORMAL)
- Alkaline Phosphatase: 68 U/L (NORMAL)
- Total Bilirubin: 0.8 mg/dL (NORMAL)

HORMONE LEVELS:
- Estradiol: 145 pg/mL (Premenopausal range)
- FSH: 8.2 mIU/mL (Premenopausal)
- LH: 6.5 mIU/mL (Premenopausal)

INTERPRETATION:
- Elevated CA 15-3 consistent with breast malignancy
- Normal organ function suitable for chemotherapy if indicated
- Premenopausal hormone status confirmed
- No evidence of bone marrow suppression
- Liver and kidney function within normal limits

CLINICAL CORRELATION:
Baseline tumor marker elevation noted. CA 15-3 will be monitored during treatment 
and follow-up as a marker of disease response and potential recurrence.
                    """,
                },
                {
                    "id": "ONC-DOC003",
                    "type": "18842-5",  # Radiology Report - Mammography
                    "content": """
MAMMOGRAPHY REPORT

Patient: Pri** Ver** (ONC1002)
Exam Date: 2026-02-15
Exam Type: Diagnostic Bilateral Mammography with Tomosynthesis
Indication: Abnormal screening mammogram, palpable right breast mass

TECHNIQUE:
Digital mammography with tomosynthesis performed in standard CC and MLO projections.
Additional spot compression and magnification views of right breast.

BREAST COMPOSITION:
Heterogeneously dense breast tissue (BI-RADS Density Category C)
This may lower the sensitivity of mammography.

FINDINGS:

RIGHT BREAST:
- Upper outer quadrant: 2.8 cm spiculated mass with irregular margins
- Location: 10 o'clock position, 5 cm from nipple
- Associated architectural distortion
- No associated calcifications
- Skin thickening overlying the mass
- No nipple retraction

LEFT BREAST:
- No suspicious masses, calcifications, or architectural distortion
- Scattered fibroglandular densities

AXILLARY LYMPH NODES:
- Right axilla: Enlarged lymph node measuring 1.2 cm, cortical thickening noted
- Left axilla: Normal appearing lymph nodes

COMPARISON:
Compared to prior mammogram dated 2025-02-10:
- New spiculated mass in right breast upper outer quadrant
- Previously normal breast tissue bilaterally

IMPRESSION:
1. Spiculated mass in right breast upper outer quadrant measuring 2.8 cm
   BI-RADS Category 5: HIGHLY SUGGESTIVE OF MALIGNANCY
   
2. Suspicious right axillary lymphadenopathy

3. Heterogeneously dense breast tissue may obscure small lesions

RECOMMENDATION:
- URGENT: Core needle biopsy of right breast mass
- Ultrasound-guided biopsy of right axillary lymph node
- Breast MRI for extent of disease evaluation
- Immediate referral to breast surgical oncology

RADIOLOGIST: Dr. Mehta, Breast Imaging
Report Date: 2026-02-15
                    """,
                },
                {
                    "id": "ONC-DOC004",
                    "type": "60568-3",  # Pathology Report
                    "content": """
SURGICAL PATHOLOGY REPORT

Patient: Pri** Ver** (ONC1002)
Specimen Collection Date: 2026-02-18
Report Date: 2026-02-22
Pathologist: Dr. Kumar, Surgical Pathology

SPECIMEN:
A. Right breast core needle biopsy, upper outer quadrant
B. Right axillary lymph node, fine needle aspiration

CLINICAL HISTORY:
44-year-old female with spiculated mass on mammography, BI-RADS 5

GROSS DESCRIPTION:
Specimen A: Four cores of tan-pink tissue, each measuring 1.5 cm in length
Specimen B: Cellular aspirate, air-dried and alcohol-fixed smears

MICROSCOPIC DESCRIPTION:

SPECIMEN A - RIGHT BREAST CORE BIOPSY:
Sections show invasive ductal carcinoma infiltrating breast parenchyma and adipose tissue.
Tumor cells arranged in irregular nests and cords with desmoplastic stromal reaction.
Tumor cells show moderate nuclear pleomorphism with vesicular nuclei and prominent nucleoli.
Mitotic figures: 8 per 10 high-power fields.
No lymphovascular invasion identified in the core samples.
Adjacent breast tissue shows usual ductal hyperplasia without atypia.

SPECIMEN B - RIGHT AXILLARY LYMPH NODE FNA:
Cellular aspirate showing metastatic adenocarcinoma consistent with breast primary.
Tumor cells present in clusters with overlapping nuclei and prominent nucleoli.

IMMUNOHISTOCHEMISTRY:
Estrogen Receptor (ER): POSITIVE (85% of tumor cells, strong intensity)
Progesterone Receptor (PR): POSITIVE (70% of tumor cells, moderate intensity)
HER2/neu: NEGATIVE (IHC score 1+, no amplification)
Ki-67 Proliferation Index: 18%
E-cadherin: POSITIVE (retained expression)
p53: Wild-type pattern (30% positive)

MOLECULAR CLASSIFICATION:
Luminal A subtype (ER+/PR+/HER2-/Ki-67 low-intermediate)

DIAGNOSIS:
A. RIGHT BREAST, UPPER OUTER QUADRANT, CORE NEEDLE BIOPSY:
   - INVASIVE DUCTAL CARCINOMA, GRADE 2 (Nottingham Score 6/9)
   - Tubule formation: 2, Nuclear pleomorphism: 2, Mitotic count: 2
   - Hormone receptor positive (ER+/PR+)
   - HER2 negative
   - Molecular subtype: Luminal A

B. RIGHT AXILLARY LYMPH NODE, FINE NEEDLE ASPIRATION:
   - POSITIVE FOR METASTATIC ADENOCARCINOMA
   - Consistent with breast primary

COMMENT:
The morphologic and immunohistochemical findings are consistent with invasive ductal 
carcinoma of breast origin. The tumor demonstrates favorable prognostic features including 
hormone receptor positivity and HER2 negativity. Oncotype DX testing is recommended to 
guide adjuvant chemotherapy decision-making in this premenopausal patient with node-positive 
disease. Genetic counseling and BRCA testing should be considered given patient age <50 years.

PATHOLOGIST: Dr. Rajesh Kumar, MD
Board Certified in Anatomic and Clinical Pathology
Subspecialty: Breast Pathology
                    """,
                },
            ],
            "ONC1003": [
                {
                    "id": "ONC1003-DOC001",
                    "type": "11488-4",  # Discharge Summary
                    "content": """
ONCOLOGY DISCHARGE SUMMARY

Patient: Sur*** Pat** (ONC1003)
Date of Birth: 1962-11-03
Age: 64 years
Gender: Male

Admission Date: 2026-02-15
Discharge Date: 2026-02-25

Chief Complaint: Abdominal pain and early satiety

Diagnosis:
Stage IIIA Gastric Adenocarcinoma
ICD-10 Code: C16.9 (Malignant neoplasm of stomach, unspecified)

Tumor Characteristics:
- Location: Gastric antrum
- Size: 4.5 cm ulcerative mass
- Depth: Invasion into muscularis propria
- Lymph Nodes: 4 of 18 nodes positive
- HER2 Status: Positive (IHC 3+)

Treatment Plan:
1. Neoadjuvant chemotherapy (FLOT regimen)
2. Subtotal gastrectomy with D2 lymphadenectomy
3. Adjuvant chemotherapy with Trastuzumab

Medications on Discharge:
- Fluorouracil, Leucovorin, Oxaliplatin, Docetaxel (FLOT)
- Trastuzumab 8mg/kg loading dose
- Pantoprazole 40mg daily
- Nutritional supplements

Prognosis: 5-year survival rate approximately 40-50% with multimodal therapy

Discharge Condition: Stable
                    """,
                },
                {
                    "id": "ONC1003-DOC002",
                    "type": "18842-5",  # Endoscopy Report
                    "content": """
UPPER GI ENDOSCOPY WITH BIOPSY

Patient: Sur*** Pat** (ONC1003)
Exam Date: 2026-02-15

FINDINGS:
- Gastric antrum: 4.5 cm ulcerative mass with irregular borders
- Biopsy: Adenocarcinoma, intestinal type, HER2 positive
- No gastric outlet obstruction

IMPRESSION:
Ulcerative gastric mass, biopsy-proven adenocarcinoma
Recommend staging CT and surgical consultation
                    """,
                },
            ],
            "ONC1004": [
                {
                    "id": "ONC1004-DOC001",
                    "type": "11488-4",  # Discharge Summary
                    "content": """
ONCOLOGY DISCHARGE SUMMARY

Patient: Arj** Sin** (ONC1004)
Date of Birth: 1990-05-18
Age: 36 years
Gender: Male

Admission Date: 2026-02-10
Discharge Date: 2026-02-22

Chief Complaint: Painless cervical lymphadenopathy and night sweats

Diagnosis:
Stage IIB Classical Hodgkin Lymphoma (Nodular Sclerosis subtype)
ICD-10 Code: C81.9 (Hodgkin lymphoma, unspecified)

Disease Characteristics:
- Involved Sites: Cervical, supraclavicular, mediastinal lymph nodes
- B Symptoms: Present (night sweats, weight loss)
- Bulky Disease: Mediastinal mass >10 cm
- Histology: Nodular sclerosis, Reed-Sternberg cells present

Treatment Plan:
1. ABVD chemotherapy (Adriamycin, Bleomycin, Vinblastine, Dacarbazine)
2. 6 cycles planned
3. Interim PET-CT after 2 cycles
4. Consider radiation therapy for residual disease

Medications on Discharge:
- ABVD chemotherapy regimen (scheduled)
- Ondansetron 8mg for nausea
- Filgrastim for neutropenia prevention
- Acyclovir prophylaxis

Prognosis: Excellent, 5-year survival rate >85% for Stage IIB

Discharge Condition: Stable
                    """,
                },
                {
                    "id": "ONC1004-DOC002",
                    "type": "18842-5",  # PET-CT Report
                    "content": """
PET-CT WHOLE BODY

Patient: Arj** Sin** (ONC1004)
Exam Date: 2026-02-10

FINDINGS:
- Cervical lymphadenopathy: Multiple FDG-avid nodes (SUVmax 8.5)
- Mediastinal mass: 12 cm bulky disease (SUVmax 12.3)
- No infradiaphragmatic involvement
- No bone marrow involvement

IMPRESSION:
Stage IIB Hodgkin Lymphoma with bulky mediastinal disease
Cervical and supraclavicular lymphadenopathy
                    """,
                },
            ],
            "ONC1005": [
                {
                    "id": "ONC1005-DOC001",
                    "type": "11488-4",  # Discharge Summary
                    "content": """
ONCOLOGY DISCHARGE SUMMARY

Patient: Moh** Red** (ONC1005)
Date of Birth: 1958-09-27
Age: 68 years
Gender: Male

Admission Date: 2026-02-12
Discharge Date: 2026-02-24

Chief Complaint: Jaundice and abdominal pain

Diagnosis:
Stage III Pancreatic Adenocarcinoma
ICD-10 Code: C25.9 (Malignant neoplasm of pancreas, unspecified)

Tumor Characteristics:
- Location: Head of pancreas
- Size: 3.8 cm mass
- Vascular Involvement: Superior mesenteric vein encasement
- Lymph Nodes: Regional nodes positive
- CA 19-9: 850 U/mL (markedly elevated)

Treatment Plan:
1. Neoadjuvant FOLFIRINOX chemotherapy
2. Re-staging after 4 cycles
3. Consider Whipple procedure if resectable
4. Biliary stent placement for jaundice

Medications on Discharge:
- FOLFIRINOX chemotherapy (scheduled)
- Pancreatic enzyme replacement
- Pain management with opioids
- Anticoagulation for thrombosis prevention

Prognosis: 5-year survival rate approximately 10-15%

Discharge Condition: Stable with biliary stent
                    """,
                },
                {
                    "id": "ONC1005-DOC002",
                    "type": "18842-5",  # CT Abdomen Report
                    "content": """
CT ABDOMEN AND PELVIS WITH CONTRAST

Patient: Moh** Red** (ONC1005)
Exam Date: 2026-02-12

FINDINGS:
- Pancreatic head: 3.8 cm hypodense mass
- Superior mesenteric vein: >180° encasement (unresectable)
- Biliary dilatation: Common bile duct 12 mm
- Regional lymphadenopathy present
- No distant metastases

IMPRESSION:
Mass in pancreatic head with vascular involvement
Borderline resectable/locally advanced pancreatic cancer
                    """,
                },
            ],
            "ONC1006": [
                {
                    "id": "ONC1006-DOC001",
                    "type": "11488-4",  # Discharge Summary
                    "content": """
ONCOLOGY DISCHARGE SUMMARY

Patient: Lak*** Iye* (ONC1006)
Date of Birth: 1979-01-14
Age: 47 years
Gender: Female

Admission Date: 2026-02-14
Discharge Date: 2026-02-26

Chief Complaint: Abnormal vaginal bleeding and pelvic pain

Diagnosis:
Stage IIB Cervical Squamous Cell Carcinoma
ICD-10 Code: C53.9 (Malignant neoplasm of cervix uteri, unspecified)

Tumor Characteristics:
- Size: 4.2 cm cervical mass
- Parametrial Invasion: Present (Stage IIB)
- Lymph Nodes: Pelvic nodes negative
- HPV Status: HPV 16 positive
- Histology: Squamous cell carcinoma, moderately differentiated

Treatment Plan:
1. Concurrent chemoradiation therapy
2. External beam radiation + brachytherapy
3. Weekly Cisplatin chemotherapy
4. HPV vaccination for family members

Medications on Discharge:
- Cisplatin 40mg/m² weekly during radiation
- Ondansetron for nausea
- Pain management
- Vaginal dilators post-treatment

Prognosis: 5-year survival rate approximately 65-70%

Discharge Condition: Stable
                    """,
                },
                {
                    "id": "ONC1006-DOC002",
                    "type": "18842-5",  # MRI Pelvis Report
                    "content": """
MRI PELVIS WITH CONTRAST

Patient: Lak*** Iye* (ONC1006)
Exam Date: 2026-02-14

FINDINGS:
- Cervix: 4.2 cm heterogeneous mass
- Parametrial invasion: Present bilaterally
- Pelvic lymph nodes: No significant enlargement
- No bladder or rectal invasion
- No distant metastases

IMPRESSION:
Stage IIB cervical carcinoma with parametrial invasion
No evidence of nodal or distant metastases
                    """,
                },
            ],
            "ONC1007": [
                {
                    "id": "ONC1007-DOC001",
                    "type": "11488-4",  # Discharge Summary
                    "content": """
ONCOLOGY DISCHARGE SUMMARY

Patient: Vij** Des**** (ONC1007)
Date of Birth: 1965-08-30
Age: 61 years
Gender: Male

Admission Date: 2026-02-16
Discharge Date: 2026-02-28

Chief Complaint: Non-healing oral ulcer and difficulty swallowing

Diagnosis:
Stage II Oral Cavity Squamous Cell Carcinoma
ICD-10 Code: C06.9 (Malignant neoplasm of mouth, unspecified)

Tumor Characteristics:
- Location: Left buccal mucosa
- Size: 3.5 cm ulcerative lesion
- Depth of Invasion: 8 mm
- Lymph Nodes: 1 ipsilateral node positive
- Risk Factors: Tobacco chewing (20 years)

Treatment Plan:
1. Wide local excision with neck dissection
2. Adjuvant radiation therapy
3. Speech and swallowing rehabilitation
4. Tobacco cessation counseling

Medications on Discharge:
- Pain management with opioids
- Antibiotics for infection prevention
- Nutritional supplements
- Oral care products

Prognosis: 5-year survival rate approximately 60-70%

Discharge Condition: Post-operative, stable
                    """,
                },
                {
                    "id": "ONC1007-DOC002",
                    "type": "18842-5",  # CT Oral Cavity Report
                    "content": """
CT ORAL CAVITY AND NECK WITH CONTRAST

Patient: Vij** Des**** (ONC1007)
Exam Date: 2026-02-16

FINDINGS:
- Left buccal mucosa: 3.5 cm enhancing mass
- Mandibular involvement: Superficial cortical erosion
- Left level II lymph node: 1.8 cm, suspicious
- No distant metastases

IMPRESSION:
Oral cavity mass with mandibular involvement
Suspicious ipsilateral cervical lymphadenopathy
                    """,
                },
            ],
            "ONC1008": [
                {
                    "id": "ONC1008-DOC001",
                    "type": "11488-4",  # Discharge Summary
                    "content": """
ONCOLOGY DISCHARGE SUMMARY

Patient: Anj*** Sha*** (ONC1008)
Date of Birth: 1988-04-09
Age: 38 years
Gender: Female

Admission Date: 2026-02-19
Discharge Date: 2026-02-27

Chief Complaint: Changing mole on back

Diagnosis:
Stage IIC Cutaneous Melanoma
ICD-10 Code: C43.9 (Malignant melanoma of skin, unspecified)

Tumor Characteristics:
- Location: Upper back
- Breslow Thickness: 3.2 mm (thick melanoma)
- Ulceration: Present
- Mitotic Rate: 8 per mm²
- Lymph Nodes: Sentinel node negative
- BRAF Status: BRAF V600E mutation positive

Treatment Plan:
1. Wide local excision (2 cm margins)
2. Adjuvant immunotherapy with Nivolumab
3. Regular skin surveillance
4. Sun protection counseling

Medications on Discharge:
- Nivolumab 240mg IV every 2 weeks (1 year)
- Topical wound care
- Sunscreen SPF 50+

Prognosis: 5-year survival rate approximately 50-60% for Stage IIC

Discharge Condition: Post-operative, stable
                    """,
                },
                {
                    "id": "ONC1008-DOC002",
                    "type": "18842-5",  # Dermoscopy Report
                    "content": """
DERMOSCOPY AND BIOPSY REPORT

Patient: Anj*** Sha*** (ONC1008)
Exam Date: 2026-02-19

FINDINGS:
- Location: Upper back, 8 cm left of midline
- Size: 1.8 cm pigmented lesion
- Dermoscopy: Asymmetry, irregular borders, color variation
- Biopsy: Melanoma, Breslow 3.2 mm, ulcerated
- BRAF V600E mutation: Positive

IMPRESSION:
Thick melanoma with ulceration (Stage IIC)
Sentinel lymph node biopsy negative
BRAF mutation positive - eligible for targeted therapy
                    """,
                },
            ],
            "ONC1009": [
                {
                    "id": "ONC1009-DOC001",
                    "type": "11488-4",  # Discharge Summary
                    "content": """
ONCOLOGY DISCHARGE SUMMARY

Patient: Ram*** Gup** (ONC1009)
Date of Birth: 1972-12-01
Age: 54 years
Gender: Male

Admission Date: 2026-02-17
Discharge Date: 2026-02-26

Chief Complaint: Painless hematuria

Diagnosis:
Stage II Urothelial Carcinoma of Bladder
ICD-10 Code: C67.9 (Malignant neoplasm of bladder, unspecified)

Tumor Characteristics:
- Location: Lateral bladder wall
- Size: 3.5 cm papillary tumor
- Grade: High-grade urothelial carcinoma
- Muscle Invasion: Invading muscularis propria (T2)
- Lymph Nodes: Negative
- Risk Factors: Smoking history

Treatment Plan:
1. Radical cystectomy with ileal conduit
2. Neoadjuvant chemotherapy (MVAC regimen)
3. Urinary diversion management
4. Smoking cessation

Medications on Discharge:
- Methotrexate, Vinblastine, Adriamycin, Cisplatin (MVAC)
- Ondansetron for nausea
- Urinary care supplies

Prognosis: 5-year survival rate approximately 60-70% with cystectomy

Discharge Condition: Stable
                    """,
                },
                {
                    "id": "ONC1009-DOC002",
                    "type": "18842-5",  # Cystoscopy Report
                    "content": """
CYSTOSCOPY WITH BIOPSY

Patient: Ram*** Gup** (ONC1009)
Exam Date: 2026-02-17

FINDINGS:
- Lateral bladder wall: 3.5 cm papillary tumor
- Biopsy: High-grade urothelial carcinoma
- Muscle invasion: Present (T2 stage)
- No carcinoma in situ identified
- Upper tracts: Normal

IMPRESSION:
Muscle-invasive bladder tumor
High-grade urothelial carcinoma
Recommend radical cystectomy after neoadjuvant chemotherapy
                    """,
                },
            ],
            "ONC1010": [
                {
                    "id": "ONC1010-DOC001",
                    "type": "11488-4",  # Discharge Summary
                    "content": """
ONCOLOGY DISCHARGE SUMMARY

Patient: Kri**** Nai* (ONC1010)
Date of Birth: 1955-06-22
Age: 71 years
Gender: Male

Admission Date: 2026-02-13
Discharge Date: 2026-02-25

Chief Complaint: Elevated PSA and urinary symptoms

Diagnosis:
Stage III Prostate Adenocarcinoma
ICD-10 Code: C61 (Malignant neoplasm of prostate)

Tumor Characteristics:
- Gleason Score: 4+4=8 (Grade Group 4)
- PSA: 45 ng/mL (markedly elevated)
- Clinical Stage: T3a (extraprostatic extension)
- Lymph Nodes: Regional nodes positive
- Bone Scan: No metastases

Treatment Plan:
1. Androgen deprivation therapy (ADT)
2. External beam radiation therapy
3. Consider radical prostatectomy if downstaging occurs
4. Long-term hormone therapy

Medications on Discharge:
- Leuprolide 22.5mg IM every 3 months
- Bicalutamide 50mg daily
- Finasteride 5mg daily
- Calcium and Vitamin D supplements

Prognosis: 5-year survival rate approximately 70-80% with multimodal therapy

Discharge Condition: Stable
                    """,
                },
                {
                    "id": "ONC1010-DOC002",
                    "type": "18842-5",  # MRI Prostate Report
                    "content": """
MRI PROSTATE WITH CONTRAST

Patient: Kri**** Nai* (ONC1010)
Exam Date: 2026-02-13

FINDINGS:
- Prostate: Enlarged, 65 cc volume
- PI-RADS 5 lesion: 2.8 cm in peripheral zone
- Extraprostatic extension: Present (T3a)
- Seminal vesicle invasion: Suspicious
- Pelvic lymph nodes: Enlarged (1.5 cm)

IMPRESSION:
High-risk prostate cancer with extraprostatic extension
PI-RADS 5 lesion, Gleason 4+4=8
Regional lymphadenopathy suspicious for metastases
                    """,
                },
            ],
        }
    
    def get_patient_bundle(self, patient_id: str) -> PatientBundle:
        """Return mock patient bundle with sample data."""
        bundle = PatientBundle()
        
        if patient_id not in self._sample_data:
            return bundle
        
        for doc_data in self._sample_data[patient_id]:
            doc_ref = FHIRDocumentReference(
                resource_type=FHIRResourceType.DOCUMENT_REFERENCE,
                id=doc_data["id"],
                patient_id=patient_id,
                type_code=doc_data["type"],
                type_display="Clinical Document",
                status="current",
                content=doc_data["content"],
                created=datetime.now(),
                raw_data={}
            )
            bundle.document_references.append(doc_ref)
        
        return bundle


def print_separator(char="=", length=80):
    """Print a separator line."""
    print(char * length)


def print_section_header(title: str):
    """Print a section header."""
    print_separator()
    print(f"  {title}")
    print_separator()
    print()


def demo_clinical_summarizer():
    """Demonstrate the Clinical_Summarizer component."""
    print("\n")
    print_separator("=")
    print("  CLINICAL AI CAPABILITIES - DEMO APPLICATION")
    print_separator("=")
    print()
    
    # Initialize services
    print("Initializing Clinical AI services...")
    mock_fhir = MockFHIRAdapterDemo()
    ontology_service = OntologyGroundingService()
    explainability_generator = ExplainabilityGenerator()
    
    summarizer = ClinicalSummarizer(
        fhir_adapter=mock_fhir,
        ontology_service=ontology_service,
        explainability_generator=explainability_generator
    )
    print("✓ Services initialized\n")
    
    # Create summarizer input
    print_section_header("PATIENT INFORMATION")
    patient_id = "P12345"
    print(f"Patient ID: {patient_id}")
    print(f"Patient Name: John Doe (Sample Patient)")
    print(f"Documents: Discharge Summary, Lab Report, Radiology Report")
    print()
    
    input_data = SummarizerInput(
        patient_id=patient_id,
        document_ids=["DOC001", "DOC002", "DOC003"],
        document_types=[
            DocumentType.DISCHARGE_SUMMARY,
            DocumentType.LAB_REPORT,
            DocumentType.RADIOLOGY_REPORT,
        ],
        language=Language.ENGLISH,
        summary_type=SummaryType.CLINICIAN
    )
    
    # Generate summary
    print_section_header("GENERATING PATIENT SUMMARY")
    print("Processing clinical documents...")
    print("- Retrieving documents from EMR")
    print("- Extracting clinical information")
    print("- Grounding medical terms to ontologies")
    print("- Generating patient snapshot")
    print("- Creating explainability report")
    print()
    
    output = summarizer.generate_summary(input_data)
    
    print(f"✓ Summary generated in {output.generation_time_ms}ms\n")
    
    # Display patient snapshot
    print_section_header("PATIENT SNAPSHOT")
    snapshot = output.patient_snapshot
    
    if snapshot.key_complaints:
        print("CHIEF COMPLAINTS:")
        for complaint in snapshot.key_complaints:
            print(f"  • {complaint}")
        print()
    
    if snapshot.past_medical_history:
        print("PAST MEDICAL HISTORY:")
        for history in snapshot.past_medical_history:
            print(f"  • {history}")
        print()
    
    if snapshot.current_medications:
        print("CURRENT MEDICATIONS:")
        for med in snapshot.current_medications:
            print(f"  • {med.name} - {med.dosage} ({med.frequency})")
        print()
    
    if snapshot.abnormal_findings:
        print("ABNORMAL FINDINGS:")
        for finding in snapshot.abnormal_findings:
            print(f"  • {finding.description}")
            print(f"    Source: {finding.source} | Severity: {finding.severity}")
        print()
    
    if snapshot.pending_actions:
        print("PENDING ACTIONS:")
        for action in snapshot.pending_actions:
            print(f"  • {action.description} (Priority: {action.priority})")
        print()
    
    print_section_header("SUMMARY TEXT")
    print(snapshot.summary_text)
    print()
    
    # Display explainability
    print_section_header("EXPLAINABILITY REPORT")
    report = output.explainability_report
    
    print(f"Component: {report.component}")
    print(f"Confidence Level: {report.confidence_level:.2%}")
    print(f"Confidence Interval: ({report.confidence_interval[0]:.2%}, {report.confidence_interval[1]:.2%})")
    print(f"Human Review Required: {'Yes' if report.human_review_required else 'No'}")
    print()
    
    print("REASONING STEPS:")
    for step in report.reasoning_steps:
        print(f"  {step.step_number}. {step.description}")
        print(f"     Confidence: {step.confidence:.2%}")
        if step.evidence:
            print(f"     Evidence: {', '.join(str(e) for e in step.evidence[:3])}")
    print()
    
    if report.limitations:
        print("LIMITATIONS:")
        for limitation in report.limitations:
            print(f"  • {limitation}")
        print()
    
    # Display warnings
    if output.warnings:
        print_section_header("WARNINGS")
        for warning in output.warnings:
            print(f"  ⚠ {warning}")
        print()
    
    # Display statistics
    print_section_header("SUMMARY STATISTICS")
    print(f"Generation Time: {output.generation_time_ms}ms")
    print(f"Summary Length: {len(snapshot.summary_text)} characters")
    print(f"Summary Lines: {snapshot.summary_text.count(chr(10)) + 1}")
    print(f"Complaints Identified: {len(snapshot.key_complaints)}")
    print(f"Medications Listed: {len(snapshot.current_medications)}")
    print(f"Findings Detected: {len(snapshot.abnormal_findings)}")
    print(f"Actions Pending: {len(snapshot.pending_actions)}")
    print(f"Warnings: {len(output.warnings)}")
    print()
    
    print_separator("=")
    print("  DEMO COMPLETED SUCCESSFULLY")
    print_separator("=")
    print()


def main():
    """Main entry point for demo application."""
    try:
        demo_clinical_summarizer()
        return 0
    except KeyboardInterrupt:
        print("\n\nDemo interrupted by user.")
        return 1
    except Exception as e:
        print(f"\n\nERROR: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
