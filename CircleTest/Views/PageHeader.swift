import SwiftUI

/// Reusable top nav bar matching the home page style.
struct PageHeader: View {
    let title: String
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.green)
                    .frame(width: 36, height: 36)
                Text(String((appState.currentUser?.name.prefix(2) ?? "ME").uppercased()))
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.black)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 16)
    }
}
