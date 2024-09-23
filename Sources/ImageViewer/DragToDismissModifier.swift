//
//  SwiftUIView.swift
//  
//
//  Created by Dove Zachary on 2024/4/8.
//

import SwiftUI

public struct DragToDismissModifier: ViewModifier {
    var dismissProgress: Binding<Double>?
    var minimumDistance: CGFloat
    var dismissImmediately: Bool
    var directions: [UnitPoint]
    var dismissThreshold: Double = 360
    var disabled: Bool
    var onDismiss: () -> Void
    var onCancel: () -> Void
    
    public init(
        dismissProgress: Binding<Double>? = nil,
        minimumDistance: CGFloat = 10,
        dismissImmediately: Bool,
        directions: [UnitPoint] = [.bottom],
        dismissThreshold: Double = 360,
        disabled: Bool = false,
        onDismiss: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.dismissProgress = dismissProgress
        self.minimumDistance = minimumDistance
        self.dismissImmediately = dismissImmediately
        self.directions = directions
        self.dismissThreshold = dismissThreshold
        self.disabled = disabled
        self.onDismiss = onDismiss
        self.onCancel = onCancel
    }
    
    @State private var shouldHandleDrag: Bool?
    @State private var dragOffset: CGSize = CGSize.zero
    @State private var dragOffsetPredicted: CGSize = CGSize.zero
    @State private var backgroundOpacity: Double = 1.0
    
    public func body(content: Content) -> some View {
        Color.clear
            .ignoresSafeArea()
            .overlay {
                content
                    .offset(x: self.dragOffset.width, y: self.dragOffset.height)
                    .simultaneousGesture(
                        disabled ? nil : DragGesture(minimumDistance: minimumDistance)
                            .onChanged { value in
                                if shouldHandleDrag == nil {
                                    let dragDirection = calculateDirection(translation: value.translation)
                                    if directions.contains(dragDirection) {
                                        shouldHandleDrag = true
                                    } else {
                                        shouldHandleDrag = false
                                    }
                                }
                                
                                guard shouldHandleDrag == true else { return }
                                self.dragOffset = value.translation
                                self.dragOffsetPredicted = value.predictedEndTranslation
                                backgroundOpacity = 1 - Double((abs(self.dragOffset.height) + abs(self.dragOffset.width)) / dismissThreshold)
                                self.dismissProgress?.wrappedValue = 1 - backgroundOpacity
                            }
                            .onEnded { value in
                                defer {
                                    shouldHandleDrag = nil
                                }
                                if shouldHandleDrag == false { return }
//                                print(
//                                    "dragOffset: \(dragOffset)",
//                                    "dragOffsetPredicted: \(dragOffsetPredicted)",
//                                    "dismissThreshold: \(dismissThreshold)",
//                                    separator: "\n"
//                                )
                                if (abs(self.dragOffset.height) + abs(self.dragOffset.width) > dismissThreshold) ||
                                    ((abs(self.dragOffsetPredicted.height)) / (abs(self.dragOffset.height)) > 3) ||
                                    ((abs(self.dragOffsetPredicted.width)) / (abs(self.dragOffset.width))) > 3 {
                                    if dismissImmediately {
                                        self.backgroundOpacity = 0
                                        self.dismissProgress?.wrappedValue = 1
                                        self.onDismiss()
                                    } else if #available(iOS 17.0, *) {
                                        withAnimation(.smooth(duration: 0.5)) {
                                            self.dragOffset = self.dragOffsetPredicted
                                            self.backgroundOpacity = 0
                                            self.dismissProgress?.wrappedValue = 1 - backgroundOpacity
                                        } completion: {
                                            self.onDismiss()
                                        }
                                    } else {
                                        withAnimation(.smooth(duration: 0.5)) {
                                            self.dragOffset = self.dragOffsetPredicted
                                            self.backgroundOpacity = 0
                                            self.dismissProgress?.wrappedValue = 1 - backgroundOpacity
                                        }
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .milliseconds(500))) {
                                            self.onDismiss()
                                        }
                                    }
                                        
                                    return
                                }
                                withAnimation(.smooth) {
                                    self.dragOffset = .zero
                                    self.backgroundOpacity = 1
                                    self.dismissProgress?.wrappedValue = 0
                                    self.onCancel()
                                }
                                dragOffsetPredicted = .zero
                            }
                    )
            }
            .opacity(backgroundOpacity)
            .onAppear {
                withAnimation(.none) {
                    self.dragOffset = .zero
                    self.backgroundOpacity = 1
                    if self.dismissProgress?.wrappedValue != 0 {
                        self.dismissProgress?.wrappedValue = 0
                    }
                }
            }
    }
    
    
    private func calculateDirection(translation: CGSize) -> UnitPoint {
        let width = translation.width
        let height = translation.height
        
        // 确定水平位置
        let horizontalPosition: String = {
            if abs(width) < minimumDistance { return "center" }
            else if width > 0 { return "trailing" }
            else { return "leading" }
        }()
        
        // 确定垂直位置
        let verticalPosition: String = {
            if abs(height) < minimumDistance { return "center" }
            else if height < 0 { return "top" }
            else { return "bottom" }
        }()
        
        // 组合水平和垂直位置
        switch (horizontalPosition, verticalPosition) {
            case ("center", "center"):
                return .center
            case ("trailing", "top"):
                return .topTrailing
            case ("leading", "bottom"):
                return .bottomLeading
            case ("leading", "center"):
                // 宽度小于高度，偏向左侧
                return .leading
            case ("trailing", "center"):
                // 宽度大于高度，偏向右侧
                return .trailing
            case ("center", "top"):
                // 高度大于宽度，偏向顶部
                return .top
            case ("center", "bottom"):
                // 宽度大于高度，偏向底部
                return .bottom
            case ("leading", "top"):
                // 宽度和高度都较小，偏向左上角
                return .topLeading
            case ("trailing", "bottom"):
                // 宽度和高度都较大，偏向右下角
                return .bottomTrailing
            default:
                return .zero
        }
    }
}

extension View {
    @MainActor @ViewBuilder
    public func dragToDismiss(
        dismissProgress: Binding<Double>? = nil,
        minimumDistance: CGFloat = 10,
        dismissThreshold: Double = 360,
        dismissImmediately: Bool = true,
        directions: UnitPoint...,
        disabled: Bool = false,
        onDismiss: @escaping () -> Void,
        onCancel: @escaping () -> Void = { }
    ) -> some View {
        modifier(
            DragToDismissModifier(
                dismissProgress: dismissProgress,
                minimumDistance: minimumDistance,
                dismissImmediately: dismissImmediately,
                directions: directions,
                dismissThreshold: dismissThreshold,
                disabled: disabled,
                onDismiss: onDismiss,
                onCancel: onCancel
            )
        )
    }
    
}
