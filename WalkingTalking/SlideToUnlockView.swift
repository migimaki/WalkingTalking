import SwiftUI

struct SlideToUnlockView: View {
    let onUnlock: () -> Void

    @State private var sliderOffset: CGFloat = 0
    @State private var sliderWidth: CGFloat = 0

    private let sliderHeight: CGFloat = 60
    private let thumbSize: CGFloat = 52
    private let unlockThreshold: CGFloat = 0.85 // 85% of the way triggers unlock

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: sliderHeight / 2)
                    .fill(Color(.systemGray5))
                    .overlay(
                        RoundedRectangle(cornerRadius: sliderHeight / 2)
                            .strokeBorder(Color(.systemGray4), lineWidth: 1)
                    )

                // Text label
                HStack {
                    Spacer()
                    Text("Slide to unlock")
                        .foregroundColor(.secondary)
                        .font(.system(size: 17, weight: .medium))
                    Spacer()
                }
                .opacity(1 - Double(sliderOffset / (geometry.size.width - thumbSize)))

                // Draggable thumb
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                    Image(systemName: "lock.open.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(width: thumbSize, height: thumbSize)
                .offset(x: sliderOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only allow sliding to the right
                            let maxOffset = geometry.size.width - thumbSize
                            let newOffset = min(max(0, value.translation.width), maxOffset)
                            sliderOffset = newOffset
                        }
                        .onEnded { value in
                            let maxOffset = geometry.size.width - thumbSize

                            // Check if slider reached the unlock threshold
                            if sliderOffset > maxOffset * unlockThreshold {
                                // Unlock action
                                withAnimation(.spring(response: 0.3)) {
                                    sliderOffset = maxOffset
                                }

                                // Trigger unlock after a brief delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onUnlock()

                                    // Reset slider
                                    withAnimation(.spring(response: 0.3)) {
                                        sliderOffset = 0
                                    }
                                }
                            } else {
                                // Snap back to start
                                withAnimation(.spring(response: 0.3)) {
                                    sliderOffset = 0
                                }
                            }
                        }
                )
            }
            .frame(height: sliderHeight)
            .onAppear {
                sliderWidth = geometry.size.width
            }
        }
        .frame(height: sliderHeight)
    }
}

#Preview {
    VStack {
        SlideToUnlockView {
            print("Unlocked!")
        }
        .padding()
    }
}
