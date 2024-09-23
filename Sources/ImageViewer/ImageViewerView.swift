//
//  SwiftUIView.swift
//  
//
//  Created by Dove Zachary on 2023/6/4.
//

import SwiftUI
struct ImageSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

public struct ImageViewerView: View {
    private let id = UUID()
    
    let image: AnyView
    var isScaling: Binding<Bool>?
    @State private var isLoading = false

    public init(
        url: URL?,
        isScaling: Binding<Bool>? = nil
    ) {
        self.image = AnyView(
            AsyncImage(url: url) { phase in
                switch phase {
                    case .empty:
                        Color.clear
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure(let error):
                        Color.clear
                            .overlay {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(.red)
                            }
                    @unknown default:
                        Color.clear
                            .overlay {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(.red)
                            }
                }
            }
        )
        self.isScaling = isScaling
    }
    
    public init<I: View>(
        isScaling: Binding<Bool>? = nil,
        @ViewBuilder image: () -> I
    ) {
        self.image = AnyView(image())
        self.isScaling = isScaling
    }
    
    @State private var imageSize: CGSize = .zero
#if os(macOS)
    @State private var window: NSWindow? = nil
#endif
    
    @Namespace var ns
    
    private var config = Config()
    
    public var body: some View {
        ZStack {
            if config.disabled {
                image
                    .aspectRatio(contentMode: config.contentModeWhenDisabled)
            } else {
                GeometryReader { geometry in
                    image
                        .scaledToFit()
                        .opacity(1e-9)
                        .preference(key: ImageSizeKey.self, value: geometry.size)
                        .onAppear {
                            self.imageSize = geometry.size
                        }
                        .onChange(of: geometry.size) { newValue in
                            self.imageSize = newValue
                        }
                }
                
                ZoomableScrollView(size: imageSize) {
                    imageView(imageView: image)
#if os(macOS)
                        .offset(x: imageSize.width / 2, y: -1 * imageSize.height / 2)
#endif
                }
                .scalingState(config.isScaling)
                .zoomScale(config.zoomScale)
                .disabled(config.ignoreInteraction)
            }
        }
        .ignoresSafeArea()
        .onPreferenceChange(ImageSizeKey.self) {
            self.imageSize = $0
        }
        .overlay {
            ProgressView()
                .opacity(isLoading ? 1 : 0)
        }
    }
    
    @ViewBuilder
    private func imageView(imageView: AnyView) -> some View {
        imageView
            .scaledToFit()
            .frame(width: imageSize == .zero ? nil : imageSize.width,
                   height: imageSize == .zero ? nil : imageSize.height)
    }
}


extension ImageViewerView {
    class Config {
        var disabled: Bool = false
        var contentModeWhenDisabled = ContentMode.fill
        var ignoreInteraction: Bool = false
        var isScaling: Binding<Bool>?
        var zoomScale: Binding<CGFloat>?
    }
    
    public func disabled(_ flag: Bool = true) -> ImageViewerView {
        self.config.disabled = flag
        return self
    }
    
    public func aspectRatioWhenDisabled(contentMode: ContentMode) -> ImageViewerView {
        self.config.contentModeWhenDisabled = contentMode
        return self
    }
    
    public func scalingState(_ isScaling: Binding<Bool>?) -> ImageViewerView {
        config.isScaling = isScaling
        return self
    }
    
    public func zoomScale(_ zoomScale: Binding<CGFloat>?) -> ImageViewerView {
        config.zoomScale = zoomScale
        return self
    }
    
    public func ignoreInteraction(_ flag: Bool = true) -> ImageViewerView {
        config.ignoreInteraction = flag
        return self
    }
}

#if DEBUG
struct ImageViewerView_Previews: PreviewProvider {
    static var previews: some View {
        ImageViewerView(url: URL(string: "https://pbs.twimg.com/media/Fxl_6mmagAA4ahV?format=jpg&name=large"), isScaling: nil)
    }
}
#endif
