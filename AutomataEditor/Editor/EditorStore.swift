import ComposableArchitecture
import CoreGraphics
import PencilKit
import CoreML
import SwiftAutomataLibrary
import SwiftUI

typealias EditorStore = Store<EditorState, EditorAction>
typealias EditorViewStore = ViewStore<EditorState, EditorAction>

struct EditorEnvironment {
    let automataClassifierService: AutomataClassifierService
    let automataLibraryService: AutomataLibraryService
    let mainQueue: AnySchedulerOf<DispatchQueue>
}

struct EditorState: Equatable {
    var tool: Tool = .pen
    var eraserImage: Image = Image(systemName: "minus.square")
    var penImage: Image = Image(systemName: "pencil.circle.fill")
    var outputString: String = ""
    var input: String = ""
    var currentAlphabetSymbol: String = ""
    var alphabetSymbols: [String] = []
    fileprivate var automatonStatesDict: [AutomatonState.ID: AutomatonState] = [:]
    var automatonStates: [AutomatonState] {
        automatonStatesDict.map(\.value)
    }
    var transitions: [AutomatonTransition] {
        transitionsDict.map(\.value)
    }
    fileprivate var transitionsDict: [AutomatonTransition.ID: AutomatonTransition] = [:]
    var strokes: [Stroke] {
        automatonStates.map(\.stroke) + automatonStates.compactMap(\.endStroke) + transitions.map(\.stroke)
    }
    var scribblePositions: [CGPoint] {
        automatonStates.map(\.scribblePosition) + transitions.map(\.scribblePosition)
    }
    var shouldDeleteLastStroke = false
    
    fileprivate var transitionsWithoutEndState: [AutomatonTransition] {
        transitions.filter { $0.endState == nil }
    }
    
    fileprivate var transitionsWithoutStartState: [AutomatonTransition] {
        transitions.filter { $0.startState == nil }
    }
    
    fileprivate var initialStates: [AutomatonState] {
        transitionsWithoutStartState
            .compactMap(\.endState)
            .compactMap { stateID in
                automatonStates.first(where: { $0.id == stateID })
            }
    }
    
    fileprivate var finalStates: [AutomatonState] {
        automatonStates.filter { $0.endStroke != nil }
    }
}

struct Empty: Equatable {}

enum EditorAction: Equatable {
    case clear
    case selectedEraser
    case selectedPen
    case currentAlphabetSymbolChanged(String)
    case addedCurrentAlphabetSymbol
    case removedAlphabetSymbol(String)
    case inputChanged(String)
    case simulateInput(String)
    case simulateInputResult(Result<Empty, AutomataLibraryError>)
    case stateSymbolChanged(AutomatonState.ID, String)
    case stateDragPointFinishedDragging(AutomatonState.ID, CGPoint)
    case stateDragPointChanged(AutomatonState.ID, CGPoint)
    case transitionFlexPointFinishedDragging(AutomatonTransition.ID, CGPoint)
    case transitionFlexPointChanged(AutomatonTransition.ID, CGPoint)
    case transitionSymbolChanged(AutomatonTransition.ID, String)
    case transitionSymbolAdded(AutomatonTransition.ID)
    case transitionSymbolRemoved(AutomatonTransition.ID, String)
    case strokesChanged([Stroke])
    case shouldDeleteLastStrokeChanged(Bool)
    case automataShapeClassified(Result<AutomatonShape, AutomataClassifierError>)
}

let editorReducer = Reducer<EditorState, EditorAction, EditorEnvironment> { state, action, env in
    struct ClosestStateResult {
        let state: AutomatonState
        let point: CGPoint
        let distance: CGFloat
    }
    func closestState(from point: CGPoint) -> ClosestStateResult? {
        let result: (AutomatonState?, CGPoint, CGFloat) = state.automatonStates.reduce((nil, .zero, CGFloat.infinity)) { acc, currentState in
            let closestPoint = currentState.stroke.controlPoints.closestPoint(from: point)
            let currentDistance = closestPoint.distance(from: point)
            return currentDistance < acc.2 ? (currentState, closestPoint, currentDistance) : acc
        }
        
        if let state = result.0 {
            return ClosestStateResult(
                state: state,
                point: result.1,
                distance: result.2
            )
        } else {
            return nil
        }
    }
    
    
    /// - Returns: State that encapsulates `controlPoints`
    func enclosingState(for controlPoints: [CGPoint]) -> AutomatonState? {
        guard
            let minX = controlPoints.min(by: { $0.x < $1.x })?.x,
            let maxX = controlPoints.max(by: { $0.x < $1.x })?.x,
            let minY = controlPoints.min(by: { $0.y < $1.y })?.y,
            let maxY = controlPoints.max(by: { $0.y < $1.y })?.y
        else { return nil }
        return state.automatonStates.first(
            where: {
                CGRect(
                    x: minX,
                    y: minY,
                    width: maxX - minX,
                    height: maxY - minY
                )
                .contains($0.stroke.controlPoints.center())
            }
        )
    }
    
    func closestTransitionWithoutEndState(
        for controlPoints: [CGPoint]
    ) -> AutomatonTransition? {
        state.transitionsWithoutEndState.first(
            where: {
                switch $0.type {
                case .cycle:
                    return false
                case let .regular(
                    startPoint: _,
                    tipPoint: tipPoint,
                    flexPoint: _
                ):
                    return sqrt(controlPoints.closestPoint(from: tipPoint).distance(from: tipPoint)) < 40
                }
            }
        )
    }
    
    func closestTransitionWithoutStartState(
        for controlPoints: [CGPoint]
    ) -> AutomatonTransition? {
        state.transitionsWithoutStartState
            .first(
                where: {
                    switch $0.type {
                    case .cycle:
                        return false
                    case let .regular(
                        startPoint: startPoint,
                        tipPoint: _,
                        flexPoint: _
                    ):
                        return sqrt(controlPoints.closestPoint(from: startPoint).distance(from: startPoint)) < 40
                    }
                }
            )
    }
    
    switch action {
    case .selectedEraser:
        state.tool = .eraser
        state.eraserImage = Image(systemName: "minus.square.fill")
        state.penImage = Image(systemName: "pencil.circle")
    case .selectedPen:
        state.tool = .pen
        state.eraserImage = Image(systemName: "minus.square")
        state.penImage = Image(systemName: "pencil.circle.fill")
    case let .currentAlphabetSymbolChanged(symbol):
        state.currentAlphabetSymbol = symbol
    case let .removedAlphabetSymbol(symbol):
        state.alphabetSymbols.removeAll(where: { $0 == symbol })
    case .addedCurrentAlphabetSymbol:
        state.alphabetSymbols.append(state.currentAlphabetSymbol)
        state.currentAlphabetSymbol = ""
    case .clear:
        state.automatonStatesDict = [:]
        state.transitionsDict = [:]
    case let .inputChanged(input):
        state.input = input
    case let .simulateInput(input):
        // TODO: Handle no or multiple initial states
        guard let initialStates = state.initialStates.first else { return .none }
        return env.automataLibraryService.simulateInput(
            input,
            state.automatonStates,
            initialStates,
            state.finalStates,
            state.alphabetSymbols,
            state.transitions
        )
        .receive(on: env.mainQueue)
        .map { Empty() }
        .catchToEffect()
        .map(EditorAction.simulateInputResult)
        .eraseToEffect()
    case .simulateInputResult(.success):
        state.outputString = "✅"
    case .simulateInputResult(.failure):
        state.outputString = "❌"
    case let .stateSymbolChanged(automatonStateID, symbol):
        state.automatonStatesDict[automatonStateID]?.name = symbol
    case let .transitionSymbolChanged(transitionID, symbol):
        state.transitionsDict[transitionID]?.currentSymbol = symbol
    case let .transitionSymbolAdded(transitionID):
        guard
            let transition = state.transitionsDict[transitionID]
        else { return .none }
        state.transitionsDict[transitionID]?.symbols.append(
            transition.currentSymbol
        )
        state.transitionsDict[transitionID]?.currentSymbol = ""
    case let .transitionSymbolRemoved(transitionID, symbol):
        state.transitionsDict[transitionID]?.symbols.removeAll(where: { $0 == symbol })
    case let .automataShapeClassified(.success(.state(stroke))):
        let center = stroke.controlPoints.center()
        
        let radius = stroke.controlPoints.radius(with: center)
        
        let controlPoints: [CGPoint] = .circle(
            center: center,
            radius: radius
        )
        
        if let automatonState = enclosingState(for: controlPoints) {
            guard !automatonState.isEndState else {
                state.shouldDeleteLastStroke = true
                return .none
            }
            let controlPoints = automatonState.stroke.controlPoints
            let center = controlPoints.center()
            state.automatonStatesDict[automatonState.id]?.isEndState = true
        } else if var transition = closestTransitionWithoutEndState(for: controlPoints) {
            guard
                let startPoint = transition.startPoint,
                let tipPoint = transition.tipPoint
            else { return .none }
            let vector = Vector(startPoint, tipPoint)
            let center = vector.point(distance: radius, other: tipPoint)
            
            let automatonState = AutomatonState(
                center: center,
                radius: radius
            )
            
            transition.endState = automatonState.id
            state.transitionsDict[transition.id] = transition
            
            state.automatonStatesDict[automatonState.id] = automatonState
        } else if var transition = closestTransitionWithoutStartState(for: controlPoints) {
            guard
                let startPoint = transition.startPoint,
                let tipPoint = transition.tipPoint
            else { return .none }
            let vector = Vector(tipPoint, startPoint)
            let center = vector.point(distance: radius, other: startPoint)
            
            let automatonState = AutomatonState(
                center: center,
                radius: radius
            )
            
            transition.startState = automatonState.id
            state.transitionsDict[transition.id] = transition
            
            state.automatonStatesDict[automatonState.id] = automatonState
        } else {
            let automatonState = AutomatonState(
                center: center,
                radius: radius
            )
            state.automatonStatesDict[automatonState.id] = automatonState
        }
    case let .transitionFlexPointFinishedDragging(transitionID, finalFlexPoint):
        guard var transition = state.transitionsDict[transitionID] else { return .none }
        transition.flexPoint = finalFlexPoint
        transition.currentFlexPoint = finalFlexPoint
        state.transitionsDict[transition.id] = transition
    case let .transitionFlexPointChanged(transitionID, flexPoint):
        state.transitionsDict[transitionID]?.flexPoint = flexPoint
    case let .stateDragPointChanged(automatonStateID, dragPoint):
        state.automatonStatesDict[automatonStateID]?.dragPoint = dragPoint
        state.transitions
            .filter { $0.endState == automatonStateID && $0.endState != $0.startState }
            .forEach { transition in
                guard
                    let flexPoint = transition.flexPoint,
                    let endStateID = transition.endState,
                    let endState = state.automatonStatesDict[endStateID]
                else { return }
                let vector = Vector(endState.center, flexPoint)
                state.transitionsDict[transition.id]?.tipPoint = vector.point(distance: endState.radius, other: endState.center)
            }
        state.transitions
            .filter { $0.startState == automatonStateID && $0.endState != $0.startState }
            .forEach { transition in
                guard
                    let flexPoint = transition.flexPoint,
                    let startStateID = transition.startState,
                    let startState = state.automatonStatesDict[startStateID]
                else { return }
                let vector = Vector(startState.center, flexPoint)
                state.transitionsDict[transition.id]?.startPoint = vector.point(distance: startState.radius, other: startState.center)
            }
        state.transitions
            .forEach { transition in
                switch transition.type {
                case let .cycle(point, center: center):
                    guard
                        let endStateID = transition.endState,
                        let endState = state.automatonStatesDict[endStateID]
                    else { return }
                    let vector = Vector(endState.center, point)
                    state.transitionsDict[transition.id]?.type = .cycle(
                        vector.point(distance: endState.radius, other: endState.center),
                        center: endState.center
                    )
                case .regular:
                    break
                }
            }
        
    case let .stateDragPointFinishedDragging(automatonStateID, dragPoint):
        state.automatonStatesDict[automatonStateID]?.dragPoint = dragPoint
        state.automatonStatesDict[automatonStateID]?.currentDragPoint = dragPoint
        state.transitions
            .filter { $0.endState == automatonStateID && $0.endState != $0.startState }
            .forEach { transition in
                guard
                    let flexPoint = transition.flexPoint,
                    let endStateID = transition.endState,
                    let endState = state.automatonStatesDict[endStateID]
                else { return }
                let vector = Vector(endState.center, flexPoint)
                state.transitionsDict[transition.id]?.tipPoint = vector.point(distance: endState.radius, other: endState.center)
            }
        state.transitions
            .filter { $0.startState == automatonStateID && $0.endState != $0.startState }
            .forEach { transition in
                guard
                    let flexPoint = transition.flexPoint,
                    let startStateID = transition.startState,
                    let startState = state.automatonStatesDict[startStateID]
                else { return }
                let vector = Vector(startState.center, flexPoint)
                state.transitionsDict[transition.id]?.startPoint = vector.point(distance: startState.radius, other: startState.center)
            }
    case let .automataShapeClassified(.success(.transitionCycle(stroke))):
        guard
            let strokeStartPoint = stroke.controlPoints.first,
            let closestStateResult = closestState(from: strokeStartPoint)
        else {
            state.shouldDeleteLastStroke = true
            return .none
        }
        
        let cycleControlPoints: [CGPoint] = .cycle(
            closestStateResult.point,
            center: closestStateResult.state.stroke.controlPoints.center()
        )
        let highestPoint = cycleControlPoints.min(by: { $0.y < $1.y }) ?? .zero

        let transition = AutomatonTransition(
            startState: closestStateResult.state.id,
            endState: closestStateResult.state.id,
            type: .cycle(closestStateResult.point, center: closestStateResult.state.stroke.controlPoints.center())
        )
        state.transitionsDict[transition.id] = transition
    case let .automataShapeClassified(.success(.transition(stroke))):
        guard
            let strokeStartPoint = stroke.controlPoints.first
        else { return .none }
        
        let closestStartStateResult = closestState(from: strokeStartPoint)
        
        let furthestPoint = stroke.controlPoints.furthestPoint(from: closestStartStateResult?.point ?? strokeStartPoint)
        let closestEndStateResult = closestState(
            from: furthestPoint
        )
        
        let startPoint: CGPoint
        let tipPoint: CGPoint
        let startState: AutomatonState?
        let endState: AutomatonState?
        if
            let closestStartStateResult = closestStartStateResult,
            let closestEndStateResult = closestEndStateResult,
            closestStartStateResult.state == closestEndStateResult.state {
            let startIsCloser = closestStartStateResult.distance < closestEndStateResult.distance
            startPoint = startIsCloser ? closestStartStateResult.point : strokeStartPoint
            tipPoint = startIsCloser ? furthestPoint : closestEndStateResult.point
            startState = startIsCloser ? closestStartStateResult.state : nil
            endState = startIsCloser ? nil : closestEndStateResult.state
        } else {
            startPoint = closestStartStateResult?.point ?? strokeStartPoint
            tipPoint = closestEndStateResult?.point ?? furthestPoint
            startState = closestStartStateResult?.state
            endState = closestEndStateResult?.state
        }
        
        let flexPoint = CGPoint(
            x: (startPoint.x + tipPoint.x) / 2,
            y: (startPoint.y + tipPoint.y) / 2
        )
        
        let transition = AutomatonTransition(
            startState: startState?.id,
            endState: endState?.id,
            type: .regular(
                startPoint: startPoint,
                tipPoint: tipPoint,
                flexPoint: flexPoint
            ),
            currentFlexPoint: flexPoint
        )
        state.transitionsDict[transition.id] = transition
    case .automataShapeClassified(.failure):
        state.shouldDeleteLastStroke = true
    case let .strokesChanged(strokes):
        // A stroke was deleted
        if strokes.count < state.strokes.count {
            // TODO: Fix
//            let centerPoints = strokes.map { $0.controlPoints.center() }
//            if let transitionIndex = state.transitions.firstIndex(
//                where: { transition in
//                    !strokes.contains(
//                        where: {
//                            transition.startPoint.distance(from: $0.controlPoints[0]) == 0
//                        }
//                    )
//                }
//            ) {
//                state.transitions.remove(at: transitionIndex)
//            } else if let automatonStateIndex = state.automatonStates.firstIndex(
//                where: { state in
//                    !centerPoints.contains(
//                        where: {
//                            sqrt(state.stroke.controlPoints.center().distance(from: $0)) < 20
//                        }
//                    )
//                }
//            ) {
//                let automatonState = state.automatonStates[automatonStateIndex]
//                state.automatonStates.remove(at: automatonStateIndex)
//                state.transitions = state.transitions.map { transition in
//                    var transition = transition
//                    if transition.startState == automatonState.id {
//                        transition.startState = nil
//                    }
//                    if transition.endState == automatonState.id {
//                        transition.endState = nil
//                    }
//                    return transition
//                }
//            }
        } else {
            guard let stroke = strokes.last else { return .none }
            return env.automataClassifierService
                .recognizeStroke(stroke)
                .receive(on: env.mainQueue)
                .catchToEffect()
                .map(EditorAction.automataShapeClassified)
                .eraseToEffect()
        }
    case let .shouldDeleteLastStrokeChanged(shouldDeleteLastStroke):
        state.shouldDeleteLastStroke = shouldDeleteLastStroke
    }
    
    return .none
}
