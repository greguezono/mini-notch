import Foundation

func pointerInsideActions(_ point: CGPoint, notch: CGRect?, panel: CGRect, panelVisible: Bool) -> Bool {
    func contains(_ rect: CGRect) -> Bool {
        point.x >= rect.minX && point.x <= rect.maxX && point.y >= rect.minY && point.y <= rect.maxY
    }
    return notch.map(contains) == true || (panelVisible && contains(panel))
}

struct PanelState {
    private(set) var visible = false
    private var inside = false
    private var keyboard = false
    var hold = false
    var pinned = false { didSet { if pinned { visible = true } else { keyboard = false; expire() } } }
    var previewing = false { didSet { if previewing { visible = true } else { expire() } } }
    private var forced: Bool { pinned || previewing }
    mutating func enter() { inside = true; visible = true }
    mutating func exit() { inside = false }
    mutating func expire() { if !inside && !keyboard && !hold && !forced { visible = false } }
    mutating func showKeyboard() { keyboard = true; visible = true }
    mutating func escape() { keyboard = false; if !forced { visible = false } }
}
