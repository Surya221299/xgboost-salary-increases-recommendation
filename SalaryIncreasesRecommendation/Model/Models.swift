import SwiftUI

// MARK: - Focus State

enum TableFocus: Hashable {
    case table
    case cell(row: Int, col: Int)
    case dropdown
}

// MARK: - Column Type

enum ColumnType {
    case text
    case textField
    case numberField
    case number(min: Int, max: Int)
    case dropdown([String])
}

// MARK: - Column Definition

struct ColumnDef {
    let name: String
    let type: ColumnType
    var width: CGFloat
    var isEditable: Bool = true
}

// MARK: - Table Row

struct TableRow: Identifiable {
    let id = UUID()
    var cells: [String]
}

// MARK: - Button States

enum DownloadState {
    case idle, loading, success
}

enum UploadState {
    case idle, loading, success
}

// MARK: - Preference Key

struct CellAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}
