//
//  ViewController.swift
//  SwiftOCR Training
//
//  Created by Nicolas Camenisch on 02.05.16.
//  Copyright © 2016 Nicolas Camenisch. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate {

    @IBOutlet weak var fontsTableView: NSTableView!
    @IBOutlet weak var startTrainingButton: NSButton!
    @IBOutlet weak var addAllFontsButton: NSButton!
    @IBOutlet weak var charactersToTrainTextField: NSTextField!
    @IBOutlet weak var trainingProgressIndicator: NSProgressIndicator!
    
    @IBOutlet weak var accuracyLabel: NSTextField!
    
    var allFontNames      = [String]()
    var selectedFontNames = [String]()
    var isTraining        = false

    let trainingInstance  = SwiftOCRTraining()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        globalNetwork = FFNN(inputs: 321, hidden: 100, outputs: recognizableCharacters.count, learningRate: 0.7, momentum: 0.4, weights: nil, activationFunction: .Sigmoid, errorFunction: .crossEntropy(average: false))
        
        allFontNames = NSFontManager.shared.availableFonts.filter {
            return !$0.hasPrefix(".")
        }
        
        charactersToTrainTextField.delegate = self
        
        fontsTableView.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return allFontNames.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        if (tableColumn?.identifier)!.rawValue == "0" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "fontCell"), owner: self) as! NSTableCellView
            let fontName = allFontNames[row]
            cell.textField?.stringValue = NSFont(name: fontName, size: 0)?.displayName ?? ""
            return cell
        } else {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "buttonCell"), owner: self) as! ButtonTableCellView
            let fontName = allFontNames[row]
            
            if selectedFontNames.contains(fontName) {
                cell.button.integerValue = 1
            }
            
            cell.button.identifier = NSUserInterfaceItemIdentifier(rawValue: fontName)
            
            return cell
        }
        
    }

    @objc @IBAction func buttonTableCellViewButtonPressed(_ sender: NSButton) {
        if sender.integerValue == 0 {
            if let index = selectedFontNames.index(of: sender.identifier?.rawValue ?? "") {
                selectedFontNames.remove(at: index)
            }
        } else {
            if let fontName = sender.identifier {
                selectedFontNames.append(fontName.rawValue)
            }
        }
    }
    
    func controlTextDidChange(_ obj: Notification) {
        //Generate new training network
        recognizableCharacters = ""
        
        charactersToTrainTextField.stringValue.forEach({
            guard !recognizableCharacters.contains($0) else {return}
            recognizableCharacters.append($0)
        })
        
        charactersToTrainTextField.stringValue = recognizableCharacters
        globalNetwork = FFNN(inputs: 321, hidden: 100, outputs: recognizableCharacters.count, learningRate: 0.7, momentum: 0.4, weights: nil, activationFunction: .Sigmoid, errorFunction: .crossEntropy(average: false))
    }
    
    @objc @IBAction func saveButtonPressed(_ sender: NSButton) {
        trainingInstance.saveOCR()
    }
    
    @objc @IBAction func startTrainingButtonPressed(_ sender: NSButton) {
        
        if isTraining {
            startTrainingButton.title = "Start Training"
            isTraining = false
            trainingProgressIndicator.stopAnimation(nil)
        } else {
            
            if selectedFontNames.isEmpty {
                return
            }
            
            startTrainingButton.title = "Stop Training"
            isTraining = true
            
            trainingProgressIndicator.startAnimation(nil)
            
            DispatchQueue.global().async {
                
                var callbackCount      = 0
                var minimumError:Float = Float.infinity {
                    didSet {
                        minimumError = min(oldValue, minimumError)
                    }
                }
                
                self.trainingInstance.trainingFontNames = self.selectedFontNames
                self.trainingInstance.trainWithCharSet() { error in
                    minimumError   = error
                    callbackCount += 1

                    if !self.isTraining {
                        return false
                    } else if minimumError + 2 < error && callbackCount >= 150 {
                        return false
                    } else {
                        return true
                    }
   
                }
                
                DispatchQueue.main.async {
                    
                    if self.isTraining == true {
                        self.startTrainingButton.title = "Start Training"
                        self.isTraining                = false
                        self.trainingProgressIndicator.stopAnimation(nil)
                    }
                }
                
            }
            
        }
        
    }

    @objc @IBAction func addAllFontsButtonPressed(_ sender: NSButton) {
        if allFontNames == selectedFontNames {
            selectedFontNames.removeAll()
            addAllFontsButton.title = "Add all Fonts"
            fontsTableView.reloadData()
        } else {
            selectedFontNames = allFontNames
            addAllFontsButton.title = "Remove all Fonts"
            fontsTableView.reloadData()
        }
    }
    
    @objc @IBAction func testButtonPressed(_ sender: NSButton) {
        startTrainingButton.title = "Start Training"
        isTraining = false
        
        self.accuracyLabel.stringValue = "Testing..."

        DispatchQueue.global().async {
            self.trainingInstance.testOCR() {accuracy in
                DispatchQueue.main.async {
                    self.accuracyLabel.stringValue = "Accuracy: \(round(accuracy * 1000) / 10)%"
                }
            }
        }
    }
}

