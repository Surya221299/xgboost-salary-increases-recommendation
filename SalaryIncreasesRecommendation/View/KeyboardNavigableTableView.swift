import SwiftUI
import Combine
import CoreML

// MARK: - KeyboardNavigableTableView

struct KeyboardNavigableTableView: View {
    @StateObject private var vm      = TableViewModel()
    @StateObject private var csvVM   = CSVViewModel()
    @FocusState  private var focus:    TableFocus?

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                headerBar

                ScrollViewReader { proxy in
                    ScrollView([.horizontal, .vertical]) {
                        VStack(alignment: .leading, spacing: 0) {
                            columnHeader
                            ForEach(Array(vm.rows.enumerated()), id: \.element.id) { rowIdx, row in
                                rowView(rowIdx: rowIdx, row: row)
                                    .id("row-\(rowIdx)")
                            }
                            addRowButton
                        }
                        .padding(0)
                    }
                    .onChange(of: vm.selectedRow) { newRow in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo("row-\(newRow)", anchor: .center)
                        }
                    }
                }

                statusBar
            }
            .background(Color(NSColor.windowBackgroundColor))
            .focusable()
            .focused($focus, equals: .table)
            .onAppear { focus = .table }
            .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow,
                               .return, .escape, .tab]) { press in
                guard focus == .table else { return .ignored }
                return handleTableKey(press)
            }
            .onKeyPress(phases: .down) { press in
                guard focus == .table else { return .ignored }
                return handleTypingKey(press)
            }
        }
        .onTapGesture {
            if vm.dropdownOpen { vm.closeDropdown(); focus = .table }
        }
        .onKeyPress(keys: [.upArrow, .downArrow, .return, .escape, .tab]) { press in
            guard vm.dropdownOpen else { return .ignored }
            return handleDropdownKey(press)
        }
        .onChange(of: focus) { newFocus in
            if case let .cell(row, col) = newFocus {
                vm.selectedRow = row
                vm.selectedCol = col
            }
        }
        .overlayPreferenceValue(CellAnchorKey.self) { anchor in
            dropdownOverlayView(anchor: anchor)
        }
    }

    // MARK: - Add Row Button
    private var addRowButton: some View {
        HStack(spacing: 0) {
            // Row number placeholder
            Color.clear.frame(width: 36, height: 32)
            Button {
                vm.rows.append(TableRow(cells: Array(repeating: "", count: vm.colCount)))
                vm.selectedRow = vm.rowCount - 1
                focus = .table
            } label: {
                HStack {
                    Text("Add Row")
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                }
            }
            .buttonStyle(.plain)
            .help("Tambah Baris Baru")
            Spacer()
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
    }

    // MARK: - Dropdown Overlay
    @ViewBuilder
    private func dropdownOverlayView(anchor: Anchor<CGRect>?) -> some View {
        if vm.dropdownOpen, let anchor {
            GeometryReader { geo in
                let cellRect = geo[anchor]
                let col      = vm.selectedCol
                let row      = vm.selectedRow
                let opts     = vm.dropdownOptions(col: col)
                let currVal  = row < vm.rows.count ? vm.rows[row].cells[col] : ""
                let popupW   = vm.columnDefs[col].width
                let popupH   = min(CGFloat(opts.count) * 28 + 16, 208)

                DropdownPopup(
                    options: opts,
                    highlighted: $vm.dropdownHighlighted,
                    currentValue: currVal,
                    onSelect: { value in
                        vm.selectDropdownValue(row: row, col: col, value: value)  // ← pakai fungsi baru
                        focus = .table
                    },
                    onDismiss: { vm.closeDropdown(); focus = .table }
                )
                .frame(width: popupW)
                .position(x: cellRect.maxX + popupW / 2, y: cellRect.minY + popupH / 2)
                .zIndex(999)
                .onTapGesture {}
            }
            .contentShape(Rectangle())
            .onTapGesture { vm.closeDropdown(); focus = .table }
            .zIndex(998)
        }
    }

    // MARK: - Header Bar
    var headerBar: some View {
        HStack {
            Image(systemName: "tablecells")
                .foregroundColor(.accentColor).font(.title3)
            Text("HR Data Input")
                .font(.headline).fontWeight(.semibold)
            Spacer()

            // Download Template
            Button {
                csvVM.triggerDownload()
            } label: {
                HStack(spacing: 6) {
                    ZStack {
                        iconLayer(name: "square.and.arrow.down.fill",            color: .primary, visible: csvVM.downloadState == .idle)
                        iconLayer(name: "square.and.arrow.down.badge.clock.fill", color: .yellow,  visible: csvVM.downloadState == .loading)
                        iconLayer(name: "checkmark.circle.fill",                 color: .green,   visible: csvVM.downloadState == .success)
                    }
                    .frame(width: 20, height: 20)
                    .scaleEffect(csvVM.downloadIconScale)
                    .animation(.spring(response: 0.35, dampingFraction: 0.5), value: csvVM.downloadIconScale)
                    .animation(.easeInOut(duration: 0.15), value: csvVM.downloadState)

                    Text("Template CSV")
                        .font(.body)
                        .foregroundColor(csvVM.downloadLabelColor)
                        .animation(.easeInOut(duration: 0.2), value: csvVM.downloadState)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(csvVM.downloadState != .idle)

            // Upload CSV
            Button {
                csvVM.triggerUpload { parsed in
                    vm.rows          = parsed
                    vm.didCalculate  = false
                    vm.selectedRow   = 0
                    vm.selectedCol   = 0
                }
            } label: {
                HStack(spacing: 6) {
                    ZStack {
                        iconLayer(name: "square.and.arrow.up",                 color: .primary, visible: csvVM.uploadState == .idle)
                        iconLayer(name: "square.and.arrow.up.badge.clock.fill",     color: .yellow,  visible: csvVM.uploadState == .loading)
                        iconLayer(name: "checkmark.circle.fill",               color: .green,   visible: csvVM.uploadState == .success)
                    }
                    .frame(width: 20, height: 20)
                    .scaleEffect(csvVM.uploadIconScale)
                    .animation(.spring(response: 0.35, dampingFraction: 0.5), value: csvVM.uploadIconScale)
                    .animation(.easeInOut(duration: 0.15), value: csvVM.uploadState)

                    Text("Upload CSV")
                        .font(.body)
                        .foregroundColor(csvVM.uploadLabelColor)
                        .animation(.easeInOut(duration: 0.2), value: csvVM.uploadState)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(csvVM.uploadState != .idle)

            // Calculate
            Button("Calculate") { vm.calculateAll() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
                .foregroundColor(.white)
                .disabled(!vm.hasValidRow())
                .help("Isi minimal 1 baris lengkap untuk melakukan kalkulasi")

            Text("\(vm.rowCount) baris · \(vm.colCount) kolom")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(NSColor.separatorColor)), alignment: .bottom)
    }

    /// Helper: single icon layer untuk ZStack crossfade
    @ViewBuilder
    private func iconLayer(name: String, color: Color, visible: Bool) -> some View {
        Image(systemName: name)
            .foregroundColor(color)
            .scaleEffect(visible ? 1.0 : 0.01)
            .opacity(visible ? 1 : 0)
    }

    // MARK: - Column Header
    var columnHeader: some View {
        HStack(spacing: 0) {
            // Row number header
            Text("No")
                .font(.headline).fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .center)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor).overlay(Color.black.opacity(0.4)))
                .overlay(Rectangle().frame(width: 1).foregroundColor(Color(NSColor.separatorColor)), alignment: .trailing)

            ForEach(Array(vm.columnDefs.enumerated()), id: \.offset) { colIdx, colDef in
                Text(colDef.name)
                    .font(.headline).fontWeight(.bold).lineLimit(1)
                    .foregroundColor(colIdx == vm.selectedCol ? .accentColor : .primary)
                    .frame(width: colDef.width, alignment: .center)
                    .padding(.vertical, 8)
                    .background(colIdx == vm.selectedCol
                                ? Color.accentColor.opacity(0.08)
                                : Color.black.opacity(0.4))
                    .overlay(Rectangle().frame(width: 1).foregroundColor(Color(NSColor.separatorColor)), alignment: .trailing)
            }
        }
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(NSColor.separatorColor)), alignment: .bottom)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(NSColor.separatorColor)), alignment: .top)
    }

    // MARK: - Row View
    func rowView(rowIdx: Int, row: TableRow) -> some View {
        HStack(spacing: 0) {
            // Row number
            Text("\(rowIdx + 1)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 36, height: 32, alignment: .center)
                .background(
                    rowIdx == vm.selectedRow
                        ? Color.accentColor.opacity(0.08)
                        : (rowIdx % 2 != 0
                            ? Color(NSColor.windowBackgroundColor).opacity(0.6)
                            : Color(NSColor.windowBackgroundColor))
                )
                .overlay(Rectangle().frame(width: 1).foregroundColor(Color(NSColor.separatorColor).opacity(0.5)), alignment: .trailing)
                .overlay(Rectangle().frame(width: 1).foregroundColor(Color(NSColor.separatorColor).opacity(0.5)), alignment: .leading)

            ForEach(Array(row.cells.enumerated()), id: \.offset) { colIdx, cell in
                cellView(rowIdx: rowIdx, colIdx: colIdx, value: cell)
            }
        }
        .background {
            if rowIdx == vm.selectedRow {
                Color.accentColor.opacity(0.08)
            } else {
                ZStack {
                    Color(NSColor.windowBackgroundColor)
                    if rowIdx % 2 != 0 { Color.black.opacity(0.4) }
                }
            }
        }
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(NSColor.separatorColor).opacity(0.5)), alignment: .bottom)
    }

    // MARK: - Cell View
    @ViewBuilder
    func cellView(rowIdx: Int, colIdx: Int, value: String) -> some View {
        let isSelected     = vm.isSelected(row: rowIdx, col: colIdx)
        let isEditingThis  = isSelected && vm.isEditing
        let colDef         = vm.columnDefs[colIdx]
        let isOutputColumn = colDef.name == "Salary increases"
        let isValidOutput  = vm.didCalculate && !value.isEmpty && value != "0"

        ZStack(alignment: .leading) {
            if isOutputColumn && isValidOutput {
                RoundedRectangle(cornerRadius: 3).fill(Color.green.opacity(0.12)).padding(1)
            }
            if isSelected {
                RoundedRectangle(cornerRadius: 3)
                    .fill(isOutputColumn && vm.didCalculate ? Color.green.opacity(0.25) : Color.accentColor.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.accentColor, lineWidth: 1.5))
                    .padding(1)
            }

            switch colDef.type {
            case .textField:
                InlineTextField(rowIdx: rowIdx, colIdx: colIdx, numberOnly: false, colDef: colDef, vm: vm, focus: $focus)

            case .numberField:
                InlineTextField(rowIdx: rowIdx, colIdx: colIdx, numberOnly: true, colDef: colDef, vm: vm, focus: $focus)

            case .dropdown(_):
                dropdownStaticCell(rowIdx: rowIdx, colIdx: colIdx, value: value, colDef: colDef)

            case .number(_, let maxVal):
                numberBarCell(value: value, maxVal: maxVal, colDef: colDef, isEditingThis: isEditingThis)

            case .text:
                textCell(rowIdx: rowIdx, colIdx: colIdx, value: value, colDef: colDef, isEditingThis: isEditingThis)
            }
        }
        .frame(width: colDef.width, height: 32)
        .contentShape(Rectangle())
        .overlay(Rectangle().frame(width: 1).foregroundColor(Color(NSColor.separatorColor).opacity(0.5)), alignment: .trailing)
        .anchorPreference(key: CellAnchorKey.self, value: .bounds) { anchor in
            (isSelected && vm.isDropdown(col: colIdx)) ? anchor : nil
        }
        .onTapGesture { handleCellTap(rowIdx: rowIdx, colIdx: colIdx, isSelected: isSelected) }
    }

    private func handleCellTap(rowIdx: Int, colIdx: Int, isSelected: Bool) {
        guard vm.isEditable(col: colIdx) else { return }
        if vm.isEditing { vm.commitEdit() }
        if vm.dropdownOpen && !isSelected { vm.closeDropdown() }
        vm.selectedRow = rowIdx
        vm.selectedCol = colIdx
        if vm.isInlineField(col: colIdx) {
            focus = .cell(row: rowIdx, col: colIdx)
        } else if vm.isDropdown(col: colIdx) {
            vm.openDropdown(); focus = .table
        } else {
            focus = .table
        }
    }

    // MARK: - Cell Sub-views

    @ViewBuilder
    private func numberBarCell(value: String, maxVal: Int, colDef: ColumnDef, isEditingThis: Bool) -> some View {
        if isEditingThis {
            TextField("", text: $vm.editingText)
                .textFieldStyle(.plain).font(.system(size: 12))
                .padding(.horizontal, 10)
                .frame(width: colDef.width, alignment: .leading)
                .onSubmit { vm.commitEdit(); focus = .table }
        } else {
            HStack(spacing: 6) {
                Text(value.isEmpty ? "–" : value)
                    .font(.system(size: 12))
                    .foregroundColor(value.isEmpty ? .secondary : .primary)
                    .frame(width: 28, alignment: .trailing)
                if !value.isEmpty, let v = Int(value) {
                    let pct = min(Double(v) / Double(maxVal), 1.0)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.15)).frame(height: 4)
                            RoundedRectangle(cornerRadius: 2).fill(Color.accentColor.opacity(0.65))
                                .frame(width: geo.size.width * pct, height: 4)
                        }
                    }.frame(height: 4)
                }
            }
            .frame(width: colDef.width, alignment: .leading)
            .padding(.horizontal, 10).padding(.vertical, 7)
        }
    }

    @ViewBuilder
    private func textCell(rowIdx: Int, colIdx: Int, value: String, colDef: ColumnDef, isEditingThis: Bool) -> some View {
        if isEditingThis {
            TextField("", text: $vm.editingText)
                .textFieldStyle(.plain).font(.system(size: 12))
                .padding(.horizontal, 10)
                .frame(width: colDef.width, alignment: .leading)
                .onSubmit { vm.commitEdit(); focus = .table }
        } else if colDef.name == "Output" {
            outputCell(rowIdx: rowIdx, value: value, colDef: colDef)
        } else {
            Text(value.isEmpty ? "–" : value)
                .font(.system(size: 12))
                .foregroundColor(value.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 7)
        }
    }

    @ViewBuilder
    private func outputCell(rowIdx: Int, value: String, colDef: ColumnDef) -> some View {
        if vm.didCalculate && !value.isEmpty && value != "0" {
            let income  = cleanNumber(vm.rows[rowIdx].cells[1])
            let percent = Double(value) ?? 0
            let bonus   = income * percent / 100
            let total   = income + bonus
            Text("+\(String(format: "%.2f", percent))% (Rp.\(Int(total)))")
                .font(.system(size: 12)).foregroundColor(.primary).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 7)
        } else if vm.didCalculate && value == "0" {
            Text("-")
                .font(.system(size: 12)).foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 7)
        } else {
            Text("–")
                .font(.system(size: 12)).foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 7)
        }
    }

    @ViewBuilder
    func dropdownStaticCell(rowIdx: Int, colIdx: Int, value: String, colDef: ColumnDef) -> some View {
        let displayValue: String = {
            if colDef.name == "Position Level" {
                return vm.levelReverseMap[value] ?? (value.isEmpty ? "Choose..." : value)
            }
            return value.isEmpty ? "Choose..." : value
        }()

        HStack(spacing: 5) {
            dropdownDot(colIdx: colIdx, value: value)
            Text(displayValue)
                .font(.system(size: 12))
                .foregroundColor(value.isEmpty ? .secondary : .primary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.down.square.fill")
                .font(.system(size: 16))
                .foregroundColor(
                    (vm.dropdownOpen && vm.isSelected(row: rowIdx, col: colIdx)) || !value.isEmpty
                    ? Color.blue : Color.secondary.opacity(0.7)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 7)
    }

    @ViewBuilder
    func dropdownDot(colIdx: Int, value: String) -> some View {
        let colName = vm.columnDefs[colIdx].name
        if colName == "Performace" {
            let m: [String: Color] = ["Low":.gray,"Medium":.blue,"High":.orange,"VeryHigh":.green]
            if let c = m[value] { Circle().fill(c).frame(width: 7, height: 7) }
        } else if colName == "Works Overtime" {
            let m: [String: Color] = ["Yes":.green,"No":.red]
            if let c = m[value] { Circle().fill(c).frame(width: 7, height: 7) }
        } else if colName == "Position Level", !value.isEmpty {
            Text(value)
                .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.accentColor))
        }
    }

    // MARK: - Status Bar
    var statusBar: some View {
        let inCell:     Bool = { if case .cell = focus { return true }; return false }()
        let inDropdown: Bool = vm.dropdownOpen

        return HStack {
            Image(systemName: "keyboard").font(.caption2).foregroundColor(.secondary)
            Group {
                if inDropdown {
                    Text("↑↓ navigasi pilihan  ·  ⏎ pilih  ·  Esc tutup")
                } else if inCell {
                    Text("Ketik · ↑↓←→ pindah · Tab kanan · Esc navigasi")
                } else {
                    Text("↑↓←→ navigasi · Ketik langsung · ⏎ buka dropdown / edit")
                }
            }
            .font(.caption2).foregroundColor(.secondary)
            Spacer()
            Text("Sel: \(vm.columns[vm.selectedCol]) – Baris \(vm.selectedRow + 1)")
                .font(.caption2).fontWeight(.medium).foregroundColor(.accentColor)
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(NSColor.separatorColor)), alignment: .top)
    }

    // MARK: - Helpers
    func cleanNumber(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: ".", with: "")
                   .replacingOccurrences(of: ",", with: "")
                   .filter { $0.isNumber }) ?? 0
    }

    // MARK: - Key Handlers
    func handleTableKey(_ press: KeyPress) -> KeyPress.Result {
        if vm.dropdownOpen { return handleDropdownKey(press) }
        if vm.isEditing {
            switch press.key {
            case .return: vm.commitEdit(); vm.moveDown();  return .handled
            case .escape: vm.cancelEdit();                 return .handled
            case .tab:    vm.commitEdit(); vm.moveRight(); return .handled
            default:      return .ignored
            }
        } else {
            switch press.key {
            case .upArrow:    vm.moveUp();    return .handled
            case .downArrow:  vm.moveDown();  return .handled
            case .leftArrow:  vm.moveLeft();  return .handled
            case .rightArrow: vm.moveRight(); return .handled
            case .tab:        vm.moveRight(); return .handled
            case .return:
                guard vm.isEditable(col: vm.selectedCol) else { return .handled }
                if vm.isDropdown(col: vm.selectedCol) {
                    vm.openDropdown()
                } else if vm.isInlineField(col: vm.selectedCol) {
                    focus = .cell(row: vm.selectedRow, col: vm.selectedCol)
                } else {
                    vm.startEditing()
                }
                return .handled
            default: return .ignored
            }
        }
    }

    func handleDropdownKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .upArrow:       vm.dropdownMoveUp();                         return .handled
        case .downArrow:     vm.dropdownMoveDown(col: vm.selectedCol);    return .handled
        case .return:        vm.confirmDropdown(); focus = .table;        return .handled
        case .escape, .tab:  vm.closeDropdown();   focus = .table;        return .handled
        default:             return .ignored
        }
    }

    func handleTypingKey(_ press: KeyPress) -> KeyPress.Result {
        if vm.dropdownOpen { return .ignored }
        let col = vm.selectedCol
        let row = vm.selectedRow

        let nav: Set<KeyEquivalent> = [.upArrow,.downArrow,.leftArrow,.rightArrow,.return,.escape,.tab,.delete,.deleteForward]
        if nav.contains(press.key) { return .ignored }

        let char = String(press.key.character)
        guard char.unicodeScalars.first.map({ $0.value >= 32 && $0.value != 127 }) == true,
              !char.isEmpty else { return .ignored }
        guard vm.isEditable(col: col), !vm.isDropdown(col: col) else { return .ignored }

        if vm.isInlineField(col: col) {
            if vm.isNumberOnly(col: col) && !char.allSatisfy({ $0.isNumber }) { return .ignored }
            focus = .cell(row: row, col: col)
            vm.rows[row].cells[col] = char
            vm.pendingChar = char
            return .handled
        } else {
            vm.editingText = char
            vm.isEditing   = true
            return .handled
        }
    }
}
