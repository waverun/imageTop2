struct PexelsResponse: Codable {
    let page: Int
    let perPage: Int
    let photos: [Photo]
    let totalResults: Int
    let nextPage: String

     enum CodingKeys: String, CodingKey {
        case page, photos, nextPage = "next_page", perPage = "per_page", totalResults = "total_results"
    }
}

struct Photo: Codable {
    let id: Int
    let width: Int
    let height: Int
    let url: String
    let photographer: String
    let photographerUrl: String
    let avgColor: String
    let src: Src

     enum CodingKeys: String, CodingKey {
        case id, width, height, url, photographer, avgColor = "avg_color", photographerUrl = "photographer_url", src
    }
}

struct Src: Codable {
    let original: String
    let large2x: String
    let large: String
    let medium: String
    let small: String
    let portrait: String
    let landscape: String
    let tiny: String
}
