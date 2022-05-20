import SwiftUI

public protocol Routeable {
    var path: [Self] { get }
}

public class Router<Destination: Routeable>: ObservableObject {
    @Published public internal(set) var destination: Destination? = nil
    
    private var navigation: [DispatchWorkItem] = []

    public var delay: Int
    
    public init(delay: Int = 550) {
        self.delay = delay
    }
    
    public func navigate(to destination: Destination?) {
        navigation.forEach { $0.cancel() }
        navigation = []
        
        guard let destination = destination else {
            self.destination = nil
            return
        }

        let currentPath = self.destination?.path ?? []
        let currentDepth = currentPath.count
        
        let nextPath = destination.path
        let nextDepth = nextPath.count
        
        // When navigating deeper than one level into a stack, `NavigationView` will fail to push consequitive views
        // unless we wait until it finished pushing the previous one.
        let work = (0..<(nextDepth - currentDepth))
            .map { iteration -> (Int, DispatchWorkItem) in
                let workItem = DispatchWorkItem {
                    let index = currentDepth + iteration
                    self.destination = nextPath[index]
                }
                
                return (iteration, workItem)
            }
        
        navigation = work.map { $1 }
        
        work.forEach { iteration, workItem in
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(iteration * delay), execute: workItem)
        }
    }
}

public struct RouteNavigationLink<Destination: Routeable, Content: View>: View {
    let router: Router<Destination>
    
    @Binding var isActive: Bool
    @Binding var path: [Destination]
    @Binding var children: [Destination]
    
    let content: (Destination) -> Content
    
    public init(
        router: Router<Destination>,
        isActive: Binding<Bool>,
        path: Binding<[Destination]>,
        children: Binding<[Destination]>,
        @ViewBuilder content: @escaping (Destination) -> Content
    ) {
        self.router = router
        self._isActive = isActive
        self._path = path
        self._children = children
        self.content = content
    }
    
    public var body: some View {
        NavigationLink(isActive: $isActive) {
            if let child = children.first {
                RouteView(
                    router: router,
                    path: $path,
                    destination: child,
                    children: Array(children.dropFirst()),
                    content: content
                )
            }
        } label: { EmptyView() }
    }
}

public struct Routes<Root: View, Destination: Routeable, Content: View>: View {
    @ObservedObject var router: Router<Destination>
    
    let root: Root
    let content: (Destination) -> Content
    
    public init(router: Router<Destination>, @ViewBuilder root: () -> Root, @ViewBuilder content: @escaping (Destination) -> Content) {
        self.router = router
        self.root = root()
        self.content = content
    }
    
    var isChildActive: Binding<Bool> {
        Binding(
            get: { router.destination != nil },
            set: { newValue in
                if !newValue && router.destination != nil {
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
                    path: children,
                    children: children,
                    content: content
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    var children: Binding<[Destination]> {
        Binding(
            get: { router.destination?.path ?? [] },
            set: { router.destination = $0.last }
        )
    }
}

public struct RouteView<Destination: Routeable, Content: View>: View {
    let router: Router<Destination>
    
    @Binding var path: [Destination]
    
    let destination: Destination
    let children: [Destination]
    
    let content: (Destination) -> Content
    
    public init(router: Router<Destination>, path: Binding<[Destination]>, destination: Destination, children: [Destination], @ViewBuilder content: @escaping (Destination) -> Content) {
        self.router = router
        self._path = path
        self.destination = destination
        self.children = children
        self.content = content
    }
    
    var isChildActive: Binding<Bool> {
        Binding(
            get: { !children.isEmpty },
            set: { newValue in
                if let _ = children.first, !newValue {
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
                children: .constant(children.dropFirst()),
                content: content
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
