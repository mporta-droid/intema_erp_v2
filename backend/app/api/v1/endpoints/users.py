from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.core.config import settings
from app.core.security import hash_password
from app.db.session import get_db
from app.models.permission import Permission
from app.models.role import Role
from app.models.user import User, UserPermission, UserRole
from app.schemas.common import Message
from app.schemas.user import AssignPermissionsRequest, AssignRolesRequest, UserCreate, UserRead, UserUpdate
from app.services.audit import write_audit
from app.services.serializers import user_to_read

router = APIRouter()


def is_seed_admin(user: User) -> bool:
    return user.username == settings.admin_username


def prevent_admin_access_lock(user: User) -> None:
    if is_seed_admin(user):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El usuario administrador principal no puede quedarse sin accesos.",
        )


@router.get("", response_model=list[UserRead])
def list_users(
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("users_permissions.view")),
) -> list[UserRead]:
    users = db.execute(select(User).order_by(User.full_name)).scalars().all()
    return [user_to_read(user) for user in users]


@router.post("", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def create_user(
    payload: UserCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("users_permissions.manage_users")),
) -> UserRead:
    unique_conditions = [User.username == payload.username]
    if payload.email is not None:
        unique_conditions.append(User.email == payload.email)
    if db.execute(select(User).where(or_(*unique_conditions))).scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ya existe un usuario con ese usuario o correo.")

    user = User(
        full_name=payload.full_name,
        username=payload.username,
        email=payload.email,
        password_hash=hash_password(payload.password),
        position_area=payload.position_area,
        is_active=payload.is_active,
        photo_url=payload.photo_url,
        created_by_id=current_user.id,
    )
    db.add(user)
    db.flush()
    replace_user_roles(db, user, payload.role_ids, current_user)
    replace_user_permissions(db, user, payload.permission_overrides, current_user)
    write_audit(db, actor=current_user, action="user_created", entity_type="users", entity_id=str(user.id), request=request)
    db.commit()
    db.refresh(user)
    return user_to_read(user)


@router.get("/{user_id}", response_model=UserRead)
def get_user(
    user_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("users_permissions.view")),
) -> UserRead:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado.")
    return user_to_read(user)


@router.patch("/{user_id}", response_model=UserRead)
def update_user(
    user_id: UUID,
    payload: UserUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("users_permissions.manage_users")),
) -> UserRead:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado.")
    data = payload.model_dump(exclude_unset=True)
    if is_seed_admin(user) and data.get("is_active") is False:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El usuario administrador principal no puede desactivarse.",
        )
    password = data.pop("password", None)
    for field, value in data.items():
        setattr(user, field, value)
    if password:
        user.password_hash = hash_password(password)
    write_audit(db, actor=current_user, action="user_updated", entity_type="users", entity_id=str(user.id), request=request)
    db.commit()
    db.refresh(user)
    return user_to_read(user)


@router.post("/{user_id}/deactivate", response_model=Message)
def deactivate_user(
    user_id: UUID,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("users_permissions.manage_users")),
) -> Message:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado.")
    if is_seed_admin(user):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El usuario administrador principal no puede desactivarse.",
        )
    user.is_active = False
    write_audit(db, actor=current_user, action="user_deactivated", entity_type="users", entity_id=str(user.id), request=request)
    db.commit()
    return Message(detail="Usuario desactivado correctamente.")


@router.put("/{user_id}/roles", response_model=UserRead)
def set_user_roles(
    user_id: UUID,
    payload: AssignRolesRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("users_permissions.manage_users")),
) -> UserRead:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado.")
    prevent_admin_access_lock(user)
    replace_user_roles(db, user, payload.role_ids, current_user)
    write_audit(db, actor=current_user, action="user_roles_updated", entity_type="users", entity_id=str(user.id), request=request)
    db.commit()
    db.refresh(user)
    return user_to_read(user)


@router.put("/{user_id}/permissions", response_model=UserRead)
def set_user_permissions(
    user_id: UUID,
    payload: AssignPermissionsRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("users_permissions.manage_users")),
) -> UserRead:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado.")
    prevent_admin_access_lock(user)
    replace_user_permissions(db, user, payload.overrides, current_user)
    write_audit(
        db,
        actor=current_user,
        action="user_permissions_updated",
        entity_type="users",
        entity_id=str(user.id),
        detail={"overrides": len(payload.overrides)},
        request=request,
    )
    db.commit()
    db.refresh(user)
    return user_to_read(user)


def replace_user_roles(db: Session, user: User, role_ids: list, actor: User) -> None:
    roles = db.execute(select(Role).where(Role.id.in_(role_ids))).scalars().all() if role_ids else []
    if len(roles) != len(set(role_ids)):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uno o más roles no existen.")
    user.role_links.clear()
    db.flush()
    user.role_links.extend(UserRole(user_id=user.id, role_id=role.id, assigned_by_id=actor.id) for role in roles)


def replace_user_permissions(db: Session, user: User, overrides: list, actor: User) -> None:
    permission_ids = [override.permission_id for override in overrides]
    permissions = db.execute(select(Permission).where(Permission.id.in_(permission_ids))).scalars().all() if permission_ids else []
    if len(permissions) != len(set(permission_ids)):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uno o más permisos no existen.")
    user.permission_links.clear()
    db.flush()
    user.permission_links.extend(
        UserPermission(
            user_id=user.id,
            permission_id=override.permission_id,
            allowed=override.allowed,
            reason=override.reason,
            assigned_by_id=actor.id,
        )
        for override in overrides
    )
