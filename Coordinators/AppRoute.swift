import Foundation

/// What fills the window: a blank launch backdrop while data loads, the profile picker,
/// or the Home navigation stack.
enum AppRoot: Equatable {
    case loading
    case profilePicker
    case home
}

enum AppRoute: Hashable {
    case picker(category: Category)
    case coloring(itemId: String)
    case celebration(itemId: String)
    case gallery
}

enum AppSheet: Identifiable {
    case parentArea(start: ParentRoute?)

    var id: String { "parentArea" }
}
