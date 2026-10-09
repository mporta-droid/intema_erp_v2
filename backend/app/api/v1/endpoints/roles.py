from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.db.session import get_db
from app.models.permission import Permission
from app.models.role import Role, RolePermission
from app.models.user import User
from app.schemas.role import RoleCreate, RolePermissionReplace, RoleRead, RoleUpdate
from app.services.audit import write_audit
from app.services.serializers import role_to_read

router = APIRouter()


@router.get("", response_model=list[RoleRead])
def list_roles(
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("users_permissions.view")),
) -> list[RoleRead]:
    roles = db.execute(select(Role).order_by(Role.name)).scalars().all()
    return [role_to_read(role) for role in roles]


@router.post("", response_model=RoleRead, status_code=status.HTTP_201_CREATED)
def create_role(
    payload: RoleCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("users_permissions.manage_users")),
) -> RoleRead:
    if db.execute(select(Role).where(Role.name == payload.name)).scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ya existe un rol con ese nombre.")
    role = Role(name=payload.name, description=payload.description, is_active=payload.is_active)
    db.add(role)
    db.flush()
    replace_role_permissions(db, role, payload.permission_ids)
    write_audit(db, actor=current_user, action="role_created", entity_type="roles", entity_id=str(role.id), request=request)
    db.commit()
    db.refresh(role)
    return role_to_read(role)


@router.patch("/{role_id}", response_model=RoleRead)
def update_role(
    role_id: UUID,
    payload: RoleUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("users_permissions.manage_users")),
) -> RoleRead:
    role = db.get(Role, role_id)
    if role is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Rol no encontrado.")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(role, field, value)
    write_audit(db, actor=current_user, action="role_updated", entity_type="roles", entity_id=str(role.id), request=request)
    db.commit()
    db.refresh(role)
    return role_to_read(role)


@router.put("/{role_id}/permissions", response_model=RoleRead)
def set_role_permissions(
    role_id: UUID,
    payload: RolePermissionReplace,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("users_permissions.manage_users")),
) -> RoleRead:
    role = db.get(Role, role_id)
    if role is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Rol no encontrado.")
    replace_role_permissions(db, role, payload.permission_ids)
    write_audit(
        db,
        actor=current_user,
        action="role_permissions_updated",
        entity_type="roles",
        entity_id=str(role.id),
        detail={"permission_count": len(payload.permission_ids)},
        request=request,
    )
    db.commit()
    db.refresh(role)
    return role_to_read(role)


def replace_role_permissions(db: Session, role: Role, permission_ids: list) -> None:
    permissions = db.execute(select(Permission).where(Permission.id.in_(permission_ids))).scalars().all() if permission_ids else []
    if len(permissions) != len(set(permission_ids)):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uno o más permisos no existen.")
    role.permission_links.clear()
    db.flush()
    role.permission_links.extend(RolePermission(role_id=role.id, permission_id=permission.id) for permission in permissions)