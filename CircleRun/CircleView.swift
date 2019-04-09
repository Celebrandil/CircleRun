//
//  CircleView.swift
//  CircleRun
//
//  Created by Mårten Björkman on 2018-02-21.
//  Copyright © 2018 Mårten Björkman. All rights reserved.
//

import UIKit

class CircleView: UIView {

    var currentShapeType: Int = 0
    var ballPos: CGPoint = CGPoint(x: 0.0, y: 0.66)
    
    init(frame: CGRect, shape: Int) {
        super.init(frame: frame)
        self.currentShapeType = shape
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func draw(_ rect: CGRect) {
        //print("draw")
        switch currentShapeType {
        case 0:
            drawCircle()
            drawBall()
        case 1: drawLines()
        case 2: drawCircle()
        default: print("default")
        }
    }
    
    func setState(ballPos: CGPoint) {
        self.ballPos = ballPos
    }
    
    func drawLines() {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 20.0, y: 20.0))
        ctx.addLine(to: CGPoint(x: 250.0, y: 100.0))
        ctx.addLine(to: CGPoint(x: 100.0, y: 200.0))
        ctx.setLineWidth(5)
        ctx.closePath()
        ctx.strokePath()
    }
    
    func drawRectangle() {
        let center = CGPoint(x: self.frame.size.width / 2.0, y: self.frame.size.height / 2.0)
        let rectangleWidth:CGFloat = 100.0
        let rectangleHeight:CGFloat = 100.0
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.addRect(CGRect(x: center.x - (0.5 * rectangleWidth), y: center.y - (0.5 * rectangleHeight), width: rectangleWidth, height: rectangleHeight))
        ctx.setLineWidth(10)
        ctx.setStrokeColor(UIColor.gray.cgColor)
        ctx.strokePath()
        ctx.setFillColor(UIColor.green.cgColor)
        ctx.addRect(CGRect(x: center.x - (0.5 * rectangleWidth), y: center.y - (0.5 * rectangleHeight), width: rectangleWidth, height: rectangleHeight))
        ctx.fillPath()
    }
    
    func drawBall() {
        let center = CGPoint(x: self.frame.size.width*CGFloat((1.0 + ballPos.x)/2.0), y: self.frame.size.height*CGFloat((1.0 + ballPos.y)/2.0))
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let x:CGFloat = center.x
        let y:CGFloat = center.y
        let radius: CGFloat = self.frame.size.width / 20.0
        let endAngle: CGFloat = CGFloat(2 * Double.pi)
        ctx.beginPath()
        ctx.setLineWidth(self.frame.size.width / 72.0)
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.addArc(center: CGPoint(x: x,y: y), radius: radius, startAngle: 0, endAngle: endAngle, clockwise: true)
        ctx.strokePath()
        ctx.setFillColor(UIColor.red.cgColor)
        ctx.addArc(center: CGPoint(x: x,y: y), radius: radius, startAngle: 0, endAngle: endAngle, clockwise: true)
        ctx.fillPath()
    }
    
    func drawCircle() {
        let center = CGPoint(x: self.frame.size.width / 2.0, y: self.frame.size.height / 2.0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.beginPath()
        ctx.setLineWidth(self.frame.size.width / 36.0)
        let x:CGFloat = center.x
        let y:CGFloat = center.y
        var radius: CGFloat = self.frame.size.width / 3.0
        let endAngle: CGFloat = CGFloat(2 * Double.pi)
        ctx.addArc(center: CGPoint(x: x,y: y), radius: radius, startAngle: 0, endAngle: endAngle, clockwise: true)
        ctx.strokePath()
        ctx.setFillColor(UIColor.black.cgColor)
        radius = self.frame.size.width / 50.0
        ctx.addArc(center: CGPoint(x: x,y: y), radius: radius, startAngle: 0, endAngle: endAngle, clockwise: true)
        ctx.fillPath()
        ctx.beginPath()
        ctx.move(to: CGPoint(x: self.frame.size.width / 2.0, y: 0.0))
        ctx.addLine(to: CGPoint(x: self.frame.size.width / 2.0, y: self.frame.size.height))
        ctx.setLineWidth(self.frame.size.width / 144.0)
        ctx.closePath()
        ctx.strokePath()
    }
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
