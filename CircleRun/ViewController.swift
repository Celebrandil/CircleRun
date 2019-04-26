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
//import AudioKit
//import AudioKitUI

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
  
//    var oscillator1 = AKOscillator()
//    var oscillator2 = AKOscillator()
//    var mixer = AKMixer()
//
//    required init?(coder aDecoder: NSCoder) {
//      super.init(coder: aDecoder)
//      mixer = AKMixer(oscillator1, oscillator2)
//
//      // Cut the volume in half since we have two oscillators
//      mixer.volume = 0.5
//      AudioKit.output = mixer
//      do {
//        AKSettings.playbackWhileMuted = true
//        try AudioKit.start()
//        oscillator1.frequency = random(in: 220 ... 880)
//        oscillator2.frequency = random(in: 220 ... 880)
//      } catch {
//        AKLog("AudioKit did not start!")
//      }
//    }
  
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
//            oscillator1.stop()
//            oscillator2.stop()
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
//            oscillator1.start()
//            oscillator2.start()
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
//                oscillator1.stop()
//                oscillator2.stop()
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
//            self.oscillator1.frequency = pow(2.0, self.xp-0.25)*440.0
//            self.oscillator2.frequency = pow(2.0, self.yp+0.25)*440.0
            //let str:String = String(format: "%0.2f %0.2f %0.2f %0.2f %0.2f %0.2f", self.xp, self.yp, self.xv, self.yv, slopeX, slopeY)
            //print(str)
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
}

extension ViewController: SocketLinkDelegate {
    func receivedMessage(message: String) {
        print("received")
        print(message)
        //insertNewMessageCell(message)
    }
}


