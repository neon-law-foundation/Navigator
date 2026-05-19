import NavigatorWeb
import Vapor
import VaporElementary

/// `/admin/help` — reference page documenting keyboard shortcuts, sort
/// and filter conventions, and the export URLs every operator can use.
///
/// Static content, no database access, so the route is safe to hit even
/// when downstream data sources are unavailable.
func registerAdminHelpRoutes(_ app: Application, brand: any Brand) {
    app.get("admin", "help") { _ -> HTMLResponse in
        HTMLResponse { AdminHelpPage(brand: brand) }
    }
}
