import SwiftUI

/// The memory configurations Apple sells, which both requirements tables are
/// laid out over.
///
/// One list rather than one per table: the two are read side by side, and a
/// column that meant 96 GB in the first and something else in the second would
/// be worse than no column at all.
struct MachineSize: Identifiable {
    /// The size in whole GB, which is stable across relaunches and localisation
    /// in a way a `UUID` or the label is not — so it can be compared against
    /// `thisMac`.
    let id: Int64
    let installedBytes: Int64
    let label: String

    /// The low end of the share a model may hold is the three-quarters rule;
    /// the high end is what Metal reported on a 128 GB M4 Max. Quoting a range
    /// is the honest form: the fraction rises with installed memory, and only
    /// the running machine knows its own.
    var lowBudget: Int64 { installedBytes * 3 / 4 }
    var highBudget: Int64 { installedBytes * 84 / 100 }

    private static let gigabyte: Int64 = 1_073_741_824

    static var all: [MachineSize] {
        [.init(id: 64, installedBytes: 64 * gigabyte,
               label: loc("memory.table.orLess", "64 GB")),
         .init(id: 96, installedBytes: 96 * gigabyte, label: "96 GB"),
         .init(id: 128, installedBytes: 128 * gigabyte, label: "128 GB"),
         .init(id: 192, installedBytes: 192 * gigabyte,
               label: loc("memory.table.orMore", "128 GB"))]
    }

    /// Which column this Mac belongs in, **rounding down**.
    ///
    /// Apple ships the sizes above, but a machine that reports something between
    /// two of them takes the smaller column, so the table can never promise more
    /// headroom than the machine has. Anything under the first column falls into
    /// it, which is why that one is labelled "or less".
    ///
    /// `nil` only if the physical size cannot be read at all.
    static var thisMac: MachineSize? {
        let installed = MachineProfile.physicalBytes
        guard installed > 0 else { return nil }
        return all.last { installed >= $0.installedBytes } ?? all.first
    }
}

/// "You are here" on the column this Mac falls in.
///
/// Deliberately **not** a green tick. The cells below already use one for
/// "Fits", so a tick in the header would read as a verdict on the machine
/// rather than a pointer to it — actively misleading on a 128 GB Mac, where
/// most of that column says "Swaps". A laptop glyph in the accent colour says
/// which column is yours and says nothing about whether that is good news.
struct ThisMacMarker: View {
    var body: some View {
        Image(systemName: "laptopcomputer")
            .imageScale(.small)
            .foregroundStyle(.tint)
            .help(loc("table.thisMac"))
            .accessibilityLabel(loc("table.thisMac"))
    }
}

/// Both requirements tables with their headings, shown in Settings ▸
/// Requirements and on the welcome dialog's second page.
///
/// Assembled here rather than at each call site so the two surfaces cannot
/// drift: the disk figure depends on the memory figure, and a reader who sees
/// one without the other draws the wrong conclusion from it.
struct RequirementsTables: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text(loc("settings.memory")).font(.headline)
                MemoryRequirementsTable()
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text(loc("settings.disk")).font(.headline)
                DiskRequirementsTable()
            }
        }
    }
}
