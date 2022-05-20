import SwiftUI

public struct Presentation<Presentable> {
    public let presentable: Presentable
    public let style: PresentationStyle
    
    public init(presentable: Presentable, style: PresentationStyle) {
        self.presentable = presentable
        self.style = style
    }
}

public enum PresentationStyle {
    case sheet
    case fullScreenCover
}

public class Presenter<Presentable>: ObservableObject {
    @Published public internal(set) var presentation: Presentation<Presentable>?
    
    public init() {
    }
    
    public func present(_ presentable: Presentable, style: PresentationStyle = .sheet) {
        presentation = Presentation(presentable: presentable, style: style)
    }
    
    public func dismiss(completion: (() -> Void)? = nil) {
        presentation = nil
        
        if let completion = completion {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(550)) {
                completion()
            }
        }
    }
}

public struct Presentations<Presentable, Root: View, Content: View>: View {
    let presenter: Presenter<Presentable>
    
    var onDismiss: ((Presentable) -> Void)?
    
    let root: Root
    let content: (Presentation<Presentable>) -> Content
    
    @State var nextPresentation: Presentation<Presentable>?
    
    @State var currentSheet: Presentation<Presentable>?
    @State var currentFullScreenCover: Presentation<Presentable>?
    
    public init(
        presenter: Presenter<Presentable>,
        onDismiss: ((Presentable) -> Void)? = nil,
        @ViewBuilder root: () -> Root,
        @ViewBuilder content: @escaping (Presentation<Presentable>) -> Content
    ) {
        self.presenter = presenter
        self.onDismiss = onDismiss
        self.root = root()
        self.content = content
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            root
            
            VStack {}
                .sheet(isPresented: isCurrentSheetActive, onDismiss: _onDismiss) {
                    if let current = currentSheet {
                        content(current)
                    }
                }
            
            VStack {}
                .fullScreenCover(isPresented: isCurrentFullScreenCoverActive, onDismiss: _onDismiss) {
                    if let current = currentFullScreenCover {
                        content(current)
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(presenter.$presentation) { presentation in
            if let presentation = presentation {
                if currentSheet != nil || currentFullScreenCover != nil {
                    enqueue(presentation)
                } else {
                    present(presentation)
                }
            } else {
                clear()
            }
        }
    }
    
    var isCurrentSheetActive: Binding<Bool> {
        Binding<Bool>(get: { currentSheet != nil }, set: { newValue in
            if !newValue {
                currentSheet = nil
            }
        })
    }
    
    var isCurrentFullScreenCoverActive: Binding<Bool> {
        Binding<Bool>(get: { currentFullScreenCover != nil }, set: { newValue in
            if !newValue {
                currentFullScreenCover = nil
            }
        })
    }
    
    private func _onDismiss() {
//        if let previous = self.previous {
//            onDismiss(previous)
//        }
        
        if let presentation = self.nextPresentation {
            present(presentation)
        } else if presenter.presentation != nil {
            presenter.presentation = nil
        }
    }
    
    private func enqueue(_ presentation: Presentation<Presentable>) {
        nextPresentation = presentation
        
        currentSheet = nil
        currentFullScreenCover = nil
    }
    
    private func present(_ presentation: Presentation<Presentable>) {
        nextPresentation = nil
        
        currentSheet = presentation.style == .sheet ? presentation : nil
        currentFullScreenCover = presentation.style == .fullScreenCover ? presentation : nil
    }
    
    private func clear() {
        nextPresentation = nil
        
        currentSheet = nil
        currentFullScreenCover = nil
    }
}
