"""Clinical summarizer service for generating patient summaries."""

import time
import re
from typing import List, Dict, Any, Optional

from src.models.summarizer import (
    SummarizerInput,
    SummarizerOutput,
    PatientSnapshot,
    Medication,
    Finding,
    Action,
    SummaryType,
)
from src.models.clinical_document import DocumentType, ClinicalDocument
from src.models.patient import Language
from src.models.ontology import OntologyGroundingInput
from src.services.fhir_adapter import FHIRAdapter
from src.services.ontology_grounding import OntologyGroundingService
from src.services.explainability_generator import ExplainabilityGenerator
from src.utils.logger import get_logger

logger = get_logger(__name__)


class ClinicalSummarizerError(Exception):
    """Base exception for clinical summarizer errors."""

    pass


class ClinicalSummarizer:
    """Service for generating clinical patient summaries.

    Processes clinical documents to generate concise patient summaries with
    ontology grounding, explainability, and one-page constraint validation.
    """

    # Maximum summary constraints
    MAX_CHARS = 3000
    MAX_LINES = 60
    MAX_LATENCY_MS = 30000  # 30 seconds

    def __init__(
        self,
        fhir_adapter: Optional[FHIRAdapter] = None,
        ontology_service: Optional[OntologyGroundingService] = None,
        explainability_generator: Optional[ExplainabilityGenerator] = None,
    ):
        """Initialize Clinical_Summarizer.

        Args:
            fhir_adapter: FHIR adapter for EMR connectivity
            ontology_service: Ontology grounding service
            explainability_generator: Explainability report generator
        """
        self.fhir_adapter = fhir_adapter or FHIRAdapter()
        self.ontology_service = ontology_service or OntologyGroundingService()
        self.explainability_generator = (
            explainability_generator or ExplainabilityGenerator()
        )

        logger.info("ClinicalSummarizer initialized")

    def generate_summary(self, input_data: SummarizerInput) -> SummarizerOutput:
        """Generate patient summary from clinical documents.

        Args:
            input_data: Summarizer input with patient ID and document specifications

        Returns:
            SummarizerOutput with patient snapshot and explainability

        Raises:
            ClinicalSummarizerError: If summary generation fails
        """
        start_time = time.time()
        logger.info(
            f"Generating summary for patient {input_data.patient_id}",
            extra={
                "patient_id": input_data.patient_id,
                "document_count": len(input_data.document_ids),
                "language": input_data.language,
            },
        )

        warnings = []

        try:
            # Step 1: Retrieve documents from EMR
            documents = self._retrieve_documents(
                input_data.patient_id, input_data.document_ids, input_data.document_types
            )

            if not documents:
                warnings.append("No documents found for patient")

            # Step 2: Extract text from documents
            extracted_texts = self._extract_text_from_documents(documents)

            # Step 3: Ground medical terms
            grounded_terms, ungrounded_terms = self._ground_medical_terms(extracted_texts)

            if ungrounded_terms:
                warnings.extend(
                    [f"Ungrounded term: {term}" for term in ungrounded_terms[:5]]
                )

            # Step 4: Generate patient snapshot using mock LLM
            patient_snapshot = self._generate_patient_snapshot(
                extracted_texts, input_data.language, input_data.summary_type
            )

            # Step 5: Validate one-page constraint
            constraint_violations = self._validate_one_page_constraint(patient_snapshot)
            if constraint_violations:
                warnings.extend(constraint_violations)

            # Step 6: Generate explainability report
            generation_time_ms = int((time.time() - start_time) * 1000)

            explainability_report = self._generate_explainability_report(
                input_data, documents, patient_snapshot, grounded_terms, generation_time_ms
            )

            # Step 7: Check latency requirement
            if generation_time_ms > self.MAX_LATENCY_MS:
                warnings.append(
                    f"Summary generation exceeded 30s latency requirement: {generation_time_ms}ms"
                )

            logger.info(
                f"Summary generated successfully for patient {input_data.patient_id}",
                extra={
                    "patient_id": input_data.patient_id,
                    "generation_time_ms": generation_time_ms,
                    "warnings_count": len(warnings),
                },
            )

            return SummarizerOutput(
                patient_snapshot=patient_snapshot,
                explainability_report=explainability_report,
                generation_time_ms=generation_time_ms,
                warnings=warnings,
            )

        except Exception as e:
            logger.error(
                f"Failed to generate summary for patient {input_data.patient_id}",
                extra={"error": str(e)},
            )
            raise ClinicalSummarizerError(f"Summary generation failed: {e}")

    def _retrieve_documents(
        self,
        patient_id: str,
        document_ids: List[str],
        document_types: List[DocumentType],
    ) -> List[ClinicalDocument]:
        """Retrieve clinical documents from EMR via FHIR adapter.

        Args:
            patient_id: Patient identifier
            document_ids: List of document IDs to retrieve
            document_types: Types of documents to filter

        Returns:
            List of clinical documents
        """
        logger.debug(f"Retrieving documents for patient {patient_id}")

        try:
            # Get patient bundle from FHIR
            bundle = self.fhir_adapter.get_patient_bundle(patient_id)

            # Convert FHIR resources to ClinicalDocument objects
            documents = []

            # Process document references
            for doc_ref in bundle.document_references:
                # Map FHIR document type to our DocumentType
                doc_type = self._map_fhir_doc_type(doc_ref.type_code)

                if document_types and doc_type not in document_types:
                    continue

                if document_ids and doc_ref.id not in document_ids:
                    continue

                # Create ClinicalDocument from FHIR DocumentReference
                from src.models.clinical_document import Clinician
                from datetime import datetime

                doc = ClinicalDocument(
                    document_id=doc_ref.id,
                    patient_id=patient_id,
                    document_type=doc_type,
                    author=Clinician(
                        clinician_id="UNKNOWN", name="Unknown", role="UNKNOWN"
                    ),
                    created_at=doc_ref.created or datetime.now(),
                    content=doc_ref.content,
                    fhir_resource_type="DocumentReference",
                    fhir_resource_id=doc_ref.id,
                )
                documents.append(doc)

            # Process diagnostic reports (radiology reports)
            for diag_report in bundle.diagnostic_reports:
                doc_type = DocumentType.RADIOLOGY_REPORT

                if document_types and doc_type not in document_types:
                    continue

                if document_ids and diag_report.id not in document_ids:
                    continue

                from src.models.clinical_document import Clinician
                from datetime import datetime

                doc = ClinicalDocument(
                    document_id=diag_report.id,
                    patient_id=patient_id,
                    document_type=doc_type,
                    author=Clinician(
                        clinician_id="UNKNOWN", name="Unknown", role="RADIOLOGIST"
                    ),
                    created_at=diag_report.issued or datetime.now(),
                    content=diag_report.conclusion or "",
                    fhir_resource_type="DiagnosticReport",
                    fhir_resource_id=diag_report.id,
                )
                documents.append(doc)

            logger.debug(f"Retrieved {len(documents)} documents")
            return documents

        except Exception as e:
            logger.error(f"Failed to retrieve documents: {e}")
            return []

    def _map_fhir_doc_type(self, fhir_type_code: str) -> DocumentType:
        """Map FHIR document type code to our DocumentType enum.

        Args:
            fhir_type_code: FHIR document type code

        Returns:
            DocumentType enum value
        """
        # Simple mapping - in production, use proper LOINC/SNOMED mapping
        type_mapping = {
            "11488-4": DocumentType.DISCHARGE_SUMMARY,
            "34133-9": DocumentType.DISCHARGE_SUMMARY,
            "11506-3": DocumentType.REFERRAL_NOTE,
            "57133-1": DocumentType.REFERRAL_NOTE,
            "18842-5": DocumentType.RADIOLOGY_REPORT,
            "11525-3": DocumentType.LAB_REPORT,
            "11502-2": DocumentType.LAB_REPORT,
        }

        return type_mapping.get(fhir_type_code, DocumentType.EMR_NOTE)

    def _extract_text_from_documents(
        self, documents: List[ClinicalDocument]
    ) -> Dict[DocumentType, List[str]]:
        """Extract text content from clinical documents.

        Args:
            documents: List of clinical documents

        Returns:
            Dictionary mapping document types to extracted text lists
        """
        logger.debug(f"Extracting text from {len(documents)} documents")

        extracted_texts: Dict[DocumentType, List[str]] = {}

        for doc in documents:
            doc_type = doc.document_type

            if doc_type not in extracted_texts:
                extracted_texts[doc_type] = []

            # Extract text content
            text = doc.content.strip()

            if text:
                extracted_texts[doc_type].append(text)

        logger.debug(
            f"Extracted text from {len(extracted_texts)} document types",
            extra={"document_types": list(extracted_texts.keys())},
        )

        return extracted_texts

    def _ground_medical_terms(
        self, extracted_texts: Dict[DocumentType, List[str]]
    ) -> tuple[List[str], List[str]]:
        """Ground medical terms to clinical ontologies.

        Args:
            extracted_texts: Extracted text by document type

        Returns:
            Tuple of (grounded_terms, ungrounded_terms)
        """
        logger.debug("Grounding medical terms")

        grounded_terms = []
        ungrounded_terms = []

        # Combine all texts
        all_text = " ".join(
            [text for texts in extracted_texts.values() for text in texts]
        )

        # Extract potential medical terms (simple approach)
        # In production, use proper NER
        words = re.findall(r"\b[a-zA-Z]{3,}\b", all_text.lower())
        unique_words = list(set(words))

        # Ground terms to SNOMED CT
        for term in unique_words[:50]:  # Limit to first 50 unique terms
            input_data = OntologyGroundingInput(
                term=term, context="", ontology="SNOMED_CT"
            )

            result = self.ontology_service.ground_term(input_data)

            if result.grounded:
                grounded_terms.append(term)
            elif result.confidence < 0.7:
                ungrounded_terms.append(term)

        logger.debug(
            f"Grounded {len(grounded_terms)} terms, {len(ungrounded_terms)} ungrounded"
        )

        return grounded_terms, ungrounded_terms

    def _generate_patient_snapshot(
        self,
        extracted_texts: Dict[DocumentType, List[str]],
        language: Language,
        summary_type: SummaryType,
    ) -> PatientSnapshot:
        """Generate patient snapshot using mock LLM.

        Args:
            extracted_texts: Extracted text by document type
            language: Target language
            summary_type: Type of summary (clinician or patient-friendly)

        Returns:
            PatientSnapshot with all required fields
        """
        logger.debug("Generating patient snapshot")

        # Mock LLM processing - in production, use actual Clinical LLM
        # Extract key information from texts

        key_complaints = self._extract_complaints(extracted_texts)
        past_medical_history = self._extract_medical_history(extracted_texts)
        current_medications = self._extract_medications(extracted_texts)
        abnormal_findings = self._extract_findings(extracted_texts)
        pending_actions = self._extract_actions(extracted_texts)

        # Generate summary text
        summary_text = self._generate_summary_text(
            key_complaints,
            past_medical_history,
            current_medications,
            abnormal_findings,
            pending_actions,
            language,
            summary_type,
        )

        return PatientSnapshot(
            key_complaints=key_complaints,
            past_medical_history=past_medical_history,
            current_medications=current_medications,
            abnormal_findings=abnormal_findings,
            pending_actions=pending_actions,
            summary_text=summary_text,
            language=language,
        )

    def _extract_complaints(
        self, extracted_texts: Dict[DocumentType, List[str]]
    ) -> List[str]:
        """Extract key complaints from documents."""
        complaints = []

        # Look for common complaint keywords
        complaint_keywords = [
            "pain",
            "fever",
            "cough",
            "shortness of breath",
            "chest pain",
            "headache",
            "nausea",
            "vomiting",
            "dizziness",
        ]

        for texts in extracted_texts.values():
            for text in texts:
                text_lower = text.lower()
                for keyword in complaint_keywords:
                    if keyword in text_lower and keyword not in complaints:
                        complaints.append(keyword.title())

        return complaints[:5]  # Limit to top 5

    def _extract_medical_history(
        self, extracted_texts: Dict[DocumentType, List[str]]
    ) -> List[str]:
        """Extract past medical history from documents."""
        history = []

        # Look for common conditions
        conditions = [
            "diabetes",
            "hypertension",
            "asthma",
            "copd",
            "heart failure",
            "cancer",
            "stroke",
        ]

        for texts in extracted_texts.values():
            for text in texts:
                text_lower = text.lower()
                for condition in conditions:
                    if condition in text_lower and condition not in history:
                        history.append(condition.title())

        return history

    def _extract_medications(
        self, extracted_texts: Dict[DocumentType, List[str]]
    ) -> List[Medication]:
        """Extract current medications from documents."""
        medications = []

        # Look for common medications
        med_names = [
            "metformin",
            "insulin",
            "lisinopril",
            "amlodipine",
            "atorvastatin",
            "aspirin",
        ]

        for texts in extracted_texts.values():
            for text in texts:
                text_lower = text.lower()
                for med_name in med_names:
                    if med_name in text_lower:
                        # Check if already added
                        if not any(m.name.lower() == med_name for m in medications):
                            medications.append(
                                Medication(
                                    name=med_name.title(),
                                    dosage="As prescribed",
                                    frequency="Daily",
                                )
                            )

        return medications

    def _extract_findings(
        self, extracted_texts: Dict[DocumentType, List[str]]
    ) -> List[Finding]:
        """Extract abnormal findings from documents."""
        findings = []

        # Look for abnormal findings keywords
        finding_keywords = [
            "elevated",
            "abnormal",
            "suspicious",
            "mass",
            "lesion",
            "nodule",
            "opacity",
        ]

        for doc_type, texts in extracted_texts.items():
            for text in texts:
                text_lower = text.lower()
                for keyword in finding_keywords:
                    if keyword in text_lower:
                        # Extract sentence containing keyword
                        sentences = text.split(".")
                        for sentence in sentences:
                            if keyword in sentence.lower():
                                findings.append(
                                    Finding(
                                        description=sentence.strip()[:100],
                                        source=doc_type.value,
                                        severity="Medium",
                                    )
                                )
                                break
                        break

        return findings[:5]  # Limit to top 5

    def _extract_actions(
        self, extracted_texts: Dict[DocumentType, List[str]]
    ) -> List[Action]:
        """Extract pending actions from documents."""
        actions = []

        # Look for action keywords
        action_keywords = [
            "follow up",
            "schedule",
            "refer",
            "repeat",
            "monitor",
            "consult",
        ]

        for texts in extracted_texts.values():
            for text in texts:
                text_lower = text.lower()
                for keyword in action_keywords:
                    if keyword in text_lower:
                        actions.append(
                            Action(
                                description=f"{keyword.title()} required",
                                priority="Medium",
                            )
                        )
                        break

        return actions[:5]  # Limit to top 5

    def _generate_summary_text(
        self,
        key_complaints: List[str],
        past_medical_history: List[str],
        current_medications: List[Medication],
        abnormal_findings: List[Finding],
        pending_actions: List[Action],
        language: Language,
        summary_type: SummaryType,
    ) -> str:
        """Generate formatted summary text.

        Args:
            key_complaints: List of key complaints
            past_medical_history: List of past medical history items
            current_medications: List of current medications
            abnormal_findings: List of abnormal findings
            pending_actions: List of pending actions
            language: Target language
            summary_type: Type of summary

        Returns:
            Formatted summary text
        """
        # Generate summary in English (mock translation for other languages)
        summary_parts = []

        if key_complaints:
            summary_parts.append(f"Chief Complaints: {', '.join(key_complaints)}")

        if past_medical_history:
            summary_parts.append(
                f"Past Medical History: {', '.join(past_medical_history)}"
            )

        if current_medications:
            med_list = [f"{m.name} {m.dosage}" for m in current_medications]
            summary_parts.append(f"Current Medications: {', '.join(med_list)}")

        if abnormal_findings:
            finding_list = [f.description for f in abnormal_findings]
            summary_parts.append(f"Abnormal Findings: {'; '.join(finding_list)}")

        if pending_actions:
            action_list = [a.description for a in pending_actions]
            summary_parts.append(f"Pending Actions: {'; '.join(action_list)}")

        summary_text = "\n\n".join(summary_parts)

        # Ensure summary_text is never empty - provide default summary
        if not summary_text or len(summary_text.strip()) == 0:
            summary_text = "Clinical documents reviewed. No specific findings extracted from available documentation."

        # Mock translation for non-English languages
        if language == Language.HINDI:
            summary_text = f"[Hindi Translation]\n{summary_text}"
        elif language == Language.REGIONAL:
            summary_text = f"[Regional Language Translation]\n{summary_text}"

        # Simplify for patient-friendly summaries
        if summary_type == SummaryType.PATIENT_FRIENDLY:
            summary_text = summary_text.replace("Chief Complaints", "Main Concerns")
            summary_text = summary_text.replace("Past Medical History", "Medical Background")

        return summary_text

    def _validate_one_page_constraint(
        self, patient_snapshot: PatientSnapshot
    ) -> List[str]:
        """Validate that summary fits on one page.

        Args:
            patient_snapshot: Generated patient snapshot

        Returns:
            List of constraint violations (empty if valid)
        """
        violations = []

        # Check character count
        char_count = len(patient_snapshot.summary_text)
        if char_count > self.MAX_CHARS:
            violations.append(
                f"Summary exceeds {self.MAX_CHARS} character limit: {char_count} chars"
            )

        # Check line count
        line_count = patient_snapshot.summary_text.count("\n") + 1
        if line_count > self.MAX_LINES:
            violations.append(
                f"Summary exceeds {self.MAX_LINES} line limit: {line_count} lines"
            )

        return violations

    def _generate_explainability_report(
        self,
        input_data: SummarizerInput,
        documents: List[ClinicalDocument],
        patient_snapshot: PatientSnapshot,
        grounded_terms: List[str],
        generation_time_ms: int,
    ):
        """Generate explainability report for the summary.

        Args:
            input_data: Original input data
            documents: Retrieved documents
            patient_snapshot: Generated patient snapshot
            grounded_terms: List of grounded medical terms
            generation_time_ms: Time taken to generate summary

        Returns:
            ExplainabilityReport
        """
        reasoning_steps = [
            {
                "description": f"Retrieved {len(documents)} clinical documents from EMR",
                "evidence": [doc.document_type.value for doc in documents],
                "confidence": 0.95,
            },
            {
                "description": "Extracted text from all document types",
                "evidence": [
                    f"{len(patient_snapshot.key_complaints)} complaints",
                    f"{len(patient_snapshot.past_medical_history)} history items",
                ],
                "confidence": 0.90,
            },
            {
                "description": f"Grounded {len(grounded_terms)} medical terms to SNOMED CT",
                "evidence": grounded_terms[:5],
                "confidence": 0.85,
            },
            {
                "description": "Generated patient snapshot with all required fields",
                "evidence": [
                    "key_complaints",
                    "past_medical_history",
                    "current_medications",
                    "abnormal_findings",
                    "pending_actions",
                ],
                "confidence": 0.88,
            },
        ]

        evidence_sources = [
            {
                "source_type": "EMR_Note",
                "source_id": doc.document_id,
                "excerpt": doc.content[:100],
                "weight": 0.8,
            }
            for doc in documents[:3]
        ]

        limitations = [
            "Using mock LLM for text processing (placeholder)",
            "Limited medical term extraction (simple keyword matching)",
            "Translation not implemented (mock translation)",
        ]

        return self.explainability_generator.generate_report(
            component="Clinical_Summarizer",
            input_summary=f"{len(documents)} clinical documents for patient {input_data.patient_id}",
            output_summary=f"Patient snapshot with {len(patient_snapshot.key_complaints)} complaints, {len(patient_snapshot.current_medications)} medications",
            reasoning_steps=reasoning_steps,
            evidence_sources=evidence_sources,
            confidence_level=0.88,
            confidence_interval=(0.82, 0.94),
            limitations=limitations,
            human_review_required=True,
        )
