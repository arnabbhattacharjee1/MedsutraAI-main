"""Clinical document data models."""

from datetime import datetime
from enum import Enum
from typing import Any, Optional
from pydantic import BaseModel, Field


class DocumentType(str, Enum):
    """Types of clinical documents."""

    EMR_NOTE = "EMR_NOTE"
    LAB_REPORT = "LAB_REPORT"
    DISCHARGE_SUMMARY = "DISCHARGE_SUMMARY"
    REFERRAL_NOTE = "REFERRAL_NOTE"
    RADIOLOGY_REPORT = "RADIOLOGY_REPORT"
    OPD_NOTE = "OPD_NOTE"
    INSURANCE_FORM = "INSURANCE_FORM"


class Clinician(BaseModel):
    """Clinician information."""

    clinician_id: str = Field(..., description="Unique clinician identifier")
    name: str = Field(..., description="Clinician name")
    role: str = Field(..., description="Clinician role (e.g., RADIOLOGIST, ONCOLOGIST)")


class ClinicalDocument(BaseModel):
    """Clinical document model with FHIR mappings."""

    document_id: str = Field(..., description="Unique document identifier")
    patient_id: str = Field(..., description="Associated patient identifier")
    document_type: DocumentType = Field(..., description="Type of clinical document")
    author: Clinician = Field(..., description="Document author")
    created_at: datetime = Field(..., description="Document creation timestamp")
    content: str = Field(..., description="Document text content")
    structured_data: Optional[dict[str, Any]] = Field(
        default=None, description="Structured data extracted from document"
    )
    fhir_resource_type: str = Field(..., description="FHIR resource type")
    fhir_resource_id: str = Field(..., description="FHIR resource identifier")

    class Config:
        """Pydantic configuration."""

        json_schema_extra = {
            "example": {
                "document_id": "DOC123",
                "patient_id": "P123456",
                "document_type": "RADIOLOGY_REPORT",
                "author": {
                    "clinician_id": "C789",
                    "name": "Dr. Smith",
                    "role": "RADIOLOGIST",
                },
                "created_at": "2024-01-15T10:30:00Z",
                "content": "Chest X-ray shows...",
                "fhir_resource_type": "DiagnosticReport",
                "fhir_resource_id": "FHIR-DR-123",
            }
        }
