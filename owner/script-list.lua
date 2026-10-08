local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local BACKEND_URL = "https://igr-backen.vercel.app/api"
local userId = tostring(LocalPlayer.UserId)
local SOUND_ID = "rbxassetid://133113969869894"

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function Notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 4
        })
    end)
end

local function SafeTostring(v)
    local ok, res = pcall(function() return tostring(v) end)
    return ok and res or "nil"
end

local function PlaySound()
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = SOUND_ID
        sound.Volume = 0.5
        sound.Parent = SoundService
        sound:Play()
        task.delay(10, function()
            if sound then sound:Destroy() end
        end)
    end)
end

local function ValidateGuard()
    local ok, res = pcall(function()
        return game:HttpGet(BACKEND_URL .. "/check-role?userId=" .. userId, true)
    end)
    if not ok or not res or res == "null" or res == "" then
        return nil, "Backend error"
    end
    local data = nil
    local parseOk = pcall(function() data = HttpService:JSONDecode(res) end)
    if not parseOk or not data then return nil, "Invalid response" end
    local role = string.lower(SafeTostring(data.role or "denied"))
    local status = string.upper(SafeTostring(data.status or ""))
    if role == "banned" or status == "BANNED" then
        return nil, "BANNED: " .. SafeTostring(data.reason or "Tidak disebutkan")
    end
    if role == "denied" or role == "unknown" or role == "" then
        return nil, "Not whitelisted"
    end
    if role == "expired" then return nil, "License expired" end
    if role ~= "owner" and role ~= "admin" and role ~= "vip" and role ~= "user" then
        return nil, "Invalid role"
    end
    return role, data
end

local guardRole, guardData = ValidateGuard()
if not guardRole then
    Notify("❌ Akses Ditolak", SafeTostring(guardData), 5)
    return
end
Notify("✅ License Valid", "Role: " .. string.upper(guardRole), 3)

local MAPS = {
    igr = {
        name = "INDO GLERITY REBORN",
        icon = "🎮",
        desc = "Map IGR original",
        features = {
            { id = "autofarm_igr", name = "AUTO FARM IGR", icon = "🚀", desc = "Auto farm otomatis",
              url = "https://raw.githubusercontent.com/DV-EXPLOITSX/LOADER-IGR/refs/heads/main/1",
              allowedRoles = { owner = true, admin = true, vip = true, user = true }, unloadFunc = "IGRFarm_Unload", loaded = false },
            { id = "shop_igr", name = "SHOP SISTEM IGR", icon = "🛒", desc = "Sistem shop IGR",
              url = "https://raw.githubusercontent.com/DV-EXPLOITSX/LOADER-IGR/refs/heads/main/2",
              allowedRoles = { owner = true, admin = true, vip = true, user = true }, unloadFunc = "IGRShop_Unload", loaded = false },
        },
    },
    sog = {
        name = "SOUND OF GLERITY", icon = "🎵", desc = "Map SOG",
        features = {
            { id = "farm_sog", name = "FARM SOG", icon = "🎵", desc = "Auto farm Sound of Glerity",
              url = "https://raw.githubusercontent.com/DV-EXPLOITSX/LOADER-IGR/refs/heads/main/SOG/1.lua",
              allowedRoles = { owner = true, admin = true, vip = true, user = true }, unloadFunc = "SOGFarm_Unload", loaded = false },
        },
    },
}

local ROLE_CONFIG = {
    owner = {
        label = "OWNER", icon = "👑",
        color = Color3.fromRGB(0, 255, 255),
        color2 = Color3.fromRGB(255, 0, 255),
        welcome = "FULL SYSTEM ACCESS GRANTED",
        sub = "SYSTEM OVERRIDE • PERMISSION: OWNER",
        borderStyle = "rainbow", borderThickness = 2.5,
    },
    admin = {
        label = "ADMIN", icon = "🛡️",
        color = Color3.fromRGB(50, 150, 255),
        color2 = Color3.fromRGB(0, 80, 200),
        welcome = "ADMIN ACCESS GRANTED",
        sub = "PERMISSION: ADMIN",
        borderStyle = "black_blue", borderThickness = 2.5,
    },
    vip = {
        label = "VIP", icon = "💎",
        color = Color3.fromRGB(255, 200, 0),
        color2 = Color3.fromRGB(255, 130, 0),
        welcome = "VIP ACCESS GRANTED",
        sub = "PERMISSION: VIP",
        borderStyle = "black_gold", borderThickness = 2.5,
    },
    user = {
        label = "USER", icon = "✅",
        color = Color3.fromRGB(0, 255, 136),
        color2 = Color3.fromRGB(0, 180, 90),
        welcome = "USER ACCESS GRANTED",
        sub = "PERMISSION: USER",
        borderStyle = "black_green", borderThickness = 2.5,
    },
    denied = {
        label = "DENIED", icon = "❌",
        color = Color3.fromRGB(255, 50, 50),
        color2 = Color3.fromRGB(150, 0, 0),
        welcome = "ACCESS DENIED",
        sub = "NOT WHITELISTED",
        borderStyle = "solid", borderThickness = 2.5,
    },
    banned = {
        label = "BANNED", icon = "🚫",
        color = Color3.fromRGB(255, 50, 50),
        color2 = Color3.fromRGB(100, 0, 0),
        welcome = "YOU ARE BANNED",
        sub = "CONTACT OWNER",
        borderStyle = "solid", borderThickness = 3,
    },
    expired = {
        label = "EXPIRED", icon = "⏰",
        color = Color3.fromRGB(255, 150, 100),
        color2 = Color3.fromRGB(200, 80, 0),
        welcome = "LICENSE EXPIRED",
        sub = "PLEASE RENEW",
        borderStyle = "solid", borderThickness = 2.5,
    },
}

local currentRole = string.lower(SafeTostring(guardRole))
local currentIsOwner = (guardData and guardData.isOwner == true) or (currentRole == "owner")
local currentIsAdmin = (guardData and guardData.isAdmin == true) or (currentRole == "admin") or currentIsOwner
local currentExpiry = nil
local currentMap = nil

if guardData and guardData.expired and guardData.expired ~= "null" and guardData.expired ~= "" then
    currentExpiry = SafeTostring(guardData.expired)
end

local screenGui, mainFrame, hideIcon

local function HttpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url, true) end)
    if not ok or not res or res == "null" then return nil end
    local dec = nil
    pcall(function() dec = HttpService:JSONDecode(res) end)
    return dec
end

local function GetAvatarUrl(uid)
    return "rbxthumb://type=AvatarHeadShot&id=" .. SafeTostring(uid) .. "&w=150&h=150"
end

local function IsFeatureBlocked(featureId)
    local bl = HttpGet(BACKEND_URL .. "/get?path=" .. HttpService:UrlEncode("/UserScriptBlacklist/" .. userId .. "/" .. featureId))
    if bl == true or bl == "true" then return true end
    return false
end

local function IsFeatureForcedAllow(featureId)
    local wl = HttpGet(BACKEND_URL .. "/get?path=" .. HttpService:UrlEncode("/UserScriptWhitelist/" .. userId .. "/" .. featureId))
    if wl == true or wl == "true" then return true end
    return false
end

local function ValidateRole()
    local url = BACKEND_URL .. "/check-role?userId=" .. userId
    local ok, res = pcall(function() return game:HttpGet(url, true) end)
    if not ok or not res or res == "null" or res == "" then return nil, "Backend error" end
    local data = nil
    pcall(function() data = HttpService:JSONDecode(res) end)
    if not data then return nil, "Parse error" end
    local roleStr = SafeTostring(data.role or "denied")
    currentRole = string.lower(roleStr)
    currentIsOwner = (data.isOwner == true) or (data.isOwner == "true") or (currentRole == "owner")
    currentIsAdmin = (data.isAdmin == true) or (data.isAdmin == "true") or (currentRole == "admin") or currentIsOwner
    local expVal = data.expired
    if expVal == nil or expVal == "null" or expVal == "" then currentExpiry = nil
    else currentExpiry = SafeTostring(expVal) end
    local statusStr = SafeTostring(data.status)
    if currentRole == "banned" or string.upper(statusStr) == "BANNED" then return "banned", data end
    if currentRole == "denied" or currentRole == "unknown" or currentRole == "" then return "denied", data end
    if currentRole == "expired" and not currentIsOwner then return "expired", data end
    if currentExpiry and not currentIsOwner and not currentIsAdmin then
        local expTime = nil
        pcall(function()
            local y, m, d = string.match(currentExpiry, "(%d+)-(%d+)-(%d+)")
            if y and m and d then
                local yN, mN, dN = tonumber(y), tonumber(m), tonumber(d)
                if yN and mN and dN then
                    expTime = os.time({year=yN, month=mN, day=dN, hour=23, min=59})
                end
            end
        end)
        if expTime and os.time() > expTime then
            currentRole = "expired"
            return "expired", data
        end
    end
    return currentRole, data
end

local function CheckMaintenance(role)
    local cfg = HttpGet(BACKEND_URL .. "/get?path=" .. HttpService:UrlEncode("/Config/Maintenance"))
    if not cfg or type(cfg) ~= "table" then return false end
    if not cfg.Enabled then return false end
    if role == "owner" then return false end
    local allowed = cfg.AllowedRoles or {}
    if allowed[role] then return false end
    return true, cfg.Message or "Sedang maintenance"
end

local function ApplyRoleBorder(stroke, role)
    local cfg = ROLE_CONFIG[role] or ROLE_CONFIG.denied
    stroke.Thickness = cfg.borderThickness or 2.5
    stroke.Color = Color3.fromRGB(255, 255, 255)
    local style = cfg.borderStyle or "solid"

    if style == "rainbow" then
        local grad = Instance.new("UIGradient", stroke)
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 255)),
        })
        grad.Name = "RoleGrad"
        task.spawn(function()
            while grad and grad.Parent do
                grad.Rotation = (grad.Rotation + 3) % 360
                task.wait(0.03)
            end
        end)
    elseif style == "black_blue" then
        local grad = Instance.new("UIGradient", stroke)
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 150, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
        })
        grad.Name = "RoleGrad"
        task.spawn(function()
            while grad and grad.Parent do
                grad.Rotation = (grad.Rotation + 3) % 360
                task.wait(0.03)
            end
        end)
    elseif style == "black_gold" then
        local grad = Instance.new("UIGradient", stroke)
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 215, 0)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
        })
        grad.Name = "RoleGrad"
        task.spawn(function()
            while grad and grad.Parent do
                grad.Rotation = (grad.Rotation + 3) % 360
                task.wait(0.03)
            end
        end)
    elseif style == "black_green" then
        local grad = Instance.new("UIGradient", stroke)
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 136)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
        })
        grad.Name = "RoleGrad"
        task.spawn(function()
            while grad and grad.Parent do
                grad.Rotation = (grad.Rotation + 3) % 360
                task.wait(0.03)
            end
        end)
    else
        stroke.Color = cfg.color
    end
end

local function GetRoleGradientColor(role)
    local cfg = ROLE_CONFIG[role] or ROLE_CONFIG.denied
    local style = cfg.borderStyle or "solid"

    if style == "rainbow" then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 255)),
        })
    elseif style == "black_blue" then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 150, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
        })
    elseif style == "black_gold" then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 215, 0)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
        })
    elseif style == "black_green" then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 136)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
        })
    else
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, cfg.color),
            ColorSequenceKeypoint.new(1, cfg.color2 or cfg.color),
        })
    end
end

local function PlayCyberpunkAnimation(onComplete)
    local animGui = Instance.new("ScreenGui")
    animGui.Name = "DVExploitsCyberpunk"
    animGui.ResetOnSpawn = false
    animGui.DisplayOrder = 9999
    animGui.IgnoreGuiInset = true
    animGui.Parent = PlayerGui

    local bg = Instance.new("Frame", animGui)
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BorderSizePixel = 0
    bg.ZIndex = 1

    local noiseFrame = Instance.new("Frame", animGui)
    noiseFrame.Size = UDim2.new(1, 0, 1, 0)
    noiseFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    noiseFrame.BackgroundTransparency = 0.97
    noiseFrame.BorderSizePixel = 0
    noiseFrame.ZIndex = 2

    task.spawn(function()
        while noiseFrame.Parent do
            noiseFrame.BackgroundTransparency = 0.95 + math.random() * 0.04
            task.wait(0.05)
        end
    end)

    local scanlines = Instance.new("Frame", animGui)
    scanlines.Size = UDim2.new(1, 0, 1, 0)
    scanlines.BackgroundTransparency = 1
    scanlines.ZIndex = 3
    for i = 1, 50 do
        local line = Instance.new("Frame", scanlines)
        line.Size = UDim2.new(1, 0, 0, 1)
        line.Position = UDim2.new(0, 0, 0, i * 14)
        line.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
        line.BackgroundTransparency = 0.92
        line.BorderSizePixel = 0
        line.ZIndex = 3
    end

    local borderOuter = Instance.new("Frame", animGui)
    borderOuter.Size = UDim2.new(1, -40, 1, -40)
    borderOuter.Position = UDim2.new(0, 20, 0, 20)
    borderOuter.BackgroundTransparency = 1
    borderOuter.ZIndex = 4

    local outerStroke = Instance.new("UIStroke", borderOuter)
    outerStroke.Color = Color3.fromRGB(0, 255, 255)
    outerStroke.Thickness = 1
    outerStroke.Transparency = 0.5

    for _, pos in ipairs({
        UDim2.new(0, 0, 0, 0),
        UDim2.new(1, -30, 0, 0),
        UDim2.new(0, 0, 1, -3),
        UDim2.new(1, -30, 1, -3),
    }) do
        local c = Instance.new("Frame", borderOuter)
        c.Size = UDim2.new(0, 30, 0, 3)
        c.Position = pos
        c.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
        c.BorderSizePixel = 0
        c.ZIndex = 5
    end

    local avatarSize = IS_MOBILE and 80 or 100
    local avatarTop = IS_MOBILE and 70 or 100

    local avatarHolder = Instance.new("Frame", animGui)
    avatarHolder.Size = UDim2.new(0, avatarSize, 0, avatarSize)
    avatarHolder.Position = UDim2.new(0.5, -avatarSize/2, 0, avatarTop)
    avatarHolder.BackgroundTransparency = 1
    avatarHolder.ZIndex = 10

    local avatarRing1 = Instance.new("Frame", avatarHolder)
    avatarRing1.Size = UDim2.new(1, 4, 1, 4)
    avatarRing1.Position = UDim2.new(0, -2, 0, -2)
    avatarRing1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    avatarRing1.BorderSizePixel = 0
    avatarRing1.ZIndex = 9
    Instance.new("UICorner", avatarRing1).CornerRadius = UDim.new(1, 0)

    local ring1Grad = Instance.new("UIGradient", avatarRing1)
    ring1Grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 0, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 255)),
    })

    task.spawn(function()
        while avatarRing1.Parent do
            ring1Grad.Rotation = (ring1Grad.Rotation + 8) % 360
            task.wait(0.03)
        end
    end)

    local avatarFrame = Instance.new("Frame", avatarHolder)
    avatarFrame.Size = UDim2.new(1, -8, 1, -8)
    avatarFrame.Position = UDim2.new(0, 4, 0, 4)
    avatarFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
    avatarFrame.BorderSizePixel = 0
    avatarFrame.ZIndex = 10
    Instance.new("UICorner", avatarFrame).CornerRadius = UDim.new(1, 0)

    local avatarImg = Instance.new("ImageLabel", avatarFrame)
    avatarImg.Size = UDim2.new(1, 0, 1, 0)
    avatarImg.BackgroundTransparency = 1
    avatarImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
    avatarImg.ZIndex = 11
    Instance.new("UICorner", avatarImg).CornerRadius = UDim.new(1, 0)

    local avatarBottom = avatarTop + avatarSize

    local usernameLbl = Instance.new("TextLabel", animGui)
    usernameLbl.Size = UDim2.new(1, -40, 0, IS_MOBILE and 24 or 30)
    usernameLbl.Position = UDim2.new(0, 20, 0, avatarBottom + 10)
    usernameLbl.BackgroundTransparency = 1
    usernameLbl.Font = Enum.Font.GothamBold
    usernameLbl.Text = LocalPlayer.Name
    usernameLbl.TextColor3 = Color3.fromRGB(0, 255, 255)
    usernameLbl.TextSize = IS_MOBILE and 18 or 24
    usernameLbl.ZIndex = 10

    local idLbl = Instance.new("TextLabel", animGui)
    idLbl.Size = UDim2.new(1, -40, 0, IS_MOBILE and 16 or 20)
    idLbl.Position = UDim2.new(0, 20, 0, avatarBottom + (IS_MOBILE and 36 or 42))
    idLbl.BackgroundTransparency = 1
    idLbl.Font = Enum.Font.Code
    idLbl.Text = "ID: " .. SafeTostring(LocalPlayer.UserId)
    idLbl.TextColor3 = Color3.fromRGB(120, 120, 140)
    idLbl.TextSize = IS_MOBILE and 11 or 14
    idLbl.ZIndex = 10

    local dividerLine = Instance.new("Frame", animGui)
    dividerLine.Size = UDim2.new(0.6, 0, 0, 1)
    dividerLine.Position = UDim2.new(0.2, 0, 0, avatarBottom + (IS_MOBILE and 60 or 75))
    dividerLine.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    dividerLine.BackgroundTransparency = 0.6
    dividerLine.BorderSizePixel = 0
    dividerLine.ZIndex = 10

    local validatingLbl = Instance.new("TextLabel", animGui)
    validatingLbl.Size = UDim2.new(1, -40, 0, IS_MOBILE and 22 or 30)
    validatingLbl.Position = UDim2.new(0, 20, 0, avatarBottom + (IS_MOBILE and 75 or 95))
    validatingLbl.BackgroundTransparency = 1
    validatingLbl.Font = Enum.Font.GothamBold
    validatingLbl.Text = "VALIDATING ROLE..."
    validatingLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    validatingLbl.TextSize = IS_MOBILE and 14 or 22
    validatingLbl.TextStrokeTransparency = 0.5
    validatingLbl.TextStrokeColor3 = Color3.fromRGB(0, 255, 255)
    validatingLbl.ZIndex = 10

    task.spawn(function()
        while validatingLbl.Parent do
            validatingLbl.TextColor3 = Color3.fromRGB(
                200 + math.random() * 55,
                200 + math.random() * 55,
                200 + math.random() * 55
            )
            task.wait(0.08)
        end
    end)

    local roleTextHolder = Instance.new("Frame", animGui)
    roleTextHolder.Size = UDim2.new(1, 0, 0, IS_MOBILE and 70 or 100)
    roleTextHolder.Position = UDim2.new(0, 0, 0, avatarBottom + (IS_MOBILE and 100 or 130))
    roleTextHolder.BackgroundTransparency = 1
    roleTextHolder.ZIndex = 10

    local roleFontSize = IS_MOBILE and 55 or 80

    local roleGlitch1 = Instance.new("TextLabel", roleTextHolder)
    roleGlitch1.Size = UDim2.new(1, 0, 1, 0)
    roleGlitch1.BackgroundTransparency = 1
    roleGlitch1.Font = Enum.Font.GothamBlack
    roleGlitch1.Text = ""
    roleGlitch1.TextColor3 = Color3.fromRGB(0, 255, 255)
    roleGlitch1.TextSize = roleFontSize
    roleGlitch1.Position = UDim2.new(0, -3, 0, 0)
    roleGlitch1.TextTransparency = 0.4
    roleGlitch1.ZIndex = 10

    local roleGlitch2 = Instance.new("TextLabel", roleTextHolder)
    roleGlitch2.Size = UDim2.new(1, 0, 1, 0)
    roleGlitch2.BackgroundTransparency = 1
    roleGlitch2.Font = Enum.Font.GothamBlack
    roleGlitch2.Text = ""
    roleGlitch2.TextColor3 = Color3.fromRGB(255, 0, 255)
    roleGlitch2.TextSize = roleFontSize
    roleGlitch2.Position = UDim2.new(0, 3, 0, 0)
    roleGlitch2.TextTransparency = 0.4
    roleGlitch2.ZIndex = 10

    local roleMain = Instance.new("TextLabel", roleTextHolder)
    roleMain.Size = UDim2.new(1, 0, 1, 0)
    roleMain.BackgroundTransparency = 1
    roleMain.Font = Enum.Font.GothamBlack
    roleMain.Text = ""
    roleMain.TextColor3 = Color3.fromRGB(255, 255, 255)
    roleMain.TextSize = roleFontSize
    roleMain.ZIndex = 11

    task.spawn(function()
        while roleTextHolder.Parent do
            roleGlitch1.Position = UDim2.new(0, -3 + (math.random() * 6 - 3), 0, math.random() * 4 - 2)
            roleGlitch2.Position = UDim2.new(0, 3 + (math.random() * 6 - 3), 0, math.random() * 4 - 2)
            task.wait(0.05)
        end
    end)

    local progressTop = avatarBottom + (IS_MOBILE and 180 or 240)

    local progressHolder = Instance.new("Frame", animGui)
    progressHolder.Size = UDim2.new(0.85, 0, 0, 40)
    progressHolder.Position = UDim2.new(0.075, 0, 0, progressTop)
    progressHolder.BackgroundTransparency = 1
    progressHolder.ZIndex = 10

    local loadingLbl = Instance.new("TextLabel", progressHolder)
    loadingLbl.Size = UDim2.new(0.5, 0, 0, 20)
    loadingLbl.Position = UDim2.new(0, 0, 0, 0)
    loadingLbl.BackgroundTransparency = 1
    loadingLbl.Font = Enum.Font.GothamBold
    loadingLbl.Text = "LOADING... 0%"
    loadingLbl.TextColor3 = Color3.fromRGB(0, 255, 255)
    loadingLbl.TextSize = IS_MOBILE and 11 or 14
    loadingLbl.TextXAlignment = Enum.TextXAlignment.Left
    loadingLbl.ZIndex = 10

    local statusLbl = Instance.new("TextLabel", progressHolder)
    statusLbl.Size = UDim2.new(0.5, 0, 0, 20)
    statusLbl.Position = UDim2.new(0.5, 0, 0, 0)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Font = Enum.Font.GothamBold
    statusLbl.Text = ""
    statusLbl.TextColor3 = Color3.fromRGB(255, 0, 255)
    statusLbl.TextSize = IS_MOBILE and 11 or 14
    statusLbl.TextXAlignment = Enum.TextXAlignment.Right
    statusLbl.ZIndex = 10

    local progressBg = Instance.new("Frame", progressHolder)
    progressBg.Size = UDim2.new(1, 0, 0, 20)
    progressBg.Position = UDim2.new(0, 0, 0, 22)
    progressBg.BackgroundColor3 = Color3.fromRGB(0, 20, 30)
    progressBg.BorderSizePixel = 2
    progressBg.BorderColor3 = Color3.fromRGB(0, 255, 255)
    progressBg.ZIndex = 10
    Instance.new("UICorner", progressBg).CornerRadius = UDim.new(0, 3)

    local progressFill = Instance.new("Frame", progressBg)
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    progressFill.BorderSizePixel = 0
    progressFill.ZIndex = 11
    Instance.new("UICorner", progressFill).CornerRadius = UDim.new(0, 3)

    local progressGrad = Instance.new("UIGradient", progressFill)
    progressGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 255)),
    })

    local panelHeight = IS_MOBILE and 110 or 140
    local panelWidth = IS_MOBILE and 0.9 or 0.85

    local bottomPanel = Instance.new("Frame", animGui)
    bottomPanel.Size = UDim2.new(panelWidth, 0, 0, panelHeight)
    bottomPanel.Position = UDim2.new((1-panelWidth)/2, 0, 1, 200)
    bottomPanel.BackgroundColor3 = Color3.fromRGB(0, 5, 10)
    bottomPanel.BorderSizePixel = 0
    bottomPanel.ZIndex = 10
    Instance.new("UICorner", bottomPanel).CornerRadius = UDim.new(0, 8)

    local panelStroke = Instance.new("UIStroke", bottomPanel)
    panelStroke.Color = Color3.fromRGB(0, 255, 255)
    panelStroke.Thickness = 1.5
    panelStroke.Transparency = 0.3

    local shieldSize = IS_MOBILE and 45 or 60
    local shieldIcon = Instance.new("TextLabel", bottomPanel)
    shieldIcon.Size = UDim2.new(0, shieldSize, 0, shieldSize)
    shieldIcon.Position = UDim2.new(0, IS_MOBILE and 15 or 20, 0, IS_MOBILE and 20 or 25)
    shieldIcon.BackgroundTransparency = 1
    shieldIcon.Font = Enum.Font.GothamBold
    shieldIcon.Text = "🛡️"
    shieldIcon.TextColor3 = Color3.fromRGB(0, 255, 255)
    shieldIcon.TextSize = IS_MOBILE and 32 or 45
    shieldIcon.ZIndex = 11

    local accessLbl = Instance.new("TextLabel", bottomPanel)
    accessLbl.Size = UDim2.new(0.6, 0, 0, 18)
    accessLbl.Position = UDim2.new(0, IS_MOBILE and 70 or 100, 0, IS_MOBILE and 15 or 20)
    accessLbl.BackgroundTransparency = 1
    accessLbl.Font = Enum.Font.GothamBold
    accessLbl.Text = "ACCESS LEVEL"
    accessLbl.TextColor3 = Color3.fromRGB(0, 255, 255)
    accessLbl.TextSize = IS_MOBILE and 10 or 13
    accessLbl.TextXAlignment = Enum.TextXAlignment.Left
    accessLbl.ZIndex = 11

    local accessValueLbl = Instance.new("TextLabel", bottomPanel)
    accessValueLbl.Size = UDim2.new(0.6, 0, 0, 28)
    accessValueLbl.Position = UDim2.new(0, IS_MOBILE and 70 or 100, 0, IS_MOBILE and 32 or 40)
    accessValueLbl.BackgroundTransparency = 1
    accessValueLbl.Font = Enum.Font.GothamBlack
    accessValueLbl.Text = ""
    accessValueLbl.TextColor3 = Color3.fromRGB(255, 0, 255)
    accessValueLbl.TextSize = IS_MOBILE and 16 or 22
    accessValueLbl.TextXAlignment = Enum.TextXAlignment.Left
    accessValueLbl.ZIndex = 11

    local subAccessLbl = Instance.new("TextLabel", bottomPanel)
    subAccessLbl.Size = UDim2.new(0.7, 0, 0, 16)
    subAccessLbl.Position = UDim2.new(0, IS_MOBILE and 70 or 100, 0, IS_MOBILE and 58 or 70)
    subAccessLbl.BackgroundTransparency = 1
    subAccessLbl.Font = Enum.Font.Gotham
    subAccessLbl.Text = ""
    subAccessLbl.TextColor3 = Color3.fromRGB(150, 150, 160)
    subAccessLbl.TextSize = IS_MOBILE and 8 or 11
    subAccessLbl.TextXAlignment = Enum.TextXAlignment.Left
    subAccessLbl.ZIndex = 11

    local fpSize = IS_MOBILE and 40 or 50
    local fingerprintIcon = Instance.new("TextLabel", bottomPanel)
    fingerprintIcon.Size = UDim2.new(0, fpSize, 0, fpSize)
    fingerprintIcon.Position = UDim2.new(1, IS_MOBILE and -55 or -70, 0, IS_MOBILE and 22 or 30)
    fingerprintIcon.BackgroundTransparency = 1
    fingerprintIcon.Font = Enum.Font.GothamBold
    fingerprintIcon.Text = "🔍"
    fingerprintIcon.TextColor3 = Color3.fromRGB(255, 0, 255)
    fingerprintIcon.TextSize = IS_MOBILE and 30 or 40
    fingerprintIcon.ZIndex = 11

    task.spawn(function()
        local pulse = 0
        while fingerprintIcon.Parent do
            pulse = pulse + 0.1
            local scale = 1 + math.sin(pulse) * 0.15
            fingerprintIcon.TextSize = (IS_MOBILE and 30 or 40) * scale
            task.wait(0.05)
        end
    end)

    local warningLbl = Instance.new("TextLabel", bottomPanel)
    warningLbl.Size = UDim2.new(1, -20, 0, 20)
    warningLbl.Position = UDim2.new(0, 10, 1, -25)
    warningLbl.BackgroundTransparency = 1
    warningLbl.Font = Enum.Font.GothamBold
    warningLbl.Text = "⚠️ SYSTEM OVERRIDE • PERMISSION: ..."
    warningLbl.TextColor3 = Color3.fromRGB(255, 0, 255)
    warningLbl.TextSize = IS_MOBILE and 9 or 11
    warningLbl.ZIndex = 11

    local actualRole, actualData

    task.spawn(function()
        local totalTime = 4.0
        local startTime = tick()
        while tick() - startTime < totalTime do
            local elapsed = tick() - startTime
            local pct = math.min(elapsed / totalTime, 1)
            local pctInt = math.floor(pct * 100)
            loadingLbl.Text = "LOADING... " .. pctInt .. "%"
            progressFill.Size = UDim2.new(pct, 0, 1, 0)
            if pctInt >= 30 and pctInt < 60 then
                statusLbl.Text = "VALIDATING"
            elseif pctInt >= 60 and pctInt < 90 then
                statusLbl.Text = "DECRYPTING"
            elseif pctInt >= 90 then
                statusLbl.Text = "ALMOST THERE"
            end
            task.wait(0.05)
        end
        loadingLbl.Text = "LOADING... 100%"
        progressFill.Size = UDim2.new(1, 0, 1, 0)
        statusLbl.Text = "COMPLETE"
    end)

    task.wait(0.3)
    actualRole, actualData = ValidateRole()
    task.wait(4.0)

    if not actualRole then
        actualRole = "denied"
        actualData = { reason = "Timeout" }
    end

    local cfg = ROLE_CONFIG[actualRole] or ROLE_CONFIG.denied

    usernameLbl.Text = LocalPlayer.Name .. " " .. cfg.icon
    usernameLbl.TextColor3 = cfg.color

    roleGlitch1.Text = cfg.label
    roleGlitch1.TextColor3 = cfg.color
    roleGlitch2.Text = cfg.label
    roleGlitch2.TextColor3 = Color3.fromRGB(
        math.max(0, 255 - cfg.color.R),
        math.max(0, 255 - cfg.color.G),
        math.max(0, 255 - cfg.color.B)
    )
    roleMain.Text = cfg.label
    roleMain.TextColor3 = cfg.color

    accessValueLbl.Text = cfg.label .. " " .. cfg.icon
    accessValueLbl.TextColor3 = cfg.color
    subAccessLbl.Text = cfg.welcome
    warningLbl.Text = "⚠️ " .. cfg.sub
    warningLbl.TextColor3 = cfg.color

    progressFill.BackgroundColor3 = cfg.color
    progressGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, cfg.color),
        ColorSequenceKeypoint.new(1, cfg.color2),
    })

    local flash = Instance.new("Frame", animGui)
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flash.BackgroundTransparency = 1
    flash.BorderSizePixel = 0
    flash.ZIndex = 100
    TweenService:Create(flash, TweenInfo.new(0.15), {BackgroundTransparency = 0.3}):Play()
    task.wait(0.15)
    TweenService:Create(flash, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()

    PlaySound()

    TweenService:Create(bottomPanel, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new((1-panelWidth)/2, 0, 1, -(panelHeight + 30)),
    }):Play()

    task.wait(2.5)

    TweenService:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
    TweenService:Create(noiseFrame, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
    TweenService:Create(bottomPanel, TweenInfo.new(0.5), {BackgroundTransparency = 1, Position = UDim2.new((1-panelWidth)/2, 0, 1, 100)}):Play()

    task.wait(0.6)
    animGui:Destroy()

    if onComplete then
        onComplete(actualRole, actualData)
    end
end

local function CreateAvatarWithRing(parent, size, roleCfg, showRing)
    local container = Instance.new("Frame", parent)
    container.Name = "AvatarContainer"
    container.Size = UDim2.new(0, size, 0, size)
    container.BackgroundTransparency = 1
    container.ZIndex = 11

    if showRing then
        local ringHolder = Instance.new("Frame", container)
        ringHolder.Name = "RingHolder"
        ringHolder.Size = UDim2.new(1, 4, 1, 4)
        ringHolder.Position = UDim2.new(0, -2, 0, -2)
        ringHolder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ringHolder.BorderSizePixel = 0
        ringHolder.ZIndex = 9
        Instance.new("UICorner", ringHolder).CornerRadius = UDim.new(1, 0)

        local ringGrad = Instance.new("UIGradient", ringHolder)
        ringGrad.Color = GetRoleGradientColor(currentRole)

        task.spawn(function()
            local rot = 0
            while ringHolder and ringHolder.Parent do
                rot = (rot + 6) % 360
                ringGrad.Rotation = rot
                task.wait(0.03)
            end
        end)
    end

    local avatarFrame = Instance.new("Frame", container)
    avatarFrame.Name = "AvatarFrame"
    avatarFrame.Size = UDim2.new(1, -4, 1, -4)
    avatarFrame.Position = UDim2.new(0, 2, 0, 2)
    avatarFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
    avatarFrame.BorderSizePixel = 0
    avatarFrame.ZIndex = 11
    Instance.new("UICorner", avatarFrame).CornerRadius = UDim.new(1, 0)

    local avatarImg = Instance.new("ImageLabel", avatarFrame)
    avatarImg.Name = "AvatarImage"
    avatarImg.Size = UDim2.new(1, 0, 1, 0)
    avatarImg.BackgroundTransparency = 1
    avatarImg.Image = GetAvatarUrl(LocalPlayer.UserId)
    avatarImg.ZIndex = 12
    Instance.new("UICorner", avatarImg).CornerRadius = UDim.new(1, 0)

    return container
end

local function ClearScroll(scroll)
    for _, c in ipairs(scroll:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
end

local isHidden = false

local function CreateHideIcon()
    if hideIcon and hideIcon.Parent then hideIcon:Destroy() end

    hideIcon = Instance.new("TextButton")
    hideIcon.Name = "DvHideIcon"
    hideIcon.Parent = screenGui
    hideIcon.BackgroundColor3 = Color3.fromRGB(0, 10, 15)
    hideIcon.BorderSizePixel = 0
    hideIcon.Position = UDim2.new(0, 15, 0.5, -24)
    hideIcon.Size = UDim2.new(0, 48, 0, 48)
    hideIcon.Font = Enum.Font.GothamBold
    hideIcon.Text = "⚡"
    hideIcon.TextColor3 = Color3.fromRGB(0, 255, 255)
    hideIcon.TextSize = 24
    hideIcon.Visible = false
    hideIcon.ZIndex = 200
    hideIcon.Active = true
    Instance.new("UICorner", hideIcon).CornerRadius = UDim.new(1, 0)

    local iconStroke = Instance.new("UIStroke", hideIcon)
    iconStroke.Color = Color3.fromRGB(0, 255, 255)
    iconStroke.Thickness = 2
    iconStroke.Name = "IconStroke"

    local iconGrad = Instance.new("UIGradient", iconStroke)
    iconGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 0, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 255)),
    })
    iconGrad.Name = "IconGrad"

    task.spawn(function()
        local rot = 0
        while hideIcon and hideIcon.Parent do
            rot = (rot + 6) % 360
            iconGrad.Rotation = rot
            task.wait(0.03)
        end
    end)

    local dragging = false
    local dragStart, startPos

    hideIcon.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            dragStart = input.Position
            startPos = hideIcon.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragStart and (input.UserInputType == Enum.UserInputType.MouseMovement 
           or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then
                dragging = true
            end
            if dragging then
                hideIcon.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 
           or input.UserInputType == Enum.UserInputType.Touch then
            task.wait(0.05)
            dragging = false
            dragStart = nil
        end
    end)

    hideIcon.MouseButton1Click:Connect(function()
        if dragging then return end
        ShowMainUI()
    end)

    return hideIcon
end

local function HideMainUI()
    isHidden = true
    if mainFrame then mainFrame.Visible = false end
    if not hideIcon then
        CreateHideIcon()
    end
    hideIcon.Visible = true
    hideIcon.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(hideIcon, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 48, 0, 48)
    }):Play()
    Notify("👁 UI Hidden", "Tap ⚡ buat balikin", 2)
end

function ShowMainUI()
    isHidden = false
    if hideIcon then
        TweenService:Create(hideIcon, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0)
        }):Play()
        task.wait(0.3)
        hideIcon.Visible = false
    end
    if mainFrame then
        mainFrame.Visible = true
        mainFrame.Size = UDim2.new(0, 0, 0, 460)
        mainFrame.Position = UDim2.new(0.5, 0, 0.5, -230)
        TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 340, 0, 460),
            Position = UDim2.new(0.5, -170, 0.5, -230),
        }):Play()
    end
end

local function CreateMapSelectorUI(role)
    if screenGui and screenGui.Parent then screenGui:Destroy() end

    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DVExploitsLoader"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 999
    screenGui.Parent = PlayerGui

    local wrap = Instance.new("Frame", screenGui)
    wrap.Name = "Wrap"
    wrap.Size = UDim2.new(0, 340, 0, 460)
    wrap.Position = UDim2.new(0.5, 200, 0.5, -230)
    wrap.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    wrap.BorderSizePixel = 0
    wrap.Active = true
    wrap.Draggable = true
    Instance.new("UICorner", wrap).CornerRadius = UDim.new(0, 14)

    local wrapStroke = Instance.new("UIStroke", wrap)
    ApplyRoleBorder(wrapStroke, role)

    TweenService:Create(wrap, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -170, 0.5, -230)
    }):Play()

    local inner = Instance.new("Frame", wrap)
    inner.Name = "Inner"
    inner.BackgroundColor3 = Color3.fromRGB(5, 5, 10)
    inner.BorderSizePixel = 0
    inner.Position = UDim2.new(0, 4, 0, 4)
    inner.Size = UDim2.new(1, -8, 1, -8)
    Instance.new("UICorner", inner).CornerRadius = UDim.new(0, 11)

    local header = Instance.new("Frame", inner)
    header.BackgroundColor3 = Color3.fromRGB(10, 5, 15)
    header.BorderSizePixel = 0
    header.Size = UDim2.new(1, 0, 0, 40)
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 11)

    local titleLbl = Instance.new("TextLabel", header)
    titleLbl.Name = "Title"
    titleLbl.BackgroundTransparency = 1
    titleLbl.Position = UDim2.new(0, 12, 0, 0)
    titleLbl.Size = UDim2.new(1, -80, 1, 0)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.Text = "⚡ DV EXPLOITS - GAME SELECT"
    titleLbl.TextColor3 = Color3.fromRGB(0, 255, 255)
    titleLbl.TextSize = 12
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left

    local closeBtn = Instance.new("TextButton", header)
    closeBtn.BackgroundColor3 = Color3.fromRGB(150, 20, 50)
    closeBtn.Position = UDim2.new(1, -30, 0.5, -11)
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 13
    closeBtn.BorderSizePixel = 0
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)
    closeBtn.MouseButton1Click:Connect(function()
        if screenGui then screenGui:Destroy() end
    end)

    local hideBtn = Instance.new("TextButton", header)
    hideBtn.BackgroundColor3 = Color3.fromRGB(20, 40, 60)
    hideBtn.Position = UDim2.new(1, -55, 0.5, -11)
    hideBtn.Size = UDim2.new(0, 22, 0, 22)
    hideBtn.Font = Enum.Font.GothamBold
    hideBtn.Text = "👁"
    hideBtn.TextColor3 = Color3.fromRGB(150, 220, 255)
    hideBtn.TextSize = 12
    hideBtn.BorderSizePixel = 0
    Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0, 5)
    hideBtn.MouseButton1Click:Connect(function()
        HideMainUI()
    end)

    local content = Instance.new("Frame", inner)
    content.Name = "Content"
    content.BackgroundTransparency = 1
    content.Position = UDim2.new(0, 0, 0, 40)
    content.Size = UDim2.new(1, 0, 1, -40)

    local cfg = ROLE_CONFIG[role] or ROLE_CONFIG.denied

    local userCard = Instance.new("Frame", content)
    userCard.Name = "UserCard"
    userCard.BackgroundColor3 = Color3.fromRGB(8, 8, 15)
    userCard.BorderSizePixel = 0
    userCard.Position = UDim2.new(0, 10, 0, 8)
    userCard.Size = UDim2.new(1, -20, 0, 78)
    Instance.new("UICorner", userCard).CornerRadius = UDim.new(0, 8)

    local userCardStroke = Instance.new("UIStroke", userCard)
    ApplyRoleBorder(userCardStroke, role)

    local avatarWrap = CreateAvatarWithRing(userCard, 54, cfg, true)
    avatarWrap.Position = UDim2.new(0, 10, 0, 12)
    avatarWrap.ZIndex = 5

    local nameLbl = Instance.new("TextLabel", userCard)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Position = UDim2.new(0, 74, 0, 10)
    nameLbl.Size = UDim2.new(1, -84, 0, 18)
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.Text = LocalPlayer.Name
    nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLbl.TextSize = 12
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    local dispLbl = Instance.new("TextLabel", userCard)
    dispLbl.BackgroundTransparency = 1
    dispLbl.Position = UDim2.new(0, 74, 0, 26)
    dispLbl.Size = UDim2.new(1, -84, 0, 12)
    dispLbl.Font = Enum.Font.Code
    dispLbl.Text = "@" .. LocalPlayer.DisplayName
    dispLbl.TextColor3 = Color3.fromRGB(150, 150, 180)
    dispLbl.TextSize = 9
    dispLbl.TextXAlignment = Enum.TextXAlignment.Left

    local roleBadge = Instance.new("Frame", userCard)
    roleBadge.BackgroundColor3 = Color3.fromRGB(
        math.floor(cfg.color.R * 0.2),
        math.floor(cfg.color.G * 0.2),
        math.floor(cfg.color.B * 0.2)
    )
    roleBadge.BorderSizePixel = 0
    roleBadge.Position = UDim2.new(0, 74, 0, 42)
    roleBadge.Size = UDim2.new(0, 130, 0, 20)
    Instance.new("UICorner", roleBadge).CornerRadius = UDim.new(0, 5)

    local roleTxt = Instance.new("TextLabel", roleBadge)
    roleTxt.Size = UDim2.new(1, 0, 1, 0)
    roleTxt.BackgroundTransparency = 1
    roleTxt.Font = Enum.Font.GothamBold
    roleTxt.Text = cfg.icon .. " " .. cfg.label
    roleTxt.TextColor3 = cfg.color
    roleTxt.TextSize = 10

    local idInfo = Instance.new("TextLabel", userCard)
    idInfo.BackgroundTransparency = 1
    idInfo.Position = UDim2.new(0, 74, 0, 62)
    idInfo.Size = UDim2.new(1, -84, 0, 12)
    idInfo.Font = Enum.Font.Code
    local expText = currentExpiry and ("📅 " .. currentExpiry) or "📅 Lifetime"
    idInfo.Text = "🆔 " .. SafeTostring(LocalPlayer.UserId) .. "  •  " .. expText
    idInfo.TextColor3 = Color3.fromRGB(130, 130, 150)
    idInfo.TextSize = 8
    idInfo.TextXAlignment = Enum.TextXAlignment.Left

    local scroll = Instance.new("ScrollingFrame", content)
    scroll.Name = "Scroll"
    scroll.BackgroundTransparency = 1
    scroll.Position = UDim2.new(0, 10, 0, 94)
    scroll.Size = UDim2.new(1, -20, 1, -120)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = cfg.color
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    local scrollLayout = Instance.new("UIListLayout", scroll)
    scrollLayout.Padding = UDim.new(0, 8)

    local footer = Instance.new("TextLabel", content)
    footer.BackgroundTransparency = 1
    footer.Position = UDim2.new(0, 10, 1, -22)
    footer.Size = UDim2.new(1, -20, 0, 16)
    footer.Font = Enum.Font.GothamBold
    footer.Text = "⚡ Powered by DV Exploits"
    footer.TextColor3 = Color3.fromRGB(0, 255, 255)
    footer.TextSize = 9
    footer.TextXAlignment = Enum.TextXAlignment.Center

    return {
        wrap = wrap,
        header = header,
        titleLbl = titleLbl,
        content = content,
        scroll = scroll,
        scrollLayout = scrollLayout,
        hideBtn = hideBtn,
        userCard = userCard,
    }
end

local RenderFeatureList

local function RenderMapList(ui)
    ClearScroll(ui.scroll)
    ui.titleLbl.Text = "⚡ DV EXPLOITS - GAME SELECT"
    currentMap = nil

    for mapId, mapInfo in pairs(MAPS) do
        local card = Instance.new("Frame", ui.scroll)
        card.Size = UDim2.new(1, -12, 0, 100)
        card.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
        card.BorderSizePixel = 0
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local cardStroke = Instance.new("UIStroke", card)
        cardStroke.Color = Color3.fromRGB(40, 60, 80)
        cardStroke.Thickness = 1

        local icon = Instance.new("TextLabel", card)
        icon.BackgroundTransparency = 1
        icon.Position = UDim2.new(0, 10, 0, 8)
        icon.Size = UDim2.new(0, 40, 0, 40)
        icon.Font = Enum.Font.GothamBold
        icon.Text = mapInfo.icon
        icon.TextColor3 = Color3.fromRGB(0, 255, 255)
        icon.TextSize = 28

        local nameLbl = Instance.new("TextLabel", card)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Position = UDim2.new(0, 58, 0, 8)
        nameLbl.Size = UDim2.new(1, -68, 0, 20)
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.Text = mapInfo.name
        nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLbl.TextSize = 13
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left

        local descLbl = Instance.new("TextLabel", card)
        descLbl.BackgroundTransparency = 1
        descLbl.Position = UDim2.new(0, 58, 0, 28)
        descLbl.Size = UDim2.new(1, -68, 0, 14)
        descLbl.Font = Enum.Font.Gotham
        descLbl.Text = mapInfo.desc
        descLbl.TextColor3 = Color3.fromRGB(150, 150, 180)
        descLbl.TextSize = 9
        descLbl.TextXAlignment = Enum.TextXAlignment.Left

        local countLbl = Instance.new("TextLabel", card)
        countLbl.BackgroundTransparency = 1
        countLbl.Position = UDim2.new(0, 58, 0, 44)
        countLbl.Size = UDim2.new(1, -68, 0, 14)
        countLbl.Font = Enum.Font.Code
        countLbl.Text = "📦 " .. #mapInfo.features .. " features"
        countLbl.TextColor3 = Color3.fromRGB(0, 200, 150)
        countLbl.TextSize = 9
        countLbl.TextXAlignment = Enum.TextXAlignment.Left

        local openBtn = Instance.new("TextButton", card)
        openBtn.Size = UDim2.new(1, -20, 0, 26)
        openBtn.Position = UDim2.new(0, 10, 1, -34)
        openBtn.BackgroundColor3 = Color3.fromRGB(0, 60, 80)
        openBtn.Font = Enum.Font.GothamBold
        openBtn.Text = "🎮 BUKA " .. mapInfo.name
        openBtn.TextColor3 = Color3.fromRGB(0, 255, 255)
        openBtn.TextSize = 11
        openBtn.BorderSizePixel = 0
        Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 6)

        openBtn.MouseButton1Click:Connect(function()
            currentMap = mapId
            RenderFeatureList(ui, mapId)
        end)
    end

    task.wait()
    ui.scroll.CanvasSize = UDim2.new(0, 0, 0, ui.scrollLayout.AbsoluteContentSize.Y + 8)
end

RenderFeatureList = function(ui, mapId)
    ClearScroll(ui.scroll)
    local mapInfo = MAPS[mapId]
    if not mapInfo then return end

    ui.titleLbl.Text = "⚡ " .. mapInfo.icon .. " " .. mapInfo.name

    local backCard = Instance.new("Frame", ui.scroll)
    backCard.Size = UDim2.new(1, -12, 0, 28)
    backCard.BackgroundColor3 = Color3.fromRGB(15, 25, 35)
    backCard.BorderSizePixel = 0
    Instance.new("UICorner", backCard).CornerRadius = UDim.new(0, 6)

    local backBtn = Instance.new("TextButton", backCard)
    backBtn.Size = UDim2.new(1, 0, 1, 0)
    backBtn.BackgroundTransparency = 1
    backBtn.Font = Enum.Font.GothamBold
    backBtn.Text = "← KEMBALI KE MAP LIST"
    backBtn.TextColor3 = Color3.fromRGB(0, 255, 255)
    backBtn.TextSize = 10
    backBtn.MouseButton1Click:Connect(function()
        RenderMapList(ui)
    end)

    for _, feature in ipairs(mapInfo.features) do
        local card = Instance.new("Frame", ui.scroll)
        card.Size = UDim2.new(1, -12, 0, 110)
        card.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
        card.BorderSizePixel = 0
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local cardStroke = Instance.new("UIStroke", card)
        cardStroke.Color = Color3.fromRGB(40, 60, 80)
        cardStroke.Thickness = 1

        local icon = Instance.new("TextLabel", card)
        icon.BackgroundTransparency = 1
        icon.Position = UDim2.new(0, 10, 0, 8)
        icon.Size = UDim2.new(0, 40, 0, 40)
        icon.Font = Enum.Font.GothamBold
        icon.Text = feature.icon
        icon.TextColor3 = Color3.fromRGB(0, 255, 255)
        icon.TextSize = 26

        local nameLbl = Instance.new("TextLabel", card)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Position = UDim2.new(0, 58, 0, 8)
        nameLbl.Size = UDim2.new(1, -68, 0, 18)
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.Text = feature.name
        nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLbl.TextSize = 12
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left

        local descLbl = Instance.new("TextLabel", card)
        descLbl.BackgroundTransparency = 1
        descLbl.Position = UDim2.new(0, 58, 0, 26)
        descLbl.Size = UDim2.new(1, -68, 0, 14)
        descLbl.Font = Enum.Font.Gotham
        descLbl.Text = feature.desc
        descLbl.TextColor3 = Color3.fromRGB(150, 150, 180)
        descLbl.TextSize = 9
        descLbl.TextXAlignment = Enum.TextXAlignment.Left

        local statusLbl = Instance.new("TextLabel", card)
        statusLbl.BackgroundTransparency = 1
        statusLbl.Position = UDim2.new(0, 58, 0, 44)
        statusLbl.Size = UDim2.new(1, -68, 0, 14)
        statusLbl.Font = Enum.Font.Code
        statusLbl.Text = feature.loaded and "🟢 ACTIVE" or "⚫ OFF"
        statusLbl.TextColor3 = feature.loaded and Color3.fromRGB(0, 255, 136) or Color3.fromRGB(150, 150, 150)
        statusLbl.TextSize = 9
        statusLbl.TextXAlignment = Enum.TextXAlignment.Left

        local toggleBtn = Instance.new("TextButton", card)
        toggleBtn.Size = UDim2.new(1, -20, 0, 34)
        toggleBtn.Position = UDim2.new(0, 10, 1, -42)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.BorderSizePixel = 0
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

        local function UpdateVisual()
            local blocked = IsFeatureBlocked(feature.id)
            local forcedAllow = IsFeatureForcedAllow(feature.id)
            local canAccess = forcedAllow or feature.allowedRoles[currentRole]

            if blocked then
                cardStroke.Color = Color3.fromRGB(120, 30, 30)
                toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 15, 15)
                toggleBtn.Text = "🚫 BLOCKED BY OWNER"
                toggleBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
                toggleBtn.Active = false
                statusLbl.Text = "🚫 Blocked"
                statusLbl.TextColor3 = Color3.fromRGB(255, 100, 100)
            elseif not canAccess then
                cardStroke.Color = Color3.fromRGB(120, 30, 30)
                toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
                toggleBtn.Text = "🔒 LOCKED"
                toggleBtn.TextColor3 = Color3.fromRGB(150, 100, 100)
                toggleBtn.Active = false
                statusLbl.Text = "❌ No Access"
                statusLbl.TextColor3 = Color3.fromRGB(255, 120, 120)
            elseif feature.loaded then
                cardStroke.Color = Color3.fromRGB(0, 200, 100)
                toggleBtn.BackgroundColor3 = Color3.fromRGB(100, 20, 40)
                toggleBtn.Text = "⏹ UNLOAD / OFF"
                toggleBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
                toggleBtn.Active = true
                statusLbl.Text = "🟢 ACTIVE"
                statusLbl.TextColor3 = Color3.fromRGB(0, 255, 136)
            else
                cardStroke.Color = Color3.fromRGB(40, 60, 80)
                toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 60, 80)
                toggleBtn.Text = "⚡ LOAD / ON"
                toggleBtn.TextColor3 = Color3.fromRGB(0, 255, 255)
                toggleBtn.Active = true
                statusLbl.Text = "⚫ OFF"
                statusLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
            end
        end

        UpdateVisual()

        toggleBtn.MouseButton1Click:Connect(function()
            if IsFeatureBlocked(feature.id) then
                Notify("🚫 Blocked", feature.name .. " diblokir owner", 4)
                UpdateVisual()
                return
            end

            local forcedAllow = IsFeatureForcedAllow(feature.id)
            if not forcedAllow and not feature.allowedRoles[currentRole] then
                Notify("🔒 No Access", "Role lu gak boleh akses", 4)
                return
            end

            if feature.loaded then
                if feature.unloadFunc and _G[feature.unloadFunc] and type(_G[feature.unloadFunc]) == "function" then
                    pcall(_G[feature.unloadFunc])
                    feature.loaded = false
                    UpdateVisual()
                    Notify("⏹ Unloaded", feature.name .. " dimatikan", 3)
                    return
                end
                Notify("⚠️ Manual Restart", "Fitur gak support unload", 5)
                return
            end

            toggleBtn.Text = "⏳ LOADING..."
            toggleBtn.Active = false

            task.spawn(function()
                local role, data = ValidateRole()
                if not role or role == "denied" or role == "banned" or role == "expired" then
                    Notify("❌ Validasi Gagal", SafeTostring(data and data.reason or "Role invalid"), 5)
                    UpdateVisual()
                    return
                end

                if IsFeatureBlocked(feature.id) then
                    Notify("🚫 Blocked", feature.name .. " diblokir owner", 4)
                    UpdateVisual()
                    return
                end

                local inMaint, maintMsg = CheckMaintenance(role)
                if inMaint then
                    Notify("🔧 Maintenance", SafeTostring(maintMsg), 5)
                    UpdateVisual()
                    return
                end

                local ok, err = pcall(function()
                    loadstring(game:HttpGet(feature.url))()
                end)

                if ok then
                    feature.loaded = true
                    UpdateVisual()
                    Notify("🎉 Success", feature.name .. " dimuat!", 3)
                else
                    Notify("❌ Gagal Load", SafeTostring(err), 5)
                    UpdateVisual()
                end
            end)
        end)
    end

    task.wait()
    ui.scroll.CanvasSize = UDim2.new(0, 0, 0, ui.scrollLayout.AbsoluteContentSize.Y + 8)
end

task.spawn(function()
    PlayCyberpunkAnimation(function(role, data)
        if role == "denied" or role == "banned" or role == "expired" then
            Notify("❌ Akses Ditolak", "Hubungi owner", 5)
            if role == "banned" then
                task.wait(2)
                LocalPlayer:Kick("🚫 Banned: " .. SafeTostring(data and data.reason or "-"))
            end
            return
        end

        local inMaint, maintMsg = CheckMaintenance(role)
        if inMaint then
            Notify("🔧 Maintenance", SafeTostring(maintMsg), 6)
            return
        end

        local ui = CreateMapSelectorUI(role)
        mainFrame = ui.wrap

        RenderMapList(ui)

        Notify("✅ Loader Ready", "Pilih map untuk mulai", 3)
    end)
end)
