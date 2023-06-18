struct VideoData: Codable {
    let page: Int
    let perPage: Int
    let totalResults: Int
    let url: String
    let videos: [Video]

    enum CodingKeys: String, CodingKey {
        case page, url, videos
        case perPage = "per_page"
        case totalResults = "total_results"
    }
}

struct Video: Codable {
    let id: Int
    let width: Int
    let height: Int
    let url: String
    let image: String
    let duration: Int
    let user: User
    let videoFiles: [VideoFile]
    let videoPictures: [VideoPicture]

    enum CodingKeys: String, CodingKey {
        case id, width, height, url, image, duration, user
        case videoFiles = "video_files"
        case videoPictures = "video_pictures"
    }
}

struct User: Codable {
    let id: Int
    let name: String
    let url: String
}

struct VideoFile: Codable {
    let id: Int
    let quality: String
    let fileType: String
    let width: Int?
    let height: Int?
    let link: String

    enum CodingKeys: String, CodingKey {
        case id, quality, width, height, link
        case fileType = "file_type"
    }
}

struct VideoPicture: Codable {
    let id: Int
    let picture: String
    let nr: Int
}
