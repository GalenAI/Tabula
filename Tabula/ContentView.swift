//
//  ContentView.swift
//  Tabula
//
//  Created by Mason on 10/1/22.
//

import SwiftUI
import AVFoundation
import Starscream
import WebKit

enum CurrentView {
    case landing, patientInfo, transcribing
}

class SocketDude : WebSocketDelegate {
    var socket: WebSocket!
    var isConnected = false
    let server = WebSocketServer()
    let binaryCallback : (Data) -> Void
    let stringCallback : (String) -> Void
    
    init(stringCallback: @escaping (String) -> Void, binaryCallback: @escaping (Data) -> Void) {
        self.stringCallback = stringCallback
        self.binaryCallback = binaryCallback

        var request = URLRequest(url: URL(string: "http://nuc.int.masonx.ca:9898")!)
        request.timeoutInterval = 5
        socket = WebSocket(request: request)
        socket.delegate = self
        socket.connect()
    }
    
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        print("\(event) rx event")
        switch event {
        case .connected(let headers):
            isConnected = true
            print("websocket is connected: \(headers)")
        case .disconnected(let reason, let code):
            isConnected = false
            print("websocket is disconnected: \(reason) with code: \(code)")
        case .text(let string):
            stringCallback(string)
        case .binary(let data):
            binaryCallback(data)
        case .ping(_):
            break
        case .pong(_):
            break
        case .viabilityChanged(_):
            break
        case .reconnectSuggested(_):
            break
        case .cancelled:
            isConnected = false
        case .error(let error):
            isConnected = false
            handleError(error)
        }
    }
    
    func transmitData(data: Data) {
        print("writing \(data) out!")
        socket.write(data: data)
    }

    func handleError(_ error: Error?) {
        if let e = error as? WSError {
            print("websocket encountered an error: \(e.message)")
        } else if let e = error {
            print("websocket encountered an error: \(e.localizedDescription)")
        } else {
            print("websocket encountered an error")
        }
    }
}

struct PatientAndOperation {
    let id: String
    let dob: String
    let name: String
    let opSide: String
    let opSite: String
    let allergies: [String]
}

struct PatientInfoView: View {
    let patient : PatientAndOperation
    let baseScale : CGFloat
    
    init(patient: PatientAndOperation, baseScale: Int) {
        self.patient = patient
        self.baseScale = CGFloat(baseScale)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer()
            VStack(alignment: .leading, spacing: 6) {
                Text("Patient").font(.system(size: baseScale*1.6))
                (Text("Patient ID: ").bold() + Text(patient.id)).font(.system(size: baseScale))
                (Text("Patient Date of Birth: ").bold() + Text(patient.dob)).font(.system(size: baseScale))
                (Text("Patient Name: ").bold() + Text(patient.name)).font(.system(size: baseScale))
                (Text("Known Allergies: ").bold() + Text(patient.allergies.joined(separator: ", "))).font(.system(size: baseScale))
            }
            Spacer()
            VStack(alignment: .leading, spacing: 6) {
                Text("Operation").font(.system(size: baseScale*1.6))
                (Text("Operation Side: ").bold() + Text(patient.opSide)).font(.system(size: baseScale))
                (Text("Operation Site: ").bold() + Text(patient.opSite)).font(.system(size: baseScale))
            }
            Spacer()
        }
    }
}

struct SevenAmMoment: Identifiable, Equatable {
    var id: UUID
    var pssss : String
}

struct ContentView: View {
    let engine = AVAudioEngine()

    var isPreview : Bool
    var myPatient : PatientAndOperation = PatientAndOperation(id: "001", dob: "2022-10-02", name: "Konwoo", opSide: "left", opSite: "abdomen", allergies: ["Digoxin"])
        
    @State var currentView : CurrentView
    @State var transcription : [SevenAmMoment] = []
    @State var mistakeDescription : String = ""
    @State var mistakeShowing : Bool = false

    init(isPreview: Bool) {
        self.isPreview = isPreview
        self.currentView = isPreview ? .transcribing : .landing
    }

    var body: some View {
        VStack {
            switch(currentView) {
            case .landing:
                Image("Logo")
                    .fixedSize()
                Text("Galen")
                    .font(.largeTitle)
                    .bold()
                    .padding()
                Button("Say \"Proceed\" to proceed") {
                    self.currentView = .patientInfo
                }
            case .patientInfo:
                Spacer()
                PatientInfoView(patient: myPatient, baseScale: 50)
                Spacer()
                Button("Say \"Confirm\" to continue") {
                    self.currentView = .transcribing
                }
            case .transcribing:
                HStack {
                    VStack {
                        Text("\(mistakeShowing ? mistakeDescription : "OK")")
                            .font(.largeTitle)
                            .background(mistakeShowing ? Color.init(red: 239/255, green: 59/255, blue: 70/255) : Color.init(red: 0, green: 150/255, blue: 71/255))
                            .foregroundColor(Color.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                        .background(mistakeShowing ? Color.init(red: 239/255, green: 59/255, blue: 70/255) : Color.init(red: 0, green: 150/255, blue: 71/255))
                        .foregroundColor(Color.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    VStack(alignment: .leading, spacing: 6) {
                        ScrollView {
                            ScrollViewReader { value in
                                ForEach(transcription) { tr in
                                    Text(tr.pssss)
                                        .font(.system(size: 30))
                                        .frame(maxWidth: .infinity)
                                        .foregroundColor((transcription.firstIndex(of: tr) ?? 100) < 2 ? Color.black : Color.gray)
                                }
                                .onChange(of: transcription) { _ in
                                    value.scrollTo(transcription.count - 1)
                                }
                            }
                        }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        PatientInfoView(patient: myPatient, baseScale: 20)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .foregroundColor(Color.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                    .background(Color.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accentColor(Color.white)
        .background(Color.init(red: 21/255, green: 53/255, blue: 111/255))
        .foregroundColor(Color.white)
        .onAppear {
            print("ContentView appeared!")
            if isPreview {
                return
            }

            var sockHandler = SocketDude(stringCallback: { str in
                do {
                    let jsonResult = try JSONSerialization.jsonObject(with: Data(str.utf8), options: .mutableContainers) as! NSDictionary
                    
                    // Parse JSON data
                    switch (jsonResult["mt"] as! String) {
                    case "transcription":
//                        transcription.$transcription.append(jsonResult["m"] as! String)
                        let stringData = jsonResult["m"] as! String
                        var res = stringData.components(separatedBy: CharacterSet(charactersIn: "!.?"))

                        res = res.reversed()
                        
                        for i in 0..<transcription.count {
                            transcription[i].pssss = res[i]
                        }
                        
                        if transcription.count < res.count {
                            for i in transcription.count..<res.count {
                                transcription.append(SevenAmMoment(id: UUID(), pssss: res[i]))
                            }
                        }
                    case "control":
                        let cmsg = jsonResult["m"] as! String
                        print("hi i'm here \(cmsg)")
                        if (cmsg == "proceed") {
                            if (self.currentView == .landing) {
                                self.currentView = .patientInfo
                            } else {
                                self.currentView = .transcribing
                            }
                        } else {
                            self.mistakeShowing = false
                            self.mistakeDescription = ""
                        }
                    case "mistake":
                        self.mistakeDescription = jsonResult["m"] as! String
                        self.mistakeShowing = true
                    default:
                        print("unknown msg from server")
                    }
                } catch {
                    print(error)
                }

                
            }, binaryCallback: { str in
                print(str)
            })

            let format = engine.inputNode.inputFormat(forBus: 0)
            let sampleRate = format.sampleRate
            print("Audio format: \(format) (Sample rate \(sampleRate))")

            // Tap the audio
            engine.inputNode.installTap(onBus: 0, // mono input
                                        // 44,100 samples per second => 5 times a second
                                        bufferSize: UInt32(sampleRate / 5.0), // a request, not a guarantee
                                        format: nil,      // no format translation
                                        block: { buffer, when in
                // This block will be called over and over for successive buffers
                // of microphone data until you stop() AVAudioEngine
                let actualSampleCount = Int(buffer.frameLength)
                if let data = buffer.floatChannelData {
                    let bufferSize = Int(actualSampleCount/3)
                    //var buffer = Array<Float32>(count: bufferSize, repeatedValue: 0.0)
                    sockHandler.transmitData(data: Data(buffer: UnsafeBufferPointer(start: data.pointee, count: 1))) //actualSampleCount)))
                }
            })
            
            // Start engine
            do {
                try engine.start()
            } catch {
                assertionFailure("AVAudioEngine start error: \(error)")
            }
        }

    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(isPreview: true)
            .previewInterfaceOrientation(.landscapeRight)
    }
}

// whispering --language en --model medium --host 0.0.0.0 --port 9898
