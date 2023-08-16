//import KeyboardShortcuts
import AppKit

class Keyboard {
    public static var keyNames: [String] { //["abc", "abcb"]
        [
            // Symbols
//            "period", "quote", "rightBracket", "semicolon", "slash", "backslash", "comma", "equal", "leftBracket", "minus",
            "backslash", "comma", "equal", "leftBracket", "minus", "period", "quote", "rightBracket", "semicolon", "slash",

            // Whitespace
            "return", "space", "tab",

            // Navigation
//            "pageUp", "pageDown", "home", "end", "upArrow", "rightArrow", "downArrow", "leftArrow",
            "downArrow", "end", "home", "leftArrow", "pageDown", "pageUp", "rightArrow", "upArrow",

            // Misc
//            "escape", "delete", "help", "volumeUp", "volumeDown", "mute",
            "delete", "escape", "help", "mute", "volumeDown", "volumeUp",

            // Functions
            "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12", "f13", "f14", "f15", "f16", "f17", "f18", "f19", "f20",

            // Keypad
//            "keypad0", "keypad1", "keypad2", "keypad3", "keypad4", "keypad5", "keypad6", "keypad7", "keypad8", "keypad9", "keypadClear", "keypadDecimal", "keypadDivide", "keypadEnter", "keypadEquals", "keypadMinus", "keypadMultiply", "keypadPlus",
            "keypad0", "keypad1", "keypad2", "keypad3", "keypad4", "keypad5", "keypad6", "keypad7", "keypad8", "keypad9", "keypadClear", "keypadDecimal", "keypadDivide", "keypadEnter", "keypadEquals", "keypadMinus", "keypadMultiply", "keypadPlus",

            // Letters
//            "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
            "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
            
            // Numbers
            "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        ]
    }

    public static var modKeyNames: [String] {
        [
            "None", "command", "option", "control", "shift", "function", "capsLock"
        ]
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
