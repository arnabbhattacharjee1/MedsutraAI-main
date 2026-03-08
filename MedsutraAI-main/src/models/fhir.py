"""FHIR data models for EMR integration."""

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional


class FHIRResourceType(str, Enum):
    """FHIR resource types used in the system."""

    PATIENT = "Patient"
    ENCOUNTER = "Encounter"
    CONDITION = "Condition"
    OBSERVATION = "Observation"
    DIAGNOSTIC_REPORT = "DiagnosticReport"
    DOCUMENT_REFERENCE = "DocumentReference"
    MEDICATION_STATEMENT = "MedicationStatement"
    PROCEDURE = "Procedure"
    CARE_PLAN = "CarePlan"


@dataclass
class FHIRResource:
    """Base FHIR resource."""

    resource_type: FHIRResourceType
    id: str
    raw_data: Dict[str, Any] = field(default_factory=dict)


@dataclass
class FHIRPatient(FHIRResource):
    """FHIR Patient resource."""

    identifier: str = ""
    given_name: str = ""
    family_name: str = ""
    birth_date: Optional[datetime] = None
    gender: str = ""

    def __post_init__(self):
        """Set resource type."""
        self.resource_type = FHIRResourceType.PATIENT


@dataclass
class FHIREncounter(FHIRResource):
    """FHIR Encounter resource."""

    patient_id: str = ""
    status: str = ""
    class_code: str = ""
    period_start: Optional[datetime] = None
    period_end: Optional[datetime] = None

    def __post_init__(self):
        """Set resource type."""
        self.resource_type = FHIRResourceType.ENCOUNTER


@dataclass
class FHIRCondition(FHIRResource):
    """FHIR Condition resource."""

    patient_id: str = ""
    code: str = ""
    display: str = ""
    clinical_status: str = ""
    verification_status: str = ""
    onset_datetime: Optional[datetime] = None

    def __post_init__(self):
        """Set resource type."""
        self.resource_type = FHIRResourceType.CONDITION


@dataclass
class FHIRObservation(FHIRResource):
    """FHIR Observation resource."""

    patient_id: str = ""
    code: str = ""
    display: str = ""
    value: str = ""
    unit: str = ""
    status: str = ""
    effective_datetime: Optional[datetime] = None

    def __post_init__(self):
        """Set resource type."""
        self.resource_type = FHIRResourceType.OBSERVATION


@dataclass
class FHIRDiagnosticReport(FHIRResource):
    """FHIR DiagnosticReport resource."""

    patient_id: str = ""
    code: str = ""
    display: str = ""
    status: str = ""
    conclusion: str = ""
    issued: Optional[datetime] = None

    def __post_init__(self):
        """Set resource type."""
        self.resource_type = FHIRResourceType.DIAGNOSTIC_REPORT


@dataclass
class FHIRDocumentReference(FHIRResource):
    """FHIR DocumentReference resource."""

    patient_id: str = ""
    type_code: str = ""
    type_display: str = ""
    status: str = ""
    content: str = ""
    created: Optional[datetime] = None

    def __post_init__(self):
        """Set resource type."""
        self.resource_type = FHIRResourceType.DOCUMENT_REFERENCE


@dataclass
class FHIRMedicationStatement(FHIRResource):
    """FHIR MedicationStatement resource."""

    patient_id: str = ""
    medication_code: str = ""
    medication_display: str = ""
    status: str = ""
    effective_datetime: Optional[datetime] = None

    def __post_init__(self):
        """Set resource type."""
        self.resource_type = FHIRResourceType.MEDICATION_STATEMENT


@dataclass
class FHIRProcedure(FHIRResource):
    """FHIR Procedure resource."""

    patient_id: str = ""
    code: str = ""
    display: str = ""
    status: str = ""
    performed_datetime: Optional[datetime] = None

    def __post_init__(self):
        """Set resource type."""
        self.resource_type = FHIRResourceType.PROCEDURE


@dataclass
class FHIRCarePlan(FHIRResource):
    """FHIR CarePlan resource."""

    patient_id: str = ""
    status: str = ""
    intent: str = ""
    title: str = ""
    description: str = ""
    created: Optional[datetime] = None

    def __post_init__(self):
        """Set resource type."""
        self.resource_type = FHIRResourceType.CARE_PLAN


@dataclass
class PatientBundle:
    """Bundle of FHIR resources for a patient."""

    patient: Optional[FHIRPatient] = None
    encounters: List[FHIREncounter] = field(default_factory=list)
    conditions: List[FHIRCondition] = field(default_factory=list)
    observations: List[FHIRObservation] = field(default_factory=list)
    diagnostic_reports: List[FHIRDiagnosticReport] = field(default_factory=list)
    document_references: List[FHIRDocumentReference] = field(default_factory=list)
    medication_statements: List[FHIRMedicationStatement] = field(default_factory=list)
    procedures: List[FHIRProcedure] = field(default_factory=list)
    care_plans: List[FHIRCarePlan] = field(default_factory=list)
