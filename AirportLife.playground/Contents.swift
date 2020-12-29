/*:
 # Airport Life
 *Playground that simulates the operation of airport (airplanes' taxiing, takeoffs and landings). I used **McCarran International Airport (KLAS)** as an example.*
 ## Controls:
 Use **arrow keys** to move the camera.
 
 **Pinch** to change camera zoom.
 */
import PlaygroundSupport
import SpriteKit
let debugMode: debugModes = .None
let sceneView = GameView(frame: CGRect(x:0 , y:0, width: 640, height: 480))
if let scene = GameScene(fileNamed: "KLAS") {
    scene.scaleMode = .aspectFill
    scene.airport = Airport(scene: scene)
    scene.showDebug(debugMode: debugMode)
    scene.generateParks(percentage: 80)
    sceneView.presentScene(scene)
}

PlaygroundSupport.PlaygroundPage.current.liveView = sceneView
