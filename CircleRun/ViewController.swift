//
//  ViewController.swift
//  CircleRun
//
//  Created by Mårten Björkman on 2018-02-21.
//  Copyright © 2018 Mårten Björkman. All rights reserved.
//

import UIKit
import QuartzCore
import CoreMotion

class ViewController: UIViewController {
    
    //MARK: Properties
    @IBOutlet weak var sessionIdField: UITextField!
    @IBOutlet weak var sessionNumField: UITextField!
    @IBOutlet weak var sessionLenField: UITextField!
    @IBOutlet weak var timePassedLabel: UILabel!
    @IBOutlet weak var completedLabel: UILabel!
    @IBOutlet weak var ipAddress: UITextField!
    @IBOutlet weak var ipPort: UITextField!
    @IBOutlet weak var messageField: UILabel!
    
    var displayLink: CADisplayLink!
    var initTimeStamp: CFTimeInterval!
    var lastTimeStamp: CFTimeInterval!
    var running = false
    var circleView: CircleView!
    var xp = 0.0, yp = 0.66
    var xl = 0.0, yl = 0.66
    var xv = 0.0, yv = 0.0
    var xa = 0.0, ya = 0.0
    var score = 0.0, sumWei = 0.0, numWei = 0.0
    var passed = false

    let motionManager = CMMotionManager()
    var motionTimer: Timer!
    var sessionLen: Double!
    var button: UIButton!
    
    let socketLink = SocketLink()
  
    var csound = CsoundObj()
    var csdFile: String?
    var csdPtr = [UnsafeMutablePointer<Float>?]()
    var csdPtrName = ["ax", "ay", "gx", "gy", "ball_x", "ball_y", "acc_ball", "vel_ball"]
    let T_AX = 0, T_AY = 1, T_GX = 2, T_GY = 3
    let B_PX = 4, B_PY = 5, B_ACC = 6, B_VEL = 7
  
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create DisplayLink timer
        displayLink = CADisplayLink(target: self, selector: #selector(update(_:)))
        displayLink.preferredFramesPerSecond = 30
        displayLink.add(to: RunLoop.current, forMode: RunLoopMode.commonModes)
        
        // Initial timestamp
        initTimeStamp = displayLink.timestamp
        lastTimeStamp = displayLink.timestamp
        sessionLen = Double(sessionLenField.text!)
        
        circleView = CircleView(frame: CGRect(x: 280, y: 30, width: 720, height: 720), shape: 0)
        circleView.backgroundColor = UIColor.white
        view.addSubview(circleView)
        
        //motionManager.startAccelerometerUpdates()
        //motionManager.startGyroUpdates()
        //motionManager.startMagnetometerUpdates()
        motionManager.startDeviceMotionUpdates()
        motionTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(ViewController.motionUpdate), userInfo: nil, repeats: true)

        //csound
        setupCsound()

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AppDelegate.AppUtility.lockOrientation(.landscapeLeft)
        socketLink.delegate = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AppDelegate.AppUtility.lockOrientation(.all)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //MARK: Actions
    @IBAction func startButton(_ sender: UIButton) {
        button = sender
        if running {
            sender.setTitle("Start", for: .normal)
            running = false
            socketLink.stopSession()

            stopCsound()
        } else {
            initTimeStamp = displayLink.timestamp
            lastTimeStamp = displayLink.timestamp
            self.xp = 0.66
            self.yp = 0.0
            self.xl = 0.66
            self.yl = 0.0
            self.xv = 0.0
            self.yv = 0.0
            self.xa = 0.0
            self.ya = 0.0
            self.score = 0.0
            self.sumWei = 0.0
            self.numWei = 0.0
            self.passed = false
            completedLabel.text = "0.00"
            sender.setTitle("Stop", for: .normal)
            running = true
            let port = Int(self.ipPort.text!)
            socketLink.setupNetworkCommunication(ipAddr: ipAddress.text!, ipPort: port!)
            let message = "celle"
            socketLink.startMessage(message: message)

            playCsound()
        }
    }
    
    func update(_ displayLink: CADisplayLink) {
        if running {
            let stepTime = displayLink.timestamp - initTimeStamp
            let str:String = String(format: "%0.2f", stepTime)
            timePassedLabel.text = str
            sessionLen = Double(sessionLenField.text!)
            if stepTime > sessionLen {
                button.setTitle("Start", for: .normal)
                running = false
                socketLink.stopSession()

                stopCsound()
            }
            updateMotion(t: displayLink.timestamp - lastTimeStamp)
            updateScore()
            let motion = motionManager.deviceMotion!.gravity
            let std = 0.2
            let xy = sqrt(self.xp*self.xp + self.yp*self.yp)
            let wei = exp(-(xy-2.0/3.0)*(xy-2.0/3.0)/(2.0*std*std))
            let message = String(format: "%.3f %.3f %.3f %.3f %0.3f %.3f ", motion.x, motion.y, motion.z, self.xp, self.yp, wei)
            socketLink.sendMessage(message: message)
            if socketLink.isRunning() {
                messageField.text = "Connected"
            } else {
                messageField.text = "Not connected"
            }
            circleView.setState(ballPos: CGPoint(x: self.yp, y: self.xp))
            circleView.setNeedsDisplay()
            lastTimeStamp = displayLink.timestamp
        } else {
            messageField.text = "Not connected"
        }
    }

    func updateMotion(t : Double) {
        if let deviceMotion = motionManager.deviceMotion {
            let x = deviceMotion.gravity.x
            let y = deviceMotion.gravity.y
            let z = deviceMotion.gravity.z
            let xy = (x==0.0 && y==0.0 ? sqrt(x*x + y*y) : 1.0)
            let gravity = 50.0
            let friction = 0.10
            let drag = 0.00025
            let Fn = gravity*(-z)
            let Ff = friction*Fn
            self.xa = gravity*x - Ff*x/xy
            self.ya = gravity*y - Ff*y/xy
            self.xl = self.xp
            self.yl = self.yp
            self.xp += self.xv*t
            self.yp += self.yv*t
            let dist0 = sqrt(self.xp*self.xp + self.yp*self.yp)
            let distB = dist0 - 2.0/3.0
            let slope = -0.2*distB
            let slopeX = slope*(dist0>0.0 ? self.xp/dist0 : 1.0)
            let slopeY = slope*(dist0>0.0 ? self.yp/dist0 : 1.0)
            self.xp += slopeX
            self.yp += slopeY
            self.xv = self.xv*(1.0 - drag) + self.xa*t + (t>0.0 ? slopeX/t : 0)
            self.yv = self.yv*(1.0 - drag) + self.ya*t + (t>0.0 ? slopeY/t : 0)
            let lim = 0.88
            if self.xp>lim {
                let frac = (self.xp == self.xl ? 1.0 : (lim - self.xl)/(self.xp - self.xl))
                self.xv = -self.xv*0.3
                self.xp = lim + (1.0 - frac)*self.xv*t
            }
            if self.xp<(-lim) {
                let frac = (self.xp == self.xl ? 1.0 : (-lim - self.xl)/(self.xp - self.xl))
                self.xv = -self.xv*0.3
                self.xp = -lim + (1.0 - frac)*self.xv*t
            }
            if self.yp>lim {
                let frac = (self.yp == self.yl ? 1.0 : (lim - self.yl)/(self.yp - self.yl))
                self.yv = -self.yv*0.3
                self.yp = lim + (1.0 - frac)*self.yv*t
            }
            if self.yp<(-lim) {
                let frac = (self.yp == self.yl ? 1.0 : (-lim - self.yl)/(self.yp - self.yl))
                self.yv = -self.yv*0.3
                self.yp = -lim + (1.0 - frac)*self.yv*t
            }

            if !csdPtr.isEmpty && self.running {
                self.csdPtr[T_AX]?.pointee = Float(deviceMotion.userAcceleration.x)
                self.csdPtr[T_AY]?.pointee = Float(deviceMotion.userAcceleration.y)
                self.csdPtr[T_GX]?.pointee = Float(deviceMotion.rotationRate.x)
                self.csdPtr[T_GY]?.pointee = Float(deviceMotion.rotationRate.y)
            }

            let str:String = String(format: "%0.2f %0.2f %0.2f %0.2f %0.2f %0.2f", self.xp, self.yp, self.xv, self.yv, slopeX, slopeY)
            print(str)
        }
    }
    
    func updateScore() {
        if self.yp>=0.0 && self.yl<0.0 && self.xp>0.0 && self.passed {
            self.score += 1.0
            self.passed = false
            let str:String = String(format: "%0.2f", self.score*self.sumWei/self.numWei)
            print(str)
            completedLabel.text = str
        }
        if self.yp<=0.0 && self.yl>0.0 && self.xp<0.0 {
            self.passed = true
        }
        let xy = sqrt(self.xp*self.xp + self.yp*self.yp)
        let std = 0.2
        let wei = exp(-(xy-2.0/3.0)*(xy-2.0/3.0)/(2.0*std*std))
        self.sumWei += wei
        self.numWei += 1.0
    }
    
    @objc func motionUpdate() {
        /*if let data = motionManager.accelerometerData {
            let len = sqrt(data.acceleration.x*data.acceleration.x + data.acceleration.y*data.acceleration.y + data.acceleration.z*data.acceleration.z)
            let str:String = String(format: "%d %d", Int(100.0*data.acceleration.x/len), Int(100.0*data.acceleration.y/len))
            print(str)
        }*/
        /*if let gyroData = motionManager.gyroData {
            print(gyroData)
        }
        if let magnetometerData = motionManager.magnetometerData {
            print(magnetometerData)
        }*/
        /* if let deviceMotion = motionManager.deviceMotion {
            print(deviceMotion.gravity.x)
        } */
    }

    func setupCsound() {
        self.csdFile = Bundle.main.path(forResource: "Vincent2", ofType: "csd")
        csound.stop()
        csound = CsoundObj()
        csound.addBinding(self)
        csound.play(self.csdFile)
    }

    func playCsound() {
        csound.sendScore("i1 0 2000")
    }

    func stopCsound() {
        for cPtr in self.csdPtr {
            cPtr?.pointee = 0
        }
    }
}

extension ViewController: SocketLinkDelegate {
    func receivedMessage(message: String) {
        print("received")
        print(message)
        //insertNewMessageCell(message)
    }
}

// MARK: Csound Binding
extension ViewController: CsoundBinding {
    func setup(_ csoundObj: CsoundObj!) {
        for name in self.csdPtrName {
            self.csdPtr.append(csound.getInputChannelPtr(name, channelType: CSOUND_CONTROL_CHANNEL))
        }
    }

    func updateValuesToCsound() {
        if !csdPtr.isEmpty {
            /* TODO: ball kinematic values should be modified with
             * based on the linear coordinates of the display (1024x768).
             * Ball position x allowed from 158 to 866 px
             * Ball position y allowed from 30 to 735 px
             * Net ball acceleration (px/s^2) and velocity (px/s) are needed
             */
            if self.running {
                self.csdPtr[B_PX]?.pointee = (Float(self.xp+1)*765)/2 // ball position x (px)
                self.csdPtr[B_PY]?.pointee = (Float(self.yp+1)*765)/2 // ball position y (px)
                self.csdPtr[B_ACC]?.pointee = Float(sqrt(self.xa*self.xa + self.ya*self.ya)) // net ball acceleration
                self.csdPtr[B_VEL]?.pointee = Float(sqrt(self.xv*self.xv + self.yv*self.yv)) // net ball velocity
            }
        }
    }
}
