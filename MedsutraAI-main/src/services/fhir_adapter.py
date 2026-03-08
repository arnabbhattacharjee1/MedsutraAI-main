"""FHIR adapter for EMR connectivity."""

import time
from datetime import datetime
from typing import Any, Dict, List, Optional

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from src.config.settings import get_settings
from src.models.fhir import (
    FHIRCarePlan,
    FHIRCondition,
    FHIRDiagnosticReport,
    FHIRDocumentReference,
    FHIREncounter,
    FHIRMedicationStatement,
    FHIRObservation,
    FHIRPatient,
    FHIRProcedure,
    FHIRResourceType,
    PatientBundle,
)
from src.utils.circuit_breaker import CircuitBreaker, CircuitBreakerError
from src.utils.logger import get_logger

logger = get_logger(__name__)
settings = get_settings()


class FHIRAdapterError(Exception):
    """Base exception for FHIR adapter errors."""

    pass


class FHIRConnectionError(FHIRAdapterError):
    """Exception for connection errors."""

    pass


class FHIRTimeoutError(FHIRAdapterError):
    """Exception for timeout errors."""

    pass


class FHIRAuthenticationError(FHIRAdapterError):
    """Exception for authentication errors."""

    pass


class FHIRResourceNotFoundError(FHIRAdapterError):
    """Exception for resource not found errors."""

    pass


class FHIRMalformedResponseError(FHIRAdapterError):
    """Exception for malformed response errors."""

    pass


class FHIRAdapter:
    """Adapter for HL7 FHIR R4 EMR integration.

    Provides methods for retrieving patient data and writing AI-generated
    documents back to the EMR system. Implements retry logic with exponential
    backoff and circuit breaker pattern for resilience.
    """

    def __init__(
        self,
        base_url: Optional[str] = None,
        timeout: Optional[int] = None,
        retry_attempts: Optional[int] = None,
        circuit_breaker_threshold: Optional[int] = None,
        circuit_breaker_timeout: Optional[int] = None,
    ):
        """Initialize FHIR adapter.

        Args:
            base_url: FHIR API base URL (defaults to settings)
            timeout: Request timeout in seconds (defaults to settings)
            retry_attempts: Number of retry attempts (defaults to settings)
            circuit_breaker_threshold: Circuit breaker failure threshold (defaults to settings)
            circuit_breaker_timeout: Circuit breaker timeout in seconds (defaults to settings)
        """
        self.base_url = base_url or settings.emr_fhir_base_url
        if not self.base_url:
            raise ValueError("FHIR base URL must be provided")

        self.timeout = timeout or settings.emr_api_timeout_seconds
        self.retry_attempts = retry_attempts or settings.emr_retry_attempts

        # Initialize circuit breaker
        self.circuit_breaker = CircuitBreaker(
            failure_threshold=circuit_breaker_threshold
            or settings.emr_circuit_breaker_threshold,
            timeout_seconds=circuit_breaker_timeout
            or settings.emr_circuit_breaker_timeout_seconds,
            name="fhir_adapter",
        )

        # Configure session with retry logic
        self.session = self._create_session()

        logger.info(
            "FHIR adapter initialized",
            extra={
                "base_url": self.base_url,
                "timeout": self.timeout,
                "retry_attempts": self.retry_attempts,
            },
        )

    def _create_session(self) -> requests.Session:
        """Create requests session with retry configuration.

        Implements exponential backoff: 1s, 2s, 4s for 3 attempts.

        Returns:
            Configured requests session
        """
        session = requests.Session()

        # Configure retry strategy with exponential backoff
        retry_strategy = Retry(
            total=self.retry_attempts,
            backoff_factor=1,  # 1s, 2s, 4s for 3 attempts
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["GET", "POST", "PUT"],
        )

        adapter = HTTPAdapter(max_retries=retry_strategy)
        session.mount("http://", adapter)
        session.mount("https://", adapter)

        return session

    def _make_request(
        self,
        method: str,
        endpoint: str,
        data: Optional[Dict[str, Any]] = None,
        params: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Make HTTP request with circuit breaker protection.

        Args:
            method: HTTP method (GET, POST, PUT)
            endpoint: API endpoint
            data: Request body data
            params: Query parameters

        Returns:
            Response JSON data

        Raises:
            FHIRConnectionError: Connection failed
            FHIRTimeoutError: Request timed out
            FHIRAuthenticationError: Authentication failed
            FHIRMalformedResponseError: Response is malformed
            CircuitBreakerError: Circuit breaker is open
        """
        url = f"{self.base_url}/{endpoint}"

        def _request():
            try:
                logger.debug(
                    f"Making FHIR request: {method} {url}",
                    extra={"method": method, "url": url, "params": params},
                )

                response = self.session.request(
                    method=method,
                    url=url,
                    json=data,
                    params=params,
                    timeout=self.timeout,
                    headers={"Accept": "application/fhir+json"},
                )

                # Handle HTTP errors
                if response.status_code == 401 or response.status_code == 403:
                    raise FHIRAuthenticationError(
                        f"Authentication failed: {response.status_code}"
                    )
                elif response.status_code == 404:
                    raise FHIRResourceNotFoundError(f"Resource not found: {url}")
                elif response.status_code >= 400:
                    raise FHIRConnectionError(
                        f"HTTP error {response.status_code}: {response.text}"
                    )

                # Parse JSON response
                try:
                    return response.json()
                except ValueError as e:
                    raise FHIRMalformedResponseError(
                        f"Failed to parse JSON response: {e}"
                    )

            except requests.exceptions.Timeout as e:
                logger.error(f"FHIR request timeout: {url}", extra={"error": str(e)})
                raise FHIRTimeoutError(f"Request timeout: {url}")
            except requests.exceptions.ConnectionError as e:
                logger.error(f"FHIR connection error: {url}", extra={"error": str(e)})
                raise FHIRConnectionError(f"Connection error: {url}")
            except (FHIRAuthenticationError, FHIRResourceNotFoundError, FHIRMalformedResponseError):
                raise
            except Exception as e:
                logger.error(f"Unexpected FHIR error: {url}", extra={"error": str(e)})
                raise FHIRAdapterError(f"Unexpected error: {e}")

        try:
            return self.circuit_breaker.call(_request)
        except CircuitBreakerError:
            logger.error(
                "Circuit breaker open, EMR unavailable",
                extra={"circuit_state": self.circuit_breaker.state},
            )
            raise

    def get_patient(self, patient_id: str) -> FHIRPatient:
        """Retrieve patient resource.

        Args:
            patient_id: Patient identifier

        Returns:
            FHIR Patient resource

        Raises:
            FHIRResourceNotFoundError: Patient not found
            FHIRAdapterError: Other errors
        """
        logger.info(f"Retrieving patient: {patient_id}")

        data = self._make_request("GET", f"Patient/{patient_id}")

        return self._parse_patient(data)

    def get_patient_bundle(self, patient_id: str) -> PatientBundle:
        """Retrieve complete patient data bundle.

        Fetches all relevant FHIR resources for a patient including encounters,
        conditions, observations, diagnostic reports, documents, medications,
        procedures, and care plans.

        Args:
            patient_id: Patient identifier

        Returns:
            PatientBundle with all patient data

        Raises:
            FHIRAdapterError: Retrieval failed
        """
        logger.info(f"Retrieving patient bundle: {patient_id}")

        bundle = PatientBundle()

        # Get patient
        try:
            bundle.patient = self.get_patient(patient_id)
        except FHIRResourceNotFoundError:
            logger.warning(f"Patient not found: {patient_id}")

        # Get encounters
        bundle.encounters = self.get_encounters(patient_id)

        # Get conditions
        bundle.conditions = self.get_conditions(patient_id)

        # Get observations
        bundle.observations = self.get_observations(patient_id)

        # Get diagnostic reports
        bundle.diagnostic_reports = self.get_diagnostic_reports(patient_id)

        # Get document references
        bundle.document_references = self.get_document_references(patient_id)

        # Get medication statements
        bundle.medication_statements = self.get_medication_statements(patient_id)

        # Get procedures
        bundle.procedures = self.get_procedures(patient_id)

        # Get care plans
        bundle.care_plans = self.get_care_plans(patient_id)

        logger.info(
            f"Retrieved patient bundle: {patient_id}",
            extra={
                "patient_id": patient_id,
                "encounters": len(bundle.encounters),
                "conditions": len(bundle.conditions),
                "observations": len(bundle.observations),
                "diagnostic_reports": len(bundle.diagnostic_reports),
                "documents": len(bundle.document_references),
                "medications": len(bundle.medication_statements),
                "procedures": len(bundle.procedures),
                "care_plans": len(bundle.care_plans),
            },
        )

        return bundle

    def get_encounters(self, patient_id: str) -> List[FHIREncounter]:
        """Retrieve patient encounters.

        Args:
            patient_id: Patient identifier

        Returns:
            List of FHIR Encounter resources
        """
        data = self._make_request("GET", "Encounter", params={"patient": patient_id})
        return self._parse_bundle(data, self._parse_encounter)

    def get_conditions(self, patient_id: str) -> List[FHIRCondition]:
        """Retrieve patient conditions.

        Args:
            patient_id: Patient identifier

        Returns:
            List of FHIR Condition resources
        """
        data = self._make_request("GET", "Condition", params={"patient": patient_id})
        return self._parse_bundle(data, self._parse_condition)

    def get_observations(self, patient_id: str) -> List[FHIRObservation]:
        """Retrieve patient observations.

        Args:
            patient_id: Patient identifier

        Returns:
            List of FHIR Observation resources
        """
        data = self._make_request("GET", "Observation", params={"patient": patient_id})
        return self._parse_bundle(data, self._parse_observation)

    def get_diagnostic_reports(self, patient_id: str) -> List[FHIRDiagnosticReport]:
        """Retrieve patient diagnostic reports.

        Args:
            patient_id: Patient identifier

        Returns:
            List of FHIR DiagnosticReport resources
        """
        data = self._make_request(
            "GET", "DiagnosticReport", params={"patient": patient_id}
        )
        return self._parse_bundle(data, self._parse_diagnostic_report)

    def get_document_references(self, patient_id: str) -> List[FHIRDocumentReference]:
        """Retrieve patient document references.

        Args:
            patient_id: Patient identifier

        Returns:
            List of FHIR DocumentReference resources
        """
        data = self._make_request(
            "GET", "DocumentReference", params={"patient": patient_id}
        )
        return self._parse_bundle(data, self._parse_document_reference)

    def get_medication_statements(
        self, patient_id: str
    ) -> List[FHIRMedicationStatement]:
        """Retrieve patient medication statements.

        Args:
            patient_id: Patient identifier

        Returns:
            List of FHIR MedicationStatement resources
        """
        data = self._make_request(
            "GET", "MedicationStatement", params={"patient": patient_id}
        )
        return self._parse_bundle(data, self._parse_medication_statement)

    def get_procedures(self, patient_id: str) -> List[FHIRProcedure]:
        """Retrieve patient procedures.

        Args:
            patient_id: Patient identifier

        Returns:
            List of FHIR Procedure resources
        """
        data = self._make_request("GET", "Procedure", params={"patient": patient_id})
        return self._parse_bundle(data, self._parse_procedure)

    def get_care_plans(self, patient_id: str) -> List[FHIRCarePlan]:
        """Retrieve patient care plans.

        Args:
            patient_id: Patient identifier

        Returns:
            List of FHIR CarePlan resources
        """
        data = self._make_request("GET", "CarePlan", params={"patient": patient_id})
        return self._parse_bundle(data, self._parse_care_plan)

    def create_document_reference(
        self,
        patient_id: str,
        document_type: str,
        content: str,
        status: str = "current",
    ) -> str:
        """Create document reference in EMR.

        Used for writing AI-generated documentation back to EMR upon clinician approval.

        Args:
            patient_id: Patient identifier
            document_type: Document type code
            content: Document content
            status: Document status (default: "current")

        Returns:
            Created document reference ID

        Raises:
            FHIRAdapterError: Creation failed
        """
        logger.info(
            f"Creating document reference for patient: {patient_id}",
            extra={"patient_id": patient_id, "document_type": document_type},
        )

        document_data = {
            "resourceType": "DocumentReference",
            "status": status,
            "type": {"coding": [{"code": document_type}]},
            "subject": {"reference": f"Patient/{patient_id}"},
            "date": datetime.utcnow().isoformat(),
            "content": [
                {
                    "attachment": {
                        "contentType": "text/plain",
                        "data": content,
                    }
                }
            ],
        }

        response = self._make_request("POST", "DocumentReference", data=document_data)

        document_id = response.get("id", "")
        logger.info(
            f"Created document reference: {document_id}",
            extra={"patient_id": patient_id, "document_id": document_id},
        )

        return document_id

    def create_care_plan(
        self,
        patient_id: str,
        title: str,
        description: str,
        status: str = "active",
        intent: str = "proposal",
    ) -> str:
        """Create care plan in EMR.

        Used for writing AI-generated workflow suggestions back to EMR upon clinician approval.

        Args:
            patient_id: Patient identifier
            title: Care plan title
            description: Care plan description
            status: Care plan status (default: "active")
            intent: Care plan intent (default: "proposal")

        Returns:
            Created care plan ID

        Raises:
            FHIRAdapterError: Creation failed
        """
        logger.info(
            f"Creating care plan for patient: {patient_id}",
            extra={"patient_id": patient_id, "title": title},
        )

        care_plan_data = {
            "resourceType": "CarePlan",
            "status": status,
            "intent": intent,
            "title": title,
            "description": description,
            "subject": {"reference": f"Patient/{patient_id}"},
            "created": datetime.utcnow().isoformat(),
        }

        response = self._make_request("POST", "CarePlan", data=care_plan_data)

        care_plan_id = response.get("id", "")
        logger.info(
            f"Created care plan: {care_plan_id}",
            extra={"patient_id": patient_id, "care_plan_id": care_plan_id},
        )

        return care_plan_id

    def _parse_bundle(self, data: Dict[str, Any], parser) -> List:
        """Parse FHIR bundle response.

        Args:
            data: FHIR bundle data
            parser: Parser function for individual resources

        Returns:
            List of parsed resources
        """
        if data.get("resourceType") != "Bundle":
            return []

        entries = data.get("entry", [])
        resources = []

        for entry in entries:
            resource_data = entry.get("resource", {})
            try:
                resource = parser(resource_data)
                resources.append(resource)
            except Exception as e:
                logger.warning(
                    f"Failed to parse resource: {e}",
                    extra={"resource_type": resource_data.get("resourceType")},
                )

        return resources

    def _parse_patient(self, data: Dict[str, Any]) -> FHIRPatient:
            """Parse FHIR Patient resource."""
            name = data.get("name", [{}])[0] if data.get("name") else {}
            identifier = data.get("identifier", [{}])[0] if data.get("identifier") else {}

            return FHIRPatient(
                resource_type=FHIRResourceType.PATIENT,
                id=data.get("id", ""),
                identifier=identifier.get("value", ""),
                given_name=" ".join(name.get("given", [])),
                family_name=name.get("family", ""),
                birth_date=self._parse_datetime(data.get("birthDate")),
                gender=data.get("gender", ""),
                raw_data=data,
            )


    def _parse_encounter(self, data: Dict[str, Any]) -> FHIREncounter:
        """Parse FHIR Encounter resource."""
        period = data.get("period", {})
        patient_ref = data.get("subject", {}).get("reference", "")
        patient_id = patient_ref.split("/")[-1] if "/" in patient_ref else ""

        return FHIREncounter(
            id=data.get("id", ""),
            patient_id=patient_id,
            status=data.get("status", ""),
            class_code=data.get("class", {}).get("code", ""),
            period_start=self._parse_datetime(period.get("start")),
            period_end=self._parse_datetime(period.get("end")),
            raw_data=data,
        )

    def _parse_condition(self, data: Dict[str, Any]) -> FHIRCondition:
        """Parse FHIR Condition resource."""
        code = data.get("code", {}).get("coding", [{}])[0]
        patient_ref = data.get("subject", {}).get("reference", "")
        patient_id = patient_ref.split("/")[-1] if "/" in patient_ref else ""

        return FHIRCondition(
            id=data.get("id", ""),
            patient_id=patient_id,
            code=code.get("code", ""),
            display=code.get("display", ""),
            clinical_status=data.get("clinicalStatus", {})
            .get("coding", [{}])[0]
            .get("code", ""),
            verification_status=data.get("verificationStatus", {})
            .get("coding", [{}])[0]
            .get("code", ""),
            onset_datetime=self._parse_datetime(data.get("onsetDateTime")),
            raw_data=data,
        )

    def _parse_observation(self, data: Dict[str, Any]) -> FHIRObservation:
        """Parse FHIR Observation resource."""
        code = data.get("code", {}).get("coding", [{}])[0]
        value = data.get("valueQuantity", {})
        patient_ref = data.get("subject", {}).get("reference", "")
        patient_id = patient_ref.split("/")[-1] if "/" in patient_ref else ""

        return FHIRObservation(
            id=data.get("id", ""),
            patient_id=patient_id,
            code=code.get("code", ""),
            display=code.get("display", ""),
            value=str(value.get("value", "")),
            unit=value.get("unit", ""),
            status=data.get("status", ""),
            effective_datetime=self._parse_datetime(data.get("effectiveDateTime")),
            raw_data=data,
        )

    def _parse_diagnostic_report(self, data: Dict[str, Any]) -> FHIRDiagnosticReport:
        """Parse FHIR DiagnosticReport resource."""
        code = data.get("code", {}).get("coding", [{}])[0]
        patient_ref = data.get("subject", {}).get("reference", "")
        patient_id = patient_ref.split("/")[-1] if "/" in patient_ref else ""

        return FHIRDiagnosticReport(
            id=data.get("id", ""),
            patient_id=patient_id,
            code=code.get("code", ""),
            display=code.get("display", ""),
            status=data.get("status", ""),
            conclusion=data.get("conclusion", ""),
            issued=self._parse_datetime(data.get("issued")),
            raw_data=data,
        )

    def _parse_document_reference(self, data: Dict[str, Any]) -> FHIRDocumentReference:
        """Parse FHIR DocumentReference resource."""
        type_code = data.get("type", {}).get("coding", [{}])[0]
        content = data.get("content", [{}])[0].get("attachment", {})
        patient_ref = data.get("subject", {}).get("reference", "")
        patient_id = patient_ref.split("/")[-1] if "/" in patient_ref else ""

        return FHIRDocumentReference(
            id=data.get("id", ""),
            patient_id=patient_id,
            type_code=type_code.get("code", ""),
            type_display=type_code.get("display", ""),
            status=data.get("status", ""),
            content=content.get("data", ""),
            created=self._parse_datetime(data.get("date")),
            raw_data=data,
        )

    def _parse_medication_statement(
        self, data: Dict[str, Any]
    ) -> FHIRMedicationStatement:
        """Parse FHIR MedicationStatement resource."""
        medication = data.get("medicationCodeableConcept", {}).get("coding", [{}])[0]
        patient_ref = data.get("subject", {}).get("reference", "")
        patient_id = patient_ref.split("/")[-1] if "/" in patient_ref else ""

        return FHIRMedicationStatement(
            id=data.get("id", ""),
            patient_id=patient_id,
            medication_code=medication.get("code", ""),
            medication_display=medication.get("display", ""),
            status=data.get("status", ""),
            effective_datetime=self._parse_datetime(data.get("effectiveDateTime")),
            raw_data=data,
        )

    def _parse_procedure(self, data: Dict[str, Any]) -> FHIRProcedure:
        """Parse FHIR Procedure resource."""
        code = data.get("code", {}).get("coding", [{}])[0]
        patient_ref = data.get("subject", {}).get("reference", "")
        patient_id = patient_ref.split("/")[-1] if "/" in patient_ref else ""

        return FHIRProcedure(
            id=data.get("id", ""),
            patient_id=patient_id,
            code=code.get("code", ""),
            display=code.get("display", ""),
            status=data.get("status", ""),
            performed_datetime=self._parse_datetime(data.get("performedDateTime")),
            raw_data=data,
        )

    def _parse_care_plan(self, data: Dict[str, Any]) -> FHIRCarePlan:
        """Parse FHIR CarePlan resource."""
        patient_ref = data.get("subject", {}).get("reference", "")
        patient_id = patient_ref.split("/")[-1] if "/" in patient_ref else ""

        return FHIRCarePlan(
            id=data.get("id", ""),
            patient_id=patient_id,
            status=data.get("status", ""),
            intent=data.get("intent", ""),
            title=data.get("title", ""),
            description=data.get("description", ""),
            created=self._parse_datetime(data.get("created")),
            raw_data=data,
        )

    def _parse_datetime(self, date_str: Optional[str]) -> Optional[datetime]:
        """Parse ISO 8601 datetime string.

        Args:
            date_str: ISO 8601 datetime string

        Returns:
            Parsed datetime or None
        """
        if not date_str:
            return None

        try:
            # Handle various ISO 8601 formats
            if "T" in date_str:
                # Full datetime
                return datetime.fromisoformat(date_str.replace("Z", "+00:00"))
            else:
                # Date only
                return datetime.fromisoformat(date_str)
        except (ValueError, AttributeError):
            logger.warning(f"Failed to parse datetime: {date_str}")
            return None
