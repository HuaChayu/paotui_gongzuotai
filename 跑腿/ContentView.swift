import SwiftUI

struct ContentView: View {
    var body: some View {
        RootTabs()
    }
}

#Preview {
    ContentView()
        .environment(WorkbenchStore())
        .frame(width: 1440, height: 900)
}
