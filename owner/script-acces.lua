local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local BACKEND_URL = "https://igr-backen.vercel.app/api"

local function HttpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url, true) end)
    if not ok or not res or res == "null" then return nil end
    local dec = nil
    pcall(function() dec = HttpService:JSONDecode(res) end)
    return dec
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
        local ok = pcall(function()
            return request({ Url = url, Method = "PUT", Headers = headers, Body = body })
        end)
        if ok then return true end
    end
    if type(http_request) == "function" then
        local ok = pcall(function()
            return http_request({ Url = url, Method = "PUT", Headers = headers, Body = body })
        end)
        if ok then return true end
    end
    return false
end

local SCRIPT_FEATURES = {
    { id = "autofarm_igr", name = "🚀 AUTO FARM IGR" },
    { id = "shop_igr", name = "🛒 SHOP SISTEM IGR" },
    { id = "farm_sog", name = "🎵 FARM SOG" },
}

local ROLE_LABEL = {
    owner = "👑 OWNER",
    admin = "🛡️ ADMIN",
    vip = "🏆 VIP",
    user = "✅ USER",
}

local ROLE_ORDER = { user = 1, admin = 2, vip = 3, owner = 4 }

local function GetRoleFromInfo(info)
    if type(info) ~= "table" then return "user" end
    return tostring(info.Role or "user"):lower()
end

local function GetRoleIcon(role)
    local assets = {
        owner = "rbxassetid://90063813596217",
        admin = "rbxassetid://123735454065460",
        vip = "rbxassetid://96846969370988",
        user = "rbxassetid://73321251136394",
    }
    return assets[role]
end

local function LogAction(action, target, detail)
    local logId = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
    FirebasePut("/AuditLog/" .. logId, {
        Action = action,
        Target = tostring(target),
        Detail = tostring(detail or ""),
        By = LocalPlayer.Name,
        Timestamp = os.time(),
        Date = os.date("%d/%m/%y %H:%M")
    })
end

local function Notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 3
        })
    end)
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DVScriptAccessPanel"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 1000
screenGui.Parent = PlayerGui

local panel = Instance.new("Frame", screenGui)
panel.Size = UDim2.new(0, 400, 0, 480)
panel.Position = UDim2.new(0.5, -200, 0.5, -240)
panel.BackgroundColor3 = Color3.fromRGB(15, 10, 25)
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local pStroke = Instance.new("UIStroke", panel)
pStroke.Color = Color3.fromRGB(255, 180, 0)
pStroke.Thickness = 2

local header = Instance.new("Frame", panel)
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundColor3 = Color3.fromRGB(30, 15, 5)
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(1, -50, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "🎛️ SCRIPT ACCESS CONTROL"
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -34, 0.5, -13)
closeBtn.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.BorderSizePixel = 0
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)
closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

local subBar = Instance.new("Frame", panel)
subBar.Size = UDim2.new(1, -20, 0, 28)
subBar.Position = UDim2.new(0, 10, 0, 50)
subBar.BackgroundColor3 = Color3.fromRGB(20, 15, 10)
subBar.BorderSizePixel = 0
Instance.new("UICorner", subBar).CornerRadius = UDim.new(0, 6)

local subRole = Instance.new("TextButton", subBar)
subRole.Size = UDim2.new(0.5, -2, 1, -4)
subRole.Position = UDim2.new(0, 2, 0, 2)
subRole.BackgroundColor3 = Color3.fromRGB(180, 120, 0)
subRole.Text = "🎯 BY ROLE"
subRole.TextColor3 = Color3.fromRGB(255, 255, 255)
subRole.Font = Enum.Font.GothamBold
subRole.TextSize = 10
subRole.BorderSizePixel = 0
Instance.new("UICorner", subRole).CornerRadius = UDim.new(0, 4)

local subUser = Instance.new("TextButton", subBar)
subUser.Size = UDim2.new(0.5, -2, 1, -4)
subUser.Position = UDim2.new(0.5, 0, 0, 2)
subUser.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
subUser.Text = "👤 BY USER"
subUser.TextColor3 = Color3.fromRGB(200, 180, 140)
subUser.Font = Enum.Font.GothamBold
subUser.TextSize = 10
subUser.BorderSizePixel = 0
Instance.new("UICorner", subUser).CornerRadius = UDim.new(0, 4)

local roleFrame = Instance.new("ScrollingFrame", panel)
roleFrame.Size = UDim2.new(1, -20, 1, -140)
roleFrame.Position = UDim2.new(0, 10, 0, 86)
roleFrame.BackgroundColor3 = Color3.fromRGB(10, 8, 15)
roleFrame.BorderSizePixel = 0
roleFrame.ScrollBarThickness = 3
roleFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 180, 0)
roleFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", roleFrame).CornerRadius = UDim.new(0, 6)
local roleLayout = Instance.new("UIListLayout", roleFrame)
roleLayout.Padding = UDim.new(0, 6)

local userFrame = Instance.new("Frame", panel)
userFrame.Size = UDim2.new(1, -20, 1, -140)
userFrame.Position = UDim2.new(0, 10, 0, 86)
userFrame.BackgroundTransparency = 1
userFrame.Visible = false

local searchBar = Instance.new("Frame", userFrame)
searchBar.Size = UDim2.new(1, 0, 0, 26)
searchBar.BackgroundColor3 = Color3.fromRGB(25, 15, 5)
searchBar.BorderSizePixel = 0
Instance.new("UICorner", searchBar).CornerRadius = UDim.new(0, 5)

local searchBox = Instance.new("TextBox", searchBar)
searchBox.Size = UDim2.new(1, -12, 1, -6)
searchBox.Position = UDim2.new(0, 6, 0, 3)
searchBox.BackgroundTransparency = 1
searchBox.PlaceholderText = "🔍 Cari user WL..."
searchBox.PlaceholderColor3 = Color3.fromRGB(160, 140, 100)
searchBox.Text = ""
searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 10
searchBox.ClearTextOnFocus = false

local userScroll = Instance.new("ScrollingFrame", userFrame)
userScroll.Size = UDim2.new(1, 0, 1, -34)
userScroll.Position = UDim2.new(0, 0, 0, 34)
userScroll.BackgroundColor3 = Color3.fromRGB(10, 8, 15)
userScroll.BorderSizePixel = 0
userScroll.ScrollBarThickness = 3
userScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 180, 0)
userScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", userScroll).CornerRadius = UDim.new(0, 6)
local userLayout = Instance.new("UIListLayout", userScroll)
userLayout.Padding = UDim.new(0, 4)

local statusLbl = Instance.new("TextLabel", panel)
statusLbl.Size = UDim2.new(1, -20, 0, 24)
statusLbl.Position = UDim2.new(0, 10, 1, -30)
statusLbl.BackgroundColor3 = Color3.fromRGB(25, 15, 5)
statusLbl.BorderSizePixel = 0
statusLbl.Font = Enum.Font.Gotham
statusLbl.Text = "⚡ Ready"
statusLbl.TextColor3 = Color3.fromRGB(255, 220, 150)
statusLbl.TextSize = 9
Instance.new("UICorner", statusLbl).CornerRadius = UDim.new(0, 5)

local expandedUserKey = nil
local currentFilter = ""

local function ClearScroll(scroll)
    for _, c in ipairs(scroll:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
end

local function RenderRole()
    ClearScroll(roleFrame)
    statusLbl.Text = "⏳ Loading script access..."
    
    local accessData = FirebaseGet("/Config/ScriptAccess") or {}
    local roles = { "owner", "admin", "vip", "user" }
    local roleIcons = { owner = "👑", admin = "🛡️", vip = "💎", user = "✅" }
    
    for _, feature in ipairs(SCRIPT_FEATURES) do
        local card = Instance.new("Frame", roleFrame)
        card.Size = UDim2.new(1, -6, 0, 90)
        card.BackgroundColor3 = Color3.fromRGB(30, 22, 10)
        card.BorderSizePixel = 0
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
        
        local ftitle = Instance.new("TextLabel", card)
        ftitle.Size = UDim2.new(1, -12, 0, 20)
        ftitle.Position = UDim2.new(0, 6, 0, 4)
        ftitle.BackgroundTransparency = 1
        ftitle.Font = Enum.Font.GothamBold
        ftitle.Text = feature.name
        ftitle.TextColor3 = Color3.fromRGB(255, 220, 150)
        ftitle.TextSize = 11
        ftitle.TextXAlignment = Enum.TextXAlignment.Left
        
        local roleRow = Instance.new("Frame", card)
        roleRow.Size = UDim2.new(1, -12, 0, 60)
        roleRow.Position = UDim2.new(0, 6, 0, 26)
        roleRow.BackgroundTransparency = 1
        
        for i, role in ipairs(roles) do
            local isAllowed = true
            local fdata = accessData[feature.id]
            if type(fdata) == "table" and fdata[role] == false then
                isAllowed = false
            end
            
            local btn = Instance.new("TextButton", roleRow)
            btn.Size = UDim2.new(0.24, -4, 1, 0)
            btn.Position = UDim2.new((i-1) * 0.25, 0, 0, 0)
            btn.BackgroundColor3 = isAllowed 
                and Color3.fromRGB(20, 100, 40) 
                or Color3.fromRGB(120, 20, 20)
            btn.Font = Enum.Font.GothamBold
            btn.Text = roleIcons[role] .. "\n" .. (isAllowed and "✅ ON" or "❌ OFF")
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.TextSize = 10
            btn.BorderSizePixel = 0
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
            
            btn.MouseButton1Click:Connect(function()
                local newVal = not isAllowed
                FirebasePut("/Config/ScriptAccess/" .. feature.id .. "/" .. role, newVal)
                LogAction("SCRIPT_TOGGLE", feature.id, role .. " → " .. (newVal and "ON" or "OFF"))
                statusLbl.Text = "✅ " .. feature.name .. " " .. roleIcons[role] .. " " .. (newVal and "ON" or "OFF")
                task.wait(0.2)
                RenderRole()
            end)
        end
    end
    
    task.wait()
    roleFrame.CanvasSize = UDim2.new(0, 0, 0, roleLayout.AbsoluteContentSize.Y + 8)
    statusLbl.Text = "🎛️ Script access loaded"
end

local function RenderUser()
    ClearScroll(userScroll)
    statusLbl.Text = "⏳ Loading WL..."
    
    local wlData = FirebaseGet("/Whitelist")
    if type(wlData) ~= "table" or next(wlData) == nil then
        local lbl = Instance.new("TextLabel", userScroll)
        lbl.Size = UDim2.new(1, -8, 0, 26)
        lbl.BackgroundTransparency = 1
        lbl.Text = "Kosong"
        lbl.TextColor3 = Color3.fromRGB(180, 160, 100)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 10
        statusLbl.Text = "🎛️ WL: 0"
        return
    end
    
    local entries = {}
    for k, v in pairs(wlData) do
        local role = GetRoleFromInfo(v)
        if role ~= "owner" then
            local match = true
            if currentFilter ~= "" then
                local q = currentFilter:lower()
                local name = tostring(v.Username or k):lower()
                match = name:find(q, 1, true) ~= nil or tostring(k):find(q, 1, true) ~= nil
            end
            if match then
                table.insert(entries, { key = k, info = v })
            end
        end
    end
    
    table.sort(entries, function(a, b)
        local aR = ROLE_ORDER[GetRoleFromInfo(a.info)] or 0
        local bR = ROLE_ORDER[GetRoleFromInfo(b.info)] or 0
        if aR ~= bR then return aR > bR end
        return tostring(a.key):lower() < tostring(b.key):lower()
    end)
    
    for _, entry in ipairs(entries) do
        local key, info = entry.key, entry.info
        local userRole = GetRoleFromInfo(info)
        local isExpanded = (expandedUserKey == key)
        
        local card = Instance.new("Frame", userScroll)
        card.Size = UDim2.new(1, -6, 0, isExpanded and 260 or 50)
        card.BackgroundColor3 = Color3.fromRGB(30, 22, 10)
        card.BorderSizePixel = 0
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 5)
        
        local iconAsset = GetRoleIcon(userRole)
        if iconAsset then
            local icon = Instance.new("ImageLabel", card)
            icon.Size = UDim2.new(0, 26, 0, 26)
            icon.Position = UDim2.new(0, 8, 0, 12)
            icon.BackgroundTransparency = 1
            icon.Image = iconAsset
            icon.ScaleType = Enum.ScaleType.Fit
        end
        
        local nameBtn = Instance.new("TextButton", card)
        nameBtn.Size = UDim2.new(1, -100, 0, 20)
        nameBtn.Position = UDim2.new(0, 42, 0, 6)
        nameBtn.BackgroundTransparency = 1
        nameBtn.Font = Enum.Font.GothamBold
        nameBtn.Text = tostring(info.Username or key)
        nameBtn.TextColor3 = Color3.fromRGB(255, 220, 150)
        nameBtn.TextSize = 11
        nameBtn.TextXAlignment = Enum.TextXAlignment.Left
        nameBtn.MouseButton1Click:Connect(function()
            expandedUserKey = (expandedUserKey == key) and nil or key
            RenderUser()
        end)
        
        local roleLbl = Instance.new("TextLabel", card)
        roleLbl.Size = UDim2.new(1, -100, 0, 14)
        roleLbl.Position = UDim2.new(0, 42, 0, 26)
        roleLbl.BackgroundTransparency = 1
        roleLbl.Font = Enum.Font.Gotham
        roleLbl.Text = ROLE_LABEL[userRole] or userRole
        roleLbl.TextColor3 = Color3.fromRGB(180, 160, 120)
        roleLbl.TextSize = 8
        roleLbl.TextXAlignment = Enum.TextXAlignment.Left
        
        local chev = Instance.new("TextButton", card)
        chev.Size = UDim2.new(0, 30, 0, 30)
        chev.Position = UDim2.new(1, -38, 0, 10)
        chev.BackgroundColor3 = Color3.fromRGB(60, 40, 15)
        chev.Text = isExpanded and "▲" or "▼"
        chev.TextColor3 = Color3.fromRGB(255, 220, 150)
        chev.Font = Enum.Font.GothamBold
        chev.TextSize = 12
        chev.BorderSizePixel = 0
        Instance.new("UICorner", chev).CornerRadius = UDim.new(0, 4)
        chev.MouseButton1Click:Connect(function()
            expandedUserKey = (expandedUserKey == key) and nil or key
            RenderUser()
        end)
        
        if isExpanded then
            local targetId = tostring(info.UserId or key)
            local blData = FirebaseGet("/UserScriptBlacklist/" .. targetId)
            local wlUserData = FirebaseGet("/UserScriptWhitelist/" .. targetId)
            if type(blData) ~= "table" then blData = {} end
            if type(wlUserData) ~= "table" then wlUserData = {} end
            
            local divider = Instance.new("Frame", card)
            divider.Size = UDim2.new(1, -12, 0, 1)
            divider.Position = UDim2.new(0, 6, 0, 50)
            divider.BackgroundColor3 = Color3.fromRGB(80, 60, 20)
            divider.BorderSizePixel = 0
            
            local fy = 55
            for _, feature in ipairs(SCRIPT_FEATURES) do
                local fCard = Instance.new("Frame", card)
                fCard.Size = UDim2.new(1, -12, 0, 65)
                fCard.Position = UDim2.new(0, 6, 0, fy)
                fCard.BackgroundColor3 = Color3.fromRGB(20, 15, 10)
                fCard.BorderSizePixel = 0
                Instance.new("UICorner", fCard).CornerRadius = UDim.new(0, 4)
                
                local fname = Instance.new("TextLabel", fCard)
                fname.Size = UDim2.new(1, -12, 0, 18)
                fname.Position = UDim2.new(0, 6, 0, 3)
                fname.BackgroundTransparency = 1
                fname.Font = Enum.Font.GothamBold
                fname.Text = feature.name
                fname.TextColor3 = Color3.fromRGB(255, 220, 150)
                fname.TextSize = 10
                fname.TextXAlignment = Enum.TextXAlignment.Left
                
                local status = "default"
                if blData[feature.id] == true then status = "blocked"
                elseif wlUserData[feature.id] == true then status = "allowed" end
                
                local sRow = Instance.new("Frame", fCard)
                sRow.Size = UDim2.new(1, -12, 0, 28)
                sRow.Position = UDim2.new(0, 6, 0, 24)
                sRow.BackgroundTransparency = 1
                
                local allowBtn = Instance.new("TextButton", sRow)
                allowBtn.Size = UDim2.new(0.32, -2, 1, 0)
                allowBtn.BackgroundColor3 = status == "allowed" and Color3.fromRGB(20, 100, 40) or Color3.fromRGB(30, 30, 40)
                allowBtn.Text = "✅ ALLOW"
                allowBtn.TextColor3 = Color3.fromRGB(200, 255, 200)
                allowBtn.Font = Enum.Font.GothamBold
                allowBtn.TextSize = 9
                allowBtn.BorderSizePixel = 0
                Instance.new("UICorner", allowBtn).CornerRadius = UDim.new(0, 4)
                allowBtn.MouseButton1Click:Connect(function()
                    FirebasePut("/UserScriptBlacklist/" .. targetId .. "/" .. feature.id, nil)
                    FirebasePut("/UserScriptWhitelist/" .. targetId .. "/" .. feature.id, true)
                    LogAction("USER_SCRIPT_ALLOW", targetId, feature.id)
                    statusLbl.Text = "✅ ALLOW: " .. tostring(info.Username or key)
                    task.wait(0.2)
                    RenderUser()
                end)
                
                local defBtn = Instance.new("TextButton", sRow)
                defBtn.Size = UDim2.new(0.32, -2, 1, 0)
                defBtn.Position = UDim2.new(0.34, 0, 0, 0)
                defBtn.BackgroundColor3 = status == "default" and Color3.fromRGB(50, 50, 80) or Color3.fromRGB(30, 30, 40)
                defBtn.Text = "⚙️ DEFAULT"
                defBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
                defBtn.Font = Enum.Font.GothamBold
                defBtn.TextSize = 9
                defBtn.BorderSizePixel = 0
                Instance.new("UICorner", defBtn).CornerRadius = UDim.new(0, 4)
                defBtn.MouseButton1Click:Connect(function()
                    FirebasePut("/UserScriptBlacklist/" .. targetId .. "/" .. feature.id, nil)
                    FirebasePut("/UserScriptWhitelist/" .. targetId .. "/" .. feature.id, nil)
                    LogAction("USER_SCRIPT_DEFAULT", targetId, feature.id)
                    statusLbl.Text = "⚙️ DEFAULT: " .. tostring(info.Username or key)
                    task.wait(0.2)
                    RenderUser()
                end)
                
                local blockBtn = Instance.new("TextButton", sRow)
                blockBtn.Size = UDim2.new(0.32, -2, 1, 0)
                blockBtn.Position = UDim2.new(0.68, 0, 0, 0)
                blockBtn.BackgroundColor3 = status == "blocked" and Color3.fromRGB(120, 20, 20) or Color3.fromRGB(30, 30, 40)
                blockBtn.Text = "🚫 BLOCK"
                blockBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
                blockBtn.Font = Enum.Font.GothamBold
                blockBtn.TextSize = 9
                blockBtn.BorderSizePixel = 0
                Instance.new("UICorner", blockBtn).CornerRadius = UDim.new(0, 4)
                blockBtn.MouseButton1Click:Connect(function()
                    FirebasePut("/UserScriptBlacklist/" .. targetId .. "/" .. feature.id, true)
                    FirebasePut("/UserScriptWhitelist/" .. targetId .. "/" .. feature.id, nil)
                    LogAction("USER_SCRIPT_BLOCK", targetId, feature.id)
                    statusLbl.Text = "🚫 BLOCK: " .. tostring(info.Username or key)
                    task.wait(0.2)
                    RenderUser()
                end)
                
                fy = fy + 70
            end
        end
    end
    
    task.wait()
    userScroll.CanvasSize = UDim2.new(0, 0, 0, userLayout.AbsoluteContentSize.Y + 8)
    statusLbl.Text = "🎛️ Total: " .. #entries .. " user"
end

subRole.MouseButton1Click:Connect(function()
    subRole.BackgroundColor3 = Color3.fromRGB(180, 120, 0)
    subRole.TextColor3 = Color3.fromRGB(255, 255, 255)
    subUser.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
    subUser.TextColor3 = Color3.fromRGB(200, 180, 140)
    roleFrame.Visible = true
    userFrame.Visible = false
    RenderRole()
end)

subUser.MouseButton1Click:Connect(function()
    subUser.BackgroundColor3 = Color3.fromRGB(180, 120, 0)
    subUser.TextColor3 = Color3.fromRGB(255, 255, 255)
    subRole.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
    subRole.TextColor3 = Color3.fromRGB(200, 180, 140)
    roleFrame.Visible = false
    userFrame.Visible = true
    RenderUser()
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    currentFilter = searchBox.Text
    RenderUser()
end)

RenderRole()
