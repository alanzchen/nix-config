-- Open ChatGPT Quick Chat in a separate window with Control-Option-Space.
chatgptWindow = require("chatgpt-new-window")
chatgptWindowHotkey = hs.hotkey.bind(
    {"ctrl", "alt"}, "space", nil, chatgptWindow.open
)
