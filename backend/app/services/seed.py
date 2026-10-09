from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.permission_catalog import ACTIONS, MODULES, permission_code
from app.core.security import hash_password
from app.models.permission import Permission
from app.models.role import Role, RolePermission
from app.models.user import User, UserRole
from app.models.mes import Machine

ROLE_DEFINITIONS: dict[str, dict[str, object]] = {
    "Administrador": {"description": "Acceso total al sistema.", "all": True},
    "Gerencia": {
        "description": "Dashboard, reportes, costos y aprobaciones.",
        "codes": [
            "dashboard.view",
            "reports.view",
            "reports.export",
            "reports.view_costs",
            "quotations.view",
            "quotations.approve",
            "quotations.view_costs",
            "work_orders.view",
            "work_orders.approve",
            "work_orders.view_costs",
            "users_permissions.view",
            "users_permissions.view_audit",
        ],
    },
    "Compras/Cotización": {
        "description": "Clientes, cotizaciones y consulta de stock.",
        "codes": [
            "dashboard.view",
            "clients.view",
            "clients.create",
            "clients.edit",
            "quotations.view",
            "quotations.create",
            "quotations.edit",
            "quotations.export",
            "warehouse_inventory.view",
            "kardex.view",
        ],
    },
    "Diseño": {
        "description": "OIT asignadas, planos, tiempos y archivos.",
        "codes": ["dashboard.view", "work_orders.view", "design.view", "design.edit"],
    },
    "Almacén": {
        "description": "Productos, movimientos, kardex y salidas vinculadas a OIT.",
        "codes": [
            "dashboard.view",
            "warehouse_inventory.view",
            "warehouse_inventory.create",
            "warehouse_inventory.edit",
            "inventory_movements.view",
            "inventory_movements.create",
            "kardex.view",
            "kardex.export",
        ],
    },
    "Producción": {
        "description": "OIT asignadas, tiempos, procesos y avances.",
        "codes": ["dashboard.view", "work_orders.view", "production.view", "production.edit", "production.operate"],
    },
    "Operario Producción": {
        "description": "Ejecución de procesos de máquina asignados por producción.",
        "codes": ["dashboard.view", "work_orders.view", "production.view", "production.operate"],
    },
    "Calidad": {
        "description": "Inspecciones, no conformidades y liberación.",
        "codes": ["dashboard.view", "work_orders.view", "quality_control.view", "quality_control.edit", "quality_control.approve"],
    },
    "Consulta": {"description": "Lectura de módulos autorizados.", "codes": ["dashboard.view"]},
}


def seed_permissions(db: Session) -> dict[str, Permission]:
    existing = {permission.code: permission for permission in db.execute(select(Permission)).scalars()}
    for module, module_label in MODULES.items():
        for action, action_label in ACTIONS.items():
            code = permission_code(module, action)
            if code not in existing:
                permission = Permission(
                    module=module,
                    action=action,
                    code=code,
                    description=f"{action_label} - {module_label}",
                )
                db.add(permission)
                existing[code] = permission
    db.flush()
    return existing


def seed_roles(db: Session, permissions: dict[str, Permission]) -> dict[str, Role]:
    existing = {role.name: role for role in db.execute(select(Role)).scalars()}
    for name, definition in ROLE_DEFINITIONS.items():
        role = existing.get(name)
        if role is None:
            role = Role(name=name, description=str(definition["description"]), is_system=True)
            db.add(role)
            db.flush()
            existing[name] = role
        else:
            role.description = str(definition["description"])
            role.is_system = True
            role.is_active = True

        selected_codes = set(permissions) if definition.get("all") else set(definition.get("codes", []))
        current_codes = {link.permission.code for link in role.permission_links}
        for code in selected_codes - current_codes:
            db.add(RolePermission(role_id=role.id, permission_id=permissions[code].id))
    db.flush()
    return existing


def seed_admin_user(db: Session, roles: dict[str, Role]) -> User:
    admin = db.execute(select(User).where(User.username == settings.admin_username)).scalar_one_or_none()
    if admin is None:
        admin = User(
            full_name=settings.admin_full_name,
            username=settings.admin_username,
            email=settings.admin_email,
            password_hash=hash_password(settings.admin_password),
            position_area="Administración",
            is_active=True,
        )
        db.add(admin)
        db.flush()
    else:
        admin.full_name = settings.admin_full_name
        admin.email = settings.admin_email
        admin.position_area = "AdministraciÃ³n"
        admin.is_active = True
        admin.permission_links.clear()
        db.flush()
    admin_role = roles["Administrador"]
    if all(link.role_id != admin_role.id for link in admin.role_links):
        db.add(UserRole(user_id=admin.id, role_id=admin_role.id, assigned_by_id=admin.id))
    return admin


def seed_phase1(db: Session) -> None:
    permissions = seed_permissions(db)
    roles = seed_roles(db, permissions)
    seed_admin_user(db, roles)
    seed_machines(db)
    db.flush()


def seed_machines(db: Session) -> None:
    defaults = [
        ("Torno", "Mecanizado"),
        ("Fresadora", "Mecanizado"),
        ("Soldadura", "Soldadura"),
        ("Corte", "Corte"),
        ("Pintura / Acabado", "Acabado"),
    ]
    existing = {machine.name for machine in db.execute(select(Machine)).scalars()}
    for name, process_name in defaults:
        if name not in existing:
            db.add(Machine(name=name, process_name=process_name))
