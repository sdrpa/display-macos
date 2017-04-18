/**
 Created by Sinisa Drpa on 2/13/17.

 Display is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License or any later version.

 Display is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Display.  If not, see <http://www.gnu.org/licenses/>
 */

import AirspaceKit
import ATCKit
import Cocoa
import FDPS
import FoundationKit
import Measure
import Socket

final class MainWindowController: NSWindowController {

    var mapView: MapView?
    let client = FDPClient(server: "localhost", port: 1337)

    fileprivate var lastDragLocation = CGPoint.zero

    override func windowDidLoad() {
        guard let window = self.window else {
            fatalError()
        }
        self.mapView = MapView(frame: CGRect(origin: CGPoint.zero, size: window.frame.size))
        guard let mapView = self.mapView else {
            fatalError()
        }
        mapView.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        window.center()
        window.contentView?.addSubview(mapView)
        window.makeFirstResponder(self)

        let directoryURL = URL(fileURLWithPath: "/Users/sdrpa/Development/ATC/Data/Airspace/Demo")
        guard let airspace = Airspace(directoryURL: directoryURL) else {
            fatalError()
        }
        mapView.airspace = airspace
        mapView.center = Coordinate(latitude: 43.9, longitude: 20.16)

        self.client.flightsUpdate = { [weak self] flights in
            self?.mapView?.flights = flights
        }
    }
}

extension MainWindowController {

    override func mouseDown(with event: NSEvent) {
        guard let mapView = self.mapView else {
            return
        }
        self.lastDragLocation = mapView.locationInView(with: event) ?? CGPoint.zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mapView = self.mapView,
            let dragLocation = mapView.locationInView(with: event) else {
                return
        }
        let lastDragLocationCoord = mapView.coordinate(for: self.lastDragLocation)
        let dragLocationCoord = mapView.coordinate(for: dragLocation)

        let distance = dragLocationCoord.distance(to: lastDragLocationCoord)
        let bearing = dragLocationCoord.bearing(to: lastDragLocationCoord)

        let center = mapView.center.coordinate(at: distance, bearing: bearing)
        mapView.center = center

        self.lastDragLocation = dragLocation
    }

    override func mouseMoved(with event: NSEvent) {
        guard let mapView = self.mapView,
            let location = mapView.locationInView(with: event) else {
                return
        }
        let coordinate = mapView.coordinate(for: location)
        mapView.debug = coordinate.description
    }

    public override func magnify(with event: NSEvent) {
        guard let mapView = self.mapView else {
            return super.magnify(with: event)
        }
        mapView.zoom -= Double(event.magnification)
    }

    // MARK:

    public override func keyDown(with event: NSEvent) {
        guard let mapView = self.mapView else {
            return super.keyDown(with: event)
        }
        if event.modifierFlags.contains(.command) {
            Swift.print("Command is pressed")
        }
        let chars = event.charactersIgnoringModifiers ?? ""
        switch chars {
        case "z":
            mapView.zoomIn()
        case "Z":
            mapView.zoomOut()
        case "c":
            let screen = mapView.convert(event.locationInWindow, from: nil)
            let center = mapView.coordinate(for: screen)
            mapView.center = center
        case "C":
            let center = Coordinate(latitude: 43.9, longitude: 20.16)
            mapView.center = center

        default:
            super.keyDown(with: event)
        }
    }
}

extension MainWindowController {

    override var windowNibName: String? {
        return "\(MainWindowController.self)"
    }
}
