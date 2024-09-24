//
//  ImageViewer.swift
//  TrickleAnyway
//
//  Created by Chocoford on 2023/2/8.
//

import SwiftUI

public struct ImageViewer: View {
    @Environment(\.isEnabled) var isEnabled
    
    var isPresent: Binding<Bool>?
    
    var image: Binding<Image?>
    var url: URL?
    var thumbnailURL: URL?
    var imageSize: CGSize?
    
    var disabled: Bool { !isEnabled }
    var content: AnyView
    var label: AnyView
    
#if os(macOS)
//    @State private var currentWindow: NSWindow? = nil
#elseif os(iOS)
    @State private var showViewer = false
    @State var dragOffset: CGSize = CGSize.zero
    @State var dragOffsetPredicted: CGSize = CGSize.zero
    @State private var backgroundOpacity: Double = 1.0
#endif
    
    public init<Content: View, Label: View>(
        isPresent: Binding<Bool>? = nil,
        imageSize: CGSize? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        self.isPresent = isPresent
        self.image = .constant(nil)
        self.imageSize = imageSize
        self.content = AnyView(content())
        self.label = AnyView(label())
    }
    
//    public init(
//        isPresent: Binding<Bool>? = nil,
//        url: URL,
//        @ViewBuilder label: () -> Label
//    ) {
//        self.isPresent = isPresent
//        self.url = url
//        self.image = .constant(nil)
//        self.label = AnyView(label())
//    }
    

    public init<Label: View>(
        isPresent: Binding<Bool>? = nil,
        image: Image,
        imageSize: CGSize? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.init(isPresent: isPresent, imageSize: imageSize) {
            image.resizable()
        } label: {
            label()
        }
    }
    
    
    public init<Label: View>(
        image: Binding<Image?>,
        imageSize: CGSize? = nil,
        @ViewBuilder label: () -> Label
    ) {
        self.init(
            isPresent: Binding(get: {
                image.wrappedValue != nil
            }, set: { val in
                image.wrappedValue = nil
            }),
            imageSize: imageSize
        ) {
            if let image = image.wrappedValue {
                image
            }
        } label: {
            label()
        }
    }
    
    
    
    public var body: some View {
        label
            .gesture(
                TapGesture()
                    .onEnded { _ in
                        if self.isPresent != nil { return }
                        openViewer()
                    }
            )
            .onChange(of: self.image.wrappedValue) { val in
                if val != nil {
                    openViewer()
                } else {
                    closeViewer()
                }
            }
#if os(iOS)
            .fullScreenCover(isPresented: $showViewer) {
                ImageViewerView {
                    content
                }
                .dragToDismiss {
                    self.showViewer = false
                }
            }
            .onChange(of: showViewer) { show in
                if show {
                    dragOffset = .zero
                    dragOffsetPredicted = .zero
                }
            }
#elseif os(macOS)
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
                if let window = notification.object as? NSWindow,
                   window == imageViewerWindow
                   /*window == self.currentWindow*/ {
                    imageViewerWindow?.close()
                    self.isPresent?.wrappedValue = false
                    self.image.wrappedValue = nil
                }
            }
#endif
    }
}

#if os(macOS)
internal var imageViewerWindow: NSWindow? = nil
#endif

extension ImageViewer {
    func openViewer() {
#if os(macOS)
        if let window = imageViewerWindow {
            closeViewer()
        }
          
        guard let screen = NSScreen.current else { return }
        
        let window = NSWindow(
            contentRect: .init(origin: .zero, size: .zero),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: true,
            screen: screen
        )
        window.animationBehavior = .documentWindow
        imageViewerWindow = window
        
        guard let window = imageViewerWindow else { return }
        
        let view: ImageViewerView
        
        if let image = self.image.wrappedValue {
            view = ImageViewerView {
                image
            }
        } else if let url {
            view = ImageViewerView(url: url)
        } else {
            view = ImageViewerView {
                self.content
            }
        }
        
        let contentView = NSHostingView(rootView: view)
        window.contentView = contentView
        window.isReleasedWhenClosed = false // important
        window.isMovable = true
        window.backgroundColor = .black
        window.titleVisibility = .hidden
        
        if let imageSize = self.imageSize {
            window.animator().setContentSize(
                .init(width: min(imageSize.width, screen.frame.width * 0.9),
                      height: min(imageSize.height, screen.frame.height * 0.9))
            )
//        } else {
//            window.animator().setContentSize(
//                .init(width: screen.frame.width,
//                      height: screen.frame.height)
//            )
        }
        
        NSApp.activate(ignoringOtherApps: true)
        window.animator().makeKeyAndOrderFront(nil)
        window.animator().center()
        
        imageViewerWindow = window
#elseif os(iOS)
        withAnimation {
            showViewer = true
            backgroundOpacity = 1
        }
#endif
    }
    
    func closeViewer() {
#if os(macOS)
        imageViewerWindow?.close()
#elseif os(iOS)
        withAnimation {
            showViewer = false
            backgroundOpacity = 0
        }
#endif
    }
}

//extension View {
//    @ViewBuilder
//    public func imageViewer(
//        isPresent: Binding<Bool>? = nil,
//        image: Image,
//        imageSize: CGSize? = nil,
//        imageRenderer: ImageViewerView.ImageRenderer = .animatableCached
//    ) -> some View {
//        ImageViewer(
//            isPresent: isPresent,
//            image: image,
//            imageSize: imageSize,
//            imageRenderer: imageRenderer
//        ) {
//            self
//        }
//    }
//    
//    @ViewBuilder
//    public func imageViewer(
//        image: Binding<Image?>,
//        imageSize: CGSize? = nil,
//        imageRenderer: ImageViewerView.ImageRenderer = .animatableCached
//    ) -> some View {
//        ImageViewer(
//            image: image,
//            imageSize: imageSize,
//            imageRenderer: imageRenderer
//        ) {
//            self
//        }
//    }
//    
//    @ViewBuilder
//    public func imageViewer(
//        isPresent: Binding<Bool>? = nil,
//        url: URL?,
//        thumbnailURL: URL? = nil,
//        imageSize: CGSize? = nil,
//        imageRenderer: ImageViewerView.ImageRenderer = .animatableCached
//    ) -> some View {
//        ImageViewer(isPresent: isPresent, url: url, thumbnailURL: thumbnailURL, imageSize: imageSize, imageRenderer: imageRenderer) {
//            self
//        }
//    }
//}




#if os(iOS)
struct BackgroundBlurView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif

#if DEBUG
#Preview {
    ScrollView {
        LazyVStack {
            ImageViewer(imageSize: .init(width: 896, height: 1344)) {
                AsyncImage(url:  URL(string: "https://pbs.twimg.com/media/Fxl_6mmagAA4ahV?format=jpg&name=large")
                ) {
                    $0.resizable()
                } placeholder: {
                    Rectangle()
                }
            } label: {
                AsyncImage(url: URL(string: "https://pbs.twimg.com/media/Fxl_6mmagAA4ahV?format=jpg&name=large")) {
                    $0
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                }
                .frame(width: 200, height: 200)
            }
            
            ImageViewer(imageSize: .init(width: 896, height: 1344))  {
                AsyncImage(url:  URL(string: "https://pbs.twimg.com/media/F8Q7Z1aW0AAXGHc?format=jpg&name=medium")
                )
            } label: {
                AsyncImage(url: URL(string: "https://pbs.twimg.com/media/F8Q7Z1aW0AAXGHc?format=jpg&name=small")) {
                    $0
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                }
                .frame(width: 200, height: 200)
            }
            
        }
    }
}
#endif
