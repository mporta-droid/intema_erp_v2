MODULES: dict[str, str] = {
    "dashboard": "Dashboard",
    "quotations": "Cotizaciones",
    "clients": "Clientes",
    "work_orders": "Órdenes de Trabajo",
    "design": "Diseño",
    "warehouse_inventory": "Almacén / Inventario",
    "inventory_movements": "Movimientos de inventario",
    "kardex": "Kardex",
    "production": "Producción",
    "quality_control": "Control de Calidad",
    "reports": "Reportes",
    "users_permissions": "Usuarios y permisos",
    "settings": "Configuración",
}

ACTIONS: dict[str, str] = {
    "view": "Ver",
    "create": "Crear",
    "edit": "Editar",
    "operate": "Operar",
    "delete": "Eliminar",
    "approve": "Aprobar",
    "annul": "Anular",
    "export": "Exportar Excel/PDF",
    "view_costs": "Ver costos",
    "change_oit_status": "Cambiar estados de OIT",
    "manage_users": "Gestionar usuarios",
    "view_audit": "Ver auditoría",
    "configure_catalogs": "Configurar catálogos",
}


def permission_code(module: str, action: str) -> str:
    return f"{module}.{action}"
