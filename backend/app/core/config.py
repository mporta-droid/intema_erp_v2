from functools import lru_cache

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file="../.env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "INTEMA ERP/MES"
    environment: str = "local"
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    backend_cors_origins: list[str] = [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost",
        "http://localhost:8000",
    ]

    database_url: str = "postgresql+psycopg://intema_app:cambiar_esta_clave@localhost:5432/intema_erp"

    jwt_secret_key: str = "cambiar_por_un_valor_largo_y_aleatorio"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_minutes: int = 720

    admin_full_name: str = "Administrador INTEMA"
    admin_username: str = "admin"
    admin_email: str = "admin@intema.local"
    admin_password: str = "Cambiar123!"

    @field_validator("backend_cors_origins", mode="before")
    @classmethod
    def parse_cors(cls, value: str | list[str]) -> list[str]:
        if isinstance(value, str):
            return [item.strip() for item in value.split(",") if item.strip()]
        return value

    @model_validator(mode="after")
    def validate_production_settings(self) -> "Settings":
        if self.environment.strip().lower() not in {"production", "prod"}:
            return self

        errors: list[str] = []
        if len(self.jwt_secret_key.strip()) < 32:
            errors.append("JWT_SECRET_KEY debe tener al menos 32 caracteres en producción.")
        if self.jwt_secret_key == "cambiar_por_un_valor_largo_y_aleatorio":
            errors.append("JWT_SECRET_KEY conserva el valor predeterminado.")
        if self.admin_password == "Cambiar123!":
            errors.append("ADMIN_PASSWORD conserva la contraseña predeterminada.")
        if "cambiar_esta_clave" in self.database_url:
            errors.append("DATABASE_URL conserva la contraseña de ejemplo.")
        if not self.backend_cors_origins or "*" in self.backend_cors_origins:
            errors.append("BACKEND_CORS_ORIGINS debe contener orígenes explícitos en producción.")
        if errors:
            raise ValueError("Configuración insegura para producción: " + " ".join(errors))
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
