//
//  SettingsView.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import SwiftUI

/// Privacy and integration settings (NFR-002).
struct SettingsView: View {
    @AppStorage(Brandfetch.fetchesLogosKey) private var fetchesLogos = true
    @AppStorage(Appearance.key) private var appearance = Appearance.system
    @AppStorage(OviStore.isShownKey) private var showsOvi = true
    @Environment(OviEngine.self) private var ovi
    @State private var didResetOvi = false
    #if DEBUG
    @AppStorage(DataMode.key) private var dataMode = DataMode.current
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(String(localized: "Settings"))
                .padding(.horizontal, Space.xl)
                .padding(.top, 20)
            form
        }
        .background(Color.canvas)
    }

    private var form: some View {
        Form {
            Section(civa: "General") {
                LabeledContent("Appearance") {
                    SegmentedTabs(Appearance.allCases, selection: $appearance, title: \.title)
                }
                Toggle("Show Ovi", isOn: $showsOvi)
                    .onChange(of: showsOvi) { ovi.refresh() }
                LabeledContent("Ovi's tips") {
                    Button(didResetOvi ? "Tips Reset" : "Reset Ovi's Tips") {
                        OviStore().reset()
                        didResetOvi = true
                    }
                    .civaButton(.textLink)
                    .disabled(didResetOvi)
                    .help("Ovi can show every tip again, including ones you closed or turned off")
                }
            }
            UpdatesSection()
            WorkspacesSection()
            ClaudeSettingsSection()
            Section {
                Toggle("Fetch Logos Online", isOn: $fetchesLogos)
                    .disabled(Brandfetch.clientID == nil)
            } header: {
                SectionTitle("Logos")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("When you type a company or school name, Civa looks up matching brands on Brandfetch and shows their logos. Only the names you type are sent. Everything else stays on this Mac, and logos never appear on your resume.")
                    if Brandfetch.clientID == nil {
                        Text("Logo lookup isn't set up in this build.")
                    }
                }
            }
            #if DEBUG
            Section {
                Picker("Data", selection: $dataMode) {
                    ForEach(DataMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            } header: {
                SectionTitle("Developer")
            } footer: {
                Text("Sample and Empty start fresh every launch, so testing never touches your real data. Empty also shows the welcome, Getting Started, and tips again. Takes effect after you restart Civa.")
            }
            #endif
        }
        .civaForm()
    }
}

#Preview {
    SettingsView()
        .environment(OviEngine())
        .frame(width: 700, height: 400)
}
