import SwiftUI

struct SearchView: View {
    @State private var searchQuery = ""
    @State private var results: [NaaSearchResult] = []
    @State private var suggestedResults: [NaaSearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Searching NaaSongs...")
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                } else {
                    if results.isEmpty {
                        // Show "Suggested" if results are empty (either no match or empty query)
                        Section(header: Text(searchQuery.isEmpty ? "Trending Albums" : "No results found. Suggested for You")) {
                            ForEach(suggestedResults) { result in
                                AlbumRow(result: result)
                            }
                        }
                    } else {
                        // Display search results
                        Section(header: Text("Search Results")) {
                            ForEach(results) { result in
                                AlbumRow(result: result)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchQuery, prompt: "Search Albums (Telugu, etc.)")
            .onSubmit(of: .search) {
                performSearch()
            }
            .onAppear {
                loadSuggestions()
            }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
    }
    
    private func loadSuggestions() {
        guard suggestedResults.isEmpty else { return }
        Task {
            do {
                let trending = try await NaaSongsService.shared.fetchHomeContent()
                await MainActor.run {
                    self.suggestedResults = Array(trending.prefix(15))
                }
            } catch {
                print("Failed to load search suggestions: \(error)")
            }
        }
    }
    
    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedResults = try await NaaSongsService.shared.search(query: searchQuery)
                await MainActor.run {
                    self.results = fetchedResults
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "NaaSongs Search failed: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

// Extracted Row for consistency
struct AlbumRow: View {
    let result: NaaSearchResult
    
    var body: some View {
        NavigationLink(destination: AlbumDetailView(album: result)) {
            HStack(spacing: 12) {
                if let imageUrlString = result.imageUrl, let imageUrl = URL(string: imageUrlString) {
                    AsyncImage(url: imageUrl) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else if phase.error != nil {
                            Image(systemName: "music.mic").foregroundColor(.gray)
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
                } else {
                    Image(systemName: "music.quarternote.3")
                        .frame(width: 50, height: 50)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.headline)
                        .lineLimit(1)
                }
            }
        }
    }
}
