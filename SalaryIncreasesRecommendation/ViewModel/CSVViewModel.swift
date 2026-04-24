import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - CSVViewModel

class CSVViewModel: ObservableObject {

    // MARK: - Button Animation State
    @Published var downloadState: DownloadState = .idle
    @Published var uploadState:   UploadState   = .idle
    @Published var downloadIconScale: CGFloat   = 1.0
    @Published var uploadIconScale:   CGFloat   = 1.0

    // MARK: - Computed: Download Icon
    var downloadIconName: String {
        switch downloadState {
        case .idle:    return "square.and.arrow.down.fill"
        case .loading: return "square.and.arrow.down.badge.clock.fill"
        case .success: return "checkmark.circle.fill"
        }
    }

    var downloadIconColor: Color {
        switch downloadState {
        case .idle:    return .primary
        case .loading: return .yellow
        case .success: return .green
        }
    }

    var downloadLabelColor: Color { downloadIconColor }

    // MARK: - Computed: Upload Icon
    var uploadIconName: String {
        switch uploadState {
        case .idle:    return "square.and.arrow.up"
        case .loading: return "square.and.arrow.up.badge.clock"
        case .success: return "checkmark.circle.fill"
        }
    }

    var uploadIconColor: Color {
        switch uploadState {
        case .idle:    return .primary
        case .loading: return .yellow
        case .success: return .green
        }
    }

    var uploadLabelColor: Color { uploadIconColor }

    // MARK: - Download Template
    func triggerDownload() {
        guard downloadState == .idle else { return }
        animateBounceIcon(isDownload: true) {
            self.downloadCSVTemplate()
        }
    }

    private func downloadCSVTemplate() -> Bool {
        let csvString = """
        Name,MonthlyRupiah,Performance,PositionLevel,YearsAtCompany,WorksOvertime
        John Doe,5000000,High,Senior,3,Yes
        Jane Smith,3500000,Medium,Junior,1,No
        """

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "template_hr_data.csv"
        panel.allowedContentTypes  = [.commaSeparatedText]

        guard panel.runModal() == .OK, let url = panel.url else { return false }
        try? csvString.write(to: url, atomically: true, encoding: .utf8)
        return true
    }

    // MARK: - Import CSV
    func triggerUpload(onParsed: @escaping ([TableRow]) -> Void) {
        guard uploadState == .idle else { return }
        animateBounceIcon(isDownload: false) {
            self.importCSV(onParsed: onParsed)
        }
    }

    private func importCSV(onParsed: ([TableRow]) -> Void) -> Bool {
        let panel = NSOpenPanel()
        panel.allowedContentTypes    = [.commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories   = false

        guard panel.runModal() == .OK,
              let url     = panel.url,
              let content = try? String(contentsOf: url, encoding: .utf8) else { return false }

        let parsed = CSVParser.parse(content)
        guard !parsed.isEmpty else { return false }
        onParsed(parsed)
        return true
    }

    // MARK: - Bounce Animation
    private func animateBounceIcon(isDownload: Bool, action: @escaping () -> Bool) {
        let setScale: (CGFloat) -> Void = { val in
            if isDownload { self.downloadIconScale = val } else { self.uploadIconScale = val }
        }
        let setLoading = {
            if isDownload {
                self.downloadState = .loading
            } else {
                self.uploadState = .loading }
        }
        let setSuccess = {
            if isDownload {
                self.downloadState = .success
            } else {
                self.uploadState = .success
            } }
        let setIdle    = { if isDownload { self.downloadState = .idle    } else { self.uploadState = .idle    } }

        // Step 1: idle icon shrink
        withAnimation(.easeIn(duration: 0.2)) { setScale(0.01) }

        // Step 2: loading icon bounce in, then run panel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            setLoading()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) { setScale(1.0) }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let confirmed = action()

                if confirmed {
                    // Step 3: loading shrink
                    withAnimation(.easeIn(duration: 0.18)) { setScale(0.01) }
                    // Step 4: success bounce in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        setSuccess()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) { setScale(1.0) }
                    }
                    // Step 5: reset ke idle
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeIn(duration: 0.15)) { setScale(0.01) }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            setIdle()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { setScale(1.0) }
                        }
                    }
                } else {
                    // User cancel → balik idle langsung
                    withAnimation(.easeIn(duration: 0.15)) { setScale(0.01) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        setIdle()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { setScale(1.0) }
                    }
                }
            }
        }
    }
}

// MARK: - CSV Parser (pure static, tidak perlu instance)

enum CSVParser {
    static func parse(_ content: String) -> [TableRow] {
        let lines = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r",   with: "\n")
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard lines.count > 1 else { return [] }

        var result: [TableRow] = []
        for line in lines.dropFirst() {
            let cols = line.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard cols.count >= 6 else { continue }

            let name          = cols[0].filter { $0.isLetter || $0.isWhitespace }.capitalized
            let salary        = cols[1].filter { $0.isNumber }
            let performance   = normalizePerformance(cols[2])
            let positionLevel = normalizePositionLevel(cols[3])
            let years         = normalizeYears(cols[4])
            let overtime      = normalizeOvertime(cols[5])

            result.append(TableRow(cells: [name, salary, performance, positionLevel, years, overtime, ""]))
        }
        return result
    }

    static func normalizePerformance(_ raw: String) -> String {
        switch raw.lowercased().trimmingCharacters(in: .whitespaces) {
        case "1", "low":                      return "Low"
        case "2", "medium":                   return "Medium"
        case "3", "high":                     return "High"
        case "4", "veryhigh", "very high":    return "VeryHigh"
        default:                              return ""
        }
    }

    static func normalizePositionLevel(_ raw: String) -> String {
        switch raw.lowercased().trimmingCharacters(in: .whitespaces) {
        case "1", "junior":    return "1"
        case "2", "middle":    return "2"
        case "3", "senior":    return "3"
        case "4", "manager":   return "4"
        case "5", "executive": return "5"
        default:               return ""
        }
    }

    static func normalizeYears(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber }
        guard let val = Int(digits), val >= 0, val <= 40 else { return "" }
        return String(val)
    }

    static func normalizeOvertime(_ raw: String) -> String {
        switch raw.lowercased().trimmingCharacters(in: .whitespaces) {
        case "1", "yes": return "Yes"
        case "0", "no":  return "No"
        default:         return ""
        }
    }
}
