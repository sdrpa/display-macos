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

import Cocoa
import CoreGraphics
import CoreText

extension CGContext: Renderer {

    func move(toPoint point: CGPoint) {
        self.move(to: point)
    }

    func line(toPoint point: CGPoint) {
        self.addLine(to: point)
    }

    func draw(text: String, at position: CGPoint) -> CGSize {
        let attributes: [String: AnyObject] = [
            NSForegroundColorAttributeName: NSColor(white: 1.0, alpha: 1.0).cgColor,
            NSFontAttributeName : NSFont.systemFont(ofSize: 17)
        ]
        guard let font = attributes[NSFontAttributeName] as? NSFont else {
            fatalError(#function)
        }
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = text.size(withAttributes: attributes)

        // y: Add font.descender (its a negative value) to align the text at the baseline
        let textPath    = CGPath(rect: CGRect(x: position.x, y: position.y + font.descender,
                                              width: ceil(textSize.width), height: ceil(textSize.height)), transform: nil)
        let frameSetter = CTFramesetterCreateWithAttributedString(attributedString)
        let frame       = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: attributedString.length), textPath, nil)
        CTFrameDraw(frame, self)
        
        return textSize
    }
}
