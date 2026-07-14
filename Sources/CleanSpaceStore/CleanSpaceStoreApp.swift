import CleanSpaceCore
import SwiftUI

@main
struct CleanSpaceStoreApp: App {
    @StateObject private var model: DashboardModel

    init() {
        _model = StateObject(wrappedValue: DashboardModel(environment: .live(profile: .store)))
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            CleanSpaceRootView(model: model)
                .frame(idealWidth: 1100, idealHeight: 720)
        }
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            CleanSpaceMenuBarView(model: model)
        } label: {
            Label("CleanSpace", systemImage: "internaldrive")
        }
        .menuBarExtraStyle(.window)
    }
}
