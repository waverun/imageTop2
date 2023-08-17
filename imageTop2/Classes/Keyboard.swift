//import KeyboardShortcuts
import AppKit

class Keyboard {
    public static var keyNames: [String] { //["abc", "abcb"]
        [
            // Symbols
//            "period", "quote", "rightBracket", "semicolon", "slash", "backslash", "comma", "equal", "leftBracket", "minus",
//            "backslash", "comma", "equal", "leftBracket", "minus", "period", "quote", "rightBracket", "semicolon", "slash",
            "Backslash", "Comma", "Equal", "Minus", "Period", "Quote", "Semicolon", "Slash",
            //            "\\", ",", "=", "[", "-", ".", "\"", "]", ";", "/",

            // Whitespace
            "Return", "Space", "Tab",

            // Navigation
            //            "PageUp", "PageDown", "Home", "End", "UpArrow", "RightArrow", "DownArrow", "LeftArrow",
            "DownArrow", "End", "Home", "LeftArrow", "PageDown", "PageUp", "RightArrow", "UpArrow",

            // Misc
            //            "Escape", "Delete", "Help", "VolumeUp", "VolumeDown", "Mute",
            "Delete", "Escape",

            // Functions
            "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "F13", "F14", "F15", "F16", "F17", "F18", "F19", "F20",

            // Keypad
            //            "Keypad0", "Keypad1", "Keypad2", "Keypad3", "Keypad4", "Keypad5", "Keypad6", "Keypad7", "Keypad8", "Keypad9", "KeypadClear", "KeypadDecimal", "KeypadDivide", "KeypadEnter", "KeypadEquals", "KeypadMinus", "KeypadMultiply", "KeypadPlus",
            "Keypad0", "Keypad1", "Keypad2", "Keypad3", "Keypad4", "Keypad5", "Keypad6", "Keypad7", "Keypad8", "Keypad9", "KeypadClear", "KeypadDecimal", "KeypadDivide", "KeypadEnter", "KeypadEquals", "KeypadMinus", "KeypadMultiply", "KeypadPlus",

            // Letters
//            "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
            "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
            
            // Numbers
            "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        ]
    }

    public static var modKeyNames: [String] {
        [
            "None", "Command", "Option", "Control", "Shift"
        ]
    }

    public static func keyEquivalentString(from keyString: String, forMenu: Bool) -> String {
        switch keyString {
            case "F1": return String(UnicodeScalar(NSF1FunctionKey)!)
            case "F2": return String(UnicodeScalar(NSF2FunctionKey)!)
            case "F3": return String(UnicodeScalar(NSF3FunctionKey)!)
            case "F4": return String(UnicodeScalar(NSF4FunctionKey)!)
            case "F5": return String(UnicodeScalar(NSF5FunctionKey)!)
            case "F6": return String(UnicodeScalar(NSF6FunctionKey)!)
            case "F7": return String(UnicodeScalar(NSF7FunctionKey)!)
            case "F8": return String(UnicodeScalar(NSF8FunctionKey)!)
            case "F9": return String(UnicodeScalar(NSF9FunctionKey)!)
            case "F10": return String(UnicodeScalar(NSF10FunctionKey)!)
            case "F11": return String(UnicodeScalar(NSF11FunctionKey)!)
            case "F12": return String(UnicodeScalar(NSF12FunctionKey)!)
            case "F13": return String(UnicodeScalar(NSF13FunctionKey)!)
            case "F14": return String(UnicodeScalar(NSF14FunctionKey)!)
            case "F15": return String(UnicodeScalar(NSF15FunctionKey)!)
            case "F16": return String(UnicodeScalar(NSF16FunctionKey)!)
            case "F17": return String(UnicodeScalar(NSF17FunctionKey)!)
            case "F18": return String(UnicodeScalar(NSF18FunctionKey)!)
            case "F19": return String(UnicodeScalar(NSF19FunctionKey)!)
            case "F20": return String(UnicodeScalar(NSF20FunctionKey)!)
            default: return Keyboard.keySymbol(from: keyString, forMenu: forMenu)
        }
    }


    public static func keySymbol(from name: String, forMenu: Bool = false) -> String {
        if name.count == 1,
           let character = name.first,
           character.isUppercase || character.isNumber {
            return name
        }

        switch name.unCapcase() {
            case "backslash": return "\\" + " (Backslash)"
            case "comma": return "," + " (Comma)"
            case "equal": return "=" + " (Equal)"
            case "leftBracket": return "[" + " (Left Bracket)"
            case "minus": return "-" + " (Minus)"
            case "period": return "." + " (Period)"
            case "quote": return "\"" + " (Quote)"
            case "rightBracket": return "]" + " (Right Bracket)"
            case "semicolon": return ";" + " (Semicolon)"
            case "slash": return "/" + " (Slash)"
            case "pageUp": return "⇞" + " (Page Up)"
            case "pageDown": return "⇟" + " (Page Down)"
            case "home": return "⇱" + " (Home)"
            case "upArrow": return "↑" + " (Up Arrow)"
            case "rightArrow": return "→" + " (Right Arrow)"
            case "downArrow": return "↓" + " (Down Arrow)"
            case "leftArrow": return "←" + " (Left Arrow)"
            case "escape": return forMenu ? String(UnicodeScalar(27)) : "␛" + " (esc)"
            case "delete": return "␡" + " (Delete)"
//            case "help": return "Help" + " (Help)"
//            case "volumeUp": return "Volume Up" + " (Volume Up)"
//            case "volumeDown": return "Volume Down" + " (Volume Down)"
//            case "mute": return "Mute" + " (Mute)"
            case "end": return "⇲" + " (End)"
            case "return": return "↵" + " (Return)"
            case "tab": return forMenu ? "\t" : "→|" + " (Tab)"
            case "space": return forMenu ? " " : "Space" + " (Space)"
            case "keypad0": return "0" + " (Keypad 0)"
            case "keypad1": return "1" + " (Keypad 1)"
            case "keypad2": return "2" + " (Keypad 2)"
            case "keypad3": return "3" + " (Keypad 3)"
            case "keypad4": return "4" + " (Keypad 4)"
            case "keypad5": return "5" + " (Keypad 5)"
            case "keypad6": return "6" + " (Keypad 6)"
            case "keypad7": return "7" + " (Keypad 7)"
            case "keypad8": return "8" + " (Keypad 8)"
            case "keypad9": return "9" + " (Keypad 9)"
            case "keypadClear": return "Clear" + " (Keypad Clear)"
            case "keypadDecimal": return "." + " (Keypad Decimal)"
            case "keypadDivide": return "/" + " (Keypad Divide)"
            case "keypadEnter": return "Enter" + " (Keypad Enter)"
            case "keypadEquals": return "=" + " (Keypad Equals)"
            case "keypadMinus": return "-" + " (Keypad Minus)"
            case "keypadMultiply": return "*" + " (Keypad Multiply)"
            case "keypadPlus": return "+" + " (Keypad Plus)"
            default: return name
        }
    }

    public static func stringToModifier(_ string: String) -> NSEvent.ModifierFlags? {
        switch string.lowercased() {
            case "control":
                return .control
            case "shift":
                return .shift
            case "command":
                return .command
            case "option":
                return .option
            case "capslock":
                return .capsLock
            case "function":
                return .function
            default:
                return nil
        }
    }
    //        [
    //            // Letters
    //            .a, .b, .c, .d, .e, .f, .g, .h, .i, .j, .k, .l, .m, .n, .o, .p, .q, .r, .s, .t, .u, .v, .w, .x, .y, .z,
    //
    //            // Numbers
    //            .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine,
    //
    //            // Symbols
    //            .period, .quote, .rightBracket, .semicolon, .slash, .backslash, .comma, .equal, .leftBracket, .minus,
    //
    //            // Whitespace
    //            .space, .tab, .return,
    //
    //            // Modifiers
    ////            .command, .rightCommand, .option, .rightOption, .control, .rightControl, .shift, .rightShift, .function, .capsLock,
    //
    //            // Navigation
    //            .pageUp, .pageDown, .home, .end, .upArrow, .rightArrow, .downArrow, .leftArrow,
    //
    //            // Functions
    //            .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12, .f13, .f14, .f15, .f16, .f17, .f18, .f19, .f20,
    //
    //            // Keypad
    //            .keypad0, .keypad1, .keypad2, .keypad3, .keypad4, .keypad5, .keypad6, .keypad7, .keypad8, .keypad9, .keypadClear, .keypadDecimal, .keypadDivide, .keypadEnter, .keypadEquals, .keypadMinus, .keypadMultiply, .keypadPlus,
    //
    //            // Misc
    //            .escape, .delete, .help, .volumeUp, .volumeDown, .mute
    //        ]
    //    }
}
