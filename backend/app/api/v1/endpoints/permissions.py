from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.db.session import get_db
from app.models.permission import Permission
from app.models.user import User
from app.schemas.permission import PermissionRead

router = APIRouter()


@router.get("", response_model=list[PermissionRead])
def list_permissions(
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("users_permissions.view")),
) -> list[PermissionRead]:
    permissions = db.execute(select(Permission).order_by(Permission.module, Permission.action)).scalars().all()
    return list(permissions)