import SwiftUI

struct SearchView: View {
    @State private var searchQuery = ""
    @State private var results: [NaaSearchResult] = []
    @State private var suggestedResults: [NaaSearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Error>?
    
    var body: some View {
        NavigationView {
            List {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
                
                if results.isEmpty {
                    if searchQuery.isEmpty {
                        // Show Trending only when not searching
                        Section(header: Text("Trending Albums")) {
                            ForEach(suggestedResults) { result in
                                AlbumRow(result: result)
                            }
                        }
                    } else if !isLoading {
                        // User requested to "just show not found"
                        Text("Not Found")
                            .foregroundColor(.secondary)
                            .padding()
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
            .navigationTitle("Search")
            .searchable(text: $searchQuery, prompt: "Search Song or Movie (Telugu)")
            .onChange(of: searchQuery) { newValue in
                performDebouncedSearch()
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
    
    private func performDebouncedSearch() {
        searchTask?.cancel()
        
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedQuery.isEmpty {
            results = []
            isLoading = false
            errorMessage = nil
            return
        }
        
        // Immediately indicate we are in search mode
        // Clear results and set isLoading to true so UI hides Trending and "Not Found"
        results = []
        isLoading = true
        errorMessage = nil
        
        searchTask = Task {
            // Debounce for 300ms
            try await Task.sleep(nanoseconds: 300 * 1_000_000)
            
            do {
                let fetchedResults = try await NaaSongsService.shared.search(query: searchQuery)
                if !Task.isCancelled {
                    await MainActor.run {
                        self.results = fetchedResults
                        self.isLoading = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.errorMessage = "Search failed: \(error.localizedDescription)"
                        self.isLoading = false
                    }
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
