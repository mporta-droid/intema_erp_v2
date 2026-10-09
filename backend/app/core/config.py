from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file="../.env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "INTEMA ERP/MES"
    environment: str = "local"
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    backend_cors_origins: list[str] = ["http://localhost", "http://localhost:8000"]

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


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()