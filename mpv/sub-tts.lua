-- sub-tts.lua: Read subtitles aloud via Kokoro TTS (on-demand daemon)
-- Toggle with Ctrl+t
-- Daemon starts automatically on first toggle, stops when mpv exits.

local utils = require("mp.utils")

local enabled = false
local last_text = ""
local daemon_pid = nil
local daemon_ready = false
local PROJECT_DIR = os.getenv("HOME") .. "/Documents/Projects/kokoro-tts-mpv"
local SOCKET_PATH = "/tmp/kokoro-tts.sock"

-- Check if socket exists (daemon is running)
local function socket_exists()
    local f = io.open(SOCKET_PATH, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- Start the daemon if not already running
local function start_daemon(callback)
    if socket_exists() then
        daemon_ready = true
        if callback then callback() end
        return
    end

    mp.osd_message("Loading Kokoro TTS...", 10)

    -- Spawn daemon in background
    utils.subprocess_detached({
        args = { PROJECT_DIR .. "/scripts/kokoro-tts-start" }
    })

    -- Poll for socket to appear
    local attempts = 0
    local max_attempts = 50  -- 10 seconds max

    local timer
    timer = mp.add_periodic_timer(0.2, function()
        attempts = attempts + 1
        if socket_exists() then
            timer:kill()
            daemon_ready = true
            mp.osd_message("Sub TTS: Ready ✓", 2)
            if callback then callback() end
        elseif attempts >= max_attempts then
            timer:kill()
            mp.osd_message("TTS failed to load", 3)
        end
    end)
end

-- Stop the daemon
local function stop_daemon()
    if not socket_exists() then return end
    utils.subprocess_detached({
        args = { "kokoro-speak", "QUIT" }
    })
    daemon_ready = false
end

local function speak(text)
    if not text or text == "" then return end
    if not daemon_ready then return end

    -- Strip HTML/ASS tags and clean up
    text = text:gsub("<[^>]+>", "")
    text = text:gsub("{\\[^}]+}", "")
    text = text:gsub("\n", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")

    if text == "" then return end

    -- Send to daemon via kokoro-speak (non-blocking)
    utils.subprocess_detached({
        args = { "kokoro-speak", text }
    })
end

local function stop_speech()
    if not daemon_ready then return end
    utils.subprocess_detached({
        args = { "kokoro-speak", "STOP" }
    })
end

local function on_sub_text(name, value)
    if not enabled then return end

    local text = value or ""
    if text ~= last_text then
        last_text = text
        speak(text)
    end
end

local function toggle_tts()
    enabled = not enabled
    if enabled then
        -- Start daemon if needed, then begin TTS
        start_daemon(function()
            mp.observe_property("sub-text", "string", on_sub_text)
            -- Speak current subtitle immediately
            local current = mp.get_property("sub-text")
            if current and current ~= "" then
                last_text = current
                speak(current)
            end
        end)
    else
        mp.osd_message("Sub TTS: OFF", 2)
        mp.unobserve_property(on_sub_text)
        stop_speech()
        last_text = ""
    end
end

-- Shut down daemon when mpv exits
mp.register_event("shutdown", function()
    if enabled then stop_speech() end
    -- Always stop daemon on mpv exit (if we started it)
    stop_daemon()
end)

-- Register keybinding
mp.add_key_binding("Ctrl+t", "toggle-sub-tts", toggle_tts)
