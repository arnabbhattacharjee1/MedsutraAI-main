#!/usr/bin/env python3
"""Verify that the development environment is set up correctly."""

import sys
from importlib import import_module


def check_python_version():
    """Check Python version is 3.9 or higher."""
    print("Checking Python version...")
    version = sys.version_info
    if version.major == 3 and version.minor >= 9:
        print(f"✓ Python {version.major}.{version.minor}.{version.micro} (OK)")
        return True
    else:
        print(f"✗ Python {version.major}.{version.minor}.{version.micro} (Need 3.9+)")
        return False


def check_dependencies():
    """Check that required dependencies are installed."""
    print("\nChecking dependencies...")
    dependencies = [
        "pydantic",
        "pydantic_settings",
        "pytest",
        "hypothesis",
        "black",
        "ruff",
        "mypy",
    ]
    
    all_ok = True
    for dep in dependencies:
        try:
            import_module(dep)
            print(f"✓ {dep} (installed)")
        except ImportError:
            print(f"✗ {dep} (missing)")
            all_ok = False
    
    return all_ok


def check_project_structure():
    """Check that project structure is correct."""
    print("\nChecking project structure...")
    import os
    
    required_dirs = [
        "src",
        "src/config",
        "src/models",
        "src/utils",
        "tests",
        "tests/unit",
        "tests/property",
        "tests/integration",
        "config",
    ]
    
    required_files = [
        "pyproject.toml",
        "requirements.txt",
        "requirements-dev.txt",
        ".env.example",
        ".gitignore",
        "README.md",
        "SETUP.md",
        "src/__init__.py",
        "src/config/__init__.py",
        "src/config/settings.py",
        "src/models/__init__.py",
        "src/utils/__init__.py",
        "src/utils/logger.py",
        "tests/conftest.py",
    ]
    
    all_ok = True
    
    for dir_path in required_dirs:
        if os.path.isdir(dir_path):
            print(f"✓ {dir_path}/ (exists)")
        else:
            print(f"✗ {dir_path}/ (missing)")
            all_ok = False
    
    for file_path in required_files:
        if os.path.isfile(file_path):
            print(f"✓ {file_path} (exists)")
        else:
            print(f"✗ {file_path} (missing)")
            all_ok = False
    
    return all_ok


def check_imports():
    """Check that core modules can be imported."""
    print("\nChecking core module imports...")
    modules = [
        "src.config",
        "src.models",
        "src.utils",
    ]
    
    all_ok = True
    for module in modules:
        try:
            import_module(module)
            print(f"✓ {module} (imports successfully)")
        except Exception as e:
            print(f"✗ {module} (import failed: {e})")
            all_ok = False
    
    return all_ok


def check_models():
    """Check that core models can be instantiated."""
    print("\nChecking core data models...")
    
    try:
        from src.models import Patient, Demographics, ClinicalDocument, AIInference
        from src.models.patient import Gender, Language
        from src.models.clinical_document import DocumentType, Clinician
        from datetime import datetime
        
        # Test Patient model
        demographics = Demographics(
            age=45,
            gender=Gender.FEMALE,
            language_preference=Language.ENGLISH,
            geographic_region="Test Region"
        )
        patient = Patient(
            patient_id="TEST123",
            demographics=demographics,
            medical_record_number="MRN123",
            emr_system_id="EMR123"
        )
        print("✓ Patient model (OK)")
        
        # Test ClinicalDocument model
        clinician = Clinician(
            clinician_id="C123",
            name="Dr. Test",
            role="DOCTOR"
        )
        doc = ClinicalDocument(
            document_id="DOC123",
            patient_id="TEST123",
            document_type=DocumentType.EMR_NOTE,
            author=clinician,
            created_at=datetime.now(),
            content="Test content",
            fhir_resource_type="DocumentReference",
            fhir_resource_id="FHIR123"
        )
        print("✓ ClinicalDocument model (OK)")
        
        return True
        
    except Exception as e:
        print(f"✗ Model instantiation failed: {e}")
        return False


def check_configuration():
    """Check that configuration can be loaded."""
    print("\nChecking configuration...")
    
    try:
        from src.config import get_settings
        settings = get_settings()
        print(f"✓ Configuration loaded (environment: {settings.environment})")
        return True
    except Exception as e:
        print(f"✗ Configuration loading failed: {e}")
        return False


def check_logging():
    """Check that logging is configured correctly."""
    print("\nChecking logging...")
    
    try:
        from src.utils import get_logger
        logger = get_logger("test")
        logger.info("Test log message")
        print("✓ Logging configured (OK)")
        return True
    except Exception as e:
        print(f"✗ Logging configuration failed: {e}")
        return False


def main():
    """Run all verification checks."""
    print("=" * 60)
    print("Clinical AI Capabilities - Setup Verification")
    print("=" * 60)
    
    checks = [
        ("Python Version", check_python_version),
        ("Dependencies", check_dependencies),
        ("Project Structure", check_project_structure),
        ("Module Imports", check_imports),
        ("Data Models", check_models),
        ("Configuration", check_configuration),
        ("Logging", check_logging),
    ]
    
    results = []
    for name, check_func in checks:
        try:
            result = check_func()
            results.append((name, result))
        except Exception as e:
            print(f"\n✗ {name} check failed with exception: {e}")
            results.append((name, False))
    
    print("\n" + "=" * 60)
    print("Summary")
    print("=" * 60)
    
    all_passed = True
    for name, result in results:
        status = "✓ PASS" if result else "✗ FAIL"
        print(f"{status}: {name}")
        if not result:
            all_passed = False
    
    print("=" * 60)
    
    if all_passed:
        print("\n✓ All checks passed! Your environment is ready.")
        print("\nNext steps:")
        print("  1. Review the design document: .kiro/specs/clinical-ai-capabilities/design.md")
        print("  2. Run the test suite: pytest")
        print("  3. Start implementing AI components (Task 2 onwards)")
        return 0
    else:
        print("\n✗ Some checks failed. Please review the errors above.")
        print("\nTroubleshooting:")
        print("  1. Ensure virtual environment is activated")
        print("  2. Install dependencies: pip install -e '.[dev]'")
        print("  3. Check Python version: python --version (need 3.9+)")
        print("  4. See SETUP.md for detailed setup instructions")
        return 1


if __name__ == "__main__":
    sys.exit(main())
