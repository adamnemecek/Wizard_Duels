//
//  MessagesViewController.swift
//  MessagesExtension
//
//  Created by Jenna and Roslyn on 1/12/17.
//  Copyright © 2017 Jenna. All rights reserved.
//

import UIKit
import Messages
import Metal
import QuartzCore

class MessagesViewController: MSMessagesAppViewController {
    @IBOutlet weak var canvas: UIImageView!
    var lastPoint = CGPoint.zero
    var swiped = false
    var color = UIColor(red: 0, green: 0, blue: 0, alpha: 1).cgColor
    var gesture = "nothing yet"
    //device for metal to be run on
    var device: MTLDevice! = nil
    var metalLayer: CAMetalLayer! = nil
    //metal object to draw
    var objectToDraw: Cube!
    var projectionMatrix: Matrix4!
    //rendering pipeline for shaders
    var pipelineState: MTLRenderPipelineState! = nil
    var commandQueue: MTLCommandQueue! = nil
    var timer: CADisplayLink! = nil
    //keep track of time to rotate cube
    var lastFrameTimestamp: CFTimeInterval = 0.0
    //var touchGesture: TouchRecognizer!

    @IBAction func didPressSend(_ sender: Any) {
        if let image = createImageForMessage(), let conversation = activeConversation {
            let layout = MSMessageTemplateLayout()
            layout.image = image
            layout.caption = "Let's Duel"
            
            let message = MSMessage()
            message.layout = layout
            message.url = URL(string: "emptyURL")
            
            conversation.insert(message, completionHandler: { (error: Error?) in
                print(error ?? "not an error")
            })
        }
    }
    
    @IBAction func longPress(_ sender: UILongPressGestureRecognizer) {
        print(" Handle long press...")
        gesture = "long press"
    }
    
    @IBAction func tap(_ sender: UITapGestureRecognizer) {
        print(" Handle tap...")
        gesture = "tap"
    }
    
    @IBAction func rotate(_ sender: UIRotationGestureRecognizer) {
        print(" Handle rotate...")
        gesture = "rotate"
    }
    
    @IBAction func pinch(_ sender: UIPinchGestureRecognizer) {
        print(" Handle pinch...")
        gesture = "pinch"
    }
    
    @IBAction func swipeDown(_ sender: UISwipeGestureRecognizer) {
        print(" Handle swipe down...")
        color = UIColor(red: 0, green: 1, blue: 0, alpha: 1).cgColor
        gesture = "down"
        objectToDraw.makeSmall()
    }
    
    @IBAction func swipeUp(_ sender: UISwipeGestureRecognizer) {
        print(" Handle swipe up...")
        color = UIColor(red: 0, green: 0, blue: 1, alpha: 1).cgColor
        gesture = "up"
        objectToDraw.makeIce()
        objectToDraw.makeBig()
    }
    
    @IBAction func swipeRight(_ sender: UISwipeGestureRecognizer) {
        print(" Handle swipe right...")
        color = UIColor(red: 0, green: 0, blue: 0, alpha: 1).cgColor
        gesture = "right"
        objectToDraw.makeMedium()
    }
    
    @IBAction func swipeLeft(_ sender: UISwipeGestureRecognizer) {
        print(" Handle swipe left...")
        color = UIColor(red: 1, green: 0, blue: 0, alpha: 1).cgColor
        gesture = "left"
        objectToDraw.makeMedium()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //touchGesture = TouchRecognizer()
        device = MTLCreateSystemDefaultDevice()
        
        projectionMatrix = Matrix4.makePerspectiveViewAngle(Matrix4.degrees(toRad: 85.0), aspectRatio:
            Float(self.view.bounds.size.width / self.view.bounds.size.height), nearZ: 0.01, farZ: 100.0)
        
        metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.frame = view.layer.frame
        //this puts the metal layer underneath the canvas layer so strokes can be viewed over the metal drawing.
        view.layer.insertSublayer(metalLayer, below: canvas.layer)
        
        objectToDraw = Cube(device: device)

        let defaultLibrary = device.newDefaultLibrary()
        let fragmentProgram = defaultLibrary!.makeFunction(name: "basic_fragment")
        let vertexProgram = defaultLibrary!.makeFunction(name: "basic_vertex")
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            try self.pipelineState = device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        } catch let pipelineError as NSError {
            print("Failed to create pipeline state, error \(pipelineError)")
        }
        
        commandQueue = device.makeCommandQueue()
        
        timer = CADisplayLink(target: self, selector: #selector(MessagesViewController.gameloop))
        timer.add(to: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
    }
    
    //renders metal image
    func render() {
        let drawable = metalLayer.nextDrawable()
        let worldModelMatrix = Matrix4()
        worldModelMatrix?.translate(0.0, y: 0.0, z: -7.0)
        worldModelMatrix?.rotateAroundX(Matrix4.degrees(toRad: 25), y: 0.0, z: 0.0)
        objectToDraw.render(commandQueue: commandQueue, pipelineState: pipelineState, drawable: drawable!, parentModelViewMatrix: worldModelMatrix!, projectionMatrix: projectionMatrix ,clearColor: nil)
    }
    
    //update cube as it moves with time
    func newFrame(displayLink: CADisplayLink){
        
        if lastFrameTimestamp == 0.0 {
            lastFrameTimestamp = displayLink.timestamp
        }
        
        let elapsed:CFTimeInterval = displayLink.timestamp - lastFrameTimestamp
        lastFrameTimestamp = displayLink.timestamp
        
        gameloop(timeSinceLastUpdate: elapsed)
    }
    
    func gameloop(timeSinceLastUpdate timeInterval: CFTimeInterval) {
        //this translates the cube over time
        objectToDraw.updateWithDelta(delta: timeInterval)
        autoreleasepool {
            self.render()
        }
    }
    
    func drawLines(fromPoint: CGPoint, toPoint: CGPoint) {
        UIGraphicsBeginImageContext(canvas.frame.size)
        canvas.image?.draw(in: CGRect(x: 0.0, y: 0.0, width: canvas.frame.width, height: canvas.frame.height))
        let context = UIGraphicsGetCurrentContext()
        
        context?.move(to: CGPoint(x: fromPoint.x, y: fromPoint.y))
        context?.addLine(to: CGPoint(x: toPoint.x, y: toPoint.y))
        context?.setBlendMode(CGBlendMode.normal)
        context?.setLineCap(CGLineCap.round)
        context?.setLineWidth(5)
        context?.setStrokeColor(color) //touchGesture.getColor()!)
        context?.strokePath()
        canvas.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            lastPoint = touch.location(in: canvas)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        swiped = true
        if let touch = touches.first {
            let currentPoint = touch.location(in: canvas)
            drawLines(fromPoint: lastPoint, toPoint: currentPoint)
            lastPoint = currentPoint
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !swiped {
            drawLines(fromPoint: lastPoint, toPoint: lastPoint)
        }
    }
    
    func createImageForMessage() -> UIImage? {
        let background = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        background.backgroundColor = UIColor.white
        
        let label = UILabel(frame: CGRect(x: 75, y: 75, width: 150, height: 150))
        label.font = UIFont.systemFont(ofSize: 56.0)
        label.backgroundColor = UIColor.red
        label.textColor = UIColor.white
        label.text = "\(gesture)" //touchGesture.getGesture()
        label.textAlignment = .center
        label.layer.cornerRadius = label.frame.size.width/2.0
        label.clipsToBounds = true
        
        background.addSubview(label)
        background.frame.origin = CGPoint(x: view.frame.size.width, y: view.frame.size.height)
        view.addSubview(background)
        
        UIGraphicsBeginImageContextWithOptions(background.frame.size, false, UIScreen.main.scale)
        background.drawHierarchy(in: background.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        background.removeFromSuperview()
        
        return image
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Conversation Handling
    
    override func willBecomeActive(with conversation: MSConversation) {
        // Called when the extension is about to move from the inactive to active state.
        // This will happen when the extension is about to present UI.
        
        // Use this method to configure the extension and restore previously stored state.
    }
    
    override func didResignActive(with conversation: MSConversation) {
        // Called when the extension is about to move from the active to inactive state.
        // This will happen when the user dissmises the extension, changes to a different
        // conversation or quits Messages.
        
        // Use this method to release shared resources, save user data, invalidate timers,
        // and store enough state information to restore your extension to its current state
        // in case it is terminated later.
    }
   
    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        // Called when a message arrives that was generated by another instance of this
        // extension on a remote device.
        
        // Use this method to trigger UI updates in response to the message.
    }
    
    override func didStartSending(_ message: MSMessage, conversation: MSConversation) {
        // Called when the user taps the send button.
    }
    
    override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {
        // Called when the user deletes the message without sending it.
    
        // Use this to clean up state related to the deleted message.
    }
    
    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        // Called before the extension transitions to a new presentation style.
    
        // Use this method to prepare for the change in presentation style.
    }
    
    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        // Called after the extension transitions to a new presentation style.
    
        // Use this method to finalize any behaviors associated with the change in presentation style.
    }

}
