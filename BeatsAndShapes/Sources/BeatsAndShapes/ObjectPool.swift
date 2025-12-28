import SpriteKit

class ObjectPool<T: AnyObject> {
    private var pool: [T] = []
    private let factory: () -> T
    private let reset: (T) -> Void
    private var activeObjects: Set<ObjectIdentifier> = []
    
    init(capacity: Int, factory: @escaping () -> T, reset: @escaping (T) -> Void) {
        self.factory = factory
        self.reset = reset
        
        for _ in 0..<capacity {
            let obj = factory()
            pool.append(obj)
        }
    }
    
    func getObject() -> T {
        if let obj = pool.first(where: { !activeObjects.contains(ObjectIdentifier($0)) }) {
            activeObjects.insert(ObjectIdentifier(obj))
            reset(obj)
            return obj
        }
        
        let newobj = factory()
        activeObjects.insert(ObjectIdentifier(newobj))
        pool.append(newobj)
        return newobj
    }
    
    func returnObject(_ obj: T) {
        activeObjects.remove(ObjectIdentifier(obj))
    }
    
    func returnAllObjects() {
        activeObjects.removeAll()
    }
    
    var activeCount: Int {
        return activeObjects.count
    }
}

class ObstaclePoolManager {
    static let shared = ObstaclePoolManager()
    
    private var beamPool: ObjectPool<SKShapeNode>!
    private var pulsarPool: ObjectPool<SKShapeNode>!
    private var aimedPool: ObjectPool<SKShapeNode>!
    
    private init() {}
    
    func initialize(in scene: SKScene) {
        beamPool = ObjectPool<SKShapeNode>(capacity: 20) {
            let beam = SKShapeNode(rectOf: CGSize(width: 4000, height: 30))
            beam.fillColor = .red
            beam.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 4000, height: 30))
            beam.physicsBody?.isDynamic = false
            beam.physicsBody?.categoryBitMask = 0x1 << 1
            return beam
        } reset: { beam in
            beam.position = .zero
            beam.alpha = 1.0
            beam.removeAllActions()
        }
        
        pulsarPool = ObjectPool<SKShapeNode>(capacity: 15) {
            let pulsar = SKShapeNode(circleOfRadius: 10)
            pulsar.fillColor = .red
            return pulsar
        } reset: { pulsar in
            pulsar.position = .zero
            pulsar.alpha = 1.0
            pulsar.removeAllActions()
            pulsar.xScale = 1.0
            pulsar.yScale = 1.0
        }
        
        aimedPool = ObjectPool<SKShapeNode>(capacity: 25) {
            let aimed = SKShapeNode(rectOf: CGSize(width: 20, height: 20))
            aimed.fillColor = .red
            aimed.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 20, height: 20))
            aimed.physicsBody?.isDynamic = false
            aimed.physicsBody?.categoryBitMask = 0x1 << 1
            return aimed
        } reset: { aimed in
            aimed.position = .zero
            aimed.alpha = 1.0
            aimed.removeAllActions()
        }
    }
    
    func getBeam() -> SKShapeNode {
        return beamPool.getObject()
    }
    
    func getPulsar() -> SKShapeNode {
        return pulsarPool.getObject()
    }
    
    func getAimed() -> SKShapeNode {
        return aimedPool.getObject()
    }
    
    func returnBeam(_ beam: SKShapeNode) {
        beamPool.returnObject(beam)
    }
    
    func returnPulsar(_ pulsar: SKShapeNode) {
        pulsarPool.returnObject(pulsar)
    }
    
    func returnAimed(_ aimed: SKShapeNode) {
        aimedPool.returnObject(aimed)
    }
    
    func getActiveCount() -> Int {
        return beamPool.activeCount + pulsarPool.activeCount + aimedPool.activeCount
    }
}

