import SwiftUI

public enum RouteStyle {
    case none
    case navigation(
        title: Text,
        barHidden: Bool = false,
        barBackButtonHidden: Bool = false
    )
}

public protocol Routeable {
    var path: [Self] { get }
    
    var style: RouteStyle { get }
}

public extension Routeable {
    var style: RouteStyle { .navigation(title: Text("")) }
}

private extension Sequence {
    /// Creates a new dictionary from the key-value pairs in the given sequence.
    func dictionary<Key: Hashable, Value>(uniqueKeysWithValues entrySelector: (Element) -> (Key, Value)) -> [Key: Value] {
        return Dictionary(uniqueKeysWithValues: map(entrySelector))
    }
}

public class Router<Destination: Routeable>: ObservableObject {
    public enum Delay {
        case milliseconds(Int)
    }

    private struct DispatchNavigation {
        let delay: DispatchTimeInterval
        let workItem: DispatchWorkItem

        func cancel() {
            workItem.cancel()
        }
    }

    @Published public internal(set) var destination: Destination? = nil

    private var navigation: [UUID: DispatchNavigation] = [:]

    public var delay: Delay

    public init(delay: Delay = .milliseconds(550)) {
        self.delay = delay
    }

    private func navigationDelay(iteration: Int) -> DispatchTimeInterval {
        switch delay {
        case let .milliseconds(value):
            return .milliseconds(value * iteration)
        }
    }

    public func navigate(to destination: Destination?) {
        navigation.values.forEach { $0.cancel() }
        navigation.removeAll()

        guard let destination = destination else {
            self.destination = nil
            return
        }

        let currentPath = self.destination?.path ?? []
        let currentDepth = currentPath.count

        let nextPath = destination.path
        let nextDepth = nextPath.count

        let targetDepth = nextDepth - currentDepth
        if targetDepth > 0 {
            // When navigating deeper than one level into a stack, `NavigationView` will fail to push consequitive views
            // unless we wait until it finished pushing the previous one.
            let work = (0 ..< (nextDepth - currentDepth))
                .dictionary { iteration -> (UUID, DispatchNavigation) in
                    let id = UUID()

                    let delay = navigationDelay(iteration: iteration)

                    let workItem = DispatchWorkItem { [weak self] in
                        guard let _ = self?.navigation.removeValue(forKey: id) else { return }

                        let index = currentDepth + iteration
                        self?.destination = nextPath[index]
                    }

                    let navigation = DispatchNavigation(delay: delay, workItem: workItem)

                    return (id, navigation)
                }

            navigation = work

            work.values.forEach { nav in
                DispatchQueue.main.asyncAfter(deadline: .now() + nav.delay, execute: nav.workItem)
            }
        } else {
            self.destination = destination
        }
    }
}

public struct RouteNavigationLink<Destination: Routeable, Content: View>: View {
    let router: Router<Destination>
    
    @Binding var isActive: Bool
    @Binding var path: [Destination]
    
    let route: [Destination]
    let content: (Destination) -> Content
    
    public init(
        router: Router<Destination>,
        isActive: Binding<Bool>,
        path: Binding<[Destination]>,
        route: [Destination],
        @ViewBuilder content: @escaping (Destination) -> Content
    ) {
        self.router = router
        self._isActive = isActive
        self._path = path
        self.route = route
        self.content = content
    }
    
    public var body: some View {
        NavigationLink(isActive: $isActive) {
            if let child = route.first {
                RouteView(
                    router: router,
                    path: $path,
                    destination: child,
                    route: Array(route.dropFirst()),
                    content: content
                )
            }
        } label: { EmptyView() }
            .isDetailLink(false)
            .modifier(NavigationLinkModifier(destination: route.first))
    }
}

struct NavigationLinkModifier<Destination: Routeable>: ViewModifier {
    let destination: Destination?
    
    @ViewBuilder func body(content: Content) -> some View {
        switch destination?.style {
        case let .navigation(title, barHidden, barBackButtonHidden):
            content
                .navigationTitle(title)
                .navigationBarHidden(barHidden)
                .navigationBarBackButtonHidden(barBackButtonHidden)
        default:
            content
                .navigationTitle("")
                .navigationBarHidden(true)
                .navigationBarBackButtonHidden(true)
        }
    }
}

public struct Routes<Root: View, Destination: Routeable, Content: View>: View {
    @ObservedObject var router: Router<Destination>
    
    let root: Root
    let content: (Destination) -> Content
    
    public init(
        router: Router<Destination>,
        @ViewBuilder root: () -> Root,
        @ViewBuilder content: @escaping (Destination) -> Content
    ) {
        self.router = router
        self.root = root()
        self.content = content
    }
    
    var isChildActive: Binding<Bool> {
        Binding(
            get: { router.destination != nil },
            set: { newValue in
                if !newValue {
                    router.destination = nil
                }
            }
        )
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                root
                
                RouteNavigationLink(
                    router: router,
                    isActive: isChildActive,
                    path: path,
                    route: route,
                    content: content
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationViewStyle(.stack)
    }
    
    var path: Binding<[Destination]> {
        Binding(
            get: { router.destination?.path ?? [] },
            set: { router.destination = $0.last }
        )
    }
    
    var route: [Destination] { router.destination?.path ?? [] }
}

public struct RouteView<Destination: Routeable, Content: View>: View {
    let router: Router<Destination>
    
    @Binding var path: [Destination]
    
    let destination: Destination
    let route: [Destination]
    
    let content: (Destination) -> Content
    
    public init(
        router: Router<Destination>,
        path: Binding<[Destination]>,
        destination: Destination,
        route: [Destination],
        @ViewBuilder content: @escaping (Destination) -> Content
    ) {
        self.router = router
        self._path = path
        self.destination = destination
        self.route = route
        self.content = content
    }
    
    var isChildActive: Binding<Bool> {
        Binding(
            get: { !route.isEmpty },
            set: { newValue in
                if !newValue {
                    path = destination.path
                }
            }
        )
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            content(destination)
            
            RouteNavigationLink(
                router: router,
                isActive: isChildActive,
                path: $path,
                route: route,
                content: content
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
