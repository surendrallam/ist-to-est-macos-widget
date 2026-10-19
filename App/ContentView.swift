import AppKit
import SwiftUI
import TimeConversionKit

struct ContentView: View {
    @State private var previewStyle: WidgetStyle = .worldClock
    @State private var previewSize: WidgetSize = .medium

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                livePreview
                ConverterView()
                AddWidgetGuide()
                footer
            }
            .padding(24)
        }
        .frame(width: 460)
        .frame(minHeight: 560, idealHeight: 760)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("IST to EST")
                    .font(.title.bold())
                Text("India time and US Eastern time, always one glance away.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var livePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Widget preview")
                .font(.headline)
            HStack {
                Picker("Style", selection: $previewStyle) {
                    ForEach(WidgetStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)
                Spacer()
                Picker("Size", selection: $previewSize) {
                    ForEach(WidgetSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)
            }
            // Ticks every second so the digital style's seconds move, as they do in the widget.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                WidgetPreviewCard(size: previewSize) {
                    WidgetContent(style: previewStyle, size: previewSize, date: context.date)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Link("Website", destination: AppLinks.website)
            Link("Source code", destination: AppLinks.repository)
            Link("Report an issue", destination: AppLinks.issues)
            Spacer()
            Text("Version \(Bundle.main.shortVersion)")
                .foregroundStyle(.tertiary)
        }
        .font(.footnote)
    }
}

/// Pick a time in one zone and read it in the other.
struct ConverterView: View {
    @State private var isReversed = false
    @State private var selection = Date()
    @State private var didCopy = false

    @Environment(\.locale) private var locale

    private var converter: TimeConverter {
        isReversed ? TimeConverter().reversed : TimeConverter()
    }

    var body: some View {
        let snapshot = converter.snapshot(at: selection)
        let source = ClockStrings(snapshot.source, locale: locale)
        let target = ClockStrings(snapshot.target, locale: locale)

        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    DatePicker(
                        "\(converter.source.name) (\(snapshot.source.abbreviation))",
                        selection: $selection,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .environment(\.timeZone, converter.source.timeZone)

                    Button {
                        isReversed.toggle()
                    } label: {
                        Label("Swap", systemImage: "arrow.left.arrow.right")
                    }
                    .help("Convert the other way")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(converter.target.name) (\(snapshot.target.abbreviation))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        DigitalTimeText(strings: target, size: 34)
                            .fixedSize()
                        Text(target.date)
                            .foregroundStyle(.secondary)
                        if snapshot.dayOffset != 0 {
                            Text(OffsetDescription.dayShift(snapshot.dayOffset))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                    Text(OffsetDescription.sentence(snapshot.offset, subject: converter.target.city, reference: converter.source.city))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Now") { selection = Date() }
                    Spacer()
                    Button {
                        // ICU puts a narrow no-break space (U+202F) before AM/PM; paste plain spaces instead.
                        copy(
                            "\(source.full) \(snapshot.source.abbreviation) (\(source.date)) = \(target.full) \(snapshot.target.abbreviation) (\(target.date))"
                                .replacingOccurrences(of: "\u{202F}", with: " ")
                        )
                    } label: {
                        Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                    }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                }
            }
            .padding(8)
        } label: {
            Text("Convert a time")
                .font(.headline)
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            didCopy = false
        }
    }
}

/// Step-by-step instructions for pinning the widget.
struct AddWidgetGuide: View {
    private let steps: [(symbol: String, text: LocalizedStringKey)] = [
        ("calendar.badge.clock", "Click the date and time in the menu bar to open Notification Center."),
        ("slider.horizontal.3", "Scroll to the bottom and click **Edit Widgets**."),
        ("magnifyingglass", "Search for **IST to EST** — choose the World Clock or the Digital widget."),
        ("hand.draw", "Pick Small, Medium or Large and drag it into Notification Center — or onto your desktop."),
    ]

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.callout.weight(.bold))
                            .monospacedDigit()
                            .frame(width: 22, height: 22)
                            .background(Color.accentColor.opacity(0.15), in: Circle())
                        Label(step.text, systemImage: step.symbol)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text("Keep the app in your Applications folder so macOS can find the widget. It doesn't need to stay open.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Add the widget")
                .font(.headline)
        }
    }
}

extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }
}

#Preview {
    ContentView()
}
