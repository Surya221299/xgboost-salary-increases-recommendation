import SwiftUI

// MARK: - InlineTextField

struct InlineTextField: View {
    let rowIdx:     Int
    let colIdx:     Int
    let numberOnly: Bool
    let colDef:     ColumnDef
    @ObservedObject var vm: TableViewModel
    @FocusState.Binding var focus: TableFocus?

    @State private var displayText: String = ""

    var body: some View {
        HStack(spacing: 4) {
            if numberOnly {
                Text("Rp.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            TextField(numberOnly ? "0" : "", text: $displayText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .onChange(of: displayText, perform: handleTextChange)
                .onAppear(perform: syncFromModel)
                .onChange(of: vm.pendingChar, perform: handlePendingChar)
                .focused($focus, equals: .cell(row: rowIdx, col: colIdx))
                .onChange(of: focus, perform: handleFocusChange)
                .onSubmit(handleSubmit)
                .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow]) { handleArrow($0) }
                .onKeyPress(.escape) { focus = .table; return .handled }
                .onKeyPress(.tab)    { handleTab(); return .handled }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(width: colDef.width, alignment: .leading)
    }

    // MARK: - Handlers

    private func handleTextChange(_ newVal: String) {
        if numberOnly {
            let digits    = newVal.filter { $0.isNumber }
            vm.rows[rowIdx].cells[colIdx] = digits
            let formatted = formatIDR(digits)
            if formatted != newVal { displayText = formatted }
        } else {
            var processed = newVal
            let isNameCol = colDef.name.lowercased().contains("name") || colDef.name == "EmployeeName"
            if isNameCol {
                processed = newVal.filter { $0.isLetter || $0.isWhitespace }.capitalized
            }
            vm.rows[rowIdx].cells[colIdx] = processed
            if processed != newVal { displayText = processed }
        }
    }

    private func syncFromModel() {
        let raw = vm.rows[rowIdx].cells[colIdx]
        displayText = numberOnly ? formatIDR(raw) : raw
    }

    private func handlePendingChar(_ char: String?) {
        guard let char, vm.isSelected(row: rowIdx, col: colIdx) else { return }
        let raw = vm.rows[rowIdx].cells[colIdx]
        displayText     = numberOnly ? formatIDR(raw) : raw
        vm.pendingChar  = nil
    }

    private func handleFocusChange(_ newFocus: TableFocus?) {
        guard newFocus == .cell(row: rowIdx, col: colIdx) else { return }
        guard vm.pendingChar == nil else { return }
        syncFromModel()
    }

    private func handleSubmit() {
        vm.selectedRow = rowIdx
        vm.selectedCol = colIdx
        vm.moveDown()
        focus = vm.isInlineField(col: vm.selectedCol)
            ? .cell(row: vm.selectedRow, col: vm.selectedCol)
            : .table
    }

    private func handleArrow(_ press: KeyPress) -> KeyPress.Result {
        vm.selectedRow = rowIdx
        vm.selectedCol = colIdx
        switch press.key {
        case .upArrow:    vm.moveUp()
        case .downArrow:  vm.moveDown()
        case .leftArrow:  vm.moveLeft()
        case .rightArrow: vm.moveRight()
        default: break
        }
        focus = vm.isInlineField(col: vm.selectedCol)
            ? .cell(row: vm.selectedRow, col: vm.selectedCol)
            : .table
        return .handled
    }

    private func handleTab() {
        vm.selectedRow = rowIdx
        vm.selectedCol = colIdx
        vm.moveRight()
        focus = vm.isInlineField(col: vm.selectedCol)
            ? .cell(row: vm.selectedRow, col: vm.selectedCol)
            : .table
    }

    // MARK: - Formatter
    private func formatIDR(_ digits: String) -> String {
        guard !digits.isEmpty, let number = Int(digits) else { return digits }
        let formatter = NumberFormatter()
        formatter.numberStyle        = .decimal
        formatter.groupingSeparator  = "."
        formatter.groupingSize       = 3
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: number)) ?? digits
    }
}
