import Foundation
import SwiftSoup

struct NaaSearchResult: Identifiable, Codable {
    let id: UUID
    let title: String
    let link: String
    let imageUrl: String?
    
    init(id: UUID = UUID(), title: String, link: String, imageUrl: String?) {
        self.id = id
        self.title = title
        self.link = link
        self.imageUrl = imageUrl
    }
}

struct NaaSong: Identifiable, Codable {
    let id: UUID
    let title: String
    let downloadUrl: String
    let artworkUrl: String?
    
    init(id: UUID = UUID(), title: String, downloadUrl: String, artworkUrl: String? = nil) {
        self.id = id
        self.title = title
        self.downloadUrl = downloadUrl
        self.artworkUrl = artworkUrl
    }
}

class NaaSongsService {
    static let shared = NaaSongsService()
    
    // Scrapes the home page: https://naasongs.com.co/
    func fetchHomeContent() async throws -> [NaaSearchResult] {
        guard let url = URL(string: "https://naasongs.com.co/") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              let html = String(data: data, encoding: .utf8) else {
            print("NaaSongs: Failed to get Home HTML")
            throw URLError(.badServerResponse)
        }
        
        print("NaaSongs: Home status \(httpResponse.statusCode), body length: \(html.count)")
        let doc = try SwiftSoup.parse(html)
        return try parseArticles(from: doc)
    }
    
    // Scrapes the search page: https://naasongs.com.co/?s=telugu
    func search(query: String) async throws -> [NaaSearchResult] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://naasongs.com.co/?s=\(encodedQuery)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              let html = String(data: data, encoding: .utf8) else {
            print("NaaSongs: Failed to get Search HTML or response")
            throw URLError(.badServerResponse)
        }
        
        print("NaaSongs: Search status \(httpResponse.statusCode), body length: \(html.count)")
        
        let doc = try SwiftSoup.parse(html)
        return try parseArticles(from: doc)
    }

    private func parseArticles(from doc: Document) throws -> [NaaSearchResult] {
        var results: [NaaSearchResult] = []
        
        // The theme seems to use <article> tags for albums
        let articles = try doc.select("article")
        print("NaaSongs: Found \(articles.size()) article tags")
        
        for article in articles.array() {
            // Title and Link are usually in the entry-title h2
            if let titleTag = try article.select("h2.entry-title a").first() {
                let link = try titleTag.attr("href")
                let titleText = try titleTag.text()
                
                let title = titleText.replacingOccurrences(of: " Songs", with: "").replacingOccurrences(of: " Songs download", with: "")
                
                var imageUrl: String? = nil
                if let imgTag = try article.select("img.wp-post-image").first() {
                    imageUrl = try imgTag.attr("src")
                } else if let imgTag = try article.select("img").first() {
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
            print("NaaSongs: Failed to get album details")
            throw URLError(.badServerResponse)
        }
        
        print("NaaSongs: Album page length: \(html.count)")
        
        let doc = try SwiftSoup.parse(html)
        var songs: [NaaSong] = []
        
        let albumArtwork: String?
        if let imgTag = try doc.select("img.wp-post-image").first() {
            albumArtwork = try imgTag.attr("src")
        } else if let imgTag = try doc.select("img").first() {
            albumArtwork = try imgTag.attr("src")
        } else {
            albumArtwork = nil
        }
        
        let aTags = try doc.select("a")
        print("NaaSongs: Found \(aTags.size()) total links on album page")
        
        for aTag in aTags.array() {
            let href = try aTag.attr("href")
            if href.lowercased().hasSuffix(".mp3") {
                print("NaaSongs: Found mp3 link: \(href)")
                // Determine title
                var title = try aTag.text().trimmingCharacters(in: .whitespacesAndNewlines)
                
                // If title is just "Download" or something generic, try looking at the parent's text
                if title.lowercased() == "download" || title.isEmpty {
                    if let parent = aTag.parent() {
                        let parentText = try parent.text()
                        if let separatorIndex = parentText.firstIndex(of: "–") {
                            title = String(parentText[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                        } else if let dashIndex = parentText.firstIndex(of: "-") {
                            title = String(parentText[..<dashIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                        } else {
                            title = parentText.replacingOccurrences(of: "Download", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                }
                
                // Final fallback to Filename
                if title.lowercased() == "download" || title.isEmpty || title.count > 100 {
                    title = URL(string: href)?.lastPathComponent.replacingOccurrences(of: ".mp3", with: "") ?? "Unknown Song"
                    title = title.removingPercentEncoding ?? title
                }
                
                // Cleanup common remnants
                title = title.replacingOccurrences(of: " Song", with: "")
                title = title.replacingOccurrences(of: " song", with: "")
                
                // Skip duplicated lower bitrate links if we have 320kbps
                if href.contains("128") && groupsOf320Exist(in: aTags) {
                    continue
                }
                
                let song = NaaSong(title: title.trimmingCharacters(in: .whitespacesAndNewlines), downloadUrl: href, artworkUrl: albumArtwork)
                // Filter out exact duplicates based on title/url segment
                if !songs.contains(where: { $0.title == song.title || $0.downloadUrl == song.downloadUrl }) {
                    songs.append(song)
                }
            }
        }
        
        return songs
    }
    
    private func groupsOf320Exist(in tags: Elements) -> Bool {
        return tags.array().contains { (try? $0.attr("href").contains("320")) ?? false }
    }
}
