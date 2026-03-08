"""Circuit breaker pattern implementation for EMR integration."""

import time
from enum import Enum
from threading import Lock
from typing import Callable, Optional, TypeVar

from src.utils.logger import get_logger

logger = get_logger(__name__)

T = TypeVar("T")


class CircuitState(str, Enum):
    """Circuit breaker states."""

    CLOSED = "closed"  # Normal operation
    OPEN = "open"  # Circuit is open, requests fail fast
    HALF_OPEN = "half_open"  # Testing if service recovered


class CircuitBreakerError(Exception):
    """Exception raised when circuit breaker is open."""

    pass


class CircuitBreaker:
    """Circuit breaker for protecting against cascading failures.

    The circuit breaker monitors failures and opens the circuit after a threshold
    is reached. When open, requests fail fast without attempting the operation.
    After a timeout, the circuit enters half-open state to test recovery.
    """

    def __init__(
        self,
        failure_threshold: int = 5,
        timeout_seconds: int = 60,
        name: str = "circuit_breaker",
    ):
        """Initialize circuit breaker.

        Args:
            failure_threshold: Number of consecutive failures before opening circuit
            timeout_seconds: Time to wait before attempting recovery (half-open state)
            name: Name for logging purposes
        """
        self.failure_threshold = failure_threshold
        self.timeout_seconds = timeout_seconds
        self.name = name

        self._state = CircuitState.CLOSED
        self._failure_count = 0
        self._last_failure_time: Optional[float] = None
        self._lock = Lock()

        logger.info(
            f"Circuit breaker '{name}' initialized",
            extra={
                "circuit_breaker": name,
                "failure_threshold": failure_threshold,
                "timeout_seconds": timeout_seconds,
            },
        )

    @property
    def state(self) -> CircuitState:
        """Get current circuit state."""
        with self._lock:
            return self._state

    @property
    def failure_count(self) -> int:
        """Get current failure count."""
        with self._lock:
            return self._failure_count

    def call(self, func: Callable[[], T]) -> T:
        """Execute function with circuit breaker protection.

        Args:
            func: Function to execute

        Returns:
            Result of function execution

        Raises:
            CircuitBreakerError: If circuit is open
            Exception: Any exception raised by the function
        """
        with self._lock:
            if self._state == CircuitState.OPEN:
                # Check if timeout has elapsed
                if (
                    self._last_failure_time
                    and time.time() - self._last_failure_time >= self.timeout_seconds
                ):
                    logger.info(
                        f"Circuit breaker '{self.name}' entering half-open state",
                        extra={"circuit_breaker": self.name, "state": "half_open"},
                    )
                    self._state = CircuitState.HALF_OPEN
                else:
                    logger.warning(
                        f"Circuit breaker '{self.name}' is open, failing fast",
                        extra={
                            "circuit_breaker": self.name,
                            "state": "open",
                            "failure_count": self._failure_count,
                        },
                    )
                    raise CircuitBreakerError(
                        f"Circuit breaker '{self.name}' is open. Service unavailable."
                    )

        # Execute function
        try:
            result = func()
            self._on_success()
            return result
        except Exception as e:
            self._on_failure()
            raise

    def _on_success(self) -> None:
        """Handle successful execution."""
        with self._lock:
            if self._state == CircuitState.HALF_OPEN:
                logger.info(
                    f"Circuit breaker '{self.name}' closing after successful test",
                    extra={"circuit_breaker": self.name, "state": "closed"},
                )
            self._state = CircuitState.CLOSED
            self._failure_count = 0
            self._last_failure_time = None

    def _on_failure(self) -> None:
        """Handle failed execution."""
        with self._lock:
            self._failure_count += 1
            self._last_failure_time = time.time()

            if self._state == CircuitState.HALF_OPEN:
                # Failed during recovery test, reopen circuit
                logger.warning(
                    f"Circuit breaker '{self.name}' reopening after failed recovery test",
                    extra={
                        "circuit_breaker": self.name,
                        "state": "open",
                        "failure_count": self._failure_count,
                    },
                )
                self._state = CircuitState.OPEN
            elif self._failure_count >= self.failure_threshold:
                # Threshold reached, open circuit
                logger.error(
                    f"Circuit breaker '{self.name}' opening due to failure threshold",
                    extra={
                        "circuit_breaker": self.name,
                        "state": "open",
                        "failure_count": self._failure_count,
                        "threshold": self.failure_threshold,
                    },
                )
                self._state = CircuitState.OPEN

    def reset(self) -> None:
        """Manually reset circuit breaker to closed state."""
        with self._lock:
            logger.info(
                f"Circuit breaker '{self.name}' manually reset",
                extra={"circuit_breaker": self.name, "state": "closed"},
            )
            self._state = CircuitState.CLOSED
            self._failure_count = 0
            self._last_failure_time = None
