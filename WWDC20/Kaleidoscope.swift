import SwiftUI
import PlaygroundSupport
import UIKit

enum PickedColor: CaseIterable {
    // Selected pallete of pastel colors my mom liked
    case wildWillow, riptide, chardonnay, coral, flamePea
    
    // For SwiftUI
    var color: Color {
        return Color(uiColor)
    }
    
    // For UIKit
    var uiColor: UIColor {
        switch self {
        case .wildWillow:
            return UIColor(red: 0.67, green: 0.79, blue: 0.40, alpha: 1.00)
        case .riptide:
            return UIColor(red: 0.53, green: 0.83, blue: 0.79, alpha: 1.00)
        case .chardonnay:
            return UIColor(red: 0.97, green: 0.76, blue: 0.45, alpha: 1.00)
        case .coral:
            return UIColor(red: 1.00, green: 0.51, blue: 0.34, alpha: 1.00)
        case .flamePea:
            return UIColor(red: 0.88, green: 0.36, blue: 0.27, alpha: 1.00)
        }
    }
}

// Saving to Photo Album (borrowed from hackingwithswift.com)
class ImageSaver: NSObject {
    func writeToPhotoAlbum(image: UIImage?) {
        guard let image = image else { return }
        UIImageWriteToSavedPhotosAlbum(image, self, nil, nil)
    }
}

struct DrawingControlsView: View {
    @Binding var drawingImage: UIImage?
    @Binding var segments: Double
    @Binding var segmentsShown: Bool
    @Binding var lineWidth: CGFloat
    @Binding var pickedColor: PickedColor
    
    // Size of touchable user control
    let diameter: CGFloat = 32
    
    var body: some View {
        HStack {
            // Clear button
            VStack {
                Button(action: {
                    self.drawingImage = nil
                }) {
                    Image(systemName: "xmark.rectangle")
                        .font(.system(size: diameter))
                        .frame(width: diameter)
                }
                .disabled(self.drawingImage == nil)
                Text("clear")
            }
            
            Spacer()
            
            // Line width slider
            VStack {
                Slider(value: $lineWidth, in: 4...16, step: 2)
                    .frame(width: diameter * 3)
                Text("pen size \(Int(lineWidth))")
            }
            
            Spacer()
            
            // Color picker
            VStack {
                HStack {
                    ForEach(PickedColor.allCases, id: \.self) { pickableColor in
                        ZStack {
                            Circle()
                                .foregroundColor(pickableColor.color)
                                .frame(width: self.diameter, height: self.diameter)
                                .onTapGesture {
                                    self.pickedColor = pickableColor
                            }
                            Circle()
                                .foregroundColor(.white)
                                .frame(width: self.pickedColor == pickableColor ? self.diameter * 0.25 : 0)
                        }
                    }
                }
                Text("pen color")
            }
            
            Spacer()
            
            // Number of segments slider
            VStack {
                Slider(value: $segments, in: 2...36, step: 2, onEditingChanged: { _ in
                    // Fade in and out when changing number of segments
                    withAnimation(.easeOut(duration: 0.5)) {
                        self.segmentsShown.toggle()
                    }
                })
                    .frame(width: diameter * 3)
                Text("\(Int(segments)) segments")
            }
            
            Spacer()
            
            // Save to photo gallery button
            VStack {
                Button(action: {
                    ImageSaver().writeToPhotoAlbum(image: self.drawingImage)
                }) {
                    Image(systemName: "photo")
                        .font(.system(size: diameter))
                        .frame(width: diameter)
                }
                .disabled(self.drawingImage == nil)
                Text("save")
            }
            
        }
        .frame(height: diameter * 1.5)
        .padding()
    }
}

class DrawingCanvasControl: UIControl {
    // Apple Pencil pressure sensitivity
    private let forceSensitivity: CGFloat = 4
    
    var drawingImage: UIImage? {
        didSet {
            // When clearing canvas
            if drawingImage == nil {
                drawingImage = UIGraphicsImageRenderer(size: bounds.size).image { context in
                    // Fill background
                    canvasColor.setFill()
                    context.fill(bounds)
                }
            }
            // Otherwise, redraw
            setNeedsDisplay()
        }
    }
    
    var segments: Double = 8
    var penSize: CGFloat = 4
    var canvasColor: UIColor = UIColor.systemBackground
    var drawingColor: UIColor = .black
    
    init(drawingImage: UIImage?, segments: Double, penSize: CGFloat, canvasColor: UIColor, pickedColor: UIColor) {
        self.segments = segments
        self.penSize = penSize
        self.canvasColor = canvasColor
        self.drawingColor = pickedColor
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        drawingImage?.draw(in: rect)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        sendActions(for: .valueChanged)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        drawingImage = UIGraphicsImageRenderer(size: bounds.size).image { context in
            // Fill background
            canvasColor.setFill()
            context.fill(bounds)
            // Draw previous image
            drawingImage?.draw(in: bounds)
            // If Apple Pencil used, draw all coalesced touches
            if let touches = event?.coalescedTouches(for: touch) {
                for touch in touches {
                    // Draw lines between touches
                    drawStroke(context: context.cgContext, touch: touch)
                }
            }
            else {
                // Draw lines between touches
                drawStroke(context: context.cgContext, touch: touch)
            }
        }
    }
    
    // Transform x and y coordinates (Descartes) to distance and angle (Polar)
    private func distanceAndAngle(from pt1: CGPoint, to pt2: CGPoint) -> (distance: CGFloat, angle: Angle) {
        let x = pt2.x - pt1.x
        let y = pt2.y - pt1.y
        let distance = sqrt(x * x + y * y)
        let angle = Angle(radians: Double(atan2(x, y)))
        
        return (distance, angle)
    }
    
    // Transform distance and angle (Polar) to x and y coordinates (Descartes)
    private func point(from center: CGPoint, distance: CGFloat, angle: Double) -> CGPoint {
        let x = center.x + distance * CGFloat(cos(angle))
        let y = center.y - distance * CGFloat(sin(angle))
        return CGPoint(x: x, y: y)
    }
    
    private func drawStroke(context: CGContext, touch: UITouch) {
        let pt1 = touch.previousLocation(in: self)
        let pt2 = touch.location(in: self)
        
        let segmentAngle: Angle = .degrees(360 / Double(segments))
        
        let (distance1, angle1) = distanceAndAngle(from: center, to: pt1)
        let (distance2, angle2) = distanceAndAngle(from: center, to: pt2)
        
        var penSize = self.penSize
        if touch.force > 0 {
            penSize = touch.force * forceSensitivity
        }
        
        context.setLineWidth(penSize)
        context.setLineCap(.round)
        
        for i in 0..<Int(segments) {
            let a0 = segmentAngle.radians * Double(i) - .pi / 2
            
            // Points in odd segments are rotated and mirrored (segmentAngle - angle), even segments are just rotated (angle)
            let isReflected = i % 2 == 1
            
            let a1 = a0 + (isReflected ? segmentAngle.radians - angle1.radians : angle1.radians)
            let pt1 = point(from: center, distance: distance1, angle: a1)
            context.move(to: pt1)
            
            let a2 = a0 + (isReflected ? segmentAngle.radians - angle2.radians : angle2.radians)
            let pt2 = point(from: center, distance: distance2, angle: a2)
            context.addLine(to: pt2)
        }
        
        drawingColor.setStroke()
        context.strokePath()
    }
}

struct DrawingCanvasControlRepresentation: UIViewRepresentable {
    @Binding var drawingImage: UIImage?
    
    let segments: Double
    let penSize: CGFloat
    let canvasColor: UIColor
    let pickedColor: PickedColor
    
    // This one was tough, I would never guessed it myself, if there wasn't Ray Wenderlich "Drawing in iOS with SwiftUI" tutorial
    class Coordinator: NSObject {
        @Binding var drawingImage: UIImage?
        
        init(drawingImage: Binding<UIImage?>) {
            _drawingImage = drawingImage
        }
        
        @objc func drawingImageChanged(_ sender: DrawingCanvasControl) {
            self.drawingImage = sender.drawingImage
        }
    }
    
    func makeCoordinator() -> DrawingCanvasControlRepresentation.Coordinator {
        Coordinator(drawingImage: $drawingImage)
    }
    
    func makeUIView(context: Context) -> DrawingCanvasControl {
        let view = DrawingCanvasControl(
            drawingImage: drawingImage, 
            segments: segments, 
            penSize: penSize, 
            canvasColor: canvasColor, 
            pickedColor: pickedColor.uiColor
        )
        view.addTarget(context.coordinator, action: #selector(Coordinator.drawingImageChanged(_:)), for: .valueChanged)
        return view
    }
    
    func updateUIView(_ uiView: DrawingCanvasControl, context: Context) {
        uiView.drawingImage = drawingImage
        uiView.segments = segments
        uiView.penSize = penSize
        uiView.canvasColor = canvasColor
        uiView.drawingColor = pickedColor.uiColor
    }
}

struct MirrorsView: View {
    @Binding var segments: Double
    let lineWidth: CGFloat
    let lineColor: UIColor
    let size: CGSize
    
    var length: CGFloat {
        min(size.width, size.height) / 2
    }
    
    var center: CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }
    
    var body: some View {
        return Path { path in
            guard segments > 1 else { return }
            let segmentAngle: Angle = .degrees(360 / Double(segments))
            for i in 0..<Int(segments) {
                let a = segmentAngle.radians * Double(i) - .pi / 2
                let x = center.x + length * CGFloat(cos(a))
                let y = center.y + length * CGFloat(sin(a))
                let pt2 = CGPoint(x: x, y: y)
                path.move(to: center)
                path.addLine(to: pt2)
            }
        }
        .stroke(Color(lineColor), lineWidth: lineWidth)
    }
}

struct KaleidoscopeView: View {
    private let canvasColor = UIColor.systemBackground
    private let borderColor = UIColor.systemGray.withAlphaComponent(0.2)
    private let borderWidth: CGFloat = 4
    
    @State var pickedColor: PickedColor
    @State var penSize: CGFloat
    @State var segments: Double
    @State var segmentsShown: Bool
    @State var drawingImage: UIImage?
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(Color(canvasColor))
                
                DrawingCanvasControlRepresentation(
                    drawingImage: $drawingImage,
                    segments: segments,
                    penSize: penSize,
                    canvasColor: canvasColor,
                    pickedColor: pickedColor
                )
                    .clipShape(Circle())
                    .overlay(Circle()
                        .inset(by: -borderWidth / 2)
                        .stroke(Color(borderColor), lineWidth: borderWidth)
                )
                
                GeometryReader { geometry in
                    MirrorsView(
                        segments: self.$segments,
                        lineWidth: self.borderWidth, 
                        lineColor: self.borderColor,
                        size: geometry.size
                    )
                        .opacity(self.segmentsShown ? 1 : 0)
                        .onAppear {
                            // Fade out initially after short delay
                            withAnimation(Animation.easeOut(duration: 0.5).delay(3)) {
                                self.segmentsShown.toggle()
                            }
                    }
                }
            }
            .padding()
            
            DrawingControlsView(
                drawingImage: $drawingImage, 
                segments: $segments, 
                segmentsShown: $segmentsShown, 
                lineWidth: $penSize, 
                pickedColor: $pickedColor
            )
        }
    }
}

struct ContentView: View {
    var body: some View {
        KaleidoscopeView(
            pickedColor: PickedColor.wildWillow, 
            penSize: 4, 
            segments: 8, 
            segmentsShown: true
        )
    }
}

PlaygroundPage.current.setLiveView(
    ContentView()
)
