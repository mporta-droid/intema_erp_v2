from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.security import verify_password
from app.models.role import Role, RolePermission
from app.models.user import User, UserPermission, UserRole


def authenticate_user(db: Session, username_or_email: str, password: str) -> User | None:
    stmt = select(User).where(
        or_(User.username == username_or_email, User.email == username_or_email),
        User.is_active.is_(True),
    ).options(
        selectinload(User.role_links)
        .selectinload(UserRole.role)
        .selectinload(Role.permission_links)
        .selectinload(RolePermission.permission),
        selectinload(User.permission_links).selectinload(UserPermission.permission),
    )
    user = db.execute(stmt).scalar_one_or_none()
    if user is None or not verify_password(password, user.password_hash):
        return None
    user.last_login_at = datetime.now(UTC)
    return user


def get_user_by_id(db: Session, user_id: UUID) -> User | None:
    return db.get(User, user_id)
