"""
Simple Web Interface for Clinical AI Demo

A lightweight Flask-based web interface to demonstrate Clinical AI capabilities.
"""

try:
    from flask import Flask, render_template, request, jsonify
    FLASK_AVAILABLE = True
except ImportError:
    FLASK_AVAILABLE = False
    print("Flask not installed. Install with: pip install flask")

import json
from datetime import datetime

from src.models.clinical_document import DocumentType
from src.models.summarizer import SummarizerInput, SummaryType
from src.models.patient import Language
from src.services.clinical_summarizer import ClinicalSummarizer
from src.services.ontology_grounding import OntologyGroundingService
from src.services.explainability_generator import ExplainabilityGenerator
from src.models.ontology import OntologyGroundingInput
from demo_app import MockFHIRAdapterDemo


if FLASK_AVAILABLE:
    app = Flask(__name__)
    
    # Initialize services
    mock_fhir = MockFHIRAdapterDemo()
    summarizer = ClinicalSummarizer(
        fhir_adapter=mock_fhir,
        ontology_service=OntologyGroundingService(),
        explainability_generator=ExplainabilityGenerator()
    )
    ontology_service = OntologyGroundingService()
    
    
    @app.route('/')
    def index():
        """Serve the main page."""
        return render_template('index.html')
    
    
    @app.route('/api/summarize', methods=['POST'])
    def api_summarize():
        """Generate patient summary."""
        try:
            data = request.json
            patient_id = data.get('patient_id', 'P12345')
            language = Language[data.get('language', 'ENGLISH')]
            summary_type = SummaryType[data.get('summary_type', 'CLINICIAN')]
            
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
            
            output = summarizer.generate_summary(input_data)
            
            return jsonify({
                'success': True,
                'patient_snapshot': {
                    'key_complaints': output.patient_snapshot.key_complaints,
                    'past_medical_history': output.patient_snapshot.past_medical_history,
                    'current_medications': [
                        {
                            'name': m.name,
                            'dosage': m.dosage,
                            'frequency': m.frequency
                        }
                        for m in output.patient_snapshot.current_medications
                    ],
                    'abnormal_findings': [
                        {
                            'description': f.description,
                            'source': f.source,
                            'severity': f.severity
                        }
                        for f in output.patient_snapshot.abnormal_findings
                    ],
                    'pending_actions': [
                        {
                            'description': a.description,
                            'priority': a.priority
                        }
                        for a in output.patient_snapshot.pending_actions
                    ],
                    'summary_text': output.patient_snapshot.summary_text,
                },
                'explainability': {
                    'confidence_level': output.explainability_report.confidence_level,
                    'confidence_interval': output.explainability_report.confidence_interval,
                    'reasoning_steps': [
                        {
                            'step_number': s.step_number,
                            'description': s.description,
                            'confidence': s.confidence,
                            'evidence': s.evidence[:3]
                        }
                        for s in output.explainability_report.reasoning_steps
                    ],
                    'limitations': output.explainability_report.limitations,
                    'human_review_required': output.explainability_report.human_review_required,
                },
                'generation_time_ms': output.generation_time_ms,
                'warnings': output.warnings[:5],
            })
        
        except Exception as e:
            return jsonify({
                'success': False,
                'error': str(e)
            }), 500
    
    
    @app.route('/api/ground_term', methods=['POST'])
    def api_ground_term():
        """Ground a medical term."""
        try:
            data = request.json
            term = data.get('term', '')
            ontology = data.get('ontology', 'SNOMED_CT')
            
            input_data = OntologyGroundingInput(
                term=term,
                context="",
                ontology=ontology
            )
            
            result = ontology_service.ground_term(input_data)
            
            return jsonify({
                'success': True,
                'grounded': result.grounded,
                'code': result.code,
                'display': result.display,
                'confidence': result.confidence,
                'alternatives': result.alternatives[:5],
            })
        
        except Exception as e:
            return jsonify({
                'success': False,
                'error': str(e)
            }), 500
    
    
    @app.route('/api/patient_data', methods=['GET'])
    def api_patient_data():
        """Get sample patient data."""
        try:
            patient_id = request.args.get('patient_id', 'P12345')
            bundle = mock_fhir.get_patient_bundle(patient_id)
            
            # Get patient name based on ID
            patient_names = {
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
            }
            
            documents = [
                {
                    'id': doc.id,
                    'type': doc.type_display,
                    'content': doc.content,
                    'created': doc.created.isoformat() if doc.created else None,
                }
                for doc in bundle.document_references
            ]
            
            return jsonify({
                'success': True,
                'patient_id': patient_id,
                'patient_name': patient_names.get(patient_id, 'Unknown Patient'),
                'documents': documents,
            })
        
        except Exception as e:
            return jsonify({
                'success': False,
                'error': str(e)
            }), 500


def main():
    """Run the web application."""
    if not FLASK_AVAILABLE:
        print("\nFlask is required to run the web demo.")
        print("Install it with: pip install flask")
        print("\nAlternatively, use the CLI demos:")
        print("  python demo_app.py")
        print("  python interactive_demo.py")
        return 1
    
    print("\n" + "=" * 60)
    print("  CLINICAL AI WEB DEMO")
    print("=" * 60)
    print("\nStarting web server...")
    print("Open your browser to: http://localhost:5000")
    print("\nPress Ctrl+C to stop the server")
    print("=" * 60 + "\n")
    
    app.run(debug=True, host='0.0.0.0', port=5000)
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
