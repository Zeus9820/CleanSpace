import SwiftUI

extension StorageCategory {
    var symbolName: String {
        switch self {
        case .caches: "bolt.horizontal.circle.fill"
        case .modelCaches: "cpu.fill"
        case .backups: "externaldrive.fill"
        case .applicationData: "app.dashed"
        case .trash: "trash.fill"
        case .otherMeasured: "folder.fill"
        case .systemUnclassified: "internaldrive.fill"
        case .available: "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .caches: .orange
        case .modelCaches: .purple
        case .backups: .blue
        case .applicationData: .pink
        case .trash: .red
        case .otherMeasured: .teal
        case .systemUnclassified: Color(nsColor: .tertiaryLabelColor)
        case .available: .green
        }
    }

    var shortDescription: String {
        switch self {
        case .caches: "Temporary files from recognized apps"
        case .modelCaches: "Supported local AI models and tool caches"
        case .backups: "Recognized device backups"
        case .applicationData: "Data belonging to recognized applications"
        case .trash: "Items waiting to be permanently removed"
        case .otherMeasured: "Accessible user data measured by CleanSpace"
        case .systemUnclassified: "Derived remainder; not assumed removable"
        case .available: "Space currently reported as available"
        }
    }
}
