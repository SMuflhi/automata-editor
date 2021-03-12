import SwiftUI
import PencilKit

struct CanvasView: UIViewRepresentable {
    @Binding var shouldDeleteLastStroke: Bool
    @Binding var strokes: [Stroke]
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.drawingGestureRecognizer.delegate = context.coordinator
        canvasView.drawingPolicy = .default
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 15)
        return canvasView
    }
    
    func makeCoordinator() -> CanvasCoordinator {
        CanvasCoordinator(self)
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        canvasView.drawing.strokes = strokes.map { $0.pkStroke() }
        if shouldDeleteLastStroke {
            if !canvasView.drawing.strokes.isEmpty {
                canvasView.drawing.strokes.removeLast()
            }
            shouldDeleteLastStroke = false
        }
    }
}

// MARK: - Coordinator

final class CanvasCoordinator: NSObject {
    private let parent: CanvasView
    fileprivate var shouldUpdateStrokes = false
    
    init(_ parent: CanvasView) {
        self.parent = parent
    }
}

extension CanvasCoordinator: PKCanvasViewDelegate {    
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard shouldUpdateStrokes else { return }
        shouldUpdateStrokes = false
        parent.strokes = canvasView.drawing.strokes.map(Stroke.init)
    }
}

extension CanvasCoordinator: UIGestureRecognizerDelegate {
    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        shouldUpdateStrokes = true
    }
}
