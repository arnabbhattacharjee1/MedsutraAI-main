"""
Data models for ontology grounding.
"""
from dataclasses import dataclass
from typing import List, Literal


OntologyType = Literal['SNOMED_CT', 'ICD10', 'LOINC', 'RXNORM']


@dataclass
class OntologyGroundingInput:
    """Input for ontology grounding service."""
    term: str
    context: str  # Surrounding text for disambiguation
    ontology: OntologyType


@dataclass
class Alternative:
    """Alternative ontology match."""
    ontology_code: str
    ontology_term: str
    confidence: float


@dataclass
class OntologyGroundingOutput:
    """Output from ontology grounding service."""
    grounded: bool
    ontology_code: str
    ontology_term: str
    confidence: float
    alternatives: List[Alternative]
