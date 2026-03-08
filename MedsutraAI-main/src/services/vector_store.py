"""Vector store integration for RAG system."""

from typing import List, Optional, Dict
from datetime import datetime
from uuid import uuid4

from src.models.rag import DocumentChunk, SourceCitation
from src.services.embedding_service import EmbeddingService
from src.utils.logger import get_logger

logger = get_logger(__name__)


class VectorStore:
    """Vector store for storing and retrieving document embeddings.

    In production, this would integrate with Pinecone, Weaviate, or Qdrant.
    For now, implements an in-memory vector store for testing.
    """

    def __init__(self, embedding_service: EmbeddingService):
        """Initialize vector store.

        Args:
            embedding_service: Service for generating embeddings
        """
        self.embedding_service = embedding_service
        self.chunks: Dict[str, DocumentChunk] = {}  # chunk_id -> chunk
        self.source_index: Dict[str, List[str]] = {}  # source_id -> list of chunk_ids
        logger.info("VectorStore initialized (in-memory implementation)")

    def add_chunks(self, chunks: List[DocumentChunk]) -> None:
        """Add document chunks to vector store.

        Args:
            chunks: List of document chunks to add
        """
        logger.info(f"Adding {len(chunks)} chunks to vector store")

        for chunk in chunks:
            # Generate embedding if not present
            if chunk.embedding is None:
                chunk.embedding = self.embedding_service.generate_embedding(chunk.content)

            # Store chunk
            self.chunks[chunk.chunk_id] = chunk

            # Update source index
            if chunk.source_id not in self.source_index:
                self.source_index[chunk.source_id] = []
            self.source_index[chunk.source_id].append(chunk.chunk_id)

        logger.info(f"Successfully added {len(chunks)} chunks to vector store")

    def search(
        self,
        query_text: str,
        top_k: int = 5,
        source_filter: Optional[List[str]] = None,
    ) -> List[tuple[DocumentChunk, float]]:
        """Search for relevant chunks using semantic similarity.

        Args:
            query_text: Query text
            top_k: Number of top results to return
            source_filter: Optional list of source IDs to filter by

        Returns:
            List of (chunk, similarity_score) tuples, sorted by relevance
        """
        logger.debug(f"Searching vector store for query: {query_text[:100]}...")

        # Generate query embedding
        query_embedding = self.embedding_service.generate_embedding(query_text)

        # Filter chunks by source if specified
        candidate_chunks = []
        if source_filter:
            for source_id in source_filter:
                chunk_ids = self.source_index.get(source_id, [])
                candidate_chunks.extend([self.chunks[cid] for cid in chunk_ids])
        else:
            candidate_chunks = list(self.chunks.values())

        if not candidate_chunks:
            logger.warning("No candidate chunks found for search")
            return []

        # Compute similarities
        results = []
        for chunk in candidate_chunks:
            if chunk.embedding is None:
                continue

            similarity = self.embedding_service.compute_similarity(
                query_embedding, chunk.embedding
            )
            results.append((chunk, similarity))

        # Sort by similarity (descending) and take top-k
        results.sort(key=lambda x: x[1], reverse=True)
        top_results = results[:top_k]

        logger.info(
            f"Search complete: found {len(results)} candidates, returning top {len(top_results)}"
        )
        return top_results

    def hybrid_search(
        self,
        query_text: str,
        top_k: int = 5,
        source_filter: Optional[List[str]] = None,
        semantic_weight: float = 0.7,
    ) -> List[tuple[DocumentChunk, float]]:
        """Hybrid search combining semantic and keyword matching.

        Args:
            query_text: Query text
            top_k: Number of top results to return
            source_filter: Optional list of source IDs to filter by
            semantic_weight: Weight for semantic similarity (1 - weight for keyword)

        Returns:
            List of (chunk, combined_score) tuples, sorted by relevance
        """
        logger.debug(f"Performing hybrid search for query: {query_text[:100]}...")

        # Get semantic search results
        semantic_results = self.search(query_text, top_k=top_k * 2, source_filter=source_filter)

        # Compute keyword scores
        query_keywords = set(query_text.lower().split())
        hybrid_results = []

        for chunk, semantic_score in semantic_results:
            # Compute keyword overlap score
            chunk_words = set(chunk.content.lower().split())
            keyword_overlap = len(query_keywords & chunk_words)
            keyword_score = keyword_overlap / max(len(query_keywords), 1)

            # Combine scores
            combined_score = (
                semantic_weight * semantic_score + (1 - semantic_weight) * keyword_score
            )
            hybrid_results.append((chunk, combined_score))

        # Re-sort by combined score and take top-k
        hybrid_results.sort(key=lambda x: x[1], reverse=True)
        top_results = hybrid_results[:top_k]

        logger.info(f"Hybrid search complete: returning top {len(top_results)} results")
        return top_results

    def delete_source(self, source_id: str) -> None:
        """Delete all chunks for a given source.

        Args:
            source_id: Source identifier
        """
        logger.info(f"Deleting chunks for source: {source_id}")

        chunk_ids = self.source_index.get(source_id, [])
        for chunk_id in chunk_ids:
            if chunk_id in self.chunks:
                del self.chunks[chunk_id]

        if source_id in self.source_index:
            del self.source_index[source_id]

        logger.info(f"Deleted {len(chunk_ids)} chunks for source {source_id}")

    def get_source_count(self, source_id: str) -> int:
        """Get number of chunks for a source.

        Args:
            source_id: Source identifier

        Returns:
            Number of chunks for the source
        """
        return len(self.source_index.get(source_id, []))

    def clear(self) -> None:
        """Clear all data from vector store."""
        logger.warning("Clearing all data from vector store")
        self.chunks.clear()
        self.source_index.clear()
