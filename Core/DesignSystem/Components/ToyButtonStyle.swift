import SwiftUI

/// "Toy-like" press style: a solid bottom shadow that the face sinks into when pressed,
/// plus a light haptic on press. Shared by every kid-facing button.
struct ToyButtonStyle<S: InsettableShape>: ButtonStyle {
    let shape: S
    let fill: Color
    let shadow: Color
    var depth: CGFloat = DSMetrics.buttonShadow
    var pressedScale: CGFloat = 1

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .background(shape.fill(fill))
            .offset(y: pressed ? depth * 0.6 : 0)
            .background(shape.fill(shadow).offset(y: depth))
            .contentShape(shape)
            .scaleEffect(pressed ? pressedScale : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
            .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, isPressed in isPressed }
    }
}
