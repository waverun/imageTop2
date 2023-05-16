import SwiftUI

struct LoadableImage: View {
    let imagePath: String
    let onError: () -> Void

    @State private var nsImage: NSImage? = nil
    @State private var imageLoadError = false

    var body: some View {
        Group {
            if let image = nsImage, !imageLoadError {
                Image(nsImage: image)
                    .resizable()
                    .clipped()
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color.clear
                    .onAppear {
                        onError()
                    }
            }
        }
        .onAppear(perform: loadImage)
    }

    private func loadImage() {
        DispatchQueue.global().async {
            if let image = NSImage(contentsOfFile: self.imagePath) {
                DispatchQueue.main.async {
                    self.nsImage = image
                }
            } else {
                DispatchQueue.main.async {
                    self.imageLoadError = true
                }
            }
        }
    }
}

//import SwiftUI
//
//struct LoadableImage: View {
//    let imagePath: String
//    let onError: () -> Void
//
//    @State private var imageLoadError = false
//
//    private func loadImage() -> NSImage? {
//        if let nsImage = NSImage(contentsOfFile: imagePath) {
//            return nsImage
//        } else {
//            imageLoadError = true
//            return nil
//        }
//    }
//
//    var body: some View {
//        Group {
//            if let nsImage = loadImage(), !imageLoadError {
//                Image(nsImage: nsImage)
//                    .resizable()
//                    .clipped()
//                    .edgesIgnoringSafeArea(.all)
//            } else {
//                Color.clear
//                    .onAppear {
//                        onError()
//                    }
//            }
//        }
//    }
//}
