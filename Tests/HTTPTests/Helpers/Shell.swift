// This source file is part of the Swift.org Server APIs open source project
//
// Copyright (c) 2017 Swift Server API project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
//


import Foundation

class Shell
{
    // MARK: public
    
    //
    public func findAndExecute(commandName: String, arguments: [String]) -> String? {
        //  /bin/bash -l -c "which CMD"
        guard var pathOfCommand = execute(command: "/bin/bash" , arguments:[ "-l", "-c", "which \(commandName)" ]) else {
            return nil
        }
        // alternatively we can check the result of the command: 0=found, 1=not found
        guard pathOfCommand != "" else {
            print("Command \(commandName) not found")
            return nil
        }
        
        pathOfCommand = pathOfCommand.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return execute(command: pathOfCommand, arguments: arguments)
    }
    
    public func execute(command: String, arguments: [String] = []) -> String? {
        let task = Process()
        task.launchPath = command
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output: String? = String(data: data, encoding: String.Encoding.utf8)
        
        return output
    }
}
