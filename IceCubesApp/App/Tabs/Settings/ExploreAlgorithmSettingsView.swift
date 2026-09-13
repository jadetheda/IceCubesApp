import SwiftUI
import Env
import DesignSystem
import NetworkClient

@MainActor
struct ExploreAlgorithmSettingsView: View {
  @Environment(UserPreferences.self) private var userPreferences
  @Environment(Theme.self) private var theme
  @Environment(FediverseClient.self) private var client

  var body: some View {
    @Bindable var userPreferences = userPreferences
    Form {
      Section {
        Picker("Algorithm", selection: $userPreferences.trendingAlgorithm) {
          ForEach(UserPreferences.TrendingAlgorithm.localCases) { algorithm in
            Text(algorithm.description).tag(algorithm)
          }
        }
        if userPreferences.trendingAlgorithm == .simpleScore {
          Stepper("Posts to search: \(userPreferences.trendingSimpleScoreSearchLimit)", value: $userPreferences.trendingSimpleScoreSearchLimit, in: 20...200, step: 20)
        } else if userPreferences.trendingAlgorithm == .decayingScore {
          VStack(alignment: .leading) {
            Text("settings.content.iceshrimp.trending-algorithm")
              .font(.footnote)
              .foregroundColor(.secondary)
            Stepper(String(format: NSLocalizedString("settings.content.iceshrimp.trending-threshold", comment: ""), userPreferences.iceShrimpTrendingThreshold), value: $userPreferences.iceShrimpTrendingThreshold, in: 1...50)
            Stepper(value: $userPreferences.iceShrimpTrendingHalfLife, in: 0.1...24.0, step: 0.1) {
              Text(String(format: NSLocalizedString("settings.content.iceshrimp.trending-half-life", comment: ""), userPreferences.iceShrimpTrendingHalfLife))
            }
          }
        }
      } header: {
        Text("settings.content.iceshrimp.header")
      } footer: {
        Text("settings.content.iceshrimp.footer")
      }
      #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
      #endif
    }
    .navigationTitle("IceShrimp.net explore algorithm")
    .onAppear {
      if userPreferences.trendingAlgorithm == .mastodon {
        userPreferences.trendingAlgorithm = .decayingScore
      }
    }
    #if !os(visionOS)
    .scrollContentBackground(.hidden)
    .background(theme.secondaryBackgroundColor)
    #endif
  }
}
