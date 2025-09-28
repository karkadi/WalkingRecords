//
//  CustomPopoverViewModifier.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 24/09/2025.
//
import SwiftUI

struct CustomPopoverViewModifier<PopoverContent: View>: ViewModifier {
    let popoverContent: () -> PopoverContent
    @Binding var showPopover: Bool
    @State private var baseHeight: CGFloat = 220 // committed detent
    @State private var displayedHeight: CGFloat = 220 // smooth animated height
    @GestureState private var dragOffset: CGFloat = 0

    let detents: [CGFloat] = [220, 500, 800]

    func body(content: Content) -> some View {
        ZStack {
            // Background (still touchable)
            content
            
            if showPopover {
                VStack {
                    Capsule()
                        .frame(width: 40, height: 6)
                        .foregroundColor(.gray)
                        .padding(.top, 8)

                    popoverContent()

                    Spacer()
                }
                .frame(height: displayedHeight)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(radius: 4)
                )
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = -value.translation.height
                        }
                        .onEnded { value in
                            let proposedHeight = baseHeight - value.translation.height
                            withAnimation(.spring()) {
                                baseHeight = nearestDetent(to: proposedHeight)
                                displayedHeight = baseHeight
                            }
                        }
                )
                .transition(.move(edge: .bottom))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .onChange(of: dragOffset) { _, offset in
                    // Smooth updates instead of instant snapping
                    let current = baseHeight + offset
                    let clamped = min(max(current, detents.first ?? 220), detents.last ?? 800)
                    
                    // Smooth interpolation (delayed response)
                    withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.9, blendDuration: 0.25)) {
                        displayedHeight = clamped
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.bottom)
    }

    private func nearestDetent(to value: CGFloat) -> CGFloat {
        detents.min(by: { abs($0 - value) < abs($1 - value) }) ?? value
    }
}

extension View {
    func customPopover<PopoverContent: View>(
        showPopover: Binding<Bool>,
        @ViewBuilder content: @escaping () -> PopoverContent
    ) -> some View {
        self.modifier(CustomPopoverViewModifier(popoverContent: content, showPopover: showPopover))
    }
}

struct ContentView: View {
    @State private var showPopover = false

    var body: some View {
        VStack {
            Button("Toggle Popover") {
                showPopover.toggle()
            }
        }
        .customPopover(showPopover: $showPopover) {
            VStack(spacing: 16) {
                Text("This is a custom popover")
                    .font(.headline)
                Text("Drag me 👇")
                    .font(.headline)
                    .padding()
                Button("Close") {
                    showPopover = false
                }
            }
            .padding()
        }
    }
}

#Preview("Popover Example") {
    ContentView()
}
