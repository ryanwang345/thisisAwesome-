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
    private var currentStartDate: Date?
    private var isRunning = false

    // Start listening to heart rate
    func start() {
        guard !isRunning else { return }
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        let depthType = HKObjectType.quantityType(forIdentifier: .underwaterDepth)

        // Request workout + underwater depth write, and heart rate read
        var typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let depthType { typesToShare.insert(depthType) }
        let typesToRead: Set<HKObjectType> = [hrType]

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
        guard isRunning else { return }
        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: Date()) { _, _ in }
        cleanupSession()
    }

    /// Completes the workout and persists it to Health / Fitness, attaching depth metadata.
    func completeDive(startDate: Date, endDate: Date, maxDepthMeters: Double) {
        guard isRunning, let builder = workoutBuilder else {
            saveDiveResultLegacy(startDate: startDate,
                                 endDate: endDate,
                                 maxDepthMeters: maxDepthMeters)
            return
        }

        workoutSession?.end()
        builder.endCollection(withEnd: endDate) { [weak self] _, error in
            guard let self else { return }
            if let error {
                print("Failed to end collection: \(error.localizedDescription)")
            }

            builder.finishWorkout { workout, finishError in
                if let finishError {
                    print("Failed to finish workout: \(finishError.localizedDescription)")
                }

                if let depthSample = self.depthSample(maxDepthMeters: maxDepthMeters,
                                                      startDate: startDate,
                                                      endDate: endDate) {
                    builder.add([depthSample]) { success, addError in
                        if !success || addError != nil {
                            let message = addError?.localizedDescription ?? "unknown error"
                            print("Failed to add depth sample to builder: \(message)")
                        }
                    }
                }

                self.cleanupSession()
            }
        }
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
            currentStartDate = Date()
            isRunning = true

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
                    self.isRunning = false
                }
            }
        } catch {
            print("Failed to start workout session: \(error)")
            isRunning = false
        }
    }

    private func saveDiveResultLegacy(startDate: Date, endDate: Date, maxDepthMeters: Double) {
        let activity: HKWorkoutActivityType
        if #available(watchOS 10.0, *) {
            activity = .underwaterDiving
        } else {
            activity = .waterSports
        }

        // Prepare depth sample if available
        var samples: [HKSample] = []
        if let depthType = HKObjectType.quantityType(forIdentifier: .underwaterDepth) {
            let depthQuantity = HKQuantity(unit: HKUnit.meter(), doubleValue: maxDepthMeters)
            let depthSample = HKQuantitySample(type: depthType,
                                               quantity: depthQuantity,
                                               start: startDate,
                                               end: endDate)
            samples.append(depthSample)
        }

        // Prefer HKWorkoutBuilder on watchOS 10+
        if #available(watchOS 10.0, *) {
            let config = HKWorkoutConfiguration()
            config.activityType = activity
            config.locationType = .outdoor

            let builder = HKWorkoutBuilder(healthStore: healthStore,
                                           configuration: config,
                                           device: .local())

            builder.beginCollection(withStart: startDate) { [weak self] started, error in
                guard started, error == nil else {
                    let message = error?.localizedDescription ?? "unknown error"
                    print("Failed to begin workout collection: \(message)")
                    return
                }

                if !samples.isEmpty {
                    builder.add(samples) { success, addError in
                        if !success || addError != nil {
                            let msg = addError?.localizedDescription ?? "unknown error"
                            print("Failed to add depth sample: \(msg)")
                        }
                    }
                }

                builder.endCollection(withEnd: endDate) { _, endError in
                    if let endError {
                        print("Failed to end workout collection: \(endError.localizedDescription)")
                    }
                    builder.finishWorkout { workout, finishError in
                        if let finishError {
                            print("Failed to finish workout: \(finishError.localizedDescription)")
                        } else {
                            if let type = workout?.workoutActivityType.rawValue {
                                print("Saved workout to Health: \(type)")
                            } else {
                                print("Saved workout to Health")
                            }
                        }
                        self?.currentStartDate = nil
                    }
                }
            }
        } else {
            let workout = HKWorkout(activityType: activity,
                                    start: startDate,
                                    end: endDate,
                                    workoutEvents: nil,
                                    totalEnergyBurned: nil,
                                    totalDistance: nil,
                                    device: .local(),
                                    metadata: [
                                        HKMetadataKeyIndoorWorkout: false,
                                        HKMetadataKeyGroupFitness: false
                                    ])

            healthStore.save(workout) { [weak self] success, error in
                if !success || error != nil {
                    let message = error?.localizedDescription ?? "unknown error"
                    print("Failed to save workout: \(message)")
                    return
                }
                guard !samples.isEmpty else { return }
                self?.healthStore.add(samples, to: workout) { addSuccess, addError in
                    if !addSuccess || addError != nil {
                        let msg = addError?.localizedDescription ?? "unknown error"
                        print("Failed to add depth sample: \(msg)")
                    }
                }
            }
        }
    }

    private func depthSample(maxDepthMeters: Double,
                             startDate: Date,
                             endDate: Date) -> HKQuantitySample? {
        guard maxDepthMeters > 0,
              let depthType = HKObjectType.quantityType(forIdentifier: .underwaterDepth) else {
            return nil
        }
        let depthQuantity = HKQuantity(unit: .meter(), doubleValue: maxDepthMeters)
        return HKQuantitySample(type: depthType,
                                quantity: depthQuantity,
                                start: startDate,
                                end: endDate)
    }

    private func cleanupSession() {
        workoutSession?.delegate = nil
        workoutBuilder?.delegate = nil
        workoutBuilder?.dataSource = nil
        workoutSession = nil
        workoutBuilder = nil
        currentStartDate = nil
        isRunning = false
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
