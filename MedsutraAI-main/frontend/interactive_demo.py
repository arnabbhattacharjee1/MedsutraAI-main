"""
Interactive Clinical AI Demo

An interactive command-line interface to explore the Clinical AI capabilities.
"""

import sys
from datetime import datetime

from src.models.clinical_document import DocumentType
from src.models.summarizer import SummarizerInput, SummaryType
from src.models.patient import Language
from src.services.clinical_summarizer import ClinicalSummarizer
from src.services.ontology_grounding import OntologyGroundingService
from src.services.explainability_generator import ExplainabilityGenerator
from src.models.ontology import OntologyGroundingInput

# Import the mock FHIR adapter from demo_app
from demo_app import MockFHIRAdapterDemo


def print_menu():
    """Print the main menu."""
    print("\n" + "=" * 60)
    print("  CLINICAL AI CAPABILITIES - INTERACTIVE DEMO")
    print("=" * 60)
    print("\nAvailable Demos:")
    print("  1. Clinical Summarizer - Generate patient summary")
    print("  2. Ontology Grounding - Ground medical terms")
    print("  3. Explainability - View AI reasoning")
    print("  4. View Sample Patient Data")
    print("  0. Exit")
    print()


def demo_summarizer():
    """Interactive Clinical Summarizer demo."""
    print("\n" + "=" * 60)
    print("  CLINICAL SUMMARIZER DEMO")
    print("=" * 60)
    
    # Initialize services
    print("\nInitializing services...")
    mock_fhir = MockFHIRAdapterDemo()
    summarizer = ClinicalSummarizer(
        fhir_adapter=mock_fhir,
        ontology_service=OntologyGroundingService(),
        explainability_generator=ExplainabilityGenerator()
    )
    
    # Get patient ID
    patient_id = input("\nEnter Patient ID (default: P12345): ").strip() or "P12345"
    
    # Select language
    print("\nSelect Language:")
    print("  1. English")
    print("  2. Hindi")
    print("  3. Regional")
    lang_choice = input("Choice (default: 1): ").strip() or "1"
    
    language_map = {
        "1": Language.ENGLISH,
        "2": Language.HINDI,
        "3": Language.REGIONAL,
    }
    language = language_map.get(lang_choice, Language.ENGLISH)
    
    # Select summary type
    print("\nSelect Summary Type:")
    print("  1. Clinician (Technical)")
    print("  2. Patient-Friendly")
    type_choice = input("Choice (default: 1): ").strip() or "1"
    
    summary_type = SummaryType.CLINICIAN if type_choice == "1" else SummaryType.PATIENT_FRIENDLY
    
    # Create input
    input_data = SummarizerInput(
        patient_id=patient_id,
        document_ids=["DOC001", "DOC002", "DOC003"],
        document_types=[
            DocumentType.DISCHARGE_SUMMARY,
            DocumentType.LAB_REPORT,
            DocumentType.RADIOLOGY_REPORT,
        ],
        language=language,
        summary_type=summary_type
    )
    
    # Generate summary
    print("\nGenerating summary...")
    output = summarizer.generate_summary(input_data)
    
    print(f"\n✓ Summary generated in {output.generation_time_ms}ms")
    
    # Display results
    print("\n" + "-" * 60)
    print("PATIENT SNAPSHOT")
    print("-" * 60)
    print(output.patient_snapshot.summary_text)
    
    print("\n" + "-" * 60)
    print("STATISTICS")
    print("-" * 60)
    print(f"Complaints: {len(output.patient_snapshot.key_complaints)}")
    print(f"Medications: {len(output.patient_snapshot.current_medications)}")
    print(f"Findings: {len(output.patient_snapshot.abnormal_findings)}")
    print(f"Actions: {len(output.patient_snapshot.pending_actions)}")
    print(f"Confidence: {output.explainability_report.confidence_level:.2%}")
    
    if output.warnings:
        print("\n" + "-" * 60)
        print("WARNINGS")
        print("-" * 60)
        for warning in output.warnings[:5]:
            print(f"  ⚠ {warning}")
    
    input("\nPress Enter to continue...")


def demo_ontology():
    """Interactive Ontology Grounding demo."""
    print("\n" + "=" * 60)
    print("  ONTOLOGY GROUNDING DEMO")
    print("=" * 60)
    
    service = OntologyGroundingService()
    
    while True:
        term = input("\nEnter medical term (or 'back' to return): ").strip()
        
        if term.lower() == 'back':
            break
        
        if not term:
            continue
        
        print("\nSelect Ontology:")
        print("  1. SNOMED CT")
        print("  2. ICD-10")
        print("  3. LOINC")
        print("  4. RxNorm")
        ontology_choice = input("Choice (default: 1): ").strip() or "1"
        
        ontology_map = {
            "1": "SNOMED_CT",
            "2": "ICD_10",
            "3": "LOINC",
            "4": "RXNORM",
        }
        ontology = ontology_map.get(ontology_choice, "SNOMED_CT")
        
        # Ground term
        input_data = OntologyGroundingInput(
            term=term,
            context="",
            ontology=ontology
        )
        
        result = service.ground_term(input_data)
        
        print("\n" + "-" * 60)
        print("GROUNDING RESULT")
        print("-" * 60)
        print(f"Term: {term}")
        print(f"Ontology: {ontology}")
        print(f"Grounded: {'Yes' if result.grounded else 'No'}")
        
        if result.grounded:
            print(f"Code: {result.code}")
            print(f"Display: {result.display}")
            print(f"Confidence: {result.confidence:.2%}")
        
        if result.alternatives:
            print("\nAlternatives:")
            for alt in result.alternatives[:3]:
                print(f"  • {alt['display']} ({alt['code']}) - {alt['confidence']:.2%}")


def demo_explainability():
    """Interactive Explainability demo."""
    print("\n" + "=" * 60)
    print("  EXPLAINABILITY DEMO")
    print("=" * 60)
    
    generator = ExplainabilityGenerator()
    
    # Create sample report
    report = generator.generate_report(
        component="Clinical_Summarizer",
        input_summary="3 clinical documents for patient P12345",
        output_summary="Patient snapshot with key findings",
        reasoning_steps=[
            {
                "description": "Retrieved clinical documents from EMR",
                "evidence": ["Discharge Summary", "Lab Report", "Radiology Report"],
                "confidence": 0.95
            },
            {
                "description": "Extracted medical information using NLP",
                "evidence": ["Chest pain", "Elevated troponin", "Cardiomegaly"],
                "confidence": 0.88
            },
            {
                "description": "Grounded medical terms to SNOMED CT",
                "evidence": ["Myocardial infarction", "Hypertension", "Diabetes"],
                "confidence": 0.92
            },
        ],
        evidence_sources=[
            {
                "source_type": "EMR_Note",
                "source_id": "DOC001",
                "excerpt": "Patient presented with chest pain...",
                "weight": 0.9
            }
        ],
        confidence_level=0.88,
        confidence_interval=(0.82, 0.94),
        limitations=["Using mock LLM", "Limited medical term extraction"],
        human_review_required=True
    )
    
    print("\n" + "-" * 60)
    print("EXPLAINABILITY REPORT")
    print("-" * 60)
    print(f"\nComponent: {report.component}")
    print(f"Timestamp: {report.timestamp}")
    print(f"Confidence: {report.confidence_level:.2%}")
    print(f"Confidence Interval: ({report.confidence_interval[0]:.2%}, {report.confidence_interval[1]:.2%})")
    
    print("\nReasoning Steps:")
    for step in report.reasoning_steps:
        print(f"\n  Step {step.step_number}: {step.description}")
        print(f"  Confidence: {step.confidence:.2%}")
        if step.evidence:
            print(f"  Evidence: {', '.join(str(e) for e in step.evidence)}")
    
    print("\nEvidence Sources:")
    for source in report.evidence_sources:
        print(f"\n  Type: {source.source_type}")
        print(f"  ID: {source.source_id}")
        print(f"  Excerpt: {source.excerpt[:50]}...")
        print(f"  Weight: {source.weight:.2f}")
    
    print("\nLimitations:")
    for limitation in report.limitations:
        print(f"  • {limitation}")
    
    print(f"\nHuman Review Required: {'Yes' if report.human_review_required else 'No'}")
    
    input("\nPress Enter to continue...")


def view_sample_data():
    """View sample patient data."""
    print("\n" + "=" * 60)
    print("  SAMPLE PATIENT DATA")
    print("=" * 60)
    
    print("\nPatient ID: P12345")
    print("Patient Name: John Doe (Sample Patient)")
    print("\nAvailable Documents:")
    print("  1. Discharge Summary (DOC001)")
    print("  2. Laboratory Report (DOC002)")
    print("  3. Radiology Report (DOC003)")
    
    choice = input("\nSelect document to view (1-3, or 'back'): ").strip()
    
    if choice == 'back':
        return
    
    mock_fhir = MockFHIRAdapterDemo()
    bundle = mock_fhir.get_patient_bundle("P12345")
    
    doc_map = {
        "1": 0,
        "2": 1,
        "3": 2,
    }
    
    if choice in doc_map:
        doc = bundle.document_references[doc_map[choice]]
        print("\n" + "-" * 60)
        print(f"DOCUMENT: {doc.id}")
        print("-" * 60)
        print(doc.content)
    
    input("\nPress Enter to continue...")


def main():
    """Main entry point for interactive demo."""
    while True:
        try:
            print_menu()
            choice = input("Select option: ").strip()
            
            if choice == "0":
                print("\nThank you for using Clinical AI Capabilities Demo!")
                break
            elif choice == "1":
                demo_summarizer()
            elif choice == "2":
                demo_ontology()
            elif choice == "3":
                demo_explainability()
            elif choice == "4":
                view_sample_data()
            else:
                print("\nInvalid choice. Please try again.")
        
        except KeyboardInterrupt:
            print("\n\nDemo interrupted by user.")
            break
        except Exception as e:
            print(f"\n\nERROR: {e}")
            import traceback
            traceback.print_exc()
            input("\nPress Enter to continue...")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
