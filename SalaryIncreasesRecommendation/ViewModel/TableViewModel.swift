//
//  TableViewModel.swift
//  SalaryIncreasesRecommendation
//
//  Created by Surya on 23/04/26.
//

import SwiftUI
import Combine

import SwiftUI
import Combine

class TableViewModel: ObservableObject {
    @Published var rows: [TableRow]
    @Published var selectedRow: Int = 0
    @Published var selectedCol: Int = 0
    @Published var isEditing: Bool = false
    @Published var editingText: String = ""
    @Published var didCalculate: Bool = false
    @Published var pendingChar: String? = nil

    // Dropdown state
    @Published var dropdownOpen: Bool = false
    @Published var dropdownHighlighted: Int = 0  // index yang sedang di-hover/navigasi
    
    // Di dalam class TableViewModel
    let levelMap: [String: String] = [
        "Junior": "1",
        "Middle": "2",
        "Senior": "3",
        "Manager": "4",
        "Executive": "5"
    ]
    
    var levelReverseMap: [String: String] {
        Dictionary(uniqueKeysWithValues: levelMap.map { ($1, $0) })
    }

    let columnDefs: [ColumnDef] = [
        ColumnDef(name: "Name",
                  type: .textField,
                  width: 160),
        ColumnDef(name: "Monthly Rupiah",
                  type: .numberField,
                  width: 130),
        ColumnDef(name: "Performace",
                  type: .dropdown(["Low","Medium","High","VeryHigh"]),
                  width: 140),
        ColumnDef(name: "Position Level",
                  type: .dropdown(["Junior", "Middle", "Senior", "Manager", "Executive"]),
                  width: 120),
        ColumnDef(name: "Years At Company",
                  type: .dropdown((0...40).map { String($0) }),
                  width: 140),
        ColumnDef(name: "Works Overtime",
                  type: .dropdown(["Yes","No"]),
                  width: 130),
        ColumnDef(name: "Output",
                  type: .text,
                  width: 180,
                  isEditable: false),
    ]

    var columns: [String] { columnDefs.map { $0.name } }
    var rowCount: Int { rows.count }
    var colCount: Int { columnDefs.count }

    init() {
        self.rows = (0..<5).map { _ in TableRow(cells: Array(repeating: "", count: 7)) }
    }

    func moveUp()    {
        if selectedRow > 0 {
            selectedRow -= 1
        }
    }
    func moveDown()  {
        if selectedRow < rowCount - 1 {
            selectedRow += 1
        }
    }
    func moveLeft() {
        var prev = selectedCol - 1
        while prev >= 0 {
            if isEditable(col: prev) {
                selectedCol = prev
                return
            }
            prev -= 1
        }
    }
    func moveRight() {
        var next = selectedCol + 1
        while next < colCount {
            if isEditable(col: next) {
                selectedCol = next
                return
            }
            next += 1
        }
    }

    func startEditing() {
        editingText = rows[selectedRow].cells[selectedCol]
        isEditing = true
    }

    func commitEdit() {
        rows[selectedRow].cells[selectedCol] = editingText
        isEditing = false
    }

    func cancelEdit() {
        isEditing = false
        editingText = ""
    }

    func setValue(row: Int, col: Int, value: String) {
        rows[row].cells[col] = value
    }

    func isSelected(row: Int, col: Int) -> Bool {
        row == selectedRow && col == selectedCol
    }

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

    func dropdownOptions(col: Int) -> [String] {
        if case .dropdown(let opts) = columnDefs[col].type { return opts }
        return []
    }

    // Buka dropdown, set highlighted ke nilai yang sudah dipilih (atau 0)
    func openDropdown() {
        let col = selectedCol
        let row = selectedRow
        guard isDropdown(col: col) else { return }
        let opts = dropdownOptions(col: col)
        let current = rows[row].cells[col]
        dropdownHighlighted = opts.firstIndex(of: current) ?? 0
        dropdownOpen = true
    }

    func closeDropdown() {
        dropdownOpen = false
    }

    func confirmDropdown() {
        let col = selectedCol
        let row = selectedRow
        let opts = dropdownOptions(col: col)
        guard dropdownHighlighted < opts.count else { return }
        
        let selectedLabel = opts[dropdownHighlighted]
        
        // Jika kolom adalah Position Level, simpan angkanya, bukan teksnya
        if columnDefs[col].name == "Position Level" {
            rows[row].cells[col] = levelMap[selectedLabel] ?? "1"
        } else {
            rows[row].cells[col] = selectedLabel
        }
        
        dropdownOpen = false
    }

    func dropdownMoveUp() {
        if dropdownHighlighted > 0 { dropdownHighlighted -= 1 }
    }

    func dropdownMoveDown(col: Int) {
        let count = dropdownOptions(col: col).count
        if dropdownHighlighted < count - 1 { dropdownHighlighted += 1 }
    }
    func isEditable(col: Int) -> Bool {
        columnDefs[col].isEditable
    }
}
