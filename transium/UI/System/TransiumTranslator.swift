//
//  TransiumTranslator.swift
//  transium
//

import Foundation
import SwiftUI

/// Translates static and dynamic API transit strings, quest metadata, and step instructions automatically.
public enum TransiumTranslator {

    /// Translates a given string based on the active app language.
    public static func translate(_ text: String) -> String {
        guard AppLanguageManager.shared.currentLanguage == .indonesia else {
            return text
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Direct Dictionary Match
        if let exact = directTranslations[trimmed] {
            return exact
        }

        var result = trimmed

        // 2. Step & Direction Patterns
        if result.lowercased().hasPrefix("walk to ") {
            let rest = String(result.dropFirst("walk to ".count))
            return "Jalan kaki ke \(rest)"
        }
        if result.lowercased().hasPrefix("walk ") {
            let rest = String(result.dropFirst("walk ".count))
            result = "Jalan kaki \(rest)"
            result = result.replacingOccurrences(of: " to ", with: " ke ")
        }
        if result.lowercased().hasPrefix("board bus ") {
            let rest = String(result.dropFirst("board bus ".count))
            result = "Naik bus \(rest)"
            result = result.replacingOccurrences(of: " towards ", with: " arah ")
        }
        if result.lowercased().hasPrefix("alight at ") {
            let rest = String(result.dropFirst("alight at ".count))
            return "Turun di \(rest)"
        }
        if result.lowercased().hasPrefix("get off at ") {
            let rest = String(result.dropFirst("get off at ".count))
            return "Turun di \(rest)"
        }
        if result.lowercased().hasPrefix("transfer to ") {
            let rest = String(result.dropFirst("transfer to ".count))
            return "Transit ke \(rest)"
        }
        if result.lowercased().hasPrefix("arrive at ") {
            let rest = String(result.dropFirst("arrive at ".count))
            return "Tiba di \(rest)"
        }
        if result.lowercased().hasPrefix("head towards ") {
            let rest = String(result.dropFirst("head towards ".count))
            return "Menuju ke arah \(rest)"
        }
        if result.lowercased().hasPrefix("head south") {
            result = result.replacingOccurrences(of: "head south", with: "jalan ke selatan", options: .caseInsensitive)
        }
        if result.lowercased().hasPrefix("head north") {
            result = result.replacingOccurrences(of: "head north", with: "jalan ke utara", options: .caseInsensitive)
        }
        if result.lowercased().hasPrefix("head east") {
            result = result.replacingOccurrences(of: "head east", with: "jalan ke timur", options: .caseInsensitive)
        }
        if result.lowercased().hasPrefix("head west") {
            result = result.replacingOccurrences(of: "head west", with: "jalan ke barat", options: .caseInsensitive)
        }
        if result.lowercased().hasPrefix("turn right") {
            result = result.replacingOccurrences(of: "turn right", with: "belok kanan", options: .caseInsensitive)
        }
        if result.lowercased().hasPrefix("turn left") {
            result = result.replacingOccurrences(of: "turn left", with: "belok kiri", options: .caseInsensitive)
        }

        // 3. Common transit suffixes and tokens
        result = result
            .replacingOccurrences(of: " mins", with: " mnt")
            .replacingOccurrences(of: " min", with: " mnt")
            .replacingOccurrences(of: " stops", with: " halte")
            .replacingOccurrences(of: " stop", with: " halte")
            .replacingOccurrences(of: " away", with: " lagi")
            .replacingOccurrences(of: "less walking", with: "sedikit jalan kaki", options: .caseInsensitive)
            .replacingOccurrences(of: "recommended", with: "disarankan", options: .caseInsensitive)
            .replacingOccurrences(of: "fastest", with: "tercepat", options: .caseInsensitive)

        return result
    }

    private static let directTranslations: [String: String] = [
        "Culture": "Budaya",
        "Nature": "Alam",
        "Culinary": "Kuliner",
        "Adventure": "Petualangan",
        "Heritage": "Warisan Budaya",
        "Art": "Seni",
        "Shopping": "Belanja",
        "Historical": "Sejarah",
        "Saved": "Tersimpan",
        "Active": "Aktif",
        "Completed": "Selesai",
        "In Progress": "Sedang Berjalan",
        "Start Journey": "Mulai Perjalanan",
        "End Journey": "Akhiri Perjalanan",
        "Go Mode": "Mode Jalan",
        "Explore Bali": "Jelajahi Bali",
        "Where do you want to go?": "Mau pergi ke mana?",
        "Nearby Stops": "Halte Terdekat",
        "Active Quest": "Misi Aktif",
        "Saved Quests": "Misi Tersimpan",
        "No saved quests yet": "Belum ada misi yang tersimpan",
        "Directions": "Petunjuk Arah",
        "Walk": "Jalan Kaki",
        "Walking": "Jalan Kaki",
        "Bus": "Bus",
        "Transfer": "Transit",
        "Current Location": "Lokasi Saat Ini",
        "Destination": "Tujuan",
        "Distance": "Jarak",
        "Cost Saved": "Hemat Biaya",
        "Calories": "Kalori",
        "Total Steps": "Total Langkah",
        "Trip Summary": "Ringkasan Perjalanan",
        "TRIP SUMMARY": "RINGKASAN PERJALANAN",
        "Such a Great Trip! ✨": "Perjalanan yang Hebat! ✨",
        "Share your experience": "Bagikan pengalamanmu",
        "Go to the Next Trip!": "Lanjut ke Perjalanan Berikutnya!",
        "Quest Complete": "Misi Selesai",
        "Transited sustainably with Transium": "Bepergian ramah lingkungan bersama Transium",
        "Settings": "Pengaturan",
        "Language": "Bahasa",
        "Voice": "Suara",
        "Music": "Musik",
        "Permissions": "Izin Akses",
        "Manage notifications & device access": "Kelola notifikasi & akses perangkat",
        "Quest Announcements": "Pengumuman Misi",
        "Get live trip updates, milestone alerts, and reminders.": "Dapatkan info perjalanan langsung, peringatan capaian, dan pengingat.",
        "Promotional Alerts": "Info Promosi",
        "Discover newly unlocked routes and community events.": "Temukan rute baru dan acara komunitas.",
        "Health & Fitness": "Kesehatan & Kebugaran",
        "Track your walking distance, calories, and steps.": "Lacak jarak jalan kaki, kalori, dan langkah Anda.",
        "Sign Out": "Keluar",
        "Signing out...": "Sedang keluar...",
        "Sign out?": "Keluar akun?",
        "Cancel": "Batal",
        "Profile": "Profil",
        "Earned Badges": "Lencana Didapat",
        "Your Badges": "Lencana Kamu",
        "Badges": "Lencana",
        "Gallery": "Galeri",
        "Account": "Akun",
        "Your Adventure Moments": "Momen Petualanganmu",
        "No Adventure Photos Yet": "Belum Ada Foto Petualangan",
        "No Photos Yet": "Belum Ada Foto",
        "Snap photos during your quests and Go Mode journeys to save them here.": "Ambil foto selama misi dan navigasi Mode Jalan untuk menyimpannya di sini.",
        "Snap photos during your journeys and quests to save your travel memories here.": "Ambil foto selama perjalanan dan misi untuk menyimpan kenangan liburanmu di sini.",
        "Take snaps in Go Mode navigation": "Ambil foto saat navigasi Mode Jalan",
        "Start Your Stamp Collection": "Mulai Koleksi Perangkomu",
        "No Badges Yet": "Belum Ada Lencana",
        "Complete bus quests across Bali to earn collectible badges.": "Selesaikan misi bus di Bali untuk mendapatkan lencana koleksi.",
        "Complete bus quests and reach destinations across Bali to unlock unique collectible badges.": "Selesaikan misi bus dan kunjungi berbagai tujuan di Bali untuk membuka lencana perangko unik.",
        "Explore quests on the Home screen": "Jelajahi misi di layar Beranda",
        "No photos yet — they'll show up here once you snap some on a quest.": "Belum ada foto — foto akan muncul di sini setelah kamu mengambilnya saat misi.",
        "Level": "Tingkat",
        "Edit Profile": "Ubah Profil",
        "Edit Account": "Ubah Akun",
        "No badges yet — complete a quest to earn your first one.": "Belum ada lencana — selesaikan misi untuk mendapatkan lencana pertamamu.",
        "Next Stop": "Halte Berikutnya",
        "Get Ready to Get Off": "Bersiap untuk Turun",
        "You have arrived at your destination!": "Anda telah tiba di tujuan!",
        "Complete Trip": "Selesaikan Perjalanan",
        "Remaining": "Tersisa",
        "Steps": "Langkah",
        "Search places or routes": "Cari tempat atau rute"
    ]
}

extension String {
    public var transiumLocalized: String {
        TransiumTranslator.translate(self)
    }
}
