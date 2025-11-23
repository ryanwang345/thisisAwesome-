//  HeartRateManager.swift
//  FreeDiving Computer Watch App

import Foundation
import HealthKit
import Combine

final class HeartRateManager: NSObject, ObservableObject {
    @Published var heartRate: Int = 0

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    // Start listening to heart rate
  func start() {
      guard HKHealthStore.isHealthDataAvailable() else { return }
      guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

      // We need workout share permission to run a live workout session.
      let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
      let typesToRead: Set<HKObjectType>  = [hrType]

      healthStore.requestAuthorization(
          toShare: typesToShare,
          read: typesToRead
      ) { [weak self] success, error in
          guard success, error == nil else {
              print("HealthKit auth failed: \(error?.localizedDescription ?? "unknown error")")
              return
          }
          guard let self = self else { return }

          DispatchQueue.main.async {
              self.startWorkoutSession(heartRateType: hrType)
          }
      }
  }


    // Stop listening
    func stop() {
        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: Date()) { _, _ in }
        workoutSession = nil
        workoutBuilder = nil
    }

    // MARK: - Private

    private func startWorkoutSession(heartRateType: HKQuantityType) {
        let config = HKWorkoutConfiguration()
        config.activityType = .waterSports      // close enough to freediving
        config.locationType = .outdoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()

            workoutSession = session
            workoutBuilder = builder

            session.delegate = self
            builder.delegate = self

            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: config
            )

            let startDate = Date()
            session.startActivity(with: startDate)
            builder.beginCollection(withStart: startDate) { _, error in
                if let error {
                    print("Failed to begin workout collection: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Failed to start workout session: \(error)")
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension HeartRateManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        // Optional: react to paused / ended / etc.
    }

    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didFailWithError error: Error) {
        print("Workout session failed: \(error)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension HeartRateManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Not needed for now
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {

        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(hrType),
              let stats = workoutBuilder.statistics(for: hrType),
              let quantity = stats.mostRecentQuantity()
        else { return }

        let unit = HKUnit.count().unitDivided(by: .minute())   // bpm
        let bpm  = quantity.doubleValue(for: unit)

        DispatchQueue.main.async {
            self.heartRate = Int(bpm.rounded())
        }
    }
}
