import SwiftUI

struct LoadableImage: View { 
    let imagePath: String
    let onError: () -> Void

    @State private var imageLoadError = false

    private func loadImage() -> NSImage? {
        if let nsImage = NSImage(contentsOfFile: imagePath) {
            return nsImage
        } else {
            imageLoadError = true
            return nil
        }
    }

    var body: some View {
        Group {
            if let nsImage = loadImage(), !imageLoadError {
                Image(nsImage: nsImage)
                    .resizable()
//                    .aspectRatio(contentMode: .fill)
//                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .clipped()
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color.clear
                    .onAppear {
                        onError()
                    }
            }
        }
    }
}
