-- Fish It Weather Detector
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Settings = {
    Webhook = "",
    DiscordEnabled = true,
    Interval = 5,
    AutoFish = false,
    AntiAFK = true,
    NotifyElemental = true
}

local lastWeather = ""
local lastElemental = ""
local UIVisible = true
local isMobile = UserInputService.TouchEnabled

local function sendDiscord(title, desc, color)
    if not Settings.DiscordEnabled or Settings.Webhook == "" then return end
    
    local payload = HttpService:JSONEncode({
        embeds = {{
            title = title,
            description = desc,
            color = color or 5814783,
            footer = {text = "Weather Alert • " .. os.date("%H:%M:%S")}
        }},
        username = "Weather Alert"
    })
    
    pcall(function()
        if syn then
            syn.request({Url = Settings.Webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        else
            request({Url = Settings.Webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        end
    end)
end

local function getWeather()
    local weather = "Unknown"
    pcall(function()
        for _, name in pairs({"Weather", "CurrentWeather", "ElementalWeather"}) do
            local obj = Workspace:FindFirstChild(name)
            if obj and obj:IsA("StringValue") then
                weather = obj.Value
                break
            end
        end
        
        local ws = Workspace:FindFirstChild("WeatherSystem")
        if ws then
            local cw = ws:FindFirstChild("CurrentWeather")
            if cw and cw:IsA("StringValue") then
                weather = cw.Value
            end
        end
    end)
    return weather
end

local function checkElemental(weather)
    local w = weather:lower()
    if w:find("fire") or w:find("api") or w:find("flame") then return "fire" end
    if w:find("thunder") or w:find("petir") or w:find("lightning") then return "thunder" end
    if w:find("ice") or w:find("es") or w:find("snow") or w:find("frost") then return "ice" end
    return nil
end

local function notify(title, text)
    pcall(function()
        local gui = CoreGui:FindFirstChild("FishItUI")
        if not gui then return end
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, isMobile and 180 or 220, 0, isMobile and 45 or 55)
        frame.Position = UDim2.new(1, 10, 0, isMobile and 70 or 20)
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        frame.BorderSizePixel = 0
        frame.Parent = gui
        
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, 0, 0, 18)
        t.BackgroundTransparency = 1
        t.Text = title
        t.TextColor3 = Color3.fromRGB(255, 150, 150)
        t.TextSize = isMobile and 10 or 12
        t.Font = Enum.Font.GothamBold
        t.Parent = frame
        
        local d = Instance.new("TextLabel")
        d.Size = UDim2.new(1, 0, 0, 22)
        d.Position = UDim2.new(0, 0, 0, 18)
        d.BackgroundTransparency = 1
        d.Text = text
        d.TextColor3 = Color3.fromRGB(255, 255, 255)
        d.TextSize = isMobile and 8 or 10
        d.TextWrapped = true
        d.Parent = frame
        
        local tween = TweenService:Create(frame, TweenInfo.new(0.3), {
            Position = UDim2.new(1, isMobile and -190 or -230, 0, isMobile and 70 or 20)
        })
        tween:Play()
        
        task.delay(5, function()
            pcall(function()
                local fade = TweenService:Create(frame, TweenInfo.new(0.3), {
                    Position = UDim2.new(1, 10, 0, isMobile and 70 or 20)
                })
                fade:Play()
                fade.Completed:Connect(function() frame:Destroy() end)
            end)
        end)
    end)
end

local function alert(weather, etype)
    local emoji, color, title = "🌤️", 5814783, "Weather Alert"
    if etype == "fire" then emoji, color, title = "🔥", 15158332, "FIRE WEATHER!" end
    if etype == "thunder" then emoji, color, title = "⚡", 16766720, "THUNDER WEATHER!" end
    if etype == "ice" then emoji, color, title = "❄️", 65280, "ICE WEATHER!" end
    
    sendDiscord(emoji .. " " .. title, string.format("**Player:** %s\n**Weather:** %s", LocalPlayer.Name, weather), color)
    notify(emoji .. " " .. etype:upper() .. " WEATHER!", "Detected: " .. weather)
end

local function createUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "FishItUI"
    gui.Parent = CoreGui
    gui.ResetOnSpawn = false
    
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, isMobile and 40 or 45, 0, isMobile and 40 or 45)
    toggle.Position = UDim2.new(0, 10, 0.3, 0)
    toggle.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    toggle.BackgroundTransparency = 0.3
    toggle.Text = "🎣"
    toggle.TextSize = isMobile and 22 or 26
    toggle.Parent = gui
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 12)
    
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, isMobile and 250 or 300, 0, isMobile and 350 or 400)
    main.Position = UDim2.new(0.5, isMobile and -125 or -150, 0.5, isMobile and -175 or -200)
    main.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    main.BackgroundTransparency = 0.1
    main.Parent = gui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, isMobile and 8 or 12)
    
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, isMobile and 35 or 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    titleBar.Parent = main
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, isMobile and 8 or 12)
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -30, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Fish It Detector"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = isMobile and 12 or 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, isMobile and 22 or 25, 0, isMobile and 22 or 25)
    close.Position = UDim2.new(1, isMobile and -27 or -30, 0, isMobile and 7 or 8)
    close.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    close.Text = "✕"
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.TextSize = isMobile and 10 or 14
    close.Parent = titleBar
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)
    
    close.MouseButton1Click:Connect(function()
        main.Visible = false
        UIVisible = false
    end)
    
    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, 0, 1, isMobile and -35 or -40)
    content.Position = UDim2.new(0, 0, 0, isMobile and 35 or 40)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 2
    content.Parent = main
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, isMobile and 4 or 8)
    layout.Parent = content
    
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, isMobile and 6 or 10)
    padding.PaddingRight = UDim.new(0, isMobile and 6 or 10)
    padding.PaddingTop = UDim.new(0, isMobile and 6 or 10)
    padding.Parent = content
    
    local function addLabel(text)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, isMobile and 18 or 22)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = Color3.fromRGB(255, 150, 150)
        l.TextSize = isMobile and 10 or 12
        l.Font = Enum.Font.GothamBold
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = content
        return l
    end
    
    local function addToggle(text, default, callback)
        local tf = Instance.new("Frame")
        tf.Size = UDim2.new(1, 0, 0, isMobile and 32 or 36)
        tf.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        tf.Parent = content
        Instance.new("UICorner", tf).CornerRadius = UDim.new(0, isMobile and 4 or 6)
        
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(0.65, 0, 1, 0)
        tl.Position = UDim2.new(0, 6, 0, 0)
        tl.BackgroundTransparency = 1
        tl.Text = text
        tl.TextColor3 = Color3.fromRGB(255, 255, 255)
        tl.TextSize = isMobile and 9 or 11
        tl.TextXAlignment = Enum.TextXAlignment.Left
        tl.TextWrapped = true
        tl.Parent = tf
        
        local tb = Instance.new("TextButton")
        tb.Size = UDim2.new(0, isMobile and 35 or 40, 0, isMobile and 18 or 22)
        tb.Position = UDim2.new(1, isMobile and -40 or -45, 0.5, isMobile and -9 or -11)
        tb.BackgroundColor3 = default and Color3.fromRGB(0, 130, 0) or Color3.fromRGB(70, 70, 70)
        tb.Text = default and "ON" or "OFF"
        tb.TextColor3 = Color3.fromRGB(255, 255, 255)
        tb.TextSize = isMobile and 8 or 10
        tb.Font = Enum.Font.GothamBold
        tb.Parent = tf
        Instance.new("UICorner", tb).CornerRadius = UDim.new(0, isMobile and 8 or 10)
        
        local isOn = default
        tb.MouseButton1Click:Connect(function()
            isOn = not isOn
            tb.Text = isOn and "ON" or "OFF"
            tb.BackgroundColor3 = isOn and Color3.fromRGB(0, 130, 0) or Color3.fromRGB(70, 70, 70)
            callback(isOn)
        end)
    end
    
    addLabel("WEATHER STATUS")
    
    local weatherDisplay = Instance.new("TextLabel")
    weatherDisplay.Size = UDim2.new(1, 0, 0, isMobile and 28 or 34)
    weatherDisplay.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    weatherDisplay.Text = "Loading..."
    weatherDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
    weatherDisplay.TextSize = isMobile and 10 or 13
    weatherDisplay.Font = Enum.Font.GothamBold
    weatherDisplay.Parent = content
    Instance.new("UICorner", weatherDisplay).CornerRadius = UDim.new(0, isMobile and 4 or 6)
    
    addLabel("FEATURES")
    addToggle("Auto Fish", false, function(v) Settings.AutoFish = v end)
    addToggle("Anti-AFK", true, function(v) Settings.AntiAFK = v end)
    addToggle("Notify Elemental", true, function(v) Settings.NotifyElemental = v end)
    
    addLabel("DISCORD")
    addToggle("Discord Alert", true, function(v) Settings.DiscordEnabled = v end)
    
    local wf = Instance.new("Frame")
    wf.Size = UDim2.new(1, 0, 0, isMobile and 55 or 65)
    wf.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    wf.Parent = content
    Instance.new("UICorner", wf).CornerRadius = UDim.new(0, isMobile and 4 or 6)
    
    local wl = Instance.new("TextLabel")
    wl.Size = UDim2.new(1, 0, 0, 14)
    wl.Position = UDim2.new(0, 6, 0, 2)
    wl.BackgroundTransparency = 1
    wl.Text = "Webhook URL:"
    wl.TextColor3 = Color3.fromRGB(255, 255, 255)
    wl.TextSize = isMobile and 8 or 10
    wl.TextXAlignment = Enum.TextXAlignment.Left
    wl.Parent = wf
    
    local wi = Instance.new("TextBox")
    wi.Size = UDim2.new(1, -12, 0, isMobile and 28 or 32)
    wi.Position = UDim2.new(0, 6, 0, isMobile and 18 or 20)
    wi.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    wi.PlaceholderText = "Paste webhook URL..."
    wi.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    wi.Text = Settings.Webhook
    wi.TextColor3 = Color3.fromRGB(255, 255, 255)
    wi.TextSize = isMobile and 7 or 9
    wi.ClearTextOnFocus = false
    wi.Parent = wf
    Instance.new("UICorner", wi).CornerRadius = UDim.new(0, 3)
    
    wi.FocusLost:Connect(function()
        if wi.Text ~= "" then Settings.Webhook = wi.Text end
    end)
    
    local test = Instance.new("TextButton")
    test.Size = UDim2.new(1, 0, 0, isMobile and 28 or 32)
    test.BackgroundColor3 = Color3.fromRGB(35, 35, 100)
    test.Text = "Test Webhook"
    test.TextColor3 = Color3.fromRGB(255, 255, 255)
    test.TextSize = isMobile and 9 or 11
    test.Font = Enum.Font.GothamBold
    test.Parent = content
    Instance.new("UICorner", test).CornerRadius = UDim.new(0, isMobile and 4 or 6)
    
    test.MouseButton1Click:Connect(function()
        local success = sendDiscord("Test Alert", "Weather Detector berfungsi!", 16776960)
        weatherDisplay.Text = success and "Test Sent!" or "Failed!"
    end)
    
    toggle.MouseButton1Click:Connect(function()
        UIVisible = not UIVisible
        main.Visible = UIVisible
    end)
    
    return weatherDisplay
end

local weatherDisplay = createUI()

task.spawn(function()
    while true do
        pcall(function()
            local weather = getWeather()
            weatherDisplay.Text = weather
            
            local etype = checkElemental(weather)
            
            if etype then
                if etype ~= lastElemental and Settings.NotifyElemental then
                    lastElemental = etype
                    alert(weather, etype)
                end
            else
                lastElemental = ""
            end
            
            lastWeather = weather
            
            if Settings.AutoFish then
                pcall(function()
                    local event = ReplicatedStorage:FindFirstChild("CastLine") or ReplicatedStorage:FindFirstChild("Cast")
                    if event and event:IsA("RemoteEvent") then
                        event:FireServer()
                    end
                end)
            end
        end)
        
        wait(Settings.Interval)
    end
end)

if Settings.AntiAFK then
    task.spawn(function()
        while Settings.AntiAFK do
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
                wait(0.5)
                VirtualUser:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
            end)
            wait(240)
        end
    end)
end

notify("Fish It Detector", "Script loaded!")
