"""
Ontology grounding service for mapping medical terms to standardized clinical ontologies.

Supports SNOMED CT, ICD-10, LOINC, and RxNorm ontologies.
Uses exact matching, fuzzy matching, and semantic similarity.
"""
import re
from typing import List, Dict, Set
from difflib import SequenceMatcher

from src.models.ontology import (
    OntologyGroundingInput,
    OntologyGroundingOutput,
    Alternative,
    OntologyType
)
from src.utils.logger import get_logger

logger = get_logger(__name__)


class OntologyGroundingService:
    """Service for grounding medical terms to clinical ontologies."""
    
    # Mock ontology databases - in production, these would be loaded from actual ontology files
    SNOMED_CT_DB: Dict[str, str] = {
        "diabetes mellitus": "73211009",
        "diabetes": "73211009",  # Also include single word
        "hypertension": "38341003",
        "myocardial infarction": "22298006",
        "pneumonia": "233604007",
        "asthma": "195967001",
        "copd": "13645005",
        "chronic obstructive pulmonary disease": "13645005",
        "heart failure": "84114007",
        "atrial fibrillation": "49436004",
        "stroke": "230690007",
        "cancer": "363346000",
        "malignancy": "363346000",
        "tumor": "108369006",
        "mass": "300848003",
        "lesion": "52988006",
        "nodule": "27925004",
        "opacity": "125149003",
        "fracture": "125605004",
        "infection": "40733004",
        "inflammation": "257552002",
    }
    
    ICD10_DB: Dict[str, str] = {
        "diabetes mellitus": "E11",
        "type 2 diabetes": "E11.9",
        "hypertension": "I10",
        "essential hypertension": "I10",
        "myocardial infarction": "I21",
        "acute myocardial infarction": "I21.9",
        "pneumonia": "J18.9",
        "asthma": "J45",
        "copd": "J44.9",
        "chronic obstructive pulmonary disease": "J44.9",
        "heart failure": "I50",
        "atrial fibrillation": "I48",
        "stroke": "I64",
        "cerebrovascular accident": "I64",
        "cancer": "C80",
        "malignant neoplasm": "C80.1",
        "fracture": "S02",
        "infection": "A49.9",
    }
    
    LOINC_DB: Dict[str, str] = {
        "glucose": "2345-7",
        "blood glucose": "2345-7",
        "hemoglobin": "718-7",
        "hematocrit": "4544-3",
        "white blood cell count": "6690-2",
        "wbc": "6690-2",
        "platelet count": "777-3",
        "creatinine": "2160-0",
        "blood urea nitrogen": "3094-0",
        "bun": "3094-0",
        "sodium": "2951-2",
        "potassium": "2823-3",
        "chloride": "2075-0",
        "bicarbonate": "1963-8",
        "calcium": "17861-6",
        "albumin": "1751-7",
        "total protein": "2885-2",
        "alt": "1742-6",
        "ast": "1920-8",
        "alkaline phosphatase": "6768-6",
        "bilirubin": "1975-2",
    }
    
    RXNORM_DB: Dict[str, str] = {
        "metformin": "6809",
        "insulin": "5856",
        "lisinopril": "29046",
        "amlodipine": "17767",
        "atorvastatin": "83367",
        "simvastatin": "36567",
        "aspirin": "1191",
        "clopidogrel": "32968",
        "warfarin": "11289",
        "levothyroxine": "10582",
        "omeprazole": "7646",
        "albuterol": "435",
        "prednisone": "8640",
        "amoxicillin": "723",
        "azithromycin": "18631",
        "ciprofloxacin": "2551",
        "furosemide": "4603",
        "hydrochlorothiazide": "5487",
        "losartan": "52175",
        "metoprolol": "6918",
    }
    
    def __init__(self):
        """Initialize the ontology grounding service."""
        self.ontology_databases = {
            'SNOMED_CT': self.SNOMED_CT_DB,
            'ICD10': self.ICD10_DB,
            'LOINC': self.LOINC_DB,
            'RXNORM': self.RXNORM_DB,
        }
        logger.info("OntologyGroundingService initialized")
    
    def ground_term(self, input_data: OntologyGroundingInput) -> OntologyGroundingOutput:
        """
        Ground a medical term to a clinical ontology.
        
        Args:
            input_data: Input containing term, context, and target ontology
            
        Returns:
            OntologyGroundingOutput with grounding results
        """
        logger.info(f"Grounding term '{input_data.term}' to {input_data.ontology}")
        
        # Normalize the term
        normalized_term = self._normalize_term(input_data.term)
        
        # Get the appropriate ontology database
        ontology_db = self.ontology_databases.get(input_data.ontology, {})
        
        # Try exact matching first
        exact_match = self._exact_match(normalized_term, ontology_db)
        if exact_match:
            logger.info(f"Exact match found: {exact_match}")
            return OntologyGroundingOutput(
                grounded=True,
                ontology_code=exact_match['code'],
                ontology_term=exact_match['term'],
                confidence=1.0,
                alternatives=[]
            )
        
        # Try fuzzy matching
        fuzzy_matches = self._fuzzy_match(normalized_term, ontology_db, threshold=0.7)
        
        if fuzzy_matches:
            # Sort by confidence (descending)
            fuzzy_matches.sort(key=lambda x: x['confidence'], reverse=True)
            best_match = fuzzy_matches[0]
            
            # Create alternatives from remaining matches
            alternatives = [
                Alternative(
                    ontology_code=match['code'],
                    ontology_term=match['term'],
                    confidence=match['confidence']
                )
                for match in fuzzy_matches[1:5]  # Top 4 alternatives
            ]
            
            # If confidence is below 0.7, flag as ungrounded
            if best_match['confidence'] < 0.7:
                logger.warning(f"Low confidence match for '{input_data.term}': {best_match['confidence']}")
                return OntologyGroundingOutput(
                    grounded=False,
                    ontology_code="",
                    ontology_term="",
                    confidence=best_match['confidence'],
                    alternatives=alternatives
                )
            
            logger.info(f"Fuzzy match found: {best_match}")
            return OntologyGroundingOutput(
                grounded=True,
                ontology_code=best_match['code'],
                ontology_term=best_match['term'],
                confidence=best_match['confidence'],
                alternatives=alternatives
            )
        
        # No match found
        logger.warning(f"No match found for term '{input_data.term}' in {input_data.ontology}")
        return OntologyGroundingOutput(
            grounded=False,
            ontology_code="",
            ontology_term="",
            confidence=0.0,
            alternatives=[]
        )
    
    def _normalize_term(self, term: str) -> str:
        """
        Normalize a medical term for matching.
        
        Args:
            term: Raw medical term
            
        Returns:
            Normalized term (lowercase, trimmed, special chars removed)
        """
        # Convert to lowercase
        normalized = term.lower().strip()
        
        # Remove extra whitespace
        normalized = re.sub(r'\s+', ' ', normalized)
        
        # Remove special characters but keep spaces and hyphens
        normalized = re.sub(r'[^\w\s-]', '', normalized)
        
        return normalized
    
    def _exact_match(self, normalized_term: str, ontology_db: Dict[str, str]) -> Dict[str, str] | None:
        """
        Perform exact string matching.
        
        Args:
            normalized_term: Normalized medical term
            ontology_db: Ontology database to search
            
        Returns:
            Match dictionary with 'term' and 'code', or None if no match
        """
        if normalized_term in ontology_db:
            return {
                'term': normalized_term,
                'code': ontology_db[normalized_term]
            }
        return None
    
    def _fuzzy_match(
        self,
        normalized_term: str,
        ontology_db: Dict[str, str],
        threshold: float = 0.7
    ) -> List[Dict[str, any]]:
        """
        Perform fuzzy matching using Levenshtein distance.
        
        Args:
            normalized_term: Normalized medical term
            ontology_db: Ontology database to search
            threshold: Minimum similarity threshold (0.0 to 1.0)
            
        Returns:
            List of matches with 'term', 'code', and 'confidence'
        """
        matches = []
        
        for ontology_term, ontology_code in ontology_db.items():
            # Calculate similarity using SequenceMatcher (Levenshtein-like)
            similarity = SequenceMatcher(None, normalized_term, ontology_term).ratio()
            
            if similarity >= threshold:
                matches.append({
                    'term': ontology_term,
                    'code': ontology_code,
                    'confidence': similarity
                })
        
        return matches
    
    def ground_terms_in_text(
        self,
        text: str,
        ontology: OntologyType,
        context_window: int = 50
    ) -> List[OntologyGroundingOutput]:
        """
        Ground all medical terms found in a text.
        
        Args:
            text: Clinical text to process
            ontology: Target ontology
            context_window: Number of characters around term for context
            
        Returns:
            List of grounding results for all identified terms
        """
        # Simple term extraction - in production, use NER
        # For now, extract potential medical terms (words with 3+ chars)
        words = re.findall(r'\b\w{3,}\b', text.lower())
        
        # Remove duplicates while preserving order
        seen: Set[str] = set()
        unique_words = []
        for word in words:
            if word not in seen:
                seen.add(word)
                unique_words.append(word)
        
        results = []
        for term in unique_words:
            # Get context around the term
            term_pos = text.lower().find(term)
            if term_pos != -1:
                start = max(0, term_pos - context_window)
                end = min(len(text), term_pos + len(term) + context_window)
                context = text[start:end]
            else:
                context = ""
            
            input_data = OntologyGroundingInput(
                term=term,
                context=context,
                ontology=ontology
            )
            
            result = self.ground_term(input_data)
            if result.grounded or result.confidence > 0.0:
                results.append(result)
        
        return results
