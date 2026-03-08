"""Application settings and configuration management."""

import os
from enum import Enum
from functools import lru_cache
from typing import Optional
from pydantic import Field
from pydantic_settings import BaseSettings


class Environment(str, Enum):
    """Application environment."""

    DEVELOPMENT = "development"
    TESTING = "testing"
    STAGING = "staging"
    PRODUCTION = "production"


class Settings(BaseSettings):
    """Application settings with environment-specific configuration."""

    # Application settings
    app_name: str = Field(default="Clinical AI Capabilities", description="Application name")
    environment: Environment = Field(
        default=Environment.DEVELOPMENT, description="Application environment"
    )
    debug: bool = Field(default=False, description="Debug mode")

    # Logging settings
    log_level: str = Field(default="INFO", description="Logging level")
    log_format: str = Field(
        default="json", description="Log format (json or text)", pattern="^(json|text)$"
    )

    # AI Model settings
    clinical_llm_model: str = Field(
        default="clinical-llm-v1", description="Clinical LLM model identifier"
    )
    vision_model: str = Field(default="vision-transformer-v1", description="Vision model identifier")
    model_timeout_seconds: int = Field(default=30, ge=1, description="Model inference timeout")

    # Performance settings
    summarization_timeout_seconds: int = Field(
        default=30, ge=1, description="Summarization timeout"
    )
    radiology_text_timeout_seconds: int = Field(
        default=10, ge=1, description="Radiology text analysis timeout"
    )
    radiology_multimodal_timeout_seconds: int = Field(
        default=30, ge=1, description="Radiology multimodal analysis timeout"
    )
    documentation_timeout_seconds: int = Field(
        default=20, ge=1, description="Documentation generation timeout"
    )
    workflow_timeout_seconds: int = Field(
        default=5, ge=1, description="Workflow suggestion timeout"
    )

    # EMR Integration settings
    emr_fhir_base_url: Optional[str] = Field(
        default=None, description="EMR FHIR API base URL"
    )
    emr_api_timeout_seconds: int = Field(default=10, ge=1, description="EMR API timeout")
    emr_retry_attempts: int = Field(default=3, ge=1, description="EMR API retry attempts")
    emr_circuit_breaker_threshold: int = Field(
        default=5, ge=1, description="Circuit breaker failure threshold"
    )
    emr_circuit_breaker_timeout_seconds: int = Field(
        default=60, ge=1, description="Circuit breaker timeout"
    )

    # RAG System settings
    vector_store_url: Optional[str] = Field(default=None, description="Vector store URL")
    embedding_model: str = Field(
        default="clinical-embeddings-v1", description="Embedding model identifier"
    )
    rag_chunk_size: int = Field(default=512, ge=1, description="RAG chunk size in tokens")
    rag_chunk_overlap: int = Field(default=50, ge=0, description="RAG chunk overlap in tokens")
    rag_top_k: int = Field(default=5, ge=1, description="Number of top results to retrieve")

    # Security settings
    encryption_key: Optional[str] = Field(default=None, description="Encryption key for data at rest")
    tls_version: str = Field(default="1.3", description="Minimum TLS version")
    audit_log_retention_days: int = Field(
        default=2555, ge=1, description="Audit log retention (7 years = 2555 days)"
    )

    # Performance monitoring
    metrics_collection_interval_seconds: int = Field(
        default=604800, ge=1, description="Metrics collection interval (weekly = 604800 seconds)"
    )
    performance_degradation_threshold: float = Field(
        default=0.10, ge=0.0, le=1.0, description="Performance degradation alert threshold"
    )
    bias_detection_threshold: float = Field(
        default=0.15, ge=0.0, le=1.0, description="Bias detection alert threshold"
    )

    # Compliance settings
    hipaa_compliance_enabled: bool = Field(default=True, description="HIPAA compliance mode")
    dpdp_compliance_enabled: bool = Field(default=True, description="DPDP Act compliance mode")
    data_breach_alert_timeout_seconds: int = Field(
        default=60, ge=1, description="Data breach alert timeout"
    )

    class Config:
        """Pydantic settings configuration."""

        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


@lru_cache()
def get_settings() -> Settings:
    """Get cached application settings.

    Returns:
        Settings: Application settings instance
    """
    return Settings()
