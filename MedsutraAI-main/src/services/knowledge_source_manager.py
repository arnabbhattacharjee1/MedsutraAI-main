"""Knowledge source management for RAG system."""

from datetime import datetime
from typing import Dict, List, Optional
from uuid import uuid4

from src.models.rag import KnowledgeSource, SourceType
from src.utils.logger import get_logger

logger = get_logger(__name__)


class KnowledgeSourceManager:
    """Manages hospital-approved knowledge sources."""

    def __init__(self):
        """Initialize knowledge source manager."""
        self.sources: Dict[str, KnowledgeSource] = {}  # source_id -> source
        logger.info("KnowledgeSourceManager initialized")

    def add_source(
        self,
        source_name: str,
        source_type: SourceType,
        approved_by: str,
        version: str,
        content_hash: str,
    ) -> KnowledgeSource:
        """Add a new approved knowledge source.

        Args:
            source_name: Human-readable source name
            source_type: Type of knowledge source
            approved_by: Administrator who approved this source
            version: Source version
            content_hash: Hash of source content

        Returns:
            Created knowledge source
        """
        source_id = str(uuid4())
        now = datetime.now()

        source = KnowledgeSource(
            source_id=source_id,
            source_name=source_name,
            source_type=source_type,
            approved_by=approved_by,
            approval_date=now,
            version=version,
            content_hash=content_hash,
            active=True,
            last_updated=now,
        )

        self.sources[source_id] = source
        logger.info(f"Added knowledge source: {source_name} (ID: {source_id})")
        return source

    def remove_source(self, source_id: str) -> bool:
        """Remove a knowledge source from approved list.

        Args:
            source_id: Source identifier

        Returns:
            True if source was removed, False if not found
        """
        if source_id in self.sources:
            source = self.sources[source_id]
            del self.sources[source_id]
            logger.info(f"Removed knowledge source: {source.source_name} (ID: {source_id})")
            return True
        else:
            logger.warning(f"Attempted to remove non-existent source: {source_id}")
            return False

    def deactivate_source(self, source_id: str) -> bool:
        """Deactivate a knowledge source without removing it.

        Args:
            source_id: Source identifier

        Returns:
            True if source was deactivated, False if not found
        """
        if source_id in self.sources:
            self.sources[source_id].active = False
            self.sources[source_id].last_updated = datetime.now()
            logger.info(f"Deactivated knowledge source: {source_id}")
            return True
        else:
            logger.warning(f"Attempted to deactivate non-existent source: {source_id}")
            return False

    def activate_source(self, source_id: str) -> bool:
        """Activate a previously deactivated knowledge source.

        Args:
            source_id: Source identifier

        Returns:
            True if source was activated, False if not found
        """
        if source_id in self.sources:
            self.sources[source_id].active = True
            self.sources[source_id].last_updated = datetime.now()
            logger.info(f"Activated knowledge source: {source_id}")
            return True
        else:
            logger.warning(f"Attempted to activate non-existent source: {source_id}")
            return False

    def get_source(self, source_id: str) -> Optional[KnowledgeSource]:
        """Get a knowledge source by ID.

        Args:
            source_id: Source identifier

        Returns:
            Knowledge source if found, None otherwise
        """
        return self.sources.get(source_id)

    def get_active_sources(self) -> List[KnowledgeSource]:
        """Get all active knowledge sources.

        Returns:
            List of active knowledge sources
        """
        active = [source for source in self.sources.values() if source.active]
        logger.debug(f"Retrieved {len(active)} active sources")
        return active

    def get_all_sources(self) -> List[KnowledgeSource]:
        """Get all knowledge sources (active and inactive).

        Returns:
            List of all knowledge sources
        """
        return list(self.sources.values())

    def get_approved_source_ids(self) -> List[str]:
        """Get list of approved (active) source IDs.

        Returns:
            List of active source IDs
        """
        return [source.source_id for source in self.sources.values() if source.active]

    def is_source_approved(self, source_id: str) -> bool:
        """Check if a source is approved (exists and is active).

        Args:
            source_id: Source identifier

        Returns:
            True if source is approved and active, False otherwise
        """
        source = self.sources.get(source_id)
        return source is not None and source.active

    def update_source_version(
        self, source_id: str, new_version: str, new_content_hash: str
    ) -> bool:
        """Update source version and content hash.

        Args:
            source_id: Source identifier
            new_version: New version string
            new_content_hash: New content hash

        Returns:
            True if updated, False if source not found
        """
        if source_id in self.sources:
            self.sources[source_id].version = new_version
            self.sources[source_id].content_hash = new_content_hash
            self.sources[source_id].last_updated = datetime.now()
            logger.info(f"Updated source {source_id} to version {new_version}")
            return True
        else:
            logger.warning(f"Attempted to update non-existent source: {source_id}")
            return False
