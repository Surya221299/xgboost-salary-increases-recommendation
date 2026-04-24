import SwiftUI
import Combine
import CoreML

// MARK: - Focus State

struct CellAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

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

struct ColumnDef {
    let name: String
    let type: ColumnType
    var width: CGFloat
    var isEditable: Bool = true
}

// MARK: - Model

struct TableRow: Identifiable {
    let id = UUID()
    var cells: [String]
}

// MARK: - Custom Dropdown Popup

struct DropdownPopup: View {
    let options: [String]
    @Binding var highlighted: Int
    let currentValue: String
    let onSelect: (String) -> Void
    let onDismiss: () -> Void
    
    // Scroll ke item yang di-highlight
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.offset) { idx, option in
                        DropdownRow(
                            option: option,
                            isHighlighted: idx == highlighted,
                            isSelected: option == currentValue
                        )
                        .id(idx)
                        .onTapGesture {
                            onSelect(option)
                        }
                        .onHover { inside in
                            if inside {
                                    highlighted = idx
                                
                            }
                        }
                    }
                    
                }
            }
            .onChange(of: highlighted) { newValue in
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
            .onAppear {
                proxy.scrollTo(highlighted, anchor: .center)
            }
        }
        .frame(maxHeight: min(CGFloat(options.count) * 28 + 8, 200))
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }
}

struct DropdownRow: View {
    let option: String
    let isHighlighted: Bool
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isSelected ? .accentColor : .clear)
                .frame(width: 14)
            Text(option)
                .font(.system(size: 12))
                .foregroundColor(isHighlighted ? .white : .primary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isHighlighted ? Color.accentColor : Color.clear)
                .padding(.horizontal, 4)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Main View

struct ContentView: View {
    @StateObject private var vm = TableViewModel()
    @FocusState private var focus: TableFocus?
    
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
                            HStack(spacing: 0) {
                                Button {
                                    vm.rows.append(TableRow(cells: Array(repeating: "", count: vm.colCount)))
                                    vm.selectedRow = vm.rowCount - 1
                                    focus = .table
                                } label: {
                                    HStack {
                                        Text("Add Row")
                                    }
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.green)
                                }
                                .buttonStyle(.plain)
                                .help("Tambah Baris Baru")
                                Spacer()
                            }
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
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
            if vm.dropdownOpen {
                vm.closeDropdown()
                focus = .table
            }
        }
        // Keyboard saat dropdown terbuka
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
            if vm.dropdownOpen, let anchor {
                GeometryReader { geo in
                    let cellRect  = geo[anchor]
                    let col       = vm.selectedCol
                    let row       = vm.selectedRow
                    let opts      = vm.dropdownOptions(col: col)
                    let currVal   = row < vm.rows.count ? vm.rows[row].cells[col] : ""
                    let popupW    = vm.columnDefs[col].width
                    let popupH    = min(CGFloat(opts.count) * 28 + 16, 208)
                    
                    DropdownPopup(
                        options: opts,
                        highlighted: $vm.dropdownHighlighted,
                        currentValue: currVal,
                        onSelect: { value in
                            vm.setValue(row: row, col: col, value: value)
                            vm.closeDropdown()
                            focus = .table
                        },
                        onDismiss: {
                            vm.closeDropdown()
                            focus = .table
                        }
                    )
                    .frame(width: popupW)
                    .position(
                        x: cellRect.maxX + popupW / 2,
                        y: cellRect.minY + popupH / 2
                    )
                    .zIndex(999)
                    .onTapGesture {}
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    vm.closeDropdown()
                    focus = .table
                }
                .zIndex(998)
            }
        }
    }
    
    func calculateAll() {
        for i in 0..<vm.rows.count {
            let row = vm.rows[i]
            
            if isRowComplete(row) {
                let result = predictRow(row)
                vm.rows[i].cells[6] = result
            } else {
                vm.rows[i].cells[6] = "0"
            }
        }
        
        vm.didCalculate = true
    }
    
    func predictRow(_ row: TableRow) -> String {
        do {
            let involvementMap: [String: Double] = [
                "Low": 1, "Medium": 2, "High": 3, "VeryHigh": 4
            ]
            
            let overtimeMap: [String: Double] = [
                "No": 0, "Yes": 1
            ]
            
            let Monthly_Rupiah = Double(row.cells[1]) ?? 0
            let Performance = involvementMap[row.cells[2]] ?? 0
            let Position_Level = Double(row.cells[3]) ?? 0
            let Years_At_Company = Double(row.cells[4]) ?? 0
            let Works_Overtime = overtimeMap[row.cells[5]] ?? 0
            
            let input = salary_hike_v2Input(
                Monthly_Rupiah: Monthly_Rupiah,
                Performance: Performance,
                Position_Level: Position_Level,
                Years_At_Company: Years_At_Company,
                Works_Overtime: Works_Overtime
            )
            
            let model = try salary_hike_v2(configuration: MLModelConfiguration())
            let prediction = try model.prediction(input: input)
            
            return String(format: "%.2f", prediction.target)
            
        } catch {
            return "Error"
        }
    }
    
    // MARK: - Dropdown Overlay
    var dropdownOverlay: some View {
        let col       = vm.selectedCol
        let row       = vm.selectedRow
        let opts      = vm.dropdownOptions(col: col)
        let currentVal = row < vm.rows.count ? vm.rows[row].cells[col] : ""
        
        let headerBarH:    CGFloat = 41
        let columnHeaderH: CGFloat = 33
        let rowH:          CGFloat = 32
        
        let xRightOfCell: CGFloat = (0..<col)
            .reduce(0) { $0 + vm.columnDefs[$1].width }
        + vm.columnDefs[col].width
        
        let yTopOfCell: CGFloat = headerBarH + columnHeaderH + CGFloat(row) * rowH
        
        let popupWidth: CGFloat = vm.columnDefs[col].width
        
        return DropdownPopup(
            options: opts,
            highlighted: $vm.dropdownHighlighted,
            currentValue: currentVal,
            onSelect: { value in
                vm.setValue(row: row, col: col, value: value)
                vm.closeDropdown()
                focus = .table
            },
            onDismiss: {
                vm.closeDropdown()
                focus = .table
            }
        )
        .frame(width: popupWidth)
        .offset(x: xRightOfCell, y: yTopOfCell)
        .zIndex(999)
        .onTapGesture { /* dikonsumsi oleh DropdownRow, jangan hapus */ }
    }
    
    // MARK: - Header Bar
    var headerBar: some View {
        HStack {
            Image(systemName: "tablecells")
                .foregroundColor(.accentColor).font(.title3)
            Text("HR Data Input")
                .font(.headline).fontWeight(.semibold)
            Spacer()
            Button("Calculate") {
                calculateAll()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.blue)
            .foregroundColor(.white)
            .disabled(!hasValidRow())
            .help("Isi minimal 1 baris lengkap untuk melakukan kalkulasi")
            
            Text("\(vm.rowCount) baris · \(vm.colCount) kolom")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(Rectangle().frame(height: 1)
            .foregroundColor(Color(NSColor.separatorColor)), alignment: .bottom)
    }
    
    // MARK: - Column Header
    var columnHeader: some View {
        HStack(spacing: 0) {
            
            ForEach(Array(vm.columnDefs.enumerated()), id: \.offset) { colIdx, colDef in
                HStack(spacing: 4) {
                    Text(colDef.name)
                        .font(.headline).fontWeight(.bold).lineLimit(1)
                        .foregroundColor(colIdx == vm.selectedCol ? .accentColor : .primary)
                    columnTypeIcon(colIdx: colIdx)
                }
                .frame(width: colDef.width, alignment: .center)
                .padding(.vertical, 8)
                .background(colIdx == vm.selectedCol
                            ? Color.accentColor.opacity(0.08)
                            : Color(NSColor.controlBackgroundColor))
                .overlay(Rectangle().frame(width: 1)
                    .foregroundColor(Color(NSColor.separatorColor)), alignment: .trailing)
            }
        }
        .overlay(Rectangle().frame(height: 1)
            .foregroundColor(Color(NSColor.separatorColor)), alignment: .bottom)
    }
    
    @ViewBuilder
    func columnTypeIcon(colIdx: Int) -> some View {
        switch vm.columnDefs[colIdx].type {
        case .dropdown:
            EmptyView()
        case .number:
            Image(systemName: "numbers")
                .font(.system(size: 8)).foregroundColor(.secondary.opacity(0.6))
        case .numberField:
            Image(systemName: "numbers")
                .font(.system(size: 8)).foregroundColor(.blue.opacity(0.7))
        case .textField:
            Image(systemName: "person.fill")
                .font(.system(size: 8)).foregroundColor(.blue.opacity(0.7))
        case .text:
            EmptyView()
        }
    }
    
    // MARK: - Row View
    func rowView(rowIdx: Int, row: TableRow) -> some View {
        HStack(spacing: 0) {
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

                    if rowIdx % 2 != 0 {
                        Color.black.opacity(0.4)
                    }
                }
            }
        }
        .overlay(Rectangle().frame(height: 1)
            .foregroundColor(Color(NSColor.separatorColor).opacity(0.5)), alignment: .bottom)
    }
    func hasValidRow() -> Bool {
        return vm.rows.contains { row in
            // semua kolom (kecuali Output) harus terisi
            for (index, value) in row.cells.enumerated() {
                let colName = vm.columnDefs[index].name
                if colName == "Output" { continue }
                if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return false
                }
            }
            return true
        }
    }
    // MARK: - Cell View
    @ViewBuilder
    func cellView(rowIdx: Int, colIdx: Int, value: String) -> some View {
        let isSelected    = vm.isSelected(row: rowIdx, col: colIdx)
        let isEditingThis = isSelected && vm.isEditing
        let colDef        = vm.columnDefs[colIdx]
        let isDropdownOpen = vm.dropdownOpen && isSelected
        let isOutputColumn = colDef.name == "Output"
        
        ZStack(alignment: .leading) {
            
            let isValidOutput = vm.didCalculate && !value.isEmpty && value != "0"

            
            if isOutputColumn && isValidOutput {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.green.opacity(0.12))
                    .padding(1)
            }
            
            if isSelected {
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        isOutputColumn && vm.didCalculate
                        ? Color.green.opacity(0.25)
                        : Color.accentColor.opacity(0.15)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.accentColor, lineWidth: 1.5)
                    )
                    .padding(1)
            }
            
            switch colDef.type {
            case .textField:
                inlineTextField(rowIdx: rowIdx, colIdx: colIdx, numberOnly: false, colDef: colDef)
                
            case .numberField:
                inlineTextField(rowIdx: rowIdx, colIdx: colIdx, numberOnly: true, colDef: colDef)
                
            case .dropdown(_):
                dropdownStaticCell(rowIdx: rowIdx, colIdx: colIdx, value: value, colDef: colDef)
                
            case .number(_, let maxVal):
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
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.secondary.opacity(0.15)).frame(height: 4)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.accentColor.opacity(0.65))
                                        .frame(width: geo.size.width * pct, height: 4)
                                }
                            }.frame(height: 4)
                        }
                    }
                    .frame(width: colDef.width, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                }
                
            case .text:
                if isEditingThis {
                    TextField("", text: $vm.editingText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(.horizontal, 10)
                        .frame(width: colDef.width, alignment: .leading)
                        .onSubmit { vm.commitEdit(); focus = .table }
                } else {
                    if colDef.name == "Output" {
                        // --- PERBAIKAN DI SINI ---
                        if vm.didCalculate && !value.isEmpty && value != "0" {
                            let income = cleanNumber(vm.rows[rowIdx].cells[1])
                            let percent = Double(value) ?? 0
                            
                            let bonus = income * percent / 100
                            let totalAmount = income + bonus
                            
                            Text("+\(String(format: "%.2f", percent))% (\(Int(totalAmount)))")
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                        }
                        
                        else if vm.didCalculate && value == "0" {
                            Text("-")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                        }
                        
                        else {
                            // Tampilkan strip atau kosong jika belum dikalkulasi
                            Text("–")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                        }
                        // --------------------------
                    } else {
                        Text(value.isEmpty ? "–" : value)
                            .font(.system(size: 12))
                            .foregroundColor(value.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    }
                }
            }
        }
        .frame(width: colDef.width, height: 32)
        .contentShape(Rectangle())
        .overlay(Rectangle().frame(width: 1)
            .foregroundColor(Color(NSColor.separatorColor).opacity(0.5)), alignment: .trailing)
        .anchorPreference(key: CellAnchorKey.self, value: .bounds) { anchor in
            (isSelected && vm.isDropdown(col: colIdx)) ? anchor : nil
        }
        .onTapGesture {
            if !vm.isEditable(col: colIdx) {
                return // 🚫 block total
            }
            
            if vm.isEditing { vm.commitEdit() }
            // Tutup dropdown lama jika ada
            if vm.dropdownOpen && !isSelected { vm.closeDropdown() }
            vm.selectedRow = rowIdx
            vm.selectedCol = colIdx
            if vm.isInlineField(col: colIdx) {
                focus = .cell(row: rowIdx, col: colIdx)
            } else if vm.isDropdown(col: colIdx) {
                vm.openDropdown()
                focus = .table
            } else {
                focus = .table
            }
        }
    }
    func cleanNumber(_ text: String) -> Double {
        let cleaned = text
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .filter { $0.isNumber }

        return Double(cleaned) ?? 0
    }
    
    // MARK: - Dropdown Static Cell (label saja, popup ditangani overlay)
    @ViewBuilder
    func dropdownStaticCell(rowIdx: Int, colIdx: Int, value: String, colDef: ColumnDef) -> some View {
        
        let displayValue: String = {
            if colDef.name == "Position Level" {
                // Ambil label dari map berdasarkan angka yang tersimpan (value)
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
            // Chevron rotate saat terbuka
            Image(systemName: "chevron.down.square.fill")
                .font(.system(size: 16))
                .foregroundColor(
                    // Jika dropdown terbuka ATAU sudah ada nilainya (!value.isEmpty), gunakan warna biru
                    (vm.dropdownOpen && vm.isSelected(row: rowIdx, col: colIdx)) || !value.isEmpty
                    ? Color.blue
                    : Color.secondary.opacity(0.7)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
    
    func isRowComplete(_ row: TableRow) -> Bool {
        for (index, value) in row.cells.enumerated() {
            let colName = vm.columnDefs[index].name
            
            // skip kolom Output
            if colName == "Output" { continue }
            
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
        }
        return true
    }
    
    // MARK: - Inline TextField
    @ViewBuilder
    func inlineTextField(rowIdx: Int, colIdx: Int, numberOnly: Bool, colDef: ColumnDef) -> some View {
        let binding = Binding<String>(
            get: {
                let rawValue = vm.rows[rowIdx].cells[colIdx]
                // Jika kolom angka dan tidak kosong, beri format titik (IDR)
                if numberOnly && !rawValue.isEmpty {
                    return formatToIDR(rawValue)
                }
                return rawValue
            },
            set: { newVal in
                var processedValue = newVal
                
                if numberOnly {
                    let cleanNumber = newVal.filter { $0.isNumber }
                    processedValue = cleanNumber
                } else if colDef.name.lowercased().contains("name") || colDef.name == "EmployeeName" {
                    // Logika Kapitalisasi: Mengubah "surya ramadhani" -> "Surya Ramadhani"
                    processedValue = newVal.filter { $0.isLetter || $0.isWhitespace }
                    processedValue = processedValue.capitalized
                }
                
                vm.rows[rowIdx].cells[colIdx] = processedValue
            }
        )
        
        TextField(numberOnly ? "0" : "", text: binding)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.primary)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .frame(width: colDef.width, alignment: .leading)
            .focused($focus, equals: .cell(row: rowIdx, col: colIdx))
            .onSubmit {
                vm.selectedRow = rowIdx
                vm.selectedCol = colIdx
                vm.moveDown()
                focus = vm.isInlineField(col: vm.selectedCol)
                ? .cell(row: vm.selectedRow, col: vm.selectedCol)
                : .table
            }
            .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow]) { press in
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
            .onKeyPress(.escape) {
                vm.selectedRow = rowIdx
                vm.selectedCol = colIdx
                focus = .table
                return .handled
            }
            .onKeyPress(.tab) {
                vm.selectedRow = rowIdx
                vm.selectedCol = colIdx
                vm.moveRight()
                focus = vm.isInlineField(col: vm.selectedCol)
                ? .cell(row: vm.selectedRow, col: vm.selectedCol)
                : .table
                return .handled
            }
    }
    // MARK: - Helper Formatting
    func formatToIDR(_ string: String) -> String {
        guard let number = Int(string) else { return string }
        let formatter = NumberFormatter()
        formatter.groupingSeparator = "."
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? string
    }
    
    // MARK: - Dropdown Dot / Badge
    @ViewBuilder
    func dropdownDot(colIdx: Int, value: String) -> some View {
        let colName = vm.columnDefs[colIdx].name
        if colName == "JobInvolvement" {
            let m: [String: Color] = ["Low":.gray,"Medium":.blue,"High":.orange,"VeryHigh":.green]
            if let c = m[value] { Circle().fill(c).frame(width: 7, height: 7) }
        } else if colName == "OverTime" {
            let m: [String: Color] = ["Yes":.red,"No":.green]
            if let c = m[value] { Circle().fill(c).frame(width: 7, height: 7) }
        } else if colName == "JobLevel", !value.isEmpty {
            Text(value)
                .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.accentColor))
        }
    }
    
    // MARK: - Status Bar
    var statusBar: some View {
        let inCell: Bool    = { if case .cell = focus { return true }; return false }()
        let inDropdown: Bool = vm.dropdownOpen
        
        return HStack {
            Image(systemName: "keyboard")
                .font(.caption2).foregroundColor(.secondary)
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
        .overlay(Rectangle().frame(height: 1)
            .foregroundColor(Color(NSColor.separatorColor)), alignment: .top)
    }
    
    // MARK: - Table Key Handler
    func handleTableKey(_ press: KeyPress) -> KeyPress.Result {
        // Jika dropdown terbuka, delegasikan ke dropdown handler
        if vm.dropdownOpen {
            return handleDropdownKey(press)
        }
        
        if vm.isEditing {
            switch press.key {
            case .return:  vm.commitEdit(); vm.moveDown();  return .handled
            case .escape:  vm.cancelEdit();                 return .handled
            case .tab:     vm.commitEdit(); vm.moveRight(); return .handled
            default:       return .ignored
            }
        } else {
            switch press.key {
            case .upArrow:    vm.moveUp();    return .handled
            case .downArrow:  vm.moveDown();  return .handled
            case .leftArrow:  vm.moveLeft();  return .handled
            case .rightArrow: vm.moveRight(); return .handled
            case .tab:        vm.moveRight(); return .handled
            case .return:
                let col = vm.selectedCol
                
                if !vm.isEditable(col: col) {
                    return .handled
                }
                
                if vm.isDropdown(col: col) {
                    // Buka dropdown dengan keyboard
                    vm.openDropdown()
                } else if vm.isInlineField(col: col) {
                    focus = .cell(row: vm.selectedRow, col: col)
                } else {
                    vm.startEditing()
                }
                return .handled
            default: return .ignored
            }
        }
    }
    
    // MARK: - Dropdown Key Handler
    func handleDropdownKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .upArrow:
            vm.dropdownMoveUp()
            return .handled
        case .downArrow:
            vm.dropdownMoveDown(col: vm.selectedCol)
            return .handled
        case .return:
            vm.confirmDropdown()
            focus = .table
            return .handled
        case .escape, .tab:
            vm.closeDropdown()
            focus = .table
            return .handled
        default:
            return .ignored
        }
    }
    
    // MARK: - Typing Key Handler
    func handleTypingKey(_ press: KeyPress) -> KeyPress.Result {
        if vm.dropdownOpen { return .ignored }
        let col = vm.selectedCol
        let row = vm.selectedRow
        
        let nav: Set<KeyEquivalent> = [.upArrow, .downArrow, .leftArrow, .rightArrow,
                                       .return, .escape, .tab, .delete, .deleteForward]
        if nav.contains(press.key) { return .ignored }
        
        let char = String(press.key.character)
        guard char.unicodeScalars.first.map({ $0.value >= 32 && $0.value != 127 }) == true,
              !char.isEmpty else { return .ignored }
        
        if !vm.isEditable(col: col) {
            return .ignored
        }
        
        if vm.isDropdown(col: col) { return .ignored }
        
        if vm.isInlineField(col: col) {
            let numberOnly = vm.isNumberOnly(col: col)
            if numberOnly && !char.allSatisfy({ $0.isNumber }) { return .ignored }
            
            // Jangan langsung nimpa di sini jika TextField akan melakukan auto-select
            // Atau set fokus dulu, baru isi datanya
            focus = .cell(row: row, col: col)
            
            // Berikan sedikit delay agar TextField "matang" sebelum karakter dimasukkan
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                vm.rows[row].cells[col] = char
            }
            return .handled
        } else {
            vm.editingText = char
            vm.isEditing = true
            return .handled
        }
    }
}



// MARK: - Preview

struct KeyboardNavigableTableView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
        //.frame(width: 1200, height: 440)
    }
}
