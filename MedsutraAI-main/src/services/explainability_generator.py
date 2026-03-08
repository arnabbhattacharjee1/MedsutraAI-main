"""Explainability report generator service."""

from datetime import datetime, timezone
from typing import Any, Optional

from src.models.explainability import (
    AlternativeInterpretation,
    EvidenceSource,
    ExplainabilityReport,
    ReasoningStep,
    SourceType,
)
from src.utils.logger import get_logger

logger = get_logger(__name__)


class ExplainabilityGenerator:
    """Service for generating explainability reports for AI components."""

    def __init__(self):
        """Initialize the explainability generator."""
        self.logger = logger

    def generate_report(
        self,
        component: str,
        input_summary: str,
        output_summary: str,
        reasoning_steps: Optional[list[dict[str, Any]]] = None,
        evidence_sources: Optional[list[dict[str, Any]]] = None,
        confidence_level: float = 0.0,
        confidence_interval: Optional[tuple[float, float]] = None,
        alternative_interpretations: Optional[list[dict[str, Any]]] = None,
        limitations: Optional[list[str]] = None,
        human_review_required: bool = True,
    ) -> ExplainabilityReport:
        """
        Generate a comprehensive explainability report.

        Args:
            component: AI component name (Clinical_Summarizer, Radiology_Analyzer,
                      Documentation_Assistant, or Workflow_Engine)
            input_summary: Brief description of input data
            output_summary: Brief description of AI output
            reasoning_steps: List of reasoning step dictionaries
            evidence_sources: List of evidence source dictionaries
            confidence_level: Overall confidence in the output (0.0-1.0)
            confidence_interval: Tuple of (lower, upper) confidence bounds
            alternative_interpretations: List of alternative interpretation dictionaries
            limitations: List of known limitations or caveats
            human_review_required: Whether human review is mandatory

        Returns:
            ExplainabilityReport: Validated explainability report

        Raises:
            ValueError: If component name is invalid or confidence values are out of range
        """
        # Validate component name
        valid_components = [
            "Clinical_Summarizer",
            "Radiology_Analyzer",
            "Documentation_Assistant",
            "Workflow_Engine",
        ]
        if component not in valid_components:
            raise ValueError(
                f"Invalid component '{component}'. Must be one of {valid_components}"
            )

        # Validate confidence level
        if not 0.0 <= confidence_level <= 1.0:
            raise ValueError(
                f"Confidence level must be between 0.0 and 1.0, got {confidence_level}"
            )

        # Generate timestamp
        timestamp = datetime.now(timezone.utc).isoformat()

        # Process reasoning steps
        processed_reasoning_steps = []
        if reasoning_steps:
            for i, step_data in enumerate(reasoning_steps):
                step = ReasoningStep(
                    step_number=i + 1,  # Always renumber sequentially starting from 1
                    description=step_data.get("description", ""),
                    evidence=step_data.get("evidence", []),
                    confidence=step_data.get("confidence", 0.0),
                )
                processed_reasoning_steps.append(step)

        # Process evidence sources
        processed_evidence_sources = []
        if evidence_sources:
            for source_data in evidence_sources:
                source = EvidenceSource(
                    source_type=SourceType(source_data.get("source_type", "EMR_Note")),
                    source_id=source_data.get("source_id", ""),
                    excerpt=source_data.get("excerpt", ""),
                    weight=source_data.get("weight", 0.0),
                )
                processed_evidence_sources.append(source)

        # Calculate confidence interval if not provided
        if confidence_interval is None:
            # Default: ±5% around confidence level
            margin = 0.05
            lower = max(0.0, confidence_level - margin)
            upper = min(1.0, confidence_level + margin)
            confidence_interval = (lower, upper)
        else:
            # Validate confidence interval
            lower, upper = confidence_interval
            if not (0.0 <= lower <= upper <= 1.0):
                raise ValueError(
                    f"Invalid confidence interval [{lower}, {upper}]. "
                    "Must satisfy 0.0 <= lower <= upper <= 1.0"
                )

        # Process alternative interpretations
        processed_alternatives = []
        if alternative_interpretations:
            for alt_data in alternative_interpretations:
                alt = AlternativeInterpretation(
                    interpretation=alt_data.get("interpretation", ""),
                    probability=alt_data.get("probability", 0.0),
                    reasoning=alt_data.get("reasoning", ""),
                )
                processed_alternatives.append(alt)

        # Create the report
        report = ExplainabilityReport(
            component=component,
            timestamp=timestamp,
            input_summary=input_summary,
            output_summary=output_summary,
            reasoning_steps=processed_reasoning_steps,
            evidence_sources=processed_evidence_sources,
            confidence_level=confidence_level,
            confidence_interval=confidence_interval,
            alternative_interpretations=processed_alternatives,
            limitations=limitations or [],
            human_review_required=human_review_required,
        )

        self.logger.info(
            f"Generated explainability report for {component}",
            extra={
                "component": component,
                "confidence_level": confidence_level,
                "reasoning_steps_count": len(processed_reasoning_steps),
                "evidence_sources_count": len(processed_evidence_sources),
            },
        )

        return report

    def add_reasoning_step(
        self,
        report: ExplainabilityReport,
        description: str,
        evidence: list[str],
        confidence: float,
    ) -> ExplainabilityReport:
        """
        Add a reasoning step to an existing report.

        Args:
            report: Existing explainability report
            description: Description of the reasoning step
            evidence: List of evidence items
            confidence: Confidence level for this step (0.0-1.0)

        Returns:
            ExplainabilityReport: Updated report with new reasoning step

        Raises:
            ValueError: If confidence is out of range
        """
        if not 0.0 <= confidence <= 1.0:
            raise ValueError(f"Confidence must be between 0.0 and 1.0, got {confidence}")

        # Determine next step number
        next_step_number = len(report.reasoning_steps) + 1

        # Create new reasoning step
        new_step = ReasoningStep(
            step_number=next_step_number,
            description=description,
            evidence=evidence,
            confidence=confidence,
        )

        # Create updated report with new step
        updated_steps = list(report.reasoning_steps) + [new_step]

        # Create new report instance with updated steps
        updated_report = ExplainabilityReport(
            component=report.component,
            timestamp=report.timestamp,
            input_summary=report.input_summary,
            output_summary=report.output_summary,
            reasoning_steps=updated_steps,
            evidence_sources=report.evidence_sources,
            confidence_level=report.confidence_level,
            confidence_interval=report.confidence_interval,
            alternative_interpretations=report.alternative_interpretations,
            limitations=report.limitations,
            human_review_required=report.human_review_required,
        )

        return updated_report

    def add_evidence_source(
        self,
        report: ExplainabilityReport,
        source_type: str,
        source_id: str,
        excerpt: str,
        weight: float,
    ) -> ExplainabilityReport:
        """
        Add an evidence source to an existing report.

        Args:
            report: Existing explainability report
            source_type: Type of evidence source
            source_id: Unique identifier for the source
            excerpt: Relevant text excerpt
            weight: Weight/importance of this source (0.0-1.0)

        Returns:
            ExplainabilityReport: Updated report with new evidence source

        Raises:
            ValueError: If weight is out of range or source_type is invalid
        """
        if not 0.0 <= weight <= 1.0:
            raise ValueError(f"Weight must be between 0.0 and 1.0, got {weight}")

        # Create new evidence source
        new_source = EvidenceSource(
            source_type=SourceType(source_type),
            source_id=source_id,
            excerpt=excerpt,
            weight=weight,
        )

        # Create updated report with new source
        updated_sources = list(report.evidence_sources) + [new_source]

        # Create new report instance with updated sources
        updated_report = ExplainabilityReport(
            component=report.component,
            timestamp=report.timestamp,
            input_summary=report.input_summary,
            output_summary=report.output_summary,
            reasoning_steps=report.reasoning_steps,
            evidence_sources=updated_sources,
            confidence_level=report.confidence_level,
            confidence_interval=report.confidence_interval,
            alternative_interpretations=report.alternative_interpretations,
            limitations=report.limitations,
            human_review_required=report.human_review_required,
        )

        return updated_report

    def validate_report_structure(self, report: ExplainabilityReport) -> bool:
        """
        Validate that a report has all required fields and proper structure.

        Args:
            report: Explainability report to validate

        Returns:
            bool: True if report is valid

        Raises:
            ValueError: If report structure is invalid
        """
        # Check required fields are non-empty
        if not report.component:
            raise ValueError("Report must have a component")
        if not report.timestamp:
            raise ValueError("Report must have a timestamp")
        if not report.input_summary:
            raise ValueError("Report must have an input_summary")
        if not report.output_summary:
            raise ValueError("Report must have an output_summary")

        # Validate confidence interval
        lower, upper = report.confidence_interval
        if lower > upper:
            raise ValueError(
                f"Confidence interval lower bound ({lower}) must be <= upper bound ({upper})"
            )

        # Validate reasoning steps
        for i, step in enumerate(report.reasoning_steps):
            if step.step_number != i + 1:
                raise ValueError(
                    f"Reasoning step {i} has incorrect step_number {step.step_number}, expected {i + 1}"
                )
            if not 0.0 <= step.confidence <= 1.0:
                raise ValueError(
                    f"Reasoning step {i} has invalid confidence {step.confidence}"
                )

        # Validate evidence sources
        for i, source in enumerate(report.evidence_sources):
            if not 0.0 <= source.weight <= 1.0:
                raise ValueError(f"Evidence source {i} has invalid weight {source.weight}")

        # Validate alternative interpretations
        for i, alt in enumerate(report.alternative_interpretations):
            if not 0.0 <= alt.probability <= 1.0:
                raise ValueError(
                    f"Alternative interpretation {i} has invalid probability {alt.probability}"
                )

        return True
