import SwiftUI

struct FullAlbumListView: View {
    let title: String
    let albums: [NaaSearchResult]
    
    var body: some View {
        List {
            ForEach(albums) { album in
                NavigationLink(destination: AlbumDetailView(album: album)) {
                    HStack(spacing: 16) {
                        // Artwork Thumbnail
                        if let imageUrlString = album.imageUrl, let imageUrl = URL(string: imageUrlString) {
                            AsyncImage(url: imageUrl) { phase in
                                if let image = phase.image {
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else if phase.error != nil {
                                    Color.gray.opacity(0.1)
                                        .overlay(Image(systemName: "music.note").foregroundColor(.gray))
                                } else {
                                    Rectangle().fill(Color.gray.opacity(0.1))
                                }
                            }
                            .frame(width: 58, height: 58)
                            .cornerRadius(6)
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 58, height: 58)
                                .cornerRadius(6)
                                .overlay(Image(systemName: "music.note").foregroundColor(.gray))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(album.title)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Text("Telugu Album")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}
