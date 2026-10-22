import SwiftUI

@main
struct SuperMealPlannerApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                // Dark is the house default everywhere; the phone's own setting still wins when
                // someone turns the app to light in Settings.
                .tint(.accentColor)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.paired {
            MainTabs()
        } else {
            PairView()
        }
    }
}

struct MainTabs: View {
    @Environment(AppModel.self) private var model
    @State private var tab = Tab.today

    enum Tab: Hashable { case today, week, list, kitchen, me }

    var body: some View {
        // The banner sits above the tabs rather than as an inset, so every navigation bar starts
        // below it and nothing is drawn under it.
        VStack(spacing: 0) {
            if model.isDemo { DemoBanner() }
            tabs
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "fork.knife") }
                .tag(Tab.today)
            WeekView()
                .tabItem { Label("Week", systemImage: "calendar") }
                .tag(Tab.week)
            ShoppingView()
                .tabItem { Label("Shopping", systemImage: "cart") }
                .tag(Tab.list)
            KitchenView()
                .tabItem { Label("Kitchen", systemImage: "timer") }
                .tag(Tab.kitchen)
            MeView()
                .tabItem { Label("Me", systemImage: "person.crop.circle") }
                .tag(Tab.me)
        }
    }
}

/// Always on screen in the demo, so nobody mistakes the invented household for a real one.
struct DemoBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            Label("Demo household", systemImage: "sparkles")
                .font(.footnote.weight(.semibold))
            Spacer()
            Button("Leave demo") { model.unpair() }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("demo-banner")
    }
}
