"""Patient data models."""

from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field


class Language(str, Enum):
    """Supported languages for patient communication."""

    ENGLISH = "ENGLISH"
    HINDI = "HINDI"
    REGIONAL = "REGIONAL"


class Gender(str, Enum):
    """Patient gender."""

    MALE = "Male"
    FEMALE = "Female"
    OTHER = "Other"


class Demographics(BaseModel):
    """Patient demographic information."""

    age: int = Field(..., ge=0, le=150, description="Patient age in years")
    gender: Gender = Field(..., description="Patient gender")
    language_preference: Language = Field(
        default=Language.ENGLISH, description="Preferred language for communication"
    )
    geographic_region: str = Field(..., description="Geographic region of patient")


class Patient(BaseModel):
    """Patient data model with demographics and identifiers."""

    patient_id: str = Field(..., description="Unique patient identifier")
    demographics: Demographics = Field(..., description="Patient demographic information")
    medical_record_number: str = Field(..., description="Medical record number")
    emr_system_id: str = Field(..., description="EMR system identifier")

    class Config:
        """Pydantic configuration."""

        json_schema_extra = {
            "example": {
                "patient_id": "P123456",
                "demographics": {
                    "age": 45,
                    "gender": "Female",
                    "language_preference": "ENGLISH",
                    "geographic_region": "Mumbai",
                },
                "medical_record_number": "MRN789012",
                "emr_system_id": "EMR-001",
            }
        }
