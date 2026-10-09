from app.core.security import create_access_token, create_refresh_token, decode_token, hash_password, verify_password
from app.models.permission import Permission
from app.models.role import Role, RolePermission
from app.models.user import User, UserPermission, UserRole
from app.services.permissions import effective_permission_codes, has_permission


def main() -> None:
    password_hash = hash_password("Cambiar123!")
    assert password_hash != "Cambiar123!"
    assert verify_password("Cambiar123!", password_hash)
    assert not verify_password("Incorrecta123!", password_hash)
    assert decode_token(create_access_token("usuario-1"), expected_type="access")["sub"] == "usuario-1"
    assert decode_token(create_refresh_token("usuario-1"), expected_type="refresh")["sub"] == "usuario-1"
    view_dashboard = Permission(module="dashboard", action="view", code="dashboard.view", description="Ver Dashboard")
    manage_users = Permission(module="users_permissions", action="manage_users", code="users_permissions.manage_users", description="Gestionar usuarios")
    role = Role(name="Consulta", is_active=True)
    user = User(full_name="Operario", username="operario", password_hash="hash", is_active=True)
    role.permission_links = [RolePermission(role=role, permission=view_dashboard)]
    user.role_links = [UserRole(user=user, role=role)]
    user.permission_links = [UserPermission(user=user, permission=view_dashboard, allowed=False), UserPermission(user=user, permission=manage_users, allowed=True)]
    codes = effective_permission_codes(user)
    assert "dashboard.view" not in codes
    assert "users_permissions.manage_users" in codes
    assert has_permission(user, "users_permissions.manage_users")


if __name__ == "__main__":
    main()
    print("Validacion directa Fase 1 OK")
