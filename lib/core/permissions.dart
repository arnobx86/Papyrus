enum AppPermission {
  createSale,
  editSale,
  deleteSale,
  createPurchase,
  editPurchase,
  deletePurchase,
  manageProducts,
  manageStock,
  manageCustomers,
  manageSuppliers,
  viewReports,
  manageEmployees,
  manageRoles,
  approveActions,
}

class Permissions {
  static final Map<AppPermission, String> _permissionKeys = {
    AppPermission.createSale: 'create_sale',
    AppPermission.editSale: 'edit_sale',
    AppPermission.deleteSale: 'delete_sale',
    AppPermission.createPurchase: 'create_purchase',
    AppPermission.editPurchase: 'edit_purchase',
    AppPermission.deletePurchase: 'delete_purchase',
    AppPermission.manageProducts: 'manage_products',
    AppPermission.manageStock: 'manage_stock',
    AppPermission.manageCustomers: 'manage_customers',
    AppPermission.manageSuppliers: 'manage_suppliers',
    AppPermission.viewReports: 'view_reports',
    AppPermission.manageEmployees: 'manage_employees',
    AppPermission.manageRoles: 'manage_roles',
    AppPermission.approveActions: 'approve_actions',
  };

  static bool hasPermission(Map<String, dynamic>? permissions, AppPermission permission) {
    if (permissions == null) return false;
    final key = _permissionKeys[permission];
    return permissions[key] == true;
  }
}
