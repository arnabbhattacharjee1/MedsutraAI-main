"""Explainability report data models."""

from enum import Enum
from typing import Any, Optional
from pydantic import BaseModel, Field


class SourceType(str, Enum):
    """Types of evidence sources."""

    EMR_NOTE = "EMR_Note"
    LAB_RESULT = "Lab_Result"
    RADIOLOGY_REPORT = "Radiology_Report"
    KNOWLEDGE_BASE = "Knowledge_Base"


class ReasoningStep(BaseModel):
    """Individual reasoning step in AI decision process."""

    step_number: int = Field(..., ge=1, description="Step sequence number")
    description: str = Field(..., description="Description of what AI did in this step")
    evidence: list[str] = Field(
        default_factory=list, description="Source data that influenced this step"
    )
    confidence: float = Field(..., ge=0.0, le=1.0, description="Confidence level for this step")


class EvidenceSource(BaseModel):
    """Evidence source used in AI inference."""

    source_type: SourceType = Field(..., description="Type of evidence source")
    source_id: str = Field(..., description="Unique identifier for the source")
    excerpt: str = Field(..., description="Relevant text excerpt from source")
    weight: float = Field(..., ge=0.0, le=1.0, description="Weight/importance of this source")


class AlternativeInterpretation(BaseModel):
    """Alternative interpretation considered by AI."""

    interpretation: str = Field(..., description="Alternative conclusion")
    probability: float = Field(..., ge=0.0, le=1.0, description="Probability of this interpretation")
    reasoning: str = Field(..., description="Why this was considered")


class ExplainabilityReport(BaseModel):
    """Comprehensive explainability report for AI inference."""

    component: str = Field(
        ...,
        description="AI component that generated this report",
        pattern="^(Clinical_Summarizer|Radiology_Analyzer|Documentation_Assistant|Workflow_Engine)$",
    )
    timestamp: str = Field(..., description="ISO 8601 timestamp of report generation")
    input_summary: str = Field(..., description="Brief description of input data")
    output_summary: str = Field(..., description="Brief description of AI output")
    reasoning_steps: list[ReasoningStep] = Field(
        default_factory=list, description="Step-by-step reasoning trace"
    )
    evidence_sources: list[EvidenceSource] = Field(
        default_factory=list, description="Sources that influenced the decision"
    )
    confidence_level: float = Field(
        ..., ge=0.0, le=1.0, description="Overall confidence in the output"
    )
    confidence_interval: tuple[float, float] = Field(
        ..., description="Confidence interval [lower, upper]"
    )
    alternative_interpretations: list[AlternativeInterpretation] = Field(
        default_factory=list, description="Alternative conclusions considered"
    )
    limitations: list[str] = Field(
        default_factory=list, description="Known limitations or caveats"
    )
    human_review_required: bool = Field(
        ..., description="Whether human review is mandatory for this output"
    )

    class Config:
        """Pydantic configuration."""

        json_schema_extra = {
            "example": {
                "component": "Radiology_Analyzer",
                "timestamp": "2024-01-15T10:35:00Z",
                "input_summary": "Chest X-ray report for patient P123456",
                "output_summary": "High cancer risk detected (score: 78)",
                "reasoning_steps": [
                    {
                        "step_number": 1,
                        "description": "Identified suspicious terminology",
                        "evidence": ["mass", "irregular borders"],
                        "confidence": 0.92,
                    }
                ],
                "evidence_sources": [
                    {
                        "source_type": "Radiology_Report",
                        "source_id": "RAD-123",
                        "excerpt": "3cm mass with irregular borders",
                        "weight": 0.95,
                    }
                ],
                "confidence_level": 0.88,
                "confidence_interval": [0.82, 0.94],
                "alternative_interpretations": [],
                "limitations": ["Limited to text analysis only"],
                "human_review_required": True,
            }
        }
