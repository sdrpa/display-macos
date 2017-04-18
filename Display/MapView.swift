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
import Projection
import Quartz
import Measure

public final class MapView: NSView {

    public var flights: [Flight]? {
        didSet {
            self.needsDisplay = true
        }
    }
    public var debug: String? {
        didSet {
            self.needsDisplay = true
        }
    }

    public var airspace: Airspace? {
        didSet {
            self.needsDisplay = true
        }
    }
    public var center: Coordinate {
        didSet {
            self.calculateST()
        }
    }
    public var range = Meter(Nm(350.0))

    fileprivate var _zoom = 1.0
    var zoom: Double {
        set {
            self._zoom = newValue.clamped(to: 0.1...7.0)
            self.calculateST()
        }
        get {
            return self._zoom
        }
    }

    fileprivate let proj = PROJ()

    fileprivate typealias Boundary = (xmin: Double, xmax: Double, ymin: Double, ymax: Double)
    fileprivate var s: Boundary // Source coord system in meters
    fileprivate var t: Boundary // Target coord system in points

    public override init(frame frameRect: NSRect) {
        self.center = Coordinate(latitude: 30, longitude: 31)
        let length = Double(min(frameRect.maxX, frameRect.maxY))
        self.s = (xmin: 0, xmax: 10_000, ymin: 0, ymax: 10_000)
        self.t = (xmin: Double(frameRect.minX), xmax: length, ymin: Double(frameRect.minY), ymax: length)

        super.init(frame: frameRect)

        self.calculateST()

        self.wantsLayer = true
        self.layer?.backgroundColor = .black
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var acceptsFirstResponder: Bool {
        return true
    }

    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        guard let _ = newWindow else { return }

        let options: NSTrackingAreaOptions = [.activeInActiveApp, .inVisibleRect, .mouseMoved]
        let trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }

    func zoomIn() {
        self.zoom += 0.15
    }

    func zoomOut() {
        self.zoom -= 0.15
    }

    /// Returns screen location for the coordinate
    public func screenLocation(for coordinate: Coordinate) -> CGPoint {
        guard let w = self.proj.world(from: coordinate) else {
            fatalError()
        }
        let screen = self.convert(point: CGPoint(x: CGFloat(w.x.v), y: CGFloat(w.y.v)), from: self.s, to: self.t)
        return screen
    }

    /// Returns coordinate for the screen location
    public func coordinate(for screen: CGPoint) -> Coordinate {
        let loc = self.convert(point: screen, from: self.t, to: self.s)
        let w = WorldCoordinate(x: Meter(Double(loc.x)), y: Meter(Double(loc.y)))
        guard let coord = self.proj.coordinate(from: w) else {
            fatalError()
        }
        return coord
    }

    public override func draw(_ rect: CGRect) {
        if let coordinates = self.airspace?.layers.first?.coordinates {
            self.draw(connecting: coordinates)
        }
        if let points = self.airspace?.points {
            self.draw(navigationPoints: points, size: CGSize(width: 3, height: 3))
        }
        if let ndbs = self.airspace?.ndbs {
            self.draw(navigationPoints: ndbs, size: CGSize(width: 4, height: 4), color: .yellow)
        }
        if let vors = self.airspace?.vors {
            self.draw(navigationPoints: vors, size: CGSize(width: 6, height: 6), color: .green)
        }
        if let flights = self.flights {
            self.draw(flights: flights)
        }
        if let debug = self.debug {
            self.draw(text: debug, at: CGPoint(x: 10, y: 10), foregroundColor: .white, backgroundColor: .black)
        }
    }

    /**
     Drawable state object needs a way to draw itself.
     Calling the map view draw(_ rect:) from the state object won't help.
     Instead use needsDisplay(in:) from the state object to mark the region of the map view
     as needing display. Then the map view then will use state object's draw: to perform drawing
     */
    func needsDisplay(in rect: CGRect) {
        self.setNeedsDisplay(rect)
    }
}

public extension MapView {

    fileprivate func draw(connecting coordinates: [Coordinate]) {
        guard let first = coordinates.first else {
            return
        }
        let path = NSBezierPath()
        let screen = self.screenLocation(for: first)
        path.move(to: CGPoint(x: screen.x, y: screen.y))
        var i = 1
        var marker = true
        while i < coordinates.count {
            marker = (coordinates[i].latitude == 10.0) || (coordinates[i].latitude == 10.0)
            if marker {
                i += 1
            }
            let screen = self.screenLocation(for: coordinates[i])
            if marker {
                path.move(to: CGPoint(x: screen.x, y: screen.y))
            } else {
                path.line(to: CGPoint(x: screen.x, y: screen.y))
            }
            i += 1
        }
        NSColor.gray.setStroke()
        path.stroke()
    }

    fileprivate func draw(navigationPoints: [NavigationPoint], size: CGSize, color fillColor: NSColor = .gray) {
        func drawSymbol(forNavaid: NavigationPoint, at position: CGPoint) {
            let origin = CGPoint(x: CGFloat(position.x) - size.width/2,
                                 y: CGFloat(position.y) - size.height/2)
            let frame = CGRect(origin: origin, size: size)

            let path = NSBezierPath()
            path.lineWidth = 1
            path.move(to: CGPoint(x: frame.minX, y: frame.minY))
            path.line(to: CGPoint(x: frame.midX, y: frame.maxY))
            path.line(to: CGPoint(x: frame.maxX, y: frame.minY))
            path.close()

            fillColor.setFill()
            //NSColor.gray.setStroke()
            path.fill()
            //path.stroke()
        }

        for point in navigationPoints {
            let screen = self.screenLocation(for: point.coordinate)
            if !self.frame.contains(screen) {
                continue
            }
            drawSymbol(forNavaid: point, at: screen)

            let offset = CGPoint(x: 5, y: 5)
            draw(text: point.title, at: CGPoint(x: screen.x + offset.x, y: screen.y + offset.y), foregroundColor: .darkGray)
        }
    }

    fileprivate func draw(flights: [Flight]) {

        func drawTarget(forFlight flight: Flight, at position: CGPoint) -> CGRect {
            let rectSize = CGSize(width: 6, height: 6)
            let origin = CGPoint(x: CGFloat(position.x) - rectSize.width/2,
                                 y: CGFloat(position.y) - rectSize.height/2)
            let rect = CGRect(origin: origin, size: rectSize)
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 1
            NSColor.darkGray.setFill()
            path.fill()
            NSColor.white.setStroke()
            path.stroke()

            return rect
        }

        func drawLabelRect(forFlight flight: Flight, at position: CGPoint, borderColor: NSColor = .white) -> CGRect {
            let rectSize = CGSize(width: 100, height: 55)
            let origin = CGPoint(x: position.x - 10, y: position.y + 20 - rectSize.height)
            let rect = CGRect(origin: origin, size: rectSize)
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 1
            borderColor.setStroke()
            path.stroke()
            NSColor.black.setFill()
            path.fill()

            return rect
        }

        func drawLabelText(forFlight flight: Flight, at position: CGPoint) {
            draw(text: flight.callsign + " " + (flight.flightPlan?.aircraft.code.rawValue ?? ""), at: position)
            draw(text:
                String(format: "%.0f", flight.flightLevel.v),
                 at: CGPoint(x: position.x, y: position.y - 15))
            draw(text:
                String(format: "M%.1f", flight.mach.v) + " " +
                String(format: "H%.0f", flight.heading.v),
                 at: CGPoint(x: position.x, y: position.y - 30))
        }

        func drawLeaderLine(from rec1: CGRect, to rect2: CGRect) {
            let path = NSBezierPath()
            path.lineWidth = 1
            path.move(to: CGPoint(x: rec1.maxX, y: rec1.maxY))
            path.line(to: CGPoint(x: rect2.minX, y: rect2.minY))
            NSColor.white.setStroke()
            path.stroke()
        }

        for flight in flights {
            drawTrajectory(flight: flight)

            let screen = self.screenLocation(for: flight.position.coordinate)
            // Draw target
            let target = drawTarget(forFlight: flight, at: screen)
            // Draw label
            let offset = CGPoint(x: 25, y: 50)
            let position = CGPoint(x: ceil(screen.x + offset.x), y: ceil(screen.y + offset.y))
            let label = drawLabelRect(forFlight: flight, at: position)
            drawLabelText(forFlight: flight, at: position)
            // Draw leader
            drawLeaderLine(from: target, to: label)
        }
    }

    func draw(minimumDistanceBetween first: Flight, and second: Flight) {
        
    }

    func drawTrajectory(flight: Flight) {
        guard let route = flight.flightPlan?.route,
            let firstPoint = route.navigationPoints.first else {
                return
        }
        let path = NSBezierPath()
        path.lineWidth = 1
        let firstPointScreen = self.screenLocation(for: firstPoint.coordinate)
        path.move(to: CGPoint(x: firstPointScreen.x, y: firstPointScreen.y))

        for navigationPoint in route.navigationPoints {
            let screen = self.screenLocation(for: navigationPoint.coordinate)
            path.line(to: CGPoint(x: screen.x, y: screen.y))
            if let timestamp = route.timestamp(for: navigationPoint) {
                let offset = CGPoint(x: 5, y: 5)
                draw(text: String(format: "%.1f", timestamp/60),
                     at: CGPoint(x: ceil(screen.x + offset.x), y: ceil(screen.y + offset.y)),
                     foregroundColor: NSColor.green)
            }
        }
        NSColor.green.setStroke()
        path.stroke()
    }

    func draw(text: String, at location: CGPoint, foregroundColor: NSColor = .white, backgroundColor: NSColor = .clear) {
        if !self.frame.contains(location) {
            return
        }
        guard let font = NSFont(name: "HelveticaNeue", size: 12) else {
            fatalError()
        }
        let attributes: [String : AnyObject] =
            [NSFontAttributeName: font,
             NSForegroundColorAttributeName: foregroundColor,
             NSBackgroundColorAttributeName: backgroundColor]
        let text = NSAttributedString(string: text, attributes: attributes)
        self.draw(attributed: text, at: location)
    }

    func draw(attributed string: NSAttributedString, at location: CGPoint) {
        string.draw(at: location)
    }
}

fileprivate extension MapView {

    fileprivate func calculateST() {
        let center = self.center
        let half = Double(self.range/2)
        let distance = Meter(half * self.zoom)

        let minX = center.coordinate(at: distance, bearing: 270)
        let maxX = center.coordinate(at: distance, bearing: 90)
        let minY = center.coordinate(at: distance, bearing: 180)
        let maxY = center.coordinate(at: distance, bearing: 0)

        guard let xmin = self.proj.world(from: minX)?.x,
            let ymin = self.proj.world(from: minY)?.y,
            let xmax = self.proj.world(from: maxX)?.x,
            let ymax = self.proj.world(from: maxY)?.y else {
                fatalError()
        }
        let length = Double(min(self.frame.maxX, self.frame.maxY))
        self.s = (xmin: Double(xmin), xmax: Double(xmax), ymin: Double(ymin), ymax: Double(ymax))
        self.t = (xmin: Double(self.frame.minX), xmax: length, ymin: Double(self.frame.minY), ymax: length)

        self.needsDisplay = true
    }

    /// http://gamedev.stackexchange.com/questions/32555/how-do-i-convert-between-two-different-2d-coordinate-systems
    /// S (min, max) <-> T (min, max)
    fileprivate func convert(_ v: Double, from s: (Double, Double), to t: (Double, Double)) -> Double {
        let (S1, S2) = (s.0, s.1)
        let (T1, T2) = (t.0, t.1)

        let translate = (T2 * S1 - T1 * S2) / (S1 - S2)
        let scale = (T2 - T1) / (S2 - S1)

        return translate + scale * v
    }

    fileprivate func convert(point p: CGPoint, from s: Boundary, to t: Boundary) -> CGPoint {
        let x = convert(Double(p.x), from: (s.0, s.1), to: (t.0, t.1))
        let y = convert(Double(p.y), from: (s.2, s.3), to: (t.2, t.3))
        return CGPoint(x: x, y: y)
    }
}

extension MapView {

    func locationInView(with event: NSEvent) -> CGPoint? {
        return self.convert(event.locationInWindow, from: self.superview)
    }
}
