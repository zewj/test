import SpriteKit
import UIKit

/// The whole game lives in this scene. Every sprite is drawn procedurally so
/// the project needs no image assets.
final class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Tuning

    private enum Tuning {
        static let gravity: CGFloat = -11          // metres / s², SpriteKit units
        static let flapVelocity: CGFloat = 480     // points / s
        static let maxFallSpeed: CGFloat = 900     // points / s
        static let basePipeSpeed: CGFloat = 170    // points / s
        static let pipeSpacing: TimeInterval = 1.35
        static let pipeWidth: CGFloat = 66
        static let pipeGap: CGFloat = 175
        static let groundHeight: CGFloat = 112
        static let birdRadius: CGFloat = 17
    }

    private enum Category {
        static let bird: UInt32 = 1 << 0
        static let pipe: UInt32 = 1 << 1
        static let ground: UInt32 = 1 << 2
        static let score: UInt32 = 1 << 3
    }

    private enum Layer {
        static let clouds: CGFloat = 1
        static let hills: CGFloat = 2
        static let pipes: CGFloat = 3
        static let ground: CGFloat = 4
        static let bird: CGFloat = 5
        static let flash: CGFloat = 10
    }

    private enum Palette {
        static let sky = SKColor(red: 0.44, green: 0.78, blue: 0.91, alpha: 1)
        static let outline = SKColor(red: 0.20, green: 0.16, blue: 0.10, alpha: 1)
        static let birdBody = SKColor(red: 0.98, green: 0.80, blue: 0.20, alpha: 1)
        static let birdBelly = SKColor(red: 1.00, green: 0.93, blue: 0.55, alpha: 1)
        static let beak = SKColor(red: 0.96, green: 0.45, blue: 0.16, alpha: 1)
        static let pipe = SKColor(red: 0.45, green: 0.78, blue: 0.28, alpha: 1)
        static let pipeLight = SKColor(red: 0.66, green: 0.90, blue: 0.45, alpha: 1)
        static let pipeDark = SKColor(red: 0.32, green: 0.60, blue: 0.20, alpha: 1)
        static let dirt = SKColor(red: 0.87, green: 0.75, blue: 0.47, alpha: 1)
        static let grass = SKColor(red: 0.47, green: 0.82, blue: 0.32, alpha: 1)
        static let grassDark = SKColor(red: 0.38, green: 0.70, blue: 0.25, alpha: 1)
        static let hills = SKColor(red: 0.62, green: 0.88, blue: 0.62, alpha: 1)
    }

    // MARK: - State

    private let state: GameState

    private var bird = SKNode()
    private var wingPivot = SKNode()
    private var pipeLayer = SKNode()
    private var groundStrips: [SKNode] = []
    private var clouds: [SKNode] = []

    private var groundTop: CGFloat { Tuning.groundHeight }
    private var pipeSpeed: CGFloat = Tuning.basePipeSpeed
    private var lastUpdateTime: TimeInterval = 0
    private var spawnTimer: TimeInterval = 0
    private var hasBuiltScene = false
    /// Incremented on every restart or death so stale delayed work can bail out.
    private var generation = 0

    private let flapHaptic = UIImpactFeedbackGenerator(style: .light)
    private let scoreHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let crashHaptic = UIImpactFeedbackGenerator(style: .heavy)

    // MARK: - Lifecycle

    init(state: GameState) {
        self.state = state
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = Palette.sky
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMove(to view: SKView) {
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: Tuning.gravity)
        flapHaptic.prepare()
        buildScene()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // Rebuild the static layout if the view is resized while not mid-round.
        guard hasBuiltScene, oldSize != size, state.phase != .playing, state.phase != .dying else { return }
        buildScene()
    }

    /// Public entry point used by the SwiftUI "Play Again" button.
    func restart() {
        generation += 1
        state.reset()
        buildScene()
    }

    // MARK: - Scene construction

    private func buildScene() {
        removeAllChildren()
        removeAllActions()
        groundStrips = []
        clouds = []

        addClouds()
        addHills()
        addGround()

        pipeLayer = SKNode()
        pipeLayer.zPosition = Layer.pipes
        addChild(pipeLayer)

        addBird()

        hasBuiltScene = true
        enterReady()
    }

    private func addClouds() {
        for index in 0..<6 {
            let scale = CGFloat.random(in: 0.7...1.3)
            let cloud = makeCloud()
            cloud.setScale(scale)
            cloud.alpha = 0.92
            cloud.zPosition = Layer.clouds

            let cloudWidth: CGFloat = 130 * scale
            let y = CGFloat.random(in: (size.height * 0.55)...(size.height * 0.92))
            let startX = CGFloat(index) * (size.width / 5) + CGFloat.random(in: -30...30)
            cloud.position = CGPoint(x: startX, y: y)

            // Bigger clouds read as closer, so they drift a little faster.
            let speed: CGFloat = 16 * scale
            let firstLeg = SKAction.moveTo(x: -cloudWidth, duration: Double((startX + cloudWidth) / speed))
            let jumpBack = SKAction.moveTo(x: size.width + cloudWidth, duration: 0)
            let fullLeg = SKAction.moveTo(x: -cloudWidth, duration: Double((size.width + 2 * cloudWidth) / speed))
            cloud.run(.sequence([firstLeg, jumpBack, .repeatForever(.sequence([fullLeg, jumpBack]))]))

            addChild(cloud)
            clouds.append(cloud)
        }
    }

    private func makeCloud() -> SKNode {
        let node = SKNode()
        let puffs: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
            (0, 0, 26), (-28, -4, 20), (26, -2,22), (8, 14, 20), (-12, 12, 18),
        ]
        for puff in puffs {
            let circle = SKShapeNode(circleOfRadius: puff.r)
            circle.fillColor = .white
            circle.strokeColor = .clear
            circle.position = CGPoint(x: puff.x, y: puff.y)
            node.addChild(circle)
        }
        return node
    }

    private func addHills() {
        var x: CGFloat = -40
        while x < size.width + 40 {
            let radius = CGFloat.random(in: 50...110)
            let hill = SKShapeNode(circleOfRadius: radius)
            hill.fillColor = Palette.hills
            hill.strokeColor = .clear
            hill.position = CGPoint(x: x, y: groundTop - radius * 0.55)
            hill.zPosition = Layer.hills
            addChild(hill)
            x += radius * CGFloat.random(in: 0.9...1.3)
        }
    }

    private func addGround() {
        let stripeStep: CGFloat = 24
        let stripWidth = (size.width / stripeStep).rounded(.up) * stripeStep
        let grassHeight: CGFloat = 22

        for index in 0..<2 {
            let strip = SKNode()

            let dirt = SKSpriteNode(color: Palette.dirt, size: CGSize(width: stripWidth + 1, height: groundTop))
            dirt.anchorPoint = .zero
            strip.addChild(dirt)

            let grass = SKSpriteNode(color: Palette.grass, size: CGSize(width: stripWidth + 1, height: grassHeight))
            grass.anchorPoint = .zero
            grass.position = CGPoint(x: 0, y: groundTop - grassHeight)
            strip.addChild(grass)

            var x: CGFloat = 0
            while x < stripWidth {
                let stripe = SKSpriteNode(color: Palette.grassDark, size: CGSize(width: stripeStep / 2, height: grassHeight))
                stripe.anchorPoint = .zero
                stripe.position = CGPoint(x: x, y: groundTop - grassHeight)
                strip.addChild(stripe)
                x += stripeStep
            }

            let edge = SKSpriteNode(color: Palette.outline, size: CGSize(width: stripWidth + 1, height: 3))
            edge.anchorPoint = .zero
            edge.position = CGPoint(x: 0, y: groundTop - 3)
            strip.addChild(edge)

            strip.position = CGPoint(x: CGFloat(index) * stripWidth, y: 0)
            strip.zPosition = Layer.ground
            addChild(strip)
            groundStrips.append(strip)

            let scroll = SKAction.sequence([
                .moveBy(x: -stripWidth, y: 0, duration: Double(stripWidth / Tuning.basePipeSpeed)),
                .moveBy(x: stripWidth, y: 0, duration: 0),
            ])
            strip.run(.repeatForever(scroll), withKey: "scroll")
        }

        let floor = SKNode()
        let body = SKPhysicsBody(edgeFrom: CGPoint(x: -200, y: groundTop), to: CGPoint(x: size.width + 200, y: groundTop))
        body.categoryBitMask = Category.ground
        body.contactTestBitMask = Category.bird
        body.collisionBitMask = Category.bird
        body.friction = 1
        floor.physicsBody = body
        addChild(floor)
    }

    private func addBird() {
        let node = SKNode()
        let radius = Tuning.birdRadius

        let body = SKShapeNode(circleOfRadius: radius)
        body.fillColor = Palette.birdBody
        body.strokeColor = Palette.outline
        body.lineWidth = 2
        node.addChild(body)

        let belly = SKShapeNode(ellipseOf: CGSize(width: 22, height: 14))
        belly.fillColor = Palette.birdBelly
        belly.strokeColor = .clear
        belly.position = CGPoint(x: 0, y: -7)
        node.addChild(belly)

        let pivot = SKNode()
        pivot.position = CGPoint(x: -2, y: -1)
        let wing = SKShapeNode(ellipseOf: CGSize(width: 18, height: 10))
        wing.fillColor = Palette.birdBelly
        wing.strokeColor = Palette.outline
        wing.lineWidth = 1.5
        wing.position = CGPoint(x: -7, y: 0)
        pivot.addChild(wing)
        node.addChild(pivot)

        let eye = SKShapeNode(circleOfRadius: 6)
        eye.fillColor = .white
        eye.strokeColor = Palette.outline
        eye.lineWidth = 1.5
        eye.position = CGPoint(x: 7, y: 5)
        node.addChild(eye)

        let pupil = SKShapeNode(circleOfRadius: 2.5)
        pupil.fillColor = Palette.outline
        pupil.strokeColor = .clear
        pupil.position = CGPoint(x: 9, y: 5)
        node.addChild(pupil)

        let beakPath = CGMutablePath()
        beakPath.move(to: CGPoint(x: 12, y: 4))
        beakPath.addLine(to: CGPoint(x: 26, y: 0))
        beakPath.addLine(to: CGPoint(x: 12, y: -4))
        beakPath.closeSubpath()
        let beak = SKShapeNode(path: beakPath)
        beak.fillColor = Palette.beak
        beak.strokeColor = Palette.outline
        beak.lineWidth = 1.5
        beak.lineJoin = .round
        node.addChild(beak)

        let physics = SKPhysicsBody(circleOfRadius: radius - 2)
        physics.categoryBitMask = Category.bird
        physics.contactTestBitMask = Category.pipe | Category.ground | Category.score
        physics.collisionBitMask = Category.ground | Category.pipe
        physics.allowsRotation = false
        physics.restitution = 0
        physics.linearDamping = 0
        node.physicsBody = physics

        node.zPosition = Layer.bird
        node.position = birdHome
        addChild(node)

        bird = node
        wingPivot = pivot
    }

    private var birdHome: CGPoint {
        CGPoint(x: size.width * 0.3, y: groundTop + (size.height - groundTop) * 0.55)
    }

    // MARK: - Phases

    private func enterReady() {
        pipeSpeed = Tuning.basePipeSpeed
        spawnTimer = 0
        lastUpdateTime = 0
        setScrollSpeed(1)

        bird.position = birdHome
        bird.zRotation = 0
        bird.physicsBody?.velocity = .zero
        bird.physicsBody?.affectedByGravity = false
        bird.physicsBody?.contactTestBitMask = Category.pipe | Category.ground | Category.score

        let bob = SKAction.sequence([
            .moveBy(x: 0, y: 8, duration: 0.4),
            .moveBy(x: 0, y: -8, duration: 0.4),
        ])
        bob.timingMode = .easeInEaseOut
        bird.run(.repeatForever(bob), withKey: "bob")
        startWingFlap()
    }

    private func startPlaying() {
        state.phase = .playing
        bird.removeAction(forKey: "bob")
        bird.physicsBody?.affectedByGravity = true
        spawnTimer = Tuning.pipeSpacing - 0.5
        flap()
    }

    private func flap() {
        bird.physicsBody?.velocity = CGVector(dx: 0, dy: Tuning.flapVelocity)
        flapHaptic.impactOccurred(intensity: 0.7)
    }

    private func die() {
        guard state.phase == .playing else { return }
        state.phase = .dying
        generation += 1
        let myGeneration = generation

        crashHaptic.impactOccurred()
        setScrollSpeed(0)
        wingPivot.removeAction(forKey: "flap")
        bird.physicsBody?.velocity = .zero
        bird.physicsBody?.contactTestBitMask = Category.ground
        showFlash()

        // Finish the round once the bird lands, or after a short timeout if it
        // gets wedged somewhere and never touches the ground.
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard myGeneration == generation else { return }
            state.finishRound()
        }
    }

    private func setScrollSpeed(_ multiplier: CGFloat) {
        for strip in groundStrips { strip.speed = multiplier }
        for cloud in clouds { cloud.speed = multiplier }
    }

    private func startWingFlap() {
        let up = SKAction.rotate(toAngle: 0.55, duration: 0.11)
        let down = SKAction.rotate(toAngle: -0.35, duration: 0.11)
        up.timingMode = .easeOut
        down.timingMode = .easeIn
        wingPivot.run(.repeatForever(.sequence([up, down])), withKey: "flap")
    }

    private func showFlash() {
        let flash = SKSpriteNode(color: .white, size: size)
        flash.anchorPoint = .zero
        flash.alpha = 0
        flash.zPosition = Layer.flash
        addChild(flash)
        flash.run(.sequence([
            .fadeAlpha(to: 0.85, duration: 0.05),
            .fadeOut(withDuration: 0.25),
            .removeFromParent(),
        ]))
    }

    // MARK: - Pipes

    private func spawnPipePair() {
        let gap = Tuning.pipeGap
        let minCenter = groundTop + gap / 2 + 60
        let maxCenter = size.height - gap / 2 - 90
        let centerY = CGFloat.random(in: minCenter...max(minCenter, maxCenter))

        let pair = SKNode()
        pair.name = "pipe"
        pair.position = CGPoint(x: size.width + Tuning.pipeWidth, y: 0)

        let topHeight = size.height - (centerY + gap / 2) + 40
        let top = makePipe(height: topHeight, capAtBottom: true)
        top.position = CGPoint(x: 0, y: centerY + gap / 2)
        pair.addChild(top)

        let bottomHeight = centerY - gap / 2 - groundTop
        let bottom = makePipe(height: bottomHeight, capAtBottom: false)
        bottom.position = CGPoint(x: 0, y: groundTop)
        pair.addChild(bottom)

        let gate = SKNode()
        gate.name = "gate"
        gate.position = CGPoint(x: Tuning.pipeWidth / 2 + 4, y: centerY)
        let gateBody = SKPhysicsBody(rectangleOf: CGSize(width: 4, height: gap))
        gateBody.isDynamic = false
        gateBody.categoryBitMask = Category.score
        gateBody.contactTestBitMask = Category.bird
        gateBody.collisionBitMask = 0
        gate.physicsBody = gateBody
        pair.addChild(gate)

        pipeLayer.addChild(pair)
    }

    /// Builds a pipe anchored at its base (bottom centre) extending `height` upward.
    private func makePipe(height: CGFloat, capAtBottom: Bool) -> SKNode {
        let node = SKNode()
        let width = Tuning.pipeWidth
        let capHeight: CGFloat = 26
        let capWidth = width + 8

        let body = SKShapeNode(rect: CGRect(x: -width / 2, y: 0, width: width, height: height))
        body.fillColor = Palette.pipe
        body.strokeColor = Palette.outline
        body.lineWidth = 2
        node.addChild(body)

        let highlight = SKSpriteNode(color: Palette.pipeLight, size: CGSize(width: 10, height: height - 4))
        highlight.anchorPoint = CGPoint(x: 0.5, y: 0)
        highlight.position = CGPoint(x: -width / 2 + 12, y: 2)
        node.addChild(highlight)

        let shade = SKSpriteNode(color: Palette.pipeDark, size: CGSize(width: 8, height: height - 4))
        shade.anchorPoint = CGPoint(x: 0.5, y: 0)
        shade.position = CGPoint(x: width / 2 - 8, y: 2)
        node.addChild(shade)

        let capY = capAtBottom ? 0 : height - capHeight
        let cap = SKShapeNode(rect: CGRect(x: -capWidth / 2, y: capY, width: capWidth, height: capHeight))
        cap.fillColor = Palette.pipe
        cap.strokeColor = Palette.outline
        cap.lineWidth = 2
        node.addChild(cap)

        let capHighlight = SKSpriteNode(color: Palette.pipeLight, size: CGSize(width: 10, height: capHeight - 4))
        capHighlight.anchorPoint = CGPoint(x: 0.5, y: 0)
        capHighlight.position = CGPoint(x: -capWidth / 2 + 12, y: capY + 2)
        node.addChild(capHighlight)

        let physics = SKPhysicsBody(rectangleOf: CGSize(width: capWidth, height: height), center: CGPoint(x: 0, y: height / 2))
        physics.isDynamic = false
        physics.categoryBitMask = Category.pipe
        physics.contactTestBitMask = Category.bird
        physics.collisionBitMask = Category.bird
        physics.friction = 0
        node.physicsBody = physics

        return node
    }

    private func movePipes(by dt: CGFloat) {
        let removeX = -Tuning.pipeWidth - 30
        for pair in pipeLayer.children {
            pair.position.x -= pipeSpeed * dt
            if pair.position.x < removeX {
                pair.removeFromParent()
            }
        }
    }

    // MARK: - Frame update

    override func update(_ currentTime: TimeInterval) {
        let dt: CGFloat
        if lastUpdateTime == 0 {
            dt = 0
        } else {
            dt = CGFloat(min(currentTime - lastUpdateTime, 1.0 / 30.0))
        }
        lastUpdateTime = currentTime

        switch state.phase {
        case .ready, .gameOver:
            break
        case .playing:
            spawnTimer += Double(dt)
            if spawnTimer >= Tuning.pipeSpacing {
                spawnTimer -= Tuning.pipeSpacing
                spawnPipePair()
            }
            movePipes(by: dt)
            constrainAndTiltBird(dt: dt)
        case .dying:
            constrainAndTiltBird(dt: dt)
        }
    }

    private func constrainAndTiltBird(dt: CGFloat) {
        guard let physics = bird.physicsBody else { return }

        if physics.velocity.dy < -Tuning.maxFallSpeed {
            physics.velocity.dy = -Tuning.maxFallSpeed
        }

        let ceiling = size.height - Tuning.birdRadius
        if bird.position.y > ceiling {
            bird.position.y = ceiling
            if physics.velocity.dy > 0 { physics.velocity.dy = 0 }
        }

        // Nose up briefly after a flap, then pitch down as the bird falls.
        let target = min(0.4, max(-1.45, physics.velocity.dy / 520))
        let blend = min(1, dt * 12)
        bird.zRotation += (target - bird.zRotation) * blend
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch state.phase {
        case .ready:
            startPlaying()
        case .playing:
            flap()
        case .dying:
            break
        case .gameOver:
            restart()
        }
    }

    // MARK: - Contacts

    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        MainActor.assumeIsolated {
            handleContact(contact)
        }
    }

    private func handleContact(_ contact: SKPhysicsContact) {
        let mask = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        guard mask & Category.bird != 0 else { return }

        if mask & Category.score != 0 {
            guard state.phase == .playing else { return }
            let gate = contact.bodyA.categoryBitMask == Category.score ? contact.bodyA.node : contact.bodyB.node
            gate?.removeFromParent()
            state.addPoint()
            scoreHaptic.impactOccurred()
            pipeSpeed = Tuning.basePipeSpeed + min(CGFloat(state.score), 40) * 1.5
            setScrollSpeed(pipeSpeed / Tuning.basePipeSpeed)
            return
        }

        if mask & (Category.pipe | Category.ground) != 0 {
            switch state.phase {
            case .playing:
                die()
            case .dying where mask & Category.ground != 0:
                bird.physicsBody?.velocity = .zero
                state.finishRound()
            default:
                break
            }
        }
    }
}
