struct VideoData: Codable {
    let page: Int
    let perPage: Int
    let totalResults: Int?
    let url: String?
    let videos: [Video]

    enum CodingKeys: String, CodingKey {
        case page, url, videos
        case perPage = "per_page"
        case totalResults = "total_results"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 0
        perPage = try container.decodeIfPresent(Int.self, forKey: .perPage) ?? 0
        totalResults = try container.decodeIfPresent(Int.self, forKey: .totalResults)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        videos = try container.decodeIfPresent([Video].self, forKey: .videos) ?? []
    }
}

struct Video: Codable {
    let id: Int
    let width: Int?
    let height: Int?
    let url: String?
    let image: String?
    let duration: Int
    let user: User
    let videoFiles: [VideoFile]
    let videoPictures: [VideoPicture]

    enum CodingKeys: String, CodingKey {
        case id, width, height, url, image, duration, user
        case videoFiles = "video_files"
        case videoPictures = "video_pictures"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        width = try container.decodeIfPresent(Int.self, forKey: .width)
        height = try container.decodeIfPresent(Int.self, forKey: .height)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        image = try container.decodeIfPresent(String.self, forKey: .image)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration) ?? 0
        user = try container.decodeIfPresent(User.self, forKey: .user) ?? User(id: 0, name: "", url: "")
        videoFiles = try container.decodeIfPresent([VideoFile].self, forKey: .videoFiles) ?? []
        videoPictures = try container.decodeIfPresent([VideoPicture].self, forKey: .videoPictures) ?? []
    }
}

struct User: Codable {
    let id: Int
    let name: String
    let url: String
}

struct VideoFile: Codable {
    let id: Int?
    let quality: String?
    let fileType: String?
    let width: Int?
    let height: Int?
    let link: String

    enum CodingKeys: String, CodingKey {
        case id, quality, width, height, link
        case fileType = "file_type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        quality = try container.decodeIfPresent(String.self, forKey: .quality)
        fileType = try container.decodeIfPresent(String.self, forKey: .fileType)
        width = try container.decodeIfPresent(Int.self, forKey: .width)
        height = try container.decodeIfPresent(Int.self, forKey: .height)
        link = try container.decodeIfPresent(String.self, forKey: .link) ?? ""
    }
}

struct VideoPicture: Codable {
    let id: Int?
    let picture: String?
    let nr: Int?
}
