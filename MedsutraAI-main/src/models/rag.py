"""RAG system data models."""

from datetime import datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, Field


class SourceType(str, Enum):
    """Knowledge source types."""

    CLINICAL_GUIDELINE = "CLINICAL_GUIDELINE"
    TREATMENT_PROTOCOL = "TREATMENT_PROTOCOL"
    DRUG_FORMULARY = "DRUG_FORMULARY"
    INSTITUTIONAL_POLICY = "INSTITUTIONAL_POLICY"
    NCCN_GUIDELINE = "NCCN_GUIDELINE"
    ICMR_GUIDELINE = "ICMR_GUIDELINE"


class KnowledgeSource(BaseModel):
    """Hospital-approved knowledge source."""

    source_id: str = Field(..., description="Unique source identifier")
    source_name: str = Field(..., description="Human-readable source name")
    source_type: SourceType = Field(..., description="Type of knowledge source")
    approved_by: str = Field(..., description="Administrator who approved this source")
    approval_date: datetime = Field(..., description="Date of approval")
    version: str = Field(..., description="Source version")
    content_hash: str = Field(..., description="Hash of source content for integrity")
    active: bool = Field(default=True, description="Whether source is currently active")
    last_updated: datetime = Field(..., description="Last update timestamp")


class DocumentChunk(BaseModel):
    """Chunked document for vector storage."""

    chunk_id: str = Field(..., description="Unique chunk identifier")
    source_id: str = Field(..., description="Parent knowledge source ID")
    content: str = Field(..., description="Chunk text content")
    chunk_index: int = Field(..., description="Position in original document")
    metadata: dict = Field(default_factory=dict, description="Additional metadata")
    embedding: Optional[List[float]] = Field(None, description="Vector embedding")


class SourceCitation(BaseModel):
    """Citation to a knowledge source."""

    source_id: str = Field(..., description="Knowledge source identifier")
    source_name: str = Field(..., description="Source name")
    section: Optional[str] = Field(None, description="Section within source")
    page_number: Optional[int] = Field(None, description="Page number if applicable")
    excerpt: str = Field(..., description="Relevant text excerpt")
    relevance_score: float = Field(..., ge=0.0, le=1.0, description="Relevance score")


class RAGQuery(BaseModel):
    """Query for RAG retrieval."""

    query_text: str = Field(..., description="Query text")
    top_k: int = Field(default=5, ge=1, description="Number of results to retrieve")
    filters: Optional[dict] = Field(None, description="Optional metadata filters")


class RAGResult(BaseModel):
    """Result from RAG retrieval."""

    query: str = Field(..., description="Original query")
    citations: List[SourceCitation] = Field(..., description="Retrieved source citations")
    has_sufficient_information: bool = Field(
        ..., description="Whether query can be answered from sources"
    )
    retrieval_time_ms: float = Field(..., description="Retrieval time in milliseconds")


class RAGAuditLog(BaseModel):
    """Audit log entry for RAG retrieval."""

    log_id: str = Field(..., description="Unique log identifier")
    timestamp: datetime = Field(..., description="Retrieval timestamp")
    query: str = Field(..., description="Query text")
    user_id: Optional[str] = Field(None, description="User who made the query")
    sources_retrieved: List[str] = Field(..., description="List of source IDs retrieved")
    retrieval_time_ms: float = Field(..., description="Retrieval time")
