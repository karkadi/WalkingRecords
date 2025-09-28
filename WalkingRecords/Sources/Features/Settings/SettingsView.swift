//
//  SettingsView.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 27/09/2025.
//

import SwiftUI
import ComposableArchitecture

@ViewAction(for: SettingsReducer.self)
struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsReducer>

    var body: some View {
        NavigationView {
            Form {
                Text("Export precision: \(store.exportPrecision, specifier: "%.0f") m")
                Slider(value: $store.exportPrecision,
                       in: 1...300,
                       step: 1) {
                    Text("Export") }
                minimumValueLabel: { Text("1") }
                maximumValueLabel: { Text("300") }
            }
            .toolbar {
                ToolbarItem {
                    Button(
                        action: {
                            send(.cancelButtonTapped)
                        },
                        label: {
                            Image(systemName: "xmark.circle")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 30.0, height: 30.0)
                        }
                    )
                }
            }
        }
    }
}

#Preview {
     SettingsView(store: Store(initialState: SettingsReducer.State(),
                                                reducer: { SettingsReducer() }))
}
