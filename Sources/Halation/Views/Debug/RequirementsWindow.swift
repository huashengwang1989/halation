import SwiftUI

/// Debug ▸ Requirements Tables: the memory and disk tables side by side.
///
/// A staging area rather than a destination. Both tables are meant for places a
/// user will actually look — the memory one already appears in Settings and in
/// onboarding — but the numbers behind them rest on estimates worth arguing with
/// before they are put in front of anyone. Seeing both at once makes the
/// relationship legible: less memory means more swap, which means *more* disk,
/// not less.
struct RequirementsWindow: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                section(loc("settings.memory")) { MemoryRequirementsTable() }
                Divider()
                section(loc("settings.disk")) { DiskRequirementsTable() }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 820, minHeight: 560)
    }

    @ViewBuilder
    private func section(_ title: String,
                         @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.weight(.semibold))
            content()
        }
    }
}
