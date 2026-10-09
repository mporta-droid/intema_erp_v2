from sqlalchemy.orm import Session

from app.models.permission import Permission
from app.models.user import User


def effective_permission_codes(user: User) -> set[str]:
    codes: set[str] = set()

    for user_role in user.role_links:
        if not user_role.role.is_active:
            continue
        for role_permission in user_role.role.permission_links:
            codes.add(role_permission.permission.code)

    for override in user.permission_links:
        if override.allowed:
            codes.add(override.permission.code)
        else:
            codes.discard(override.permission.code)

    return codes


def has_permission(user: User, permission_code: str) -> bool:
    return permission_code in effective_permission_codes(user)


def permission_by_code(db: Session, code: str) -> Permission | None:
    return db.query(Permission).filter(Permission.code == code).one_or_none()