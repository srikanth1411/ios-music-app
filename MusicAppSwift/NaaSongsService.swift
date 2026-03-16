import Foundation
import SwiftSoup

struct NaaSearchResult: Identifiable {
    let id = UUID()
    let title: String
    let link: String
    let imageUrl: String?
}

struct NaaSong: Identifiable {
    let id = UUID()
    let title: String
    let downloadUrl: String
}

class NaaSongsService {
    static let shared = NaaSongsService()
    
    // Scrapes the search page: https://naasongs.com.co/?s=telugu
    func search(query: String) async throws -> [NaaSearchResult] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://naasongs.com.co/?s=\(encodedQuery)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        
        let doc = try SwiftSoup.parse(html)
        var results: [NaaSearchResult] = []
        
        let posts = try doc.select(".post-image")
        
        for post in posts.array() {
            if let aTag = try post.select("a").first() {
                let link = try aTag.attr("href")
                let title = try aTag.attr("title").replacingOccurrences(of: " Songs", with: "")
                
                var imageUrl: String? = nil
                if let imgTag = try post.select("img").first() {
                    imageUrl = try imgTag.attr("src")
                }
                
                if !link.isEmpty && !title.isEmpty {
                    results.append(NaaSearchResult(title: title, link: link, imageUrl: imageUrl))
                }
            }
        }
        
        return results
    }
    
    // Scrapes album details to get the .mp3 URLs
    func getSongs(from albumUrl: String) async throws -> [NaaSong] {
        guard let url = URL(string: albumUrl) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        
        let doc = try SwiftSoup.parse(html)
        var songs: [NaaSong] = []
        
        let aTags = try doc.select("a")
        for aTag in aTags.array() {
            let href = try aTag.attr("href")
            if href.lowercased().hasSuffix(".mp3") {
                // Determine title
                var title = try aTag.text()
                // If title is just "Download" or something generic, try looking at the filename or parent element
                if title.lowercased().contains("download") {
                    title = URL(string: href)?.lastPathComponent.replacingOccurrences(of: ".mp3", with: "") ?? "Unknown Song"
                }
                
                // Decode percent-encoded filename for display
                title = title.removingPercentEncoding ?? title
                
                // Skip duplicated lower bitrate links if we have 320kbps
                if href.contains("128") && !songs.isEmpty {
                    continue
                }
                
                let song = NaaSong(title: title.trimmingCharacters(in: .whitespacesAndNewlines), downloadUrl: href)
                // Filter out exact duplicates based on title/url segment
                if !songs.contains(where: { $0.title == song.title || $0.downloadUrl == song.downloadUrl }) {
                    songs.append(song)
                }
            }
        }
        
        return songs
    }
}
