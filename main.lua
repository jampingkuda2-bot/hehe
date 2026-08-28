--[[
    Fish It - Utility Module
    Fokus pada keamanan eksekusi & efisiensi loop
    Menggunakan teknik Randomized Delay + Modular Closure
]]

-- Services
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")

-- Konfigurasi (Local Environment)
local Config = {
    WebhookURL = "",          -- Isi dengan Discord Webhook
    DiscordEnabled = true,
    WeatherNotify = true,
    AutoFish = false,
    AntiAFK = true,

    -- Randomized Delay Settings
    MinDelay = 0.8,           -- detik
    MaxDelay = 1.5,           -- detik
    WeatherCheckInterval = 5, -- detik (jarak antar pengecekan cuaca)
}

-- Utility: Randomized Delay (Menghindari pola spam instan)
local function randomizedDelay()
    local delayTime = Config.MinDelay + (math.random() * (Config.MaxDelay - Config.MinDelay))
    task.wait(delayTime)
end

-- Utility: Safe Remote Fire (dengan pcall & validasi)
local function safeFireRemote(remoteName, ...)
    local success, err = pcall(function()
        local remote = ReplicatedStorage:FindFirstChild(remoteName)
        if remote and remote:IsA("RemoteEvent") then
            remote:FireServer(...)
        end
    end)
    if not success then
        -- Silent fail, jangan spam console
        return false
    end
    return true
end

-- Utility: Discord Webhook (dengan pcall)
local function sendDiscord(message)
    if not Config.DiscordEnabled or Config.WebhookURL == "" then return end

    pcall(function()
        local payload = HttpService:JSONEncode({
            content = message,
            username = "Fish It Utility"
        })
        if syn then
            syn.request({
                Url = Config.WebhookURL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
        else
            request({
                Url = Config.WebhookURL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
        end
    end)
end

-- Utility: Cek Cuaca (dengan pcall)
local function getWeather()
    local weather = "Unknown"
    pcall(function()
        local obj = Workspace:FindFirstChild("Weather") or Workspace:FindFirstChild("CurrentWeather") or Workspace:FindFirstChild("ElementalWeather")
        if obj and obj:IsA("StringValue") then
            weather = obj.Value
        end
    end)
    return weather
end

-- Utility: Deteksi Elemental (Api/Petir/Es)
local function checkElemental(weather)
    local w = weather:lower()
    if w:find("fire") or w:find("api") then return "fire" end
    if w:find("thunder") or w:find("petir") or w:find("lightning") then return "thunder" end
    if w:find("ice") or w:find("es") or w:find("snow") then return "ice" end
    return nil
end

-- =============================================
-- MODUL UTAMA (Listener Cuaca & Notifikasi)
-- =============================================
local WeatherListener = {}

WeatherListener.lastElemental = ""

function WeatherListener.Start()
    task.spawn(function()
        while true do
            pcall(function()
                local weather = getWeather()
                local etype = checkElemental(weather)

                -- Hanya kirim notifikasi jika elemen berubah
                if etype and etype ~= WeatherListener.lastElemental and Config.WeatherNotify then
                    WeatherListener.lastElemental = etype
                    local emoji = etype == "fire" and "🔥" or etype == "thunder" and "⚡" or "❄️"
                    local msg = emoji .. " " .. etype:upper() .. " Weather Detected!"

                    sendDiscord(msg .. "\nWeather: " .. weather)
                end

                WeatherListener.lastElemental = etype or ""
            end)
            task.wait(Config.WeatherCheckInterval) -- Jeda antar pengecekan cuaca
        end
    end)
end

-- =============================================
-- MODUL INTERAKSI GAME (Fishing Logic)
-- =============================================
local FishingLogic = {}

function FishingLogic.Start()
    task.spawn(function()
        while true do
            if Config.AutoFish then
                pcall(function()
                    -- Gunakan safeFireRemote dengan jeda acak
                    safeFireRemote("CastLine")
                    randomizedDelay()
                    safeFireRemote("Fish")
                    randomizedDelay()
                end)
            end
            randomizedDelay() -- Jeda acak di setiap loop
        end
    end)
end

-- =============================================
-- MODUL ANTI-AFK
-- =============================================
local AntiAFK = {}

function AntiAFK.Start()
    if not Config.AntiAFK then return end

    task.spawn(function()
        while true do
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
                task.wait(0.5)
                VirtualUser:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
            end)
            task.wait(240) -- 4 menit
        end
    end)
end

-- =============================================
-- INISIALISASI MODUL
-- =============================================
local function Init()
    WeatherListener.Start()
    FishingLogic.Start()
    AntiAFK.Start()
end

Init()
