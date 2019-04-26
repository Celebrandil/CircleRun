//
//  Socket.swift
//  CircleRun
//
//  Created by Mårten Björkman on 2018-03-28.
//  Copyright © 2018 Mårten Björkman. All rights reserved.
//
import UIKit

protocol SocketLinkDelegate: class {
    func receivedMessage(message: String)
}

class SocketLink: NSObject {
    weak var delegate: SocketLinkDelegate?
    
    var inputStream: InputStream?
    var outputStream: OutputStream?
    
    let maxReadLength = 1024
    var running = false
    
    func setupNetworkCommunication(ipAddr: String, ipPort: Int) {
        Stream.getStreamsToHost(withName: ipAddr, port: ipPort, inputStream: &self.inputStream, outputStream: &self.outputStream)
        
        inputStream!.delegate = self
        outputStream!.delegate = self
        
        inputStream!.schedule(in: .main, forMode: .commonModes)
        outputStream!.schedule(in: .main, forMode: .commonModes)
        
        inputStream!.open()
        outputStream!.open()
        
        running = true
    }
    
    func startMessage(message: String) {
        let data = "GET \(message)".data(using: .ascii)!
        print("startMessage")
        print(data)
        _ = data.withUnsafeBytes { outputStream!.write($0, maxLength: data.count) }
    }
    
    func sendMessage(message: String) {
        let data = "DATA \(message)".data(using: .ascii)!
        _ = data.withUnsafeBytes { outputStream!.write($0, maxLength: data.count) }
    }
    
    func stopSession() {
        inputStream!.close()
        outputStream!.close()
        running = false
    }
    
    func isRunning() -> Bool {
        return running
    }
}

extension SocketLink: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.hasBytesAvailable:
            print("new message received")
            readAvailableBytes(stream: aStream as! InputStream)
        case Stream.Event.endEncountered:
            stopSession()
        case Stream.Event.errorOccurred:
            running = false
            print("error occurred")
        case Stream.Event.hasSpaceAvailable:
            print("has space available")
        case Stream.Event.openCompleted:
            print("open completed")
        default:
            print("some other event...")
            break
        }
    }
    
    private func readAvailableBytes(stream: InputStream) {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadLength)
        while stream.hasBytesAvailable {
            let numberOfBytesRead = inputStream!.read(buffer, maxLength: maxReadLength)
            if numberOfBytesRead < 0 {
                if let _ = inputStream!.streamError {
                    break
                }
            }
            if let message = processedMessageString(buffer: buffer, length: numberOfBytesRead) {
                delegate?.receivedMessage(message: message)
            }
        }
    }
    
    private func processedMessageString(buffer: UnsafeMutablePointer<UInt8>, length: Int) -> String? {
        guard let stringArray = String(bytesNoCopy: buffer, length: length, encoding: .ascii,
                                       freeWhenDone: true)?.components(separatedBy: ":"),
        let message = stringArray.first else {
            return nil
        }
        return message
    }
}
