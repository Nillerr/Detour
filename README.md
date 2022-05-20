# Detour

Simple navigation and presentation in SwiftUI.

While Detour itself is only a library it also comes with a recommended architecture for your SwiftUI applications,
which includes some rules for designing your user journeys through your applications, which aim to embrace some of the
limitations posed by SwiftUI.

## SwiftUI Application Architecture

The following chapter describes a set of rules in our recommended architecture for designing SwiftUI applications.

### Rule 1: Avoid Nested Modals

Nested modals in SwiftUI suffer from the limitation that dismissing a modal (using `.sheet` or `.fullScreenCover`)
which itself is presenting another modal results in the second modal remaining on screen, while losing connection
control of its presenting binding.

### Rule 2: Modals are application-wide

Since a modal is content presented on top of other content, the content behind it can freely transition to any other,
and as such the modals presentation state should not be bound to a _content_ view. Using Detour, the singular primary
application view hosts all modals of your application using the `Presentations` view.

### Rule 3: Flows are Navigable

Detour introduces the concept of a `Flow`, which is a special type of SwiftUI `View` that hosts a `NavigationView`,
typically using a `Routes` view. Flows are navigable using `Router<Destination>`, which we recommend you use a
`typealias` for:

```swift
enum ApplicationDestination: Navigable {
  case detail(Detail)

  var path: [ApplicationDestination] {
    switch self {
    case let .detail(detail):
      return [.detail(detail)]
    }
  }
}

typealias ApplicationRouter = Router<ApplicationDestination>

struct ApplicationDestinations: View {
  let router: ApplicationRouter

  let destination: ApplicationDestination

  var body: some View {
    switch destination {
    case .detail(detail):
      DetailView(detail: detail, onDismiss: { router.navigate(to: nil) })
    }
  }
}

struct ApplicationFlow: View {
  @StateObject var router = ApplicationRouter()

  var body: some View {
    Routes(router: router) {
      ListView(onNavigate: { router.navigate(to: ....) })
    } content: { destination in
      ApplicationDestinations(router: router, destination: destination)
    }
  }
}
```

### Rule 4: Views are dumb

Any custom SwiftUI view with the suffix `View` must expose its actions through callbacks. These views may not
reference a `Router`, nor a `Presenter`.

```swift
struct AuthenticationView: View {
  let signedIn: () -> Void

  var body: some View {
    Button("Sign in", action: signedIn)
  }
}
```

### Rule 5: Screens are smart

Any custom SwiftUI view with the suffix `Screen` may bind a `View`s actions to operations on `Router` or `Presenter`.
Screens are largely optional, as they can also be implemented inline within a `Destinations` or `Presentations` view.

```swift
struct AuthenticationScreen: View {
  let router: Router

  var body: some View {
    AuthenticationView(signedIn: { router.navigate(to: nil) })
  }
}
```

### Rule 6: Authentication is completed in a modal

In order to seamlessly transition between from the signed out and the signed in state of your application, we recommend
presenting a modal where the actual authentication is taking place, and only dismissing it once the session has been 
established and the _content_ of the root view has changed to the "signed in" state.

## Presenter

A `Presenter` presents Flows and Views as modals from a root view. Both `sheet` and `fullScreenCover` is supported, and
changing the presented view between either of these awaits the dismissal of the other to avoid issues with SwiftUI.

```swift
import Detour

enum TodoPresentation {
  case edit
}

struct TodoPresentations: View {
  let presenter: Presenter

  let presentation: TodoPresentation
  let style: PresentationStyle

  var body: some View {
      switch presentation {
      case .edit:
        EditView(dismiss: { presenter.dismiss() })
      }
  }
}

typealias TodoPresenter = Presenter<TodoPresentation>

struct ContentView: View {
  @StateObject var presenter = TodoPresenter()
  
  var body: some View {
    Presentations(presenter: presenter) {
      RootView(edit: { presenter.present(.edit) })
    } content: { presentation in
      TodoPresentations(presenter: presenter, presentation: presentation.presentable, style: presentation.style)
    }
  }
}

```

## Router

A `Router` navigates to Views through a `NavigationView` hosted in a `Routes` view.

```swift
import Detour

enum TodoRoutes: Routeable {
  case todo(TodoDetailViewModel)

  var path: [TodoRoutes] {
    switch self {
    case .todo(let todo):
      return [.todo(todo)]
    }
  }
}

typealias TodoRouter = Router<TodoRoutes>

struct ContentView: View {
  @StateObject var router = TodoRouter()

  var body: some View {
    Routes(router: router) {
      TodoListView(selectTodo: { todo in router.navigate(to: .todo(todo)) })
    } content: { destination in
      switch destination {
      case .todo(let todo):
        TodoDetailView(viewModel: todo, dismiss: { router.navigate(to: nil) })
      }
    }
  }
}
```
