"""Clinical summarizer data models."""

from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field

from .clinical_document import DocumentType
from .patient import Language
from .explainability import ExplainabilityReport


class SummaryType(str, Enum):
    """Type of summary to generate."""

    CLINICIAN = "clinician"
    PATIENT_FRIENDLY = "patient_friendly"


class Medication(BaseModel):
    """Medication information."""

    name: str = Field(..., description="Medication name")
    dosage: str = Field(..., description="Dosage information")
    frequency: str = Field(..., description="Frequency of administration")
    route: Optional[str] = Field(default=None, description="Route of administration")


class Finding(BaseModel):
    """Clinical finding."""

    description: str = Field(..., description="Finding description")
    source: str = Field(..., description="Source document or test")
    severity: Optional[str] = Field(default=None, description="Severity level")
    date: Optional[str] = Field(default=None, description="Date of finding")


class Action(BaseModel):
    """Pending clinical action."""

    description: str = Field(..., description="Action description")
    priority: str = Field(..., description="Priority level (High/Medium/Low)")
    due_date: Optional[str] = Field(default=None, description="Due date for action")


class PatientSnapshot(BaseModel):
    """One-page patient summary."""

    key_complaints: list[str] = Field(
        default_factory=list, description="Key patient complaints"
    )
    past_medical_history: list[str] = Field(
        default_factory=list, description="Past medical history items"
    )
    current_medications: list[Medication] = Field(
        default_factory=list, description="Current medications"
    )
    abnormal_findings: list[Finding] = Field(
        default_factory=list, description="Abnormal clinical findings"
    )
    pending_actions: list[Action] = Field(
        default_factory=list, description="Pending clinical actions"
    )
    summary_text: str = Field(..., description="One-page formatted summary text")
    language: Language = Field(..., description="Language of the summary")

    class Config:
        """Pydantic configuration."""

        json_schema_extra = {
            "example": {
                "key_complaints": ["Chest pain", "Shortness of breath"],
                "past_medical_history": ["Hypertension", "Type 2 Diabetes"],
                "current_medications": [
                    {
                        "name": "Metformin",
                        "dosage": "500mg",
                        "frequency": "twice daily",
                        "route": "oral",
                    }
                ],
                "abnormal_findings": [
                    {
                        "description": "Elevated troponin levels",
                        "source": "Lab Report",
                        "severity": "High",
                        "date": "2024-01-15",
                    }
                ],
                "pending_actions": [
                    {
                        "description": "Schedule cardiac catheterization",
                        "priority": "High",
                        "due_date": "2024-01-20",
                    }
                ],
                "summary_text": "Patient presents with...",
                "language": "ENGLISH",
            }
        }


class SummarizerInput(BaseModel):
    """Input for Clinical_Summarizer."""

    patient_id: str = Field(..., description="Patient identifier")
    document_ids: list[str] = Field(
        default_factory=list, description="EMR document reference IDs"
    )
    document_types: list[DocumentType] = Field(
        default_factory=list, description="Types of documents to include"
    )
    language: Language = Field(
        default=Language.ENGLISH, description="Language for summary"
    )
    summary_type: SummaryType = Field(
        default=SummaryType.CLINICIAN, description="Type of summary to generate"
    )

    class Config:
        """Pydantic configuration."""

        json_schema_extra = {
            "example": {
                "patient_id": "P123456",
                "document_ids": ["DOC001", "DOC002", "DOC003"],
                "document_types": ["EMR_NOTE", "LAB_REPORT", "RADIOLOGY_REPORT"],
                "language": "ENGLISH",
                "summary_type": "clinician",
            }
        }


class SummarizerOutput(BaseModel):
    """Output from Clinical_Summarizer."""

    patient_snapshot: PatientSnapshot = Field(..., description="Generated patient snapshot")
    explainability_report: ExplainabilityReport = Field(
        ..., description="Explainability report for the summary"
    )
    generation_time_ms: int = Field(
        ..., ge=0, description="Time taken to generate summary in milliseconds"
    )
    warnings: list[str] = Field(
        default_factory=list,
        description="Warnings about ungrounded terms, missing data, etc.",
    )

    class Config:
        """Pydantic configuration."""

        json_schema_extra = {
            "example": {
                "patient_snapshot": {
                    "key_complaints": ["Chest pain"],
                    "past_medical_history": ["Hypertension"],
                    "current_medications": [],
                    "abnormal_findings": [],
                    "pending_actions": [],
                    "summary_text": "Patient presents with...",
                    "language": "ENGLISH",
                },
                "explainability_report": {
                    "component": "Clinical_Summarizer",
                    "timestamp": "2024-01-15T10:30:00Z",
                    "input_summary": "3 clinical documents",
                    "output_summary": "Patient snapshot generated",
                    "reasoning_steps": [],
                    "evidence_sources": [],
                    "confidence_level": 0.9,
                    "confidence_interval": [0.85, 0.95],
                    "alternative_interpretations": [],
                    "limitations": [],
                    "human_review_required": True,
                },
                "generation_time_ms": 25000,
                "warnings": [],
            }
        }
