import SwiftUI

struct TransitionsView: View {
    var transitions: [AutomatonTransition]
    let transitionSymbolRemoved: ((AutomatonTransition.ID, String) -> Void)
    let transitionSymbolChanged: ((AutomatonTransition.ID, String) -> Void)
    let transitionSymbolAdded: ((AutomatonTransition.ID) -> Void)
    let transitionDragged: ((AutomatonTransition.ID, CGPoint) -> Void)
    let transitionFinishedDragging: ((AutomatonTransition.ID, CGPoint) -> Void)
    
    @State private var counter = 0
    
    var body: some View {
        ForEach(transitions) { transition in
            VStack(alignment: .center) {
                FlexibleView(
                    data: transition.symbols,
                    spacing: 3,
                    alignment: .leading,
                    content: { symbol in
                        Button(
                            action: { transitionSymbolRemoved(transition.id, symbol) }
                        ) {
                            HStack {
                                Text(symbol)
                                    .foregroundColor(Color.black)
                                Image(systemName: "xmark")
                                    .foregroundColor(Color.black)
                            }
                            .padding(.all, 5)
                            .background(Color.white)
                            .cornerRadius(10)
                        }
                    }
                )
                .frame(width: 200)
                HStack {
                    TextView(
                        text: Binding(
                            get: { transition.currentSymbol },
                            set: { transitionSymbolChanged(transition.id, $0) }
                        )
                    )
                    .border(Color.white, width: 2)
                    .frame(width: 50, height: 30)
                    Button(
                        action: { transitionSymbolAdded(transition.id) }
                    ) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .position(transition.scribblePosition)
            if let currentFlexPoint = transition.currentFlexPoint,
               let flexPoint = transition.flexPoint {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 30)
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .frame(width: 25)
                }
                .position(currentFlexPoint)
                .offset(x: flexPoint.x - currentFlexPoint.x, y: flexPoint.y - currentFlexPoint.y)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            counter += 1
                            guard counter % 3 == 1 else { return }
                            transitionDragged(
                                transition.id,
                                CGPoint(
                                    x: currentFlexPoint.x + value.translation.width,
                                    y: currentFlexPoint.y + value.translation.height
                                )
                            )
                        }
                        .onEnded { value in
                            transitionFinishedDragging(
                                transition.id,
                                CGPoint(
                                    x: currentFlexPoint.x + value.translation.width,
                                    y: currentFlexPoint.y + value.translation.height
                                )
                            )
                        }
                )
            }
        }
    }
}