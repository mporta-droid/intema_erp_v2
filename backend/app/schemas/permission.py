from uuid import UUID

from pydantic import BaseModel, ConfigDict


class PermissionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    module: str
    action: str
    code: str
    description: str


class PermissionOverrideIn(BaseModel):
    permission_id: UUID
    allowed: bool
    reason: str | None = None


class PermissionOverrideRead(BaseModel):
    permission_id: UUID
    code: str
    allowed: bool
    reason: str | None = None