import Foundation

struct SaavnImage: Codable {
    let quality: String
    let url: String
}

struct SaavnDownloadLink: Codable {
    let quality: String
    let url: String
}

struct SaavnSong: Identifiable, Codable {
    let id: String
    let name: String
    let type: String
    let album: SaavnAlbumInfo
    let year: String?
    let releaseDate: String?
    let duration: String?
    let label: String?
    let primaryArtists: String?
    let singers: String?
    let language: String
    let image: [SaavnImage]
    let downloadUrl: [SaavnDownloadLink]
    
    struct SaavnAlbumInfo: Codable {
        let id: String?
        let name: String?
        let url: String?
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, album, year, releaseDate, duration, label, primaryArtists, singers, language, image, downloadUrl
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        album = try container.decode(SaavnAlbumInfo.self, forKey: .album)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        primaryArtists = try container.decodeIfPresent(String.self, forKey: .primaryArtists)
        singers = try container.decodeIfPresent(String.self, forKey: .singers)
        language = try container.decode(String.self, forKey: .language)
        
        // Handle image being false or array
        if let imgs = try? container.decode([SaavnImage].self, forKey: .image) {
            image = imgs
        } else {
            image = []
        }
        
        // Handle downloadUrl being false or array
        if let urls = try? container.decode([SaavnDownloadLink].self, forKey: .downloadUrl) {
            downloadUrl = urls
        } else {
            downloadUrl = []
        }
        
        // Flexible decoding for year (Int or String)
        if let yearStr = try? container.decode(String.self, forKey: .year) {
            year = yearStr
        } else if let yearInt = try? container.decode(Int.self, forKey: .year) {
            year = String(yearInt)
        } else {
            year = nil
        }
        
        // Flexible decoding for duration (Int or String)
        if let durStr = try? container.decode(String.self, forKey: .duration) {
            duration = durStr
        } else if let durInt = try? container.decode(Int.self, forKey: .duration) {
            duration = String(durInt)
        } else {
            duration = nil
        }
    }
}

struct SaavnAlbum: Identifiable, Codable {
    let id: String
    let name: String
    let year: String?
    let releaseDate: String?
    let songCount: String?
    let primaryArtists: String?
    let image: [SaavnImage]
    let songs: [SaavnSong]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, year, releaseDate, songCount, primaryArtists, image, songs
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        primaryArtists = try container.decodeIfPresent(String.self, forKey: .primaryArtists)
        songs = try container.decodeIfPresent([SaavnSong].self, forKey: .songs)
        
        // Handle images
        if let imgs = try? container.decode([SaavnImage].self, forKey: .image) {
            image = imgs
        } else {
            image = []
        }
        
        // Flexible decoding for year
        if let yearStr = try? container.decode(String.self, forKey: .year) {
            year = yearStr
        } else if let yearInt = try? container.decode(Int.self, forKey: .year) {
            year = String(yearInt)
        } else {
            year = nil
        }
        
        // Flexible decoding for songCount
        if let countStr = try? container.decode(String.self, forKey: .songCount) {
            songCount = countStr
        } else if let countInt = try? container.decode(Int.self, forKey: .songCount) {
            songCount = String(countInt)
        } else {
            songCount = nil
        }
    }
}

struct SaavnSearchResponse<T: Codable>: Codable {
    let success: Bool?
    let data: SaavnData<T>?
    
    struct SaavnData<T: Codable>: Codable {
        let results: [T]?
    }
}

struct SaavnAlbumResponse: Codable {
    let success: Bool?
    let data: SaavnAlbum?
}

class JioSaavnService {
    static let shared = JioSaavnService()
    private let baseURL = "https://saavn.dev/api"
    
    private func performRequest<T: Codable>(urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("--- JioSaavn Decoding Error ---")
            print("Error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON: \(jsonString)")
            }
            print("--------------------------------")
            throw error
        }
    }

    func searchAlbums(query: String) async throws -> [SaavnAlbum] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw URLError(.badURL)
        }
        
        let urlString = "\(baseURL)/search/albums?query=\(encodedQuery)"
        let response: SaavnSearchResponse<SaavnAlbum> = try await performRequest(urlString: urlString)
        return response.data?.results ?? []
    }
    
    func getAlbumDetails(id: String) async throws -> SaavnAlbum {
        let urlString = "\(baseURL)/albums?id=\(id)"
        let response: SaavnAlbumResponse = try await performRequest(urlString: urlString)
        if let album = response.data {
            return album
        } else {
            throw URLError(.cannotParseResponse)
        }
    }
    
    func fetchTrending(language: String = "telugu,hindi") async throws -> [SaavnAlbum] {
        let urlString = "\(baseURL)/search/albums?query=\(language)&limit=20"
        let response: SaavnSearchResponse<SaavnAlbum> = try await performRequest(urlString: urlString)
        return response.data?.results ?? []
    }
}

