import pytest
from pydantic import ValidationError

from app.core.config import Settings


def test_production_rejects_default_secrets() -> None:
    with pytest.raises(ValidationError, match="Configuración insegura para producción"):
        Settings(
            _env_file=None,
            environment="production",
        )


def test_production_accepts_explicit_secure_configuration() -> None:
    settings = Settings(
        _env_file=None,
        environment="production",
        jwt_secret_key="a-secure-test-secret-that-is-longer-than-32-characters",
        admin_password="Unique-Strong-Test-Password-2026!",
        database_url="postgresql+psycopg://intema_app:secure-test-password@localhost:5432/intema_erp",
        backend_cors_origins=["https://erp.example.com"],
    )

    assert settings.environment == "production"
    assert settings.backend_cors_origins == ["https://erp.example.com"]
