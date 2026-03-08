"""Embedding generation service for RAG system."""

from typing import List
import numpy as np

from src.utils.logger import get_logger

logger = get_logger(__name__)


class EmbeddingService:
    """Generates embeddings for text using clinical domain-adapted models."""

    def __init__(self, model_name: str = "clinical-embeddings-v1"):
        """Initialize embedding service.

        Args:
            model_name: Name of the embedding model to use
        """
        self.model_name = model_name
        self.embedding_dim = 384  # Typical dimension for sentence transformers
        logger.info(f"EmbeddingService initialized with model: {model_name}")

    def generate_embedding(self, text: str) -> List[float]:
        """Generate embedding for a single text.

        Args:
            text: Text to embed

        Returns:
            Embedding vector as list of floats
        """
        # In production, this would call a real embedding model
        # For now, return a mock embedding based on text hash
        logger.debug(f"Generating embedding for text of length {len(text)}")

        # Mock implementation: generate deterministic embedding from text
        # This ensures same text always gets same embedding
        embedding = self._mock_embedding(text)

        logger.debug(f"Generated embedding with dimension {len(embedding)}")
        return embedding

    def generate_embeddings_batch(self, texts: List[str]) -> List[List[float]]:
        """Generate embeddings for multiple texts in batch.

        Args:
            texts: List of texts to embed

        Returns:
            List of embedding vectors
        """
        logger.info(f"Generating embeddings for batch of {len(texts)} texts")

        embeddings = [self.generate_embedding(text) for text in texts]

        logger.info(f"Generated {len(embeddings)} embeddings")
        return embeddings

    def _mock_embedding(self, text: str) -> List[float]:
        """Generate mock embedding for testing.

        Creates a deterministic embedding based on text content.

        Args:
            text: Text to embed

        Returns:
            Mock embedding vector
        """
        # Use text hash as seed for reproducibility
        seed = hash(text) % (2**32)
        rng = np.random.RandomState(seed)

        # Generate random embedding
        embedding = rng.randn(self.embedding_dim)

        # Normalize to unit length (common for embeddings)
        norm = np.linalg.norm(embedding)
        if norm > 0:
            embedding = embedding / norm

        return embedding.tolist()

    def compute_similarity(self, embedding1: List[float], embedding2: List[float]) -> float:
        """Compute cosine similarity between two embeddings.

        Args:
            embedding1: First embedding vector
            embedding2: Second embedding vector

        Returns:
            Cosine similarity score normalized to [0, 1] range
        """
        # Convert to numpy arrays
        vec1 = np.array(embedding1)
        vec2 = np.array(embedding2)

        # Compute cosine similarity
        dot_product = np.dot(vec1, vec2)
        norm1 = np.linalg.norm(vec1)
        norm2 = np.linalg.norm(vec2)

        if norm1 == 0 or norm2 == 0:
            return 0.0

        similarity = dot_product / (norm1 * norm2)
        
        # Normalize from [-1, 1] to [0, 1] range
        normalized_similarity = (similarity + 1.0) / 2.0
        
        return float(normalized_similarity)
