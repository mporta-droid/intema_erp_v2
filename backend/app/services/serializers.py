from app.models.role import Role
from app.models.user import User
from app.schemas.permission import PermissionOverrideRead
from app.schemas.role import RoleRead
from app.schemas.user import RoleSummary, UserRead
from app.services.permissions import effective_permission_codes


def role_to_read(role: Role) -> RoleRead:
    return RoleRead(
        id=role.id,
        name=role.name,
        description=role.description,
        is_active=role.is_active,
        is_system=role.is_system,
        permissions=sorted(link.permission.code for link in role.permission_links),
    )


def user_to_read(user: User) -> UserRead:
    return UserRead(
        id=user.id,
        full_name=user.full_name,
        username=user.username,
        email=user.email,
        position_area=user.position_area,
        is_active=user.is_active,
        photo_url=user.photo_url,
        created_by_id=user.created_by_id,
        created_at=user.created_at,
        updated_at=user.updated_at,
        last_login_at=user.last_login_at,
        roles=[RoleSummary(id=link.role.id, name=link.role.name) for link in user.role_links],
        permission_overrides=[
            PermissionOverrideRead(
                permission_id=link.permission_id,
                code=link.permission.code,
                allowed=link.allowed,
                reason=link.reason,
            )
            for link in user.permission_links
        ],
        effective_permissions=sorted(effective_permission_codes(user)),
    )