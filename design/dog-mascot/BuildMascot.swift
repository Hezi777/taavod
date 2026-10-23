import AppKit
import SceneKit
import simd

// Builds the editable SceneKit source scene, the USDZ used by the app, and its
// transparent icon render. The mesh is composed from real 3D geometry.
@MainActor
enum ShihTzuMascot {
    static let cream = material(0.94, 0.88, 0.75, roughness: 0.82)
    static let muzzle = material(0.98, 0.93, 0.83, roughness: 0.78)
    static let warmWhite = material(1.0, 0.97, 0.88, roughness: 0.72)
    static let tan = material(0.63, 0.36, 0.20, roughness: 0.9)
    static let tanLight = material(0.77, 0.52, 0.30, roughness: 0.88)
    static let ear = material(0.23, 0.13, 0.10, roughness: 0.76)
    static let earWarm = material(0.38, 0.24, 0.18, roughness: 0.78)
    static let eye = material(0.025, 0.02, 0.023, roughness: 0.12, metallic: 0.04)
    static let nose = material(0.035, 0.027, 0.03, roughness: 0.24)
    static let tongue = material(0.91, 0.20, 0.30, roughness: 0.58)

    static func material(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, roughness: CGFloat, metallic: CGFloat = 0) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
        m.roughness.contents = roughness
        m.metalness.contents = metallic
        m.lightingModel = .physicallyBased
        return m
    }

    static func scene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.clear
        let root = scene.rootNode
        root.name = "ShihTzuMascot"
        let key = SCNNode()
        key.light = SCNLight(); key.light?.type = .area; key.light?.intensity = 200
        key.light?.color = NSColor(calibratedWhite: 1, alpha: 1)
        key.position = SCNVector3(-3.2, 4.8, 6.0); key.light?.areaType = .rectangle
        root.addChildNode(key)
        let fill = SCNNode(); fill.light = SCNLight(); fill.light?.type = .omni
        fill.light?.intensity = 105; fill.position = SCNVector3(4, 1.5, 3.5); root.addChildNode(fill)
        let rim = SCNNode(); rim.light = SCNLight(); rim.light?.type = .area
        rim.light?.intensity = 90; rim.position = SCNVector3(2, 4, -3)
        root.addChildNode(rim)
        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient
        ambient.light?.intensity = 42; root.addChildNode(ambient)
        let character = SCNNode(); character.name = "CharacterRoot"; root.addChildNode(character)
        let head = SCNNode(); head.name = "HeadPivot"; head.position = SCNVector3(0, 0.08, 0.02); head.eulerAngles.z = -0.06; head.eulerAngles.y = 0.09; character.addChildNode(head)
        let coat = coatHead()
        let coatNode = SCNNode(geometry: coat); coatNode.name = "HeadCoat"
        head.addChildNode(coatNode)

        // Flowing fur layers follow the head surface so the face marks read as coat.
        for side: Float in [-1, 1] {
            let earNode = SCNNode(); earNode.name = side < 0 ? "EarLeftPivot" : "EarRightPivot"
            earNode.position = SCNVector3(side * 0.88, 0.12, 0.46)
            head.addChildNode(earNode)
            let outer = ellipsoid("Ear", scale: SCNVector3(0.30, 0.78, 0.16), at: SCNVector3(side * 0.08, -0.34, 0.00), material: ear)
            outer.eulerAngles.z = CGFloat(-side * 0.20); earNode.addChildNode(outer)
            let sheen = ellipsoid("EarSheen", scale: SCNVector3(0.17, 0.66, 0.045), at: SCNVector3(-side * 0.07, -0.34, 0.13), material: earWarm)
            sheen.eulerAngles.z = CGFloat(-side * 0.18); earNode.addChildNode(sheen)
        }

        // Layered woolly crown over a swept white center blaze.
        let crown = ellipsoid("CrownTuft", scale: SCNVector3(0.43, 0.21, 0.22), at: SCNVector3(-0.06, 0.66, 0.22), material: warmWhite)
        crown.eulerAngles.z = -0.18; head.addChildNode(crown)
        for side: Float in [-1, 1] {
            for i in 0..<7 {
                let t = Float(i) / 6
                let start = facePoint(side * (0.62 + 0.06 * t), 0.22 - 0.22 * t, lift: 0.04)
                let end = facePoint(side * (0.60 + 0.04 * t), -0.42 - 0.05 * t, lift: 0.04)
                let c1 = facePoint(side * (0.77 + 0.03 * t), 0.00 - 0.18 * t, lift: 0.06)
                let c2 = facePoint(side * (0.72 + 0.05 * t), -0.27 - 0.12 * t, lift: 0.055)
                head.addChildNode(furLock("CheekFlow", from: start, control1: c1, control2: c2, to: end,
                                          width: 0.060 + Float(i % 3) * 0.009, material: i.isMultiple(of: 3) ? warmWhite : cream))
            }
        }

        // Deep glossy eyes sit within a soft dark fur mask, then move as separate nodes.
        let eyesRoot = SCNNode(); eyesRoot.name = "EyesPivot"; head.addChildNode(eyesRoot)
        for side: Float in [-1, 1] {
            head.addChildNode(faceMask(side: side))
            let eyeNode = SCNNode(); eyeNode.name = side < 0 ? "EyeLeft" : "EyeRight"
            eyeNode.position = SCNVector3(side * 0.39, 0.15, 0.77); eyesRoot.addChildNode(eyeNode)
            eyeNode.addChildNode(ellipsoid("Iris", scale: SCNVector3(0.11, 0.14, 0.06), at: SCNVector3(0, 0, 0), material: eye))
            let shine = ellipsoid("EyeCatchlight", scale: SCNVector3(0.032, 0.038, 0.020), at: SCNVector3(-0.032, 0.045, 0.056), material: warmWhite)
            eyeNode.addChildNode(shine)
            let glint = ellipsoid("EyeGlint", scale: SCNVector3(0.014, 0.016, 0.010), at: SCNVector3(0.039, -0.035, 0.059), material: warmWhite)
            eyeNode.addChildNode(glint)
        }

        // Broad split moustache pads make the short, flat Shih Tzu muzzle.
        head.addChildNode(ellipsoid("Bridge", scale: SCNVector3(0.18, 0.21, 0.14), at: SCNVector3(0, -0.18, 0.75), material: muzzle))
        for side: Float in [-1, 1] {
            head.addChildNode(ellipsoid("MuzzlePad", scale: SCNVector3(0.36, 0.21, 0.16),
                                        at: SCNVector3(side * 0.16, -0.39, 0.77), material: warmWhite))
        }
        head.addChildNode(ellipsoid("ChinFur", scale: SCNVector3(0.38, 0.13, 0.12), at: SCNVector3(0, -0.55, 0.76), material: warmWhite))
        let noseNode = SCNNode(); noseNode.name = "Nose"
        noseNode.position = SCNVector3(0, -0.19, 0.91)
        noseNode.addChildNode(ellipsoid("Nose", scale: SCNVector3(0.16, 0.11, 0.10), at: SCNVector3(0, 0, 0), material: nose))
        for side: Float in [-1, 1] {
            noseNode.addChildNode(ellipsoid("Nostril", scale: SCNVector3(0.024, 0.017, 0.012), at: SCNVector3(side * 0.065, 0.01, 0.104), material: ear))
        }
        head.addChildNode(noseNode)
        let mouth = ellipsoid("Mouth", scale: SCNVector3(0.09, 0.022, 0.022), at: SCNVector3(0, -0.57, 0.84), material: ear)
        head.addChildNode(mouth)
        let tongueNode = ellipsoid("Tongue", scale: SCNVector3(0.060, 0.12, 0.035), at: SCNVector3(0, -0.65, 0.86), material: tongue)
        tongueNode.name = "Tongue"; tongueNode.isHidden = true; head.addChildNode(tongueNode)

        let camera = SCNNode(); camera.name = "MascotCamera"; camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 34; camera.position = SCNVector3(0.34, 0.05, 6.55)
        camera.look(at: SCNVector3(0, -0.18, 0)); root.addChildNode(camera)
        return scene
    }

    static func ellipsoid(_ name: String, scale: SCNVector3, at position: SCNVector3, material: SCNMaterial) -> SCNNode {
        let geometry = SCNSphere(radius: 1); geometry.segmentCount = 20; geometry.isGeodesic = true
        geometry.firstMaterial = material
        let node = SCNNode(geometry: geometry); node.name = name; node.position = position; node.scale = scale
        return node
    }

    static func coatHead() -> SCNGeometry {
        let rings = 72, slices = 112
        let radius = SIMD3<Float>(1.10, 0.87, 0.78)
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var colors: [Float] = []
        var indices: [Int32] = []
        let base = SIMD3<Float>(0.94, 0.88, 0.75)
        let tan = SIMD3<Float>(0.58, 0.32, 0.19)
        let mask = SIMD3<Float>(0.16, 0.075, 0.055)
        let white = SIMD3<Float>(1.0, 0.97, 0.89)
        func gaussian(_ x: Float, _ y: Float, _ cx: Float, _ cy: Float, _ sx: Float, _ sy: Float) -> Float {
            exp(-((x - cx) * (x - cx) / (sx * sx) + (y - cy) * (y - cy) / (sy * sy)) * 1.6)
        }
        func blend(_ from: SIMD3<Float>, _ to: SIMD3<Float>, _ weight: Float) -> SIMD3<Float> {
            from * (1 - weight) + to * weight
        }
        for ring in 0...rings {
            let theta = Float(ring) / Float(rings) * .pi
            for slice in 0...slices {
                let phi = Float(slice) / Float(slices) * 2 * .pi
                let unit = SIMD3<Float>(sin(theta) * sin(phi), cos(theta), sin(theta) * cos(phi))
                let point = unit * radius
                vertices.append(SCNVector3(CGFloat(point.x), CGFloat(point.y), CGFloat(point.z)))
                let normal = simd_normalize(SIMD3<Float>(unit.x / radius.x, unit.y / radius.y, unit.z / radius.z))
                normals.append(SCNVector3(CGFloat(normal.x), CGFloat(normal.y), CGFloat(normal.z)))

                var color = base
                let front = max(0, unit.z)
                let sidePatch = max(gaussian(unit.x, unit.y, -0.54, 0.08, 0.38, 0.55),
                                    gaussian(unit.x, unit.y, 0.54, 0.08, 0.38, 0.55)) * front
                color = blend(color, tan, simd_clamp(sidePatch * 1.25, 0, 0.88))
                let eyeMask = max(gaussian(unit.x, unit.y, -0.37, 0.22, 0.28, 0.34),
                                  gaussian(unit.x, unit.y, 0.37, 0.22, 0.28, 0.34)) * front
                color = blend(color, mask, simd_clamp(eyeMask * 1.18, 0, 0.98))
                let blaze = exp(-(unit.x * unit.x) / (0.14 * 0.14)) * front * simd_clamp((unit.y + 0.02) * 1.5, 0, 1)
                color = blend(color, white, simd_clamp(blaze * 0.86, 0, 0.92))
                let noise = 0.006 * sin(point.x * 91 + point.y * 47) * cos(point.y * 63 - point.z * 27)
                colors.append(contentsOf: [color.x + noise, color.y + noise, color.z + noise, 1])
            }
        }
        for ring in 0..<rings {
            for slice in 0..<slices {
                let a = Int32(ring * (slices + 1) + slice)
                let b = a + 1
                let c = a + Int32(slices + 1)
                let d = c + 1
                indices.append(contentsOf: [a, c, b, b, c, d])
            }
        }
        let colorData = colors.withUnsafeBufferPointer { Data(buffer: $0) }
        let colorSource = SCNGeometrySource(data: colorData, semantic: .color, vectorCount: vertices.count,
                                             usesFloatComponents: true, componentsPerVector: 4,
                                             bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0,
                                             dataStride: MemoryLayout<Float>.size * 4)
        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals), colorSource],
                                   elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        let coat = SCNMaterial(); coat.diffuse.contents = NSColor.white; coat.roughness.contents = 0.85
        coat.lightingModel = .physicallyBased; geometry.firstMaterial = coat
        return geometry
    }

    static func faceMask(side: Float) -> SCNNode {
        let rings = 112, slices = 64
        let centerX = side * 0.39, centerY: Float = 0.17
        let radiusX: Float = 0.39, radiusY: Float = 0.42
        var vertices: [SCNVector3] = []
        var indicesByRing = Array(repeating: [Int32](), count: rings)
        for ring in 0...rings {
            let r = Float(ring) / Float(rings)
            for slice in 0...slices {
                let angle = Float(slice) / Float(slices) * 2 * .pi
                let irregular = 1 + 0.11 * sin(3 * angle + side) + 0.06 * cos(5 * angle - side)
                let x = centerX + radiusX * r * irregular * cos(angle)
                let y = centerY + radiusY * r * irregular * sin(angle)
                let z = 0.78 * sqrt(max(0.025, 1 - x * x / (1.10 * 1.10) - y * y / (0.87 * 0.87))) + 0.024
                vertices.append(SCNVector3(CGFloat(x), CGFloat(y), CGFloat(z)))
            }
        }
        for ring in 0..<rings {
            for slice in 0..<slices {
                let inner = Int32(ring * (slices + 1) + slice)
                let nextInner = inner + 1
                let outer = inner + Int32(slices + 1)
                let nextOuter = outer + 1
                indicesByRing[ring].append(contentsOf: [inner, outer, nextInner, nextInner, outer, nextOuter])
            }
        }
        let elements = indicesByRing.map { SCNGeometryElement(indices: $0, primitiveType: .triangles) }
        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices)], elements: elements)
        let dark = SIMD3<Float>(0.19, 0.105, 0.085)
        let tan = SIMD3<Float>(0.62, 0.38, 0.24)
        let light = SIMD3<Float>(0.90, 0.79, 0.65)
        geometry.materials = (0..<rings).map { index in
            let t = Float(index) / Float(rings - 1)
            let color: SIMD3<Float>
            if t < 0.58 {
                let blend = t / 0.58
                color = dark * (1 - blend) + SIMD3<Float>(0.30, 0.17, 0.12) * blend
            } else if t < 0.88 {
                let blend = (t - 0.58) / 0.30
                color = SIMD3<Float>(0.30, 0.17, 0.12) * (1 - blend) + tan * blend
            } else {
                let blend = (t - 0.88) / 0.12
                color = tan * (1 - blend) + light * blend
            }
            return material(CGFloat(color.x), CGFloat(color.y), CGFloat(color.z), roughness: 0.88)
        }
        let node = SCNNode(geometry: geometry); node.name = side < 0 ? "LeftCoatMask" : "RightCoatMask"
        return node
    }

    static func facePoint(_ x: Float, _ y: Float, lift: Float) -> SIMD3<Float> {
        let z = 0.78 * sqrt(max(0.03, 1 - x * x / (1.10 * 1.10) - y * y / (0.87 * 0.87))) + lift
        return SIMD3<Float>(x, y, z)
    }

    static func furLock(_ name: String, from p0: SIMD3<Float>, control1 p1: SIMD3<Float>, control2 p2: SIMD3<Float>, to p3: SIMD3<Float>, width: Float, material: SCNMaterial) -> SCNNode {
        let rings = 8, sides = 7
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [Int32] = []
        for ring in 0...rings {
            let t = Float(ring) / Float(rings), u = 1 - t
            let point = p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t)
            var tangent = (p1 - p0) * (3 * u * u) + (p2 - p1) * (6 * u * t) + (p3 - p2) * (3 * t * t)
            tangent = simd_normalize(tangent)
            let reference = abs(simd_dot(tangent, SIMD3<Float>(0, 0, 1))) > 0.92 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(0, 0, 1)
            let axisA = simd_normalize(simd_cross(tangent, reference))
            let axisB = simd_normalize(simd_cross(tangent, axisA))
            let profile: [Float] = [0.08, 0.58, 0.86, 1.00, 0.98, 0.92, 0.77, 0.48, 0.08]
            let taper = profile[ring]
            for side in 0..<sides {
                let angle = Float(side) * 2 * .pi / Float(sides)
                let radial = axisA * cos(angle) + axisB * sin(angle)
                let vertex = point + radial * (width * taper)
                vertices.append(SCNVector3(CGFloat(vertex.x), CGFloat(vertex.y), CGFloat(vertex.z)))
                normals.append(SCNVector3(CGFloat(radial.x), CGFloat(radial.y), CGFloat(radial.z)))
            }
        }
        for ring in 0..<rings {
            for side in 0..<sides {
                let next = (side + 1) % sides
                let a = Int32(ring * sides + side), b = Int32(ring * sides + next)
                let c = Int32((ring + 1) * sides + side), d = Int32((ring + 1) * sides + next)
                indices.append(contentsOf: [a, b, c, b, d, c])
            }
        }
        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals)],
                                   elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        geometry.firstMaterial = material
        geometry.firstMaterial?.isDoubleSided = true
        let node = SCNNode(geometry: geometry); node.name = name
        return node
    }

}

@main
@MainActor
struct BuildMascot {
    static func main() throws {
        let repo = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let scene = ShihTzuMascot.scene()
        let source = repo.appendingPathComponent("design/dog-mascot/ShihTzu.scn")
        let usdz = repo.appendingPathComponent("native/Taavod/Resources/Mascot/ShihTzu.usdz")
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.rootNode.childNode(withName: "MascotCamera", recursively: true)
        renderer.autoenablesDefaultLighting = false
        scene.rootNode.childNode(withName: "Tongue", recursively: true)?.isHidden = false
        let image = renderer.snapshot(atTime: 0, with: CGSize(width: 1024, height: 1024), antialiasingMode: .multisampling4X)
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "MascotExport", code: 1) }
        try png.write(to: repo.appendingPathComponent("design/dog-mascot/ShihTzu-Icon.png"))
        try png.write(to: repo.appendingPathComponent("native/Taavod/Resources/Mascot/ShihTzu-Icon.png"))
        scene.rootNode.childNode(withName: "Tongue", recursively: true)?.isHidden = true
        scene.write(to: source, options: nil, delegate: nil, progressHandler: nil)
        scene.write(to: usdz, options: nil, delegate: nil, progressHandler: nil)
    }
}
