"""Document processor for RAG system - handles PDF/text parsing and semantic chunking."""

import hashlib
import re
from typing import List, Optional
from uuid import uuid4

from src.models.rag import DocumentChunk, KnowledgeSource
from src.utils.logger import get_logger

logger = get_logger(__name__)


class DocumentProcessor:
    """Processes documents for RAG system ingestion."""

    def __init__(self, chunk_size: int = 512, chunk_overlap: int = 50):
        """Initialize document processor.

        Args:
            chunk_size: Size of each chunk in tokens (approximate)
            chunk_overlap: Overlap between chunks in tokens (approximate)
        """
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap
        logger.info(
            f"DocumentProcessor initialized with chunk_size={chunk_size}, "
            f"chunk_overlap={chunk_overlap}"
        )

    def parse_document(self, content: str, source: KnowledgeSource) -> str:
        """Parse document content from various formats.

        Args:
            content: Raw document content
            source: Knowledge source metadata

        Returns:
            Parsed text content
        """
        # For now, handle plain text. In production, would add PDF parsing, etc.
        logger.debug(f"Parsing document from source {source.source_id}")

        # Basic text cleaning
        text = content.strip()
        text = re.sub(r'\s+', ' ', text)  # Normalize whitespace

        logger.info(f"Parsed document from {source.source_name}, length: {len(text)} chars")
        return text

    def chunk_text(self, text: str, source_id: str) -> List[DocumentChunk]:
        """Chunk text into semantic segments.

        Uses a simple token-based chunking strategy with overlap.
        In production, could use more sophisticated semantic chunking.

        Args:
            text: Text to chunk
            source_id: Source identifier

        Returns:
            List of document chunks
        """
        logger.debug(f"Chunking text for source {source_id}")

        # Approximate tokens by splitting on whitespace
        words = text.split()
        chunks: List[DocumentChunk] = []

        # Calculate step size (chunk_size - overlap)
        step_size = max(1, self.chunk_size - self.chunk_overlap)

        chunk_index = 0
        for i in range(0, len(words), step_size):
            chunk_words = words[i : i + self.chunk_size]
            if not chunk_words:
                break

            chunk_text = ' '.join(chunk_words)

            # Extract metadata (section headers, page numbers, etc.)
            metadata = self._extract_metadata(chunk_text, chunk_index)

            chunk = DocumentChunk(
                chunk_id=str(uuid4()),
                source_id=source_id,
                content=chunk_text,
                chunk_index=chunk_index,
                metadata=metadata,
            )
            chunks.append(chunk)
            chunk_index += 1

        logger.info(f"Created {len(chunks)} chunks for source {source_id}")
        return chunks

    def _extract_metadata(self, chunk_text: str, chunk_index: int) -> dict:
        """Extract metadata from chunk text.

        Args:
            chunk_text: Chunk content
            chunk_index: Index of chunk in document

        Returns:
            Metadata dictionary
        """
        metadata = {"chunk_index": chunk_index}

        # Try to extract section headers (lines that look like headers)
        lines = chunk_text.split('.')
        if lines:
            first_line = lines[0].strip()
            # Simple heuristic: if first line is short and capitalized, it might be a header
            if len(first_line) < 100 and first_line and first_line[0].isupper():
                metadata["section"] = first_line

        # Try to extract page numbers (look for "Page X" or "p. X" patterns)
        page_match = re.search(r'(?:Page|p\.)\s*(\d+)', chunk_text, re.IGNORECASE)
        if page_match:
            metadata["page_number"] = int(page_match.group(1))

        return metadata

    def compute_content_hash(self, content: str) -> str:
        """Compute hash of content for integrity checking.

        Args:
            content: Content to hash

        Returns:
            SHA-256 hash of content
        """
        return hashlib.sha256(content.encode('utf-8')).hexdigest()

    def process_document(
        self, content: str, source: KnowledgeSource
    ) -> List[DocumentChunk]:
        """Process a complete document: parse and chunk.

        Args:
            content: Raw document content
            source: Knowledge source metadata

        Returns:
            List of document chunks ready for embedding
        """
        logger.info(f"Processing document: {source.source_name}")

        # Parse document
        parsed_text = self.parse_document(content, source)

        # Chunk text
        chunks = self.chunk_text(parsed_text, source.source_id)

        logger.info(
            f"Document processing complete: {source.source_name}, "
            f"{len(chunks)} chunks created"
        )
        return chunks
