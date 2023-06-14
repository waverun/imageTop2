import AVFoundation
import AppKit
import SwiftUI

struct VideoPlayerView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        // create an AVPlayer
        let player = AVPlayer(url: url)

        // create a player layer
        let playerLayer = AVPlayerLayer(player: player)

        // make the player layer the same size as the view
        playerLayer.frame = view.bounds

        // make the player layer maintain its aspect ratio, and fill the view
        playerLayer.videoGravity = .resizeAspectFill

        // add the player layer to the view's layer
        view.layer = playerLayer

        // play the video
        player.play()

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Nothing to do here
    }
}

//import AVKit
//import SwiftUI
//import AppKit
//
//struct VideoPlayerView: NSViewRepresentable {
//    let url: String
//
//    func makeNSView(context: Context) -> NSView {
//        let player = AVPlayer(url: URL(string: url)!)
//        let controller = AVPlayerView()
//        controller.player = player
//        player.play()
//        return controller
//    }
//
//    func updateNSView(_ nsView: NSView, context: Context) {
//    }
//}
