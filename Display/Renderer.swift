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

import Foundation

protocol Drawable {
    func draw()
}

protocol Renderer {

    func move(toPoint point: CGPoint)
    func line(toPoint point: CGPoint)
    func draw(text: String, at position: CGPoint) -> CGSize
}
