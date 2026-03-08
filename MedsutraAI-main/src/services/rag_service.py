"""RAG (Retrieval-Augmented Generation) service."""

import time
from datetime import datetime
from typing import List, Optional
from uuid import uuid4

from src.models.rag import (
    DocumentChunk,
    KnowledgeSource,
    RAGAuditLog,
    RAGQuery,
    RAGResult,
    SourceCitation,
)
from src.services.document_processor import DocumentProcessor
from src.services.embedding_service import EmbeddingService
from src.services.knowledge_source_manager import KnowledgeSourceManager
from src.services.vector_store import VectorStore
from src.utils.logger import get_logger

logger = get_logger(__name__)


class RAGService:
    """RAG system for retrieving information from approved knowledge sources."""

    def __init__(
        self,
        chunk_size: int = 512,
        chunk_overlap: int = 50,
        top_k: int = 5,
        embedding_model: str = "clinical-embeddings-v1",
    ):
        """Initialize RAG service.

        Args:
            chunk_size: Size of document chunks in tokens
            chunk_overlap: Overlap between chunks in tokens
            top_k: Number of top results to retrieve
            embedding_model: Name of embedding model to use
        """
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap
        self.top_k = top_k

        # Initialize components
        self.document_processor = DocumentProcessor(chunk_size, chunk_overlap)
        self.embedding_service = EmbeddingService(embedding_model)
        self.vector_store = VectorStore(self.embedding_service)
        self.knowledge_source_manager = KnowledgeSourceManager()

        # Audit log storage (in production, would persist to database)
        self.audit_logs: List[RAGAuditLog] = []

        logger.info(
            f"RAGService initialized with chunk_size={chunk_size}, "
            f"chunk_overlap={chunk_overlap}, top_k={top_k}"
        )

    def ingest_document(self, content: str, source: KnowledgeSource) -> int:
        """Ingest a document into the RAG system.

        Args:
            content: Document content
            source: Knowledge source metadata

        Returns:
            Number of chunks created
        """
        logger.info(f"Ingesting document: {source.source_name}")

        # Process document into chunks
        chunks = self.document_processor.process_document(content, source)

        # Add chunks to vector store
        self.vector_store.add_chunks(chunks)

        logger.info(f"Document ingestion complete: {len(chunks)} chunks created")
        return len(chunks)

    def retrieve(
        self,
        query: RAGQuery,
        user_id: Optional[str] = None,
        use_hybrid_search: bool = True,
    ) -> RAGResult:
        """Retrieve relevant information from approved knowledge sources.

        Args:
            query: RAG query
            user_id: Optional user identifier for audit logging
            use_hybrid_search: Whether to use hybrid search (semantic + keyword)

        Returns:
            RAG result with citations
        """
        start_time = time.time()
        logger.info(f"Processing RAG query: {query.query_text[:100]}...")

        # Get approved source IDs
        approved_source_ids = self.knowledge_source_manager.get_approved_source_ids()

        if not approved_source_ids:
            logger.warning("No approved knowledge sources available")
            return RAGResult(
                query=query.query_text,
                citations=[],
                has_sufficient_information=False,
                retrieval_time_ms=0.0,
            )

        # Perform search
        if use_hybrid_search:
            results = self.vector_store.hybrid_search(
                query.query_text,
                top_k=query.top_k,
                source_filter=approved_source_ids,
            )
        else:
            results = self.vector_store.search(
                query.query_text,
                top_k=query.top_k,
                source_filter=approved_source_ids,
            )

        # Convert to citations
        citations = self._create_citations(results)

        # Determine if we have sufficient information
        # Consider sufficient if we have at least one result with decent relevance
        has_sufficient_info = len(citations) > 0 and citations[0].relevance_score > 0.3

        retrieval_time_ms = (time.time() - start_time) * 1000

        result = RAGResult(
            query=query.query_text,
            citations=citations,
            has_sufficient_information=has_sufficient_info,
            retrieval_time_ms=retrieval_time_ms,
        )

        # Log retrieval for audit
        self._log_retrieval(query.query_text, user_id, citations, retrieval_time_ms)

        logger.info(
            f"RAG retrieval complete: {len(citations)} citations, "
            f"sufficient_info={has_sufficient_info}, time={retrieval_time_ms:.2f}ms"
        )

        return result

    def _create_citations(
        self, search_results: List[tuple[DocumentChunk, float]]
    ) -> List[SourceCitation]:
        """Create source citations from search results.

        Args:
            search_results: List of (chunk, score) tuples

        Returns:
            List of source citations
        """
        citations = []

        for chunk, score in search_results:
            # Get source information
            source = self.knowledge_source_manager.get_source(chunk.source_id)
            if source is None:
                logger.warning(f"Source not found for chunk: {chunk.chunk_id}")
                continue

            # Extract metadata
            section = chunk.metadata.get("section")
            page_number = chunk.metadata.get("page_number")

            # Create excerpt (truncate if too long)
            excerpt = chunk.content
            if len(excerpt) > 500:
                excerpt = excerpt[:497] + "..."

            citation = SourceCitation(
                source_id=source.source_id,
                source_name=source.source_name,
                section=section,
                page_number=page_number,
                excerpt=excerpt,
                relevance_score=score,
            )
            citations.append(citation)

        return citations

    def _log_retrieval(
        self,
        query: str,
        user_id: Optional[str],
        citations: List[SourceCitation],
        retrieval_time_ms: float,
    ) -> None:
        """Log RAG retrieval for audit purposes.

        Args:
            query: Query text
            user_id: User identifier
            citations: Retrieved citations
            retrieval_time_ms: Retrieval time in milliseconds
        """
        log_entry = RAGAuditLog(
            log_id=str(uuid4()),
            timestamp=datetime.now(),
            query=query,
            user_id=user_id,
            sources_retrieved=[c.source_id for c in citations],
            retrieval_time_ms=retrieval_time_ms,
        )

        self.audit_logs.append(log_entry)
        logger.debug(f"Logged RAG retrieval: {log_entry.log_id}")

    def get_audit_logs(
        self, user_id: Optional[str] = None, limit: int = 100
    ) -> List[RAGAuditLog]:
        """Get audit logs for RAG retrievals.

        Args:
            user_id: Optional user ID to filter by
            limit: Maximum number of logs to return

        Returns:
            List of audit log entries
        """
        logs = self.audit_logs

        if user_id:
            logs = [log for log in logs if log.user_id == user_id]

        # Return most recent logs first
        logs = sorted(logs, key=lambda x: x.timestamp, reverse=True)
        return logs[:limit]

    def format_citations(self, citations: List[SourceCitation]) -> str:
        """Format citations for display in AI-generated content.

        Args:
            citations: List of source citations

        Returns:
            Formatted citation text
        """
        if not citations:
            return ""

        formatted = "\n\nSources:\n"
        for i, citation in enumerate(citations, 1):
            parts = [f"{i}. {citation.source_name}"]

            if citation.section:
                parts.append(f"Section: {citation.section}")

            if citation.page_number:
                parts.append(f"Page: {citation.page_number}")

            formatted += ", ".join(parts) + "\n"

        return formatted
