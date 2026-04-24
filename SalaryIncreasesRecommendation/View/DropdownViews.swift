import SwiftUI

// MARK: - DropdownPopup

struct DropdownPopup: View {
    let options: [String]
    @Binding var highlighted: Int
    let currentValue: String
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

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
                        .onTapGesture { onSelect(option) }
                        .onHover { if $0 { highlighted = idx } }
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
            .onAppear { proxy.scrollTo(highlighted, anchor: .center) }
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

// MARK: - DropdownRow

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
