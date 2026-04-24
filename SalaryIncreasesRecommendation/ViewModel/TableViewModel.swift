import SwiftUI
import Combine
import CoreML

// MARK: - TableViewModel

class TableViewModel: ObservableObject {

    // MARK: - Table State
    @Published var rows: [TableRow]
    @Published var selectedRow: Int = 0
    @Published var selectedCol: Int = 0
    @Published var isEditing: Bool = false
    @Published var editingText: String = ""
    @Published var didCalculate: Bool = false

    // MARK: - Dropdown State
    @Published var dropdownOpen: Bool = false
    @Published var dropdownHighlighted: Int = 0

    // MARK: - Pending char (realtime typing fix)
    @Published var pendingChar: String? = nil

    // MARK: - Position Level Maps
    let levelMap: [String: String] = [
        "Junior":    "1",
        "Middle":    "2",
        "Senior":    "3",
        "Manager":   "4",
        "Executive": "5"
    ]

    var levelReverseMap: [String: String] {
        Dictionary(uniqueKeysWithValues: levelMap.map { ($1, $0) })
    }

    // MARK: - Column Definitions
    let columnDefs: [ColumnDef] = [
        ColumnDef(name: "Name",             type: .textField,                                width: 160),
        ColumnDef(name: "Monthly Rupiah",   type: .numberField,                              width: 130),
        ColumnDef(name: "Performace",       type: .dropdown(["Low","Medium","High","VeryHigh"]), width: 140),
        ColumnDef(name: "Position Level",   type: .dropdown(["Junior","Middle","Senior","Manager","Executive"]), width: 120),
        ColumnDef(name: "Years At Company", type: .dropdown((0...40).map { String($0) }),    width: 140),
        ColumnDef(name: "Works Overtime",   type: .dropdown(["Yes","No"]),                   width: 130),
        ColumnDef(name: "Salary increases",           type: .text,  width: 180, isEditable: false),
    ]

    var columns:  [String] { columnDefs.map { $0.name } }
    var rowCount: Int      { rows.count }
    var colCount: Int      { columnDefs.count }

    // MARK: - Init
    init() {
        self.rows = (0..<5).map { _ in TableRow(cells: Array(repeating: "", count: 7)) }
    }

    // MARK: - Navigation
    func moveUp()    { if selectedRow > 0          { selectedRow -= 1 } }
    func moveDown()  { if selectedRow < rowCount-1 { selectedRow += 1 } }

    func moveLeft() {
        var prev = selectedCol - 1
        while prev >= 0 {
            if isEditable(col: prev) { selectedCol = prev; return }
            prev -= 1
        }
    }

    func moveRight() {
        var next = selectedCol + 1
        while next < colCount {
            if isEditable(col: next) { selectedCol = next; return }
            next += 1
        }
    }

    // MARK: - Editing
    func startEditing() {
        editingText = rows[selectedRow].cells[selectedCol]
        isEditing   = true
    }

    func commitEdit() {
        rows[selectedRow].cells[selectedCol] = editingText
        isEditing = false
    }

    func cancelEdit() {
        isEditing   = false
        editingText = ""
    }

    func setValue(row: Int, col: Int, value: String) {
        rows[row].cells[col] = value
    }

    // MARK: - Selection
    func isSelected(row: Int, col: Int) -> Bool {
        row == selectedRow && col == selectedCol
    }

    // MARK: - Column Type Queries
    func isDropdown(col: Int) -> Bool {
        if case .dropdown(_) = columnDefs[col].type { return true }
        return false
    }

    func isInlineField(col: Int) -> Bool {
        switch columnDefs[col].type {
        case .textField, .numberField: return true
        default: return false
        }
    }

    func isNumberOnly(col: Int) -> Bool {
        if case .numberField = columnDefs[col].type { return true }
        return false
    }

    func isEditable(col: Int) -> Bool {
        columnDefs[col].isEditable
    }

    func dropdownOptions(col: Int) -> [String] {
        if case .dropdown(let opts) = columnDefs[col].type { return opts }
        return []
    }

    // MARK: - Dropdown Actions
    func openDropdown() {
        let col  = selectedCol
        let row  = selectedRow
        guard isDropdown(col: col) else { return }
        let opts    = dropdownOptions(col: col)
        let current = rows[row].cells[col]
        dropdownHighlighted = opts.firstIndex(of: current) ?? 0
        dropdownOpen = true
    }

    func closeDropdown() { dropdownOpen = false }

    func confirmDropdown() {
        let col  = selectedCol
        let row  = selectedRow
        let opts = dropdownOptions(col: col)
        guard dropdownHighlighted < opts.count else { return }
        selectDropdownValue(row: row, col: col, value: opts[dropdownHighlighted])
    }
    
    /// Gunakan ini untuk semua pemilihan dropdown — baik dari klik maupun keyboard
    func selectDropdownValue(row: Int, col: Int, value: String) {
        if columnDefs[col].name == "Position Level" {
            rows[row].cells[col] = levelMap[value] ?? value
        } else {
            rows[row].cells[col] = value
        }
        dropdownOpen = false
    }

    func dropdownMoveUp()           { if dropdownHighlighted > 0 { dropdownHighlighted -= 1 } }
    func dropdownMoveDown(col: Int) {
        let count = dropdownOptions(col: col).count
        if dropdownHighlighted < count - 1 { dropdownHighlighted += 1 }
    }
    
    

    // MARK: - ML Prediction
    func calculateAll() {
        for i in 0..<rows.count {
            let row = rows[i]
            if isRowComplete(row) {
                rows[i].cells[6] = predictRow(row)
            } else {
                rows[i].cells[6] = "0"
            }
        }
        didCalculate = true
    }

    func isRowComplete(_ row: TableRow) -> Bool {
        for (index, value) in row.cells.enumerated() {
            if columnDefs[index].name == "Salary increases" { continue }
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        }
        return true
    }

    func hasValidRow() -> Bool {
        rows.contains { isRowComplete($0) }
    }

    private func predictRow(_ row: TableRow) -> String {
        do {
            let involvementMap: [String: Double] = ["Low":1,"Medium":2,"High":3,"VeryHigh":4]
            let overtimeMap:    [String: Double] = ["No":0,"Yes":1]

            let input = salary_hike_v2Input(
                Monthly_Rupiah:   Double(row.cells[1]) ?? 0,
                Performance:      involvementMap[row.cells[2]] ?? 0,
                Position_Level:   Double(row.cells[3]) ?? 0,
                Years_At_Company: Double(row.cells[4]) ?? 0,
                Works_Overtime:   overtimeMap[row.cells[5]] ?? 0
            )

            let model      = try salary_hike_v2(configuration: MLModelConfiguration())
            let prediction = try model.prediction(input: input)
            return String(format: "%.2f", prediction.target)
        } catch {
            return "Error"
        }
    }
}
