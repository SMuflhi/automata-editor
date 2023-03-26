import SwiftUI
import Vision
import PencilKit
import ComposableArchitecture

struct EditorView: View {
    let store: StoreOf<EditorFeature>
    
    var body: some View {
        WithViewStore(store) { viewStore in
            GeometryReader { geometry in
                ZStack {
                    ZStack {
                        CanvasView(
                            tool: viewStore.state.tool,
                            strokesChanged: { viewStore.send(.strokesChanged($0)) },
                            currentVisibleScrollViewRectChanged: { viewStore.send(.currentVisibleScrollViewRectChanged($0)) }
                        ) {
                            ZStack {
                                TransitionsView(
                                    transitions: viewStore.transitions,
                                    toggleEpsilonInclusion: { viewStore.send(.toggleEpsilonInclusion($0)) },
                                    transitionSymbolRemoved: { viewStore.send(.transitionSymbolRemoved($0, $1)) },
                                    transitionSymbolChanged: { viewStore.send(.transitionSymbolChanged($0, $1)) },
                                    transitionSymbolAdded: { viewStore.send(.transitionSymbolAdded($0)) },
                                    transitionRemoved: { viewStore.send(.transitionRemoved($0)) },
                                    transitionDragged: {
                                        viewStore.send(.transitionFlexPointChanged($0, $1))
                                    },
                                    transitionFinishedDragging: {
                                        viewStore.send(.transitionFlexPointFinishedDragging($0, $1))
                                    },
                                    mode: viewStore.mode
                                )
                                AutomatonStatesView(
                                    automatonStates: viewStore.automatonStates,
                                    stateSymbolChanged: { viewStore.send(.stateSymbolChanged($0, $1)) },
                                    automatonStateDragged: { viewStore.send(.stateDragPointChanged($0, $1)) },
                                    automatonStateFinishedDragging: { viewStore.send(.stateDragPointFinishedDragging($0, $1)) },
                                    automatonStateRemoved: { viewStore.send(.automatonStateRemoved($0)) },
                                    selectedStateForTransition: { viewStore.send(.selectedStateForTransition($0)) },
                                    selectedStateForCycle: { viewStore.send(.selectedStateForCycle($0)) },
                                    selectedFinalState: { viewStore.send(.selectedFinalState($0)) },
                                    currentlySelectedStateForTransition: viewStore.currentlySelectedStateForTransition,
                                    mode: viewStore.mode
                                )
                            }
                        }
                        Text("Output: \(viewStore.outputString)")
                            .frame(width: 140)
                            .position(x: 70, y: 50)
                    }
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HStack {
                                TextField(
                                    "Automaton input",
                                    text: viewStore.binding(
                                        get: \.input,
                                        send: { .inputChanged($0) }
                                    )
                                )
                                .foregroundColor(.black)
                                Button(
                                    action: {
                                        viewStore.send(.removeLastInputSymbol)
                                    }
                                ) {
                                    Image(systemName: "delete.left")
                                        .foregroundColor(Color(UIColor.opaqueSeparator))
                                }
                            }
                            .frame(width: 200)
                            .padding(15)
                            .background(.white)
                            .cornerRadius(15)
                            Spacer()
                        }
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .principal) {
                        HStack {
                            Button(action: { viewStore.send(.simulateInput) }) {
                                Image(systemName: "play.fill")
                            }
                            Button(action: { viewStore.send(.selectedPen) }) {
                                Image(systemName: viewStore.state.isPenSelected ? "pencil.circle.fill" : "pencil.circle")
                            }
                            Button(action: { viewStore.send(.selectedEraser) }) {
                                Image(systemName: viewStore.state.isEraserSelected ? "eraser.fill" : "eraser")
                            }
                            Menu {
                                Button(action: { viewStore.send(.addNewState) }) {
                                    Label("State", systemImage: "circle")
                                }
                                
                                Button(action: { viewStore.send(.startAddingTransition) }) {
                                    Label("Transition", systemImage: "arrow.right")
                                }
                                Button(action: { viewStore.send(.startAddingCycle) }) {
                                    Label("Cycle", systemImage: "arrow.counterclockwise")
                                }
                                Button(action: { viewStore.send(.startAddingFinalState) }) {
                                    Label("Final state", systemImage: "circle.circle")
                                }
                            } label: {
                                Label("Add new element", systemImage: "plus.circle")
                            }
                        }
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        switch viewStore.mode {
                        case .editing, .erasing:
                            Button(action: { viewStore.send(.clear) }) {
                                Image(systemName: "trash")
                            }
                        case .addingTransition:
                            Button("Cancel", action: { viewStore.send(.stopAddingTransition) })
                        case .addingCycle:
                            Button("Cancel", action: { viewStore.send(.stopAddingCycle) })
                        case .addingFinalState:
                            Button("Cancel", action: { viewStore.send(.stopAddingFinalState) })
                        }
                    }
                }
                .onChange(of: viewStore.state, perform: { viewStore.send(.stateUpdated($0)) })
                .onAppear { viewStore.send(.viewSizeChanged(geometry.size)) }
            }
        }
    }
}
