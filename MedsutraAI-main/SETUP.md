# Clinical AI Capabilities - Setup Guide

This guide will help you set up the development environment for the Clinical AI Capabilities system.

## Prerequisites

- Python 3.9 or higher
- pip (Python package installer)
- Git (for version control)

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd clinical-ai-capabilities
```

### 2. Create Virtual Environment

Create a Python virtual environment to isolate project dependencies:

**On Windows:**
```bash
python -m venv venv
venv\Scripts\activate
```

**On macOS/Linux:**
```bash
python3 -m venv venv
source venv/bin/activate
```

You should see `(venv)` in your terminal prompt indicating the virtual environment is active.

### 3. Install Dependencies

Install the project in editable mode with development dependencies:

```bash
pip install -e ".[dev]"
```

This will install:
- Core dependencies (pydantic, python-dateutil, typing-extensions)
- Development tools (pytest, hypothesis, black, ruff, mypy)
- Testing frameworks (pytest-cov, pytest-asyncio)

### 4. Configure Environment Variables

Copy the example environment file and update with your settings:

```bash
cp .env.example .env
```

Edit `.env` and update the following critical settings:
- `EMR_FHIR_BASE_URL`: Your EMR system's FHIR API endpoint
- `VECTOR_STORE_URL`: Your vector database URL
- `ENCRYPTION_KEY`: Generate a secure encryption key for production

For development, the default values in `.env.example` will work.

### 5. Verify Installation

Run the test suite to verify everything is set up correctly:

```bash
pytest
```

You should see all tests passing. If you encounter any errors, check that:
- Your virtual environment is activated
- All dependencies are installed
- Python version is 3.9 or higher

## Project Structure

```
clinical-ai-capabilities/
├── src/                          # Source code
│   ├── config/                   # Configuration management
│   │   ├── __init__.py
│   │   └── settings.py          # Application settings
│   ├── models/                   # Core data models
│   │   ├── __init__.py
│   │   ├── patient.py           # Patient data model
│   │   ├── clinical_document.py # Clinical document model
│   │   ├── ai_inference.py      # AI inference model
│   │   └── explainability.py    # Explainability report model
│   ├── utils/                    # Utility functions
│   │   ├── __init__.py
│   │   └── logger.py            # Structured logging
│   └── __init__.py
├── tests/                        # Test suite
│   ├── unit/                     # Unit tests
│   │   ├── test_config.py
│   │   ├── test_logger.py
│   │   └── test_models.py
│   ├── property/                 # Property-based tests
│   ├── integration/              # Integration tests
│   └── conftest.py              # Pytest configuration
├── config/                       # Configuration files
│   └── README.md                # Configuration documentation
├── .env.example                 # Example environment variables
├── .gitignore                   # Git ignore rules
├── pyproject.toml               # Project metadata and dependencies
├── README.md                    # Project overview
└── SETUP.md                     # This file
```

## Development Workflow

### Running Tests

**Run all tests:**
```bash
pytest
```

**Run with coverage report:**
```bash
pytest --cov=src --cov-report=html
```

**Run specific test file:**
```bash
pytest tests/unit/test_models.py
```

**Run property-based tests only:**
```bash
pytest tests/property/
```

### Code Quality

**Format code with Black:**
```bash
black src/ tests/
```

**Lint code with Ruff:**
```bash
ruff check src/ tests/
```

**Type checking with mypy:**
```bash
mypy src/
```

### Logging

The application uses structured logging (JSON format by default). To change the log format or level, update your `.env` file:

```bash
LOG_LEVEL=DEBUG
LOG_FORMAT=text  # Use 'text' for human-readable logs in development
```

## Configuration Management

The application uses environment-based configuration with Pydantic Settings. Configuration is loaded from:

1. Environment variables
2. `.env` file (if present)
3. Default values in `src/config/settings.py`

### Key Configuration Settings

**Application Settings:**
- `ENVIRONMENT`: development, testing, staging, or production
- `DEBUG`: Enable debug mode (true/false)
- `LOG_LEVEL`: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)

**Performance Settings:**
- `SUMMARIZATION_TIMEOUT_SECONDS`: Timeout for clinical summarization (default: 30)
- `RADIOLOGY_TEXT_TIMEOUT_SECONDS`: Timeout for radiology text analysis (default: 10)
- `DOCUMENTATION_TIMEOUT_SECONDS`: Timeout for documentation generation (default: 20)

**Security Settings:**
- `ENCRYPTION_KEY`: Encryption key for data at rest
- `TLS_VERSION`: Minimum TLS version (default: 1.3)
- `AUDIT_LOG_RETENTION_DAYS`: Audit log retention period (default: 2555 days = 7 years)

**Compliance Settings:**
- `HIPAA_COMPLIANCE_ENABLED`: Enable HIPAA compliance mode (default: true)
- `DPDP_COMPLIANCE_ENABLED`: Enable DPDP Act compliance mode (default: true)

See `config/README.md` for complete configuration documentation.

## Core Data Models

The system includes the following core data models:

### Patient Model
- Patient demographics (age, gender, language preference, geographic region)
- Medical record number and EMR system ID
- Validation for age range (0-150 years)

### Clinical Document Model
- Document metadata (ID, type, author, creation date)
- Document content (text and optional structured data)
- FHIR resource mappings
- Support for multiple document types (EMR notes, lab reports, radiology reports, etc.)

### AI Inference Model
- Inference metadata (ID, component, patient ID, timestamp)
- Input and output data
- Explainability report
- Model version and inference time
- Optional clinician action (accepted, modified, rejected)

### Explainability Report Model
- Reasoning steps with evidence and confidence levels
- Evidence sources with excerpts and weights
- Confidence intervals
- Alternative interpretations
- Limitations and human review requirements

## Testing Strategy

The project uses a dual testing approach:

### Unit Tests
- Test specific examples and edge cases
- Validate error handling
- Test integration points
- Located in `tests/unit/`

### Property-Based Tests
- Test universal properties across all inputs
- Use Hypothesis for randomized testing
- Minimum 100 iterations per property test
- Located in `tests/property/`

### Test Configuration
Hypothesis is configured in `tests/conftest.py` with:
- `max_examples=100`: Minimum 100 test cases per property
- `deadline=None`: No timeout for complex tests

## Troubleshooting

### Import Errors

If you encounter import errors, ensure:
1. Virtual environment is activated
2. Package is installed in editable mode: `pip install -e ".[dev]"`
3. You're running commands from the project root directory

### Test Failures

If tests fail:
1. Check Python version: `python --version` (should be 3.9+)
2. Reinstall dependencies: `pip install -e ".[dev]"`
3. Clear pytest cache: `rm -rf .pytest_cache`
4. Check for conflicting environment variables

### Configuration Issues

If configuration is not loading:
1. Verify `.env` file exists in project root
2. Check environment variable names match those in `settings.py`
3. Ensure no syntax errors in `.env` file
4. Try setting environment variables directly in your shell

## Next Steps

After completing the setup:

1. **Review the Design Document**: See `.kiro/specs/clinical-ai-capabilities/design.md`
2. **Review the Requirements**: See `.kiro/specs/clinical-ai-capabilities/requirements.md`
3. **Check the Implementation Plan**: See `.kiro/specs/clinical-ai-capabilities/tasks.md`
4. **Start Development**: Begin implementing the AI components (Task 2 onwards)

## Additional Resources

- **Pydantic Documentation**: https://docs.pydantic.dev/
- **Pytest Documentation**: https://docs.pytest.org/
- **Hypothesis Documentation**: https://hypothesis.readthedocs.io/
- **HL7 FHIR Specification**: https://www.hl7.org/fhir/

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the configuration documentation in `config/README.md`
3. Consult the project README.md for architecture overview
4. Contact the development team

## License

See LICENSE file for details.
