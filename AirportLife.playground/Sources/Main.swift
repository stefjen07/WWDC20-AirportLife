import Foundation
import SpriteKit
public enum debugModes
{
    case None
    case ShowRDs
    case ShowRWYs
    case ShowAll
    case ShowPRKs
}

public enum operationType
{
    case Transit
    case Takeoff
}

public enum routeType: Int
{
    case toPark = 0
    case toRunway
}

public class Operation
{
    public let type: operationType
    public let transitRoute: Route
    public let aircraft: SKNode
    init(type: operationType)
    {
        self.type = type
        self.transitRoute = Route(type: .toPark, scene: GameScene())
        self.aircraft = SKNode()
    }
    init(type: operationType, transitRoute: Route, aircraft: SKNode)
    {
        self.type = type
        self.transitRoute = transitRoute
        self.aircraft = aircraft
    }
}

public class Route
{
    public var type: routeType
    public let scene: GameScene
    public var way = [Int]()
    public var duration = 0.0
    init(type: routeType, scene: GameScene)
    {
        self.type = type
        self.scene = scene
    }
    @objc func deferredTransit(sender: Timer)
    {
        let info = sender.userInfo as! ([Int], SKNode, Runway, Int)
        let way = info.0
        let aircraft = info.1
        let runway = info.2
        let route = Route(type: routeType(rawValue: info.3)!, scene: scene)
        route.way = way
        if(type == .toPark)
        {
            runway.operationQueue.insert(Operation(type: .Transit, transitRoute: route, aircraft: aircraft), at: 0)
        } else {
            runway.operationQueue.append(Operation(type: .Transit, transitRoute: route, aircraft: aircraft))
        }
    }
    public func useRoute(aircraft: SKNode, airport: Airport, operationRunway: Runway?)
    {
        var anims = [SKAction]()
        var pRot = aircraft.zRotation
        if(way.count>0)
        {
            var frunway = way[0].isTransit(in: airport)
            if(operationRunway != nil)
            {
                frunway = nil
            }
            let frot = airport.wps[way[0]].angle(to: aircraft.position)
            var fchange = frot-pRot
            if(abs(fchange)>=CGFloat(Double.pi))
            {
                fchange = 2*CGFloat(Double.pi)-max(frot,pRot)+min(frot,pRot)
                if(frot>pRot)
                {
                    fchange = -fchange
                }
            }
            if(frunway != nil)
            {
                Timer.scheduledTimer(timeInterval: 0.04, target: self, selector: #selector(deferredTransit(sender: )), userInfo: (way, aircraft, frunway, type.rawValue), repeats: false)
            } else {
                pRot = frot
                anims.append(SKAction.rotate(byAngle: fchange, duration: Double(abs(fchange))*0.5))
                anims.append(SKAction.move(to: airport.wps[way[0]], duration: Double(sqrt(pow(abs(airport.wps[way[0]].x-aircraft.position.x),2)+pow(abs(airport.wps[way[0]].y-aircraft.position.y),2)))*0.08))
                if(way.count>1)
                {
                    for i in 1...way.count-1
                    {
                        let runway = way[i].isTransit(in: airport)
                        let rot = airport.wps[way[i]].angle(to: airport.wps[way[i-1]])
                        var change = rot-pRot
                        if(abs(change)>=CGFloat(Double.pi))
                        {
                            change = 2*CGFloat(Double.pi)-max(rot,pRot)+min(rot,pRot)
                            if(rot>pRot)
                            {
                                change = -change
                            }
                        }
                        if(runway != nil)
                        {
                            let route = Route(type: type, scene: scene)
                            route.way = [Int]()+way[i...way.count-1]
                            if(anims.count>0)
                            {
                                let seq = SKAction.sequence(anims)
                                aircraft.run(seq)
                                duration = seq.duration
                            }
                            Timer.scheduledTimer(timeInterval: duration+0.04, target: self, selector: #selector(deferredTransit(sender: )), userInfo: (route.way, aircraft, runway, type.rawValue), repeats: false)
                            return
                        }
                        pRot = rot
                        anims.append(SKAction.rotate(byAngle: change, duration: Double(abs(change))*0.5))
                        anims.append(SKAction.move(to: airport.wps[way[i]], duration: Double(Road(start: way[i], end: way[i-1]).length(airport: airport))*0.08))
                        if(i==1 && operationRunway != nil)
                        {
                            let seq = SKAction.sequence(anims)
                            duration = seq.duration
                            if let rw = way[i-1].isTransit(in: airport) {
                                Timer.scheduledTimer(timeInterval: duration+0.04, target: self, selector: #selector(deoperate(sender: )), userInfo: rw, repeats: false)
                            }
                        }
                    }
                }
            }
        }
        let seq = SKAction.sequence(anims)
        duration = seq.duration
        aircraft.run(seq)
        if(type == .toPark)
        {
            Timer.scheduledTimer(timeInterval: duration+0.04, target: self, selector: #selector(park(sender: )), userInfo: aircraft, repeats: false)
        } else {
            Timer.scheduledTimer(timeInterval: duration+0.04, target: self, selector: #selector(takeoff(sender: )), userInfo: aircraft, repeats: false)
        }
    }
    @objc func deoperate(sender: Timer)
    {
        scene.deoperate(sender: sender)
    }
    @objc func takeoff(sender: Timer)
    {
        scene.toTakeoff(sender: sender)
    }
    @objc func park(sender: Timer)
    {
        scene.park(sender: sender)
    }
}

public class Park {
    public let pos: CGPoint
    public let rot: CGFloat
    public let pushback: Int
    public var busy: Bool
    public var taxiing: SKSpriteNode?
    init() {
        self.pos = CGPoint()
        self.rot = 0
        self.pushback = 0
        self.busy = true
        self.taxiing = nil
    }
    init(pos: CGPoint, rot: CGFloat, point: Int) {
        self.pos = pos
        self.rot = rot
        self.pushback = point
        self.busy = false
        self.taxiing = nil
    }
}

public class Road {
    public let start: Int
    public let end: Int
    public init(start: Int, end: Int) {
        self.start=start
        self.end=end
    }
    public func length(airport: Airport) -> CGFloat {
        return sqrt(pow(abs(airport.wps[start].x-airport.wps[end].x),2)+pow(abs(airport.wps[start].y-airport.wps[end].y),2))
    }
}
public class Runway {
    public let node: SKNode
    public let start: Int
    public let end: Int
    public let points: [Int]
    public var operationQueue = [Operation]()
    public var operating: SKSpriteNode? = nil
    public var timer = Timer()
    public let scene: GameScene
    @objc func queueIter()
    {
         if(operationQueue.count>0 && operating == nil)
         {
             let operation = operationQueue.first!
             operationQueue.removeFirst()
             operating = operation.aircraft as? SKSpriteNode
             if(operation.type == .Transit)
             {
                 operation.transitRoute.useRoute(aircraft: operating!, airport: scene.airport, operationRunway: self)
             }
             if(operation.type == .Takeoff)
             {
                 if(operation.aircraft.position == scene.airport.wps[self.start])
                 {
                     scene.takeoff(aircraft: operation.aircraft as! SKSpriteNode)
                 } else {
                     scene.takeoff(aircraft: operation.aircraft as! SKSpriteNode)
                 }
             }
         } else if(Int.random(in: 0...10)==0 && operating == nil) {
             var park: Park? = nil
             for m in scene.airport.prks
             {
                 if(!m.busy)
                 {
                     park = m
                     m.busy = true
                     break
                 }
             }
            if(park != nil)
            {
                let j=Int.random(in: 0...1)
                var aircraft = SKSpriteNode()
                switch(j)
                {
                    case 0:
                        aircraft = SKSpriteNode(imageNamed: "B737.gif")
                    default:
                        aircraft = SKSpriteNode(imageNamed: "A320.gif")
                }
                aircraft.scale(to: CGSize(width: 12, height: 16))
                scene.addChild(aircraft)
                park!.taxiing = aircraft
                scene.aircrafts.append(aircraft)
                operating = aircraft
                scene.landing(aircraft: aircraft, runway: self)
            }
         } else {
             queueTimer(duration: Double.random(in: 0.5...1))
         }
    }

    func queueTimer(duration: TimeInterval)
    {
        self.timer = Timer.scheduledTimer(timeInterval: duration, target: self, selector: #selector(queueIter), userInfo: nil, repeats: false)
    }

    public init(node: SKNode, start: Int, end: Int, scene: GameScene, points: [Int]) {
        self.node = node
        self.start = start
        self.end = end
        self.scene = scene
        self.points = points
    }
}

public class GameScene: SKScene {
    public var airport = Airport()
    public var aircrafts = [SKNode]()
    
    public func showDebug(debugMode: debugModes)
    {
        if(debugMode == .ShowRDs || debugMode == .ShowAll)
        {
            for i in airport.rds
            {
                let path = CGMutablePath()
                path.move(to: airport.wps[i.start])
                path.addLine(to: airport.wps[i.end])
                let node = SKShapeNode(path: path)
                node.lineWidth = 5
                node.strokeColor = NSColor.red
                self.addChild(node)
            }
        }
        if(debugMode == .ShowRWYs || debugMode == .ShowAll)
        {
            for i in airport.rwys
            {
                let rwy = i.node
                rwy.alpha = 1
                let path = CGMutablePath()
                path.move(to: airport.wps[i.start])
                path.addLine(to: airport.wps[i.end])
                let node = SKShapeNode(path: path)
                node.lineWidth = 1.5
                node.strokeColor = NSColor.blue
                self.addChild(node)
            }
        }
        if(debugMode == .ShowPRKs || debugMode == .ShowAll)
        {
            for i in airport.prks
            {
                let path = CGMutablePath()
                path.move(to: i.pos)
                path.addLine(to: airport.wps[i.pushback])
                let node = SKShapeNode(path: path)
                node.lineWidth = 1
                node.strokeColor = NSColor.purple
                self.addChild(node)
            }
        }
        if(debugMode == .None)
        {
            for i in 0...airport.wps.count-1
            {
                self.childNode(withName: String(i))!.isHidden = true
            }
            for i in 0...airport.prks.count-1
            {
                self.childNode(withName: "P\(i)")!.isHidden = true
            }
        }
    }
    
    public func generateParks(percentage: Int)
    {
        var parks = airport.prks
        while(parks.count>=airport.prks.count*percentage/100)
        {
            parks.remove(at: Int.random(in: 0...parks.count-1))
        }
        for i in parks
        {
            let j=Int.random(in: 0...1)
            var aircraft: SKSpriteNode
            switch(j)
            {
                case 0:
                    aircraft = SKSpriteNode(imageNamed: "B737.gif")
                default:
                    aircraft = SKSpriteNode(imageNamed: "A320.gif")
            }
            aircraft.position = i.pos
            aircraft.zRotation = i.rot+CGFloat(Double.pi*1.5)
            aircraft.scale(to: CGSize(width: 12, height: 16))
            i.busy = true
            self.addChild(aircraft)
            aircrafts.append(aircraft)
        }
        Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(newFlight), userInfo: nil, repeats: true)
    }
    
    @objc func newFlight()
    {
        var aircraft: SKSpriteNode? = nil
        var busyCount = 0.0
        var parkCount = 0.0
        for i in airport.prks
        {
            if(i.busy)
            {
                for j in aircrafts
                {
                    if(j.position == i.pos && i.taxiing == nil)
                    {
                        aircraft = j as? SKSpriteNode
                        busyCount+=1
                    }
                }
            }
            parkCount+=1
        }
        if(aircraft != nil && busyCount/parkCount>=0.6 && Int.random(in: 0...20)==0)
        {
            pushback(aircraft: aircraft!)
            Timer.scheduledTimer(timeInterval: 2+0.04, target: self, selector: #selector(toRunway(sender: )), userInfo: aircraft!, repeats: false)
        }
    }
    
    @objc func toRunway(sender: Timer)
    {
        let aircraft = sender.userInfo as! SKSpriteNode
        for m in airport.prks
        {
            if(airport.wps[m.pushback] == aircraft.position)
            {
                var rw = airport.rwys.randomElement()!.start
                if(Int.random(in: 0...1)==0)
                {
                    rw = airport.rwys.randomElement()!.end
                }
                let route = generateRoute(start: m.pushback, end: rw)
                route.type = .toRunway
                route.useRoute(aircraft: aircraft, airport: airport, operationRunway: nil)
            }
        }
    }
    
    @objc func toTakeoff(sender: Timer)
    {
        let aircraft = sender.userInfo as! SKSpriteNode
        var runway = Runway(node: SKNode(), start: 0, end: 0, scene: self, points: [Int]())
        for i in airport.rwys
        {
            if(aircraft.position == airport.wps[i.start] || aircraft.position == airport.wps[i.end])
            {
                runway = i
            }
        }
        runway.operationQueue.append(Operation(type: .Takeoff, transitRoute: Route(type: .toRunway, scene: self), aircraft: aircraft))
    }
    
    @objc public func park(sender: Timer)
    {
        let aircraft = sender.userInfo as! SKSpriteNode
        for i in airport.prks
        {
            if(aircraft.position == airport.wps[i.pushback])
            {
                i.taxiing = nil
                var anims = [SKAction]()
                var pRot = aircraft.zRotation
                let rot = i.pos.angle(to: aircraft.position)
                var change = rot-pRot
                if(abs(change)>=CGFloat(Double.pi))
                {
                    change = 2*CGFloat(Double.pi)-max(rot,pRot)+min(rot,pRot)
                    if(rot>pRot)
                    {
                        change = -change
                    }
                }
                anims.append(SKAction.rotate(byAngle: change, duration: Double(abs(change))*0.5))
                pRot = rot
                anims.append(SKAction.move(to: i.pos, duration: Double(sqrt(pow(abs(i.pos.x-aircraft.position.x),2)+pow(abs(i.pos.y-aircraft.position.y),2)))*0.08))
                aircraft.run(SKAction.sequence(anims))
            }
        }
    }
    
    public func pushback(aircraft: SKNode)
    {
        var park = Park()
        for i in airport.prks
        {
            if(i.pos == aircraft.position)
            {
                park = i
            }
        }
        park.busy = false
        aircraft.run(SKAction.move(to: airport.wps[park.pushback], duration: 2))
    }
    
    public func takeoff(aircraft: SKSpriteNode)
    {
        var runway = Runway(node: SKNode(), start: 0, end: 0, scene: self, points: [Int]())
        var dir = Int()
        for i in airport.rwys
        {
            if(aircraft.position == airport.wps[i.start])
            {
                runway = i
                dir=0
            }
            if(aircraft.position == airport.wps[i.end])
            {
                runway = i
                dir=1
            }
        }
        var actions = [SKAction]()
        var vec = CGVector()
        if(dir==0)
        {
            aircraft.position = airport.wps[runway.start]
            aircraft.zRotation = airport.wps[runway.end].angle(to: airport.wps[runway.start])
            vec = CGVector(dx: airport.wps[runway.end].x-airport.wps[runway.start].x,dy: airport.wps[runway.end].y-airport.wps[runway.start].y)
        } else {
            aircraft.position = airport.wps[runway.end]
            aircraft.zRotation = airport.wps[runway.start].angle(to: airport.wps[runway.end])
            vec = CGVector(dx: airport.wps[runway.start].x-airport.wps[runway.end].x,dy: airport.wps[runway.start].y-airport.wps[runway.end].y)
        }
        for i in 0...50
        {
            actions.append(SKAction.move(by: CGVector(dx: vec.dx/CGFloat(51-i), dy: vec.dy/CGFloat(51-i)), duration: 0.5))
        }
        aircraft.run(SKAction.sequence(actions))
        Timer.scheduledTimer(timeInterval: 22, target: self, selector: #selector(remove(sender: )), userInfo: aircraft, repeats: false)
    }
    
    @objc func remove(sender: Timer)
    {
        let aircraft = sender.userInfo as! SKNode
        for i in airport.rwys
        {
            if(i.operating == aircraft)
            {
                i.operating = nil
                i.queueIter()
            }
        }
        aircraft.removeFromParent()
    }
    
    public func landing(aircraft: SKNode, runway: Runway)
    {
        let dir = Int.random(in: 0...1)
        var vec = CGVector()
        if(dir==0)
        {
            vec = CGVector(dx: airport.wps[runway.end].x-airport.wps[runway.start].x,dy: airport.wps[runway.end].y-airport.wps[runway.start].y)
            aircraft.position = airport.wps[runway.end]
            aircraft.position.x -= vec.dx*2
            aircraft.position.y -= vec.dy*2
            aircraft.zRotation = airport.wps[runway.end].angle(to: airport.wps[runway.start])
        } else {
            vec = CGVector(dx: airport.wps[runway.start].x-airport.wps[runway.end].x,dy: airport.wps[runway.start].y-airport.wps[runway.end].y)
            aircraft.position = airport.wps[runway.start]
            aircraft.position.x -= vec.dx*2
            aircraft.position.y -= vec.dy*2
            aircraft.zRotation = airport.wps[runway.start].angle(to: airport.wps[runway.end])
        }
        var actions = [SKAction]()
        let eff = CGFloat.random(in: 0.8...1)
        for i in 8...25
        {
            actions.append(SKAction.move(by: CGVector(dx: eff*vec.dx/CGFloat(i+1), dy: eff*vec.dy/CGFloat(i+1)), duration: 0.5))
        }
        for i in 0...8
        {
            actions.append(SKAction.move(by: CGVector(dx: eff*vec.dx/CGFloat(25+i*2), dy: eff*vec.dy/CGFloat(25+i*2)), duration: 0.5))
        }
        for i in 0...4
        {
            actions.append(SKAction.move(by: CGVector(dx: eff*vec.dx/CGFloat(41+i*4), dy: eff*vec.dy/CGFloat(41+i*4)), duration: 0.5))
        }
        for i in 0...3
        {
            actions.append(SKAction.move(by: CGVector(dx: eff*vec.dx/CGFloat(57+i*8), dy: eff*vec.dy/CGFloat(57+i*8)), duration: 0.5))
        }
        for i in 0...2
        {
            actions.append(SKAction.move(by: CGVector(dx: eff*vec.dx/CGFloat(81+i*16), dy: eff*vec.dy/CGFloat(81+i*16)), duration: 0.5))
        }
        for i in 0...2
        {
            actions.append(SKAction.move(by: CGVector(dx: eff*vec.dx/CGFloat(113+i*32), dy: eff*vec.dy/CGFloat(113+i*16)), duration: 0.5))
        }
        for i in 0...2
        {
            actions.append(SKAction.move(by: CGVector(dx: eff*vec.dx/CGFloat(177+i*128), dy: eff*vec.dy/CGFloat(177+i*128)), duration: 0.5))
        }
        let seq = SKAction.sequence(actions)
        aircraft.run(seq)
        Timer.scheduledTimer(timeInterval: seq.duration, target: self, selector: #selector(toPark(sender: )), userInfo: aircraft, repeats: false)
        runway.queueTimer(duration: seq.duration+0.01)
    }
    
    @objc func toPark(sender: Timer)
    {
        let aircraft = sender.userInfo as! SKSpriteNode
        for i in airport.rwys
        {
            if(i.operating == aircraft)
            {
                var minL = 1000000.0
                var wp = -1
                if(aircraft.zRotation>CGFloat(0) && aircraft.zRotation<CGFloat(Double.pi))
                {
                    for j in 0...airport.wps.count-1
                    {
                        if(i.points.contains(j) && j != i.start && j != i.end && airport.wps[j].x<aircraft.position.x)
                        {
                            if(Double(sqrt(pow(abs(airport.wps[j].x-aircraft.position.x),2)+pow(abs(airport.wps[j].y-aircraft.position.y),2)))<minL)
                            {
                                minL = Double(sqrt(pow(abs(airport.wps[j].x-aircraft.position.x),2)+pow(abs(airport.wps[j].y-aircraft.position.y),2)))
                                wp = j
                            }
                        }
                    }
                    
                } else {
                    for j in 0...airport.wps.count-1
                    {
                        if(i.points.contains(j) && j != i.start && j != i.end && airport.wps[j].x>=aircraft.position.x)
                        {
                            if(Double(sqrt(pow(abs(airport.wps[j].x-aircraft.position.x),2)+pow(abs(airport.wps[j].y-aircraft.position.y),2)))<minL)
                            {
                                minL = Double(sqrt(pow(abs(airport.wps[j].x-aircraft.position.x),2)+pow(abs(airport.wps[j].y-aircraft.position.y),2)))
                                wp = j
                            }
                        }
                    }
                }
                for m in airport.prks
                {
                    if(m.taxiing == aircraft)
                    {
                        let route = generateRoute(start: wp, end: m.pushback)
                        route.type = .toPark
                        route.useRoute(aircraft: aircraft, airport: airport, operationRunway: i)
                        break
                    }
                }
                break
            }
        }
        
    }
    @objc func deoperate(sender: Timer)
    {
        let runway = sender.userInfo as! Runway
        runway.operating = nil
        runway.queueIter()
    }
    public func generateRoute(start: Int, end: Int) -> Route
    {
        var g = [[CGPoint]]()
        for i in 0...airport.wps.count-1
        {
            var arr = [CGPoint]()
            for j in airport.rds
            {
                if(j.start==i)
                {
                    arr.append(CGPoint(x: j.end,y: Int(j.length(airport: airport))))
                }
                if(j.end==i)
                {
                    arr.append(CGPoint(x: j.start,y: Int(j.length(airport: airport))))
                }
            }
            g.append(arr)
        }
        var d = [Int](), p = [Int](), u = [Bool]()
        for _ in 0...airport.wps.count-1
        {
            d.append(1000000)
            p.append(-1)
            u.append(false)
        }
        d[start] = 0;
        for _ in 0...airport.wps.count-1
        {
            var v = -1
            for j in 0...airport.wps.count-1
            {
                if(!u[j] && (v == -1 || d[j] < d[v])) //warn
                {
                    v = j
                }
            }
            if(d[v] == 1000000)
            {
                break
            }
            u[v] = true
            
            for j in 0...g[v].count-1
            {
                let to = Int(g[v][j].x),
                    len = Int(g[v][j].y);
                if (d[v] + len < d[to]) {
                    d[to] = d[v] + len;
                    p[to] = v;
                }
            }
        }
        if(d[end]==1000000)
        {
            print("No path from \(start) to \(end)")
        }
        let way = Route(type: .toPark, scene: self)
        var path = [Int]();
        var v = end
        while(v != start)
        {
            path.append(v)
            v=p[v]
        }
        path.append(start)
        path.reverse()
        way.way = path
        return way
    }
}

public class GameView: SKView
{
    var zoom = CGFloat(1)
    var tempZoom = CGFloat(1)
    var camera = SKCameraNode()
    public override func keyDown(with event: NSEvent) {
        var vec = CGVector()
        switch event.keyCode {
            case 123:
                vec = CGVector(dx: -20, dy: 0)
            case 126:
                vec = CGVector(dx: 0, dy: 20)
            case 125:
                vec = CGVector(dx: 0, dy: -20)
            case 124:
                vec = CGVector(dx: 20, dy: 0)
            default:
                break
        }
        let size = CGSize(width: self.scene!.size.width*zoom, height: self.scene!.size.height*zoom)
        let rect = CGRect(origin: CGPoint(x: camera.position.x-size.width/2, y: camera.position.y-size.height/2), size: size)
        if(rect.minX+vec.dx >= -512 && rect.maxX+vec.dx <= 512 && rect.minY+vec.dy >= -384 && rect.maxY+vec.dy <= 384)
        {
            camera.run(SKAction.move(by: vec, duration: 0.1))
        }
    }
    public override func magnify(with event: NSEvent) {
        super.magnify(with: event)
        tempZoom*=event.magnification+1
        switch event.phase {
            case .began:
                tempZoom=1
            case .changed:
                break
            case .ended:
                var fZoom = zoom
                if(tempZoom < 0)
                {
                    fZoom*=tempZoom
                }
                if(tempZoom > 0)
                {
                    fZoom/=tempZoom
                }
                if(fZoom>1)
                {
                    fZoom = 1
                }
                if(fZoom<0.2)
                {
                    fZoom = 0.2
                }
                let size = CGSize(width: self.scene!.size.width*fZoom, height: self.scene!.size.height*fZoom)
                let fPos = CGPoint(x: min(512-size.width/2,max((-512+size.width/2),camera.position.x)), y: min(384-size.height/2,max((-384+size.height/2),camera.position.y)))
                camera.run(SKAction.move(to: fPos, duration: 0.1))
                zoom = fZoom
                self.scene!.camera?.run(SKAction.scale(to: zoom, duration: 0.3))
            default:
                tempZoom+=event.magnification
        }
    }
    public override func presentScene(_ scene: SKScene?) {
        super.presentScene(scene)
        scene!.addChild(camera)
        scene!.camera = camera
    }
}

extension CGPoint {
    func angle(to comparisonPoint: CGPoint) -> CGFloat {
        let originX = comparisonPoint.x - self.x
        let originY = comparisonPoint.y - self.y
        var angle = CGFloat(atan2f(Float(originY), Float(originX))+Float(Double.pi*0.5))
        while(angle < 0)
        {
            angle += 2*CGFloat(Double.pi)
        }
        while(angle > 2*CGFloat(Double.pi))
        {
            angle -= 2*CGFloat(Double.pi)
        }
        return angle
    }
}

extension Int {
    func isTransit(in airport: Airport) -> Runway? {
        var runway: Runway? = nil
        for i in airport.rwys
        {
            if(i.points.contains(self))
            {
                runway = i
            }
        }
        return runway
    }
}
