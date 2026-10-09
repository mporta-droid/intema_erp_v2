from datetime import datetime

from sqlalchemy import DateTime, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import UuidPkMixin


class Permission(UuidPkMixin, Base):
    __tablename__ = "permissions"
    __table_args__ = (
        UniqueConstraint("module", "action", name="uq_permissions_module_action"),
        UniqueConstraint("code", name="uq_permissions_code"),
    )

    module: Mapped[str] = mapped_column(String(80), index=True)
    action: Mapped[str] = mapped_column(String(80))
    code: Mapped[str] = mapped_column(String(160))
    description: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    role_links = relationship("RolePermission", back_populates="permission", cascade="all, delete-orphan")
    user_links = relationship("UserPermission", back_populates="permission", cascade="all, delete-orphan")