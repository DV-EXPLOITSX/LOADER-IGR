local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local BACKEND_URL = "https://igr-backen.vercel.app/api"
local URL_AUTOFARM = "https://raw.githubusercontent.com/DV-EXPLOITSX/LOADER-IGR/refs/heads/main/1"
local URL_SHOP = "https://raw.githubusercontent.com/DV-EXPLOITSX/LOADER-IGR/refs/heads/main/2"

local function HttpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url, true) end)
    if not ok or not res or res == "null" then return nil end
    local dec = nil
    pcall(function() dec = HttpService:JSONDecode(res) end)
    return dec
end

local function HttpPut(url, data)
    local body = HttpService:JSONEncode(data)
    if type(request) == "function" then
        local ok = pcall(function()
            return request({ Url = url, Method = "PUT", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
        if ok then return true end
    end
    if type(http_request) == "function" then
        local ok = pcall(function()
            return http_request({ Url = url, Method = "PUT", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
        if ok then return true end
    end
    return false
end

local function FirebaseGet(path)
    return HttpGet(BACKEND_URL .. "/get?path=" .. HttpService:UrlEncode(path))
end

local function FirebasePut(path, data)
    local body = HttpService:JSONEncode(data)
    local url = BACKEND_URL .. "/put?path=" .. HttpService:UrlEncode(path)
    local headers = {
        ["Content-Type"] = "application/json",
        ["X-User-Id"] = tostring(LocalPlayer.UserId),
    }
    if type(request) == "function" then
        local ok, res = pcall(function()
            return request({ Url = url, Method = "PUT", Headers = headers, Body = body })
        end)
        if ok and res and res.StatusCode then
            return res.StatusCode >= 200 and res.StatusCode < 300
        end
    end
    if type(http_request) == "function" then
        local ok, res = pcall(function()
            return http_request({ Url = url, Method = "PUT", Headers = headers, Body = body })
        end)
        if ok and res and res.StatusCode then
            return res.StatusCode >= 200 and res.StatusCode < 300
        end
    end
    return false
end
local function FindUserIdByUsername(username)
    if not username or username == "" then return nil end
    local wlData = FirebaseGet("/Whitelist")
    if type(wlData) ~= "table" then return nil end
    local target = tostring(username):lower()
    for userId, info in pairs(wlData) do
        if type(info) == "table" and info.Username then
            if tostring(info.Username):lower() == target then
                return tostring(userId)
            end
        end
    end
    return nil
end

local currentRole = "unknown"
local currentExpiry = nil
local currentReason = nil
local currentIsOwner = false
local currentIsAdmin = false

local ChatGui = nil
local chatMessages = {}
local chatScrollRef = nil
local chatRefreshConn = nil
local chatCooldown = 0
local CHAT_STATE = { isOpen = false, isEnabled = true, autoClear = true, clearInterval = 86400 }

local ROLE_COLORS = {
    owner = Color3.fromRGB(255, 215, 0),
    admin = Color3.fromRGB(100, 180, 255),
    vip = Color3.fromRGB(200, 150, 255),
    user = Color3.fromRGB(150, 255, 180),
    guest = Color3.fromRGB(180, 180, 180),
}

local ROLE_BADGE = {
    owner = "👑 OWNER",
    admin = "🛡️ ADMIN",
    vip = "🏆 VIP",
    user = "✅ USER",
    guest = "❓ GUEST",
}

local function getRoleColor(role) return ROLE_COLORS[role] or ROLE_COLORS.guest end
local function getRoleBadge(role) return ROLE_BADGE[role] or ROLE_BADGE.guest end

local function escapeText(str) return tostring(str):gsub("[%c]", "") end

local function loadChatSettings()
    local cfg = FirebaseGet("/Config/ChatSettings")
    if cfg and type(cfg) == "table" then
        CHAT_STATE.isEnabled = cfg.Enabled ~= false
        CHAT_STATE.autoClear = cfg.AutoClear ~= false
        CHAT_STATE.clearInterval = tonumber(cfg.ClearInterval) or 86400
    end
end

local function sendChatMessage(text)
    if not CHAT_STATE.isEnabled then return end
    
    if currentRole == "unknown" or currentRole == "denied" then
        pcall(CheckUserRole)
    end
    
    print("[CHAT] Kirim sebagai role:", currentRole)
    
    if currentRole == "denied" or currentRole == "expired" or currentRole == "banned" or currentRole == "unknown" then 
        print("[CHAT] Blocked - role invalid")
        return 
    end
    
    local now = tick()
    if now - chatCooldown < 3 then return end
    text = escapeText(text):gsub("^%s+", ""):gsub("%s+$", "")
    if #text == 0 then return end
    if #text > 200 then text = text:sub(1, 200) end
    chatCooldown = now
    local msgId = tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
    local payload = {
        UserId = tostring(LocalPlayer.UserId),
        Username = LocalPlayer.Name,
        DisplayName = LocalPlayer.DisplayName,
        Role = currentRole,
        Text = text,
        Timestamp = os.time(),
        Date = os.date("%H:%M"),
    }
    FirebasePut("/Chat/" .. msgId, payload)
end

local function deleteChatMessage(msgId)
    if currentRole ~= "owner" and currentRole ~= "admin" then return end
    print("[DEL] deleting:", msgId)
    local url = BACKEND_URL .. "/put?path=" .. HttpService:UrlEncode("/Chat/" .. msgId)
    local headers = {
        ["Content-Type"] = "application/json",
        ["X-User-Id"] = tostring(LocalPlayer.UserId),
    }
    local res = nil
    if type(request) == "function" then
        local ok, r = pcall(function()
            return request({ Url = url, Method = "PUT", Headers = headers, Body = "null" })
        end)
        if ok then res = r end
    elseif type(http_request) == "function" then
        local ok, r = pcall(function()
            return http_request({ Url = url, Method = "PUT", Headers = headers, Body = "null" })
        end)
        if ok then res = r end
    end
    if res and type(res) == "table" then
        print("[DEL] status:", res.StatusCode, "body:", res.Body)
    end
    task.wait(0.5)
    if chatRefreshConn then pcall(chatRefreshConn) end
end

local function clearAllChat()
    if currentRole ~= "owner" then return end
    FirebasePut("/Chat", nil)
end

local function updateChatSettings()
    if currentRole ~= "owner" and currentRole ~= "admin" then return end
    FirebasePut("/Config/ChatSettings", {
        Enabled = CHAT_STATE.isEnabled,
        AutoClear = CHAT_STATE.autoClear,
        ClearInterval = CHAT_STATE.clearInterval,
        UpdatedBy = LocalPlayer.Name,
        UpdatedAt = os.time(),
    })
end

local function ParseDate(s)
    if not s or type(s) ~= "string" then return nil end
    local y, m, d = s:match("(%d+)-(%d+)-(%d+)")
    if y and m and d then return os.time({year=tonumber(y), month=tonumber(m), day=tonumber(d), hour=23, min=59}) end
    return nil
end

local function FormatDate(t)
    if not t then return nil end
    return os.date("%Y-%m-%d", t)
end

local ROLE_ORDER = { user = 1, admin = 2, vip = 3, owner = 4 }
local ROLE_LABEL = { user = "✅ USER", admin = "🛡️ ADMIN", vip = "🏆 VIP", owner = "👑 OWNER" }
local ADMIN_ROLES = { moderator = 1, admin = 2, owner = 3 }

local function LogAction(action, target, detail)
    if not currentIsOwner and not currentIsAdmin then return end
    local logId = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
    FirebasePut("/AuditLog/" .. logId, {
        Action = action, Target = tostring(target), Detail = tostring(detail or ""),
        By = LocalPlayer.Name, Timestamp = os.time(), Date = os.date("%d/%m/%y %H:%M")
    })
end

local function Heartbeat()
    local userId = tostring(LocalPlayer.UserId)
    local device = "Unknown"
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        device = "Mobile"
    elseif UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
        device = "PC"
    elseif game:GetService("GuiService"):IsTenFootInterface() then
        device = "Console"
    end
    local locale = "unknown"
    pcall(function() locale = game:GetService("LocalizationService").RobloxLocaleId end)
    FirebasePut("/ActiveUsers/" .. userId, {
        Username = LocalPlayer.Name,
        DisplayName = LocalPlayer.DisplayName,
        Role = currentRole or "unknown",
        Device = device,
        Locale = locale,
        AccountAge = LocalPlayer.AccountAge,
        LastSeen = os.time(),
        LastSeenStr = os.date("%d/%m/%y %H:%M")
    })
end

local function CheckMaintenance(myRole)
    local cfg = FirebaseGet("/Config/Maintenance")
    if not cfg or type(cfg) ~= "table" then return false end
    if not cfg.Enabled then return false end
    if myRole == "owner" then return false end
    local allowed = cfg.AllowedRoles or {}
    if allowed[myRole] then return false end
    return true, cfg.Message or "Sedang maintenance. Coba lagi nanti."
end

local function CheckUserRole()
    local userId = tostring(LocalPlayer.UserId)
    local ok, res = pcall(function()
        return game:HttpGet(BACKEND_URL .. "/check-role?userId=" .. userId)
    end)
    if not ok or not res then
        currentRole = "denied"
        currentReason = "Backend error"
        return "denied"
    end
    local data = nil
    pcall(function() data = HttpService:JSONDecode(res) end)
    if not data then
        currentRole = "denied"
        currentReason = "Parse error"
        return "denied"
    end
        currentRole = data.role or "denied"
    currentExpiry = data.expired
    currentReason = data.reason
    currentIsOwner = data.isOwner or false
    currentIsAdmin = data.isAdmin or false
    return currentRole
end

if PlayerGui:FindFirstChild("DV EXPLOITS") then
    PlayerGui["DV EXPLOITS"]:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DV EXPLOITS"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
screenGui.Parent = PlayerGui

local loadingBorder = Instance.new("Frame")
loadingBorder.Parent = screenGui
loadingBorder.Size = UDim2.new(0, 320, 0, 180)
loadingBorder.Position = UDim2.new(0.5, -160, 0.5, -90)
loadingBorder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
loadingBorder.BorderSizePixel = 0
loadingBorder.ZIndex = 99
Instance.new("UICorner", loadingBorder).CornerRadius = UDim.new(0, 14)

local loadGrad = Instance.new("UIGradient")
loadGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
    ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 255, 0)),
    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(0, 255, 0)),
    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 255, 255)),
    ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0, 100, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 255)),
})
loadGrad.Parent = loadingBorder

task.spawn(function()
    local rot = 0
    while loadingBorder and loadingBorder.Parent do
        rot = (rot + 12) % 360
        loadGrad.Rotation = rot
        task.wait(0.016)
    end
end)

task.spawn(function()
    while true do
        task.wait(0.05)
        if roleBadgeGrad then
            roleBadgeGrad.Rotation = (roleBadgeGrad.Rotation + 5) % 360
        end
    end
end)

local loadingFrame = Instance.new("Frame")
loadingFrame.Parent = loadingBorder
loadingFrame.BackgroundColor3 = Color3.fromRGB(10, 5, 5)
loadingFrame.BorderSizePixel = 0
loadingFrame.Position = UDim2.new(0, 4, 0, 4)
loadingFrame.Size = UDim2.new(1, -8, 1, -8)
loadingFrame.ZIndex = 100
Instance.new("UICorner", loadingFrame).CornerRadius = UDim.new(0, 10)

local loadAvatar = Instance.new("ImageLabel")
loadAvatar.Parent = loadingFrame
loadAvatar.BackgroundColor3 = Color3.fromRGB(20, 5, 5)
loadAvatar.Position = UDim2.new(0.5, -26, 0, 12)
loadAvatar.Size = UDim2.new(0, 52, 0, 52)
loadAvatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
loadAvatar.ZIndex = 101
Instance.new("UICorner", loadAvatar).CornerRadius = UDim.new(1, 0)

local loadAvatarStroke = Instance.new("UIStroke")
loadAvatarStroke.Parent = loadAvatar
loadAvatarStroke.Color = Color3.fromRGB(255, 50, 50)
loadAvatarStroke.Thickness = 2

local loadTitle = Instance.new("TextLabel")
loadTitle.Parent = loadingFrame
loadTitle.BackgroundTransparency = 1
loadTitle.Position = UDim2.new(0, 10, 0, 68)
loadTitle.Size = UDim2.new(1, -20, 0, 22)
loadTitle.Font = Enum.Font.GothamBold
loadTitle.Text = "DV EXPLOITS HUB"
loadTitle.TextColor3 = Color3.fromRGB(255, 50, 50)
loadTitle.TextSize = 15
loadTitle.TextXAlignment = Enum.TextXAlignment.Center
loadTitle.ZIndex = 101

local loadSub = Instance.new("TextLabel")
loadSub.Parent = loadingFrame
loadSub.BackgroundTransparency = 1
loadSub.Position = UDim2.new(0, 10, 0, 90)
loadSub.Size = UDim2.new(1, -20, 0, 16)
loadSub.Font = Enum.Font.Code
loadSub.Text = "VERIFYING..."
loadSub.TextColor3 = Color3.fromRGB(180, 100, 100)
loadSub.TextSize = 9
loadSub.TextXAlignment = Enum.TextXAlignment.Center
loadSub.ZIndex = 101

local progressBg = Instance.new("Frame")
progressBg.Parent = loadingFrame
progressBg.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
progressBg.BorderSizePixel = 0
progressBg.Position = UDim2.new(0, 25, 0, 116)
progressBg.Size = UDim2.new(1, -50, 0, 7)
progressBg.ZIndex = 101
Instance.new("UICorner", progressBg).CornerRadius = UDim.new(1, 0)

local progressBar = Instance.new("Frame")
progressBar.Parent = progressBg
progressBar.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
progressBar.BorderSizePixel = 0
progressBar.Size = UDim2.new(0, 0, 1, 0)
progressBar.ZIndex = 102
Instance.new("UICorner", progressBar).CornerRadius = UDim.new(1, 0)

local percentLbl = Instance.new("TextLabel")
percentLbl.Parent = loadingFrame
percentLbl.BackgroundTransparency = 1
percentLbl.Position = UDim2.new(0, 10, 0, 130)
percentLbl.Size = UDim2.new(1, -20, 0, 18)
percentLbl.Font = Enum.Font.Code
percentLbl.Text = "0%"
percentLbl.TextColor3 = Color3.fromRGB(150, 80, 80)
percentLbl.TextSize = 9
percentLbl.TextXAlignment = Enum.TextXAlignment.Center
percentLbl.ZIndex = 101

local maintenanceOverlay = Instance.new("Frame")
maintenanceOverlay.Parent = screenGui
maintenanceOverlay.Size = UDim2.new(1, 0, 1, 0)
maintenanceOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
maintenanceOverlay.BackgroundTransparency = 0.3
maintenanceOverlay.BorderSizePixel = 0
maintenanceOverlay.Visible = false
maintenanceOverlay.ZIndex = 800

local maintenanceFrame = Instance.new("Frame")
maintenanceFrame.Parent = maintenanceOverlay
maintenanceFrame.Size = UDim2.new(0, 320, 0, 200)
maintenanceFrame.Position = UDim2.new(0.5, -160, 0.5, -100)
maintenanceFrame.BackgroundColor3 = Color3.fromRGB(20, 10, 5)
maintenanceFrame.BorderSizePixel = 0
maintenanceFrame.ZIndex = 801
Instance.new("UICorner", maintenanceFrame).CornerRadius = UDim.new(0, 14)
local maintStroke = Instance.new("UIStroke", maintenanceFrame)
maintStroke.Color = Color3.fromRGB(255, 180, 0)
maintStroke.Thickness = 2

local maintIcon = Instance.new("TextLabel", maintenanceFrame)
maintIcon.Size = UDim2.new(1, 0, 0, 60)
maintIcon.Position = UDim2.new(0, 0, 0, 15)
maintIcon.BackgroundTransparency = 1
maintIcon.Font = Enum.Font.GothamBold
maintIcon.Text = "🔧"
maintIcon.TextColor3 = Color3.fromRGB(255, 180, 0)
maintIcon.TextSize = 48
maintIcon.ZIndex = 802

local maintTitle = Instance.new("TextLabel", maintenanceFrame)
maintTitle.Size = UDim2.new(1, -20, 0, 26)
maintTitle.Position = UDim2.new(0, 10, 0, 80)
maintTitle.BackgroundTransparency = 1
maintTitle.Font = Enum.Font.GothamBold
maintTitle.Text = "🔧 MAINTENANCE MODE"
maintTitle.TextColor3 = Color3.fromRGB(255, 180, 0)
maintTitle.TextSize = 16
maintTitle.ZIndex = 802

local maintMsg = Instance.new("TextLabel", maintenanceFrame)
maintMsg.Size = UDim2.new(1, -20, 0, 50)
maintMsg.Position = UDim2.new(0, 10, 0, 110)
maintMsg.BackgroundTransparency = 1
maintMsg.Font = Enum.Font.Gotham
maintMsg.Text = "Sedang maintenance. Coba lagi nanti."
maintMsg.TextColor3 = Color3.fromRGB(220, 200, 180)
maintMsg.TextSize = 11
maintMsg.TextWrapped = true
maintMsg.ZIndex = 802

local maintSub = Instance.new("TextLabel", maintenanceFrame)
maintSub.Size = UDim2.new(1, -20, 0, 18)
maintSub.Position = UDim2.new(0, 10, 1, -30)
maintSub.BackgroundTransparency = 1
maintSub.Font = Enum.Font.Code
maintSub.Text = "Contact: suyadi_irengbadeg"
maintSub.TextColor3 = Color3.fromRGB(150, 130, 100)
maintSub.TextSize = 9
maintSub.ZIndex = 802

local mainWrap = Instance.new("Frame")
mainWrap.Parent = screenGui
mainWrap.Size = UDim2.new(0, 320, 0, 440)
mainWrap.Position = UDim2.new(0.5, -160, 0.4, -220)
mainWrap.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
mainWrap.BorderSizePixel = 0
mainWrap.Visible = false
mainWrap.Active = true
mainWrap.Draggable = true
Instance.new("UICorner", mainWrap).CornerRadius = UDim.new(0, 14)

local mainGrad = Instance.new("UIGradient")
mainGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
    ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 255, 0)),
    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(0, 255, 0)),
    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 255, 255)),
    ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0, 100, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 255)),
})
mainGrad.Parent = mainWrap

task.spawn(function()
    local rot = 0
    while mainWrap and mainWrap.Parent do
        rot = (rot + 12) % 360
        mainGrad.Rotation = rot
        task.wait(0.016)
    end
end)

local mainFrame = Instance.new("Frame")
mainFrame.Parent = mainWrap
mainFrame.BackgroundColor3 = Color3.fromRGB(12, 6, 6)
mainFrame.BorderSizePixel = 0
mainFrame.Position = UDim2.new(0, 4, 0, 4)
mainFrame.Size = UDim2.new(1, -8, 1, -8)
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 11)

local topBar = Instance.new("Frame")
topBar.Parent = mainFrame
topBar.BackgroundColor3 = Color3.fromRGB(25, 8, 8)
topBar.BorderSizePixel = 0
topBar.Size = UDim2.new(1, 0, 0, 40)
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 11)

local iconAvatar = Instance.new("ImageLabel")
iconAvatar.Parent = topBar
iconAvatar.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
iconAvatar.BorderSizePixel = 0
iconAvatar.Position = UDim2.new(0, 8, 0.5, -11)
iconAvatar.Size = UDim2.new(0, 22, 0, 22)
iconAvatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
Instance.new("UICorner", iconAvatar).CornerRadius = UDim.new(1, 0)

local iconStroke = Instance.new("UIStroke", iconAvatar)
iconStroke.Color = Color3.fromRGB(255, 50, 50)
iconStroke.Thickness = 1.5

local titleLbl = Instance.new("TextLabel")
titleLbl.Parent = topBar
titleLbl.BackgroundTransparency = 1
titleLbl.Position = UDim2.new(0, 38, 0, 0)
titleLbl.Size = UDim2.new(0, 150, 1, 0)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.Text = "DV EXPLOITS HUB"
titleLbl.TextColor3 = Color3.fromRGB(255, 70, 70)
titleLbl.TextSize = 12
titleLbl.TextXAlignment = Enum.TextXAlignment.Left

local minBtn = Instance.new("TextButton")
minBtn.Parent = topBar
minBtn.BackgroundColor3 = Color3.fromRGB(50, 15, 15)
minBtn.Position = UDim2.new(1, -80, 0.5, -11)
minBtn.Size = UDim2.new(0, 22, 0, 22)
minBtn.Font = Enum.Font.GothamBold
minBtn.Text = "−"
minBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
minBtn.TextSize = 15
minBtn.BorderSizePixel = 0
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)

local hideBtn = Instance.new("TextButton")
hideBtn.Parent = topBar
hideBtn.BackgroundColor3 = Color3.fromRGB(50, 15, 15)
hideBtn.Position = UDim2.new(1, -55, 0.5, -11)
hideBtn.Size = UDim2.new(0, 22, 0, 22)
hideBtn.Font = Enum.Font.GothamBold
hideBtn.Text = "◉"
hideBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
hideBtn.TextSize = 11
hideBtn.BorderSizePixel = 0
Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0, 5)

local closeBtn = Instance.new("TextButton")
closeBtn.Parent = topBar
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
closeBtn.Position = UDim2.new(1, -30, 0.5, -11)
closeBtn.Size = UDim2.new(0, 22, 0, 22)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 13
closeBtn.BorderSizePixel = 0
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)

local content = Instance.new("Frame")
content.Parent = mainFrame
content.BackgroundTransparency = 1
content.Position = UDim2.new(0, 0, 0, 40)
content.Size = UDim2.new(1, 0, 1, -40)

local userCard = Instance.new("Frame")
userCard.Parent = content
userCard.BackgroundColor3 = Color3.fromRGB(20, 10, 10)
userCard.BorderSizePixel = 0
userCard.Position = UDim2.new(0, 10, 0, 8)
userCard.Size = UDim2.new(1, -20, 0, 72)
Instance.new("UICorner", userCard).CornerRadius = UDim.new(0, 7)
local userCardStroke = Instance.new("UIStroke", userCard)
userCardStroke.Color = Color3.fromRGB(80, 30, 30)

local userAvatar = Instance.new("ImageLabel")
userAvatar.Parent = userCard
userAvatar.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
userAvatar.BorderSizePixel = 0
userAvatar.Position = UDim2.new(0, 8, 0, 8)
userAvatar.Size = UDim2.new(0, 52, 0, 52)
userAvatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
Instance.new("UICorner", userAvatar).CornerRadius = UDim.new(1, 0)
local uaStroke = Instance.new("UIStroke", userAvatar)
uaStroke.Color = Color3.fromRGB(255, 50, 50)
uaStroke.Thickness = 2

local userNameLbl = Instance.new("TextLabel")
userNameLbl.Parent = userCard
userNameLbl.BackgroundTransparency = 1
userNameLbl.Position = UDim2.new(0, 68, 0, 6)
userNameLbl.Size = UDim2.new(1, -76, 0, 18)
userNameLbl.Font = Enum.Font.GothamBold
userNameLbl.Text = LocalPlayer.Name
userNameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
userNameLbl.TextSize = 12
userNameLbl.TextXAlignment = Enum.TextXAlignment.Left

local userIdLbl = Instance.new("TextLabel")
userIdLbl.Parent = userCard
userIdLbl.BackgroundTransparency = 1
userIdLbl.Position = UDim2.new(0, 68, 0, 22)
userIdLbl.Size = UDim2.new(1, -76, 0, 12)
userIdLbl.Font = Enum.Font.Code
userIdLbl.Text = "ID: " .. LocalPlayer.UserId
userIdLbl.TextColor3 = Color3.fromRGB(180, 140, 140)
userIdLbl.TextSize = 8
userIdLbl.TextXAlignment = Enum.TextXAlignment.Left

local roleBadge = Instance.new("TextLabel")
roleBadge.Parent = userCard
roleBadge.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
roleBadge.BorderSizePixel = 0
roleBadge.Position = UDim2.new(0, 68, 0, 38)
roleBadge.Size = UDim2.new(0, 82, 0, 18)
roleBadge.Font = Enum.Font.GothamBold
roleBadge.Text = "❓ UNKNOWN"
roleBadge.TextColor3 = Color3.fromRGB(200, 180, 180)
roleBadge.TextSize = 9
Instance.new("UICorner", roleBadge).CornerRadius = UDim.new(0, 4)

local expiryLbl = Instance.new("TextLabel")
expiryLbl.Parent = userCard
expiryLbl.BackgroundTransparency = 1
expiryLbl.Position = UDim2.new(0, 155, 0, 38)
expiryLbl.Size = UDim2.new(1, -165, 0, 18)
expiryLbl.Font = Enum.Font.Gotham
expiryLbl.Text = ""
expiryLbl.TextColor3 = Color3.fromRGB(180, 160, 160)
expiryLbl.TextSize = 8
expiryLbl.TextXAlignment = Enum.TextXAlignment.Left

local statusInfo = Instance.new("TextLabel")
statusInfo.Parent = content
statusInfo.BackgroundColor3 = Color3.fromRGB(15, 10, 20)
statusInfo.BorderSizePixel = 0
statusInfo.Position = UDim2.new(0, 10, 0, 88)
statusInfo.Size = UDim2.new(1, -20, 0, 28)
statusInfo.Font = Enum.Font.Gotham
statusInfo.Text = "Klik CHECK untuk verifikasi"
statusInfo.TextColor3 = Color3.fromRGB(200, 180, 220)
statusInfo.TextSize = 9
Instance.new("UICorner", statusInfo).CornerRadius = UDim.new(0, 5)

local checkBtn = Instance.new("TextButton")
checkBtn.Parent = content
checkBtn.BackgroundColor3 = Color3.fromRGB(50, 25, 80)
checkBtn.BorderSizePixel = 0
checkBtn.Position = UDim2.new(0, 10, 0, 123)
checkBtn.Size = UDim2.new(1, -20, 0, 34)
checkBtn.Font = Enum.Font.GothamBold
checkBtn.Text = "🔍 CHECK MY ACCOUNT"
checkBtn.TextColor3 = Color3.fromRGB(255, 220, 100)
checkBtn.TextSize = 11
Instance.new("UICorner", checkBtn).CornerRadius = UDim.new(0, 7)

local reqBtn = Instance.new("TextButton")
reqBtn.Parent = content
reqBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 20)
reqBtn.BorderSizePixel = 0
reqBtn.Position = UDim2.new(0, 10, 0, 164)
reqBtn.Size = UDim2.new(1, -20, 0, 32)
reqBtn.Font = Enum.Font.GothamBold
reqBtn.Text = "📩 REQUEST WHITELIST"
reqBtn.TextColor3 = Color3.fromRGB(255, 220, 120)
reqBtn.TextSize = 11
reqBtn.Visible = false
Instance.new("UICorner", reqBtn).CornerRadius = UDim.new(0, 7)

local loadFarmBtn = Instance.new("TextButton")
loadFarmBtn.Parent = content
loadFarmBtn.BackgroundColor3 = Color3.fromRGB(40, 12, 12)
loadFarmBtn.BorderSizePixel = 0
loadFarmBtn.Position = UDim2.new(0, 10, 0, 205)
loadFarmBtn.Size = UDim2.new(1, -20, 0, 38)
loadFarmBtn.Font = Enum.Font.GothamBold
loadFarmBtn.Text = "🚀 LOAD AUTO FARM IGR"
loadFarmBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
loadFarmBtn.TextSize = 11
loadFarmBtn.Active = false
Instance.new("UICorner", loadFarmBtn).CornerRadius = UDim.new(0, 7)

local loadShopBtn = Instance.new("TextButton")
loadShopBtn.Parent = content
loadShopBtn.BackgroundColor3 = Color3.fromRGB(40, 12, 12)
loadShopBtn.BorderSizePixel = 0
loadShopBtn.Position = UDim2.new(0, 10, 0, 248)
loadShopBtn.Size = UDim2.new(1, -20, 0, 38)
loadShopBtn.Font = Enum.Font.GothamBold
loadShopBtn.Text = "🛒 LOAD SHOP SYSTEM IGR"
loadShopBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
loadShopBtn.TextSize = 11
loadShopBtn.Active = false
Instance.new("UICorner", loadShopBtn).CornerRadius = UDim.new(0, 7)

local ownerPanelBtn = Instance.new("TextButton")
ownerPanelBtn.Parent = content
ownerPanelBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 0)
ownerPanelBtn.BorderSizePixel = 0
ownerPanelBtn.Position = UDim2.new(0, 10, 0, 291)
ownerPanelBtn.Size = UDim2.new(1, -20, 0, 34)
ownerPanelBtn.Font = Enum.Font.GothamBold
ownerPanelBtn.Text = "👑 OPEN OWNER PANEL"
ownerPanelBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
ownerPanelBtn.TextSize = 11
ownerPanelBtn.Visible = false
Instance.new("UICorner", ownerPanelBtn).CornerRadius = UDim.new(0, 7)

local creditLbl = Instance.new("TextLabel")
creditLbl.Parent = content
creditLbl.BackgroundTransparency = 1
creditLbl.Position = UDim2.new(0, 10, 1, -24)
creditLbl.Size = UDim2.new(1, -20, 0, 18)
creditLbl.Font = Enum.Font.GothamBold
creditLbl.Text = "⚡ Powered by DV Exploits ⚡"
creditLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
creditLbl.TextSize = 10
creditLbl.TextXAlignment = Enum.TextXAlignment.Center

local ownerPanel = Instance.new("Frame")
ownerPanel.Parent = screenGui
ownerPanel.Size = UDim2.new(0, 480, 0, 520)
ownerPanel.Position = UDim2.new(0.5, -240, 0.5, -260)
ownerPanel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ownerPanel.BorderSizePixel = 0
ownerPanel.Visible = false
ownerPanel.Active = true
ownerPanel.Draggable = true
Instance.new("UICorner", ownerPanel).CornerRadius = UDim.new(0, 14)

local opGrad = Instance.new("UIGradient")
opGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0)),
})
opGrad.Parent = ownerPanel

task.spawn(function()
    local rot = 0
    while ownerPanel and ownerPanel.Parent do
        rot = (rot + 12) % 360
        opGrad.Rotation = rot
        task.wait(0.016)
    end
end)

local opInner = Instance.new("Frame")
opInner.Parent = ownerPanel
opInner.BackgroundColor3 = Color3.fromRGB(15, 10, 5)
opInner.BorderSizePixel = 0
opInner.Position = UDim2.new(0, 4, 0, 4)
opInner.Size = UDim2.new(1, -8, 1, -8)
Instance.new("UICorner", opInner).CornerRadius = UDim.new(0, 11)

local opHeader = Instance.new("Frame")
opHeader.Parent = opInner
opHeader.BackgroundColor3 = Color3.fromRGB(35, 20, 5)
opHeader.BorderSizePixel = 0
opHeader.Size = UDim2.new(1, 0, 0, 38)
Instance.new("UICorner", opHeader).CornerRadius = UDim.new(0, 11)

local opTitle = Instance.new("TextLabel")
opTitle.Parent = opHeader
opTitle.BackgroundTransparency = 1
opTitle.Position = UDim2.new(0, 12, 0, 0)
opTitle.Size = UDim2.new(1, -160, 1, 0)
opTitle.Font = Enum.Font.GothamBold
opTitle.Text = "👑 OWNER PANEL"
opTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
opTitle.TextSize = 13
opTitle.TextXAlignment = Enum.TextXAlignment.Left

local opExportBtn = Instance.new("TextButton")
opExportBtn.Parent = opHeader
opExportBtn.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
opExportBtn.Position = UDim2.new(1, -100, 0.5, -10)
opExportBtn.Size = UDim2.new(0, 40, 0, 20)
opExportBtn.Font = Enum.Font.GothamBold
opExportBtn.Text = "💾 EXP"
opExportBtn.TextColor3 = Color3.fromRGB(200, 255, 200)
opExportBtn.TextSize = 9
opExportBtn.BorderSizePixel = 0
Instance.new("UICorner", opExportBtn).CornerRadius = UDim.new(0, 5)

local opClose = Instance.new("TextButton")
opClose.Parent = opHeader
opClose.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
opClose.Position = UDim2.new(1, -28, 0.5, -10)
opClose.Size = UDim2.new(0, 20, 0, 20)
opClose.Font = Enum.Font.GothamBold
opClose.Text = "✕"
opClose.TextColor3 = Color3.fromRGB(255, 255, 255)
opClose.TextSize = 12
opClose.BorderSizePixel = 0
Instance.new("UICorner", opClose).CornerRadius = UDim.new(0, 5)

local opTabs = Instance.new("Frame")
opTabs.Parent = opInner
opTabs.BackgroundTransparency = 1
opTabs.Position = UDim2.new(0, 6, 0, 44)
opTabs.Size = UDim2.new(1, -12, 0, 24)

local opTabWL = Instance.new("TextButton")
opTabWL.Parent = opTabs
opTabWL.BackgroundColor3 = Color3.fromRGB(180, 120, 0)
opTabWL.Size = UDim2.new(0.125, -2, 1, 0)
opTabWL.Font = Enum.Font.GothamBold
opTabWL.Text = "📋 WL"
opTabWL.TextColor3 = Color3.fromRGB(255, 255, 255)
opTabWL.TextSize = 8
opTabWL.BorderSizePixel = 0
Instance.new("UICorner", opTabWL).CornerRadius = UDim.new(0, 4)

local opTabReq = Instance.new("TextButton")
opTabReq.Parent = opTabs
opTabReq.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
opTabReq.Position = UDim2.new(0.125, 2, 0, 0)
opTabReq.Size = UDim2.new(0.125, -4, 1, 0)
opTabReq.Font = Enum.Font.GothamBold
opTabReq.Text = "📩 REQ"
opTabReq.TextColor3 = Color3.fromRGB(200, 180, 140)
opTabReq.TextSize = 8
opTabReq.BorderSizePixel = 0
Instance.new("UICorner", opTabReq).CornerRadius = UDim.new(0, 4)

local opTabBan = Instance.new("TextButton")
opTabBan.Parent = opTabs
opTabBan.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
opTabBan.Position = UDim2.new(0.25, 2, 0, 0)
opTabBan.Size = UDim2.new(0.125, -4, 1, 0)
opTabBan.Font = Enum.Font.GothamBold
opTabBan.Text = "🚫 BAN"
opTabBan.TextColor3 = Color3.fromRGB(200, 180, 140)
opTabBan.TextSize = 8
opTabBan.BorderSizePixel = 0
Instance.new("UICorner", opTabBan).CornerRadius = UDim.new(0, 4)

local opTabStats = Instance.new("TextButton")
opTabStats.Parent = opTabs
opTabStats.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
opTabStats.Position = UDim2.new(0.375, 2, 0, 0)
opTabStats.Size = UDim2.new(0.125, -4, 1, 0)
opTabStats.Font = Enum.Font.GothamBold
opTabStats.Text = "📊 STAT"
opTabStats.TextColor3 = Color3.fromRGB(200, 180, 140)
opTabStats.TextSize = 8
opTabStats.BorderSizePixel = 0
Instance.new("UICorner", opTabStats).CornerRadius = UDim.new(0, 4)

local opTabLog = Instance.new("TextButton")
opTabLog.Parent = opTabs
opTabLog.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
opTabLog.Position = UDim2.new(0.5, 2, 0, 0)
opTabLog.Size = UDim2.new(0.125, -4, 1, 0)
opTabLog.Font = Enum.Font.GothamBold
opTabLog.Text = "📜 LOG"
opTabLog.TextColor3 = Color3.fromRGB(200, 180, 140)
opTabLog.TextSize = 8
opTabLog.BorderSizePixel = 0
Instance.new("UICorner", opTabLog).CornerRadius = UDim.new(0, 4)

local opTabDev = Instance.new("TextButton")
opTabDev.Parent = opTabs
opTabDev.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
opTabDev.Position = UDim2.new(0.625, 2, 0, 0)
opTabDev.Size = UDim2.new(0.125, -4, 1, 0)
opTabDev.Font = Enum.Font.GothamBold
opTabDev.Text = "📱 DEV"
opTabDev.TextColor3 = Color3.fromRGB(200, 180, 140)
opTabDev.TextSize = 8
opTabDev.BorderSizePixel = 0
Instance.new("UICorner", opTabDev).CornerRadius = UDim.new(0, 4)

local opTabAnn = Instance.new("TextButton")
opTabAnn.Parent = opTabs
opTabAnn.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
opTabAnn.Position = UDim2.new(0.75, 2, 0, 0)
opTabAnn.Size = UDim2.new(0.125, -4, 1, 0)
opTabAnn.Font = Enum.Font.GothamBold
opTabAnn.Text = "📢 ANN"
opTabAnn.TextColor3 = Color3.fromRGB(200, 180, 140)
opTabAnn.TextSize = 8
opTabAnn.BorderSizePixel = 0
Instance.new("UICorner", opTabAnn).CornerRadius = UDim.new(0, 4)

local opTabCfg = Instance.new("TextButton")
opTabCfg.Parent = opTabs
opTabCfg.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
opTabCfg.Position = UDim2.new(0.875, 2, 0, 0)
opTabCfg.Size = UDim2.new(0.125, -2, 1, 0)
opTabCfg.Font = Enum.Font.GothamBold
opTabCfg.Text = "⚙️ CFG"
opTabCfg.TextColor3 = Color3.fromRGB(200, 180, 140)
opTabCfg.TextSize = 8
opTabCfg.BorderSizePixel = 0
Instance.new("UICorner", opTabCfg).CornerRadius = UDim.new(0, 4)

local opContentArea = Instance.new("Frame")
opContentArea.Parent = opInner
opContentArea.BackgroundTransparency = 1
opContentArea.Position = UDim2.new(0, 6, 0, 72)
opContentArea.Size = UDim2.new(1, -12, 1, -120)

local opWLFrame = Instance.new("Frame", opContentArea)
opWLFrame.Size = UDim2.new(1, 0, 1, 0)
opWLFrame.BackgroundTransparency = 1
opWLFrame.Visible = true

local opWLSearchBar = Instance.new("Frame", opWLFrame)
opWLSearchBar.Size = UDim2.new(1, 0, 0, 26)
opWLSearchBar.BackgroundColor3 = Color3.fromRGB(25, 15, 5)
opWLSearchBar.BorderSizePixel = 0
Instance.new("UICorner", opWLSearchBar).CornerRadius = UDim.new(0, 5)

local opWLSearch = Instance.new("TextBox", opWLSearchBar)
opWLSearch.Size = UDim2.new(1, -80, 1, -6)
opWLSearch.Position = UDim2.new(0, 6, 0, 3)
opWLSearch.BackgroundTransparency = 1
opWLSearch.PlaceholderText = "🔍 Cari user..."
opWLSearch.PlaceholderColor3 = Color3.fromRGB(160, 140, 100)
opWLSearch.Text = ""
opWLSearch.TextColor3 = Color3.fromRGB(255, 255, 255)
opWLSearch.Font = Enum.Font.Gotham
opWLSearch.TextSize = 10
opWLSearch.ClearTextOnFocus = false

local opRoleFilterBtn = Instance.new("TextButton", opWLSearchBar)
opRoleFilterBtn.Size = UDim2.new(0, 68, 1, -6)
opRoleFilterBtn.Position = UDim2.new(1, -74, 0, 3)
opRoleFilterBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 15)
opRoleFilterBtn.Text = "FILTER: ALL"
opRoleFilterBtn.TextColor3 = Color3.fromRGB(255, 220, 150)
opRoleFilterBtn.Font = Enum.Font.GothamBold
opRoleFilterBtn.TextSize = 8
opRoleFilterBtn.BorderSizePixel = 0
Instance.new("UICorner", opRoleFilterBtn).CornerRadius = UDim.new(0, 4)

local opWLBulkBar = Instance.new("Frame", opWLFrame)
opWLBulkBar.Size = UDim2.new(1, 0, 0, 22)
opWLBulkBar.Position = UDim2.new(0, 0, 0, 28)
opWLBulkBar.BackgroundColor3 = Color3.fromRGB(20, 12, 5)
opWLBulkBar.BorderSizePixel = 0
Instance.new("UICorner", opWLBulkBar).CornerRadius = UDim.new(0, 5)

local opSelectAllBtn = Instance.new("TextButton", opWLBulkBar)
opSelectAllBtn.Size = UDim2.new(0.25, -3, 1, -4)
opSelectAllBtn.Position = UDim2.new(0, 2, 0, 2)
opSelectAllBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 15)
opSelectAllBtn.Text = "☐ ALL"
opSelectAllBtn.TextColor3 = Color3.fromRGB(255, 220, 150)
opSelectAllBtn.Font = Enum.Font.GothamBold
opSelectAllBtn.TextSize = 8
opSelectAllBtn.BorderSizePixel = 0
Instance.new("UICorner", opSelectAllBtn).CornerRadius = UDim.new(0, 4)

local opBulkDelBtn = Instance.new("TextButton", opWLBulkBar)
opBulkDelBtn.Size = UDim2.new(0.36, -3, 1, -4)
opBulkDelBtn.Position = UDim2.new(0.25, 2, 0, 2)
opBulkDelBtn.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
opBulkDelBtn.Text = "🗑️ HAPUS"
opBulkDelBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
opBulkDelBtn.Font = Enum.Font.GothamBold
opBulkDelBtn.TextSize = 8
opBulkDelBtn.BorderSizePixel = 0
Instance.new("UICorner", opBulkDelBtn).CornerRadius = UDim.new(0, 4)

local opBulkBanBtn = Instance.new("TextButton", opWLBulkBar)
opBulkBanBtn.Size = UDim2.new(0.36, -3, 1, -4)
opBulkBanBtn.Position = UDim2.new(0.62, 2, 0, 2)
opBulkBanBtn.BackgroundColor3 = Color3.fromRGB(80, 20, 40)
opBulkBanBtn.Text = "🔨 BAN"
opBulkBanBtn.TextColor3 = Color3.fromRGB(255, 200, 220)
opBulkBanBtn.Font = Enum.Font.GothamBold
opBulkBanBtn.TextSize = 8
opBulkBanBtn.BorderSizePixel = 0
Instance.new("UICorner", opBulkBanBtn).CornerRadius = UDim.new(0, 4)

local opWLScroll = Instance.new("ScrollingFrame", opWLFrame)
opWLScroll.Size = UDim2.new(1, 0, 1, -54)
opWLScroll.Position = UDim2.new(0, 0, 0, 54)
opWLScroll.BackgroundColor3 = Color3.fromRGB(20, 15, 5)
opWLScroll.BorderSizePixel = 0
opWLScroll.ScrollBarThickness = 3
opWLScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 180, 0)
opWLScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", opWLScroll).CornerRadius = UDim.new(0, 7)
local opWLLayout = Instance.new("UIListLayout", opWLScroll)
opWLLayout.Padding = UDim.new(0, 3)

local opReqScroll = Instance.new("ScrollingFrame", opContentArea)
opReqScroll.Size = UDim2.new(1, 0, 1, 0)
opReqScroll.BackgroundColor3 = Color3.fromRGB(20, 15, 5)
opReqScroll.BorderSizePixel = 0
opReqScroll.ScrollBarThickness = 3
opReqScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 180, 0)
opReqScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
opReqScroll.Visible = false
Instance.new("UICorner", opReqScroll).CornerRadius = UDim.new(0, 7)
local opReqLayout = Instance.new("UIListLayout", opReqScroll)
opReqLayout.Padding = UDim.new(0, 3)

local opBanFrame = Instance.new("Frame", opContentArea)
opBanFrame.Size = UDim2.new(1, 0, 1, 0)
opBanFrame.BackgroundTransparency = 1
opBanFrame.Visible = false

local opBanInputArea = Instance.new("Frame", opBanFrame)
opBanInputArea.Size = UDim2.new(1, 0, 0, 80)
opBanInputArea.BackgroundColor3 = Color3.fromRGB(25, 15, 5)
opBanInputArea.BorderSizePixel = 0
Instance.new("UICorner", opBanInputArea).CornerRadius = UDim.new(0, 6)

local opBanInputLbl = Instance.new("TextLabel", opBanInputArea)
opBanInputLbl.Size = UDim2.new(1, -12, 0, 14)
opBanInputLbl.Position = UDim2.new(0, 6, 0, 3)
opBanInputLbl.BackgroundTransparency = 1
opBanInputLbl.Text = "🔨 Ban User:"
opBanInputLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
opBanInputLbl.Font = Enum.Font.GothamBold
opBanInputLbl.TextSize = 9
opBanInputLbl.TextXAlignment = Enum.TextXAlignment.Left

local opBanInput = Instance.new("TextBox", opBanInputArea)
opBanInput.Size = UDim2.new(0.6, -4, 0, 24)
opBanInput.Position = UDim2.new(0, 6, 0, 20)
opBanInput.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
opBanInput.BorderSizePixel = 0
opBanInput.PlaceholderText = "UserId/Username"
opBanInput.PlaceholderColor3 = Color3.fromRGB(150, 130, 100)
opBanInput.Text = ""
opBanInput.TextColor3 = Color3.fromRGB(255, 255, 255)
opBanInput.Font = Enum.Font.Code
opBanInput.TextSize = 10
opBanInput.ClearTextOnFocus = false
Instance.new("UICorner", opBanInput).CornerRadius = UDim.new(0, 4)

local opBanDurationBtn = Instance.new("TextButton", opBanInputArea)
opBanDurationBtn.Size = UDim2.new(0.2, -4, 0, 24)
opBanDurationBtn.Position = UDim2.new(0.6, 0, 0, 20)
opBanDurationBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 15)
opBanDurationBtn.Text = "Perm"
opBanDurationBtn.TextColor3 = Color3.fromRGB(255, 220, 150)
opBanDurationBtn.Font = Enum.Font.GothamBold
opBanDurationBtn.TextSize = 9
opBanDurationBtn.BorderSizePixel = 0
Instance.new("UICorner", opBanDurationBtn).CornerRadius = UDim.new(0, 4)

local opBanSubmit = Instance.new("TextButton", opBanInputArea)
opBanSubmit.Size = UDim2.new(0.2, -6, 0, 24)
opBanSubmit.Position = UDim2.new(0.8, 0, 0, 20)
opBanSubmit.BackgroundColor3 = Color3.fromRGB(150, 20, 20)
opBanSubmit.Text = "🔨 BAN"
opBanSubmit.TextColor3 = Color3.fromRGB(255, 220, 220)
opBanSubmit.Font = Enum.Font.GothamBold
opBanSubmit.TextSize = 10
opBanSubmit.BorderSizePixel = 0
Instance.new("UICorner", opBanSubmit).CornerRadius = UDim.new(0, 4)

local opBanReasonLbl = Instance.new("TextLabel", opBanInputArea)
opBanReasonLbl.Size = UDim2.new(1, -12, 0, 12)
opBanReasonLbl.Position = UDim2.new(0, 6, 0, 48)
opBanReasonLbl.BackgroundTransparency = 1
opBanReasonLbl.Text = "📝 Alasan (opsional):"
opBanReasonLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
opBanReasonLbl.Font = Enum.Font.GothamBold
opBanReasonLbl.TextSize = 8
opBanReasonLbl.TextXAlignment = Enum.TextXAlignment.Left

local opBanReason = Instance.new("TextBox", opBanInputArea)
opBanReason.Size = UDim2.new(1, -12, 0, 20)
opBanReason.Position = UDim2.new(0, 6, 0, 58)
opBanReason.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
opBanReason.BorderSizePixel = 0
opBanReason.PlaceholderText = "Contoh: Bypass license"
opBanReason.PlaceholderColor3 = Color3.fromRGB(150, 130, 100)
opBanReason.Text = ""
opBanReason.TextColor3 = Color3.fromRGB(255, 255, 255)
opBanReason.Font = Enum.Font.Gotham
opBanReason.TextSize = 9
opBanReason.ClearTextOnFocus = false
Instance.new("UICorner", opBanReason).CornerRadius = UDim.new(0, 4)

local opBanScroll = Instance.new("ScrollingFrame", opBanFrame)
opBanScroll.Size = UDim2.new(1, 0, 1, -86)
opBanScroll.Position = UDim2.new(0, 0, 0, 86)
opBanScroll.BackgroundColor3 = Color3.fromRGB(20, 15, 5)
opBanScroll.BorderSizePixel = 0
opBanScroll.ScrollBarThickness = 3
opBanScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 180, 0)
opBanScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", opBanScroll).CornerRadius = UDim.new(0, 7)
local opBanLayout = Instance.new("UIListLayout", opBanScroll)
opBanLayout.Padding = UDim.new(0, 3)

local opStatsFrame = Instance.new("ScrollingFrame", opContentArea)
opStatsFrame.Size = UDim2.new(1, 0, 1, 0)
opStatsFrame.BackgroundColor3 = Color3.fromRGB(20, 15, 5)
opStatsFrame.BorderSizePixel = 0
opStatsFrame.ScrollBarThickness = 3
opStatsFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 180, 0)
opStatsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
opStatsFrame.Visible = false
Instance.new("UICorner", opStatsFrame).CornerRadius = UDim.new(0, 7)
local opStatsLayout = Instance.new("UIListLayout", opStatsFrame)
opStatsLayout.Padding = UDim.new(0, 4)

local opLogScroll = Instance.new("ScrollingFrame", opContentArea)
opLogScroll.Size = UDim2.new(1, 0, 1, 0)
opLogScroll.BackgroundColor3 = Color3.fromRGB(20, 15, 5)
opLogScroll.BorderSizePixel = 0
opLogScroll.ScrollBarThickness = 3
opLogScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 180, 0)
opLogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
opLogScroll.Visible = false
Instance.new("UICorner", opLogScroll).CornerRadius = UDim.new(0, 7)
local opLogLayout = Instance.new("UIListLayout", opLogScroll)
opLogLayout.Padding = UDim.new(0, 3)

local opDevScroll = Instance.new("ScrollingFrame", opContentArea)
opDevScroll.Size = UDim2.new(1, 0, 1, 0)
opDevScroll.BackgroundColor3 = Color3.fromRGB(20, 15, 5)
opDevScroll.BorderSizePixel = 0
opDevScroll.ScrollBarThickness = 3
opDevScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 180, 0)
opDevScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
opDevScroll.Visible = false
Instance.new("UICorner", opDevScroll).CornerRadius = UDim.new(0, 7)
local opDevLayout = Instance.new("UIListLayout", opDevScroll)
opDevLayout.Padding = UDim.new(0, 3)

local opAnnFrame = Instance.new("Frame", opContentArea)
opAnnFrame.Size = UDim2.new(1, 0, 1, 0)
opAnnFrame.BackgroundTransparency = 1
opAnnFrame.Visible = false

local opAnnInputArea = Instance.new("Frame", opAnnFrame)
opAnnInputArea.Size = UDim2.new(1, 0, 0, 130)
opAnnInputArea.BackgroundColor3 = Color3.fromRGB(25, 15, 5)
opAnnInputArea.BorderSizePixel = 0
Instance.new("UICorner", opAnnInputArea).CornerRadius = UDim.new(0, 6)

local opAnnTitleLbl = Instance.new("TextLabel", opAnnInputArea)
opAnnTitleLbl.Size = UDim2.new(1, -12, 0, 14)
opAnnTitleLbl.Position = UDim2.new(0, 6, 0, 3)
opAnnTitleLbl.BackgroundTransparency = 1
opAnnTitleLbl.Text = "📌 Judul:"
opAnnTitleLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
opAnnTitleLbl.Font = Enum.Font.GothamBold
opAnnTitleLbl.TextSize = 9
opAnnTitleLbl.TextXAlignment = Enum.TextXAlignment.Left

local opAnnTitle = Instance.new("TextBox", opAnnInputArea)
opAnnTitle.Size = UDim2.new(1, -12, 0, 22)
opAnnTitle.Position = UDim2.new(0, 6, 0, 19)
opAnnTitle.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
opAnnTitle.BorderSizePixel = 0
opAnnTitle.PlaceholderText = "Contoh: Update v9"
opAnnTitle.PlaceholderColor3 = Color3.fromRGB(150, 130, 100)
opAnnTitle.Text = ""
opAnnTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
opAnnTitle.Font = Enum.Font.Gotham
opAnnTitle.TextSize = 10
opAnnTitle.ClearTextOnFocus = false
Instance.new("UICorner", opAnnTitle).CornerRadius = UDim.new(0, 4)

local opAnnMsgLbl = Instance.new("TextLabel", opAnnInputArea)
opAnnMsgLbl.Size = UDim2.new(1, -12, 0, 14)
opAnnMsgLbl.Position = UDim2.new(0, 6, 0, 45)
opAnnMsgLbl.BackgroundTransparency = 1
opAnnMsgLbl.Text = "📝 Pesan:"
opAnnMsgLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
opAnnMsgLbl.Font = Enum.Font.GothamBold
opAnnMsgLbl.TextSize = 9
opAnnMsgLbl.TextXAlignment = Enum.TextXAlignment.Left

local opAnnMsg = Instance.new("TextBox", opAnnInputArea)
opAnnMsg.Size = UDim2.new(1, -12, 0, 40)
opAnnMsg.Position = UDim2.new(0, 6, 0, 61)
opAnnMsg.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
opAnnMsg.BorderSizePixel = 0
opAnnMsg.PlaceholderText = "Pesan announcement..."
opAnnMsg.PlaceholderColor3 = Color3.fromRGB(150, 130, 100)
opAnnMsg.Text = ""
opAnnMsg.TextColor3 = Color3.fromRGB(255, 255, 255)
opAnnMsg.Font = Enum.Font.Gotham
opAnnMsg.TextSize = 10
opAnnMsg.TextWrapped = true
opAnnMsg.ClearTextOnFocus = false
Instance.new("UICorner", opAnnMsg).CornerRadius = UDim.new(0, 4)

local opAnnSend = Instance.new("TextButton", opAnnInputArea)
opAnnSend.Size = UDim2.new(0.48, -6, 0, 22)
opAnnSend.Position = UDim2.new(0, 6, 0, 105)
opAnnSend.BackgroundColor3 = Color3.fromRGB(20, 100, 40)
opAnnSend.Text = "📢 KIRIM KE SEMUA"
opAnnSend.TextColor3 = Color3.fromRGB(200, 255, 200)
opAnnSend.Font = Enum.Font.GothamBold
opAnnSend.TextSize = 9
opAnnSend.BorderSizePixel = 0
Instance.new("UICorner", opAnnSend).CornerRadius = UDim.new(0, 4)

local opAnnClear = Instance.new("TextButton", opAnnInputArea)
opAnnClear.Size = UDim2.new(0.48, -6, 0, 22)
opAnnClear.Position = UDim2.new(0.52, 0, 0, 105)
opAnnClear.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
opAnnClear.Text = "🗑️ HAPUS ANNOUNCEMENT"
opAnnClear.TextColor3 = Color3.fromRGB(255, 220, 220)
opAnnClear.Font = Enum.Font.GothamBold
opAnnClear.TextSize = 8
opAnnClear.BorderSizePixel = 0
Instance.new("UICorner", opAnnClear).CornerRadius = UDim.new(0, 4)

local opAnnActive = Instance.new("TextLabel", opAnnFrame)
opAnnActive.Size = UDim2.new(1, 0, 0, 24)
opAnnActive.Position = UDim2.new(0, 0, 0, 135)
opAnnActive.BackgroundColor3 = Color3.fromRGB(30, 20, 5)
opAnnActive.BorderSizePixel = 0
opAnnActive.Font = Enum.Font.GothamBold
opAnnActive.Text = "Loading..."
opAnnActive.TextColor3 = Color3.fromRGB(255, 220, 150)
opAnnActive.TextSize = 9
Instance.new("UICorner", opAnnActive).CornerRadius = UDim.new(0, 5)

local opCfgFrame = Instance.new("ScrollingFrame", opContentArea)
opCfgFrame.Size = UDim2.new(1, 0, 1, 0)
opCfgFrame.BackgroundColor3 = Color3.fromRGB(20, 15, 5)
opCfgFrame.BorderSizePixel = 0
opCfgFrame.ScrollBarThickness = 3
opCfgFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 180, 0)
opCfgFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
opCfgFrame.Visible = false
Instance.new("UICorner", opCfgFrame).CornerRadius = UDim.new(0, 7)
local opCfgLayout = Instance.new("UIListLayout", opCfgFrame)
opCfgLayout.Padding = UDim.new(0, 4)

local opStatus = Instance.new("TextLabel")
opStatus.Parent = opInner
opStatus.BackgroundColor3 = Color3.fromRGB(25, 15, 5)
opStatus.BorderSizePixel = 0
opStatus.Position = UDim2.new(0, 6, 1, -40)
opStatus.Size = UDim2.new(1, -12, 0, 32)
opStatus.Font = Enum.Font.Gotham
opStatus.Text = "⚡ Ready — v9"
opStatus.TextColor3 = Color3.fromRGB(255, 220, 150)
opStatus.TextSize = 9
Instance.new("UICorner", opStatus).CornerRadius = UDim.new(0, 5)

local dropdownOverlay = Instance.new("Frame")
dropdownOverlay.Parent = screenGui
dropdownOverlay.Size = UDim2.new(1, 0, 1, 0)
dropdownOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dropdownOverlay.BackgroundTransparency = 0.5
dropdownOverlay.BorderSizePixel = 0
dropdownOverlay.Visible = false
dropdownOverlay.ZIndex = 500

local dropdown = Instance.new("Frame")
dropdown.Parent = dropdownOverlay
dropdown.Size = UDim2.new(0, 240, 0, 280)
dropdown.Position = UDim2.new(0.5, -120, 0.5, -140)
dropdown.BackgroundColor3 = Color3.fromRGB(20, 12, 5)
dropdown.BorderSizePixel = 0
dropdown.ZIndex = 501
Instance.new("UICorner", dropdown).CornerRadius = UDim.new(0, 10)
local dropdownStroke = Instance.new("UIStroke", dropdown)
dropdownStroke.Color = Color3.fromRGB(255, 180, 0)
dropdownStroke.Thickness = 2

local dropdownTitle = Instance.new("TextLabel", dropdown)
dropdownTitle.Size = UDim2.new(1, -20, 0, 24)
dropdownTitle.Position = UDim2.new(0, 10, 0, 6)
dropdownTitle.BackgroundTransparency = 1
dropdownTitle.Font = Enum.Font.GothamBold
dropdownTitle.Text = "⚙️ PILIH"
dropdownTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
dropdownTitle.TextSize = 12
dropdownTitle.TextXAlignment = Enum.TextXAlignment.Left
dropdownTitle.ZIndex = 502

local dropdownUserName = Instance.new("TextLabel", dropdown)
dropdownUserName.Size = UDim2.new(1, -20, 0, 14)
dropdownUserName.Position = UDim2.new(0, 10, 0, 28)
dropdownUserName.BackgroundTransparency = 1
dropdownUserName.Font = Enum.Font.Gotham
dropdownUserName.Text = ""
dropdownUserName.TextColor3 = Color3.fromRGB(200, 180, 140)
dropdownUserName.TextSize = 9
dropdownUserName.TextXAlignment = Enum.TextXAlignment.Left
dropdownUserName.ZIndex = 502

local dropdownList = Instance.new("Frame", dropdown)
dropdownList.Size = UDim2.new(1, -20, 1, -46)
dropdownList.Position = UDim2.new(0, 10, 0, 46)
dropdownList.BackgroundTransparency = 1
dropdownList.ZIndex = 502

local dropdownListLayout = Instance.new("UIListLayout", dropdownList)
dropdownListLayout.Padding = UDim.new(0, 4)

local dropdownCancel = Instance.new("TextButton", dropdown)
dropdownCancel.Size = UDim2.new(1, -20, 0, 26)
dropdownCancel.Position = UDim2.new(0, 10, 1, -32)
dropdownCancel.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
dropdownCancel.Text = "✕ BATAL"
dropdownCancel.TextColor3 = Color3.fromRGB(255, 220, 220)
dropdownCancel.Font = Enum.Font.GothamBold
dropdownCancel.TextSize = 10
dropdownCancel.BorderSizePixel = 0
dropdownCancel.ZIndex = 502
Instance.new("UICorner", dropdownCancel).CornerRadius = UDim.new(0, 5)

local previewOverlay = Instance.new("Frame")
previewOverlay.Parent = screenGui
previewOverlay.Size = UDim2.new(1, 0, 1, 0)
previewOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
previewOverlay.BackgroundTransparency = 0.5
previewOverlay.BorderSizePixel = 0
previewOverlay.Visible = false
previewOverlay.ZIndex = 600

local previewFrame = Instance.new("Frame")
previewFrame.Parent = previewOverlay
previewFrame.Size = UDim2.new(0, 280, 0, 320)
previewFrame.Position = UDim2.new(0.5, -140, 0.5, -160)
previewFrame.BackgroundColor3 = Color3.fromRGB(20, 12, 5)
previewFrame.BorderSizePixel = 0
previewFrame.ZIndex = 601
Instance.new("UICorner", previewFrame).CornerRadius = UDim.new(0, 12)
local previewStroke = Instance.new("UIStroke", previewFrame)
previewStroke.Color = Color3.fromRGB(255, 180, 0)
previewStroke.Thickness = 2

local previewAvatar = Instance.new("ImageLabel", previewFrame)
previewAvatar.Size = UDim2.new(0, 80, 0, 80)
previewAvatar.Position = UDim2.new(0.5, -40, 0, 12)
previewAvatar.BackgroundColor3 = Color3.fromRGB(30, 20, 10)
previewAvatar.BorderSizePixel = 0
previewAvatar.ZIndex = 602
Instance.new("UICorner", previewAvatar).CornerRadius = UDim.new(1, 0)

local previewName = Instance.new("TextLabel", previewFrame)
previewName.Size = UDim2.new(1, -20, 0, 20)
previewName.Position = UDim2.new(0, 10, 0, 100)
previewName.BackgroundTransparency = 1
previewName.Font = Enum.Font.GothamBold
previewName.Text = "Username"
previewName.TextColor3 = Color3.fromRGB(255, 230, 150)
previewName.TextSize = 13
previewName.TextXAlignment = Enum.TextXAlignment.Center
previewName.ZIndex = 602

local previewInfo = Instance.new("TextLabel", previewFrame)
previewInfo.Size = UDim2.new(1, -20, 1, -170)
previewInfo.Position = UDim2.new(0, 10, 0, 124)
previewInfo.BackgroundTransparency = 1
previewInfo.Font = Enum.Font.Gotham
previewInfo.Text = ""
previewInfo.TextColor3 = Color3.fromRGB(220, 200, 180)
previewInfo.TextSize = 10
previewInfo.TextXAlignment = Enum.TextXAlignment.Left
previewInfo.TextYAlignment = Enum.TextYAlignment.Top
previewInfo.TextWrapped = true
previewInfo.ZIndex = 602

local previewClose = Instance.new("TextButton", previewFrame)
previewClose.Size = UDim2.new(1, -20, 0, 28)
previewClose.Position = UDim2.new(0, 10, 1, -38)
previewClose.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
previewClose.Text = "✕ TUTUP"
previewClose.TextColor3 = Color3.fromRGB(255, 220, 220)
previewClose.Font = Enum.Font.GothamBold
previewClose.TextSize = 10
previewClose.BorderSizePixel = 0
previewClose.ZIndex = 602
Instance.new("UICorner", previewClose).CornerRadius = UDim.new(0, 5)

local isHidden = false
local isMinimized = false

local hideIcon = Instance.new("TextButton")
hideIcon.Parent = screenGui
hideIcon.BackgroundColor3 = Color3.fromRGB(20, 8, 8)
hideIcon.BorderSizePixel = 0
hideIcon.Position = UDim2.new(0, 15, 0.5, -22)
hideIcon.Size = UDim2.new(0, 46, 0, 46)
hideIcon.Font = Enum.Font.GothamBold
hideIcon.Text = "⚡"
hideIcon.TextColor3 = Color3.fromRGB(255, 215, 0)
hideIcon.TextSize = 22
hideIcon.Visible = false
hideIcon.ZIndex = 200
Instance.new("UICorner", hideIcon).CornerRadius = UDim.new(1, 0)
local hideIconStroke = Instance.new("UIStroke", hideIcon)
hideIconStroke.Color = Color3.fromRGB(255, 215, 0)
hideIconStroke.Thickness = 2.5

local selectedUsers = {}
local currentSearchFilter = ""
local currentRoleFilter = "all"
local currentBanDuration = "permanent"

local roleBadgeGrad = nil

local function SetRoleVisual(role)
    if roleBadgeGrad then
        roleBadgeGrad:Destroy()
        roleBadgeGrad = nil
    end

    if role == "owner" then
        roleBadge.Text = "👑 OWNER"
        roleBadge.BackgroundColor3 = Color3.fromRGB(120, 80, 0)
        roleBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
        ownerPanelBtn.Visible = true
        roleBadgeGrad = Instance.new("UIGradient")
        roleBadgeGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.4, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0, 100, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 255)),
        })
        roleBadgeGrad.Parent = roleBadge
    elseif role == "admin" then
    roleBadge.Text = "🛡️ ADMIN"
    roleBadge.BackgroundColor3 = Color3.fromRGB(60, 30, 100)
    roleBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
    ownerPanelBtn.Visible = true
        roleBadgeGrad = Instance.new("UIGradient")
        roleBadgeGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 100, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 20, 30)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 50, 50)),
        })
        roleBadgeGrad.Parent = roleBadge
    elseif role == "vip" then
        roleBadge.Text = "🏆 VIP"
        roleBadge.BackgroundColor3 = Color3.fromRGB(120, 20, 150)
        roleBadge.TextColor3 = Color3.fromRGB(255, 200, 255)
        ownerPanelBtn.Visible = false
    elseif role == "user" then
        roleBadge.Text = "✅ USER"
        roleBadge.BackgroundColor3 = Color3.fromRGB(20, 80, 40)
        roleBadge.TextColor3 = Color3.fromRGB(150, 255, 180)
        ownerPanelBtn.Visible = false
    elseif role == "pending" then
        roleBadge.Text = "🟡 PENDING"
        roleBadge.BackgroundColor3 = Color3.fromRGB(120, 100, 0)
        roleBadge.TextColor3 = Color3.fromRGB(255, 230, 100)
        ownerPanelBtn.Visible = false
    elseif role == "expired" then
        roleBadge.Text = "⏰ EXPIRED"
        roleBadge.BackgroundColor3 = Color3.fromRGB(100, 40, 20)
        roleBadge.TextColor3 = Color3.fromRGB(255, 150, 100)
        ownerPanelBtn.Visible = false
    elseif role == "banned" then
        roleBadge.Text = "🚫 BANNED"
        roleBadge.BackgroundColor3 = Color3.fromRGB(150, 10, 10)
        roleBadge.TextColor3 = Color3.fromRGB(255, 100, 100)
        ownerPanelBtn.Visible = false
    else
        roleBadge.Text = "❌ DENIED"
        roleBadge.BackgroundColor3 = Color3.fromRGB(80, 10, 10)
        roleBadge.TextColor3 = Color3.fromRGB(255, 120, 120)
        ownerPanelBtn.Visible = false
    end

    if currentExpiry then expiryLbl.Text = "📅 " .. tostring(currentExpiry)
    else expiryLbl.Text = "" end

    local canLoad = (role == "owner" or role == "admin" or role == "vip" or role == "user")
    loadFarmBtn.Active = canLoad
    loadShopBtn.Active = canLoad
    loadFarmBtn.AutoButtonColor = canLoad
    loadShopBtn.AutoButtonColor = canLoad

    if canLoad then
        loadFarmBtn.BackgroundColor3 = Color3.fromRGB(70, 25, 25)
        loadShopBtn.BackgroundColor3 = Color3.fromRGB(70, 25, 25)
        loadFarmBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
        loadShopBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
    else
        loadFarmBtn.BackgroundColor3 = Color3.fromRGB(25, 15, 15)
        loadShopBtn.BackgroundColor3 = Color3.fromRGB(25, 15, 15)
        loadFarmBtn.TextColor3 = Color3.fromRGB(100, 80, 80)
        loadShopBtn.TextColor3 = Color3.fromRGB(100, 80, 80)
    end

    reqBtn.Visible = (role == "denied" or role == "expired")
end

local function DoCheckAccount()
    statusInfo.Text = "🔄 Cek akun..."
    statusInfo.TextColor3 = Color3.fromRGB(200, 200, 100)
    task.wait(0.3)
    local role = CheckUserRole()
    SetRoleVisual(role)
    if role == "owner" then
        statusInfo.Text = "👑 Selamat datang, OWNER!"
        statusInfo.TextColor3 = Color3.fromRGB(255, 215, 0)
    elseif role == "vip" then
        statusInfo.Text = "🏆 Selamat datang, VIP!"
        statusInfo.TextColor3 = Color3.fromRGB(255, 200, 255)
    elseif role == "admin" then
    statusInfo.Text = "🛡️ Admin aktif."
    statusInfo.TextColor3 = Color3.fromRGB(200, 180, 255)
    elseif role == "user" then
        statusInfo.Text = "✅ Whitelist aktif."
        statusInfo.TextColor3 = Color3.fromRGB(150, 255, 180)
    elseif role == "pending" then
        statusInfo.Text = "🟡 Request sedang ditinjau..."
        statusInfo.TextColor3 = Color3.fromRGB(255, 230, 100)
    elseif role == "expired" then
        statusInfo.Text = "⏰ Expired!"
        statusInfo.TextColor3 = Color3.fromRGB(255, 150, 100)
    elseif role == "banned" then
    statusInfo.Text = "🚫 " .. (currentReason or "Banned")
    statusInfo.TextColor3 = Color3.fromRGB(255, 100, 100)
    task.wait(0.5)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "🚫 ANDA DI-BAN",
            Text = "Hubungi owner: suyadi_irengbadeg",
            Duration = 3
        })
    end)
    task.wait(1.5)
    LocalPlayer:Kick("🚫 ANDA TELAH DI-BAN DARI DV EXPLOITS HUB\n\n📝 Alasan: " .. tostring(currentReason or "Tidak disebutkan") .. "\n\n📞 Hubungi owner: 😈👿\n\n⚡ DV EXPLOITS HUB ⚡")
    return
    else
        statusInfo.Text = "❌ Belum terdaftar."
        statusInfo.TextColor3 = Color3.fromRGB(255, 120, 120)
    end
end

checkBtn.MouseButton1Click:Connect(function() DoCheckAccount() end)

reqBtn.MouseButton1Click:Connect(function()
    local userId = tostring(LocalPlayer.UserId)
    local banCheck = FirebaseGet("/Banned/" .. userId)
    if banCheck then
        statusInfo.Text = "🚫 u ar ban idiots."
        statusInfo.TextColor3 = Color3.fromRGB(255, 100, 100)
        task.wait(1)
        LocalPlayer:Kick("🚫 ANDA DI-BAN DARI DV EXPLOITS HUB\n\n📞 Hubungi owner: 👿😈")
        return
    end
    local userName = LocalPlayer.Name
    local existing = FirebaseGet("/Requests/" .. userId)
    if existing and type(existing) == "table" and tostring(existing.Status or ""):lower() == "pending" then
        statusInfo.Text = "⚠️ Request lo udah ada!"
        statusInfo.TextColor3 = Color3.fromRGB(255, 230, 100)
        return
    end
    statusInfo.Text = "⏳ Mengirim request..."
    local success = FirebasePut("/Requests/" .. userId, {
        Username = userName, DisplayName = LocalPlayer.DisplayName, UserId = LocalPlayer.UserId,
        Reason = "Minta whitelist via Roblox", Status = "pending",
        Timestamp = os.time(), DateRequest = os.date("%d/%m/%y %H:%M")
    })
    if success then
        statusInfo.Text = "✅ Request terkirim!"
        statusInfo.TextColor3 = Color3.fromRGB(150, 255, 180)
        SetRoleVisual("pending")
    else
        statusInfo.Text = "❌ Gagal kirim."
        statusInfo.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end)

loadFarmBtn.MouseButton1Click:Connect(function()
    if not loadFarmBtn.Active then return end
    loadFarmBtn.Text = "⏳ Loading..."
    local ok = pcall(function() loadstring(game:HttpGet(URL_AUTOFARM))() end)
    loadFarmBtn.Text = ok and "✅ Loaded!" or "❌ Gagal"
    loadFarmBtn.BackgroundColor3 = ok and Color3.fromRGB(30, 120, 50) or Color3.fromRGB(120, 30, 30)
    task.wait(1.5)
    loadFarmBtn.Text = "🚀 LOAD AUTO FARM IGR"
end)

loadShopBtn.MouseButton1Click:Connect(function()
    if not loadShopBtn.Active then return end
    if PlayerGui:FindFirstChild("DVExploitsShopPro") then
        loadShopBtn.Text = "⚠️ Udah Active!"
        task.wait(1.5); loadShopBtn.Text = "🛒 LOAD SHOP SYSTEM IGR"; return
    end
    loadShopBtn.Text = "⏳ Loading..."
    local ok = pcall(function() loadstring(game:HttpGet(URL_SHOP))() end)
    loadShopBtn.Text = ok and "✅ Loaded!" or "❌ Gagal"
    loadShopBtn.BackgroundColor3 = ok and Color3.fromRGB(30, 120, 50) or Color3.fromRGB(120, 30, 30)
    task.wait(1.5)
    loadShopBtn.Text = "🛒 LOAD SHOP SYSTEM IGR"
end)

local function ClearScroll(scroll)
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") or c:IsA("TextButton") then c:Destroy() end
    end
end

local function IsOwnerKey(key, info)
    if not info then
        info = FirebaseGet("/Whitelist/" .. tostring(key))
    end
    if info and type(info) == "table" then
        return tostring(info.Role or ""):lower() == "owner"
    end
    return false
end

local function GetKeyDisplay(key, info)
    if type(info) == "table" and info.Username then
        return tostring(info.Username) .. " (" .. tostring(info.UserId or key) .. ")"
    end
    return tostring(key)
end

local function GetRoleFromInfo(info)
    if type(info) ~= "table" then return "user" end
    return tostring(info.Role or "user"):lower()
end

local function MatchesSearch(key, info, query)
    if query == "" then return true end
    local q = query:lower()
    if tostring(key):lower():find(q, 1, true) then return true end
    if type(info) == "table" then
        if info.Username and tostring(info.Username):lower():find(q, 1, true) then return true end
        if info.UserId and tostring(info.UserId):lower():find(q, 1, true) then return true end
    end
    return false
end

local function MatchesRole(info, roleFilter)
    if roleFilter == "all" then return true end
    return GetRoleFromInfo(info) == roleFilter
end

local RenderWL

local function CloseDropdown()
    dropdownOverlay.Visible = false
    for _, c in ipairs(dropdownList:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("TextLabel") or c:IsA("Frame") then
            c:Destroy()
        end
    end
end

local function OpenDropdown(userKey, userInfo, mode)
    CloseDropdown()
    dropdownOverlay.Visible = true

    if mode == "role" then
    dropdownTitle.Text = "⚙️ PILIH ROLE"
    dropdownUserName.Text = "👤 " .. GetKeyDisplay(userKey, userInfo)
    local roles = { "user", "admin", "vip" }
    local cur = GetRoleFromInfo(userInfo)
    for _, role in ipairs(roles) do
        local btn = Instance.new("TextButton", dropdownList)
        btn.Size = UDim2.new(1, 0, 0, 28)
        btn.BackgroundColor3 = (role == cur) and Color3.fromRGB(80, 60, 10) or Color3.fromRGB(40, 25, 10)
        btn.Text = (role == cur and "● " or "○ ") .. (ROLE_LABEL[role] or role)
        btn.TextColor3 = Color3.fromRGB(255, 230, 150)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.BorderSizePixel = 0
        btn.ZIndex = 503
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
        btn.MouseButton1Click:Connect(function()
    if role == cur then
        opStatus.Text = "⚠️ Udah role " .. role
        CloseDropdown()
        return
    end
    
    if currentRole == "admin" and (role == "owner" or role == "vip") then
        opStatus.Text = "❌ Admin nggak bisa ubah ke " .. role
        CloseDropdown()
        return
    end
    
    CloseDropdown()
    
    local confirm = Instance.new("Frame", screenGui) 
            confirm.Size = UDim2.new(0, 300, 0, 150)
            confirm.Position = UDim2.new(0.5, -150, 0.5, -75)
            confirm.BackgroundColor3 = Color3.fromRGB(30, 20, 10)
            confirm.BorderSizePixel = 0
            confirm.ZIndex = 700
            Instance.new("UICorner", confirm).CornerRadius = UDim.new(0, 10)
            
            local confirmStroke = Instance.new("UIStroke", confirm)
            confirmStroke.Color = Color3.fromRGB(255, 180, 0)
            confirmStroke.Thickness = 2
            
            local title = Instance.new("TextLabel", confirm)
            title.Size = UDim2.new(1, -20, 0, 30)
            title.Position = UDim2.new(0, 10, 0, 10)
            title.BackgroundTransparency = 1
            title.Text = "⚙️ Change Role?"
            title.TextColor3 = Color3.fromRGB(255, 215, 0)
            title.Font = Enum.Font.GothamBold
            title.TextSize = 14
            title.ZIndex = 701
            
            local msg = Instance.new("TextLabel", confirm)
            msg.Size = UDim2.new(1, -20, 0, 60)
            msg.Position = UDim2.new(0, 10, 0, 40)
            msg.BackgroundTransparency = 1
            msg.Text = "Yakin ubah role:\n" .. GetKeyDisplay(userKey, userInfo) .. "\n" .. cur:upper() .. " → " .. role:upper() .. "?"
            msg.TextColor3 = Color3.fromRGB(255, 220, 220)
            msg.Font = Enum.Font.Gotham
            msg.TextSize = 10
            msg.TextWrapped = true
            msg.ZIndex = 701
            
            local okBtn = Instance.new("TextButton", confirm)
            okBtn.Size = UDim2.new(0.45, -15, 0, 30)
            okBtn.Position = UDim2.new(0, 10, 1, -40)
            okBtn.BackgroundColor3 = Color3.fromRGB(20, 100, 40)
            okBtn.Text = "✅ OK"
            okBtn.TextColor3 = Color3.fromRGB(200, 255, 200)
            okBtn.Font = Enum.Font.GothamBold
            okBtn.TextSize = 11
            okBtn.BorderSizePixel = 0
            okBtn.ZIndex = 701
            Instance.new("UICorner", okBtn).CornerRadius = UDim.new(0, 5)
            
            local cancelBtn = Instance.new("TextButton", confirm)
            cancelBtn.Size = UDim2.new(0.45, -15, 0, 30)
            cancelBtn.Position = UDim2.new(0.5, 5, 1, -40)
            cancelBtn.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
            cancelBtn.Text = "❌ BATAL"
            cancelBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
            cancelBtn.Font = Enum.Font.GothamBold
            cancelBtn.TextSize = 11
            cancelBtn.BorderSizePixel = 0
            cancelBtn.ZIndex = 701
            Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 5)
            
            okBtn.MouseButton1Click:Connect(function()
                FirebasePut("/Whitelist/" .. userKey .. "/Role", role)
                FirebasePut("/Whitelist/" .. userKey .. "/Source", "manual-owner")
                LogAction("ROLE_CHANGE", GetKeyDisplay(userKey, userInfo), cur .. " → " .. role)
                opStatus.Text = "✅ " .. cur .. " → " .. role
                
                pcall(function()
                    StarterGui:SetCore("SendNotification", {
                        Title = "✅ Role Changed",
                        Text = GetKeyDisplay(userKey, userInfo) .. ": " .. cur .. " → " .. role,
                        Duration = 3
                    })
                end)
                
                confirm:Destroy()
                task.wait(0.2)
                RenderWL()
            end)
            
            cancelBtn.MouseButton1Click:Connect(function()
                opStatus.Text = "❌ Dibatalkan"
                confirm:Destroy()
            end)
        end)
    end
    elseif mode == "expiry" then
        dropdownTitle.Text = "📅 SET EXPIRY"
        dropdownUserName.Text = "👤 " .. GetKeyDisplay(userKey, userInfo)
        local opts = {
            { label = "♾️ Lifetime", val = "lifetime" },
            { label = "📅 +7 hari", val = "7d" },
            { label = "📅 +30 hari", val = "30d" },
            { label = "📅 +1 tahun", val = "1y" }
        }
        for _, opt in ipairs(opts) do
            local btn = Instance.new("TextButton", dropdownList)
            btn.Size = UDim2.new(1, 0, 0, 28)
            btn.BackgroundColor3 = Color3.fromRGB(50, 35, 15)
            btn.Text = opt.label
            btn.TextColor3 = Color3.fromRGB(255, 220, 150)
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 10
            btn.BorderSizePixel = 0
            btn.ZIndex = 503
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
            btn.MouseButton1Click:Connect(function()
    local newExp = nil
    if opt.val == "7d" then newExp = FormatDate(os.time() + 7 * 86400)
    elseif opt.val == "30d" then newExp = FormatDate(os.time() + 30 * 86400)
    elseif opt.val == "1y" then newExp = FormatDate(os.time() + 365 * 86400) end
    FirebasePut("/Whitelist/" .. userKey .. "/Expired", newExp)
    LogAction("EXPIRY_CHANGE", GetKeyDisplay(userKey, userInfo), tostring(newExp or "Lifetime"))
    opStatus.Text = "📅 Expiry: " .. tostring(newExp or "Lifetime")
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "📅 Expiry Set",
            Text = GetKeyDisplay(userKey, userInfo) .. ": " .. tostring(newExp or "Lifetime"),
            Duration = 3
        })
    end)
    CloseDropdown(); task.wait(0.2); RenderWL()
end)
        end
    elseif mode == "filter" then
        dropdownTitle.Text = "🎯 FILTER ROLE"
        dropdownUserName.Text = "Pilih role untuk difilter"
        local filters = { "all", "user", "admin", "vip", "owner" }
        for _, f in ipairs(filters) do
            local btn = Instance.new("TextButton", dropdownList)
            btn.Size = UDim2.new(1, 0, 0, 28)
            btn.BackgroundColor3 = (f == currentRoleFilter) and Color3.fromRGB(80, 60, 10) or Color3.fromRGB(40, 25, 10)
            btn.Text = (f == currentRoleFilter and "● " or "○ ") .. f:upper()
            btn.TextColor3 = Color3.fromRGB(255, 230, 150)
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 10
            btn.BorderSizePixel = 0
            btn.ZIndex = 503
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
            btn.MouseButton1Click:Connect(function()
    currentRoleFilter = f
    opRoleFilterBtn.Text = "FILTER: " .. f:upper()
    CloseDropdown()
task.defer(RenderWL)
end)
        end
    elseif mode == "banduration" then
        dropdownTitle.Text = "⏱️ DURASI BAN"
        dropdownUserName.Text = "Pilih durasi ban"
        local durs = {
            { label = "♾️ Permanent", val = "permanent" },
            { label = "⏱️ 1 Jam", val = "1h" },
            { label = "⏱️ 24 Jam", val = "24h" },
            { label = "📅 7 Hari", val = "7d" },
            { label = "📅 30 Hari", val = "30d" }
        }
        for _, d in ipairs(durs) do
            local btn = Instance.new("TextButton", dropdownList)
            btn.Size = UDim2.new(1, 0, 0, 28)
            btn.BackgroundColor3 = (d.val == currentBanDuration) and Color3.fromRGB(80, 60, 10) or Color3.fromRGB(40, 25, 10)
            btn.Text = (d.val == currentBanDuration and "● " or "○ ") .. d.label
            btn.TextColor3 = Color3.fromRGB(255, 230, 150)
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 10
            btn.BorderSizePixel = 0
            btn.ZIndex = 503
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
            btn.MouseButton1Click:Connect(function()
                currentBanDuration = d.val
                opBanDurationBtn.Text = d.label:gsub("♾️ ", ""):gsub("⏱️ ", ""):gsub("📅 ", "")
                CloseDropdown()
            end)
        end
    end

    task.wait()
dropdownList.Size = UDim2.new(1, -20, 0, 0)
dropdownList.AutomaticSize = Enum.AutomaticSize.Y
end

dropdownCancel.MouseButton1Click:Connect(CloseDropdown)
dropdownOverlay.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        task.defer(function()
            if dropdownOverlay.Visible then
                CloseDropdown()
            end
        end)
    end
end)

local function ShowPreview(key, info)
    previewOverlay.Visible = true
    local userId = tonumber(info.UserId or key) or 0
    previewName.Text = tostring(info.Username or key)
    previewAvatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=150&h=150"
    local lines = {}
    table.insert(lines, "🆔 ID: " .. tostring(userId))
    table.insert(lines, "👑 Role: " .. tostring(info.Role or "user"))
    table.insert(lines, "📌 Status: " .. tostring(info.Status or "ACTIVE"))
    table.insert(lines, "📅 Expired: " .. tostring(info.Expired or "Lifetime"))
    table.insert(lines, "📦 Source: " .. tostring(info.Source or "?"))
    if info.RegisteredAt then
        table.insert(lines, "⏰ Registered: " .. os.date("%d/%m/%y %H:%M", tonumber(info.RegisteredAt) or 0))
    end
    if info.ApprovedBy then table.insert(lines, "✅ By: " .. tostring(info.ApprovedBy)) end
    previewInfo.Text = table.concat(lines, "\n")
end

previewClose.MouseButton1Click:Connect(function() previewOverlay.Visible = false end)
previewOverlay.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        previewOverlay.Visible = false
    end
end)

local function renderChatMessages()
    if not chatScrollRef then return end
    local now = os.time()
    local data = FirebaseGet("/Chat") or {}
    local entries = {}
    for k, v in pairs(data) do
        if type(v) == "table" and v.Text then
            if CHAT_STATE.autoClear then
                local age = now - tonumber(v.Timestamp or now)
                if age > CHAT_STATE.clearInterval then
                    FirebasePut("/Chat/" .. k, nil)
                else
                    table.insert(entries, { id = k, info = v })
                end
            else
                table.insert(entries, { id = k, info = v })
            end
        end
    end
    table.sort(entries, function(a, b) return tonumber(a.info.Timestamp or 0) < tonumber(b.info.Timestamp or 0) end)
    while #entries > 100 do table.remove(entries, 1) end
    for _, c in ipairs(chatScrollRef:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") or c:IsA("TextButton") then c:Destroy() end
    end
    local lastY = 0
    for _, e in ipairs(entries) do
        local msg = e.info
        local role = tostring(msg.Role or "guest"):lower()
        local msgText = tostring(msg.Text or "")
        local usn = tostring(msg.Username or "unknown")
        local timeStr = tostring(msg.Date or os.date("%H:%M", tonumber(msg.Timestamp) or now))
        local userId = tostring(msg.UserId or "0")
        local card = Instance.new("Frame", chatScrollRef)
        card.Size = UDim2.new(1, -8, 0, 56)
        card.Position = UDim2.new(0, 4, 0, lastY)
        card.BackgroundColor3 = (role == "owner") and Color3.fromRGB(20, 30, 20) or (role == "admin") and Color3.fromRGB(20, 25, 35) or Color3.fromRGB(20, 25, 20)
        card.BorderSizePixel = 0
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 5)
        if role == "owner" or role == "admin" then
            local s = Instance.new("UIStroke", card)
            s.Color = (role == "owner") and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(100, 180, 255)
            s.Thickness = 1
        end
        local av = Instance.new("ImageLabel", card)
        av.Size = UDim2.new(0, 40, 0, 40)
        av.Position = UDim2.new(0, 6, 0, 8)
        av.BackgroundColor3 = Color3.fromRGB(15, 20, 15)
        av.BorderSizePixel = 0
        av.Image = "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150"
        Instance.new("UICorner", av).CornerRadius = UDim.new(1, 0)
        local avS = Instance.new("UIStroke", av)
        avS.Color = getRoleColor(role)
        avS.Thickness = 1.5
        local nameBtn = Instance.new("TextButton", card)
        nameBtn.Size = UDim2.new(1, -100, 0, 14)
        nameBtn.Position = UDim2.new(0, 52, 0, 4)
        nameBtn.BackgroundTransparency = 1
        nameBtn.Font = Enum.Font.GothamBold
        nameBtn.Text = usn
        if role == "owner" or role == "admin" then
    nameBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    task.spawn(function()
        while nameBtn and nameBtn.Parent do
            local hue = (tick() * 0.3) % 1
            if role == "owner" then
                nameBtn.TextColor3 = Color3.fromHSV(hue, 1, 1)
            else
                local palette = {
                    Color3.fromRGB(50, 100, 255),
                    Color3.fromRGB(20, 20, 30),
                    Color3.fromRGB(220, 50, 50),
                }
                local idx = math.floor((tick() * 3) % 3) + 1
                nameBtn.TextColor3 = palette[idx]
            end
            task.wait(0.1)
        end
    end)
else
    nameBtn.TextColor3 = getRoleColor(role)
end
nameBtn.TextSize = 11
nameBtn.TextXAlignment = Enum.TextXAlignment.Left
nameBtn.AutoButtonColor = false
        local badge = Instance.new("TextLabel", card)
        badge.Size = UDim2.new(0, 70, 0, 12)
        badge.Position = UDim2.new(1, -78, 0, 4)
        badge.BackgroundTransparency = 1
        badge.Font = Enum.Font.GothamBold
        badge.Text = getRoleBadge(role)
        badge.TextColor3 = getRoleColor(role)
        badge.TextSize = 9
        badge.TextXAlignment = Enum.TextXAlignment.Right
        local timeLbl = Instance.new("TextLabel", card)
        timeLbl.Size = UDim2.new(0, 50, 0, 10)
        timeLbl.Position = UDim2.new(0, 52, 0, 18)
        timeLbl.BackgroundTransparency = 1
        timeLbl.Font = Enum.Font.Code
        timeLbl.Text = timeStr
        timeLbl.TextColor3 = Color3.fromRGB(140, 160, 140)
        timeLbl.TextSize = 8
        timeLbl.TextXAlignment = Enum.TextXAlignment.Left
        local msgLbl = Instance.new("TextLabel", card)
        msgLbl.Size = UDim2.new(1, -60, 0, 22)
        msgLbl.Position = UDim2.new(0, 52, 0, 30)
        msgLbl.BackgroundTransparency = 1
        msgLbl.Font = Enum.Font.Gotham
        msgLbl.Text = msgText
        msgLbl.TextColor3 = Color3.fromRGB(220, 240, 220)
        msgLbl.TextSize = 10
        msgLbl.TextXAlignment = Enum.TextXAlignment.Left
        msgLbl.TextWrapped = true
        msgLbl.TextYAlignment = Enum.TextYAlignment.Top
        if currentRole == "owner" or currentRole == "admin" then
            local delBtn = Instance.new("TextButton", card)
            delBtn.Size = UDim2.new(0, 18, 0, 18)
            delBtn.Position = UDim2.new(1, -22, 0, 36)
            delBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
            delBtn.Text = "✕"
            delBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
            delBtn.Font = Enum.Font.GothamBold
            delBtn.TextSize = 10
            delBtn.BorderSizePixel = 0
            Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 3)
            delBtn.MouseButton1Click:Connect(function() deleteChatMessage(e.id) end)
        end
        lastY = lastY + 60
    end
    chatScrollRef.CanvasSize = UDim2.new(0, 0, 0, lastY + 8)
    task.wait()
    pcall(function() chatScrollRef.CanvasPosition = Vector2.new(0, chatScrollRef.AbsoluteCanvasSize.Y) end)
end

chatRefreshConn = renderChatMessages

local function createChatUI()
    if ChatGui then ChatGui:Destroy() ChatGui = nil end
    ChatGui = Instance.new("ScreenGui")
    ChatGui.Name = "DVExploitsChat"
    ChatGui.ResetOnSpawn = false
    ChatGui.DisplayOrder = 998
    ChatGui.Parent = PlayerGui
    local chatIcon = Instance.new("TextButton", ChatGui)
    chatIcon.Size = UDim2.new(0, 46, 0, 46)
    chatIcon.Position = UDim2.new(1, -60, 0, 15)
    chatIcon.BackgroundColor3 = Color3.fromRGB(20, 60, 30)
    chatIcon.Text = "💬"
    chatIcon.TextColor3 = Color3.fromRGB(150, 255, 180)
    chatIcon.Font = Enum.Font.GothamBold
    chatIcon.TextSize = 22
    chatIcon.BorderSizePixel = 0
    chatIcon.Active = true
    chatIcon.Draggable = true
    Instance.new("UICorner", chatIcon).CornerRadius = UDim.new(1, 0)
    local iconStroke = Instance.new("UIStroke", chatIcon)
    iconStroke.Color = Color3.fromRGB(50, 200, 100)
    iconStroke.Thickness = 2
    local panel = Instance.new("Frame", ChatGui)
    panel.Size = UDim2.new(0, 340, 0, 420)
    panel.Position = UDim2.new(1, -360, 0, 70)
    panel.BackgroundColor3 = Color3.fromRGB(10, 20, 12)
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Active = true
    panel.Draggable = true
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
    local panelStroke = Instance.new("UIStroke", panel)
    panelStroke.Color = Color3.fromRGB(50, 200, 100)
    panelStroke.Thickness = 2
    local header = Instance.new("Frame", panel)
    header.Size = UDim2.new(1, 0, 0, 36)
    header.BackgroundColor3 = Color3.fromRGB(15, 40, 20)
    header.BorderSizePixel = 0
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)
    local title = Instance.new("TextLabel", header)
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "💬 LIVE CHAT"
    title.TextColor3 = Color3.fromRGB(150, 255, 180)
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    local closeBtn = Instance.new("TextButton", header)
    closeBtn.Size = UDim2.new(0, 24, 0, 24)
    closeBtn.Position = UDim2.new(1, -30, 0, 6)
    closeBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.BorderSizePixel = 0
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)
    closeBtn.MouseButton1Click:Connect(function()
        panel.Visible = false
        CHAT_STATE.isOpen = false
    end)
    local clearAllBtn = Instance.new("TextButton", header)
    clearAllBtn.Size = UDim2.new(0, 24, 0, 24)
    clearAllBtn.Position = UDim2.new(1, -60, 0, 6)
    clearAllBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 30)
    clearAllBtn.Text = "🗑️"
    clearAllBtn.TextColor3 = Color3.fromRGB(255, 200, 150)
    clearAllBtn.Font = Enum.Font.GothamBold
    clearAllBtn.TextSize = 11
    clearAllBtn.BorderSizePixel = 0
    clearAllBtn.Visible = (currentRole == "owner")
    Instance.new("UICorner", clearAllBtn).CornerRadius = UDim.new(0, 5)
    clearAllBtn.MouseButton1Click:Connect(function() clearAllChat() end)
    local scroll = Instance.new("ScrollingFrame", panel)
    scroll.Size = UDim2.new(1, -8, 1, -100)
    scroll.Position = UDim2.new(0, 4, 0, 40)
    scroll.BackgroundColor3 = Color3.fromRGB(8, 15, 10)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(50, 200, 100)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 6)
    local inputBg = Instance.new("Frame", panel)
    inputBg.Size = UDim2.new(1, -8, 0, 50)
    inputBg.Position = UDim2.new(0, 4, 1, -54)
    inputBg.BackgroundColor3 = Color3.fromRGB(15, 30, 18)
    inputBg.BorderSizePixel = 0
    Instance.new("UICorner", inputBg).CornerRadius = UDim.new(0, 6)
    local input = Instance.new("TextBox", inputBg)
    input.Size = UDim2.new(1, -60, 0, 34)
    input.Position = UDim2.new(0, 6, 0, 8)
    input.BackgroundColor3 = Color3.fromRGB(8, 20, 12)
    input.BorderSizePixel = 0
    input.PlaceholderText = "Ketik pesan..."
    input.PlaceholderColor3 = Color3.fromRGB(100, 150, 120)
    input.Text = ""
    input.TextColor3 = Color3.fromRGB(200, 255, 200)
    input.Font = Enum.Font.Gotham
    input.TextSize = 11
    input.ClearTextOnFocus = false
    input.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", input).CornerRadius = UDim.new(0, 4)
    local sendBtn = Instance.new("TextButton", inputBg)
    sendBtn.Size = UDim2.new(0, 46, 0, 34)
    sendBtn.Position = UDim2.new(1, -52, 0, 8)
    sendBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 60)
    sendBtn.Text = "➤"
    sendBtn.TextColor3 = Color3.fromRGB(220, 255, 220)
    sendBtn.Font = Enum.Font.GothamBold
    sendBtn.TextSize = 18
    sendBtn.BorderSizePixel = 0
    Instance.new("UICorner", sendBtn).CornerRadius = UDim.new(0, 4)
    local function doSend()
        local txt = input.Text
        if txt and #txt > 0 then
            sendChatMessage(txt)
            input.Text = ""
        end
    end
    sendBtn.MouseButton1Click:Connect(doSend)
    input.FocusLost:Connect(function(enter) if enter then doSend() end end)
    chatIcon.MouseButton1Click:Connect(function()
        panel.Visible = not panel.Visible
        CHAT_STATE.isOpen = panel.Visible
        if panel.Visible then renderChatMessages() end
    end)
    chatScrollRef = scroll
end

function RenderWL()
    ClearScroll(opWLScroll)
    opStatus.Text = "⏳ Loading WL..."
    local data = FirebaseGet("/Whitelist")
    if type(data) ~= "table" or next(data) == nil then
        local lbl = Instance.new("TextLabel", opWLScroll)
        lbl.Size = UDim2.new(1, -8, 0, 26)
        lbl.BackgroundTransparency = 1
        lbl.Text = "Kosong"
        lbl.TextColor3 = Color3.fromRGB(180, 160, 100)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 10
        opStatus.Text = "📋 WL: 0"
        return
    end
    local entries = {}
    for k, v in pairs(data) do
        if MatchesSearch(k, v, currentSearchFilter) and MatchesRole(v, currentRoleFilter) then
            table.insert(entries, { key = k, info = v })
        end
    end
    table.sort(entries, function(a, b)
    local aO = (GetRoleFromInfo(a.info) == "owner")
    local bO = (GetRoleFromInfo(b.info) == "owner")
        if aO and not bO then return true end
        if bO and not aO then return false end
        local aR, bR = ROLE_ORDER[GetRoleFromInfo(a.info)] or 0, ROLE_ORDER[GetRoleFromInfo(b.info)] or 0
        if aR ~= bR then return aR > bR end
        return tostring(a.key):lower() < tostring(b.key):lower()
    end)
    for _, entry in ipairs(entries) do
        local key, info = entry.key, entry.info
        local currentRoleUser = GetRoleFromInfo(info)
local isOwner = (currentRoleUser == "owner")
        local source = (type(info) == "table" and info.Source) and tostring(info.Source) or "?"
        local card = Instance.new("Frame", opWLScroll)
        card.Size = UDim2.new(1, -8, 0, isOwner and 60 or 90)
        card.BackgroundColor3 = isOwner and Color3.fromRGB(45, 35, 5) or Color3.fromRGB(30, 22, 10)
        card.BorderSizePixel = 0
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 5)
        if isOwner then
            local s = Instance.new("UIStroke", card)
            s.Color = Color3.fromRGB(255, 215, 0); s.Thickness = 1.5
        elseif source == "auto-vip-prefix" then
            local s = Instance.new("UIStroke", card)
            s.Color = Color3.fromRGB(180, 100, 255); s.Thickness = 1
        end
        local cb = Instance.new("TextButton", card)
cb.Size = UDim2.new(0, 14, 0, 14)
cb.Position = UDim2.new(0, 6, 0, 4)
cb.BackgroundColor3 = selectedUsers[key] and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(40, 25, 10)
cb.Text = selectedUsers[key] and "✓" or ""
cb.TextColor3 = Color3.fromRGB(255, 255, 255)
cb.Font = Enum.Font.GothamBold
cb.TextSize = 10
cb.BorderSizePixel = 0
cb.Visible = not isOwner
cb.ZIndex = 10
cb.Active = true
Instance.new("UICorner", cb).CornerRadius = UDim.new(0, 3)
cb.MouseButton1Click:Connect(function()
    if selectedUsers[key] then
        selectedUsers[key] = nil
        cb.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
        cb.Text = ""
    else
        selectedUsers[key] = true
        cb.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
        cb.Text = "✓"
    end
end)
        local name = Instance.new("TextButton", card)
        name.Size = UDim2.new(1, -22, 0, 16)
        name.Position = UDim2.new(0, 24, 0, 3)
        name.BackgroundTransparency = 1
        local icon = isOwner and "👑 " or (source == "auto-vip-prefix" and "🌟 " or "👤 ")
        name.Text = icon .. GetKeyDisplay(key, info)
        name.TextColor3 = isOwner and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(255, 230, 150)
        name.Font = Enum.Font.GothamBold
        name.TextSize = 10
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.MouseButton1Click:Connect(function() ShowPreview(key, info) end)
        local roleLbl = Instance.new("TextLabel", card)
        roleLbl.Size = UDim2.new(1, -22, 0, 12)
        roleLbl.Position = UDim2.new(0, 24, 0, 20)
        roleLbl.BackgroundTransparency = 1
        local roleText = ROLE_LABEL[currentRoleUser] or currentRoleUser
        local expired = (type(info) == "table" and info.Expired) and tostring(info.Expired) or "Lifetime"
        local src = source == "auto-vip-prefix" and "  • 🌟AUTO" or ""
        roleLbl.Text = roleText .. "  •  " .. expired .. src
        roleLbl.TextColor3 = Color3.fromRGB(200, 180, 120)
        roleLbl.Font = Enum.Font.Gotham
        roleLbl.TextSize = 8
        roleLbl.TextXAlignment = Enum.TextXAlignment.Left
        if isOwner then
            local l = Instance.new("TextLabel", card)
            l.Size = UDim2.new(1, -10, 0, 20)
            l.Position = UDim2.new(0, 6, 0, 35)
            l.BackgroundColor3 = Color3.fromRGB(60, 40, 0)
            l.BorderSizePixel = 0
            l.Text = "🔒 OWNER PROTECTED"
            l.TextColor3 = Color3.fromRGB(255, 215, 0)
            l.Font = Enum.Font.GothamBold
            l.TextSize = 9
            Instance.new("UICorner", l).CornerRadius = UDim.new(0, 4)
        else
            local row = Instance.new("Frame", card)
            row.Size = UDim2.new(1, -10, 0, 26)
            row.Position = UDim2.new(0, 6, 0, 58)
            row.BackgroundTransparency = 1
            local roleBtn = Instance.new("TextButton", row)
            roleBtn.Size = UDim2.new(0.28, -2, 1, 0)
            roleBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 100)
            roleBtn.Text = "⚙️ ROLE"
            roleBtn.TextColor3 = Color3.fromRGB(220, 200, 255)
            roleBtn.Font = Enum.Font.GothamBold
            roleBtn.TextSize = 8
            roleBtn.BorderSizePixel = 0
            Instance.new("UICorner", roleBtn).CornerRadius = UDim.new(0, 4)
            roleBtn.MouseButton1Click:Connect(function() OpenDropdown(key, info, "role") end)
            local expBtn = Instance.new("TextButton", row)
            expBtn.Size = UDim2.new(0.28, -2, 1, 0)
            expBtn.Position = UDim2.new(0.29, 0, 0, 0)
            expBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 20)
            expBtn.Text = "📅 EXPIRE"
            expBtn.TextColor3 = Color3.fromRGB(255, 230, 150)
            expBtn.Font = Enum.Font.GothamBold
            expBtn.TextSize = 8
            expBtn.BorderSizePixel = 0
            Instance.new("UICorner", expBtn).CornerRadius = UDim.new(0, 4)
            expBtn.MouseButton1Click:Connect(function() OpenDropdown(key, info, "expiry") end)
            local banBtn = Instance.new("TextButton", row)
            banBtn.Size = UDim2.new(0.2, -2, 1, 0)
            banBtn.Position = UDim2.new(0.58, 0, 0, 0)
            banBtn.BackgroundColor3 = Color3.fromRGB(140, 20, 20)
            banBtn.Text = "🔨 BAN"
            banBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
            banBtn.Font = Enum.Font.GothamBold
            banBtn.TextSize = 8
            banBtn.BorderSizePixel = 0
            Instance.new("UICorner", banBtn).CornerRadius = UDim.new(0, 4)
            banBtn.MouseButton1Click:Connect(function()
    if currentRole == "admin" then
        local targetRole = GetRoleFromInfo(info)
        if targetRole == "owner" or targetRole == "admin" then
            opStatus.Text = "❌ Admin nggak bisa ban " .. targetRole
            return
        end
    end
    
    local confirm = Instance.new("Frame", screenGui)
    confirm.Size = UDim2.new(0, 300, 0, 150)
    confirm.Position = UDim2.new(0.5, -150, 0.5, -75)
    confirm.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
    confirm.BorderSizePixel = 0
    confirm.ZIndex = 700
    Instance.new("UICorner", confirm).CornerRadius = UDim.new(0, 10)
    
    local title = Instance.new("TextLabel", confirm)
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "🔨 Ban User?"
    title.TextColor3 = Color3.fromRGB(255, 100, 100)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.ZIndex = 701
    
    local msg = Instance.new("TextLabel", confirm)
    msg.Size = UDim2.new(1, -20, 0, 60)
    msg.Position = UDim2.new(0, 10, 0, 40)
    msg.BackgroundTransparency = 1
    msg.Text = "Yakin ban:\n" .. GetKeyDisplay(key, info) .. "?"
    msg.TextColor3 = Color3.fromRGB(255, 220, 220)
    msg.Font = Enum.Font.Gotham
    msg.TextSize = 11
    msg.TextWrapped = true
    msg.ZIndex = 701
    
    local okBtn = Instance.new("TextButton", confirm)
    okBtn.Size = UDim2.new(0.45, -15, 0, 30)
    okBtn.Position = UDim2.new(0, 10, 1, -40)
    okBtn.BackgroundColor3 = Color3.fromRGB(140, 20, 20)
    okBtn.Text = "🔨 BAN"
    okBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
    okBtn.Font = Enum.Font.GothamBold
    okBtn.TextSize = 11
    okBtn.BorderSizePixel = 0
    okBtn.ZIndex = 701
    Instance.new("UICorner", okBtn).CornerRadius = UDim.new(0, 5)
    
    local cancelBtn = Instance.new("TextButton", confirm)
    cancelBtn.Size = UDim2.new(0.45, -15, 0, 30)
    cancelBtn.Position = UDim2.new(0.5, 5, 1, -40)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    cancelBtn.Text = "❌ BATAL"
    cancelBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextSize = 11
    cancelBtn.BorderSizePixel = 0
    cancelBtn.ZIndex = 701
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 5)
    
    okBtn.MouseButton1Click:Connect(function()
        local bk = tostring(info.UserId or key)
        FirebasePut("/Banned/" .. bk, {
    banned = true,
    Reason = "Banned via WL panel",
    Duration = "permanent",
    Timestamp = os.time()
})
        FirebasePut("/Whitelist/" .. key, nil)
        LogAction("BAN", GetKeyDisplay(key, info), "Via WL")
        opStatus.Text = "🔨 Banned: " .. GetKeyDisplay(key, info)
        
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "🔨 User Banned",
                Text = GetKeyDisplay(key, info),
                Duration = 3
            })
        end)
        
        confirm:Destroy()
        task.wait(0.2); RenderWL()
    end)
    
    cancelBtn.MouseButton1Click:Connect(function()
        confirm:Destroy()
    end)
end)
            local delBtn = Instance.new("TextButton", row)
            delBtn.Size = UDim2.new(0.2, -2, 1, 0)
            delBtn.Position = UDim2.new(0.79, 0, 0, 0)
            delBtn.BackgroundColor3 = Color3.fromRGB(100, 20, 20)
            delBtn.Text = "🗑️ DEL"
            delBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
            delBtn.Font = Enum.Font.GothamBold
            delBtn.TextSize = 8
            delBtn.BorderSizePixel = 0
            Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 4)
            delBtn.MouseButton1Click:Connect(function()
    local confirm = Instance.new("Frame", screenGui)
    confirm.Size = UDim2.new(0, 300, 0, 150)
    confirm.Position = UDim2.new(0.5, -150, 0.5, -75)
    confirm.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
    confirm.BorderSizePixel = 0
    confirm.ZIndex = 700
    Instance.new("UICorner", confirm).CornerRadius = UDim.new(0, 10)
    
    local title = Instance.new("TextLabel", confirm)
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "🗑️ Hapus User?"
    title.TextColor3 = Color3.fromRGB(255, 100, 100)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.ZIndex = 701
    
    local msg = Instance.new("TextLabel", confirm)
    msg.Size = UDim2.new(1, -20, 0, 60)
    msg.Position = UDim2.new(0, 10, 0, 40)
    msg.BackgroundTransparency = 1
    msg.Text = "Yakin hapus:\n" .. GetKeyDisplay(key, info) .. "?"
    msg.TextColor3 = Color3.fromRGB(255, 220, 220)
    msg.Font = Enum.Font.Gotham
    msg.TextSize = 11
    msg.TextWrapped = true
    msg.ZIndex = 701
    
    local okBtn = Instance.new("TextButton", confirm)
    okBtn.Size = UDim2.new(0.45, -15, 0, 30)
    okBtn.Position = UDim2.new(0, 10, 1, -40)
    okBtn.BackgroundColor3 = Color3.fromRGB(140, 20, 20)
    okBtn.Text = "🗑️ HAPUS"
    okBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
    okBtn.Font = Enum.Font.GothamBold
    okBtn.TextSize = 11
    okBtn.BorderSizePixel = 0
    okBtn.ZIndex = 701
    Instance.new("UICorner", okBtn).CornerRadius = UDim.new(0, 5)
    
    local cancelBtn = Instance.new("TextButton", confirm)
    cancelBtn.Size = UDim2.new(0.45, -15, 0, 30)
    cancelBtn.Position = UDim2.new(0.5, 5, 1, -40)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    cancelBtn.Text = "❌ BATAL"
    cancelBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextSize = 11
    cancelBtn.BorderSizePixel = 0
    cancelBtn.ZIndex = 701
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 5)
    
    okBtn.MouseButton1Click:Connect(function()
        FirebasePut("/Whitelist/" .. key, nil)
        LogAction("DELETE", GetKeyDisplay(key, info), "Via WL")
        opStatus.Text = "🗑️ Deleted: " .. GetKeyDisplay(key, info)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "🗑️ User Deleted",
                Text = GetKeyDisplay(key, info),
                Duration = 3
            })
        end)
        confirm:Destroy()
        task.wait(0.2); RenderWL()
    end)
    
    cancelBtn.MouseButton1Click:Connect(function()
        confirm:Destroy()
    end)
end)
        end
    end
    task.wait()
    opWLScroll.CanvasSize = UDim2.new(0, 0, 0, opWLLayout.AbsoluteContentSize.Y + 8)
    local total = 0
    for _ in pairs(data) do total = total + 1 end
    opStatus.Text = "📋 WL: " .. total .. " (tampil " .. #entries .. ")"
end

local function RenderReq()
    ClearScroll(opReqScroll)
    local data = FirebaseGet("/Requests")
    if type(data) ~= "table" or next(data) == nil then
        local lbl = Instance.new("TextLabel", opReqScroll)
        lbl.Size = UDim2.new(1, -8, 0, 26)
        lbl.BackgroundTransparency = 1
        lbl.Text = "Belum ada request"
        lbl.TextColor3 = Color3.fromRGB(180, 160, 100)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 10
        opStatus.Text = "📩 REQ: 0"
        return
    end
    local count = 0
    for key, info in pairs(data) do
        if type(info) == "table" and tostring(info.Status or ""):lower() == "pending" then
            count = count + 1
            local card = Instance.new("Frame", opReqScroll)
            card.Size = UDim2.new(1, -8, 0, 74)
            card.BackgroundColor3 = Color3.fromRGB(30, 22, 10)
            card.BorderSizePixel = 0
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 5)
            local name = Instance.new("TextLabel", card)
            name.Size = UDim2.new(1, -12, 0, 16)
            name.Position = UDim2.new(0, 6, 0, 3)
            name.BackgroundTransparency = 1
            name.Text = "👤 " .. tostring(info.Username or key)
            name.TextColor3 = Color3.fromRGB(255, 230, 150)
            name.Font = Enum.Font.GothamBold
            name.TextSize = 9
            name.TextXAlignment = Enum.TextXAlignment.Left
            local idL = Instance.new("TextLabel", card)
            idL.Size = UDim2.new(1, -12, 0, 12)
            idL.Position = UDim2.new(0, 6, 0, 19)
            idL.BackgroundTransparency = 1
            idL.Text = "ID: " .. tostring(info.UserId or key) .. "  •  📅 " .. tostring(info.DateRequest or "?")
            idL.TextColor3 = Color3.fromRGB(180, 160, 120)
            idL.Font = Enum.Font.Gotham
            idL.TextSize = 8
            idL.TextXAlignment = Enum.TextXAlignment.Left
            local row = Instance.new("Frame", card)
            row.Size = UDim2.new(1, -12, 0, 24)
            row.Position = UDim2.new(0, 6, 1, -32)
            row.BackgroundTransparency = 1
            local ab = Instance.new("TextButton", row)
            ab.Size = UDim2.new(0.48, -2, 1, 0)
            ab.BackgroundColor3 = Color3.fromRGB(20, 100, 40)
            ab.Text = "✅ APPROVE"
            ab.TextColor3 = Color3.fromRGB(200, 255, 200)
            ab.Font = Enum.Font.GothamBold
            ab.TextSize = 9
            ab.BorderSizePixel = 0
            Instance.new("UICorner", ab).CornerRadius = UDim.new(0, 4)
                        ab.MouseButton1Click:Connect(function()
    local targetId = tostring(info.UserId or key)
    local banCheck = FirebaseGet("/Banned/" .. targetId)
    if banCheck then
        opStatus.Text = "🚫 User ini di-ban! Gak bisa di-approve."
        return
    end
    FirebasePut("/Whitelist/" .. targetId, {
        Username = tostring(info.Username or key), UserId = tonumber(info.UserId) or info.UserId,
        Role = "user", Status = "ACTIVE", Expired = nil, Locked = false,
        Source = "request-approve", ApprovedBy = LocalPlayer.Name, ApprovedAt = os.time()
    })
    FirebasePut("/Requests/" .. key .. "/Status", "approved")
    LogAction("APPROVE", tostring(info.Username or key), "Request")
    opStatus.Text = "✅ Approved: " .. tostring(info.Username or key)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "✅ Request Approved",
            Text = tostring(info.Username or key),
            Duration = 3
        })
    end)
    task.wait(0.2); RenderReq()
end)
            local rb = Instance.new("TextButton", row)
            rb.Size = UDim2.new(0.48, -2, 1, 0)
            rb.Position = UDim2.new(0.52, 0, 0, 0)
            rb.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
            rb.Text = "❌ REJECT"
            rb.TextColor3 = Color3.fromRGB(255, 200, 200)
            rb.Font = Enum.Font.GothamBold
            rb.TextSize = 9
            rb.BorderSizePixel = 0
            Instance.new("UICorner", rb).CornerRadius = UDim.new(0, 4)
            rb.MouseButton1Click:Connect(function()
    FirebasePut("/Requests/" .. key .. "/Status", "rejected")
    LogAction("REJECT", tostring(info.Username or key), "Request")
    opStatus.Text = "❌ Rejected"
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "❌ Request Rejected",
            Text = tostring(info.Username or key),
            Duration = 3
        })
    end)
    task.wait(0.2); RenderReq()
end)
        end
    end
    task.wait()
    opReqScroll.CanvasSize = UDim2.new(0, 0, 0, opReqLayout.AbsoluteContentSize.Y + 8)
    opStatus.Text = "📩 REQ: " .. count .. " pending"
end

local function RenderBan()
    ClearScroll(opBanScroll)
    local data = FirebaseGet("/Banned")
    if type(data) ~= "table" or next(data) == nil then
        local lbl = Instance.new("TextLabel", opBanScroll)
        lbl.Size = UDim2.new(1, -8, 0, 26)
        lbl.BackgroundTransparency = 1
        lbl.Text = "Belum ada banned"
        lbl.TextColor3 = Color3.fromRGB(180, 160, 100)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 10
        opStatus.Text = "🚫 BAN: 0"
        return
    end
    local count = 0
    for key, val in pairs(data) do
        count = count + 1
        local card = Instance.new("Frame", opBanScroll)
        card.Size = UDim2.new(1, -8, 0, (type(val) == "table" and val.Duration) and 50 or 34)
        card.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
        card.BorderSizePixel = 0
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 5)
        local n = Instance.new("TextLabel", card)
        n.Size = UDim2.new(1, -90, 0, 16)
        n.Position = UDim2.new(0, 6, 0, 2)
        n.BackgroundTransparency = 1
        n.Text = "🚫 " .. tostring(key)
        n.TextColor3 = Color3.fromRGB(255, 150, 150)
        n.Font = Enum.Font.GothamBold
        n.TextSize = 10
        n.TextXAlignment = Enum.TextXAlignment.Left
        if type(val) == "table" and val.Duration then
            local dl = Instance.new("TextLabel", card)
            dl.Size = UDim2.new(1, -90, 0, 12)
            dl.Position = UDim2.new(0, 6, 0, 18)
            dl.BackgroundTransparency = 1
            dl.Text = "⏱️ " .. tostring(val.Duration) .. " • 📝 " .. tostring(val.Reason or "-")
            dl.TextColor3 = Color3.fromRGB(200, 150, 120)
            dl.Font = Enum.Font.Gotham
            dl.TextSize = 8
            dl.TextXAlignment = Enum.TextXAlignment.Left
        end
        local ub = Instance.new("TextButton", card)
        ub.Size = UDim2.new(0, 70, 0, 26)
        ub.Position = UDim2.new(1, -76, 0, 4)
        ub.BackgroundColor3 = Color3.fromRGB(20, 100, 40)
        ub.Text = "✅ UNBAN"
        ub.TextColor3 = Color3.fromRGB(200, 255, 200)
        ub.Font = Enum.Font.GothamBold
        ub.TextSize = 9
        ub.BorderSizePixel = 0
        Instance.new("UICorner", ub).CornerRadius = UDim.new(0, 4)
        ub.MouseButton1Click:Connect(function()
    local confirm = Instance.new("Frame", screenGui)
    confirm.Size = UDim2.new(0, 300, 0, 150)
    confirm.Position = UDim2.new(0.5, -150, 0.5, -75)
    confirm.BackgroundColor3 = Color3.fromRGB(10, 30, 10)
    confirm.BorderSizePixel = 0
    confirm.ZIndex = 700
    Instance.new("UICorner", confirm).CornerRadius = UDim.new(0, 10)
    
    local title = Instance.new("TextLabel", confirm)
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "✅ Unban User?"
    title.TextColor3 = Color3.fromRGB(100, 255, 100)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.ZIndex = 701
    
    local msg = Instance.new("TextLabel", confirm)
    msg.Size = UDim2.new(1, -20, 0, 60)
    msg.Position = UDim2.new(0, 10, 0, 40)
    msg.BackgroundTransparency = 1
    msg.Text = "Yakin unban:\n" .. tostring(key) .. "?"
    msg.TextColor3 = Color3.fromRGB(220, 255, 220)
    msg.Font = Enum.Font.Gotham
    msg.TextSize = 11
    msg.TextWrapped = true
    msg.ZIndex = 701
    
    local okBtn = Instance.new("TextButton", confirm)
    okBtn.Size = UDim2.new(0.45, -15, 0, 30)
    okBtn.Position = UDim2.new(0, 10, 1, -40)
    okBtn.BackgroundColor3 = Color3.fromRGB(20, 100, 40)
    okBtn.Text = "✅ UNBAN"
    okBtn.TextColor3 = Color3.fromRGB(200, 255, 200)
    okBtn.Font = Enum.Font.GothamBold
    okBtn.TextSize = 11
    okBtn.BorderSizePixel = 0
    okBtn.ZIndex = 701
    Instance.new("UICorner", okBtn).CornerRadius = UDim.new(0, 5)
    
    local cancelBtn = Instance.new("TextButton", confirm)
    cancelBtn.Size = UDim2.new(0.45, -15, 0, 30)
    cancelBtn.Position = UDim2.new(0.5, 5, 1, -40)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    cancelBtn.Text = "❌ BATAL"
    cancelBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextSize = 11
    cancelBtn.BorderSizePixel = 0
    cancelBtn.ZIndex = 701
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 5)
    
    okBtn.MouseButton1Click:Connect(function()
        FirebasePut("/Banned/" .. key, nil)
        LogAction("UNBAN", tostring(key), "Panel")
        opStatus.Text = "✅ Unbanned: " .. tostring(key)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "✅ User Unbanned",
                Text = tostring(key),
                Duration = 3
            })
        end)
        confirm:Destroy()
        task.wait(0.2); RenderBan()
    end)
    
    cancelBtn.MouseButton1Click:Connect(function()
        confirm:Destroy()
    end)
end)
    end
    task.wait()
    opBanScroll.CanvasSize = UDim2.new(0, 0, 0, opBanLayout.AbsoluteContentSize.Y + 8)
    opStatus.Text = "🚫 BAN: " .. count
end

local function RenderStats()
    ClearScroll(opStatsFrame)
    local wlData = FirebaseGet("/Whitelist") or {}
    local banData = FirebaseGet("/Banned") or {}
    local reqData = FirebaseGet("/Requests") or {}
    local activeData = FirebaseGet("/ActiveUsers") or {}
    local counts = { owner = 0, vip = 0, admin = 0, user = 0 }
    local auto, manual, total = 0, 0, 0
    for k, v in pairs(wlData) do
        total = total + 1
        if type(v) == "table" then
            local r = tostring(v.Role or "user"):lower()
            if counts[r] then counts[r] = counts[r] + 1 end
            if tostring(v.Source or "") == "auto-vip-prefix" then auto = auto + 1 else manual = manual + 1 end
        end
    end
    local banCount = 0
    for _ in pairs(banData) do banCount = banCount + 1 end
    local reqCount = 0
    for _, v in pairs(reqData) do
        if type(v) == "table" and tostring(v.Status or ""):lower() == "pending" then reqCount = reqCount + 1 end
    end
    local now = os.time()
    local activeCount = 0
    local mobileCount, pcCount, consoleCount = 0, 0, 0
    for _, v in pairs(activeData) do
        if type(v) == "table" and v.LastSeen and (now - tonumber(v.LastSeen)) < 300 then
            activeCount = activeCount + 1
            if v.Device == "Mobile" then mobileCount = mobileCount + 1
            elseif v.Device == "PC" then pcCount = pcCount + 1
            elseif v.Device == "Console" then consoleCount = consoleCount + 1 end
        end
    end
    local function addStat(t, v, c)
        local card = Instance.new("Frame", opStatsFrame)
        card.Size = UDim2.new(1, -8, 0, 30)
        card.BackgroundColor3 = Color3.fromRGB(30, 22, 10)
        card.BorderSizePixel = 0
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 5)
        local tl = Instance.new("TextLabel", card)
        tl.Size = UDim2.new(0.6, 0, 1, 0)
        tl.Position = UDim2.new(0, 8, 0, 0)
        tl.BackgroundTransparency = 1
        tl.Text = t
        tl.TextColor3 = Color3.fromRGB(220, 200, 150)
        tl.Font = Enum.Font.GothamBold
        tl.TextSize = 10
        tl.TextXAlignment = Enum.TextXAlignment.Left
        local vl = Instance.new("TextLabel", card)
        vl.Size = UDim2.new(0.4, -8, 1, 0)
        vl.Position = UDim2.new(0.6, 0, 0, 0)
        vl.BackgroundTransparency = 1
        vl.Text = tostring(v)
        vl.TextColor3 = c or Color3.fromRGB(255, 220, 120)
        vl.Font = Enum.Font.GothamBold
        vl.TextSize = 12
        vl.TextXAlignment = Enum.TextXAlignment.Right
    end
    addStat("📊 Total WL", total, Color3.fromRGB(150, 255, 180))
    addStat("👑 Owner", counts.owner, Color3.fromRGB(255, 215, 0))
    addStat("🏆 VIP", counts.vip, Color3.fromRGB(255, 200, 255))
    addStat("🛡️ Admin", counts.admin, Color3.fromRGB(200, 180, 255))
    addStat("✅ User", counts.user, Color3.fromRGB(150, 255, 180))
    addStat("🌟 Auto-Registered", auto, Color3.fromRGB(200, 150, 255))
    addStat("✍️ Manual-Added", manual, Color3.fromRGB(255, 220, 150))
    addStat("📩 Pending Req", reqCount, reqCount > 0 and Color3.fromRGB(255, 220, 120) or Color3.fromRGB(200, 200, 200))
    addStat("🚫 Banned", banCount, Color3.fromRGB(255, 120, 120))
    addStat("🟢 Online (5m)", activeCount, Color3.fromRGB(100, 255, 100))
    addStat("📱 Mobile Online", mobileCount, Color3.fromRGB(180, 220, 255))
    addStat("💻 PC Online", pcCount, Color3.fromRGB(180, 255, 220))
    addStat("🎮 Console Online", consoleCount, Color3.fromRGB(255, 200, 220))
    task.wait()
    opStatsFrame.CanvasSize = UDim2.new(0, 0, 0, opStatsLayout.AbsoluteContentSize.Y + 8)
    opStatus.Text = "📊 Stats loaded"
end

local function RenderLog()
    ClearScroll(opLogScroll)
    local data = FirebaseGet("/AuditLog")
    if type(data) ~= "table" or next(data) == nil then
        local lbl = Instance.new("TextLabel", opLogScroll)
        lbl.Size = UDim2.new(1, -8, 0, 26)
        lbl.BackgroundTransparency = 1
        lbl.Text = "Belum ada log"
        lbl.TextColor3 = Color3.fromRGB(180, 160, 100)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 10
        opStatus.Text = "📜 LOG: 0"
        return
    end
    local entries = {}
    for k, v in pairs(data) do table.insert(entries, { key = k, info = v }) end
    table.sort(entries, function(a, b)
        return tonumber(a.info.Timestamp or 0) > tonumber(b.info.Timestamp or 0)
    end)
    local count = 0
    for _, e in ipairs(entries) do
        count = count + 1
        if count > 100 then break end
        local info = e.info
        local card = Instance.new("Frame", opLogScroll)
        card.Size = UDim2.new(1, -8, 0, 34)
        card.BackgroundColor3 = Color3.fromRGB(25, 18, 8)
        card.BorderSizePixel = 0
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 5)
        local actionColor = Color3.fromRGB(255, 220, 150)
        local action = tostring(info.Action or "?")
        if action == "BAN" then actionColor = Color3.fromRGB(255, 120, 120)
        elseif action == "APPROVE" then actionColor = Color3.fromRGB(150, 255, 180)
        elseif action == "REJECT" then actionColor = Color3.fromRGB(255, 150, 100)
        elseif action == "DELETE" then actionColor = Color3.fromRGB(255, 180, 180)
        elseif action == "UNBAN" then actionColor = Color3.fromRGB(150, 255, 180)
        elseif action == "ROLE_CHANGE" then actionColor = Color3.fromRGB(150, 220, 255)
        elseif action == "EXPIRY_CHANGE" then actionColor = Color3.fromRGB(200, 150, 255)
        elseif action == "MAINTENANCE" then actionColor = Color3.fromRGB(255, 180, 0)
        elseif action == "ANNOUNCE" then actionColor = Color3.fromRGB(255, 200, 100) end
        local al = Instance.new("TextLabel", card)
        al.Size = UDim2.new(0.35, 0, 0, 16)
        al.Position = UDim2.new(0, 6, 0, 2)
        al.BackgroundTransparency = 1
        al.Text = action
        al.TextColor3 = actionColor
        al.Font = Enum.Font.GothamBold
        al.TextSize = 9
        al.TextXAlignment = Enum.TextXAlignment.Left
        local dl = Instance.new("TextLabel", card)
        dl.Size = UDim2.new(0.65, -6, 0, 16)
        dl.Position = UDim2.new(0.35, 0, 0, 2)
        dl.BackgroundTransparency = 1
        dl.Text = tostring(info.Date or "?")
        dl.TextColor3 = Color3.fromRGB(180, 160, 120)
        dl.Font = Enum.Font.Gotham
        dl.TextSize = 8
        dl.TextXAlignment = Enum.TextXAlignment.Right
        local tl = Instance.new("TextLabel", card)
        tl.Size = UDim2.new(1, -12, 0, 14)
        tl.Position = UDim2.new(0, 6, 0, 18)
        tl.BackgroundTransparency = 1
        tl.Text = "→ " .. tostring(info.Target or "?") .. " (" .. tostring(info.Detail or "") .. ")"
        tl.TextColor3 = Color3.fromRGB(200, 180, 140)
        tl.Font = Enum.Font.Gotham
        tl.TextSize = 8
        tl.TextXAlignment = Enum.TextXAlignment.Left
    end
    task.wait()
    opLogScroll.CanvasSize = UDim2.new(0, 0, 0, opLogLayout.AbsoluteContentSize.Y + 8)
    opStatus.Text = "📜 LOG: " .. math.min(count, 100)
end

local function RenderDev()
    ClearScroll(opDevScroll)
    local data = FirebaseGet("/ActiveUsers")
    if type(data) ~= "table" or next(data) == nil then
        local lbl = Instance.new("TextLabel", opDevScroll)
        lbl.Size = UDim2.new(1, -8, 0, 26)
        lbl.BackgroundTransparency = 1
        lbl.Text = "Belum ada data device"
        lbl.TextColor3 = Color3.fromRGB(180, 160, 100)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 10
        opStatus.Text = "📱 DEV: 0"
        return
    end
    local entries = {}
    for k, v in pairs(data) do
        if type(v) == "table" then table.insert(entries, { key = k, info = v }) end
    end
    table.sort(entries, function(a, b)
        return tonumber(a.info.LastSeen or 0) > tonumber(b.info.LastSeen or 0)
    end)
    local now = os.time()
    local onlineCount = 0
    for _, e in ipairs(entries) do
        local info = e.info
        local isOnline = info.LastSeen and (now - tonumber(info.LastSeen)) < 300
        if isOnline then onlineCount = onlineCount + 1 end
        local card = Instance.new("Frame", opDevScroll)
        card.Size = UDim2.new(1, -8, 0, 60)
        card.BackgroundColor3 = isOnline and Color3.fromRGB(20, 40, 20) or Color3.fromRGB(25, 20, 10)
        card.BorderSizePixel = 0
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 5)
        if isOnline then
            local s = Instance.new("UIStroke", card)
            s.Color = Color3.fromRGB(100, 255, 100); s.Thickness = 1
        end
        local name = Instance.new("TextLabel", card)
        name.Size = UDim2.new(1, -12, 0, 16)
        name.Position = UDim2.new(0, 6, 0, 3)
        name.BackgroundTransparency = 1
        name.Text = (isOnline and "🟢 " or "⚫ ") .. tostring(info.Username or e.key)
        name.TextColor3 = Color3.fromRGB(255, 230, 150)
        name.Font = Enum.Font.GothamBold
        name.TextSize = 10
        name.TextXAlignment = Enum.TextXAlignment.Left
        local line2 = Instance.new("TextLabel", card)
        line2.Size = UDim2.new(1, -12, 0, 12)
        line2.Position = UDim2.new(0, 6, 0, 20)
        line2.BackgroundTransparency = 1
        line2.Text = "📱 " .. tostring(info.Device or "?") .. "  •  🌏 " .. tostring(info.Locale or "?") .. "  •  📅 Age: " .. tostring(info.AccountAge or "?") .. "d"
        line2.TextColor3 = Color3.fromRGB(200, 180, 120)
        line2.Font = Enum.Font.Gotham
        line2.TextSize = 8
        line2.TextXAlignment = Enum.TextXAlignment.Left
        local line3 = Instance.new("TextLabel", card)
        line3.Size = UDim2.new(1, -12, 0, 12)
        line3.Position = UDim2.new(0, 6, 0, 32)
        line3.BackgroundTransparency = 1
        line3.Text = "👑 " .. tostring(info.Role or "?") .. "  •  ⏰ " .. tostring(info.LastSeenStr or "?")
        line3.TextColor3 = Color3.fromRGB(180, 160, 140)
        line3.Font = Enum.Font.Gotham
        line3.TextSize = 8
        line3.TextXAlignment = Enum.TextXAlignment.Left
        local kickBtn = Instance.new("TextButton", card)
        kickBtn.Size = UDim2.new(0, 60, 0, 22)
        kickBtn.Position = UDim2.new(1, -66, 0, 30)
        kickBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 20)
        kickBtn.Text = "🚪 CLEAR"
        kickBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
        kickBtn.Font = Enum.Font.GothamBold
        kickBtn.TextSize = 8
        kickBtn.BorderSizePixel = 0
        Instance.new("UICorner", kickBtn).CornerRadius = UDim.new(0, 4)
        kickBtn.MouseButton1Click:Connect(function()
            FirebasePut("/ActiveUsers/" .. e.key, nil)
            opStatus.Text = "🚪 Cleared: " .. tostring(info.Username)
            task.wait(0.2); RenderDev()
        end)
    end
    task.wait()
    opDevScroll.CanvasSize = UDim2.new(0, 0, 0, opDevLayout.AbsoluteContentSize.Y + 8)
    opStatus.Text = "📱 DEV: " .. #entries .. " (🟢 " .. onlineCount .. " online)"
end

local function RenderAnn()
    local cfg = FirebaseGet("/Announcement")
    if cfg and type(cfg) == "table" and cfg.Text then
        opAnnActive.Text = "📢 ACTIVE: " .. tostring(cfg.Title or "No title") .. " — " .. tostring(cfg.Text):sub(1, 50)
        opAnnActive.TextColor3 = Color3.fromRGB(150, 255, 180)
        opAnnTitle.Text = tostring(cfg.Title or "")
        opAnnMsg.Text = tostring(cfg.Text or "")
    else
        opAnnActive.Text = "⚫ Tidak ada announcement aktif"
        opAnnActive.TextColor3 = Color3.fromRGB(180, 160, 100)
    end
end

local function RenderCfg()
    ClearScroll(opCfgFrame)
    local maint = FirebaseGet("/Config/Maintenance") or {}
    local cfg = FirebaseGet("/Config") or {}

    local function addToggle(title, current, callback)
        local card = Instance.new("Frame", opCfgFrame)
        card.Size = UDim2.new(1, -8, 0, 40)
        card.BackgroundColor3 = Color3.fromRGB(30, 22, 10)
        card.BorderSizePixel = 0
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 5)
        local t = Instance.new("TextLabel", card)
        t.Size = UDim2.new(0.6, 0, 1, 0)
        t.Position = UDim2.new(0, 8, 0, 0)
        t.BackgroundTransparency = 1
        t.Text = title
        t.TextColor3 = Color3.fromRGB(220, 200, 150)
        t.Font = Enum.Font.GothamBold
        t.TextSize = 10
        t.TextXAlignment = Enum.TextXAlignment.Left
        local b = Instance.new("TextButton", card)
        b.Size = UDim2.new(0.3, -8, 0, 26)
        b.Position = UDim2.new(0.7, 0, 0, 7)
        b.BackgroundColor3 = current and Color3.fromRGB(20, 100, 40) or Color3.fromRGB(80, 20, 20)
        b.Text = current and "✅ ON" or "❌ OFF"
        b.TextColor3 = current and Color3.fromRGB(200, 255, 200) or Color3.fromRGB(255, 200, 200)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.BorderSizePixel = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        b.MouseButton1Click:Connect(function()
            callback(not current)
        end)
    end

    addToggle("🔧 Maintenance Mode", maint.Enabled == true, function(newVal)
        FirebasePut("/Config/Maintenance/Enabled", newVal)
        LogAction("MAINTENANCE", newVal and "ON" or "OFF", "Toggle")
        task.wait(0.2); RenderCfg()
    end)

    addToggle("⭐ Allow Owner During Maint", maint.AllowOwner ~= false, function(newVal)
        FirebasePut("/Config/Maintenance/AllowOwner", newVal)
        task.wait(0.2); RenderCfg()
    end)

    local rolesCard = Instance.new("Frame", opCfgFrame)
    rolesCard.Size = UDim2.new(1, -8, 0, 90)
    rolesCard.BackgroundColor3 = Color3.fromRGB(30, 22, 10)
    rolesCard.BorderSizePixel = 0
    Instance.new("UICorner", rolesCard).CornerRadius = UDim.new(0, 5)
    local rolesTitle = Instance.new("TextLabel", rolesCard)
    rolesTitle.Size = UDim2.new(1, -12, 0, 16)
    rolesTitle.Position = UDim2.new(0, 6, 0, 3)
    rolesTitle.BackgroundTransparency = 1
    rolesTitle.Text = "👥 Role yang Boleh Akses Saat Maintenance:"
    rolesTitle.TextColor3 = Color3.fromRGB(220, 200, 150)
    rolesTitle.Font = Enum.Font.GothamBold
    rolesTitle.TextSize = 9
    rolesTitle.TextXAlignment = Enum.TextXAlignment.Left

    local allowed = maint.AllowedRoles or {}
    local roleList = { "owner", "vip", "admin", "user" }
    for i, role in ipairs(roleList) do
        local btn = Instance.new("TextButton", rolesCard)
        btn.Size = UDim2.new(0.24, -4, 0, 26)
        btn.Position = UDim2.new((i-1) * 0.25, 4, 0, 24)
        btn.BackgroundColor3 = allowed[role] and Color3.fromRGB(20, 100, 40) or Color3.fromRGB(60, 30, 30)
        btn.Text = (allowed[role] and "✅ " or "❌ ") .. role:upper()
        btn.TextColor3 = allowed[role] and Color3.fromRGB(200, 255, 200) or Color3.fromRGB(255, 200, 200)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        btn.BorderSizePixel = 0
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        btn.MouseButton1Click:Connect(function()
            local newAllowed = maint.AllowedRoles or {}
            newAllowed[role] = not newAllowed[role]
            FirebasePut("/Config/Maintenance/AllowedRoles", newAllowed)
            task.wait(0.2); RenderCfg()
        end)
    end

    local msgLbl = Instance.new("TextLabel", rolesCard)
    msgLbl.Size = UDim2.new(1, -12, 0, 14)
    msgLbl.Position = UDim2.new(0, 6, 0, 56)
    msgLbl.BackgroundTransparency = 1
    msgLbl.Text = "📝 Pesan Maintenance:"
    msgLbl.TextColor3 = Color3.fromRGB(220, 200, 150)
    msgLbl.Font = Enum.Font.GothamBold
    msgLbl.TextSize = 8
    msgLbl.TextXAlignment = Enum.TextXAlignment.Left

    local msgInput = Instance.new("TextBox", rolesCard)
    msgInput.Size = UDim2.new(1, -12, 0, 22)
    msgInput.Position = UDim2.new(0, 6, 0, 68)
    msgInput.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
    msgInput.BorderSizePixel = 0
    msgInput.Text = tostring(maint.Message or "Sedang maintenance. Coba lagi nanti.")
    msgInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    msgInput.Font = Enum.Font.Gotham
    msgInput.TextSize = 9
    msgInput.ClearTextOnFocus = false
    Instance.new("UICorner", msgInput).CornerRadius = UDim.new(0, 4)
    msgInput.FocusLost:Connect(function()
        FirebasePut("/Config/Maintenance/Message", msgInput.Text)
        opStatus.Text = "📝 Message updated"
    end)

    local verCard = Instance.new("Frame", opCfgFrame)
    verCard.Size = UDim2.new(1, -8, 0, 60)
    verCard.BackgroundColor3 = Color3.fromRGB(30, 22, 10)
    verCard.BorderSizePixel = 0
    Instance.new("UICorner", verCard).CornerRadius = UDim.new(0, 5)
    local vt = Instance.new("TextLabel", verCard)
    vt.Size = UDim2.new(1, -12, 0, 16)
    vt.Position = UDim2.new(0, 6, 0, 3)
    vt.BackgroundTransparency = 1
    vt.Text = "🔢 Version Info"
    vt.TextColor3 = Color3.fromRGB(220, 200, 150)
    vt.Font = Enum.Font.GothamBold
    vt.TextSize = 9
    vt.TextXAlignment = Enum.TextXAlignment.Left
    local vInput = Instance.new("TextBox", verCard)
    vInput.Size = UDim2.new(1, -12, 0, 22)
    vInput.Position = UDim2.new(0, 6, 0, 22)
    vInput.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
    vInput.BorderSizePixel = 0
    vInput.Text = tostring(cfg.Version or "v9.0")
    vInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    vInput.Font = Enum.Font.Gotham
    vInput.TextSize = 9
    vInput.ClearTextOnFocus = false
    Instance.new("UICorner", vInput).CornerRadius = UDim.new(0, 4)
    vInput.FocusLost:Connect(function()
        FirebasePut("/Config/Version", vInput.Text)
        FirebasePut("/Config/LastUpdate", os.time())
        opStatus.Text = "🔢 Version updated"
    end)

    task.wait()
    opCfgFrame.CanvasSize = UDim2.new(0, 0, 0, opCfgLayout.AbsoluteContentSize.Y + 8)
    opStatus.Text = "⚙️ Config loaded"
end

opRoleFilterBtn.MouseButton1Click:Connect(function()
    OpenDropdown("", {}, "filter")
end)

opBanDurationBtn.MouseButton1Click:Connect(function()
    OpenDropdown("", {}, "banduration")
end)

opWLSearch:GetPropertyChangedSignal("Text"):Connect(function()
    currentSearchFilter = opWLSearch.Text
    RenderWL()
end)

opSelectAllBtn.MouseButton1Click:Connect(function()
    local data = FirebaseGet("/Whitelist")
    if type(data) ~= "table" then return end
    local anyUnselected = false
    for k, v in pairs(data) do
        local r = GetRoleFromInfo(v)
        if r ~= "owner" and not selectedUsers[k] then
            anyUnselected = true
            break
        end
    end
    if anyUnselected then
        for k, v in pairs(data) do
            local r = GetRoleFromInfo(v)
            if r ~= "owner" then
                selectedUsers[k] = true
            end
        end
        opSelectAllBtn.Text = "☑ ALL"
    else
        selectedUsers = {}
        opSelectAllBtn.Text = "☐ ALL"
    end
    RenderWL()
end)

opBulkDelBtn.MouseButton1Click:Connect(function()
    local total = 0
    for _ in pairs(selectedUsers) do total = total + 1 end
    if total == 0 then
        opStatus.Text = "⚠️ Gak ada user dipilih!"
        return
    end
    
    local confirm = Instance.new("Frame", screenGui)
    confirm.Size = UDim2.new(0, 300, 0, 150)
    confirm.Position = UDim2.new(0.5, -150, 0.5, -75)
    confirm.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
    confirm.BorderSizePixel = 0
    confirm.ZIndex = 700
    Instance.new("UICorner", confirm).CornerRadius = UDim.new(0, 10)
    
    local title = Instance.new("TextLabel", confirm)
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "🗑️ Bulk Delete?"
    title.TextColor3 = Color3.fromRGB(255, 100, 100)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.ZIndex = 701
    
    local msg = Instance.new("TextLabel", confirm)
    msg.Size = UDim2.new(1, -20, 0, 60)
    msg.Position = UDim2.new(0, 10, 0, 40)
    msg.BackgroundTransparency = 1
    msg.Text = "Yakin hapus " .. total .. " user sekaligus?"
    msg.TextColor3 = Color3.fromRGB(255, 220, 220)
    msg.Font = Enum.Font.Gotham
    msg.TextSize = 11
    msg.TextWrapped = true
    msg.ZIndex = 701
    
    local okBtn = Instance.new("TextButton", confirm)
    okBtn.Size = UDim2.new(0.45, -15, 0, 30)
    okBtn.Position = UDim2.new(0, 10, 1, -40)
    okBtn.BackgroundColor3 = Color3.fromRGB(140, 20, 20)
    okBtn.Text = "🗑️ HAPUS " .. total
    okBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
    okBtn.Font = Enum.Font.GothamBold
    okBtn.TextSize = 10
    okBtn.BorderSizePixel = 0
    okBtn.ZIndex = 701
    Instance.new("UICorner", okBtn).CornerRadius = UDim.new(0, 5)
    
    local cancelBtn = Instance.new("TextButton", confirm)
    cancelBtn.Size = UDim2.new(0.45, -15, 0, 30)
    cancelBtn.Position = UDim2.new(0.5, 5, 1, -40)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    cancelBtn.Text = "❌ BATAL"
    cancelBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextSize = 11
    cancelBtn.BorderSizePixel = 0
    cancelBtn.ZIndex = 701
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 5)
    
    okBtn.MouseButton1Click:Connect(function()
        local count = 0
        for k, _ in pairs(selectedUsers) do
            FirebasePut("/Whitelist/" .. k, nil); count = count + 1
        end
        LogAction("BULK_DELETE", count .. " users", "Bulk")
        opStatus.Text = "🗑️ Bulk deleted: " .. count
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "🗑️ Bulk Deleted",
                Text = count .. " user dihapus",
                Duration = 3
            })
        end)
        selectedUsers = {}
        confirm:Destroy()
        task.wait(0.2); RenderWL()
    end)
    
    cancelBtn.MouseButton1Click:Connect(function()
        confirm:Destroy()
    end)
end)

opBulkBanBtn.MouseButton1Click:Connect(function()
    local total = 0
    for _ in pairs(selectedUsers) do total = total + 1 end
    if total == 0 then
        opStatus.Text = "⚠️ Gak ada user dipilih!"
        return
    end
    
    local confirm = Instance.new("Frame", screenGui)
    confirm.Size = UDim2.new(0, 300, 0, 150)
    confirm.Position = UDim2.new(0.5, -150, 0.5, -75)
    confirm.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
    confirm.BorderSizePixel = 0
    confirm.ZIndex = 700
    Instance.new("UICorner", confirm).CornerRadius = UDim.new(0, 10)
    
    local title = Instance.new("TextLabel", confirm)
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "🔨 Bulk Ban?"
    title.TextColor3 = Color3.fromRGB(255, 100, 100)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.ZIndex = 701
    
    local msg = Instance.new("TextLabel", confirm)
    msg.Size = UDim2.new(1, -20, 0, 60)
    msg.Position = UDim2.new(0, 10, 0, 40)
    msg.BackgroundTransparency = 1
    msg.Text = "Yakin ban " .. total .. " user sekaligus?"
    msg.TextColor3 = Color3.fromRGB(255, 220, 220)
    msg.Font = Enum.Font.Gotham
    msg.TextSize = 11
    msg.TextWrapped = true
    msg.ZIndex = 701
    
    local okBtn = Instance.new("TextButton", confirm)
    okBtn.Size = UDim2.new(0.45, -15, 0, 30)
    okBtn.Position = UDim2.new(0, 10, 1, -40)
    okBtn.BackgroundColor3 = Color3.fromRGB(140, 20, 20)
    okBtn.Text = "🔨 BAN " .. total
    okBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
    okBtn.Font = Enum.Font.GothamBold
    okBtn.TextSize = 10
    okBtn.BorderSizePixel = 0
    okBtn.ZIndex = 701
    Instance.new("UICorner", okBtn).CornerRadius = UDim.new(0, 5)
    
    local cancelBtn = Instance.new("TextButton", confirm)
    cancelBtn.Size = UDim2.new(0.45, -15, 0, 30)
    cancelBtn.Position = UDim2.new(0.5, 5, 1, -40)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    cancelBtn.Text = "❌ BATAL"
    cancelBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextSize = 11
    cancelBtn.BorderSizePixel = 0
    cancelBtn.ZIndex = 701
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 5)
    
    okBtn.MouseButton1Click:Connect(function()
        local count = 0
        for k, _ in pairs(selectedUsers) do
            FirebasePut("/Banned/" .. k, {
    banned = true,
    Reason = "Bulk banned",
    Duration = "permanent",
    Timestamp = os.time()
})
            FirebasePut("/Whitelist/" .. k, nil); count = count + 1
        end
        LogAction("BULK_BAN", count .. " users", "Bulk")
        opStatus.Text = "🔨 Bulk banned: " .. count
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "🔨 Bulk Banned",
                Text = count .. " user kena ban",
                Duration = 3
            })
        end)
        selectedUsers = {}
        confirm:Destroy()
        task.wait(0.2); RenderWL()
    end)
    
    cancelBtn.MouseButton1Click:Connect(function()
        confirm:Destroy()
    end)
end)

opExportBtn.MouseButton1Click:Connect(function()
    local export = {
        ExportedAt = os.date("%Y-%m-%d %H:%M:%S"),
        Whitelist = FirebaseGet("/Whitelist") or {},
        Banned = FirebaseGet("/Banned") or {},
        Requests = FirebaseGet("/Requests") or {},
        AuditLog = FirebaseGet("/AuditLog") or {},
        Config = FirebaseGet("/Config") or {},
        Announcement = FirebaseGet("/Announcement") or {}
    }
    local json = HttpService:JSONEncode(export)
    if writefile then
        local fn = "DVExploitsBackup_" .. os.date("%d%m%y_%H%M") .. ".json"
        writefile(fn, json)
        opStatus.Text = "💾 Saved: " .. fn
    else
        opStatus.Text = "⚠️ writefile not supported"
    end
end)

opBanSubmit.MouseButton1Click:Connect(function()
    local target = opBanInput.Text:gsub("%s", "")
    if target == "" then
        opStatus.Text = "⚠️ Isi UserId/Username!"
        return
    end
    
    if not target:match("^%d+$") then
        local foundId = FindUserIdByUsername(target)
        if not foundId then
            opStatus.Text = "❌ Username nggak ketemu di WL!"
            return
        end
        target = foundId
    end
    
    local targetInfo = FirebaseGet("/Whitelist/" .. target)
    if targetInfo and type(targetInfo) == "table" and tostring(targetInfo.Role):lower() == "owner" then
        opStatus.Text = "🔒 Gak bisa ban Owner!"
        return
    end
    
    if currentRole == "admin" and targetInfo and type(targetInfo) == "table" and tostring(targetInfo.Role):lower() == "admin" then
        opStatus.Text = "❌ Admin nggak bisa ban admin lain!"
        return
    end
    
    local banData = { banned = true, Reason = opBanReason.Text, Duration = currentBanDuration, Timestamp = os.time() }
    local expireAt = nil
    local now = os.time()
    if currentBanDuration == "1h" then expireAt = now + 3600
    elseif currentBanDuration == "24h" then expireAt = now + 86400
    elseif currentBanDuration == "7d" then expireAt = now + 7 * 86400
    elseif currentBanDuration == "30d" then expireAt = now + 30 * 86400 end
    if expireAt then banData.ExpiresAt = expireAt end
    FirebasePut("/Banned/" .. target, banData)
    FirebasePut("/Whitelist/" .. target, nil)
    LogAction("BAN", target, "Duration: " .. currentBanDuration .. " | " .. opBanReason.Text)
    opStatus.Text = "🔨 Banned: " .. target
    opBanInput.Text = ""
    opBanReason.Text = ""
    task.wait(0.2); RenderBan()
end)

opAnnSend.MouseButton1Click:Connect(function()
    if opAnnTitle.Text == "" and opAnnMsg.Text == "" then
        opStatus.Text = "⚠️ Isi title/pesan!"
        return
    end
    FirebasePut("/Announcement", {
        Title = opAnnTitle.Text,
        Text = opAnnMsg.Text,
        Timestamp = os.time(),
        By = LocalPlayer.Name
    })
    LogAction("ANNOUNCE", opAnnTitle.Text, opAnnMsg.Text)
    opStatus.Text = "📢 Announcement sent!"
    task.wait(0.5); RenderAnn()
end)

opAnnClear.MouseButton1Click:Connect(function()
    FirebasePut("/Announcement", nil)
    opStatus.Text = "🗑️ Announcement cleared"
    opAnnTitle.Text = ""
    opAnnMsg.Text = ""
    task.wait(0.2); RenderAnn()
end)

local function SwitchTab(name)
    opWLFrame.Visible = (name == "WL")
    opReqScroll.Visible = (name == "REQ")
    opBanFrame.Visible = (name == "BAN")
    opStatsFrame.Visible = (name == "STAT")
    opLogScroll.Visible = (name == "LOG")
    opDevScroll.Visible = (name == "DEV")
    opAnnFrame.Visible = (name == "ANN")
    opCfgFrame.Visible = (name == "CFG")

    opTabWL.BackgroundColor3 = (name == "WL") and Color3.fromRGB(180, 120, 0) or Color3.fromRGB(40, 25, 10)
    opTabReq.BackgroundColor3 = (name == "REQ") and Color3.fromRGB(180, 120, 0) or Color3.fromRGB(40, 25, 10)
    opTabBan.BackgroundColor3 = (name == "BAN") and Color3.fromRGB(180, 120, 0) or Color3.fromRGB(40, 25, 10)
    opTabStats.BackgroundColor3 = (name == "STAT") and Color3.fromRGB(180, 120, 0) or Color3.fromRGB(40, 25, 10)
    opTabLog.BackgroundColor3 = (name == "LOG") and Color3.fromRGB(180, 120, 0) or Color3.fromRGB(40, 25, 10)
    opTabDev.BackgroundColor3 = (name == "DEV") and Color3.fromRGB(180, 120, 0) or Color3.fromRGB(40, 25, 10)
    opTabAnn.BackgroundColor3 = (name == "ANN") and Color3.fromRGB(180, 120, 0) or Color3.fromRGB(40, 25, 10)
    opTabCfg.BackgroundColor3 = (name == "CFG") and Color3.fromRGB(180, 120, 0) or Color3.fromRGB(40, 25, 10)

    if name == "WL" then RenderWL()
    elseif name == "REQ" then RenderReq()
    elseif name == "BAN" then RenderBan()
    elseif name == "STAT" then RenderStats()
    elseif name == "LOG" then RenderLog()
    elseif name == "DEV" then RenderDev()
    elseif name == "ANN" then RenderAnn()
    elseif name == "CFG" then RenderCfg() end
end

opTabWL.MouseButton1Click:Connect(function() SwitchTab("WL") end)
opTabReq.MouseButton1Click:Connect(function() SwitchTab("REQ") end)
opTabBan.MouseButton1Click:Connect(function() SwitchTab("BAN") end)
opTabStats.MouseButton1Click:Connect(function() SwitchTab("STAT") end)
opTabLog.MouseButton1Click:Connect(function() SwitchTab("LOG") end)
opTabDev.MouseButton1Click:Connect(function() SwitchTab("DEV") end)
opTabAnn.MouseButton1Click:Connect(function() SwitchTab("ANN") end)
opTabCfg.MouseButton1Click:Connect(function() SwitchTab("CFG") end)

opClose.MouseButton1Click:Connect(function()
    ownerPanel.Visible = false
    CloseDropdown()
end)

ownerPanelBtn.MouseButton1Click:Connect(function()
    if currentRole ~= "owner" and currentRole ~= "admin" then
        return warn("❌ Akses ditolak!")
    end
    ownerPanel.Visible = true
    
    opTabCfg.Visible = (currentRole == "owner")
    
    SwitchTab("WL")
end)

local function ShowLauncher()
    isHidden = false
    hideIcon.Visible = false
    mainWrap.Visible = true
end

local function HideLauncher()
    isHidden = true
    mainWrap.Visible = false
    hideIcon.Visible = true
    hideIcon.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(hideIcon, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Size = UDim2.new(0, 46, 0, 46)}):Play()
end

hideBtn.MouseButton1Click:Connect(HideLauncher)
hideIcon.MouseButton1Click:Connect(ShowLauncher)

minBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    content.Visible = not isMinimized
    mainWrap.Size = isMinimized and UDim2.new(0, 320, 0, 40) or UDim2.new(0, 320, 0, 440)
    minBtn.Text = isMinimized and "⊕" or "−"
end)

closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

local dragging = false
local dragStart, startPos
hideIcon.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
        dragStart = input.Position
        startPos = hideIcon.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then dragging = true end
        if dragging then
            hideIcon.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragStart = nil
        task.wait(0.05)
        dragging = false
    end
end)

hideIcon.MouseButton1Click:Connect(function()
    if dragging then return end
    ShowLauncher()
end)

task.spawn(function()
    local stages = {
        {15, "Connecting..."}, {35, "Loading UI..."}, {55, "Verifying..."},
        {75, "Syncing WL..."}, {90, "Finalizing..."}, {100, "Ready!"}
    }
    local prev = 0
    for _, stage in ipairs(stages) do
        loadSub.Text = stage[2]
        TweenService:Create(progressBar, TweenInfo.new(0.3), {Size = UDim2.new(stage[1]/100, 0, 1, 0)}):Play()
        for i = prev, stage[1] do
            percentLbl.Text = i .. "%"
            task.wait(0.006)
        end
        prev = stage[1]
        task.wait(0.1)
    end
    task.wait(0.3)

    Heartbeat()

    local role = CheckUserRole()
    local inMaint, maintMsg = CheckMaintenance(role)
    if inMaint then
        loadingBorder:Destroy()
        maintenanceOverlay.Visible = true
        maintMsg.Text = tostring(maintMsg)
        return
    end

    local announce = FirebaseGet("/Announcement")
    if announce and type(announce) == "table" and announce.Text then
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "📢 " .. tostring(announce.Title or "Announcement"),
                Text = tostring(announce.Text),
                Duration = 8
            })
        end)
    end

    loadingBorder:Destroy()
    mainWrap.Visible = true
    DoCheckAccount()
end)

createChatUI()
-- loadChatSettings()

task.spawn(function()
    while true do
        task.wait(3)
        if ChatGui and CHAT_STATE.isOpen and chatScrollRef then
            pcall(renderChatMessages)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(30)
        pcall(Heartbeat)
    end
end)

task.spawn(function()
    while true do
        task.wait(15)
        if not currentIsOwner then
    local role = currentRole or "denied"
    local inMaint, msg = CheckMaintenance(role)
            if inMaint then
                maintenanceOverlay.Visible = true
                maintMsg.Text = tostring(msg)
                mainWrap.Visible = false
                hideIcon.Visible = false
            else
                if maintenanceOverlay.Visible then
                    maintenanceOverlay.Visible = false
                    if not mainWrap.Visible and not hideIcon.Visible then
                        mainWrap.Visible = true
                    end
                end
            end
        end
    end
end)
