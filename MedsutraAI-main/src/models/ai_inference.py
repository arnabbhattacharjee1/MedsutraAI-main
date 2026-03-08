"""AI inference data models."""

from datetime import datetime
from enum import Enum
from typing import Any, Optional
from pydantic import BaseModel, Field

from .explainability import ExplainabilityReport


class ActionType(str, Enum):
    """Types of clinician actions on AI outputs."""

    ACCEPTED = "Accepted"
    MODIFIED = "Modified"
    REJECTED = "Rejected"


class ClinicianAction(BaseModel):
    """Clinician action on AI inference output."""

    action: ActionType = Field(..., description="Type of action taken")
    modifications: Optional[str] = Field(
        default=None, description="Description of modifications made"
    )
    rejection_reason: Optional[str] = Field(default=None, description="Reason for rejection")
    feedback_rating: Optional[int] = Field(
        default=None, ge=1, le=5, description="Feedback rating (1-5)"
    )
    timestamp: datetime = Field(..., description="Timestamp of action")
    clinician_id: str = Field(..., description="Identifier of clinician who took action")


class AIInference(BaseModel):
    """AI inference record with input, output, and explainability."""

    inference_id: str = Field(..., description="Unique inference identifier")
    component: str = Field(
        ...,
        description="AI component that performed inference",
        pattern="^(Clinical_Summarizer|Radiology_Analyzer|Documentation_Assistant|Workflow_Engine)$",
    )
    patient_id: str = Field(..., description="Associated patient identifier")
    input_data: dict[str, Any] = Field(..., description="Input data for inference")
    output_data: dict[str, Any] = Field(..., description="Output data from inference")
    explainability_report: ExplainabilityReport = Field(
        ..., description="Explainability report for this inference"
    )
    model_version: str = Field(..., description="Version of AI model used")
    inference_time_ms: int = Field(..., ge=0, description="Inference time in milliseconds")
    timestamp: datetime = Field(..., description="Timestamp of inference")
    clinician_action: Optional[ClinicianAction] = Field(
        default=None, description="Clinician action on this inference"
    )

    class Config:
        """Pydantic configuration."""

        json_schema_extra = {
            "example": {
                "inference_id": "INF123",
                "component": "Radiology_Analyzer",
                "patient_id": "P123456",
                "input_data": {"report_id": "RAD-123", "report_text": "Chest X-ray shows..."},
                "output_data": {"cancer_risk_score": 78, "risk_flag": "High"},
                "explainability_report": {
                    "component": "Radiology_Analyzer",
                    "timestamp": "2024-01-15T10:35:00Z",
                    "input_summary": "Chest X-ray report",
                    "output_summary": "High cancer risk",
                    "reasoning_steps": [],
                    "evidence_sources": [],
                    "confidence_level": 0.88,
                    "confidence_interval": [0.82, 0.94],
                    "alternative_interpretations": [],
                    "limitations": [],
                    "human_review_required": True,
                },
                "model_version": "1.0.0",
                "inference_time_ms": 8500,
                "timestamp": "2024-01-15T10:35:00Z",
            }
        }
