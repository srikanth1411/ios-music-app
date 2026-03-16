import SwiftUI

struct HomeView: View {
    @State private var latestAlbums: [NaaSearchResult] = []
    @State private var trendingAlbums: [NaaSearchResult] = []
    @State private var featuredAlbum: NaaSearchResult?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Curating for you...")
                            Spacer()
                        }
                        .padding(.top, 100)
                    } else if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        // Featured Section
                        if let featured = featuredAlbum {
                            VStack(alignment: .leading) {
                                Text("FEATURED")
                                    .font(.caption2.bold())
                                    .foregroundColor(.secondary)
                                
                                NavigationLink(destination: NaaAlbumDetailView(albumResult: featured)) {
                                    FeaturedCard(album: featured)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Recently Played Section
                        if !LibraryStore.shared.recentlyPlayedAlbums.isEmpty {
                            AlbumRowSection(title: "Recently Played", albums: LibraryStore.shared.recentlyPlayedAlbums)
                        }
                        
                        // Horizontal Section: Latest Releases
                        AlbumRowSection(title: "New Releases", albums: latestAlbums)
                        
                        // Horizontal Section: Trending
                        AlbumRowSection(title: "Trending Now", albums: trendingAlbums)
                        
                        // Just an extra spacer
                        Spacer(minLength: 100)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Listen Now")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundColor(.pink)
                }
            }
        }
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        guard latestAlbums.isEmpty else { return }
        isLoading = true
        
        Task {
            do {
                let allItems = try await NaaSongsService.shared.fetchHomeContent()
                await MainActor.run {
                    if !allItems.isEmpty {
                        self.featuredAlbum = allItems.first
                        self.latestAlbums = Array(allItems.dropFirst().prefix(10))
                        self.trendingAlbums = Array(allItems.shuffled().prefix(10))
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load Home: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

struct AlbumRowSection: View {
    let title: String
    let albums: [NaaSearchResult]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title2.bold())
                Spacer()
                Button("See All") { 
                    // Future: Navigate to full list
                }
                .font(.subheadline)
                .foregroundColor(.pink)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(albums) { album in
                        NavigationLink(destination: NaaAlbumDetailView(albumResult: album)) {
                            AlbumCard(album: album)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct FeaturedCard: View {
    let album: NaaSearchResult
    
    var body: some View {
        VStack(alignment: .leading) {
            if let imageUrlString = album.imageUrl, let imageUrl = URL(string: imageUrlString) {
                AsyncImage(url: imageUrl) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(height: 220)
                .clipped()
                .cornerRadius(12)
            }
            
            Text(album.title)
                .font(.title3.bold())
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text("Latest Telugu Hits")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct AlbumCard: View {
    let album: NaaSearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageUrlString = album.imageUrl, let imageUrl = URL(string: imageUrlString) {
                AsyncImage(url: imageUrl) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(width: 160, height: 160)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .overlay(Image(systemName: "music.note").foregroundColor(.gray))
            }
            
            Text(album.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 160, alignment: .leading)
                .lineLimit(2)
        }
    }
}
