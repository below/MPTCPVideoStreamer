//
//  ViewController.swift
//  Videotest
//
//  Created by Alexander v. Below on 24.02.18.
//  Copyright © 2018 MPTCPHackathon. All rights reserved.
//

// Icon "Projector" by Lee Haywood, https://flic.kr/p/8PP7rT, (CC BY-SA 2.0)

import UIKit
import AVKit

class ViewController: UIViewController, URLSessionDelegate, URLSessionDownloadDelegate {
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var useMPTCPSwitch: UISwitch!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    var startTime : Date!
    var session : URLSession!
    var files : [URL] = []
    let queuePlayer = AVQueuePlayer.init()
    var currentSegmentNumber = 0
    var currentPriority : Float = 1.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    
    func url(segment: Int) -> URL {
        let string = String(format:"https://video.progmp.net/dash/out%d.mp4", segment)
        return URL(string: string)!
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let ttd = Date().timeIntervalSince(startTime)
        let bytesPerSecond = Double(totalBytesWritten) / ttd
        DispatchQueue.main.async {
            let output = String.init(format: "%.2f MBytes per Second", bytesPerSecond / 1000000)
            self.timeLabel.text = output
        }
    }
    
    @IBAction func download() {
        startTime = Date()
        activityIndicator.startAnimating()
        
        for url in files {
            do {
                try FileManager.default.removeItem(at: url)
            }
            catch {
                print ("\(url) could not be removed!")
            }
        }
        files = []
        currentSegmentNumber = 0
        
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        if self.useMPTCPSwitch.isOn {
            sessionConfiguration.multipathServiceType = .aggregate
        }
        else {
            sessionConfiguration.multipathServiceType = .none
        }
        sessionConfiguration.timeoutIntervalForRequest = 5
        session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
        

        self.loadSegment()
    }
    
    func loadSegment () {
        print ("Loading Segment \(currentSegmentNumber)")
        let url = self.url(segment: self.currentSegmentNumber)
        let request = URLRequest(url: url)
        let task = session.downloadTask(with: request)
        task.priority = currentPriority
        currentPriority = currentPriority - 0.05
        if currentPriority < 0.05 {
            currentPriority = 0.05
        }
        task.resume()

    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        var urlString = location.absoluteString
        urlString.append(".mp4")
        let newLocation = URL(string:urlString)!
        do {
            try FileManager.default.moveItem(at: location, to: newLocation)
        }
        catch {
            print ("FIRE IN THE HOLE!")
        }
        
        self.queuePlayer.insert(AVPlayerItem(url: newLocation) , after: queuePlayer.items().last)
        files.append(newLocation)
        print ("➕ Added segment \(currentSegmentNumber)")
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: newLocation.path)
            if let number = attributes[.size] as? NSNumber {
                let size = number.doubleValue
                let time = Date().timeIntervalSince(startTime)
                print (String(format: "File Size: %.2f MB, time: %.2f sec., %.2f MB/sec", size / 1000000, time, (size / 1000000) / time))
            }
            
        }
        catch {
            print ("Unable to get attributes for \(newLocation.path)")
        }
        
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.playButton.isEnabled = true
        }
        if currentSegmentNumber < 20 {
//            DispatchQueue.main.async {
//                self.performSegue(withIdentifier: "playVideo", sender: self)
//            }
            self.currentSegmentNumber = currentSegmentNumber + 1
            loadSegment()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
        }
        if let error = error {
            DispatchQueue.main.async {
                self.timeLabel.text = error.localizedDescription
            }
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let avController = segue.destination as? AVPlayerViewController {
            if let _ = files.first {
                print ("🏃‍♂️running with \(queuePlayer.items().count) items")
                avController.player = queuePlayer
                avController.player?.play()
            }
            else {
                print ("PANIC")
            }
        }
    }
}

