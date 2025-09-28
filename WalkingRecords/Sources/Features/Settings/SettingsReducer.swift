//
//  SettingsReducer.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 27/09/2025.
//

import ComposableArchitecture
import Foundation

@Reducer
struct SettingsReducer {
    // MARK: - Dependencies
    @Dependency(\.dismiss) var dismiss
    
    // MARK: - State
    @ObservableState
    public struct State: Equatable {
        @Shared(.appStorage("exportPrecision")) var exportPrecision: Double = 1.0
    }
    
    // MARK: - Action
    public enum Action: ViewAction, BindableAction {
        case binding(BindingAction<State>)
        case view(View)
        // swiftlint:disable nesting
        public enum View {
            case cancelButtonTapped
        }
        // swiftlint:enable nesting
    }
    
    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce(core)
    }
    
    // MARK: - Reducer
    private func core(
        _ state: inout State,
        _ action: Action
    ) -> Effect<Action> {
        switch action {
        case let .view(viewAction):
            switch viewAction {
            case .cancelButtonTapped:
                return .run { _ in
                    await self.dismiss()
                }
            }
        case .binding:
            return .none
        }
    }
    
}
