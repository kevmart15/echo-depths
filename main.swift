// Echo Depths - A sonar-based deep-sea exploration game
// Single-file SpriteKit game for macOS 10.15+ / Swift 5.3.2
// Build: swiftc main.swift -o EchoDepths -framework AppKit -framework SpriteKit -O

import AppKit
import SpriteKit

// MARK: - Constants

let WINDOW_W: CGFloat = 1200
let WINDOW_H: CGFloat = 800
let GRID_W = 120
let GRID_H = 80
let CELL_SIZE: CGFloat = 24
let WORLD_W: CGFloat = CGFloat(GRID_W) * CELL_SIZE
let WORLD_H: CGFloat = CGFloat(GRID_H) * CELL_SIZE

let SUB_SPEED: CGFloat = 150
let SUB_SILENT_SPEED: CGFloat = 75
let SUB_GLOW_RADIUS: CGFloat = 40
let SONAR_SPEED: CGFloat = 400
let SONAR_MAX_RADIUS: CGFloat = 350
let SONAR_COOLDOWN: Double = 1.5
let REVEAL_DURATION: CGFloat = 3.5
let MAX_HULL: CGFloat = 100
let MAX_OXYGEN: CGFloat = 120
let SPECIMENS_PER_LEVEL = 5
let TOTAL_DEPTHS = 3

// Colors
let COLOR_BG = NSColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 1.0)
let COLOR_CYAN = NSColor(red: 0.0, green: 0.85, blue: 0.9, alpha: 1.0)
let COLOR_TEAL = NSColor(red: 0.0, green: 0.7, blue: 0.75, alpha: 1.0)
let COLOR_SUB_GLOW = NSColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 0.15)
let COLOR_WALL = NSColor(red: 0.0, green: 0.6, blue: 0.7, alpha: 1.0)
let COLOR_WALL_DIM = NSColor(red: 0.0, green: 0.2, blue: 0.25, alpha: 1.0)
let COLOR_CREATURE_ANGLER = NSColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1.0)
let COLOR_CREATURE_JELLY = NSColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1.0)
let COLOR_CREATURE_LEVIATHAN = NSColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1.0)
let COLOR_SPECIMEN = NSColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1.0)
let COLOR_AIR_POCKET = NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.5)
let COLOR_HUD_BG = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5)
let COLOR_HP_BAR = NSColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)
let COLOR_OXY_BAR = NSColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0)
let COLOR_DANGER = NSColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1.0)

// MARK: - Texture Helpers

func makeTexture(width: Int, height: Int, draw: (CGContext) -> Void) -> SKTexture {
    let img = NSImage(size: NSSize(width: width, height: height))
    img.lockFocus()
    if let ctx = NSGraphicsContext.current?.cgContext {
        draw(ctx)
    }
    img.unlockFocus()
    return SKTexture(image: img)
}

func makeSubTexture() -> SKTexture {
    return makeTexture(width: 36, height: 24) { ctx in
        // Body
        ctx.setFillColor(NSColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0).cgColor)
        ctx.fillEllipse(in: CGRect(x: 4, y: 4, width: 28, height: 16))
        // Viewport
        ctx.setFillColor(NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.8).cgColor)
        ctx.fillEllipse(in: CGRect(x: 24, y: 8, width: 8, height: 8))
        // Propeller
        ctx.setFillColor(NSColor(red: 0.3, green: 0.4, blue: 0.5, alpha: 1.0).cgColor)
        ctx.fill(CGRect(x: 0, y: 2, width: 6, height: 4))
        ctx.fill(CGRect(x: 0, y: 18, width: 6, height: 4))
    }
}

func makeGlowTexture(radius: Int, color: NSColor) -> SKTexture {
    let size = radius * 2
    return makeTexture(width: size, height: size) { ctx in
        let center = CGPoint(x: radius, y: radius)
        let r = CGFloat(radius)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var red: CGFloat = 0; var green: CGFloat = 0; var blue: CGFloat = 0; var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let colors = [
            CGColor(colorSpace: colorSpace, components: [red, green, blue, alpha])!,
            CGColor(colorSpace: colorSpace, components: [red, green, blue, 0.0])!
        ]
        let locations: [CGFloat] = [0.0, 1.0]
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) {
            ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: r, options: .drawsAfterEndLocation)
        }
    }
}

func makeWallTexture() -> SKTexture {
    return makeTexture(width: 8, height: 8) { ctx in
        ctx.setFillColor(COLOR_WALL.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        ctx.setFillColor(COLOR_WALL_DIM.cgColor)
        ctx.fill(CGRect(x: 1, y: 1, width: 6, height: 6))
    }
}

func makeCreatureTexture(color: NSColor, size: Int) -> SKTexture {
    return makeTexture(width: size, height: size) { ctx in
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: size - 4, height: size - 4))
        ctx.setFillColor(color.withAlphaComponent(0.5).cgColor)
        ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
    }
}

func makeSpecimenTexture() -> SKTexture {
    return makeTexture(width: 12, height: 12) { ctx in
        ctx.setFillColor(COLOR_SPECIMEN.cgColor)
        // Diamond shape
        ctx.move(to: CGPoint(x: 6, y: 0))
        ctx.addLine(to: CGPoint(x: 12, y: 6))
        ctx.addLine(to: CGPoint(x: 6, y: 12))
        ctx.addLine(to: CGPoint(x: 0, y: 6))
        ctx.closePath()
        ctx.fillPath()
        ctx.setFillColor(NSColor(red: 0.5, green: 1.0, blue: 0.6, alpha: 0.7).cgColor)
        ctx.fillEllipse(in: CGRect(x: 3, y: 3, width: 6, height: 6))
    }
}

func makeParticleTexture() -> SKTexture {
    return makeTexture(width: 4, height: 4) { ctx in
        ctx.setFillColor(NSColor(red: 0.5, green: 0.7, blue: 0.9, alpha: 0.6).cgColor)
        ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: 4, height: 4))
    }
}

func makeSonarRingTexture() -> SKTexture {
    return makeTexture(width: 64, height: 64) { ctx in
        ctx.setStrokeColor(COLOR_CYAN.cgColor)
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: CGRect(x: 2, y: 2, width: 60, height: 60))
    }
}

// MARK: - Cave Generator

struct CaveCell {
    var isWall: Bool
    var revealTimer: CGFloat = 0
    var isAirPocket: Bool = false
    var isExit: Bool = false
}

func generateCave(depth: Int) -> [[CaveCell]] {
    var grid = [[CaveCell]](repeating: [CaveCell](repeating: CaveCell(isWall: false), count: GRID_W), count: GRID_H)
    let fillChance: Double = 0.44 + Double(depth) * 0.02

    // Random fill
    for y in 0..<GRID_H {
        for x in 0..<GRID_W {
            if x == 0 || x == GRID_W - 1 || y == 0 || y == GRID_H - 1 {
                grid[y][x].isWall = true
            } else {
                grid[y][x].isWall = Double.random(in: 0...1) < fillChance
            }
        }
    }

    // Carve a start area (top center)
    let startX = GRID_W / 2
    let startY = GRID_H - 5
    for dy in -3...3 {
        for dx in -3...3 {
            let nx = startX + dx
            let ny = startY + dy
            if nx > 0 && nx < GRID_W - 1 && ny > 0 && ny < GRID_H - 1 {
                grid[ny][nx].isWall = false
            }
        }
    }

    // Cellular automata smoothing (5 passes)
    for _ in 0..<5 {
        var newGrid = grid
        for y in 1..<(GRID_H - 1) {
            for x in 1..<(GRID_W - 1) {
                var wallCount = 0
                for dy in -1...1 {
                    for dx in -1...1 {
                        if grid[y + dy][x + dx].isWall { wallCount += 1 }
                    }
                }
                newGrid[y][x].isWall = wallCount >= 5
            }
        }
        grid = newGrid
    }

    // Ensure start area is open
    for dy in -2...2 {
        for dx in -2...2 {
            let nx = startX + dx
            let ny = startY + dy
            if nx > 0 && nx < GRID_W - 1 && ny > 0 && ny < GRID_H - 1 {
                grid[ny][nx].isWall = false
            }
        }
    }

    // Place air pockets (3-5 per level, open spots near top half)
    let airPocketCount = Int.random(in: 3...5)
    var airPocketsPlaced = 0
    var attempts = 0
    while airPocketsPlaced < airPocketCount && attempts < 500 {
        let ax = Int.random(in: 5..<(GRID_W - 5))
        let ay = Int.random(in: GRID_H / 2..<(GRID_H - 5))
        if !grid[ay][ax].isWall {
            // Carve out air pocket area
            for dy in -1...1 {
                for dx in -1...1 {
                    let nx = ax + dx
                    let ny = ay + dy
                    if nx > 0 && nx < GRID_W - 1 && ny > 0 && ny < GRID_H - 1 {
                        grid[ny][nx].isWall = false
                        grid[ny][nx].isAirPocket = true
                    }
                }
            }
            airPocketsPlaced += 1
        }
        attempts += 1
    }

    // Place exit at bottom area
    var exitPlaced = false
    attempts = 0
    while !exitPlaced && attempts < 500 {
        let ex = Int.random(in: 10..<(GRID_W - 10))
        let ey = Int.random(in: 3...8)
        if !grid[ey][ex].isWall {
            grid[ey][ex].isExit = true
            // Carve around exit
            for dy in -1...1 {
                for dx in -1...1 {
                    let nx = ex + dx
                    let ny = ey + dy
                    if nx > 0 && nx < GRID_W - 1 && ny > 0 && ny < GRID_H - 1 {
                        grid[ny][nx].isWall = false
                    }
                }
            }
            exitPlaced = true
        }
        attempts += 1
    }
    if !exitPlaced {
        grid[5][GRID_W / 2].isWall = false
        grid[5][GRID_W / 2].isExit = true
    }

    // Flood fill connectivity from start — carve tunnels to disconnected areas
    var visited = [[Bool]](repeating: [Bool](repeating: false, count: GRID_W), count: GRID_H)
    var stack: [(Int, Int)] = [(startX, startY)]
    visited[startY][startX] = true
    while !stack.isEmpty {
        let (cx, cy) = stack.removeLast()
        for (ddx, ddy) in [(1,0),(-1,0),(0,1),(0,-1)] {
            let nx2 = cx + ddx
            let ny2 = cy + ddy
            if nx2 > 0 && nx2 < GRID_W - 1 && ny2 > 0 && ny2 < GRID_H - 1 && !visited[ny2][nx2] && !grid[ny2][nx2].isWall {
                visited[ny2][nx2] = true
                stack.append((nx2, ny2))
            }
        }
    }

    // Find unreachable open cells and tunnel to them
    for y in 2..<(GRID_H - 2) {
        for x in 2..<(GRID_W - 2) {
            if !grid[y][x].isWall && !visited[y][x] {
                // Carve a tunnel toward start
                var tx = x; var ty = y
                var tunnelSteps = 0
                while !visited[ty][tx] && tunnelSteps < 200 {
                    if tx < startX { tx += 1 } else if tx > startX { tx -= 1 }
                    if ty < startY { ty += 1 } else if ty > startY { ty -= 1 }
                    if tx > 0 && tx < GRID_W - 1 && ty > 0 && ty < GRID_H - 1 {
                        grid[ty][tx].isWall = false
                        if visited[ty][tx] {
                            // Re-flood from this connection
                            var stack2: [(Int, Int)] = [(tx, ty)]
                            while !stack2.isEmpty {
                                let (cx2, cy2) = stack2.removeLast()
                                for (ddx2, ddy2) in [(1,0),(-1,0),(0,1),(0,-1)] {
                                    let nx3 = cx2 + ddx2
                                    let ny3 = cy2 + ddy2
                                    if nx3 > 0 && nx3 < GRID_W - 1 && ny3 > 0 && ny3 < GRID_H - 1 && !visited[ny3][nx3] && !grid[ny3][nx3].isWall {
                                        visited[ny3][nx3] = true
                                        stack2.append((nx3, ny3))
                                    }
                                }
                            }
                            break
                        }
                    }
                    tunnelSteps += 1
                }
            }
        }
    }

    return grid
}

// MARK: - Creature Types

enum CreatureType {
    case anglerfish
    case jellyfish
    case leviathan
}

// MARK: - Game State

enum GameState {
    case menu
    case playing
    case dead
    case victory
}

// MARK: - Creature Node

class CreatureNode: SKSpriteNode {
    var creatureType: CreatureType
    var hp: CGFloat
    var maxHp: CGFloat
    var moveSpeed: CGFloat
    var damage: CGFloat
    var patrolTarget: CGPoint?
    var alertedToPing: Bool = false
    var pingTarget: CGPoint = .zero
    var alertTimer: CGFloat = 0
    var glowNode: SKSpriteNode?
    var contactCooldown: CGFloat = 0

    init(type: CreatureType, position pos: CGPoint) {
        self.creatureType = type
        switch type {
        case .anglerfish:
            hp = 30; maxHp = 30; moveSpeed = 60; damage = 10
        case .jellyfish:
            hp = 10; maxHp = 10; moveSpeed = 30; damage = 5
        case .leviathan:
            hp = 99999; maxHp = 99999; moveSpeed = 120; damage = 30
        }
        let tex: SKTexture
        let sz: CGSize
        switch type {
        case .anglerfish:
            tex = makeCreatureTexture(color: COLOR_CREATURE_ANGLER, size: 16)
            sz = CGSize(width: 32, height: 32)
        case .jellyfish:
            tex = makeCreatureTexture(color: COLOR_CREATURE_JELLY, size: 12)
            sz = CGSize(width: 24, height: 24)
        case .leviathan:
            tex = makeCreatureTexture(color: COLOR_CREATURE_LEVIATHAN, size: 24)
            sz = CGSize(width: 56, height: 56)
        }
        super.init(texture: tex, color: .clear, size: sz)
        self.position = pos
        self.zPosition = 20

        // Creature glow
        let glowColor: NSColor
        let glowSize: Int
        switch type {
        case .anglerfish: glowColor = COLOR_CREATURE_ANGLER.withAlphaComponent(0.12); glowSize = 24
        case .jellyfish: glowColor = COLOR_CREATURE_JELLY.withAlphaComponent(0.1); glowSize = 18
        case .leviathan: glowColor = COLOR_CREATURE_LEVIATHAN.withAlphaComponent(0.15); glowSize = 40
        }
        let glow = SKSpriteNode(texture: makeGlowTexture(radius: glowSize, color: glowColor))
        glow.size = CGSize(width: CGFloat(glowSize) * 2, height: CGFloat(glowSize) * 2)
        glow.zPosition = -1
        glow.alpha = 1.0
        self.addChild(glow)
        self.glowNode = glow
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(dt: CGFloat, subPos: CGPoint, grid: [[CaveCell]], isSilent: Bool) {
        contactCooldown = max(0, contactCooldown - dt)

        if alertedToPing {
            alertTimer -= dt
            if alertTimer <= 0 {
                alertedToPing = false
            }
            // Move toward ping
            let dx = pingTarget.x - position.x
            let dy = pingTarget.y - position.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist > 5 {
                let chargeSpeed = creatureType == .leviathan ? moveSpeed * 1.5 : moveSpeed * 1.2
                let vx = (dx / dist) * chargeSpeed * dt
                let vy = (dy / dist) * chargeSpeed * dt
                let newPos = CGPoint(x: position.x + vx, y: position.y + vy)
                if !isWallAt(pos: newPos, grid: grid) {
                    position = newPos
                }
            }
            return
        }

        // Patrol
        if creatureType == .jellyfish {
            // Drift randomly
            if patrolTarget == nil || distTo(patrolTarget!) < 20 {
                let rx = position.x + CGFloat.random(in: -150...150)
                let ry = position.y + CGFloat.random(in: -150...150)
                patrolTarget = CGPoint(x: rx, y: ry)
            }
        } else {
            // Anglerfish and Leviathan patrol
            if patrolTarget == nil || distTo(patrolTarget!) < 20 {
                let rx = position.x + CGFloat.random(in: -200...200)
                let ry = position.y + CGFloat.random(in: -200...200)
                patrolTarget = CGPoint(x: rx, y: ry)
            }

            // If close to sub and sub is not silent, alert
            let distToSub = distTo(subPos)
            if distToSub < 120 && !isSilent {
                alertedToPing = true
                pingTarget = subPos
                alertTimer = 3.0
                return
            }
        }

        if let target = patrolTarget {
            let dx = target.x - position.x
            let dy = target.y - position.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist > 1 {
                let vx = (dx / dist) * moveSpeed * dt
                let vy = (dy / dist) * moveSpeed * dt
                let newPos = CGPoint(x: position.x + vx, y: position.y + vy)
                if !isWallAt(pos: newPos, grid: grid) {
                    position = newPos
                } else {
                    patrolTarget = nil
                }
            }
        }
    }

    func distTo(_ p: CGPoint) -> CGFloat {
        let dx = p.x - position.x
        let dy = p.y - position.y
        return sqrt(dx * dx + dy * dy)
    }

    func isWallAt(pos: CGPoint, grid: [[CaveCell]]) -> Bool {
        let gx = Int(pos.x / CELL_SIZE)
        let gy = Int(pos.y / CELL_SIZE)
        if gx < 0 || gx >= GRID_W || gy < 0 || gy >= GRID_H { return true }
        return grid[gy][gx].isWall
    }

    func alertToPing(at pos: CGPoint) {
        if creatureType == .jellyfish { return } // Jellyfish don't respond to pings
        let dist = distTo(pos)
        let alertRange: CGFloat = creatureType == .leviathan ? 500 : 350
        if dist < alertRange {
            alertedToPing = true
            pingTarget = pos
            alertTimer = creatureType == .leviathan ? 6.0 : 4.0
        }
    }
}

// MARK: - Specimen Node

class SpecimenNode: SKSpriteNode {
    var collected = false
    var glowNode: SKSpriteNode?

    init(position pos: CGPoint) {
        let tex = makeSpecimenTexture()
        super.init(texture: tex, color: .clear, size: CGSize(width: 18, height: 18))
        self.position = pos
        self.zPosition = 15

        let glow = SKSpriteNode(texture: makeGlowTexture(radius: 14, color: COLOR_SPECIMEN.withAlphaComponent(0.1)))
        glow.size = CGSize(width: 28, height: 28)
        glow.zPosition = -1
        self.addChild(glow)
        self.glowNode = glow

        // Gentle bob
        let moveUp = SKAction.moveBy(x: 0, y: 4, duration: Double(CGFloat.random(in: 1.5...2.5)))
        let moveDown = SKAction.moveBy(x: 0, y: -4, duration: Double(CGFloat.random(in: 1.5...2.5)))
        self.run(SKAction.repeatForever(SKAction.sequence([moveUp, moveDown])))
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Sonar Ring

class SonarRing: SKShapeNode {
    var currentRadius: CGFloat = 0
    var maxRadius: CGFloat = SONAR_MAX_RADIUS
    var origin: CGPoint

    init(origin: CGPoint) {
        self.origin = origin
        super.init()
        self.strokeColor = COLOR_CYAN
        self.fillColor = .clear
        self.lineWidth = 2.0
        self.zPosition = 50
        self.position = origin
        self.alpha = 0.9
        updatePath()
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateRing(dt: CGFloat) -> Bool {
        currentRadius += SONAR_SPEED * dt
        if currentRadius >= maxRadius {
            return true // done
        }
        let progress = currentRadius / maxRadius
        self.alpha = max(0, 0.9 - progress * 0.8)
        self.lineWidth = max(0.5, 2.0 - progress * 1.5)
        updatePath()
        return false
    }

    func updatePath() {
        let rect = CGRect(x: -currentRadius, y: -currentRadius, width: currentRadius * 2, height: currentRadius * 2)
        self.path = CGPath(ellipseIn: rect, transform: nil)
    }
}

// MARK: - GameScene

class GameScene: SKScene {
    var gameState: GameState = .menu
    var currentDepth = 1
    var grid: [[CaveCell]] = []
    var wallNodes: [[SKSpriteNode?]] = []
    var exitNode: SKSpriteNode?

    var submarine: SKSpriteNode!
    var subGlow: SKSpriteNode!
    var hullHP: CGFloat = MAX_HULL
    var oxygen: CGFloat = MAX_OXYGEN
    var specimensCollected = 0

    var sonarCooldown: CGFloat = 0
    var sonarRings: [SonarRing] = []

    var creatures: [CreatureNode] = []
    var specimens: [SpecimenNode] = []

    var keysPressed = Set<UInt16>()
    var isSilentRunning = false
    var mouseClicked = false

    var cameraNode: SKCameraNode!
    var hudNode: SKNode!
    var hpBar: SKSpriteNode!
    var hpBarBg: SKSpriteNode!
    var oxyBar: SKSpriteNode!
    var oxyBarBg: SKSpriteNode!
    var depthLabel: SKLabelNode!
    var specimenLabel: SKLabelNode!
    var silentLabel: SKLabelNode!
    var cooldownIndicator: SKShapeNode!
    var dangerOverlay: SKSpriteNode!

    var menuTitleLabel: SKLabelNode!
    var menuSubLabel: SKLabelNode!
    var menuInstructLabel: SKLabelNode!

    var wallTexture: SKTexture!
    var lastUpdate: TimeInterval = 0

    var damageFlashTimer: CGFloat = 0
    var damageFlash: SKSpriteNode!

    var bubbleEmitter: SKNode!
    var invulnTimer: CGFloat = 0

    override func didMove(to view: SKView) {
        backgroundColor = COLOR_BG
        wallTexture = makeWallTexture()

        cameraNode = SKCameraNode()
        self.camera = cameraNode
        addChild(cameraNode)

        setupHUD()
        showMenu()
    }

    // MARK: - Menu

    func showMenu() {
        gameState = .menu
        removeGameNodes()

        cameraNode.position = CGPoint(x: WINDOW_W / 2, y: WINDOW_H / 2)

        menuTitleLabel = SKLabelNode(text: "ECHO DEPTHS")
        menuTitleLabel.fontName = "Menlo-Bold"
        menuTitleLabel.fontSize = 48
        menuTitleLabel.fontColor = COLOR_CYAN
        menuTitleLabel.position = CGPoint(x: 0, y: 80)
        menuTitleLabel.zPosition = 100
        cameraNode.addChild(menuTitleLabel)

        menuSubLabel = SKLabelNode(text: "A Sonar Deep-Sea Exploration")
        menuSubLabel.fontName = "Menlo"
        menuSubLabel.fontSize = 18
        menuSubLabel.fontColor = COLOR_TEAL
        menuSubLabel.position = CGPoint(x: 0, y: 40)
        menuSubLabel.zPosition = 100
        cameraNode.addChild(menuSubLabel)

        menuInstructLabel = SKLabelNode(text: "Press ENTER to Dive")
        menuInstructLabel.fontName = "Menlo"
        menuInstructLabel.fontSize = 22
        menuInstructLabel.fontColor = NSColor.white
        menuInstructLabel.position = CGPoint(x: 0, y: -30)
        menuInstructLabel.zPosition = 100
        cameraNode.addChild(menuInstructLabel)

        let controlsText = "WASD/Arrows: Move  |  Space/Click: Sonar Ping  |  E: Collect  |  Shift: Silent Mode"
        let controlsLabel = SKLabelNode(text: controlsText)
        controlsLabel.fontName = "Menlo"
        controlsLabel.fontSize = 12
        controlsLabel.fontColor = COLOR_TEAL.withAlphaComponent(0.7)
        controlsLabel.position = CGPoint(x: 0, y: -80)
        controlsLabel.zPosition = 100
        controlsLabel.name = "controlsLabel"
        cameraNode.addChild(controlsLabel)

        // Pulse animation for instruction
        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: Double(1.0))
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: Double(1.0))
        menuInstructLabel.run(SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn])))
    }

    func showDeath() {
        gameState = .dead
        removeGameNodes()

        let title = SKLabelNode(text: "SUBMERSIBLE LOST")
        title.fontName = "Menlo-Bold"
        title.fontSize = 42
        title.fontColor = COLOR_DANGER
        title.position = CGPoint(x: 0, y: 50)
        title.zPosition = 100
        title.name = "deathTitle"
        cameraNode.addChild(title)

        let info = SKLabelNode(text: "Depth reached: \(currentDepth) / \(TOTAL_DEPTHS)")
        info.fontName = "Menlo"
        info.fontSize = 18
        info.fontColor = COLOR_TEAL
        info.position = CGPoint(x: 0, y: 10)
        info.zPosition = 100
        info.name = "deathInfo"
        cameraNode.addChild(info)

        let restart = SKLabelNode(text: "Press ENTER to Try Again")
        restart.fontName = "Menlo"
        restart.fontSize = 20
        restart.fontColor = NSColor.white
        restart.position = CGPoint(x: 0, y: -40)
        restart.zPosition = 100
        restart.name = "deathRestart"
        cameraNode.addChild(restart)

        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: Double(1.0))
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: Double(1.0))
        restart.run(SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn])))
    }

    func showVictory() {
        gameState = .victory
        removeGameNodes()

        let title = SKLabelNode(text: "EXPEDITION COMPLETE")
        title.fontName = "Menlo-Bold"
        title.fontSize = 42
        title.fontColor = COLOR_SPECIMEN
        title.position = CGPoint(x: 0, y: 50)
        title.zPosition = 100
        title.name = "victoryTitle"
        cameraNode.addChild(title)

        let info = SKLabelNode(text: "You explored all depths and survived!")
        info.fontName = "Menlo"
        info.fontSize = 18
        info.fontColor = COLOR_TEAL
        info.position = CGPoint(x: 0, y: 10)
        info.zPosition = 100
        info.name = "victoryInfo"
        cameraNode.addChild(info)

        let restart = SKLabelNode(text: "Press ENTER to Dive Again")
        restart.fontName = "Menlo"
        restart.fontSize = 20
        restart.fontColor = NSColor.white
        restart.position = CGPoint(x: 0, y: -40)
        restart.zPosition = 100
        restart.name = "victoryRestart"
        cameraNode.addChild(restart)

        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: Double(1.0))
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: Double(1.0))
        restart.run(SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn])))
    }

    func removeGameNodes() {
        // Remove everything from world, keep camera and HUD
        self.enumerateChildNodes(withName: "wall") { n, _ in n.removeFromParent() }
        self.enumerateChildNodes(withName: "exit") { n, _ in n.removeFromParent() }
        self.enumerateChildNodes(withName: "airPocket") { n, _ in n.removeFromParent() }
        submarine?.removeFromParent()
        subGlow?.removeFromParent()
        for c in creatures { c.removeFromParent() }
        creatures.removeAll()
        for s in specimens { s.removeFromParent() }
        specimens.removeAll()
        for r in sonarRings { r.removeFromParent() }
        sonarRings.removeAll()
        bubbleEmitter?.removeFromParent()
        damageFlash?.removeFromParent()
        wallNodes = []

        // Remove menu/death/victory labels
        cameraNode.childNode(withName: "controlsLabel")?.removeFromParent()
        cameraNode.childNode(withName: "deathTitle")?.removeFromParent()
        cameraNode.childNode(withName: "deathInfo")?.removeFromParent()
        cameraNode.childNode(withName: "deathRestart")?.removeFromParent()
        cameraNode.childNode(withName: "victoryTitle")?.removeFromParent()
        cameraNode.childNode(withName: "victoryInfo")?.removeFromParent()
        cameraNode.childNode(withName: "victoryRestart")?.removeFromParent()
        menuTitleLabel?.removeFromParent()
        menuSubLabel?.removeFromParent()
        menuInstructLabel?.removeFromParent()
    }

    // MARK: - Start Game

    func startGame() {
        currentDepth = 1
        hullHP = MAX_HULL
        oxygen = MAX_OXYGEN
        specimensCollected = 0
        loadLevel()
    }

    func loadLevel() {
        gameState = .playing
        removeGameNodes()
        sonarCooldown = 0
        invulnTimer = 2.0 // brief invulnerability on level start

        // Generate cave
        grid = generateCave(depth: currentDepth)

        // Build wall nodes
        wallNodes = [[SKSpriteNode?]](repeating: [SKSpriteNode?](repeating: nil, count: GRID_W), count: GRID_H)
        for y in 0..<GRID_H {
            for x in 0..<GRID_W {
                if grid[y][x].isWall {
                    let node = SKSpriteNode(texture: wallTexture)
                    node.size = CGSize(width: CELL_SIZE, height: CELL_SIZE)
                    node.position = CGPoint(x: CGFloat(x) * CELL_SIZE + CELL_SIZE / 2,
                                            y: CGFloat(y) * CELL_SIZE + CELL_SIZE / 2)
                    node.alpha = 0
                    node.zPosition = 10
                    node.name = "wall"
                    addChild(node)
                    wallNodes[y][x] = node
                }
                if grid[y][x].isExit {
                    exitNode = SKSpriteNode(color: COLOR_CYAN, size: CGSize(width: CELL_SIZE * 2, height: CELL_SIZE * 2))
                    exitNode!.position = CGPoint(x: CGFloat(x) * CELL_SIZE + CELL_SIZE / 2,
                                                 y: CGFloat(y) * CELL_SIZE + CELL_SIZE / 2)
                    exitNode!.alpha = 0
                    exitNode!.zPosition = 8
                    exitNode!.name = "exit"
                    addChild(exitNode!)
                }
                if grid[y][x].isAirPocket {
                    let ap = SKSpriteNode(color: COLOR_AIR_POCKET, size: CGSize(width: CELL_SIZE, height: CELL_SIZE))
                    ap.position = CGPoint(x: CGFloat(x) * CELL_SIZE + CELL_SIZE / 2,
                                          y: CGFloat(y) * CELL_SIZE + CELL_SIZE / 2)
                    ap.alpha = 0
                    ap.zPosition = 5
                    ap.name = "airPocket"
                    addChild(ap)
                }
            }
        }

        // Place submarine at start
        let startX = CGFloat(GRID_W / 2) * CELL_SIZE + CELL_SIZE / 2
        let startY = CGFloat(GRID_H - 5) * CELL_SIZE + CELL_SIZE / 2
        submarine = SKSpriteNode(texture: makeSubTexture())
        submarine.size = CGSize(width: 36, height: 24)
        submarine.position = CGPoint(x: startX, y: startY)
        submarine.zPosition = 30
        addChild(submarine)

        // Sub glow
        let glowTex = makeGlowTexture(radius: 40, color: COLOR_SUB_GLOW)
        subGlow = SKSpriteNode(texture: glowTex)
        subGlow.size = CGSize(width: 80, height: 80)
        subGlow.zPosition = 25
        subGlow.alpha = 1.0
        addChild(subGlow)

        // Damage flash overlay
        damageFlash = SKSpriteNode(color: COLOR_DANGER, size: CGSize(width: WINDOW_W + 100, height: WINDOW_H + 100))
        damageFlash.zPosition = 90
        damageFlash.alpha = 0
        cameraNode.addChild(damageFlash)

        // Place creatures
        creatures.removeAll()
        let anglerCount = 3 + currentDepth
        let jellyCount = 2 + currentDepth
        let leviathanCount = currentDepth == 3 ? 1 : 0

        placeCreatures(count: anglerCount, type: .anglerfish)
        placeCreatures(count: jellyCount, type: .jellyfish)
        placeCreatures(count: leviathanCount, type: .leviathan)

        // Place specimens
        specimens.removeAll()
        specimensCollected = 0
        var specPlaced = 0
        var specAttempts = 0
        while specPlaced < SPECIMENS_PER_LEVEL && specAttempts < 1000 {
            let sx = Int.random(in: 5..<(GRID_W - 5))
            let sy = Int.random(in: 5..<(GRID_H - 5))
            if !grid[sy][sx].isWall {
                let pos = CGPoint(x: CGFloat(sx) * CELL_SIZE + CELL_SIZE / 2,
                                  y: CGFloat(sy) * CELL_SIZE + CELL_SIZE / 2)
                // Don't place too close to start
                let distFromStart = sqrt(pow(pos.x - startX, 2) + pow(pos.y - startY, 2))
                if distFromStart > 200 {
                    let spec = SpecimenNode(position: pos)
                    addChild(spec)
                    specimens.append(spec)
                    specPlaced += 1
                }
            }
            specAttempts += 1
        }

        // Bubble particles (simple manual particles)
        bubbleEmitter = SKNode()
        bubbleEmitter.zPosition = 35
        addChild(bubbleEmitter)

        updateHUD()
    }

    func placeCreatures(count: Int, type: CreatureType) {
        let startX = CGFloat(GRID_W / 2) * CELL_SIZE + CELL_SIZE / 2
        let startY = CGFloat(GRID_H - 5) * CELL_SIZE + CELL_SIZE / 2
        var placed = 0
        var attempts = 0
        while placed < count && attempts < 1000 {
            let cx = Int.random(in: 5..<(GRID_W - 5))
            let cy = Int.random(in: 5..<(GRID_H - 5))
            if !grid[cy][cx].isWall {
                let pos = CGPoint(x: CGFloat(cx) * CELL_SIZE + CELL_SIZE / 2,
                                  y: CGFloat(cy) * CELL_SIZE + CELL_SIZE / 2)
                let distFromStart = sqrt(pow(pos.x - startX, 2) + pow(pos.y - startY, 2))
                if distFromStart > 300 {
                    let creature = CreatureNode(type: type, position: pos)
                    addChild(creature)
                    creatures.append(creature)
                    placed += 1
                }
            }
            attempts += 1
        }
    }

    // MARK: - HUD

    func setupHUD() {
        hudNode = SKNode()
        hudNode.zPosition = 200
        cameraNode.addChild(hudNode)

        // HP bar background
        hpBarBg = SKSpriteNode(color: NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 0.7),
                               size: CGSize(width: 154, height: 14))
        hpBarBg.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpBarBg.position = CGPoint(x: -WINDOW_W / 2 + 20, y: WINDOW_H / 2 - 30)
        hudNode.addChild(hpBarBg)

        hpBar = SKSpriteNode(color: COLOR_HP_BAR, size: CGSize(width: 150, height: 10))
        hpBar.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpBar.position = CGPoint(x: -WINDOW_W / 2 + 22, y: WINDOW_H / 2 - 30)
        hudNode.addChild(hpBar)

        let hpLabel = SKLabelNode(text: "HULL")
        hpLabel.fontName = "Menlo-Bold"
        hpLabel.fontSize = 10
        hpLabel.fontColor = COLOR_HP_BAR
        hpLabel.horizontalAlignmentMode = .left
        hpLabel.position = CGPoint(x: -WINDOW_W / 2 + 20, y: WINDOW_H / 2 - 18)
        hudNode.addChild(hpLabel)

        // Oxygen bar
        oxyBarBg = SKSpriteNode(color: NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 0.7),
                                size: CGSize(width: 154, height: 14))
        oxyBarBg.anchorPoint = CGPoint(x: 0, y: 0.5)
        oxyBarBg.position = CGPoint(x: -WINDOW_W / 2 + 20, y: WINDOW_H / 2 - 55)
        hudNode.addChild(oxyBarBg)

        oxyBar = SKSpriteNode(color: COLOR_OXY_BAR, size: CGSize(width: 150, height: 10))
        oxyBar.anchorPoint = CGPoint(x: 0, y: 0.5)
        oxyBar.position = CGPoint(x: -WINDOW_W / 2 + 22, y: WINDOW_H / 2 - 55)
        hudNode.addChild(oxyBar)

        let oxyLabel = SKLabelNode(text: "O2")
        oxyLabel.fontName = "Menlo-Bold"
        oxyLabel.fontSize = 10
        oxyLabel.fontColor = COLOR_OXY_BAR
        oxyLabel.horizontalAlignmentMode = .left
        oxyLabel.position = CGPoint(x: -WINDOW_W / 2 + 20, y: WINDOW_H / 2 - 43)
        hudNode.addChild(oxyLabel)

        // Depth
        depthLabel = SKLabelNode(text: "DEPTH 1/3")
        depthLabel.fontName = "Menlo-Bold"
        depthLabel.fontSize = 14
        depthLabel.fontColor = COLOR_CYAN
        depthLabel.horizontalAlignmentMode = .right
        depthLabel.position = CGPoint(x: WINDOW_W / 2 - 20, y: WINDOW_H / 2 - 30)
        hudNode.addChild(depthLabel)

        // Specimens
        specimenLabel = SKLabelNode(text: "0/5")
        specimenLabel.fontName = "Menlo-Bold"
        specimenLabel.fontSize = 14
        specimenLabel.fontColor = COLOR_SPECIMEN
        specimenLabel.horizontalAlignmentMode = .right
        specimenLabel.position = CGPoint(x: WINDOW_W / 2 - 20, y: WINDOW_H / 2 - 50)
        hudNode.addChild(specimenLabel)

        // Sonar cooldown indicator
        cooldownIndicator = SKShapeNode(circleOfRadius: 10)
        cooldownIndicator.strokeColor = COLOR_CYAN
        cooldownIndicator.fillColor = COLOR_CYAN.withAlphaComponent(0.3)
        cooldownIndicator.lineWidth = 2
        cooldownIndicator.position = CGPoint(x: -WINDOW_W / 2 + 50, y: WINDOW_H / 2 - 80)
        hudNode.addChild(cooldownIndicator)

        let sonarLabel = SKLabelNode(text: "SONAR")
        sonarLabel.fontName = "Menlo"
        sonarLabel.fontSize = 8
        sonarLabel.fontColor = COLOR_CYAN
        sonarLabel.position = CGPoint(x: -WINDOW_W / 2 + 50, y: WINDOW_H / 2 - 96)
        hudNode.addChild(sonarLabel)

        // Silent indicator
        silentLabel = SKLabelNode(text: "SILENT")
        silentLabel.fontName = "Menlo-Bold"
        silentLabel.fontSize = 14
        silentLabel.fontColor = NSColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 0.8)
        silentLabel.position = CGPoint(x: 0, y: WINDOW_H / 2 - 30)
        silentLabel.alpha = 0
        hudNode.addChild(silentLabel)

        // Danger overlay (low oxygen warning)
        dangerOverlay = SKSpriteNode(color: .clear, size: CGSize(width: WINDOW_W + 100, height: WINDOW_H + 100))
        dangerOverlay.zPosition = 95
        dangerOverlay.alpha = 0
        cameraNode.addChild(dangerOverlay)
    }

    func updateHUD() {
        let hpFrac = max(0, hullHP / MAX_HULL)
        hpBar.xScale = hpFrac
        if hpFrac < 0.3 {
            hpBar.color = COLOR_DANGER
        } else {
            hpBar.color = COLOR_HP_BAR
        }

        let oxyFrac = max(0, oxygen / MAX_OXYGEN)
        oxyBar.xScale = oxyFrac
        if oxyFrac < 0.2 {
            oxyBar.color = COLOR_DANGER
        } else {
            oxyBar.color = COLOR_OXY_BAR
        }

        depthLabel.text = "DEPTH \(currentDepth)/\(TOTAL_DEPTHS)"
        specimenLabel.text = "\(specimensCollected)/\(SPECIMENS_PER_LEVEL)"

        // Sonar cooldown
        if sonarCooldown > 0 {
            let frac = sonarCooldown / CGFloat(SONAR_COOLDOWN)
            cooldownIndicator.fillColor = COLOR_CYAN.withAlphaComponent(CGFloat(0.1))
            cooldownIndicator.strokeColor = COLOR_CYAN.withAlphaComponent(CGFloat(1.0 - Double(frac) * 0.7))
        } else {
            cooldownIndicator.fillColor = COLOR_CYAN.withAlphaComponent(0.5)
            cooldownIndicator.strokeColor = COLOR_CYAN
        }

        // Silent indicator
        silentLabel.alpha = isSilentRunning ? 1.0 : 0.0

        // Danger overlay for low oxygen
        if oxygen / MAX_OXYGEN < 0.2 {
            let pulseVal = (sin(CACurrentMediaTime() * 4.0) + 1.0) / 2.0
            dangerOverlay.color = COLOR_DANGER.withAlphaComponent(CGFloat(pulseVal * 0.15))
            dangerOverlay.alpha = 1.0
        } else {
            dangerOverlay.alpha = 0
        }
    }

    // MARK: - Input

    override func keyDown(with event: NSEvent) {
        if event.isARepeat { return }
        keysPressed.insert(event.keyCode)

        if gameState == .menu || gameState == .dead || gameState == .victory {
            if event.keyCode == 36 { // Enter
                if gameState == .menu || gameState == .dead {
                    startGame()
                } else if gameState == .victory {
                    showMenu()
                }
            }
            return
        }

        // Space -> sonar
        if event.keyCode == 49 {
            fireSonar()
        }

        // E -> collect
        if event.keyCode == 14 {
            collectNearby()
        }
    }

    override func keyUp(with event: NSEvent) {
        keysPressed.remove(event.keyCode)
    }

    override func mouseDown(with event: NSEvent) {
        if gameState == .playing {
            fireSonar()
        }
    }

    // MARK: - Sonar

    func fireSonar() {
        guard sonarCooldown <= 0 else { return }
        sonarCooldown = CGFloat(SONAR_COOLDOWN)

        let ring = SonarRing(origin: submarine.position)
        addChild(ring)
        sonarRings.append(ring)

        // Add a second, slightly delayed ring for visual depth
        let ring2 = SonarRing(origin: submarine.position)
        ring2.alpha = 0.4
        ring2.lineWidth = 1.0
        addChild(ring2)
        sonarRings.append(ring2)

        // Alert creatures
        for creature in creatures {
            creature.alertToPing(at: submarine.position)
        }
    }

    func collectNearby() {
        for spec in specimens {
            if spec.collected { continue }
            let dx = spec.position.x - submarine.position.x
            let dy = spec.position.y - submarine.position.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < 50 {
                spec.collected = true
                spec.removeFromParent()
                specimensCollected += 1
                // Flash effect
                let flash = SKSpriteNode(color: COLOR_SPECIMEN, size: CGSize(width: 30, height: 30))
                flash.position = spec.position
                flash.zPosition = 60
                addChild(flash)
                flash.run(SKAction.sequence([
                    SKAction.fadeOut(withDuration: Double(0.5)),
                    SKAction.removeFromParent()
                ]))
                break
            }
        }
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        if lastUpdate == 0 { lastUpdate = currentTime; return }
        let dt = CGFloat(min(currentTime - lastUpdate, 1.0 / 30.0))
        lastUpdate = currentTime

        guard gameState == .playing else { return }

        invulnTimer = max(0, invulnTimer - dt)

        // Movement
        isSilentRunning = keysPressed.contains(56) || keysPressed.contains(60) // left/right shift
        let speed = isSilentRunning ? SUB_SILENT_SPEED : SUB_SPEED
        var dx: CGFloat = 0
        var dy: CGFloat = 0

        // WASD: W=13, A=0, S=1, D=2  Arrows: Up=126, Down=125, Left=123, Right=124
        if keysPressed.contains(13) || keysPressed.contains(126) { dy += 1 }
        if keysPressed.contains(1) || keysPressed.contains(125) { dy -= 1 }
        if keysPressed.contains(0) || keysPressed.contains(123) { dx -= 1 }
        if keysPressed.contains(2) || keysPressed.contains(124) { dx += 1 }

        if dx != 0 || dy != 0 {
            let len = sqrt(dx * dx + dy * dy)
            dx = dx / len * speed * dt
            dy = dy / len * speed * dt

            // Flip sub based on direction
            if dx < 0 { submarine.xScale = -1 }
            else if dx > 0 { submarine.xScale = 1 }

            let newPos = CGPoint(x: submarine.position.x + dx, y: submarine.position.y + dy)
            let gx = Int(newPos.x / CELL_SIZE)
            let gy = Int(newPos.y / CELL_SIZE)
            if gx >= 0 && gx < GRID_W && gy >= 0 && gy < GRID_H && !grid[gy][gx].isWall {
                submarine.position = newPos
            } else {
                // Try sliding along walls
                let newPosX = CGPoint(x: submarine.position.x + dx, y: submarine.position.y)
                let gxX = Int(newPosX.x / CELL_SIZE)
                let gyX = Int(newPosX.y / CELL_SIZE)
                if gxX >= 0 && gxX < GRID_W && gyX >= 0 && gyX < GRID_H && !grid[gyX][gxX].isWall {
                    submarine.position = newPosX
                }
                let newPosY = CGPoint(x: submarine.position.x, y: submarine.position.y + dy)
                let gxY = Int(newPosY.x / CELL_SIZE)
                let gyY = Int(newPosY.y / CELL_SIZE)
                if gxY >= 0 && gxY < GRID_W && gyY >= 0 && gyY < GRID_H && !grid[gyY][gxY].isWall {
                    submarine.position = newPosY
                }
            }
        }

        // Sub glow follows sub
        subGlow.position = submarine.position
        subGlow.alpha = isSilentRunning ? 0.3 : 1.0

        // Camera follow
        cameraNode.position = submarine.position

        // Sonar cooldown
        sonarCooldown = max(0, sonarCooldown - dt)

        // Update sonar rings + reveal
        var ringsToRemove: [Int] = []
        for (i, ring) in sonarRings.enumerated() {
            let prevRadius = ring.currentRadius
            let done = ring.updateRing(dt: dt)
            if done {
                ringsToRemove.append(i)
            }
            // Reveal tiles in the ring band
            revealTilesInRing(center: ring.origin, innerR: prevRadius, outerR: ring.currentRadius)
        }
        for i in ringsToRemove.reversed() {
            sonarRings[i].removeFromParent()
            sonarRings.remove(at: i)
        }

        // Sub glow reveal (always reveals nearby tiles)
        let glowRadius = isSilentRunning ? SUB_GLOW_RADIUS * 0.5 : SUB_GLOW_RADIUS
        revealTilesNearSub(radius: glowRadius)

        // Fade revealed tiles
        for y in 0..<GRID_H {
            for x in 0..<GRID_W {
                if grid[y][x].revealTimer > 0 {
                    grid[y][x].revealTimer -= dt
                    let alpha = max(0, grid[y][x].revealTimer / REVEAL_DURATION)
                    wallNodes[y][x]?.alpha = alpha
                    // Also reveal air pockets and exit near these coordinates
                }
            }
        }

        // Update exit visibility
        if let exitNode = exitNode {
            var maxReveal: CGFloat = 0
            let ex = Int(exitNode.position.x / CELL_SIZE)
            let ey = Int(exitNode.position.y / CELL_SIZE)
            for ddy in -2...2 {
                for ddx in -2...2 {
                    let nx = ex + ddx
                    let ny = ey + ddy
                    if nx >= 0 && nx < GRID_W && ny >= 0 && ny < GRID_H {
                        maxReveal = max(maxReveal, grid[ny][nx].revealTimer)
                    }
                }
            }
            exitNode.alpha = max(0, maxReveal / REVEAL_DURATION) * 0.8
        }

        // Update air pocket visibility
        self.enumerateChildNodes(withName: "airPocket") { node, _ in
            guard let sprite = node as? SKSpriteNode else { return }
            let gxA = Int(sprite.position.x / CELL_SIZE)
            let gyA = Int(sprite.position.y / CELL_SIZE)
            if gxA >= 0 && gxA < GRID_W && gyA >= 0 && gyA < GRID_H {
                sprite.alpha = max(0, self.grid[gyA][gxA].revealTimer / REVEAL_DURATION) * 0.6
            }
        }

        // Update creature visibility: visible if nearby tile is revealed or within sub glow
        for creature in creatures {
            let distToSub = distBetween(creature.position, submarine.position)
            let gxC = Int(creature.position.x / CELL_SIZE)
            let gyC = Int(creature.position.y / CELL_SIZE)
            var nearbyReveal: CGFloat = 0
            for ddy in -1...1 {
                for ddx in -1...1 {
                    let nx = gxC + ddx
                    let ny = gyC + ddy
                    if nx >= 0 && nx < GRID_W && ny >= 0 && ny < GRID_H {
                        nearbyReveal = max(nearbyReveal, grid[ny][nx].revealTimer)
                    }
                }
            }
            let sonarAlpha = nearbyReveal / REVEAL_DURATION
            let glowAlpha: CGFloat = distToSub < glowRadius ? 0.8 : 0
            // Creatures always have faint glow from their own bioluminescence
            let bioGlow: CGFloat = distToSub < 200 ? 0.15 : (distToSub < 400 ? 0.05 : 0)
            creature.alpha = min(1.0, max(sonarAlpha, max(glowAlpha, bioGlow)))
        }

        // Update specimen visibility
        for spec in specimens {
            if spec.collected { continue }
            let gxS = Int(spec.position.x / CELL_SIZE)
            let gyS = Int(spec.position.y / CELL_SIZE)
            var nearbyReveal: CGFloat = 0
            for ddy in -1...1 {
                for ddx in -1...1 {
                    let nx = gxS + ddx
                    let ny = gyS + ddy
                    if nx >= 0 && nx < GRID_W && ny >= 0 && ny < GRID_H {
                        nearbyReveal = max(nearbyReveal, grid[ny][nx].revealTimer)
                    }
                }
            }
            let sonarAlpha = nearbyReveal / REVEAL_DURATION
            let distToSubS = distBetween(spec.position, submarine.position)
            let glowAlphaS: CGFloat = distToSubS < glowRadius ? 0.8 : 0
            let bioGlowS: CGFloat = distToSubS < 150 ? 0.12 : 0
            spec.alpha = min(1.0, max(sonarAlpha, max(glowAlphaS, bioGlowS)))
        }

        // Update creatures
        for creature in creatures {
            creature.update(dt: dt, subPos: submarine.position, grid: grid, isSilent: isSilentRunning)

            // Collision with sub
            let distToSub = distBetween(creature.position, submarine.position)
            let hitDist: CGFloat = creature.creatureType == .leviathan ? 40 : 25
            if distToSub < hitDist && creature.contactCooldown <= 0 && invulnTimer <= 0 {
                takeDamage(amount: creature.damage)
                creature.contactCooldown = 1.0
            }
        }

        // Oxygen
        oxygen -= dt
        if oxygen <= 0 {
            hullHP = 0
        }

        // Check air pockets
        let subGX = Int(submarine.position.x / CELL_SIZE)
        let subGY = Int(submarine.position.y / CELL_SIZE)
        if subGX >= 0 && subGX < GRID_W && subGY >= 0 && subGY < GRID_H {
            if grid[subGY][subGX].isAirPocket {
                oxygen = min(MAX_OXYGEN, oxygen + dt * 10)
            }
        }

        // Check exit
        if let exitNode = exitNode {
            let distToExit = distBetween(submarine.position, exitNode.position)
            if distToExit < 30 {
                if currentDepth < TOTAL_DEPTHS {
                    currentDepth += 1
                    oxygen = min(MAX_OXYGEN, oxygen + 30) // bonus oxygen between levels
                    loadLevel()
                    return
                } else {
                    showVictory()
                    return
                }
            }
        }

        // Check death
        if hullHP <= 0 {
            showDeath()
            return
        }

        // Damage flash
        if damageFlashTimer > 0 {
            damageFlashTimer -= dt
            damageFlash.alpha = max(0, damageFlashTimer / 0.3) * 0.4
        }

        // Spawn bubbles near sub
        if Int.random(in: 0...5) == 0 {
            let bubble = SKSpriteNode(texture: makeParticleTexture())
            bubble.size = CGSize(width: CGFloat.random(in: 2...5), height: CGFloat.random(in: 2...5))
            bubble.position = CGPoint(
                x: submarine.position.x + CGFloat.random(in: -20...20),
                y: submarine.position.y + CGFloat.random(in: -10...10)
            )
            bubble.zPosition = 32
            bubble.alpha = CGFloat.random(in: 0.2...0.5)
            addChild(bubble)
            let rise = SKAction.moveBy(x: CGFloat.random(in: -5...5), y: CGFloat.random(in: 30...60), duration: Double(CGFloat.random(in: 2.0...4.0)))
            let fade = SKAction.fadeOut(withDuration: Double(CGFloat.random(in: 2.0...4.0)))
            bubble.run(SKAction.group([rise, fade])) {
                bubble.removeFromParent()
            }
        }

        // Ambient dust particles (less frequent)
        if Int.random(in: 0...20) == 0 {
            let dust = SKSpriteNode(texture: makeParticleTexture())
            dust.size = CGSize(width: 2, height: 2)
            dust.position = CGPoint(
                x: submarine.position.x + CGFloat.random(in: -WINDOW_W/2...WINDOW_W/2),
                y: submarine.position.y + CGFloat.random(in: -WINDOW_H/2...WINDOW_H/2)
            )
            dust.zPosition = 3
            dust.alpha = CGFloat.random(in: 0.05...0.15)
            addChild(dust)
            let drift = SKAction.moveBy(x: CGFloat.random(in: -10...10), y: CGFloat.random(in: 5...20), duration: Double(CGFloat.random(in: 3.0...6.0)))
            let fade = SKAction.fadeOut(withDuration: Double(CGFloat.random(in: 3.0...6.0)))
            dust.run(SKAction.group([drift, fade])) {
                dust.removeFromParent()
            }
        }

        updateHUD()
    }

    func takeDamage(amount: CGFloat) {
        hullHP -= amount
        damageFlashTimer = 0.3
        damageFlash.alpha = 0.4
    }

    func revealTilesInRing(center: CGPoint, innerR: CGFloat, outerR: CGFloat) {
        // Determine grid bounds to check
        let minGX = max(0, Int((center.x - outerR) / CELL_SIZE) - 1)
        let maxGX = min(GRID_W - 1, Int((center.x + outerR) / CELL_SIZE) + 1)
        let minGY = max(0, Int((center.y - outerR) / CELL_SIZE) - 1)
        let maxGY = min(GRID_H - 1, Int((center.y + outerR) / CELL_SIZE) + 1)

        for y in minGY...maxGY {
            for x in minGX...maxGX {
                let cellCenter = CGPoint(x: CGFloat(x) * CELL_SIZE + CELL_SIZE / 2,
                                         y: CGFloat(y) * CELL_SIZE + CELL_SIZE / 2)
                let dist = distBetween(center, cellCenter)
                if dist >= innerR && dist <= outerR + CELL_SIZE {
                    grid[y][x].revealTimer = REVEAL_DURATION
                    if grid[y][x].isWall {
                        wallNodes[y][x]?.alpha = 1.0
                    }
                }
            }
        }
    }

    func revealTilesNearSub(radius: CGFloat) {
        let cx = submarine.position.x
        let cy = submarine.position.y
        let minGX = max(0, Int((cx - radius) / CELL_SIZE) - 1)
        let maxGX = min(GRID_W - 1, Int((cx + radius) / CELL_SIZE) + 1)
        let minGY = max(0, Int((cy - radius) / CELL_SIZE) - 1)
        let maxGY = min(GRID_H - 1, Int((cy + radius) / CELL_SIZE) + 1)

        for y in minGY...maxGY {
            for x in minGX...maxGX {
                let cellCenter = CGPoint(x: CGFloat(x) * CELL_SIZE + CELL_SIZE / 2,
                                         y: CGFloat(y) * CELL_SIZE + CELL_SIZE / 2)
                let dist = distBetween(CGPoint(x: cx, y: cy), cellCenter)
                if dist <= radius {
                    // Keep at a low reveal level for glow effect
                    grid[y][x].revealTimer = max(grid[y][x].revealTimer, 0.8)
                    if grid[y][x].isWall {
                        wallNodes[y][x]?.alpha = max(wallNodes[y][x]?.alpha ?? 0, 0.3)
                    }
                }
            }
        }
    }

    func distBetween(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - App Delegate and Window

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let scene = GameScene(size: CGSize(width: WINDOW_W, height: WINDOW_H))
        scene.scaleMode = .aspectFit

        let skView = SKView(frame: NSRect(x: 0, y: 0, width: Int(WINDOW_W), height: Int(WINDOW_H)))
        skView.presentScene(scene)
        skView.showsFPS = false
        skView.showsNodeCount = false

        let windowRect = NSRect(x: 0, y: 0, width: Int(WINDOW_W), height: Int(WINDOW_H))
        window = NSWindow(contentRect: windowRect,
                          styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered,
                          defer: false)
        window.title = "Echo Depths"
        window.contentView = skView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.acceptsMouseMovedEvents = true

        // Make the app a proper foreground app
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Main Entry Point

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
