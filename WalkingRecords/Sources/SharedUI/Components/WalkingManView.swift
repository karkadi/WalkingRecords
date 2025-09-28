//
//  WalkingManView.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 27/09/2025.
//

import SwiftUI

struct WalkingManView: View {
    let isWaling: Bool
    let width: CGFloat
    @State private var counter = 0.0
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        TimelineView(.animation) { context in
            Rectangle()
                .colorEffect(ShaderLibrary.walking(
                    .float4(colorScheme == .dark ? 0.0 : 1.0, 0.0, width, width),
                    .float(counter)
                ))
                .frame(width: width, height: width)
                .onChange(of: context.date) { _, _ in
                    if isWaling {
                        counter += 0.01
                    }
                }
        }
    }
}

#Preview {
    WalkingManView(isWaling: true, width: 100.0)
}
