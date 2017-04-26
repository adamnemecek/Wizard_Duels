
//
//  Node.swift
//  Duel
//
//  Created by Jenna on 2/23/17.
//  Copyright © 2017 Jenna. All rights reserved.
//

import Foundation
import Metal
import QuartzCore
import simd

class Node {
    
    var time:Float = 0.0
    var moving:Bool
    
    let name: String
    let light = Light(color: (1.0,1.0,1.0), ambientIntensity: 0.1, direction: (0.0, 0.0, 1.0), diffuseIntensity: 0.8, shininess: 10, specularIntensity: 2)
    
    var vertexCount: Int
    var vertexBuffer: MTLBuffer
    var device: MTLDevice
    
    var positionX:Float = 0.0
    var positionY:Float = 0.0
    var positionZ:Float = 0.0
    
    var rotationX:Float = 0.0
    var rotationY:Float = 0.0
    var rotationZ:Float = 0.0
    var scale:Float     = 1.0
    
    var bufferProvider: BufferProvider
    var texture: MTLTexture //spell cast
    var texture2: MTLTexture //floor
    var texture3: MTLTexture //walls
    var texture4: MTLTexture //sky
    var texture5: MTLTexture //witch face
    var texture6: MTLTexture //witchcloak
    lazy var samplerState: MTLSamplerState? = Node.defaultSampler(self.device)
    
    init(name: String, vertices: Array<Vertex>, device: MTLDevice, texture: MTLTexture, texture2: MTLTexture, texture3: MTLTexture, texture4: MTLTexture, texture5: MTLTexture, texture6: MTLTexture) {
        //cube should start out not moving
        moving = false;
        
        var vertexData = Array<Float>()
        for vertex in vertices{
            vertexData += vertex.floatBuffer()
        }
        
        let dataSize = vertexData.count * MemoryLayout<Float>.size
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: MTLResourceOptions())
        
        self.name = name
        self.device = device
        vertexCount = vertices.count
        self.texture = texture
        self.texture2 = texture2
        self.texture3 = texture3
        self.texture4 = texture4
        self.texture5 = texture5
        self.texture6 = texture6
        
        self.bufferProvider = BufferProvider(device: device, inflightBuffersCount: 3)
    }
    
    func render(_ commandQueue: MTLCommandQueue, pipelineState: MTLRenderPipelineState, drawable: CAMetalDrawable, parentModelViewMatrix: float4x4, projectionMatrix: float4x4, clearColor: MTLClearColor?) {
        
        if (moving) {
            updateMovement()
        }
        //could add here if moving == -3 then stop moving
        
        let _ = bufferProvider.avaliableResourcesSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.2, green: 0.2, blue: 0.35, alpha: 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        commandBuffer.addCompletedHandler { (commandBuffer) -> Void in
            self.bufferProvider.avaliableResourcesSemaphore.signal()
        }
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        renderEncoder.setCullMode(MTLCullMode.front)
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, at: 0)
        renderEncoder.setFragmentTexture(texture, at: 0)
        
        if let samplerState = samplerState {
            renderEncoder.setFragmentSamplerState(samplerState, at: 0)
        }
        
        var nodeModelMatrix = self.modelMatrix()
        nodeModelMatrix.multiplyLeft(parentModelViewMatrix)
        
        let uniformBuffer = bufferProvider.nextUniformsBuffer(projectionMatrix, modelViewMatrix: nodeModelMatrix, light: light)
        
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, at: 1)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, at: 1)
        
        //Set up floor
        renderEncoder.setFragmentTexture(texture2, at: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 48)
        
        //set up walls
        renderEncoder.setFragmentTexture(texture3, at: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 48, vertexCount: 144)
        
        //set up sky
        renderEncoder.setFragmentTexture(texture4, at: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 144, vertexCount: 6)
        
        //set up witch cloak and hat
        renderEncoder.setFragmentTexture(texture6, at: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 150, vertexCount: 234)
        
        //set up witch face
        renderEncoder.setFragmentTexture(texture5, at: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 384, vertexCount: 24)
        
        //set up cube, 36 count for a cube
        renderEncoder.setFragmentTexture(texture, at: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 408, vertexCount: vertexCount - 408)
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func modelMatrix() -> float4x4 {
        var matrix = float4x4()
        matrix.translate(positionX, y: positionY, z: positionZ)
        matrix.rotateAroundX(rotationX, y: rotationY, z: rotationZ)
        matrix.scale(scale, y: scale, z: scale)
        return matrix
    }
    
    func updateMovement() {
        time -= 0.1 //delta
    }
    
    class func defaultSampler(_ device: MTLDevice) -> MTLSamplerState {
        let pSamplerDescriptor:MTLSamplerDescriptor? = MTLSamplerDescriptor();
        
        if let sampler = pSamplerDescriptor {
            sampler.minFilter             = MTLSamplerMinMagFilter.nearest
            sampler.magFilter             = MTLSamplerMinMagFilter.nearest
            sampler.mipFilter             = MTLSamplerMipFilter.nearest
            sampler.maxAnisotropy         = 1
            sampler.sAddressMode          = MTLSamplerAddressMode.clampToEdge
            sampler.tAddressMode          = MTLSamplerAddressMode.clampToEdge
            sampler.rAddressMode          = MTLSamplerAddressMode.clampToEdge
            sampler.normalizedCoordinates = true
            sampler.lodMinClamp           = 0
            sampler.lodMaxClamp           = Float.greatestFiniteMagnitude
        }
        else {
            print(">> ERROR: Failed creating a sampler descriptor!")
        }
        return device.makeSamplerState(descriptor: pSamplerDescriptor!)
    }
    
    func update(vertices: Array<Vertex>) {
        vertexCount = vertices.count
        var vertexData = Array<Float>()
        for vertex in vertices {
            vertexData += vertex.floatBuffer()
        }
        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])
    }
    
    func updateTexture(texture: MTLTexture) {
        self.texture = texture
    }
}
