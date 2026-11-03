-- Current ChatGPT desktop app (not ChatGPT Classic).
-- Load this file from your Hammerspoon init.lua; see the accompanying setup.
local M = {}
local bundleID = "com.openai.codex"
local buttonLabel = "Open in a new window"
local activeRun
local cachedPath
-- Load extensions at config reload, outside the hotkey's critical path.
local application, ax, timer, eventtap = hs.application, hs.axuielement, hs.timer, hs.eventtap

local function isPopOutButton(element)
    if element:attributeValue("AXRole") ~= "AXButton" then return false end
    for _, attribute in ipairs({"AXDescription", "AXTitle", "AXHelp"}) do
        if element:attributeValue(attribute) == buttonLabel then
            return element:attributeValue("AXEnabled") ~= false
        end
    end
    return false
end

function M.open()
    if activeRun then return end -- Ignore repeated hotkeys while opening.
    if not hs.accessibilityState() then
        hs.alert.show("Enable Hammerspoon in System Settings → Privacy & Security → Accessibility.")
        return
    end

    local run = {sentShortcut = false, misses = 0}
    activeRun = run

    local function finish(message)
        if activeRun ~= run then return end
        activeRun = nil -- Invalidate callbacks before cancelling the search.
        if run.timer then run.timer:stop() end
        if run.timeout then run.timeout:stop() end
        if run.search and run.search:isRunning() then run.search:cancel() end
        if message then hs.alert.show(message) end
    end

    local function later(callback, seconds)
        run.timer = timer.doAfter(seconds or 0.02, function()
            if activeRun == run then callback() end
        end)
    end

    run.timeout = timer.doAfter(15, function()
        finish("Could not find “Open in a new window”. Check ChatGPT's Quick Chat shortcut and English UI labels.")
    end)

    local runningApp = application.applicationsForBundleID(bundleID)[1]
    if not runningApp then
        -- Launch in the background; never raise the main app just to invoke
        -- Quick Chat. Retain the task until its completion callback runs.
        run.launchTask = hs.task.new("/usr/bin/open", function(code, _, stderr)
            if code ~= 0 then
                finish("Could not launch ChatGPT: " .. tostring(stderr))
            end
        end, {"-g", "-b", bundleID})
        if not run.launchTask or not run.launchTask:start() then
            finish("Could not start ChatGPT's background launch.")
            return
        end
    end

    local function press(button, path)
        local accepted, err = button:performAction("AXPress")
        if accepted then
            if path then cachedPath = path end
            finish()
        else
            finish("ChatGPT rejected the pop-out click: " .. tostring(err or "AXPress failed"))
        end
    end

    local step
    step = function()
        local app = application.applicationsForBundleID(bundleID)[1]
        if not app then later(step); return end

        local root = ax.applicationElement(app)
        if not root then later(step); return end

        if not run.sentShortcut then
            -- Wait for the initial UI on a cold launch, without focusing it.
            if #(root:attributeValue("AXWindows") or {}) == 0 then
                later(step)
                return
            end
            -- The application argument targets ChatGPT directly, even while
            -- another app is frontmost. Never emit this as a global keystroke.
            run.sentShortcut = true
            eventtap.keyStroke({"cmd", "alt"}, "n", 0, app)
            later(step, 0.01)
            return
        end

        local windows = {}
        local focused = root:attributeValue("AXFocusedWindow")
        if focused then windows[1] = focused end
        for _, window in ipairs(root:attributeValue("AXWindows") or {}) do
            if window ~= focused and window:attributeValue("AXMinimized") ~= true then
                windows[#windows + 1] = window
            end
        end

        -- Reuse the child-index path found on the previous invocation.
        -- Always verify the label and role: a changed layout must not cause
        -- us to click a different button at the old location.
        if cachedPath then
            for _, window in ipairs(windows) do
                local element = window
                for _, index in ipairs(cachedPath) do
                    element = (element:attributeValue("AXChildren") or {})[index]
                    if not element then break end
                end
                if element and isPopOutButton(element) then
                    press(element, cachedPath)
                    return
                end
            end
        end

        -- Retain the original broad search as an occasional compatibility
        -- fallback for apps exposing controls outside AXChildren.
        if run.misses > 0 and run.misses % 10 == 0 then
            run.search = root:elementSearch(function(_, results)
                if activeRun ~= run then return end
                if results[1] then press(results[1]); return end
                run.misses = run.misses + 1
                later(step)
            end, isPopOutButton, {count = 1, depth = 25})
            return
        end

        -- Read just AXChildren, instead of elementSearch's allAttributeValues
        -- at every node. Yield in small batches so Hammerspoon stays responsive.
        local queue, head = {}, 1
        for _, window in ipairs(windows) do
            queue[#queue + 1] = {element = window, path = {}}
        end
        local scan
        scan = function()
            local sliceStart = timer.absoluteTime()
            for _ = 1, 32 do
                local entry = queue[head]
                if not entry then
                    run.misses = run.misses + 1
                    later(step)
                    return
                end
                head = head + 1
                if isPopOutButton(entry.element) then
                    press(entry.element, entry.path)
                    return
                end
                if #entry.path < 25 then
                    for index, child in ipairs(entry.element:attributeValue("AXChildren") or {}) do
                        local path = {table.unpack(entry.path)}
                        path[#path + 1] = index
                        queue[#queue + 1] = {element = child, path = path}
                    end
                end
                if timer.absoluteTime() - sliceStart > 4000000 then break end
            end
            later(scan, 0.001)
        end
        scan()
    end

    step()
end

return M
