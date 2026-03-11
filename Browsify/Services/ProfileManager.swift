//
//  ProfileManager.swift
//  Browsify
//

import Foundation
import Combine

class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    @Published var profiles: [Profile] = []
    @Published var activeProfileId: UUID? = nil

    private init() {
        loadProfiles()
    }

    var activeProfile: Profile? {
        profiles.first { $0.id == activeProfileId }
    }

    func addProfile(_ profile: Profile) {
        profiles.append(profile)
        saveProfiles()
    }

    func updateProfile(_ profile: Profile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            saveProfiles()
        }
    }

    func deleteProfile(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        if activeProfileId == profile.id {
            setActiveProfile(nil)
        }
        saveProfiles()
    }

    func setActiveProfile(_ profile: Profile?) {
        activeProfileId = profile?.id
        if let id = profile?.id {
            UserDefaults.standard.set(id.uuidString, forKey: "activeProfileId")
        } else {
            UserDefaults.standard.removeObject(forKey: "activeProfileId")
        }
    }

    private func saveProfiles() {
        if let encoded = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(encoded, forKey: "profiles")
        }
    }

    private func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: "profiles"),
           let decoded = try? JSONDecoder().decode([Profile].self, from: data) {
            profiles = decoded
        }
        if let idString = UserDefaults.standard.string(forKey: "activeProfileId"),
           let id = UUID(uuidString: idString) {
            activeProfileId = id
        }
    }
}
