from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.permission import PermissionOverrideIn, PermissionOverrideRead


class UserBase(BaseModel):
    full_name: str = Field(min_length=3, max_length=160)
    username: str = Field(min_length=3, max_length=80, pattern=r"^[a-zA-Z0-9._-]+$")
    email: str | None = Field(default=None, max_length=160)
    position_area: str | None = Field(default=None, max_length=120)
    is_active: bool = True
    photo_url: str | None = Field(default=None, max_length=500)


class UserCreate(UserBase):
    password: str = Field(min_length=8, max_length=128)
    role_ids: list[UUID] = Field(default_factory=list)
    permission_overrides: list[PermissionOverrideIn] = Field(default_factory=list)

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        if not any(char.isupper() for char in value):
            raise ValueError("La contraseña debe incluir al menos una mayúscula.")
        if not any(char.islower() for char in value):
            raise ValueError("La contraseña debe incluir al menos una minúscula.")
        if not any(char.isdigit() for char in value):
            raise ValueError("La contraseña debe incluir al menos un número.")
        return value


class UserUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=3, max_length=160)
    email: str | None = Field(default=None, max_length=160)
    position_area: str | None = Field(default=None, max_length=120)
    is_active: bool | None = None
    photo_url: str | None = Field(default=None, max_length=500)
    password: str | None = Field(default=None, min_length=8, max_length=128)


class RoleSummary(BaseModel):
    id: UUID
    name: str


class UserRead(UserBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
    updated_at: datetime
    last_login_at: datetime | None = None
    created_by_id: UUID | None = None
    roles: list[RoleSummary] = Field(default_factory=list)
    permission_overrides: list[PermissionOverrideRead] = Field(default_factory=list)
    effective_permissions: list[str] = Field(default_factory=list)


class AssignRolesRequest(BaseModel):
    role_ids: list[UUID] = Field(default_factory=list)


class AssignPermissionsRequest(BaseModel):
    overrides: list[PermissionOverrideIn] = Field(default_factory=list)
