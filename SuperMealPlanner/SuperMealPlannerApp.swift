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
