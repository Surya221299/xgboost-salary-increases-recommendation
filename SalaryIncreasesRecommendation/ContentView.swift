import SwiftUI
import Combine
import CoreML
internal import UniformTypeIdentifiers

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
    
    
//    @State private var downloadState: DownloadState = .idle
//    @State private var uploadState: UploadState = .idle
//    @State private var uploadScale: CGFloat = 1.0
    
    // Ganti dengan ini:
    @State private var downloadState: DownloadState = .idle
    @State private var uploadState: UploadState = .idle

    // Scale per-icon, bukan shared
    @State private var downloadIconScale: CGFloat = 1.0
    @State private var uploadIconScale: CGFloat = 1.0

    // Opacity untuk crossfade antar icon
    @State private var downloadIconOpacity: Double = 1.0
    @State private var uploadIconOpacity: Double = 1.0
    

    enum UploadState {
        case idle
        case loading
        case success
    }

    enum DownloadState {
        case idle
        case loading
        case success
    }
    
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
    
    var iconName: String {
        switch downloadState {
        case .idle:
            return "square.and.arrow.down.fill"
        case .loading:
            return "square.and.arrow.down.badge.clock.fill"
        case .success:
            return "square.and.arrow.down.badge.checkmark.fill"
        }
    }

    var iconColor: Color {
        switch downloadState {
        case .success:
            return .green
        case .loading:
                return .yellow
        default:
            return .primary
        }
    }
    
    var uploadIconName: String {
        switch uploadState {
        case .idle:
            return "square.and.arrow.up"
        case .loading:
            return "square.and.arrow.up.badge.clock"
        case .success:
            return "square.and.arrow.up.badge.checkmark.fill"
        }
    }

    var uploadIconColor: Color {
        switch uploadState {
        case .idle:
            return .primary
        case .loading:
            return .yellow
        case .success:
            return .green
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

            // --- Download Button ---
            Button {
                guard downloadState == .idle else { return }
                animateBounceIcon(isDownload: true)
                {
                    downloadCSVTemplate()

                }
            } label: {
                HStack(spacing: 6) {
                    ZStack {
                        // IDLE icon
                        Image(systemName: "square.and.arrow.down.fill")
                            .scaleEffect(downloadState == .idle ? downloadIconScale : 0.01)
                            .opacity(downloadState == .idle ? 1 : 0)

                        // LOADING icon
                        Image(systemName: "square.and.arrow.down.badge.clock.fill")
                            .foregroundColor(.yellow)
                            .scaleEffect(downloadState == .loading ? downloadIconScale : 0.01)
                            .opacity(downloadState == .loading ? 1 : 0)

                        // SUCCESS icon
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .scaleEffect(downloadState == .success ? downloadIconScale : 0.01)
                            .opacity(downloadState == .success ? 1 : 0)
                    }
                    .frame(width: 20, height: 20)
                    .animation(.spring(response: 0.35, dampingFraction: 0.5), value: downloadIconScale)
                    .animation(.easeInOut(duration: 0.15), value: downloadState)

                    Text("download_template.csv")
                        .font(.body)
                        .foregroundColor(
                                downloadState == .success ? .green :
                                downloadState == .loading ? .yellow :
                                .primary
                            )
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(downloadState != .idle)

            // --- Upload Button ---
            Button {
                guard uploadState == .idle else { return }
                animateBounceIcon(isDownload: false) {
                    importCSV()
                }
            } label: {
                HStack(spacing: 6) {
                    ZStack {
                        // IDLE icon
                        Image(systemName: "square.and.arrow.up")
                            .scaleEffect(uploadState == .idle ? uploadIconScale : 0.01)
                            .opacity(uploadState == .idle ? 1 : 0)

                        // LOADING icon
                        Image(systemName: "square.and.arrow.up.badge.clock.fill")
                            .foregroundColor(.yellow)
                            .scaleEffect(uploadState == .loading ? uploadIconScale : 0.01)
                            .opacity(uploadState == .loading ? 1 : 0)

                        // SUCCESS icon
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .scaleEffect(uploadState == .success ? uploadIconScale : 0.01)
                            .opacity(uploadState == .success ? 1 : 0)
                    }
                    .frame(width: 20, height: 20)
                    .animation(.spring(response: 0.35, dampingFraction: 0.5), value: uploadIconScale)
                    .animation(.easeInOut(duration: 0.15), value: uploadState)

                    Text("Upload CSV")
                        .font(.body)
                        .foregroundColor(
                                uploadState == .success ? .green :
                                uploadState == .loading ? .yellow :
                                .primary
                            )
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(uploadState != .idle)

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
            
            // --- Kolom nomor baris (header kosong) ---
            Text("No")
                .font(.headline).fontWeight(.bold)
                .foregroundColor(.primary)
                .frame(width: 36, alignment: .center)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(Rectangle().frame(width: 1)
                    .foregroundColor(Color(NSColor.separatorColor)), alignment: .trailing)
                .overlay(Rectangle().frame(width: 1)
                    .foregroundColor(Color(NSColor.separatorColor)), alignment: .leading)
            
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
        .overlay(Rectangle().frame(height: 1)
            .foregroundColor(Color(NSColor.separatorColor)), alignment: .top)
    }
    
    func animateBounceIcon(isDownload: Bool, action: @escaping () -> Bool) {
        let setScale: (CGFloat) -> Void = { val in
            if isDownload { downloadIconScale = val } else { uploadIconScale = val }
        }
        let setLoading = {
            if isDownload { downloadState = .loading } else { uploadState = .loading }
        }
        let setSuccess = {
            if isDownload { downloadState = .success } else { uploadState = .success }
        }
        let setIdle = {
            if isDownload { downloadState = .idle } else { uploadState = .idle }
        }

        // Step 1: idle icon shrink
        withAnimation(.easeIn(duration: 0.2)) {
            setScale(0.01)
        }

        // Step 2: switch ke loading bounce, lalu langsung jalankan panel (di main thread)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            setLoading()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) {
                setScale(1.0)
            }

            // Sedikit delay agar loading icon sempat muncul sebelum panel muncul
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let confirmed = action() // panel berjalan di sini, blocking sampai user konfirmasi/cancel

                if confirmed {
                    withAnimation(.easeIn(duration: 0.18)) { setScale(0.01) }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        setSuccess()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) {
                            setScale(1.0)
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeIn(duration: 0.15)) { setScale(0.01) }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            setIdle()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                setScale(1.0)
                            }
                        }
                    }
                } else {
                    // Cancel → balik idle tanpa success
                    withAnimation(.easeIn(duration: 0.15)) { setScale(0.01) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        setIdle()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            setScale(1.0)
                        }
                    }
                }
            }
        }
    }
    
    func downloadCSVTemplate() -> Bool {
        let csvString = """
        Name,MonthlyRupiah,Performance,PositionLevel,YearsAtCompany,WorksOvertime
        John Doe,5000000,High,Senior,3,Yes
        Jane Smith,3500000,Medium,Junior,1,No
        """
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "template_hr_data.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        
        guard panel.runModal() == .OK, let url = panel.url else {
            return false // user cancel
        }
        try? csvString.write(to: url, atomically: true, encoding: .utf8)
        return true
    }
    
    func importCSV() -> Bool {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        guard panel.runModal() == .OK, let url = panel.url else {
            return false // user cancel
        }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return false
        }
        
        let parsed = parseCSV(content)
        if !parsed.isEmpty {
            vm.rows = parsed
            vm.didCalculate = false
            vm.selectedRow = 0
            vm.selectedCol = 0
        }
        return true
    }
    
    func parseCSV(_ content: String) -> [TableRow] {
        // Normalize line endings
        let lines = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        guard lines.count > 1 else { return [] }
        
        // Skip header (baris pertama)
        let dataLines = Array(lines.dropFirst())
        
        var result: [TableRow] = []
        
        for line in dataLines {
            let cols = line.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            guard cols.count >= 6 else { continue }
            
            // --- Kolom 0: Name ---
            let name = cols[0]
                .filter { $0.isLetter || $0.isWhitespace }
                .capitalized
            
            // --- Kolom 1: MonthlyRupiah ---
            let salary = cols[1].filter { $0.isNumber }
            
            // --- Kolom 2: Performance → simpan label asli (Low/Medium/High/VeryHigh) ---
            let performance = normalizePerformance(cols[2])
            
            // --- Kolom 3: PositionLevel → simpan angka "1"-"5" ---
            let positionLevel = normalizePositionLevel(cols[3])
            
            // --- Kolom 4: YearsAtCompany → validasi 0-40 ---
            let years = normalizeYears(cols[4])
            
            // --- Kolom 5: WorksOvertime → "Yes" atau "No" ---
            let overtime = normalizeOvertime(cols[5])
            
            // Output dikosongkan, akan diisi oleh calculateAll()
            let cells = [name, salary, performance, positionLevel, years, overtime, ""]
            result.append(TableRow(cells: cells))
        }
        
        return result
    }

    // MARK: - Normalizer Helpers

    func normalizePerformance(_ raw: String) -> String {
        switch raw.lowercased().trimmingCharacters(in: .whitespaces) {
        case "1", "low":      return "Low"
        case "2", "medium":   return "Medium"
        case "3", "high":     return "High"
        case "4", "veryhigh", "very high": return "VeryHigh"
        default:              return ""
        }
    }

    func normalizePositionLevel(_ raw: String) -> String {
        switch raw.lowercased().trimmingCharacters(in: .whitespaces) {
        case "1", "junior":    return "1"
        case "2", "middle":    return "2"
        case "3", "senior":    return "3"
        case "4", "manager":   return "4"
        case "5", "executive": return "5"
        default:               return ""
        }
    }

    func normalizeYears(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber }
        guard let val = Int(digits), val >= 0, val <= 40 else { return "" }
        return String(val)
    }

    func normalizeOvertime(_ raw: String) -> String {
        switch raw.lowercased().trimmingCharacters(in: .whitespaces) {
        case "1", "yes": return "Yes"
        case "0", "no":  return "No"
        default:         return ""
        }
    }
    
    @ViewBuilder
    func columnTypeIcon(colIdx: Int) -> some View {
        switch vm.columnDefs[colIdx].type {
        case .dropdown:
            EmptyView()
        case .number:
            EmptyView()

        case .numberField:
            EmptyView()

        case .textField:
            EmptyView()

        case .text:
            EmptyView()
        }
    }
    
    // MARK: - Row View
    func rowView(rowIdx: Int, row: TableRow) -> some View {
        HStack(spacing: 0) {
            
            // --- Nomor baris ---
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
                .overlay(Rectangle().frame(width: 1)
                    .foregroundColor(Color(NSColor.separatorColor).opacity(0.5)), alignment: .trailing)
                .overlay(Rectangle().frame(width: 1)
                    .foregroundColor(Color(NSColor.separatorColor).opacity(0.5)), alignment: .leading)
            
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
                            
                            Text("+\(String(format: "%.2f", percent))% (Rp.\(Int(totalAmount)))")
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
        
        InlineTextField(
            rowIdx: rowIdx,
            colIdx: colIdx,
            numberOnly: numberOnly,
            colDef: colDef,
            vm: vm,
            focus: $focus
        )
    }
    // MARK: - Helper Formatting
    func formatToIDR(_ string: String) -> String {
        // Pastikan hanya digit yang masuk formatter
        let digitsOnly = string.filter { $0.isNumber }
        guard !digitsOnly.isEmpty, let number = Int(digitsOnly) else { return string }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.groupingSize = 3
        formatter.usesGroupingSeparator = true
        
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
            
            focus = .cell(row: row, col: col)
            
            vm.rows[row].cells[col] = char
            vm.pendingChar = char
            return .handled
        } else {
            vm.editingText = char
            vm.isEditing = true
            return .handled
        }
    }
}

struct InlineTextField: View {
    let rowIdx: Int
    let colIdx: Int
    let numberOnly: Bool
    let colDef: ColumnDef
    @ObservedObject var vm: TableViewModel
    @FocusState.Binding var focus: TableFocus?

    // Local display text — ini yang ditampilkan di TextField
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
                // Format REALTIME setiap karakter berubah
                .onChange(of: displayText) { newVal in
                    if numberOnly {
                        let digits = newVal.filter { $0.isNumber }
                        // Update model dengan angka bersih
                        vm.rows[rowIdx].cells[colIdx] = digits
                        // Format display string dengan titik pemisah
                        let formatted = formatIDR(digits)
                        // Hanya update jika berbeda, hindari loop
                        if formatted != newVal {
                            displayText = formatted
                        }
                    } else {
                        var processed = newVal
                        if colDef.name.lowercased().contains("name") || colDef.name == "EmployeeName" {
                            processed = newVal.filter { $0.isLetter || $0.isWhitespace }
                            processed = processed.capitalized
                        }
                        vm.rows[rowIdx].cells[colIdx] = processed
                        if processed != newVal {
                            displayText = processed
                        }
                    }
                }
                // Sync dari model ke display saat pertama muncul / focus kembali
                .onAppear {
                    let raw = vm.rows[rowIdx].cells[colIdx]
                    displayText = numberOnly ? formatIDR(raw) : raw
                }
                .onChange(of: vm.pendingChar) { char in
                    guard let char = char,
                          vm.isSelected(row: rowIdx, col: colIdx) else { return }
                    // Sync displayText dengan nilai terbaru dari model
                    let raw = vm.rows[rowIdx].cells[colIdx]
                    displayText = numberOnly ? formatIDR(raw) : raw
                    vm.pendingChar = nil // reset flag
                }
                .focused($focus, equals: .cell(row: rowIdx, col: colIdx))
                .onChange(of: focus) { newFocus in
                    // Hanya sync jika focus MASUK ke cell ini (bukan keluar)
                    guard newFocus == .cell(row: rowIdx, col: colIdx) else { return }
                    // Jika ada pendingChar, jangan overwrite — biarkan onChange(pendingChar) yang handle
                    guard vm.pendingChar == nil else { return }
                    let raw = vm.rows[rowIdx].cells[colIdx]
                    displayText = numberOnly ? formatIDR(raw) : raw
                }
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
                    case .upArrow:   vm.moveUp()
                    case .downArrow: vm.moveDown()
                    case .leftArrow: vm.moveLeft()
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
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(width: colDef.width, alignment: .leading)
    }

    func formatIDR(_ digits: String) -> String {
        guard !digits.isEmpty, let number = Int(digits) else { return digits }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.groupingSize = 3
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: number)) ?? digits
    }
}


// MARK: - Preview

struct KeyboardNavigableTableView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
        //.frame(width: 1200, height: 440)
    }
}
