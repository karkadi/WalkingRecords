//  SettingsReducerTests.swift
//  WalkingRecordsTests
//
//  Created by Assistant on 03/10/2025.
//

import Testing
import ComposableArchitecture
@testable import WalkingRecords

@MainActor
@Suite("SettingsReducer Tests")
struct SettingsReducerTests {
    @Test("Initial state has exportPrecision == 1.0")
    func testInitialState() async {
        let store = TestStore(initialState: SettingsReducer.State()) {
            SettingsReducer()
        }
        #expect(store.state.exportPrecision == 1.0)
    }
    
    @Test("Changing exportPrecision updates state")
    func testExportPrecisionBinding() async {
        let store = TestStore(initialState: SettingsReducer.State()) {
            SettingsReducer()
        }
        
        await store.send(.binding(.set(\.exportPrecision, 123.0))) { state in
            state.$exportPrecision.withLock { $0 = 123.0 }
        }
    }
    
    @Test("Cancel button propagates to parent and dismisses settings")
    func testCancelButtonTappedPropagatesToParent() async {
        let initialSettingsState = SettingsReducer.State()
        let store = TestStore(initialState: WalkTrackerReducer.State(settings: initialSettingsState)) {
            WalkTrackerReducer()
        }
        await store.send(.settings(.presented(.view(.cancelButtonTapped))))
        #expect(store.state.settings == nil, "WalkTrackerReducer cleared settings on cancel")
    }

}
