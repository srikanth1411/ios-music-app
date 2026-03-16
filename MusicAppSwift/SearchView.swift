import SwiftUI

struct SearchView: View {
    @State private var searchQuery = ""
    @State private var results: [NaaSearchResult] = []
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
                } else if results.isEmpty && !searchQuery.isEmpty {
                    Text("No results found on NaaSongs.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(results) { result in
                        NavigationLink(destination: AlbumDetailView(album: result)) {
                            HStack {
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
                                
                                VStack(alignment: .leading) {
                                    Text(result.title)
                                        .font(.headline)
                                    Text("Telugu Album") // Default since NaaSongs results don't always have artist here
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Music Search")
            .searchable(text: $searchQuery, prompt: "Search NaaSongs (Telugu, etc.)")
            .onSubmit(of: .search) {
                performSearch()
            }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
    }
    
    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        results = []
        
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
