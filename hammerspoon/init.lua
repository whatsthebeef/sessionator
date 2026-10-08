-- ==================== Base ====================

-- Enable IPC CLI (hs command)
require("hs.ipc")

-- Reload
hs.hotkey.bind({"alt", "shift"}, "R", function() hs.reload() end)
hs.alert.show("Config loaded")

-- ⌃ ⇧ ⌘ + B : show & copy bundle ID of frontmost app
hs.hotkey.bind({"alt","shift"}, "B", function()
  local win = hs.window.frontmostWindow()
  local app = (win and win:application()) or hs.application.frontmostApplication()
  if not app then hs.alert.show("No frontmost application"); return end
  local name   = app:name() or "?"
  local bundle = app:bundleID() or "?"
  hs.pasteboard.setContents(bundle)
  hs.alert.show(string.format("App: %s\nBundle ID: %s\n(Copied)", name, bundle), 2)
  hs.console.printStyledtext(string.format("Bundle ID copied: %s (%s)\n", bundle, name))
end)

-- ==================== Window Helpers ====================

local function isMovableWindow(w)
  return w and w:isVisible() and not w:isMinimized() and w:isStandard()
end

local function ensureMovable(win, cont)
  if not win then return end
  if win:isFullScreen() then
    win:setFullScreen(false)
    hs.timer.doAfter(0.30, function() cont(win) end)
  else
    cont(win)
  end
end

local function focusedMovableWindow()
  local w = hs.window.frontmostWindow()
  if isMovableWindow(w) then return w end
  -- Try to pick best window of frontmost app
  local app = hs.application.frontmostApplication()
  if not app then return nil end
  local best, area = nil, 0
  for _, win in ipairs(app:allWindows()) do
    if isMovableWindow(win) then
      local f = win:frame()
      local a = math.max(0, f.w) * math.max(0, f.h)
      if a > area then best, area = win, a end
    end
  end
  return best
end

local UNITS = {
  full   = {x=0.0, y=0.0, w=1.0, h=1.0},
  left   = {x=0.0, y=0.0, w=0.5, h=1.0},
  right  = {x=0.5, y=0.0, w=0.5, h=1.0},
  top    = {x=0.0, y=0.0, w=1.0, h=0.5},
  bottom = {x=0.0, y=0.5, w=1.0, h=0.5},
}

local function snap(win, unit)
  win:moveToUnit(unit, 0)
end

local function moveToNextScreenAndMaximize(win)
  win:moveToScreen(win:screen():next(), false, true, 0)
  snap(win, UNITS.full)
end

-- Helper to operate on current focused window
local function withFocusedWindow(action)
  local w = focusedMovableWindow()
  if not w then hs.alert.show("No movable window"); return end
  ensureMovable(w, action)
end

-- ==================== App Focus Shortcuts ====================
-- Use your existing keys to FOCUS apps (no modal).

local function focusApp(idOrName)
  if idOrName:find("%.") then
    hs.application.launchOrFocusByBundleID(idOrName)
  else
    hs.application.launchOrFocus(idOrName)
  end
  withFocusedWindow(function(w) snap(w, snap(w, UNITS.full)) end)-- ensure frontmost window is movable
end

local function focusChrome()
  focusApp("com.google.Chrome")
end

local function shiftChromeTab(direction)
  hs.eventtap.keyStroke({"alt", "cmd"}, direction)
end

-- Alt+B/T/D/W/S/G -> focus apps (same letters you used before)
hs.hotkey.bind({"alt"}, "B", function() focusChrome() end)
hs.hotkey.bind({"alt"}, "T", function() focusApp("com.apple.Terminal") end)
hs.hotkey.bind({"alt"}, "D", function() focusApp("com.google.Chrome.app.jojdhmlcnakilabhnnmaclkdocikbjed") end)
hs.hotkey.bind({"alt"}, "W", function() focusApp("net.whatsapp.WhatsApp") end)
hs.hotkey.bind({"alt"}, "S", function() focusApp("com.tinyspeck.slackmacgap") end)
hs.hotkey.bind({"alt"}, "G", function() focusApp("com.openai.codex") end)
hs.hotkey.bind({"alt"}, "A", function() focusApp("dev.yuhapps.g2fa") end)

-- Focus or open a Chrome tab matching a URL pattern
local function focusChromeTab(matchPattern, fallbackUrl)
  local script = [[
    tell application "Google Chrome"
      activate
      set found to false
      repeat with w in windows
        set tabIndex to 0
        repeat with t in tabs of w
          set tabIndex to tabIndex + 1
          if URL of t contains "]] .. matchPattern .. [[" then
            set active tab index of w to tabIndex
            set index of w to 1
            set found to true
            exit repeat
          end if
        end repeat
        if found then exit repeat
      end repeat
      if not found then
        if (count of windows) is 0 then
          make new window with properties {mode:"normal"}
        end if
        tell front window to make new tab with properties {URL:"]] .. fallbackUrl .. [["}
      end if
    end tell
  ]]
  local ok, err = hs.osascript.applescript(script)
  if not ok then
    hs.alert.show("Chrome tab error: " .. tostring(err))
  end
end

hs.hotkey.bind({"alt"}, "J", function()
  focusChromeTab("pocketlab1.atlassian.net/jira", "https://pocketlab1.atlassian.net/jira/software/c/projects/N2/boards/100")
end)

hs.hotkey.bind({"alt"}, "E", function()
  focusChromeTab("console.aws.amazon.com/codesuite/codebuild", "https://us-east-1.console.aws.amazon.com/codesuite/codebuild/projects?region=us-east-1")
end)

hs.hotkey.bind({"alt"}, "M", function()
  focusChromeTab("localhost:5173", "http://localhost:5173")
end)

hs.hotkey.bind({"alt"}, "P", function()
  focusChromeTab("app-int.thepocketlab.com", "https://app-int.thepocketlab.com")
end)

-- ==================== Global Move/Resize Shortcuts ====================
-- Act on the CURRENTLY FOCUSED window. No mode needed.

-- Alt+H/J/K/L: halves (left/bottom/top/right)
-- hs.hotkey.bind({"alt", "shift"}, "H", function() withFocusedWindow(function(w) snap(w, UNITS.left)   end) end)
-- hs.hotkey.bind({"alt", "shift"}, "L", function() withFocusedWindow(function(w) snap(w, UNITS.right)  end) end)
hs.hotkey.bind({"alt", "shift"}, "K", function() withFocusedWindow(function(w) snap(w, UNITS.top)    end) end)
hs.hotkey.bind({"alt", "shift"}, "J", function() withFocusedWindow(function(w) snap(w, UNITS.bottom) end) end)

hs.hotkey.bind({"alt", "shift"}, "S", function() withFocusedWindow(function(w) moveToNextScreenAndMaximize(w) end) end)

hs.hotkey.bind({"alt", "shift"}, "H", function() shiftChromeTab(hs.keycodes.map.left) end)
hs.hotkey.bind({"alt", "shift"}, "L", function() shiftChromeTab(hs.keycodes.map.right) end)
hs.hotkey.bind({"alt", "shift"}, "Q", function() hs.eventtap.keyStroke({"cmd"}, "W") end)

-- Chrome
hs.hotkey.bind({"alt", "shift"}, "C", function()
  hs.application.launchOrFocusByBundleID("com.google.Chrome")
end)
