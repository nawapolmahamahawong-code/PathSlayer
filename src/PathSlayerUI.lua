-- PathSlayer UI — เมนูฝั่ง client ล้วน ไม่มี remote ของตัวเอง ไม่แตะ server
-- แท็บ Main = ร้านอาวุธ อ่านรายการจริงจาก ReplicatedStorage ไม่ฝังลิสต์ไว้ในโค้ด
-- เพราะเกมนี้แก้ราคา/สูตรผ่าน Live config ได้ ลิสต์ที่ฝังไว้จะเพี้ยนทันทีที่เขาอัปเดต

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

if _G.PathSlayerUnload then
	_G.PathSlayerUnload()
end

local LocalPlayer = Players.LocalPlayer

local Theme = {
	Base = Color3.fromRGB(16, 16, 20),
	Panel = Color3.fromRGB(21, 21, 26),
	Raised = Color3.fromRGB(30, 30, 37),
	Row = Color3.fromRGB(25, 25, 31),
	Stroke = Color3.fromRGB(44, 44, 54),
	Text = Color3.fromRGB(236, 236, 242),
	Muted = Color3.fromRGB(128, 128, 142),
	Dim = Color3.fromRGB(88, 88, 100),
	Accent = Color3.fromRGB(122, 162, 255),
	Warn = Color3.fromRGB(226, 176, 96),
	Danger = Color3.fromRGB(226, 96, 96),
}

-- สีตาม Rarity ของเกม (1-7) อ่านจากค่า Rarity ในโมดูลไอเทม
local RarityColor = {
	Color3.fromRGB(150, 150, 158),
	Color3.fromRGB(150, 150, 158),
	Color3.fromRGB(110, 190, 130),
	Color3.fromRGB(100, 155, 235),
	Color3.fromRGB(175, 120, 235),
	Color3.fromRGB(230, 165, 80),
	Color3.fromRGB(235, 95, 95),
}

local Config = {
	Width = 640,
	Height = 448,
	SidebarW = 153,
	TitleH = 46,
	TabH = 34,
	RowH = 34,

	SlideTime = 0.18,
	FadeTime = 0.12,
	ToggleKey = Enum.KeyCode.RightShift,
	UnloadKey = Enum.KeyCode.Delete,

	-- สกุลเงินที่โชว์บนหัวร้าน เลือกเฉพาะที่อาวุธใช้จ่ายจริง
	-- (Silk Thread/RunPoints ใช้เฉพาะสูตรตีบางตัว เลยไม่กินที่หัวจอ)
	WalletShown = { "Wen", "Metal Scraps", "Refinement Ore", "Mythic Refinement Ore" },
	WalletShort = {
		["Wen"] = "Wen",
		["Metal Scraps"] = "Scraps",
		["Refinement Ore"] = "Ore",
		["Mythic Refinement Ore"] = "Mythic",
	},
}

local EASE = TweenInfo.new(Config.SlideTime, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local FAST = TweenInfo.new(Config.FadeTime)

local function font(weight)
	return Font.new("rbxasset://fonts/families/GothamSSm.json", weight)
end

local conns = {}
local function track(conn)
	conns[#conns + 1] = conn
	return conn
end

local function tween(inst, props, info)
	local t = TweenService:Create(inst, info or EASE, props)
	t:Play()
	return t
end

local function new(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	return inst
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function stroke(color, thickness)
	return new("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function comma(n)
	local s = tostring(math.floor(n))
	local k
	repeat
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return s
end

-- ข้อมูลเกม -----------------------------------------------------------------

local Game = {}

-- โมดูลไอเทมมี 57 ตัว require ครั้งเดียวแล้วแคช ไม่งั้นทุกครั้งที่รีเฟรชร้านจะ require ซ้ำ
local itemCache
local function allWeaponItems()
	if itemCache then
		return itemCache
	end
	itemCache = {}
	local items = ReplicatedStorage:FindFirstChild("Items")
	for _, folderName in ipairs({ "Katana", "Weapons" }) do
		local folder = items and items:FindFirstChild(folderName)
		if folder then
			for _, m in ipairs(folder:GetChildren()) do
				if m:IsA("ModuleScript") then
					itemCache[#itemCache + 1] = { name = m.Name, group = folderName, def = require(m) }
				end
			end
		end
	end
	table.sort(itemCache, function(a, b)
		local ra, rb = a.def.Rarity or 0, b.def.Rarity or 0
		if ra ~= rb then
			return ra < rb
		end
		return a.name < b.name
	end)
	return itemCache
end

local shopModule = ReplicatedStorage:FindFirstChild("CAM")
	and ReplicatedStorage.CAM.Global:FindFirstChild("Shop")
local Shop = shopModule and require(shopModule)

local craftModule = ReplicatedStorage:FindFirstChild("CAM")
	and ReplicatedStorage.CAM.Global:FindFirstChild("Crafting")
local Crafting = craftModule and require(craftModule)

local function equippedSlot()
	local data = ReplicatedStorage.Player_Service.Data:FindFirstChild(LocalPlayer.Name)
	if not data then
		return nil
	end
	local idx = data:FindFirstChild("slotEquipped")
	return data.slots:FindFirstChild("Slot" .. tostring(idx and idx.Value or 1))
end

-- คลัง: Inventory.Inventory เป็น Configuration ที่มีโฟลเดอร์ชื่อไอเทมอยู่ข้างใน
-- ตัวที่ stack ได้จะพกจำนวนไว้ในค่า Amount/Quantity/Count ตัวที่ไม่ stack ก็นับโฟลเดอร์ละ 1
-- หมายเหตุ: ยืนยันได้แค่รูปแบบโฟลเดอร์ เพราะทุกคนในเซิร์ฟที่ตรวจตอนเขียนยังคลังว่าง
function Game.wallet()
	local slot = equippedSlot()
	local w = {}
	if not slot then
		return w
	end

	local wen = slot:FindFirstChild("Wen")
	w["Wen"] = wen and wen.Value or 0

	local runPoints = slot:FindFirstChild("RunPoints")
	w["RunPoints"] = runPoints and runPoints.Value or 0

	local invRoot = slot:FindFirstChild("Inventory")
	local bag = invRoot and invRoot:FindFirstChild("Inventory")
	if bag then
		for _, entry in ipairs(bag:GetChildren()) do
			local qty = 1
			for _, key in ipairs({ "Amount", "Quantity", "Count" }) do
				local v = entry:FindFirstChild(key)
				if v and v:IsA("ValueBase") then
					qty = v.Value
					break
				end
			end
			w[entry.Name] = (w[entry.Name] or 0) + qty
		end
	end
	return w
end

-- เลเวลตัวละครไม่มีเก็บเป็นค่าตรง ๆ ใน Player_Service เกมคำนวณจาก Exp เอง
-- ยังหาสูตรไม่เจอ เลยอ่านจาก attribute/HUD ถ้ามี ไม่มีก็คืน nil
-- แล้วให้ฝั่ง UI แสดงเงื่อนไขเลเวลเป็นคำเตือนแทนการล็อก จะได้ไม่โกหกผู้ใช้
function Game.level()
	local char = LocalPlayer.Character
	for _, src in ipairs({ LocalPlayer, char }) do
		if src then
			for _, key in ipairs({ "Level", "level", "PlayerLevel" }) do
				local v = src:GetAttribute(key)
				if type(v) == "number" then
					return v
				end
			end
		end
	end
	return nil
end

function Game.race()
	local slot = equippedSlot()
	local r = slot and slot:FindFirstChild("Race")
	return r and tostring(r.Value) or nil
end

-- แหล่งที่ได้อาวุธมี 2 ทาง: ร้าน NPC (itemsforsale) กับโต๊ะตีของช่าง (Crafting.Definitions)
-- ที่เหลือคือของดรอป/แลกอย่างเดียว ซื้อไม่ได้
local function craftingFor(itemName)
	if not (Crafting and Crafting.Definitions) then
		return nil
	end
	for _, recipe in pairs(Crafting.Definitions) do
		if recipe.result == itemName then
			return recipe
		end
	end
	return nil
end

local function priceParts(price)
	local parts = {}
	for currency, amount in pairs(price or {}) do
		parts[#parts + 1] = { currency = currency, amount = amount }
	end
	table.sort(parts, function(a, b)
		return a.currency < b.currency
	end)
	return parts
end

function Game.listings()
	local wallet = Game.wallet()
	local level = Game.level()
	local race = Game.race()
	local forSale = Shop and Shop.itemsforsale or {}

	local out = {}
	for _, item in ipairs(allWeaponItems()) do
		local def = item.def
		local row = {
			name = item.name,
			group = item.group,
			rarity = def.Rarity or 1,
			icon = def.Icon,
			mastery = def.Mastery,
			cost = {},
			locked = false,
			reason = nil,
			source = nil,
			buyable = false,
		}

		local listing = forSale[item.name]
		local recipe = craftingFor(item.name)

		if listing then
			row.source = "shop"
			row.buyable = true
			row.cost = priceParts(listing.Price)
			if listing.RequiresQuestDone then
				row.locked = true
				row.reason = "ต้องจบเควส: " .. listing.RequiresQuestDone
			end
			if listing.Requirements and listing.Requirements.Level then
				row.reqLevel = listing.Requirements.Level
			end
		elseif recipe then
			row.source = "craft"
			row.station = recipe.station
			for _, p in ipairs(priceParts(recipe.price)) do
				row.cost[#row.cost + 1] = p
			end
			for _, mat in pairs(recipe.required or {}) do
				row.cost[#row.cost + 1] = { currency = mat.name, amount = mat.amount }
			end
			for _, mat in pairs(recipe.additionalMaterials or {}) do
				row.cost[#row.cost + 1] = { currency = mat.name, amount = mat.amount }
			end
			row.locked = true
			row.reason = "ตีที่ช่าง " .. tostring(recipe.station)
		else
			row.locked = true
			row.reason = "ไม่มีขาย (ดรอป/แลกเท่านั้น)"
		end

		-- เงินไม่พอ: เช็กทุกสกุลในราคา ขาดตัวไหนบอกตัวนั้น
		if not row.locked then
			for _, p in ipairs(row.cost) do
				if p.currency == "Product" then
					row.reason = "จ่ายด้วย Robux"
					row.locked = true
					break
				end
				local have = wallet[p.currency] or 0
				if have < p.amount then
					row.locked = true
					row.reason = string.format("ขาด %s %s", comma(p.amount - have), p.currency)
					break
				end
			end
		end

		-- เผ่าเป็นเงื่อนไขสวมใส่ ไม่ใช่เงื่อนไขซื้อ แต่ซื้อมาแล้วใช้ไม่ได้ก็เสียเปล่า
		local raceReq = def.EquipRequirements and def.EquipRequirements.Race
		if raceReq and race then
			local ok = false
			for _, allowed in pairs(raceReq) do
				if allowed == race then
					ok = true
				end
			end
			if not ok then
				row.locked = true
				row.reason = "เผ่าไม่ตรง"
			end
		end

		if row.reqLevel and level and level < row.reqLevel then
			row.locked = true
			row.reason = "ต้องเลเวล " .. row.reqLevel
		elseif row.reqLevel and not level then
			row.note = "ต้องเลเวล " .. row.reqLevel
		end

		out[#out + 1] = row
	end
	return out, wallet
end

local signalModule = ReplicatedStorage:FindFirstChild("Communication")
	and ReplicatedStorage.Communication:FindFirstChild("ServerAndClient")
	and ReplicatedStorage.Communication.ServerAndClient.Signals:FindFirstChild("SignalEvent")
local SignalEvent = signalModule and require(signalModule)

-- Shop.Buy ใช้ไม่ได้จากฝั่งเรา บรรทัดแรกของมันคือ if not RunService:IsServer() then return end
-- เดิมเรียกตัวนั้นแล้วขึ้น "ส่งคำสั่งซื้อแล้ว" ทั้งที่ไม่มีอะไรไปถึงเซิร์ฟเวอร์เลย
-- ทางที่หน้าคุยร้านของเกมใช้จริง (Dialogue.ProceedWithPurchase):
--   Shop.CanBuy(player, ชื่อ, nil, จำนวน) แล้ว SignalEvent.ToServer("PurchaseFromShop", ชื่อ, จำนวน)
-- เซิร์ฟเวอร์ไม่ตอบกลับ เลยยืนยันผลจากเงินที่ลดลงจริงแทน
function Game.buy(row)
	if not (Shop and SignalEvent) then
		return false, "ไม่พบโมดูลร้าน"
	end
	if row.source ~= "shop" then
		return false, "ซื้อผ่านร้านไม่ได้"
	end

	local amount = Shop.SanitizeAmount and Shop.SanitizeAmount(1) or 1
	local canOk, can, why = pcall(Shop.CanBuy, LocalPlayer, row.name, nil, amount)
	if canOk and not can then
		return false, "เกมไม่ให้ซื้อ: " .. tostring(why or "?")
	end

	-- ยิงจากที่ไหนก็ได้เซิร์ฟเวอร์เงียบ (ลองแล้ว Wen ค้าง 1880) ต้องยืนที่แผงขายของชิ้นนั้น
	-- แผงคือ ProximityPrompt "Purchase" ที่ ObjectText = ชื่อของ เช่น Raze's Shop.Regular Katana
	-- แผงโผล่ใน workspace เฉพาะตอน stream ถึง ร้านโซนอื่นที่ยังไม่เคยไปจะหาไม่เจอ
	local stand
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.ObjectText == row.name and d.ActionText == "Purchase" then
			stand = d
			break
		end
	end
	if not stand then
		return false, "หาแผงขาย " .. row.name .. " ไม่เจอ ลองเดินไปโซนร้านนั้นก่อน"
	end
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false, "ไม่พบตัวละคร"
	end
	local standPos = stand.Parent:IsA("BasePart") and stand.Parent.Position or stand.Parent:GetPivot().Position
	local home = hrp.CFrame
	hrp.CFrame = CFrame.lookAt(standPos + Vector3.new(0, 1, 4), standPos)
	task.wait(0.6)

	local before = Game.wallet()
	local sent, err = pcall(SignalEvent.ToServer, "PurchaseFromShop", row.name, amount)
	local bought = false
	if sent then
		local deadline = os.clock() + 4
		while os.clock() < deadline and not bought do
			task.wait(0.25)
			local now = Game.wallet()
			for _, p in ipairs(row.cost) do
				if (now[p.currency] or 0) < (before[p.currency] or 0) then
					bought = true
				end
			end
		end
	end
	hrp.CFrame = home

	if not sent then
		return false, tostring(err)
	end
	if bought then
		return true, "ซื้อแล้ว: " .. row.name
	end
	return false, "ยืนที่แผงแล้วแต่เงินไม่ลด เซิร์ฟเวอร์ไม่รับคำสั่งซื้อ"
end

-- โครงหน้าต่าง --------------------------------------------------------------

local function guiParent()
	if typeof(gethui) == "function" then
		return gethui()
	end
	return CoreGui
end

local screen = new("ScreenGui", {
	Name = "PathSlayer_" .. tostring(math.random(1e6, 9e6)),
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ResetOnSpawn = false,
	DisplayOrder = 9999,
	IgnoreGuiInset = true,
	Parent = guiParent(),
})

local root = new("Frame", {
	Name = "Root",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(Config.Width, Config.Height),
	BackgroundColor3 = Theme.Base,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Parent = screen,
}, { corner(12), stroke() })

local titleBar = new("Frame", {
	Name = "TitleBar",
	Size = UDim2.new(1, 0, 0, Config.TitleH),
	BackgroundTransparency = 1,
	Parent = root,
}, {
	new("TextLabel", {
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(0, 260, 0, Config.TitleH),
		BackgroundTransparency = 1,
		Text = "PathSlayer",
		TextColor3 = Theme.Text,
		TextSize = 15,
		FontFace = font(Enum.FontWeight.SemiBold),
		TextXAlignment = Enum.TextXAlignment.Left,
	}),
	new("TextLabel", {
		Position = UDim2.fromOffset(92, 0),
		Size = UDim2.new(0, 120, 0, Config.TitleH),
		BackgroundTransparency = 1,
		Text = "v0.2 · dev",
		TextColor3 = Theme.Muted,
		TextSize = 12,
		FontFace = font(Enum.FontWeight.Medium),
		TextXAlignment = Enum.TextXAlignment.Left,
	}),
})

new("Frame", {
	Name = "TitleDivider",
	Position = UDim2.fromOffset(0, Config.TitleH - 1),
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = Theme.Stroke,
	BorderSizePixel = 0,
	Parent = root,
})

local function iconButton(glyph, xOffset, hoverColor)
	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, xOffset, 0, Config.TitleH / 2),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Theme.Raised,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = glyph,
		TextColor3 = Theme.Muted,
		TextSize = 15,
		FontFace = font(Enum.FontWeight.Medium),
		Parent = titleBar,
	}, { corner(7) })

	track(btn.MouseEnter:Connect(function()
		tween(btn, { BackgroundTransparency = 0, TextColor3 = hoverColor }, FAST)
	end))
	track(btn.MouseLeave:Connect(function()
		tween(btn, { BackgroundTransparency = 1, TextColor3 = Theme.Muted }, FAST)
	end))
	return btn
end

local closeBtn = iconButton("X", -12, Theme.Danger)
local minBtn = iconButton("-", -44, Theme.Text)

local sidebar = new("Frame", {
	Name = "Sidebar",
	Position = UDim2.fromOffset(0, Config.TitleH),
	Size = UDim2.new(0, Config.SidebarW, 1, -Config.TitleH),
	BackgroundColor3 = Theme.Panel,
	BorderSizePixel = 0,
	Parent = root,
}, {
	new("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}),
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
})

new("Frame", {
	Name = "SidebarDivider",
	Position = UDim2.fromOffset(Config.SidebarW, Config.TitleH),
	Size = UDim2.new(0, 1, 1, -Config.TitleH),
	BackgroundColor3 = Theme.Stroke,
	BorderSizePixel = 0,
	Parent = root,
})

-- แถบ accent อยู่นอก sidebar เพราะ UIListLayout จะจัดตำแหน่งให้ถ้าอยู่ข้างใน
local indicator = new("Frame", {
	Name = "Indicator",
	Position = UDim2.fromOffset(Config.SidebarW - 2, Config.TitleH + 12),
	Size = UDim2.fromOffset(2, Config.TabH),
	BackgroundColor3 = Theme.Accent,
	BorderSizePixel = 0,
	BackgroundTransparency = 1,
	Parent = root,
}, { corner(1) })

local content = new("Frame", {
	Name = "Content",
	Position = UDim2.fromOffset(Config.SidebarW + 1, Config.TitleH),
	Size = UDim2.new(1, -(Config.SidebarW + 1), 1, -Config.TitleH),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	Parent = root,
})

local tabs = {}
local activeTab

-- ประกาศไว้ก่อนเพราะ selectTab ต้องปิดแผงร้านตอนสลับแท็บ แต่แผงถูกสร้างทีหลัง
local closeShopPanel

local function selectTab(tab)
	if activeTab == tab then
		return
	end

	local prev = activeTab
	activeTab = tab

	if prev then
		tween(prev.button, { BackgroundTransparency = 1 }, FAST)
		tween(prev.label, { TextColor3 = Theme.Muted }, FAST)
		-- เลื่อนออกทางตรงข้ามกับหน้าที่เข้ามา ไม่งั้นสองหน้าวิ่งตามกันดูเบลอ
		tween(prev.page, { GroupTransparency = 1, Position = UDim2.fromOffset(-16, 0) })
		task.delay(Config.SlideTime, function()
			if activeTab ~= prev then
				prev.page.Visible = false
			end
		end)
	end

	tween(tab.button, { BackgroundTransparency = 0 }, FAST)
	tween(tab.label, { TextColor3 = Theme.Text }, FAST)

	indicator.BackgroundTransparency = 0
	tween(indicator, {
		Position = UDim2.fromOffset(Config.SidebarW - 2, tab.button.AbsolutePosition.Y - root.AbsolutePosition.Y),
	})

	tab.page.Position = UDim2.fromOffset(16, 0)
	tab.page.GroupTransparency = 1
	tab.page.Visible = true
	tween(tab.page, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })

	if closeShopPanel and tab ~= tabs[1] then
		closeShopPanel()
	end
end

local function addTab(name)
	local label = new("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = Theme.Muted,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.Medium),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, { new("UIPadding", { PaddingLeft = UDim.new(0, 12) }) })

	local button = new("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, Config.TabH),
		BackgroundColor3 = Theme.Raised,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = #tabs + 1,
		Parent = sidebar,
	}, { corner(7), label })

	local page = new("CanvasGroup", {
		Name = name .. "Page",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Parent = content,
	}, {
		new("UIPadding", {
			PaddingTop = UDim.new(0, 16),
			PaddingLeft = UDim.new(0, 18),
			PaddingRight = UDim.new(0, 18),
			PaddingBottom = UDim.new(0, 16),
		}),
	})

	local tab = { name = name, button = button, label = label, page = page }
	tabs[#tabs + 1] = tab

	track(button.MouseButton1Click:Connect(function()
		selectTab(tab)
	end))
	track(button.MouseEnter:Connect(function()
		if activeTab ~= tab then
			tween(label, { TextColor3 = Theme.Text }, FAST)
		end
	end))
	track(button.MouseLeave:Connect(function()
		if activeTab ~= tab then
			tween(label, { TextColor3 = Theme.Muted }, FAST)
		end
	end))

	return tab
end

-- แท็บ Main: ร้านอาวุธ -------------------------------------------------------

local mainTab = addTab("Main")

new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 18),
	BackgroundTransparency = 1,
	Text = "ฟังก์ชัน",
	TextColor3 = Theme.Muted,
	TextSize = 11,
	FontFace = font(Enum.FontWeight.Medium),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = mainTab.page,
})

local featureList = new("Frame", {
	Position = UDim2.fromOffset(0, 26),
	Size = UDim2.new(1, 0, 1, -26),
	BackgroundTransparency = 1,
	Parent = mainTab.page,
}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

local features = {}

-- แถวฟังก์ชันหนึ่งแถว = หนึ่งระบบ ปุ่มขวาสลับ OPEN/CLOSE เอง ไม่ต้องให้ผู้เรียกจัดการ
local function featureRow(name, desc, order, onOpen, onClose)
	local frame = new("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Theme.Row,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = featureList,
	}, { corner(8), stroke(Theme.Stroke, 1) })

	new("TextLabel", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -110, 0, 15),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = Theme.Text,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.Medium),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})

	new("TextLabel", {
		Position = UDim2.fromOffset(14, 24),
		Size = UDim2.new(1, -110, 0, 13),
		BackgroundTransparency = 1,
		Text = desc,
		TextColor3 = Theme.Dim,
		TextSize = 11,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})

	local toggleLabel = new("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "OPEN",
		TextColor3 = Theme.Base,
		TextSize = 11,
		FontFace = font(Enum.FontWeight.SemiBold),
	})

	local toggle = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(72, 26),
		BackgroundColor3 = Theme.Accent,
		AutoButtonColor = false,
		Text = "",
		Parent = frame,
	}, { corner(6), toggleLabel })

	local entry = {}
	local open = false

	function entry.setOpen(state)
		if open == state then
			return
		end
		open = state
		toggleLabel.Text = open and "CLOSE" or "OPEN"
		tween(toggle, { BackgroundColor3 = open and Theme.Raised or Theme.Accent }, FAST)
		tween(toggleLabel, { TextColor3 = open and Theme.Text or Theme.Base }, FAST)
		if open then
			-- เปิดได้ทีละแผง ไม่งั้นสองแผงซ้อนกันแล้วคลิกโดนอันล่าง
			for _, other in ipairs(features) do
				if other ~= entry then
					other.setOpen(false)
				end
			end
			onOpen()
		else
			onClose()
		end
	end

	track(toggle.MouseButton1Click:Connect(function()
		entry.setOpen(not open)
	end))

	features[#features + 1] = entry
	return entry
end

-- แผงเนื้อหา: วางทับ content ไม่ใช่ในหน้า Main เพราะรายการยาวกว่าที่หน้าจะรับไหว
-- เคยลองยัดลงหน้า Main ตรง ๆ แล้ว list กับแถบสถานะซ้อนกันเพราะพื้นที่เหลือ 200px
-- เลข -170/-136 = 114 (ของบนหัว) + ปุ่มท้าย 34 ถ้ามี + แถบสถานะ 14 + ช่องไฟ 8
local function makePanel(title, hasFooter)
	local panel = new("CanvasGroup", {
		Name = title:gsub("%s", "") .. "Panel",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Theme.Base,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
		Parent = content,
	}, {
		new("UIPadding", {
			PaddingTop = UDim.new(0, 16),
			PaddingLeft = UDim.new(0, 18),
			PaddingRight = UDim.new(0, 18),
			PaddingBottom = UDim.new(0, 16),
		}),
	})

	new("TextLabel", {
		Size = UDim2.new(1, -30, 0, 18),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Theme.Text,
		TextSize = 14,
		FontFace = font(Enum.FontWeight.SemiBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})

	local closeBtn2 = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = Theme.Raised,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "X",
		TextColor3 = Theme.Muted,
		TextSize = 12,
		FontFace = font(Enum.FontWeight.Medium),
		Parent = panel,
	}, { corner(6) })

	track(closeBtn2.MouseEnter:Connect(function()
		tween(closeBtn2, { BackgroundTransparency = 0, TextColor3 = Theme.Text }, FAST)
	end))
	track(closeBtn2.MouseLeave:Connect(function()
		tween(closeBtn2, { BackgroundTransparency = 1, TextColor3 = Theme.Muted }, FAST)
	end))

	local subtitle = new("TextLabel", {
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.Muted,
		TextSize = 11,
		FontFace = font(Enum.FontWeight.Medium),
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
		Parent = panel,
	})

	local search = new("TextBox", {
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = Theme.Raised,
		BorderSizePixel = 0,
		Text = "",
		PlaceholderText = "ค้นหา…",
		PlaceholderColor3 = Theme.Dim,
		TextColor3 = Theme.Text,
		TextSize = 12,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = panel,
	}, { corner(7), new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })

	local filterRow = new("Frame", {
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) })

	local list = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 114),
		Size = UDim2.new(1, 0, 1, hasFooter and -170 or -136),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = panel,
	}, { new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local status = new("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, hasFooter and -38 or 0),
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.Muted,
		TextSize = 11,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})

	local self = {
		panel = panel,
		subtitle = subtitle,
		search = search,
		filterRow = filterRow,
		list = list,
		closeButton = closeBtn2,
	}

	function self.setStatus(text, color)
		status.Text = text or ""
		status.TextColor3 = color or Theme.Muted
	end

	function self.show()
		panel.Position = UDim2.fromOffset(0, 14)
		panel.GroupTransparency = 1
		panel.Visible = true
		tween(panel, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
	end

	function self.hide()
		if not panel.Visible then
			return
		end
		tween(panel, { GroupTransparency = 1, Position = UDim2.fromOffset(0, 14) })
		task.delay(Config.SlideTime, function()
			if panel.GroupTransparency >= 1 then
				panel.Visible = false
			end
		end)
	end

	return self
end

local function addPills(container, names, onChange)
	local current = names[1]
	local buttons = {}
	for _, name in ipairs(names) do
		local label = new("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = name == current and Theme.Text or Theme.Muted,
			TextSize = 11,
			FontFace = font(Enum.FontWeight.Medium),
		})
		local pill = new("TextButton", {
			Size = UDim2.fromOffset(#name * 7 + 22, 24),
			BackgroundColor3 = Theme.Raised,
			BackgroundTransparency = name == current and 0 or 1,
			AutoButtonColor = false,
			Text = "",
			Parent = container,
		}, { corner(6), stroke(Theme.Stroke, 1), label })
		buttons[#buttons + 1] = { pill = pill, label = label, name = name }

		track(pill.MouseButton1Click:Connect(function()
			current = name
			for _, b in ipairs(buttons) do
				local on = b.name == name
				tween(b.pill, { BackgroundTransparency = on and 0 or 1 }, FAST)
				tween(b.label, { TextColor3 = on and Theme.Text or Theme.Muted }, FAST)
			end
			onChange(name)
		end))
	end
end

-- ร้านอาวุธ -----------------------------------------------------------------

local shopUI = makePanel("Buy Weapons", true)
shopUI.search.PlaceholderText = "ค้นหาอาวุธ…"

local buyLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Text = "BUY",
	TextColor3 = Theme.Dim,
	TextSize = 13,
	FontFace = font(Enum.FontWeight.SemiBold),
})

local buyBtn = new("TextButton", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = Theme.Raised,
	AutoButtonColor = false,
	Text = "",
	Parent = shopUI.panel,
}, { corner(8), buyLabel })

local shopFilter = "All"
local shopSelected
local shopRows = {}

local function refreshBuyButton()
	local enabled = shopSelected ~= nil and not shopSelected.locked and shopSelected.buyable
	buyLabel.Text = shopSelected and ("BUY  ·  " .. shopSelected.name) or "BUY"
	tween(buyBtn, { BackgroundColor3 = enabled and Theme.Accent or Theme.Raised }, FAST)
	tween(buyLabel, { TextColor3 = enabled and Theme.Base or Theme.Dim }, FAST)
end

-- กดซ้ำแถวเดิม = ยกเลิกการเลือก ไม่ต้องมีปุ่ม Cancel แยก
local function selectShopRow(row)
	if row.data.locked then
		return
	end
	local target = shopSelected ~= row.data and row or nil
	for _, r in ipairs(shopRows) do
		local on = r == target
		tween(r.tickFill, { BackgroundTransparency = on and 0 or 1 }, FAST)
		-- แถวที่เพิ่งยกเลิกยังมีเมาส์ค้างอยู่ ให้อยู่สถานะ hover ไม่ใช่ปกติ
		tween(r.frame, { BackgroundColor3 = (on or r == row) and Theme.Raised or Theme.Row }, FAST)
		r.tickStroke.Color = on and Theme.Accent or Theme.Stroke
	end
	shopSelected = target and row.data or nil
	refreshBuyButton()
end

-- กล่องติ๊กซ้ายสุด คืน fill กับ stroke ให้ผู้เรียกเปลี่ยนสีตอนเลือก
local function tickBox(parent)
	local fill = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, { corner(2) })
	local outline = stroke(Theme.Stroke, 1)
	new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { corner(4), outline, fill })
	return fill, outline
end

local function buildShopRow(data, order)
	local frame = new("Frame", {
		Size = UDim2.new(1, -6, 0, Config.RowH),
		BackgroundColor3 = Theme.Row,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = shopUI.list,
	}, { corner(7) })

	local tickFill, tickStroke = tickBox(frame)

	new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 32, 0.5, 0),
		Size = UDim2.fromOffset(3, 14),
		BackgroundColor3 = RarityColor[data.rarity] or Theme.Muted,
		BackgroundTransparency = data.locked and 0.6 or 0,
		BorderSizePixel = 0,
		Parent = frame,
	}, { corner(2) })

	new("TextLabel", {
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(0.5, -44, 1, 0),
		BackgroundTransparency = 1,
		Text = data.name,
		TextColor3 = data.locked and Theme.Dim or Theme.Text,
		TextSize = 12,
		FontFace = font(Enum.FontWeight.Medium),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})

	local costText = {}
	for _, p in ipairs(data.cost) do
		costText[#costText + 1] = comma(p.amount) .. " " .. p.currency
	end
	local right = data.locked and (data.reason or "ล็อก") or table.concat(costText, " + ")
	if #right == 0 then
		right = "-"
	end

	new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0.5, -12, 1, 0),
		BackgroundTransparency = 1,
		Text = right .. (data.note and ("  ·  " .. data.note) or ""),
		TextColor3 = data.locked and Theme.Dim or Theme.Accent,
		TextSize = 11,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})

	local row = { frame = frame, tickFill = tickFill, tickStroke = tickStroke, data = data }

	local hit = new("TextButton", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		Parent = frame,
	})
	track(hit.MouseButton1Click:Connect(function()
		selectShopRow(row)
	end))
	track(hit.MouseEnter:Connect(function()
		if not data.locked and shopSelected ~= data then
			tween(frame, { BackgroundColor3 = Theme.Raised }, FAST)
		end
	end))
	track(hit.MouseLeave:Connect(function()
		if shopSelected ~= data then
			tween(frame, { BackgroundColor3 = Theme.Row }, FAST)
		end
	end))

	return row
end

local function applyShopFilter()
	local query = shopUI.search.Text:lower()
	local shown = 0
	for _, r in ipairs(shopRows) do
		local d = r.data
		local okGroup = shopFilter == "All" or d.group == shopFilter
		local okText = query == "" or d.name:lower():find(query, 1, true) ~= nil
		r.frame.Visible = okGroup and okText
		if r.frame.Visible then
			shown += 1
		end
	end
	if shown == 0 then
		shopUI.setStatus("ไม่พบอาวุธที่ตรงกับคำค้น", Theme.Muted)
	end
end

local function rebuildShop()
	for _, r in ipairs(shopRows) do
		r.frame:Destroy()
	end
	table.clear(shopRows)
	shopSelected = nil

	local listings, wallet = Game.listings()
	for i, data in ipairs(listings) do
		shopRows[#shopRows + 1] = buildShopRow(data, i)
	end

	local parts = {}
	for _, currency in ipairs(Config.WalletShown) do
		parts[#parts + 1] = string.format(
			'<font color="#8f8f9e">%s</font> %s',
			Config.WalletShort[currency],
			comma(wallet[currency] or 0)
		)
	end
	shopUI.subtitle.Text = table.concat(parts, "   ")

	applyShopFilter()
	refreshBuyButton()

	local sellable = 0
	for _, d in ipairs(listings) do
		if not d.locked then
			sellable += 1
		end
	end
	shopUI.setStatus(string.format("อาวุธทั้งหมด %d · ซื้อได้ตอนนี้ %d", #listings, sellable), Theme.Muted)
end

addPills(shopUI.filterRow, { "All", "Katana", "Weapons" }, function(name)
	shopFilter = name
	applyShopFilter()
end)

track(shopUI.search:GetPropertyChangedSignal("Text"):Connect(applyShopFilter))

-- Game.buy รอดูเงินลดได้ถึง 4 วิ กดซ้ำระหว่างนั้นจะส่งคำสั่งซื้อซ้อน
local buying = false
track(buyBtn.MouseButton1Click:Connect(function()
	if buying or not shopSelected or shopSelected.locked or not shopSelected.buyable then
		return
	end
	buying = true
	shopUI.setStatus("กำลังซื้อ " .. shopSelected.name .. "…", Theme.Muted)
	-- แยก thread เพราะ Game.buy รอเงินลด ถ้า handler ถูกเรียกแบบห้าม yield
	-- (getconnections():Fire() ของ executor) จะพังด้วย "thread is not yieldable"
	local target = shopSelected
	task.spawn(function()
		local ok, msg = Game.buy(target)
		buying = false
		shopUI.setStatus(msg, ok and Theme.Accent or Theme.Danger)
		if ok then
			task.delay(0.6, rebuildShop)
		end
	end)
end))

-- เควส ----------------------------------------------------------------------

-- เควสอยู่ที่ Ouwland.Content.<โซน>.NpcContents.Dialogues.Quests.<โมดูล NPC>
-- โมดูลหนึ่งตัวถือได้หลายเควส เช่น Krue มีทั้งเควสแรกกับเควสบอสที่ Lv 7
local questCache
function Game.quests()
	if questCache then
		return questCache
	end

	local content = ReplicatedStorage.Ouwland.Content
	local out = {}

	for _, region in ipairs(content:GetChildren()) do
		local dialogues = region:FindFirstChild("NpcContents")
		dialogues = dialogues and dialogues:FindFirstChild("Dialogues")
		local questFolder = dialogues and dialogues:FindFirstChild("Quests")
		if questFolder then
			for _, m in ipairs(questFolder:GetChildren()) do
				if m:IsA("ModuleScript") then
					local def = require(m)
					for questName, q in pairs(def) do
						local req = q.Requirements or {}

						-- เควสส่วนใหญ่ใส่เลเวลไว้ในชื่อด้วย เช่น "Ill take the bandit boss(Lv 7)"
						-- ใช้เป็นตัวสำรองตอน Requirements.Level ว่าง จะได้ไม่เรียงผิด
						local level = req.Level
						if not level then
							local fromName = questName:match("%(Lv (%d+)%)")
							level = fromName and tonumber(fromName) or nil
						end

						local kind = "เควส NPC"
						if m.Name == "Boss Hunts" then
							kind = "บอส"
						elseif q.OfferNpc == false or m.Name:find("Trainer") or m.Name:find("Expert")
							or m.Name == "Evil Art Cores" or m.Name:find("Harvester") then
							kind = "ฝึกวิชา"
						end

						local races
						if req.Race then
							local t = {}
							for _, r in pairs(req.Race) do
								t[#t + 1] = r
							end
							table.sort(t)
							races = table.concat(t, "/")
						end

						-- QuestInstance เป็น Instance จริง ๆ ไม่ใช่สตริง ชื่อเควสที่คนเห็นอยู่ใน .Name
						local instance = q.QuestInstance
						local title = typeof(instance) == "Instance" and instance.Name
							or (type(instance) == "string" and instance)
							or questName

						-- Tasks.<ชื่อ>.Code คือ NpcCode ของม็อบที่ต้องฆ่า (Krue: KaruVillageBandit x3)
						-- งานที่ไม่ใช่การฆ่า Code เป็นข้อความ เช่น "Speak with Noote" จับคู่ม็อบไม่ได้เอง
						local tasks = {}
						local taskFolder = typeof(instance) == "Instance" and instance:FindFirstChild("Tasks")
						for _, t in ipairs(taskFolder and taskFolder:GetChildren() or {}) do
							local code, max = t:FindFirstChild("Code"), t:FindFirstChild("Max")
							tasks[#tasks + 1] = {
								name = t.Name,
								code = code and code.Value,
								max = max and max.Value or 1,
							}
						end

						out[#out + 1] = {
							region = region.Name,
							npc = q.OfferNpc or m.Name,
							-- OfferNpc = false คือเควสที่ไม่ได้รับจากการคุย (Boss Hunts, Evil Art Cores)
							offerNpc = type(q.OfferNpc) == "string" and q.OfferNpc or nil,
							tasks = tasks,
							quest = questName:gsub("%(Lv %d+%)", ""),
							-- ชื่อดิบพร้อม "(Lv N)" คือคีย์ที่เกมใช้บันทึกว่าทำจบแล้ว
							key = questName,
							title = title,
							level = level,
							kind = kind,
							race = races,
							exp = q.Rewards and q.Rewards.Exp or 0,
						}
					end
				end
			end
		end
	end

	-- 17 จาก 83 เควสไม่มี Requirements.Level เลย เรียงตรง ๆ แล้วมันไปกองรวมกันหัวสุด
	-- ทั้งที่ Evil Art Cores กับ Muzan ไม่ใช่ของเลเวล 1 ใช้เลเวลต่ำสุดของโซนนั้นแทน
	-- โซนบอกลำดับได้จริง: Windy Peak 7, Bamboo Grove 10, Mistfall 45, Hidden Mist 65
	local regionMin = {}
	for _, q in ipairs(out) do
		if q.level and (not regionMin[q.region] or q.level < regionMin[q.region]) then
			regionMin[q.region] = q.level
		end
	end

	local firstRegionLevel = math.huge
	for _, lvl in pairs(regionMin) do
		firstRegionLevel = math.min(firstRegionLevel, lvl)
	end

	for _, q in ipairs(out) do
		q.sortLevel = q.level or regionMin[q.region] or 0
		-- เควสเปิดเกมจริง ๆ อยู่ในโซนที่เลเวลต่ำสุด ที่เหลือเป็นการเดาจากโซน บอกให้รู้ด้วย
		q.estimated = q.level == nil and q.sortLevel > firstRegionLevel
	end

	table.sort(out, function(a, b)
		if a.sortLevel ~= b.sortLevel then
			return a.sortLevel < b.sortLevel
		end
		-- ในชั้นเลเวลเดียวกัน เควสที่ไม่ระบุเลเวลคือเควสเปิดโซน ให้มาก่อน
		if (a.level == nil) ~= (b.level == nil) then
			return a.level == nil
		end
		if a.exp ~= b.exp then
			return a.exp < b.exp
		end
		return a.quest < b.quest
	end)

	questCache = out
	return out
end

local questUI = makePanel("Auto-Quest", true)
questUI.search.PlaceholderText = "ค้นหา NPC หรือเควส…"

local questFilter = "All"
-- รายการเควสที่ติ๊กไว้ในแถวที่เลือก เรียงเลเวลสูงไปต่ำ (บอสก่อน แล้วค่อยลูกกระจ๊อก)
local questSelected
local questSelectedRow
local questRows = {}

-- ชิปที่ติ๊กไว้ของแถว เรียงเลเวลมากไปน้อย ผู้ใช้อยากให้เคลียร์บอสก่อนเสมอ
local function pickedQuests(row)
	local list = {}
	for i, d in ipairs(row.group) do
		if row.picked[i] then
			list[#list + 1] = d
		end
	end
	-- ใช้ sortLevel อย่างเดียวไม่ได้ เควสโจร 3 ตัวไม่มีเลเวล เลยได้ค่าต่ำสุดของโซน (7)
	-- เท่ากับบอส Lv 7 พอดี ผลคือโจรมาก่อนบอส ใช้เลเวลจริงก่อน แล้วค่อย Exp ตัดสิน
	table.sort(list, function(a, b)
		local la, lb = a.level or 0, b.level or 0
		if la ~= lb then
			return la > lb
		end
		return a.exp > b.exp
	end)
	return list
end

local applyQuestFilter
-- ตัวรันเควสนิยามอยู่ล่างกว่า แต่ชิปตัวเลือกต้องเช็กว่ากำลังรันอยู่ไหม
local Runner
local refreshStartButton

-- force = true ใช้ตอนกดชิปตัวเลือก ต้องเลือกแถวนั้นเสมอ ไม่ใช่สลับเปิด/ปิดแบบคลิกแถว
local function selectQuestRow(row, force)
	local target = (force or questSelectedRow ~= row) and row or nil
	if target and #pickedQuests(target) == 0 then
		target = nil
	end
	for _, r in ipairs(questRows) do
		local on = r == target
		tween(r.tickFill, { BackgroundTransparency = on and 0 or 1 }, FAST)
		tween(r.frame, { BackgroundColor3 = (on or r == row) and Theme.Raised or Theme.Row }, FAST)
		r.tickStroke.Color = on and Theme.Accent or Theme.Stroke
	end
	questSelectedRow = target
	questSelected = target and pickedQuests(target) or nil

	if questSelected then
		local titles = {}
		for _, d in ipairs(questSelected) do
			titles[#titles + 1] = d.title
		end
		questUI.setStatus(string.format("เลือก: %s · %s", row.group[1].npc, table.concat(titles, " → ")), Theme.Muted)
	else
		applyQuestFilter()
	end
	refreshStartButton()
end

local function levelText(data)
	return data.level and ("Lv " .. data.level)
		or (data.estimated and ("~Lv " .. data.sortLevel) or "เริ่มต้น")
end

-- แถวหนึ่ง = NPC หนึ่งตัว ถ้า NPC ให้เควสหลายอัน (Krue: โจร 3 ตัว / บอสโจร Lv 7)
-- จะมีชิปให้เลือกคำตอบเหมือนในหน้าคุยของเกม แทนที่จะแยกเป็นสองแถวห่างกันคนละที่
local function buildQuestRow(group, order)
	local multi = #group > 1
	local frame = new("Frame", {
		Size = UDim2.new(1, -6, 0, multi and 64 or 40),
		BackgroundColor3 = Theme.Row,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = questUI.list,
	}, { corner(7) })

	local tickFill, tickStroke = tickBox(frame)
	if multi then
		-- tickBox จัดกลางแนวตั้ง แถวสูงขึ้นแล้วให้อยู่ระดับชื่อ NPC แทน
		tickFill.Parent.AnchorPoint = Vector2.new(0, 0)
		tickFill.Parent.Position = UDim2.fromOffset(10, 12)
	end

	new("TextLabel", {
		Position = UDim2.fromOffset(34, 5),
		Size = UDim2.new(1, -110, 0, 14),
		BackgroundTransparency = 1,
		Text = group[1].npc,
		TextColor3 = Theme.Text,
		TextSize = 12,
		FontFace = font(Enum.FontWeight.Medium),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})

	local subtitle = new("TextLabel", {
		Position = UDim2.fromOffset(34, 20),
		Size = UDim2.new(1, -110, 0, 13),
		BackgroundTransparency = 1,
		TextColor3 = Theme.Dim,
		TextSize = 11,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})

	local levelLabel = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, multi and 12 or 13),
		Size = UDim2.fromOffset(84, 14),
		BackgroundTransparency = 1,
		TextSize = 11,
		FontFace = font(Enum.FontWeight.Medium),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	})

	local row = {
		frame = frame,
		tickFill = tickFill,
		tickStroke = tickStroke,
		group = group,
		-- ติ๊กได้หลายชิป ค่าเริ่มคือเควสแรกของ NPC (เลเวลต่ำสุด)
		picked = { [1] = true },
		data = group[1],
		chips = {},
	}

	local function paint()
		local list = pickedQuests(row)
		local d = list[1] or group[1]
		row.data = d
		local titles = {}
		for _, q in ipairs(list) do
			titles[#titles + 1] = q.title
		end
		subtitle.Text = (#titles > 0 and table.concat(titles, " → ") or d.title) .. "  ·  " .. d.region
		levelLabel.Text = levelText(d)
		levelLabel.TextColor3 = d.level and Theme.Accent or Theme.Warn
		for i, c in ipairs(row.chips) do
			local on = row.picked[i] == true
			tween(c.btn, { BackgroundTransparency = on and 0 or 1 }, FAST)
			tween(c.label, { TextColor3 = on and Theme.Text or Theme.Muted }, FAST)
		end
	end

	local hit = new("TextButton", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		Parent = frame,
	})
	track(hit.MouseButton1Click:Connect(function()
		selectQuestRow(row)
	end))
	track(hit.MouseEnter:Connect(function()
		if questSelectedRow ~= row then
			tween(frame, { BackgroundColor3 = Theme.Raised }, FAST)
		end
	end))
	track(hit.MouseLeave:Connect(function()
		if questSelectedRow ~= row then
			tween(frame, { BackgroundColor3 = Theme.Row }, FAST)
		end
	end))

	if multi then
		-- วางหลัง hit และ ZIndex สูงกว่า ไม่งั้นคลิกชิปแล้วไปโดนปุ่มทั้งแถวแทน
		local chipRow = new("Frame", {
			Position = UDim2.fromOffset(34, 38),
			Size = UDim2.new(1, -46, 0, 20),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = 2,
			Parent = frame,
		}, { new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}) })

		for i, d in ipairs(group) do
			local text = d.quest .. (d.level and ("  Lv " .. d.level) or "")
			local label = new("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = text,
				TextColor3 = Theme.Muted,
				TextSize = 10,
				FontFace = font(Enum.FontWeight.Medium),
				ZIndex = 3,
			})
			local btn = new("TextButton", {
				Size = UDim2.fromOffset(#text * 6 + 16, 20),
				BackgroundColor3 = Theme.Base,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = i,
				ZIndex = 3,
				Parent = chipRow,
			}, { corner(5), stroke(Theme.Stroke, 1), label })
			row.chips[i] = { btn = btn, label = label }

			track(btn.MouseButton1Click:Connect(function()
				-- เปลี่ยนตัวเลือกระหว่างที่กำลังรันไม่ได้ Runner ถือรายการของรอบนี้อยู่
				if Runner.active then
					return
				end
				-- กดสลับติ๊ก ถ้าเอาออกจนไม่เหลือสักอันแถวนี้จะหลุดจากการเลือกเอง
				row.picked[i] = not row.picked[i] or nil
				paint()
				selectQuestRow(row, true)
			end))
		end
	end

	paint()
	return row
end

function applyQuestFilter()
	local query = questUI.search.Text:lower()
	local shown = 0
	for _, r in ipairs(questRows) do
		local visible = false
		for _, d in ipairs(r.group) do
			local okKind = questFilter == "All" or d.kind == questFilter
			local okText = query == ""
				or d.npc:lower():find(query, 1, true) ~= nil
				or d.title:lower():find(query, 1, true) ~= nil
				or d.region:lower():find(query, 1, true) ~= nil
			if okKind and okText then
				visible = true
				shown += 1
			end
		end
		r.frame.Visible = visible
	end
	questUI.setStatus(string.format("แสดง %d เควส · เรียงจากเลเวลต่ำไปสูง", shown), Theme.Muted)
end

-- จับกลุ่มตาม NPC ที่ให้เควสจากการคุยเท่านั้น
-- Boss Hunts (30 เควส) กับ Evil Art Cores (9) ไม่มีคนให้ ถ้ารวมจะได้ชิปยาวเป็นพืด
-- ลำดับกลุ่มยึดเควสที่เลเวลต่ำสุดของ NPC นั้น (Game.quests เรียงมาแล้ว)
local function questGroups()
	local groups, byNpc = {}, {}
	for _, d in ipairs(Game.quests()) do
		local key = d.offerNpc and (d.region .. "/" .. d.offerNpc)
		if key and byNpc[key] then
			table.insert(byNpc[key], d)
		else
			local g = { d }
			groups[#groups + 1] = g
			if key then
				byNpc[key] = g
			end
		end
	end
	return groups
end

local function rebuildQuests()
	if #questRows > 0 then
		applyQuestFilter()
		return
	end
	for i, group in ipairs(questGroups()) do
		questRows[#questRows + 1] = buildQuestRow(group, i)
	end
	local npcs = {}
	local count = 0
	for _, d in ipairs(Game.quests()) do
		if not npcs[d.npc] then
			npcs[d.npc] = true
			count += 1
		end
	end
	questUI.subtitle.Text = string.format(
		'<font color="#8f8f9e">NPC</font> %d   <font color="#8f8f9e">เควส</font> %d',
		count,
		#Game.quests()
	)
	applyQuestFilter()
end

addPills(questUI.filterRow, { "All", "เควส NPC", "บอส", "ฝึกวิชา" }, function(name)
	questFilter = name
	applyQuestFilter()
end)

track(questUI.search:GetPropertyChangedSignal("Text"):Connect(applyQuestFilter))

-- ตัวรันเควสอัตโนมัติ ---------------------------------------------------------

-- ขั้นตอนหนึ่งขั้น = ไปหา NPC หนึ่งตัว แล้วเดินบทสนทนาจนกดคำตอบที่ต้องการ
-- ชื่อคำตอบเอามาจาก Dialogue.Diagloues ของเกมตรง ๆ (MoldySugar_4 / Elara_Delivery)
local QuestScripts = {
	["Deliver Package to Elara"] = {
		{ npc = "MoldySugar", answer = "Ill deliver the package" },
		{ npc = "Elara", answer = "Hand over the package" },
	},
	["Deliver the Coded Letter"] = {
		{ npc = "Noote", answer = "Ill get this letter delivered" },
		{ npc = "Chaka", answer = "Hand over the letter" },
	},
}

-- เควสฆ่าม็อบไม่ต้องเขียนมือ: รับจาก OfferNpc ด้วยคำตอบที่เป็นชื่อเควส แล้วไล่ฆ่าตาม Tasks
-- ใช้ได้เฉพาะเมื่อ Code ทุกตัวตรงกับ NpcCode ของม็อบจริง ถ้ามีงานอื่นปน (วิดพื้น ตกปลา
-- เก็บของ) ถือว่ายังไม่รองรับ ตอนเขียนเข้าเงื่อนไข 14 เควส เช่น Krue, Kazu, Tom, Chaka
-- ไม่มีขั้นกลับไปส่ง: เควสที่ต้องกลับไปหา NPC เกมใส่เป็น task แยก ("Return to Ginzo")
-- ปุ่ม START เรียกทุกวินาที Game.mobs() กวาด workspace ทุกครั้ง เลยทำแผนที่ไว้ครั้งเดียว
local mobByCode
local function questPlan(data)
	if QuestScripts[data.title] then
		return QuestScripts[data.title]
	end
	if not data.offerNpc or #data.tasks == 0 then
		return nil
	end

	if not mobByCode then
		mobByCode = {}
		for _, mob in ipairs(Game.mobs()) do
			if mob.code then
				mobByCode[mob.code] = mob
			end
		end
	end
	local byCode = mobByCode

	-- ตัดวงเล็บเลเวลออก ปุ่มในเกมอาจโชว์หรือไม่โชว์ "(Lv 7)" ก็ได้ ส่วนที่เหลือจับเจอทั้งสองแบบ
	local steps = { { npc = data.offerNpc, answer = data.quest } }
	for _, t in ipairs(data.tasks) do
		local mob = t.code and byCode[t.code]
		if not mob then
			return nil
		end
		steps[#steps + 1] = { hunt = mob.name, center = mob.center, task = t.name, max = t.max }
	end
	return steps
end

local QuestRules = require(ReplicatedStorage.CAM.Global.Subsets.Gameplay.Quests)

-- Spawns เก็บเป็นสตริง CFrame 12 ตัว เอาแค่ 3 ตัวแรกที่เป็นตำแหน่ง
local function parseSpawn(str)
	local nums = {}
	for n in tostring(str):gmatch("%-?%d+%.?%d*") do
		nums[#nums + 1] = tonumber(n)
		if #nums == 3 then
			return Vector3.new(nums[1], nums[2], nums[3])
		end
	end
	return nil
end

local spawnCache
local function npcSpawnPoint(name)
	if not spawnCache then
		spawnCache = {}
		for _, region in ipairs(ReplicatedStorage.Ouwland.Content:GetChildren()) do
			local npcs = region:FindFirstChild("Npcs")
			for _, m in ipairs(npcs and npcs:GetChildren() or {}) do
				if m:IsA("ModuleScript") then
					local def = require(m)
					local pos = def.Spawns and parseSpawn(def.Spawns[1])
					if pos then
						spawnCache[def.Name or m.Name] = { pos = pos, region = region.Name }
					end
				end
			end
		end
	end
	return spawnCache[name]
end

-- NPC โผล่ใน workspace เฉพาะตอน stream ถึง ต้องวาร์ปไปก่อนแล้วค่อยหา
local function findLiveNpc(name)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d.Name == name and d:FindFirstChildWhichIsA("ProximityPrompt", true) then
			return d
		end
	end
	return nil
end

local function questFolder()
	local slot = equippedSlot()
	return slot and slot:FindFirstChild("Quests") or nil
end

-- เกมให้รับเควสใหม่ได้ทุก QuestCD วินาที (อ่านจากโมดูลเกม ตอนเขียนคือ 30)
-- LastTime อยู่ในโดเมนเวลาเซิร์ฟเวอร์ ถ้าเทียบด้วย os.time() จะเพี้ยนตามนาฬิกาเครื่อง
local function questCooldown()
	local quests = questFolder()
	local last = quests and quests:FindFirstChild("LastTime")
	if not last then
		return 0
	end
	return math.max(0, (QuestRules.QuestCD or 30) - (workspace:GetServerTimeNow() - last.Value))
end

-- เควสที่จบแล้วถูกบันทึกด้วย "ชื่อคำตอบ" ไม่ใช่ชื่อ QuestInstance
-- เช่น "Ill deliver the package" ไม่ใช่ "Deliver Package to Elara"
local function questProgress(questKey)
	local quests = questFolder()
	if not quests then
		return "unknown"
	end
	local done = quests:FindFirstChild("Completed")
	if questKey and done and done:FindFirstChild(questKey) then
		return "completed"
	end
	local holder = quests:FindFirstChild("Holder")
	if holder and #holder:GetChildren() > 0 then
		return "busy"
	end
	return "available"
end

-- ตัวนับของเควสที่ถืออยู่: Holder.<เควส>...Tasks.<ชื่องาน>.Value (IntValue ลูก)
-- คืน nil ถ้าไม่มีเควสนี้ใน Holder แล้ว (จบ หรือโดนลบ)
local function taskProgress(taskName)
	local quests = questFolder()
	local holder = quests and quests:FindFirstChild("Holder")
	for _, d in ipairs(holder and holder:GetDescendants() or {}) do
		if d.Name == taskName then
			local v = d:FindFirstChild("Value")
			if v and v:IsA("ValueBase") then
				return v.Value
			end
		end
	end
	return nil
end

local function clockText(seconds)
	seconds = math.ceil(seconds)
	if seconds >= 60 then
		return string.format("%d:%02d นาที", seconds // 60, seconds % 60)
	end
	return seconds .. " วิ"
end

-- DialogueFrame.Actual ถูกสร้างใหม่ทุกครั้งที่เปิดคุย และโดนลบทันทีที่ปิด
-- เคยอ้าง frame.Actual ตรง ๆ แล้วพังกลางทางด้วย "Actual is not a valid member"
local function dialogueActual()
	local holder = LocalPlayer.PlayerGui:FindFirstChild("ComponentsHolder")
	local frame = holder and holder:FindFirstChild("DialogueFrame")
	if not (frame and frame.Visible) then
		return nil
	end
	return frame:FindFirstChild("Actual")
end

-- ปุ่มคำตอบไม่ได้เป็น GuiButton ลูกตรงของ ButtonHolder แต่เป็น Frame ชื่อตามคำตอบ
-- ที่ข้างในมี TextButton อีกที เคยอ่านแค่ลูกตรงแล้วได้ 0 ตัวทุกครั้ง
local function dialogueOptions(actual)
	local holder = actual:FindFirstChild("ButtonHolder")
	local list = {}
	for _, entry in ipairs(holder and holder:GetChildren() or {}) do
		if entry:IsA("GuiObject") then
			local btn, text
			for _, d in ipairs(entry:GetDescendants()) do
				if d:IsA("TextButton") then
					btn = d
				end
				if d:IsA("TextLabel") and d.Text ~= "" then
					text = d.Text
				end
			end
			if btn then
				list[#list + 1] = { text = text or entry.Name, button = btn }
			end
		end
	end
	return list
end

local function dialogueText(actual)
	local tp = actual:FindFirstChild("DialogueHolder")
	tp = tp and tp:FindFirstChild("TextPlusTextHolder")
	local words = {}
	for _, d in ipairs(tp and tp:GetChildren() or {}) do
		if d:IsA("TextLabel") then
			words[#words + 1] = d.Text
		end
	end
	return table.concat(words, "")
end

local function clickGui(btn)
	for _, c in ipairs(getconnections(btn.MouseButton1Click)) do
		c:Fire()
	end
end

Runner = { active = false, cancel = false, lastStart = 0, hasAlternative = false }
-- ค่าที่ Runner.hunt คืนเมื่อยกเลิกเควสบอสเพราะบอสตาย ไม่ใช่ความผิดพลาด ไม่ต้องตัดเควสออก
Runner.BOSS_GONE = "boss-gone"

local function report(text, color)
	questUI.setStatus(text, color or Theme.Muted)
end

-- คืน true เมื่อกดคำตอบเป้าหมายไปแล้ว
local function walkDialogue(answer, deadline)
	local lastLine
	while os.clock() < deadline do
		if Runner.cancel then
			return false, "ยกเลิกแล้ว"
		end
		local actual = dialogueActual()
		if not actual then
			return false, "NPC ไม่มีตัวเลือกนี้ให้ (เงื่อนไขยังไม่ครบ หรือทำไปแล้ว)"
		end

		local opts = dialogueOptions(actual)
		if #opts > 0 then
			for _, o in ipairs(opts) do
				if o.text:lower():find(answer:lower(), 1, true) then
					clickGui(o.button)
					return true
				end
			end
			-- ไม่มีคำตอบที่ต้องการ ปิดหน้าคุยทิ้งดีกว่าค้างไว้บังจอ
			for _, o in ipairs(opts) do
				if o.text:lower():find("close", 1, true) then
					clickGui(o.button)
				end
			end
			local names = {}
			for _, o in ipairs(opts) do
				names[#names + 1] = o.text
			end
			return false, 'ไม่มีตัวเลือก "' .. answer .. '" (มี: ' .. table.concat(names, " / ") .. ")"
		end

		lastLine = dialogueText(actual)
		local clicker = actual:FindFirstChild("ClickDetector")
		if clicker then
			clickGui(clicker)
		end
		task.wait(0.7)
	end
	return false, "บทสนทนาค้างที่: " .. tostring(lastLine)
end

local function runStep(step, index, total)
	if step.hunt then
		-- ตัวลูปสู้อยู่ล่างไฟล์ ผูกเข้ามาทีหลังที่ Runner.hunt
		if not Runner.hunt then
			return false, "ระบบสู้ยังไม่พร้อม"
		end
		return Runner.hunt(step, index, total)
	end

	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false, "ไม่พบตัวละคร"
	end

	local spawn = npcSpawnPoint(step.npc)
	if not spawn then
		return false, "ไม่รู้ตำแหน่ง " .. step.npc
	end

	report(string.format("[%d/%d] วาร์ปไปหา %s · %s", index, total, step.npc, spawn.region), Theme.Accent)
	hrp.CFrame = CFrame.new(spawn.pos + Vector3.new(0, 3, 5), spawn.pos)

	local npc
	for _ = 1, 40 do
		if Runner.cancel then
			return false, "ยกเลิกแล้ว"
		end
		npc = findLiveNpc(step.npc)
		if npc then
			break
		end
		task.wait(0.3)
	end
	if not npc then
		return false, step.npc .. " ยังไม่ stream เข้ามาใน 12 วิ"
	end

	-- ยืนห่าง 4 stud หันหน้าเข้าหา prompt ของเกมยอมรับที่ระยะ 10
	local pos = npc:GetPivot().Position
	hrp.CFrame = CFrame.new(pos + Vector3.new(0, 0, 4), pos)
	task.wait(0.8)

	report(string.format("[%d/%d] คุยกับ %s", index, total, step.npc), Theme.Accent)
	fireproximityprompt(npc:FindFirstChildWhichIsA("ProximityPrompt", true))

	local deadline = os.clock() + 8
	while os.clock() < deadline and not dialogueActual() do
		task.wait(0.2)
	end
	if not dialogueActual() then
		return false, "เปิดบทสนทนากับ " .. step.npc .. " ไม่สำเร็จ"
	end

	return walkDialogue(step.answer, os.clock() + 30)
end

function Runner.stop()
	Runner.cancel = true
end

-- list = เควสที่ติ๊กไว้ในแถวเดียวกัน เรียงบอสก่อนมาแล้ว (Krue: บอสโจร Lv 7 → โจร 3 ตัว)
-- วนทำทีละเควสตามลำดับ ครบรายการก็เริ่มรอบใหม่ จนกว่าจะกด STOP
function Runner.start(list)
	-- getconnections ของ executor ยิงซ้ำได้ กันไว้ 1 วิ ไม่งั้นวาร์ปซ้อนสองรอบ
	if Runner.active or os.clock() - Runner.lastStart < 1 then
		return false
	end

	local queue = {}
	for _, d in ipairs(list) do
		local steps = questPlan(d)
		if steps and questProgress(d.key) ~= "completed" then
			queue[#queue + 1] = { data = d, steps = steps }
		end
	end
	if #queue == 0 then
		report("เควสที่เลือกยังไม่รองรับ หรือทำจบไปแล้วทั้งหมด", Theme.Warn)
		return false
	end

	-- ถือเควสในรายการค้างอยู่แล้ว (รับเองกับมือ หรือกด STOP กลางทาง) ข้ามขั้นรับไปไล่ฆ่าต่อ
	-- Holder.<ชื่อ QuestInstance> เก็บ QuestString = คำตอบที่ใช้รับ วัดจาก Krue รอบแรก
	local resumeAt, firstStep = 1, 1
	local quests = questFolder()
	local holder = quests and quests:FindFirstChild("Holder")
	local held = holder and holder:GetChildren()[1]
	if held then
		for i, q in ipairs(queue) do
			if q.data.title == held.Name and q.steps[2] and q.steps[2].hunt then
				resumeAt, firstStep = i, 2
			end
		end
		if firstStep == 1 then
			report("ยังมีเควสอื่นค้างอยู่: " .. held.Name .. " (เกมให้ถือได้ทีละ " .. QuestRules.MaxQuestsPerPlayer .. ")", Theme.Warn)
			return false
		end
	end

	Runner.lastStart = os.clock()
	Runner.active = true
	Runner.cancel = false

	-- เปิด Kill Aura ให้ตอนกด START แล้วคืนสถานะเดิมตอนจบ ผู้ใช้เปิดไว้เองก็ไม่ไปปิดให้
	local auraWasOn = Runner.auraOn and Runner.auraOn()
	if Runner.setAura and not auraWasOn then
		Runner.setAura(true)
	end

	local function finish(text, color)
		report(text, color)
		if Runner.setAura and not auraWasOn then
			Runner.setAura(false)
		end
		Runner.active = false
		Runner.onFinish()
	end

	-- เควสที่รับไม่ได้ (เลเวลไม่ถึง / เกมไม่ให้ตัวเลือก) หรือเป็นแบบทำได้ครั้งเดียวที่จบแล้ว
	-- ตัดออกจากรอบถัดไป เควสที่เหลือยังวนต่อได้ ไม่ต้องหยุดทั้งชุด
	-- เควสบอส = มีขั้นฆ่าที่ต้องฆ่าแค่ตัวเดียว (Zuko, Mother Bear, Kaiden ...)
	-- บอสเกิดใหม่ช้า Zuko ใช้ ~130 วิ รอเฉย ๆ เสียเวลา ถ้ามีเควสอื่นติ๊กไว้ให้ไปทำอันนั้นก่อน
	local function bossStep(q)
		for _, s in ipairs(q.steps) do
			if s.hunt and s.max == 1 then
				return s
			end
		end
		return nil
	end

	-- คืน true ถ้ารอบนี้ได้ลงมือทำ false ถ้าข้ามเพราะบอสยังไม่เกิด
	local function runQuest(q, round, canSkip)
		local d = q.data
		local boss = bossStep(q)
		Runner.hasAlternative = canSkip

		-- เช็กก่อนรับ จะได้ไม่ต้องรับแล้วยกเลิก (รับเควสทีกินคูลดาวน์ 30 วิ)
		if boss and canSkip and firstStep == 1 and Runner.bossAlive and not Runner.bossAlive(boss) then
			report(string.format("รอบ %d · %s ยังไม่เกิด ข้ามไปทำเควสอื่นก่อน", round, boss.hunt), Theme.Warn)
			task.wait(1)
			return false
		end

		while questCooldown() > 0 and not Runner.cancel and firstStep == 1 do
			report(string.format("รอบ %d · %s · คูลดาวน์รับเควส %s", round, d.title, clockText(questCooldown())), Theme.Warn)
			task.wait(1)
		end

		for i = firstStep, #q.steps do
			if Runner.cancel then
				return true
			end
			local ok, err = runStep(q.steps[i], i, #q.steps)
			if not ok then
				if err == Runner.BOSS_GONE then
					-- ยกเลิกเควสไปแล้วใน Runner.hunt ไม่ตัดออกจากรอบ รอบหน้ามาลองใหม่
					report(string.format("รอบ %d · %s ตาย/หายไป ยกเลิกเควสแล้ว ไปทำเควสอื่นก่อน", round, boss and boss.hunt or "บอส"), Theme.Warn)
					task.wait(1)
				elseif not Runner.cancel then
					q.dropped = d.title .. ": " .. tostring(err)
				end
				return true
			end
			task.wait(1.5)
		end

		if questProgress(d.key) == "completed" then
			q.dropped = d.title .. " ทำได้ครั้งเดียว จบแล้ว"
		end
		return true
	end

	task.spawn(function()
		-- เควสฆ่าม็อบเกมไม่บันทึกลง Completed เลยรับใหม่ได้เรื่อย ๆ
		local round = 0
		local lastDrop
		-- ทุกเควสที่เหลือเป็นบอสที่ยังไม่เกิดหมด ข้ามกันไปมาจะวนเปล่า ๆ รอบถัดไปห้ามข้าม รอบอสเลย
		local mustWait = false
		while not Runner.cancel do
			round += 1
			local ranAny = false
			for qi = resumeAt, #queue do
				local q = queue[qi]
				if Runner.cancel then
					break
				end
				if not q.dropped then
					local others = 0
					for _, o in ipairs(queue) do
						if o ~= q and not o.dropped then
							others += 1
						end
					end
					if runQuest(q, round, others > 0 and not mustWait) then
						ranAny = true
					end
					firstStep = 1
					if q.dropped then
						lastDrop = q.dropped
						report("ข้าม " .. q.dropped, Theme.Warn)
						task.wait(1.5)
					end
				end
			end
			resumeAt = 1
			mustWait = not ranAny

			if Runner.cancel then
				break
			end
			local left = 0
			for _, q in ipairs(queue) do
				if not q.dropped then
					left += 1
				end
			end
			if left == 0 then
				finish("หยุด: ไม่เหลือเควสให้ทำ (" .. tostring(lastDrop) .. ")", Theme.Danger)
				return
			end
			report(string.format("จบรอบ %d · วนรับเควสต่อ", round), Theme.Accent)
		end

		finish("ยกเลิกแล้ว", Theme.Warn)
	end)
	return true
end

function Runner.onFinish() end

local startLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Text = "START",
	TextColor3 = Theme.Dim,
	TextSize = 13,
	FontFace = font(Enum.FontWeight.SemiBold),
})

local startBtn = new("TextButton", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = Theme.Raised,
	AutoButtonColor = false,
	Text = "",
	Parent = questUI.panel,
}, { corner(8), startLabel })

refreshStartButton = function()
	if Runner.active then
		startLabel.Text = "STOP"
		tween(startBtn, { BackgroundColor3 = Theme.Danger }, FAST)
		tween(startLabel, { TextColor3 = Theme.Text }, FAST)
		return
	end

	if not questSelected then
		startLabel.Text = "START"
		tween(startBtn, { BackgroundColor3 = Theme.Raised }, FAST)
		tween(startLabel, { TextColor3 = Theme.Dim }, FAST)
		return
	end

	-- questSelected เป็นรายการ ปุ่มสรุปจากทั้งชุด: มีอันไหนรันได้ก็กด START ได้
	local runnable, titles = {}, {}
	for _, d in ipairs(questSelected) do
		titles[#titles + 1] = d.title
		if questPlan(d) and questProgress(d.key) ~= "completed" then
			runnable[#runnable + 1] = d
		end
	end
	local names = table.concat(titles, " → ")

	local quests = questFolder()
	local holder = quests and quests:FindFirstChild("Holder")
	local held = holder and holder:GetChildren()[1]
	local resumable = false
	for _, d in ipairs(runnable) do
		if held and held.Name == d.title then
			resumable = true
		end
	end
	local cd = questCooldown()

	if #runnable == 0 then
		local anyPlan = false
		for _, d in ipairs(questSelected) do
			anyPlan = anyPlan or questPlan(d) ~= nil
		end
		startLabel.Text = (anyPlan and "ทำแล้ว  ·  " or "ยังไม่รองรับ  ·  ") .. names
	elseif resumable then
		startLabel.Text = "ทำต่อ  ·  " .. held.Name
	elseif held then
		startLabel.Text = "มีเควสค้าง  ·  " .. held.Name
	elseif cd > 0 then
		startLabel.Text = "คูลดาวน์ " .. clockText(cd) .. "  ·  START"
	else
		startLabel.Text = "START  ·  " .. names
	end

	local ready = #runnable > 0 and (resumable or (not held and cd <= 0))
	tween(startBtn, { BackgroundColor3 = ready and Theme.Accent or Theme.Raised }, FAST)
	tween(startLabel, { TextColor3 = ready and Theme.Base or Theme.Dim }, FAST)
end

Runner.onFinish = function()
	refreshStartButton()
end

-- เดินนาฬิกาคูลดาวน์ทุกวินาที เฉพาะตอนแผงเปิดอยู่ ไม่งั้นเสีย frame ฟรี ๆ
task.spawn(function()
	while questUI.panel.Parent do
		task.wait(1)
		if questUI.panel.Visible and not Runner.active then
			refreshStartButton()
		end
	end
end)

track(startBtn.MouseButton1Click:Connect(function()
	if Runner.active then
		Runner.stop()
		report("กำลังยกเลิก…", Theme.Warn)
		return
	end
	if not questSelected then
		return
	end
	if Runner.start(questSelected) then
		refreshStartButton()
	end
end))

-- รายชื่อม็อบทั้งแมพ --------------------------------------------------------

-- นิยามม็อบอยู่ที่ Ouwland.Content.<โซน>.ActiveNpcs (45 ตัว) แต่ค่าพลังชีวิตจริง
-- อยู่ฝั่ง server (โมดูลมีแค่ NpcCode) เลยต้องเอาค่าจากตัวที่ stream เข้ามาแล้วมาเติม
local MobTier = {
	-- แบ่งจากค่าที่วัดได้จริง: Bandit 45, Zuko 300 ที่เหลือยังไม่ได้เห็นตัวเลข
	-- เส้นแบ่งนี้เป็นการเดาจากสองจุดนั้น ถ้าเจอม็อบที่หลุดช่วงค่อยขยับ
	Normal = { max = 100, color = Color3.fromRGB(120, 190, 140), label = "ธรรมดา" },
	Mini = { max = 600, color = Color3.fromRGB(230, 175, 90), label = "Miniboss" },
	Boss = { max = math.huge, color = Color3.fromRGB(235, 95, 95), label = "Boss" },
}

local function tierOf(maxHealth)
	if not maxHealth then
		return nil
	end
	if maxHealth <= MobTier.Normal.max then
		return "Normal"
	elseif maxHealth <= MobTier.Mini.max then
		return "Mini"
	end
	return "Boss"
end

local mobDefCache
function Game.mobs()
	if not mobDefCache then
		mobDefCache = {}
		for _, region in ipairs(ReplicatedStorage.Ouwland.Content:GetChildren()) do
			local active = region:FindFirstChild("ActiveNpcs")
			for _, m in ipairs(active and active:GetChildren() or {}) do
				if m:IsA("ModuleScript") then
					local def = require(m)
					local send = def.SendOver or {}
					local spawning = send.Spawning or {}
					mobDefCache[#mobDefCache + 1] = {
						key = m.Name,
						name = def.Name or m.Name,
						region = region.Name,
						quantity = def.Quantity,
						icon = def.Icon,
						-- ตัวที่เควสนับคือ Settings.NpcCode ไม่ใช่ชื่อโมเดล (Bandit = KaruVillageBandit)
						code = send.Settings and send.Settings.NpcCode,
						-- ม็อบ stream เข้ามาเฉพาะตอนอยู่ใกล้ ต้องรู้ว่าจะวาร์ปไปรอที่ไหนก่อน
						center = spawning.Center or (spawning.Locations and spawning.Locations[1]),
					}
				end
			end
		end
	end

	-- เติมค่าพลังชีวิต/จำนวนที่ยังไม่ตาย จากตัวที่อยู่ใน workspace ตอนนี้
	local live = {}
	local folder = workspace:FindFirstChild("Humanoids")
	for _, m in ipairs(folder and folder:GetDescendants() or {}) do
		if m:IsA("Model") and m:GetAttribute("IsMob") then
			local hum = m:FindFirstChildOfClass("Humanoid")
			if hum then
				local slot = live[m.Name] or { alive = 0, maxHealth = nil, health = 0 }
				if hum.Health > 0 then
					slot.alive += 1
					slot.health += hum.Health
				end
				slot.maxHealth = math.max(slot.maxHealth or 0, hum.MaxHealth)
				live[m.Name] = slot
			end
		end
	end

	local out = {}
	for _, def in ipairs(mobDefCache) do
		local seen = live[def.name] or live[def.key]
		local maxHealth = seen and seen.maxHealth or nil
		out[#out + 1] = {
			key = def.key,
			name = def.name,
			region = def.region,
			quantity = def.quantity,
			maxHealth = maxHealth,
			alive = seen and seen.alive or 0,
			health = seen and seen.health or 0,
			tier = tierOf(maxHealth),
			code = def.code,
			center = def.center,
		}
	end

	-- อ่อนสุดขึ้นก่อน ตัวที่ยังไม่เคยเห็นค่าเลือดดันไปท้ายสุด ไม่ใช่มาปนข้างบน
	table.sort(out, function(a, b)
		local ha = a.maxHealth or math.huge
		local hb = b.maxHealth or math.huge
		if ha ~= hb then
			return ha < hb
		end
		if a.region ~= b.region then
			return a.region < b.region
		end
		return a.name < b.name
	end)
	return out
end

local mobUI = makePanel("Auto-Attack-Mob", false)
mobUI.search.PlaceholderText = "ค้นหาชื่อม็อบหรือโซน…"

local mobFilter = "All"
local mobRows = {}
local selectedMob

-- ประกาศไว้ก่อน ตัวจริงคือ applyMobFilter ที่นิยามอยู่ล่างกว่านี้
local refreshMobStart = function() end

local function selectMobRow(row)
	local target = selectedMob ~= row.data.name and row or nil
	for _, r in ipairs(mobRows) do
		local on = r == target
		tween(r.tickFill, { BackgroundTransparency = on and 0 or 1 }, FAST)
		tween(r.frame, { BackgroundColor3 = (on or r == row) and Theme.Raised or Theme.Row }, FAST)
		r.tickStroke.Color = on and Theme.Accent or Theme.Stroke
	end
	selectedMob = target and row.data.name or nil
	refreshMobStart()
end

local function buildMobRow(data, order)
	local frame = new("Frame", {
		Size = UDim2.new(1, -6, 0, 40),
		BackgroundColor3 = Theme.Row,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = mobUI.list,
	}, { corner(7) })

	local tickFill, tickStroke = tickBox(frame)

	local tier = data.tier and MobTier[data.tier]
	new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 32, 0.5, 0),
		Size = UDim2.fromOffset(3, 20),
		BackgroundColor3 = tier and tier.color or Theme.Dim,
		BorderSizePixel = 0,
		Parent = frame,
	}, { corner(2) })

	new("TextLabel", {
		Position = UDim2.fromOffset(44, 5),
		Size = UDim2.new(1, -150, 0, 14),
		BackgroundTransparency = 1,
		Text = data.name,
		TextColor3 = tier and tier.color or Theme.Muted,
		TextSize = 12,
		FontFace = font(Enum.FontWeight.Medium),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})

	new("TextLabel", {
		Position = UDim2.fromOffset(44, 20),
		Size = UDim2.new(1, -150, 0, 13),
		BackgroundTransparency = 1,
		Text = data.region .. (tier and ("  ·  " .. tier.label) or "  ·  ยังไม่เห็นตัว"),
		TextColor3 = Theme.Dim,
		TextSize = 11,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})

	local hpText = data.maxHealth and (comma(data.maxHealth) .. " HP") or "HP ?"
	new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 5),
		Size = UDim2.fromOffset(110, 14),
		BackgroundTransparency = 1,
		Text = hpText,
		TextColor3 = tier and tier.color or Theme.Dim,
		TextSize = 11,
		FontFace = font(Enum.FontWeight.Medium),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	})

	new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 20),
		Size = UDim2.fromOffset(110, 13),
		BackgroundTransparency = 1,
		Text = data.alive > 0 and ("ในแมพ " .. data.alive .. " ตัว") or "ยังไม่ spawn",
		TextColor3 = Theme.Dim,
		TextSize = 11,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	})

	local row = { frame = frame, tickFill = tickFill, tickStroke = tickStroke, data = data }
	local hit = new("TextButton", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		Parent = frame,
	})
	track(hit.MouseButton1Click:Connect(function()
		selectMobRow(row)
	end))
	track(hit.MouseEnter:Connect(function()
		if selectedMob ~= data.name then
			tween(frame, { BackgroundColor3 = Theme.Raised }, FAST)
		end
	end))
	track(hit.MouseLeave:Connect(function()
		if selectedMob ~= data.name then
			tween(frame, { BackgroundColor3 = Theme.Row }, FAST)
		end
	end))
	return row
end

local function applyMobFilter()
	local query = mobUI.search.Text:lower()
	local shown = 0
	for _, r in ipairs(mobRows) do
		local d = r.data
		local okTier = mobFilter == "All"
			or (mobFilter == "ธรรมดา" and d.tier == "Normal")
			or (mobFilter == "Miniboss" and d.tier == "Mini")
			or (mobFilter == "Boss" and d.tier == "Boss")
		local okText = query == ""
			or d.name:lower():find(query, 1, true) ~= nil
			or d.region:lower():find(query, 1, true) ~= nil
		r.frame.Visible = okTier and okText
		if r.frame.Visible then
			shown += 1
		end
	end
	mobUI.setStatus(
		string.format("แสดง %d ม็อบ · เรียงจากเลือดน้อยไปมาก%s",
			shown,
			selectedMob and (" · เลือก " .. selectedMob) or ""),
		selectedMob and Theme.Accent or Theme.Muted
	)
end

local function rebuildMobs()
	for _, r in ipairs(mobRows) do
		r.frame:Destroy()
	end
	table.clear(mobRows)

	local list = Game.mobs()
	for i, data in ipairs(list) do
		mobRows[#mobRows + 1] = buildMobRow(data, i)
		if data.name == selectedMob then
			local r = mobRows[#mobRows]
			r.tickFill.BackgroundTransparency = 0
			r.tickStroke.Color = Theme.Accent
			r.frame.BackgroundColor3 = Theme.Raised
		end
	end

	local seen = 0
	for _, d in ipairs(list) do
		if d.maxHealth then
			seen += 1
		end
	end
	mobUI.subtitle.Text = string.format(
		'<font color="#8f8f9e">ม็อบทั้งหมด</font> %d   <font color="#8f8f9e">เห็นค่าเลือดแล้ว</font> %d',
		#list,
		seen
	)
	applyMobFilter()
end

refreshMobStart = applyMobFilter

addPills(mobUI.filterRow, { "All", "ธรรมดา", "Miniboss", "Boss" }, function(name)
	mobFilter = name
	applyMobFilter()
end)

track(mobUI.search:GetPropertyChangedSignal("Text"):Connect(applyMobFilter))

-- ผูกฟังก์ชันเข้าหน้า Main ---------------------------------------------------

local shopFeature = featureRow(
	"Buy Weapons",
	"เลือกซื้ออาวุธทุกชิ้นในเกม เทียบราคากับเงินที่มีจริง",
	1,
	function()
		-- อ่านเงินกับคลังใหม่ทุกครั้งที่เปิด ไม่งั้นซื้อของที่อื่นแล้วตัวเลขในแผงค้าง
		rebuildShop()
		shopUI.show()
	end,
	shopUI.hide
)

local questFeature = featureRow(
	"Auto-Quest",
	"รายชื่อ NPC ที่มีเควส เรียงตามเลเวลที่ควรทำ",
	2,
	function()
		rebuildQuests()
		questUI.show()
	end,
	questUI.hide
)

local mobFeature = featureRow(
	"Auto-Attack-Mob",
	"เลือกม็อบที่จะให้ตี แล้วไปเปิดสวิตช์ในแท็บ Visuals",
	3,
	function()
		rebuildMobs()
		mobUI.show()
	end,
	mobUI.hide
)

track(shopUI.closeButton.MouseButton1Click:Connect(function()
	shopFeature.setOpen(false)
end))
track(questUI.closeButton.MouseButton1Click:Connect(function()
	questFeature.setOpen(false)
end))
track(mobUI.closeButton.MouseButton1Click:Connect(function()
	mobFeature.setOpen(false)
end))

closeShopPanel = function()
	for _, f in ipairs(features) do
		f.setOpen(false)
	end
end

local function placeholderTab(name)
	local tab = addTab(name)
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = name .. " — ยังว่าง",
		TextColor3 = Theme.Muted,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = tab.page,
	})
end

placeholderTab("Pathfinding")

-- แท็บ Visuals: สวิตช์ช่วยต่อสู้ ----------------------------------------------

local visualsTab = addTab("Visuals")

new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 18),
	BackgroundTransparency = 1,
	Text = "ช่วยต่อสู้",
	TextColor3 = Theme.Muted,
	TextSize = 11,
	FontFace = font(Enum.FontWeight.Medium),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = visualsTab.page,
})

local switchList = new("Frame", {
	Position = UDim2.fromOffset(0, 26),
	Size = UDim2.new(1, 0, 1, -26),
	BackgroundTransparency = 1,
	Parent = visualsTab.page,
}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

-- แถวใน Visuals มีสองแบบ: สวิตช์ ON/OFF กับแถวเลือกตัวเลข (opts.choices)
-- แบบเลือกตัวเลขใช้กับช่องอาวุธ เพราะผู้เล่นแต่ละคนวางของคนละช่อง
local function switchRow(name, desc, order, onChange, opts)
	opts = opts or {}

	local frame = new("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Theme.Row,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = switchList,
	}, { corner(8), stroke(Theme.Stroke, 1) })

	local rightWidth = opts.choices and (#opts.choices * 28 + 14) or 90

	new("TextLabel", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -rightWidth, 0, 15),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = Theme.Text,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.Medium),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})

	local descLabel = new("TextLabel", {
		Position = UDim2.fromOffset(14, 24),
		Size = UDim2.new(1, -rightWidth, 0, 13),
		BackgroundTransparency = 1,
		Text = desc,
		TextColor3 = Theme.Dim,
		TextSize = 11,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})

	local entry = {}
	function entry.setDesc(text)
		descLabel.Text = text
	end

	if opts.choices then
		local row = new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(#opts.choices * 28 - 4, 24),
			BackgroundTransparency = 1,
			Parent = frame,
		}, { new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}) })

		local buttons = {}
		local current = opts.selected or 1
		-- multi: เลือกได้หลายปุ่ม เก็บเป็นเซ็ต { [i] = true } ต้องเหลืออย่างน้อยหนึ่งเสมอ
		local picked = {}
		if opts.multi then
			for _, i in ipairs(opts.selected or { 1 }) do
				picked[i] = true
			end
		end

		local function paint()
			for i, b in ipairs(buttons) do
				local on
				if opts.multi then
					on = picked[i] == true
				else
					on = i == current
				end
				tween(b.btn, { BackgroundColor3 = on and Theme.Accent or Theme.Raised }, FAST)
				tween(b.label, { TextColor3 = on and Theme.Base or Theme.Muted }, FAST)
			end
		end

		for i, text in ipairs(opts.choices) do
			local label = new("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = text,
				TextColor3 = Theme.Muted,
				TextSize = 11,
				FontFace = font(Enum.FontWeight.SemiBold),
			})
			local btn = new("TextButton", {
				Size = UDim2.fromOffset(24, 24),
				BackgroundColor3 = Theme.Raised,
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = i,
				Parent = row,
			}, { corner(6), stroke(Theme.Stroke, 1), label })
			buttons[i] = { btn = btn, label = label }

			track(btn.MouseButton1Click:Connect(function()
				if opts.multi then
					local count = 0
					for _ in pairs(picked) do
						count += 1
					end
					if picked[i] and count == 1 then
						return
					end
					picked[i] = not picked[i] or nil
				else
					current = i
				end
				paint()
				if opts.onChoice then
					local copy = table.clone(picked)
					opts.onChoice(i, copy)
				end
			end))
		end

		-- ไม่เรียก onChoice ตอนสร้าง เพราะตัวแปรที่ callback อ้างถึงยังไม่ถูก assign
		paint()
		return entry
	end

	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Theme.Muted,
		BorderSizePixel = 0,
	}, { corner(8) })

	local rail = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(42, 22),
		BackgroundColor3 = Theme.Raised,
		BorderSizePixel = 0,
		Parent = frame,
	}, { corner(11), stroke(Theme.Stroke, 1), knob })

	local hit = new("TextButton", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		Parent = frame,
	})

	local on = false
	function entry.set(state)
		if on == state then
			return
		end
		on = state
		tween(rail, { BackgroundColor3 = on and Theme.Accent or Theme.Raised }, FAST)
		tween(knob, {
			Position = UDim2.new(0, on and 23 or 3, 0.5, 0),
			BackgroundColor3 = on and Theme.Base or Theme.Muted,
		}, FAST)
		onChange(on, entry)
	end

	track(hit.MouseButton1Click:Connect(function()
		entry.set(not on)
	end))

	return entry
end

-- ตัวเลขทั้งหมดวัดจากการลองจริงที่ค่ายโจร Windy Peak (Bandit 45 HP / Zuko 300 HP)
local Combat = {
	-- ไม่จำกัดรัศมี กวาดทั้งแมพแล้วเลือกตัวที่ใกล้ที่สุดเสมอ
	-- ที่จำกัดไว้ 120 ตอนแรกทำให้พอถอยหนีแล้วหาเป้าไม่เจออีกเลย (ห่าง 226 stud)
	AcquireRange = math.huge,
	-- พื้นแมพจริงอยู่ราว Y 900-1300 อะไรที่ต่ำกว่านี้คือม็อบที่ถูกพักไว้ใต้แมพ
	WorldFloorY = 0,
	-- ชาวบ้านมี IsMob = true เหมือนม็อบ (attribute เหมือนโจรทุกตัว แยกได้แค่ชื่อ)
	-- Auto-Attack ทั่วไปไม่ควรไปไล่ตีคนในหมู่บ้าน ถ้าอยากตีจริง (เควสจับสายลับ)
	-- ให้เลือกชื่อเองในแผง Auto-Attack-Mob ซึ่งข้ามรายการนี้
	NeverTarget = { ["Civilian"] = true, ["*Civilian*"] = true },
	-- ลอยเหนือหัวม็อบแล้วต่อยลงมา ยืนข้างตัวแบบเดิมโดนรุมตายทุกรอบ
	-- วัดกับ Bandit 6 หมัดต่อความสูง:
	--   3 stud  ดาเมจเข้า 25  โดนตี 0
	--   5 stud  ดาเมจเข้า 0   โดนตี 18
	--   7 stud  ดาเมจเข้า 7   โดนตี 36
	HoverHeight = 3,
	-- เข้าหาจนเหลือระยะนี้แล้วค่อยสลับไปปักเหนือหัว ใกล้กว่านี้การก้าว 6 stud ต่อรอบจะเลยเป้า
	EngageDistance = 8,
	-- เกมฆ่าตัวละครที่ค้าง Freefall นาน: ลอยนิ่ง 7.5 วิยังรอด ตายที่วินาทีที่ 9
	-- ตั้ง 3 วิเผื่อไว้เยอะ เพราะช่วงโดนตีเด้งก็นับเป็น Freefall ด้วย
	MaxAirTime = 3,
	-- เวลาบนพื้นขั้นต่ำก่อนนับรอบลอยใหม่ ยังไม่ได้วัดว่าเกมต้องการเท่าไร 0.6 คือค่าเผื่อ
	GroundTouch = 0.6,
	-- ตอนลงแตะพื้นยืนเยื้องจากเป้า 6 stud พ้นตัวม็อบแต่ยังอยู่ใกล้พอให้ลอยกลับได้ทันที
	LandOffset = 6,
	-- 0.45 วิต่อหมัด คือจังหวะที่คอมโบเดินต่อเนื่องโดยไม่โดนกินอินพุต
	SwingInterval = 0.45,

	-- ข้ามบอส: รอบแรกที่ลอง มันล็อก Zuko (300 HP) ก่อนเพราะอยู่ใกล้สุด
	-- แล้วตายใน 7 วิเพราะโดนรุมจากม็อบรอบ ๆ ด้วย ม็อบธรรมดาแถวนี้ 45 HP
	SkipBossAbove = 120,

	-- ไม่มีระบบถอยรอเลือดแล้ว (ผู้ใช้เลือกเอง: ตายก็เกิดใหม่แล้วตีต่อ)
	-- เลือดฟื้นช้ามาก ค้างราว 30 วิกว่าจะเริ่มขึ้น ถอยรอเสียเวลากว่าตายแล้วเกิดใหม่

	-- Auto-Dodge เดิมใช้ Dash (กดทิศค้าง 0.4 วิ + Q) หลังโดนตี
	-- ช้าเกินไป ท่าโจรเร็วสุดดาเมจเข้าหลังเริ่มท่า 0.14 วิ ตอนนี้ใช้วาร์ปแทน (ดู Dodge)
}

local VIM = game:GetService("VirtualInputManager")
-- ช่องอาวุธที่ติ๊กไว้ในแถว Auto-Equip-Weapon ติ๊กได้หลายช่อง Kill Aura จะสลับไปเรื่อย ๆ
local weaponSlots = { [1] = true }
-- ช่องแรกที่ติ๊กไว้ ลูปสู้ใช้ตัวนี้เป็นอาวุธหลักตอนยังไม่ถืออะไร
local function primarySlot()
	for i = 1, 5 do
		if weaponSlots[i] then
			return i
		end
	end
	return 1
end

-- เกมเก็บช่องที่ถืออยู่ไว้ที่ LocalPlayer.Items_Config.Equipped (0 = มือเปล่า)
-- แถบ toolbar ของเกมฟัง .Changed แล้วยิง SignalEvent "Item_Equip" ให้เอง
-- เขียนค่านี้ตรง ๆ จึงสลับอาวุธได้ทันที ไม่ต้องกดเลขผ่าน VirtualInputManager (0.5 วิต่อครั้ง)
-- และไม่มีปัญหากดซ้ำแล้วกลายเป็นถอดแบบเดิม เพราะตั้งค่าเดิมซ้ำไม่ทำให้ .Changed ยิง
local function equippedValue()
	local cfg = LocalPlayer:FindFirstChild("Items_Config")
	return cfg and cfg:FindFirstChild("Equipped")
end

local function heldSlot()
	local v = equippedValue()
	return v and v.Value or 0
end

-- ช่องว่างใน toolbar (ค่า 0) สลับไปก็ถือมือเปล่า ข้ามไป
local function slotHasItem(index)
	local slot = equippedSlot()
	local bar = slot and slot:FindFirstChild("Inventory") and slot.Inventory:FindFirstChild("Toolbar")
	local names = { "One", "Two", "Three", "Four", "Five" }
	local v = bar and bar:FindFirstChild(names[index])
	return v ~= nil and v.Value ~= 0
end

local function equipSlot(index)
	local v = equippedValue()
	if v and v.Value ~= index then
		v.Value = index
	end
end

-- ถือช่องที่ติ๊กไว้ช่องใดช่องหนึ่งอยู่ถือว่าพร้อมตี
local function weaponReady()
	return weaponSlots[heldSlot()] == true
end

local function equipWeapon()
	if weaponReady() then
		return true
	end
	local slot = primarySlot()
	if not slotHasItem(slot) then
		return false
	end
	equipSlot(slot)
	task.wait(0.3)
	return weaponReady()
end

-- ต้องคลิกตรงตัวม็อบจริง ๆ เกมเล็งจากตำแหน่งเมาส์
-- ลองย้ายไปคลิกกลางจอแทนแล้ว ดาเมจไม่เข้าเลย (Bandit ค้างที่ 37/45 ทั้งยก)
-- ปัญหาเดิมคือบางทีม็อบอยู่หลังหน้าต่าง PathSlayer แล้วคลิกไปโดนสวิตช์ตัวเอง
-- เลยดับ ScreenGui แค่ช่วงคลิก (~70ms) เฉพาะตอนที่จุดนั้นทับหน้าต่างจริง
local function swingAt(worldPos)
	local p = workspace.CurrentCamera:WorldToViewportPoint(worldPos)
	local pos, size = root.AbsolutePosition, root.AbsoluteSize
	local overlaps = root.Visible
		and p.X >= pos.X and p.X <= pos.X + size.X
		and p.Y >= pos.Y and p.Y <= pos.Y + size.Y

	if overlaps then
		screen.Enabled = false
	end
	local trace = _G.PathSlayerTrace
	if trace then
		trace[#trace + 1] = string.format("%.2f SWING", os.clock())
	end
	VIM:SendMouseButtonEvent(p.X, p.Y, 0, true, game, false)
	task.wait(0.06)
	VIM:SendMouseButtonEvent(p.X, p.Y, 0, false, game, false)
	if overlaps then
		screen.Enabled = true
	end
end

-- เลือกม็อบที่ใกล้ที่สุด เรียงตามระยะล้วน
-- เคยลองเรียงตามเลือดน้อยสุดก่อน แล้วมันวิ่งข้ามแมพไปเก็บตัวที่เกือบตาย
-- nameFilter มาจากแผง Auto-Attack-Mob ถ้าระบุชื่อไว้จะไม่สนเพดานบอส
-- เพราะผู้ใช้เลือกบอสเองก็ต้องได้ตีบอส
local function pickTarget(origin, nameFilter)
	local folder = workspace:FindFirstChild("Humanoids")
	if not folder then
		return nil
	end
	local best, bestD
	for _, m in ipairs(folder:GetDescendants()) do
		if m:IsA("Model") and m:GetAttribute("IsMob") then
			local hum = m:FindFirstChildOfClass("Humanoid")
			local root = m:FindFirstChild("HumanoidRootPart")
			local nameOk = not nameFilter or m.Name == nameFilter
			local tierOk = nameFilter ~= nil or (hum and hum.MaxHealth <= Combat.SkipBossAbove)
			-- ตัวที่ถูกพักไว้ถูกเก็บไว้ที่ Y ราว -1,000,000 และเลือดยังเต็ม
			-- พอปลดเพดานรัศมีแล้วมันโดนเลือกเป็นเป้า ตัวเราเลยวาร์ปตกนอกแมพซ้ำ ๆ
			local inWorld = root and root.Position.Y > Combat.WorldFloorY
			local allowed = nameFilter ~= nil or not Combat.NeverTarget[m.Name]
			if hum and root and hum.Health > 0 and nameOk and tierOk and inWorld and allowed then
				local d = (root.Position - origin).Magnitude
				if d <= Combat.AcquireRange and (not bestD or d < bestD) then
					best, bestD = m, d
				end
			end
		end
	end
	return best, bestD
end

-- สร้าง CFrame ที่หันหน้าไปทางเป้าแบบแนวนอน ห้ามใช้ CFrame.new(pos, lookAt) ตรง ๆ
-- ถ้า lookAt อยู่ตำแหน่งเดียวกับ pos (เช่นลอยตรงเหนือหัวเป้าพอดี หรือก้าวสุดท้ายถึงจุดเป้า)
-- การหมุนจะเป็น NaN แล้ว Roblox โยนตัวละครทั้งตัวไปที่ Y -1,000,000
-- บั๊กนี้คือตัวการของ "ตกใต้แมพ" ทั้งหมดที่เจอ ซึ่งเคยเดาผิดว่าเป็นระบบกันโกง ragdoll และระยะหมัด
local function facing(pos, lookAt, fallbackLook)
	local flat = Vector3.new(lookAt.X - pos.X, 0, lookAt.Z - pos.Z)
	if flat.Magnitude < 0.05 then
		flat = fallbackLook and Vector3.new(fallbackLook.X, 0, fallbackLook.Z) or Vector3.new(0, 0, -1)
		if flat.Magnitude < 0.05 then
			flat = Vector3.new(0, 0, -1)
		end
	end
	return CFrame.lookAt(pos, pos + flat.Unit)
end

-- ทุกการย้ายตัวละครในระบบสู้ผ่านที่นี่ที่เดียว
-- ห้ามย้ายไปต่ำกว่าพื้นแมพ และห้ามส่งค่า NaN ถ้าเจอให้ทิ้งแล้วจดไว้ว่ามาจากไหน
-- _G.PathSlayerTrace เปิดไว้ตอนดีบักเท่านั้น เก็บ 120 บรรทัดล่าสุด
local function placeAt(hrp, cf, tag)
	local trace = _G.PathSlayerTrace
	local look = cf.LookVector
	if cf.Position ~= cf.Position or look ~= look then
		if trace then
			trace[#trace + 1] = string.format("%.2f BLOCKED NaN %s", os.clock(), tag)
		end
		return false
	end
	if cf.Position.Y < Combat.WorldFloorY then
		if trace then
			trace[#trace + 1] = string.format("%.2f BLOCKED %s y=%.0f", os.clock(), tag, cf.Position.Y)
		end
		return false
	end
	hrp.CFrame = cf
	if trace then
		trace[#trace + 1] = string.format("%.2f %s y=%.0f", os.clock(), tag, cf.Position.Y)
		if #trace > 120 then
			table.remove(trace, 1)
		end
	end
	return true
end

local autoAttack = { on = false, onlySelected = false }
local killAura = { on = false, far = false, lastFire = 0, fires = 0, slotIndex = 0, comboBySlot = {}, lastBySlot = {} }
local autoDodge = { on = false, holdUntil = 0, dodges = 0, hitsTaken = 0, learned = 0 }

local function selfParts()
	local char = LocalPlayer.Character
	return char,
		char and char:FindFirstChild("HumanoidRootPart"),
		char and char:FindFirstChildOfClass("Humanoid")
end

local attackRow, dodgeRow, equipRow, mobOnlyRow, auraRow

-- ลูปเดียวถูกเปิดได้จากสองสวิตช์ ต้องเขียนสถานะลงตัวที่เปิดอยู่
-- ไม่งั้นเปิด Auto-Attack-Mob แล้วไปอ่านที่แถว Auto-Attack ซึ่งขึ้น "ปิดอยู่" ค้าง
local function combatStatus(text)
	local row = autoAttack.onlySelected and mobOnlyRow or attackRow
	if row then
		row.setDesc(text)
	end
end



-- ปักตัวไว้เหนือหัวม็อบ ต้องเขียนทุกเฟรมเพราะแรงโน้มถ่วงดึงลงตลอด
-- ตั้ง velocity เป็นศูนย์ด้วย ไม่งั้นตัวสะสมความเร็วตกแล้วกระตุกขึ้นลง
-- ม็อบที่หมดอายุถูกย้ายไปพักใต้แมพ (Y ราว -1,000,000) ถ้าไม่เช็กก่อน ตัวเราจะถูกลากตามลงไปด้วย
local function pinAbove(hrp, root)
	if not (root and root.Parent and hrp.Parent and root.Position.Y > Combat.WorldFloorY) then
		return false
	end
	local p = root.Position
	local spot = p + Vector3.new(0, Combat.HoverHeight, 0)
	placeAt(hrp, facing(spot, p, hrp.CFrame.LookVector), "hover")
	hrp.AssemblyLinearVelocity = Vector3.zero
	return true
end

-- นับเวลาลอยจาก state ของ Humanoid เอง ไม่ใช่จากโค้ดเรา
-- เพราะช่วงวิ่งเข้าหาเป้าก็ลอยด้วย (เขียน CFrame + ล้าง velocity ทุก 0.1 วิ)
-- รอบที่แล้วเดินทางไกลทั้งแมพแล้วตายกลางทางวนไม่จบ เพราะไม่ได้นับช่วงนี้
local airSince

-- สถานะที่เกมใช้ตอนตัวละครโดนตีล้ม วัดได้: โดนหมัดโจร -> Freefall (เด้ง) -> Physics
local KnockedStates = {
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
}

local function isKnockedDown(hum)
	return KnockedStates[hum:GetState()] == true
end

local function airborneFor(hum)
	local state = hum:GetState()
	if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
		airSince = airSince or os.clock()
		return os.clock() - airSince
	end
	airSince = nil
	return 0
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

-- ความสูงสะโพกของ R15 ปกติ วางตัวที่ พื้น + ค่านี้ เท้าจะแตะพื้นพอดี state เป็น Running
local HipOffset = 3

-- คืนตำแหน่งยืนบนพื้นใต้จุดที่ให้มา ไม่เจอพื้น (ข้ามเหว) คืน nil ให้ผู้เรียกใช้ Y เดิม
local function groundAt(pos)
	local exclude = { LocalPlayer.Character }
	local humanoids = workspace:FindFirstChild("Humanoids")
	if humanoids then
		exclude[#exclude + 1] = humanoids
	end
	groundParams.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(pos + Vector3.new(0, 25, 0), Vector3.new(0, -120, 0), groundParams)
	return hit and (hit.Position + Vector3.new(0, HipOffset, 0)) or nil
end

-- ลงไปยืนบนพื้นข้างเป้า ปล่อยให้แรงโน้มถ่วงทำงาน (ไม่ล้าง velocity)
-- ยิงเรย์หาพื้นจริงก่อน ไม่งั้นวางตัวลงไปในหินหรือบนหลังคาแล้วค้าง Freefall ต่อ
local function touchGround(hrp, hum, nearPos)
	local beside = nearPos + Vector3.new(Combat.LandOffset, 0, 0)
	local stand = groundAt(beside) or beside
	placeAt(hrp, facing(stand, nearPos, hrp.CFrame.LookVector), "land")

	local deadline = os.clock() + 1.5
	repeat
		task.wait(0.05)
	until hum:GetState() ~= Enum.HumanoidStateType.Freefall or os.clock() > deadline
	task.wait(Combat.GroundTouch)
	airSince = nil
end

local function attackLoop()
	airSince = nil
	autoAttack.running = true

	while autoAttack.on do
		local char, hrp, hum = selfParts()
		if not (hrp and hum and hum.Health > 0) then
			-- ตายแล้วรอเกิดใหม่ ของที่ถือหลุดหมด รอบถัดไปจะเห็นว่าวงกลมดำแล้วกดให้เอง
			combatStatus("รอเกิดใหม่…")
			task.wait(1.5)
		elseif isKnockedDown(hum) or hrp.Position.Y < Combat.WorldFloorY then
			-- โดนตีล้ม (Physics) ปล่อยให้เกมพาลุกเอง อย่าไปเขียน CFrame ทับตอนกำลังล้ม
			-- ตกใต้แมพก็หยุดรอเหมือนกัน ห้ามก้าวต่อจากตรงนั้นเด็ดขาด
			combatStatus(hrp.Position.Y < Combat.WorldFloorY and "ตกใต้แมพ รอเกมดึงกลับ…" or "โดนตีล้ม รอลุก…")
			airSince = nil
			task.wait(0.15)
		elseif os.clock() < autoDodge.holdUntil then
			-- Auto-Dodge เพิ่งวาร์ปหลบท่าตี ห้ามดึงกลับไปเหนือหัวเป้าจนกว่าจะพ้นช่วงหมัด
			combatStatus("หลบท่าตี…")
			task.wait(0.03)
		else
			-- ถือช่องไหนที่ติ๊กไว้ก็ได้ Kill Aura อาจสลับช่องอยู่ ห้ามดึงกลับช่องหลักทุกรอบ
			if not weaponReady() then
				combatStatus("ถือช่อง " .. primarySlot())
				if not equipWeapon() then
					combatStatus("ถือช่อง " .. primarySlot() .. " ไม่ติด (ช่องว่าง?)")
					task.wait(1)
				end
			end

			-- target มาจาก Auto-Quest ตอนไล่ฆ่าตามเควส มาก่อนตัวที่ติ๊กในแผง
			local wanted = autoAttack.target or (autoAttack.onlySelected and selectedMob or nil)
			local mob, dist = pickTarget(hrp.Position, wanted)
			local mobRoot = mob and mob:FindFirstChild("HumanoidRootPart")
			if mobRoot and mobRoot.Position.Y <= Combat.WorldFloorY then
				mobRoot = nil
			end
			if not mobRoot then
				combatStatus(wanted and ("ไม่เจอ " .. wanted .. " ทั้งแมพ") or "ไม่เจอม็อบทั้งแมพ")
				task.wait(0.8)
			else
				local mobHum = mob:FindFirstChildOfClass("Humanoid")
				local target = mobRoot.Position

				if airborneFor(hum) > Combat.MaxAirTime then
					combatStatus("แตะพื้นรีเซ็ตเวลาลอย")
					touchGround(hrp, hum, target)
				elseif dist > Combat.EngageDistance then
					-- วาร์ปตรงไปเหนือหัวเป้าทีเดียว ไม่เดินเข้าไป
					-- ช่วงเดินเข้าคือช่วงที่โดนม็อบตัวอื่นตีกลางทางบ่อยสุด วาร์ปตัดช่วงนั้นทิ้ง
					-- วาร์ปไกลข้ามแมพเคยใช้กับ Auto-Quest (Windy Peak -> Mistfall Harbor) ไม่มีปัญหา
					combatStatus(string.format("วาร์ปไป %s · %d stud", mob.Name, math.floor(dist)))
					pinAbove(hrp, mobRoot)
					airSince = nil
					task.wait(0.05)
				else
					-- แบ่ง SwingInterval เป็นช่วงสั้น ๆ เพื่อปักตำแหน่งใหม่ระหว่างรอหมัดถัดไป
					pinAbove(hrp, mobRoot)
					-- Kill Aura เปิดอยู่ให้มันยิงแทน คลิกซ้อนด้วยจะส่งถี่เกินจนเซิร์ฟเวอร์ทิ้ง
					if not killAura.on then
						swingAt(target)
					end
					combatStatus(string.format(
						"ตี %s · HP %d/%d",
						mob.Name,
						math.max(0, math.floor(mobHum.Health)),
						math.floor(mobHum.MaxHealth)
					))
					local until_ = os.clock() + Combat.SwingInterval
					while os.clock() < until_ do
						if os.clock() < autoDodge.holdUntil or isKnockedDown(hum) or airborneFor(hum) > Combat.MaxAirTime or not pinAbove(hrp, mobRoot) then
							break
						end
						task.wait(0.03)
					end
				end
			end
		end
	end
	autoAttack.running = false
	attackRow.setDesc("ปิดอยู่")
end

local function weaponSlotsText()
	local list = {}
	for i = 1, 5 do
		if weaponSlots[i] then
			list[#list + 1] = tostring(i)
		end
	end
	if #list == 1 then
		return "ใช้ช่อง " .. list[1] .. " ตอน Auto-Attack"
	end
	return "Kill Aura สลับช่อง " .. table.concat(list, "+") .. " ทีละคอมโบ"
end

equipRow = switchRow("Auto-Equip-Weapon", weaponSlotsText(), 1, function() end, {
	choices = { "1", "2", "3", "4", "5" },
	multi = true,
	selected = { 1 },
	onChoice = function(_, picked)
		weaponSlots = picked
		equipRow.setDesc(weaponSlotsText())
	end,
})



-- สองสวิตช์นี้ใช้ลูปเดียวกัน ต่างแค่กรองชื่อเป้า เปิดพร้อมกันไม่ได้
-- ลำดับสำคัญ: ต้องปิดอีกตัวให้เสร็จก่อนค่อยตั้ง flag ไม่งั้น onChange ของตัวที่ถูกปิด
-- จะไปล้าง autoAttack.on ที่เพิ่งตั้ง แล้วลูปตายทันทีที่เกิด
attackRow = switchRow("Auto-Attack", "ปิดอยู่", 2, function(on)
	if on then
		mobOnlyRow.set(false)
		autoAttack.onlySelected = false
		autoAttack.on = true
		attackRow.setDesc("กำลังหาเป้า…")
		task.spawn(attackLoop)
	else
		autoAttack.on = false
	end
end)

-- โหมดเจาะจงตัว: ใช้ชื่อที่ติ๊กไว้ในแผง Auto-Attack-Mob หน้า Main
mobOnlyRow = switchRow("Auto-Attack-Mob", "ตีเฉพาะม็อบที่เลือกไว้หน้า Main", 3, function(on)
	if not on then
		autoAttack.on = false
		autoAttack.onlySelected = false
		mobOnlyRow.setDesc("ตีเฉพาะม็อบที่เลือกไว้หน้า Main")
		return
	end
	if not selectedMob then
		mobOnlyRow.setDesc("ยังไม่ได้เลือกม็อบ ไปติ๊กที่ Main > Auto-Attack-Mob ก่อน")
		mobOnlyRow.set(false)
		return
	end
	attackRow.set(false)
	autoAttack.onlySelected = true
	autoAttack.on = true
	mobOnlyRow.setDesc("ล็อกเป้า " .. selectedMob)
	task.spawn(attackLoop)
end)

-- Auto-Quest ยืมลูปสู้ตัวเดียวกันไปไล่ฆ่าตาม task ------------------------------

local function liveMobCount(name)
	local folder = workspace:FindFirstChild("Humanoids")
	local n = 0
	for _, m in ipairs(folder and folder:GetDescendants() or {}) do
		if m:IsA("Model") and m.Name == name and m:GetAttribute("IsMob") then
			local hum = m:FindFirstChildOfClass("Humanoid")
			local root = m:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 and root.Position.Y > Combat.WorldFloorY then
				n += 1
			end
		end
	end
	return n
end

-- ม็อบในโซนอื่นยังไม่ stream เข้ามา pickTarget เลยมองไม่เห็น ต้องไปยืนที่จุดเกิดก่อน
-- Bandit เกิดใหม่ทุก 30 วิ (SpawnTime) ถ้าฆ่าหมดก็รอที่ Center ไม่ต้องวิ่งหา
local function goToSpawn(center)
	local _, hrp = selfParts()
	if not (hrp and center) or (hrp.Position - center).Magnitude < 60 then
		return
	end
	local stand = groundAt(center) or center + Vector3.new(0, HipOffset, 0)
	placeAt(hrp, facing(stand, center, hrp.CFrame.LookVector), "quest-spawn")
	airSince = nil
end

-- หีบกับของดรอป --------------------------------------------------------------

-- ฆ่าบอสแล้วเกมวางหีบไว้ที่ Workspace.Chests (Common Chest, IsOpen = false)
-- เปิดด้วย ChestPrompt ระยะ 12 แล้วของเด้งออกมาเป็น Part ชื่อ LootDrop ใน Workspace.LootDrops
-- แต่ละชิ้นมี LootDropPrompt "Claim" ระยะ 10 กดแล้วหายภายใน 0.6 วิ ของเข้า Inventory ตรง ๆ
-- วัดจากหีบ Zuko: ได้ Black Kumo Haori กับ One-Horned Imp Mask
local Loot = {
	-- หีบที่อยู่ไกลกว่านี้ไม่ใช่ของบอสที่เพิ่งฆ่า อาจเป็นหีบอีเวนต์อีกฟากแมพ
	ChestRadius = 250,
	-- ยังไม่ได้วัดว่าหีบโผล่ช้ากว่าบอสตายกี่วิ 3 วิคือค่าเผื่อ รอเฉพาะเควสบอส (ฆ่า 1 ตัว)
	ChestWait = 3,
	-- ของบินออกจากหีบใช้ DropFlightTime ~0.52 วิ รอให้ลงพื้นก่อนค่อยกด
	LandWait = 0.8,
}

local function promptPoint(prompt)
	local parent = prompt.Parent
	if parent:IsA("BasePart") then
		return parent.Position
	elseif parent:IsA("Attachment") then
		return parent.WorldPosition
	end
	return nil
end

local function firePromptAt(prompt)
	local _, hrp = selfParts()
	local pos = hrp and promptPoint(prompt)
	if not pos then
		return false
	end
	placeAt(hrp, facing(pos + Vector3.new(0, 2, 3), pos, hrp.CFrame.LookVector), "loot")
	hrp.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.4)
	fireproximityprompt(prompt)
	return true
end

local function closedChests(origin)
	local list = {}
	local folder = workspace:FindFirstChild("Chests")
	for _, chest in ipairs(folder and folder:GetChildren() or {}) do
		local prompt = chest:FindFirstChild("ChestPrompt", true)
		local pos = prompt and promptPoint(prompt)
		if pos and chest:GetAttribute("IsOpen") == false and prompt.Enabled
			and (pos - origin).Magnitude <= Loot.ChestRadius then
			list[#list + 1] = { model = chest, prompt = prompt }
		end
	end
	return list
end

-- เก็บเฉพาะของที่เกมผูกกับเรา (DropOwnerUserId) ของคนอื่นกดไปก็ไม่ได้
local function myDrops()
	local list = {}
	local folder = workspace:FindFirstChild("LootDrops")
	for _, drop in ipairs(folder and folder:GetChildren() or {}) do
		local prompt = drop:FindFirstChild("LootDropPrompt")
		if prompt and drop:GetAttribute("DropOwnerUserId") == LocalPlayer.UserId then
			list[#list + 1] = { part = drop, prompt = prompt, item = drop:GetAttribute("DropItemId") }
		end
	end
	return list
end

-- ใช้ได้สองที่: Auto-Quest หลังฆ่าเสร็จ กับลูป Auto-Chest ตอนไม่ได้รันเควส
-- opts.wait = รอหีบโผล่ (เฉพาะเควสบอส) / opts.stop = ฟังก์ชันบอกให้เลิก / opts.say = ที่แสดงสถานะ
-- คืนรายชื่อของที่เก็บได้
local function collectLoot(opts)
	local stop = opts.stop or function()
		return false
	end
	local say = opts.say or function() end
	local _, hrp = selfParts()
	if not hrp then
		return {}
	end
	local origin = hrp.Position

	local deadline = os.clock() + (opts.wait and Loot.ChestWait or 0)
	local chests = closedChests(origin)
	while #chests == 0 and os.clock() < deadline and not stop() do
		task.wait(0.25)
		chests = closedChests(origin)
	end

	for _, c in ipairs(chests) do
		if stop() then
			break
		end
		say("เปิดหีบ " .. c.model.Name)
		firePromptAt(c.prompt)
		local until_ = os.clock() + 2
		while c.model.Parent and c.model:GetAttribute("IsOpen") == false and os.clock() < until_ do
			task.wait(0.1)
		end
	end
	if #chests > 0 then
		task.wait(Loot.LandWait)
	end

	local got = {}
	for _, d in ipairs(myDrops()) do
		if stop() then
			break
		end
		say("เก็บ " .. tostring(d.item))
		if firePromptAt(d.prompt) then
			local until_ = os.clock() + 3
			while d.part.Parent and os.clock() < until_ do
				task.wait(0.1)
			end
			if not d.part.Parent then
				got[#got + 1] = tostring(d.item)
			end
		end
	end
	return got
end

-- เก็บเป็นฟิลด์ของ Runner ไม่ใช่ local: ไฟล์นี้ชนเพดาน local ระดับบนสุดของ Luau (200 ตัว) แล้ว
Runner.Hunt = {
	-- ไม่เห็นบอสเกินนี้ถือว่าตายแล้ว: 3 วิแรกยังไม่วาร์ป + วาร์ปไปจุดเกิดแล้วรอ stream อีกราว 5 วิ
	BossGoneAfter = 8,
	-- รอ stream ตอนเช็กว่าบอสเกิดหรือยังก่อนรับเควส
	StreamWait = 3,
}

-- ยกเลิกเควสที่ถืออยู่แบบเดียวกับปุ่มกากบาทในแถบเควสของเกม
-- (IndividualQuest: SignalEvent.ToServer("RemoveQuest", ชื่อลูกใน Holder)) ชื่อลูกคือชื่อ QuestInstance
function Runner.abandonQuest(taskName)
	local quests = questFolder()
	local holder = quests and quests:FindFirstChild("Holder")
	for _, held in ipairs(holder and holder:GetChildren() or {}) do
		if held:FindFirstChild(taskName, true) then
			pcall(SignalEvent.ToServer, "RemoveQuest", held.Name)
			local untilT = os.clock() + 3
			while held.Parent and os.clock() < untilT do
				task.wait(0.1)
			end
			return not held.Parent
		end
	end
	return false
end

-- วาร์ปไปจุดเกิดแล้วดูว่าบอสอยู่ไหม ใช้ก่อนรับเควสบอส
function Runner.bossAlive(step)
	goToSpawn(step.center)
	local untilT = os.clock() + Runner.Hunt.StreamWait
	repeat
		if liveMobCount(step.hunt) > 0 then
			return true
		end
		task.wait(0.25)
	until os.clock() >= untilT or Runner.cancel
	return false
end

function Runner.hunt(step, index, total)
	-- ปิดสวิตช์ของผู้ใช้ก่อน แล้วรอลูปเดิมออกให้จริง ไม่งั้นสองลูปแย่งกันเขียน CFrame
	attackRow.set(false)
	mobOnlyRow.set(false)
	autoAttack.on = false
	local waitUntil = os.clock() + 3
	while autoAttack.running and os.clock() < waitUntil do
		task.wait(0.05)
	end

	goToSpawn(step.center)
	autoAttack.target = step.hunt
	autoAttack.onlySelected = false
	autoAttack.on = true
	task.spawn(attackLoop)

	local emptySince
	local result, reason = false, "ยกเลิกแล้ว"
	while not Runner.cancel do
		local count = taskProgress(step.task)
		if count == nil then
			-- เควสหายจาก Holder แปลว่าเกมปิดเควสให้แล้วตอนนับครบ
			result, reason = true, nil
			break
		end
		if count >= step.max then
			result, reason = true, nil
			break
		end

		if liveMobCount(step.hunt) == 0 then
			emptySince = emptySince or os.clock()
			if os.clock() - emptySince > 3 then
				goToSpawn(step.center)
			end
			-- บอสตาย (คนอื่นฆ่า หรือยังไม่เกิด) และมีเควสอื่นติ๊กไว้: ยกเลิกเควสนี้ไปทำอันอื่นก่อน
			-- ใช้กับเควสฆ่าตัวเดียวเท่านั้น โจรหมดค่ายชั่วคราวเป็นเรื่องปกติ เกิดใหม่ทุก 30 วิ
			if step.max == 1 and Runner.hasAlternative and os.clock() - emptySince > Runner.Hunt.BossGoneAfter then
				autoAttack.on = false
				autoAttack.target = nil
				Runner.abandonQuest(step.task)
				return false, Runner.BOSS_GONE
			end
		else
			emptySince = nil
		end

		report(string.format("[%d/%d] ฆ่า %s  %d/%d", index, total, step.hunt, count, step.max), Theme.Accent)
		task.wait(0.3)
	end

	autoAttack.on = false
	autoAttack.target = nil

	-- ผู้เล่นปิด Auto-Chest ไว้ = ไม่สนของ ฆ่าเสร็จก็ไปรับเควสต่อเลย
	if result and Runner.lootOn and Runner.lootOn() then
		local got = collectLoot({
			wait = step.max == 1,
			stop = function()
				return Runner.cancel
			end,
			say = function(text)
				report(string.format("[%d/%d] %s", index, total, text), Theme.Accent)
			end,
		})
		if #got > 0 then
			report("ได้ของ: " .. table.concat(got, ", "), Theme.Accent)
			task.wait(1.2)
		end
	end
	return result, reason
end

-- Auto-Dodge: อ่านท่าโจมตีของม็อบแล้วหลบก่อนดาเมจเข้า ------------------------

-- เกมไม่มี attribute บอกว่าม็อบกำลังจะตี (CastTelegraph เป็น 0 ทุกตัว)
-- แต่ทุกหมัดมีแอนิเมชันเริ่มก่อนดาเมจเสมอ วัดกับโจร 5 ท่าคอมโบ:
--   95263713118697  -> ดาเมจตามมา 0.14 วิ
--   117989400565423 -> 0.24 วิ
--   122637417128576 -> 0.24 วิ
--   82697249356744  -> 0.24 วิ
--   81068731814520  -> 0.37 วิ (หมัดปิดคอมโบ -6)
-- ม็อบชนิดอื่นใช้ท่าคนละชุด เลยต้องเรียนรู้เองตอนเล่น: ทุกครั้งที่เราเสียเลือด
-- ย้อนดูท่าที่ม็อบใกล้ ๆ เพิ่งเริ่มเล่น แล้วนับว่าท่าไหนตามด้วยดาเมจบ่อย
-- ส่วน Auto-Dodge อยู่ใน do ... end เพราะไฟล์ชนเพดาน local ระดับบนสุดของ Luau (200 ตัว)
-- ข้างนอกใช้แค่ stopDodge (ตอน unload) เลยประกาศไว้ข้างนอกตัวเดียว
local stopDodge
do
local Dodge = {
	-- ท่าที่ม็อบห่างเกินนี้เล่น ไม่ต้องหลบ โจรตีโดนที่ระยะราว 5 stud ทุกครั้งที่วัด
	ThreatRadius = 12,
	-- ถอยออกไปเท่านี้ พ้นระยะหมัดประชิดทุกตัวที่เห็นมา
	BlinkDistance = 12,
	-- ค้างที่จุดหลบนานเท่านี้ ครอบช่วงท่าที่ช้าสุดที่วัดได้ (0.37 วิ) บวกดีเลย์ส่งตำแหน่ง
	HoldTime = 0.5,
	-- ม็อบที่ออกท่าในระยะ ThreatRadius + ค่านี้ ยังนับว่ากำลังคอมโบใส่เรา ให้รอข้างนอกต่อ
	-- หลบไป 12 stud แล้วท่าถัดไปมาเริ่มที่ 12-15 stud (เดินตามมา) เลยเผื่อไว้ 8
	WaitMargin = 8,
	-- ย้อนดูท่าที่เริ่มก่อนโดนตีไม่เกินนี้ ท่าช้าสุดที่วัดได้ 0.37 วิ
	LookBack = 0.6,
	-- ท่าที่ตามด้วยดาเมจอย่างน้อยเท่านี้ครั้ง และคิดเป็นสัดส่วนนี้ขึ้นไปของที่เห็นเล่น ถือว่าเป็นท่าตี
	LearnHits = 2,
	LearnRatio = 0.3,
	SaveFile = "PathSlayer/learned_attacks.json",
}

-- ชื่อแทร็กพวกนี้คือเดิน วิ่ง ร่วง ยืนเฉย ไม่ใช่ท่าตี ไม่ต้องนับเลย
local Locomotion = { WalkAnim = true, run = true, fall = true, idle = true, jump = true, climb = true, swim = true }

local HttpService = game:GetService("HttpService")

local attackAnims = {
	["rbxassetid://95263713118697"] = true,
	["rbxassetid://117989400565423"] = true,
	["rbxassetid://122637417128576"] = true,
	["rbxassetid://82697249356744"] = true,
	["rbxassetid://81068731814520"] = true,
}
local animSeen, animHits = {}, {}

-- ท่าที่เรียนได้เก็บไว้ในไฟล์ของ executor รันรอบหน้าไม่ต้องเริ่มจากศูนย์
local function loadLearned()
	if typeof(isfile) ~= "function" or not isfile(Dodge.SaveFile) then
		return 0
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(Dodge.SaveFile))
	end)
	if not ok or type(data) ~= "table" then
		return 0
	end
	local n = 0
	for id in pairs(data) do
		if not attackAnims[id] then
			attackAnims[id] = true
			n += 1
		end
	end
	return n
end

local function saveLearned()
	if typeof(writefile) ~= "function" then
		return
	end
	-- คนที่รันผ่าน loadstring ไม่มีโฟลเดอร์ PathSlayer ใน workspace ของ executor
	-- writefile ลงโฟลเดอร์ที่ไม่มีอยู่จะล้มเงียบ ๆ แล้วท่าที่เรียนรู้หายทุกครั้งที่ปิดเกม
	local folder = Dodge.SaveFile:match("^(.+)/[^/]+$")
	if folder and typeof(makefolder) == "function" and typeof(isfolder) == "function" and not isfolder(folder) then
		pcall(makefolder, folder)
	end
	pcall(writefile, Dodge.SaveFile, HttpService:JSONEncode(attackAnims))
end

local recentAnims = {} -- { t, id, mob }
local watchedMobs = {}
local dodgeConns = {}

local function learnedCount()
	local n = 0
	for _ in pairs(attackAnims) do
		n += 1
	end
	return n
end

-- หลบทันทีในเฟรมที่ม็อบเริ่มท่า ไม่รอ task.wait
-- ทิศหลบคือตรงข้ามกับม็อบตัวที่ออกท่า แนวนอนล้วน แล้ววางบนพื้นจริง
local function blinkAwayFrom(mobRoot)
	local _, hrp, hum = selfParts()
	if not (hrp and hum and hum.Health > 0) or isKnockedDown(hum) or hrp.Position.Y < Combat.WorldFloorY then
		return
	end
	local away = Vector3.new(hrp.Position.X - mobRoot.Position.X, 0, hrp.Position.Z - mobRoot.Position.Z)
	away = away.Magnitude > 0.5 and away.Unit or hrp.CFrame.LookVector * -1
	away = Vector3.new(away.X, 0, away.Z).Unit
	local spot = hrp.Position + away * Dodge.BlinkDistance
	spot = groundAt(spot) or spot
	if placeAt(hrp, facing(spot, mobRoot.Position, away * -1), "dodge") then
		hrp.AssemblyLinearVelocity = Vector3.zero
		autoDodge.holdUntil = os.clock() + Dodge.HoldTime
		autoDodge.dodges += 1
	end
end

local function watchMob(mob)
	if watchedMobs[mob] then
		return
	end
	local hum = mob:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	watchedMobs[mob] = animator.AnimationPlayed:Connect(function(trackPlayed)
		if not autoDodge.on then
			return
		end
		local id = trackPlayed.Animation and trackPlayed.Animation.AnimationId or ""
		if Locomotion[trackPlayed.Name] or id == "" then
			return
		end
		local mobRoot = mob:FindFirstChild("HumanoidRootPart")
		local _, hrp = selfParts()
		if not (mobRoot and hrp) then
			return
		end
		local dist = (mobRoot.Position - hrp.Position).Magnitude
		if dist > Dodge.ThreatRadius + 6 then
			return
		end

		recentAnims[#recentAnims + 1] = { t = os.clock(), id = id }
		animSeen[id] = (animSeen[id] or 0) + 1
		local trace = _G.PathSlayerTrace
		if trace then
			trace[#trace + 1] = string.format("%.2f ANIM %s %s d=%.1f %s", os.clock(), mob.Name,
				id:match("%d+$") or id, dist, attackAnims[id] and "ATTACK" or "?")
		end

		if attackAnims[id] and dist <= Dodge.ThreatRadius then
			blinkAwayFrom(mobRoot)
			dodgeRow.setDesc(string.format("หลบท่า %s · หลบไป %d ครั้ง", mob.Name, autoDodge.dodges))
		elseif attackAnims[id] and dist <= Dodge.ThreatRadius + Dodge.WaitMargin then
			-- ม็อบยังคอมโบต่ออยู่นอกระยะ ไม่ต้องวาร์ป แต่ห้ามเดินกลับเข้าไปหา
			-- 3 หมัดที่โดนในเทสต์ล่าสุดเป็นแบบนี้ทั้งหมด: หลบทัน แล้วพ้น HoldTime
			-- ก็วิ่งกลับเข้าไปตอนท่าถัดไปเพิ่งเริ่มที่ระยะ 12.0-12.4 stud
			autoDodge.holdUntil = math.max(autoDodge.holdUntil, os.clock() + Dodge.HoldTime)
		end
	end)
end

-- เราเสียเลือด = มีท่าที่ยังไม่รู้จัก หรือหลบไม่ทัน ย้อนดูท่าที่เพิ่งเกิดแล้วนับคะแนน
local function onDamaged(lost)
	autoDodge.hitsTaken += 1
	local now = os.clock()
	local counted = {}
	for i = #recentAnims, 1, -1 do
		local e = recentAnims[i]
		if now - e.t > Dodge.LookBack then
			break
		end
		if not counted[e.id] then
			counted[e.id] = true
			animHits[e.id] = (animHits[e.id] or 0) + 1
			local hits, seen = animHits[e.id], animSeen[e.id] or 1
			if not attackAnims[e.id] and hits >= Dodge.LearnHits and hits / seen >= Dodge.LearnRatio then
				attackAnims[e.id] = true
				autoDodge.learned += 1
				saveLearned()
			end
		end
	end
	dodgeRow.setDesc(string.format(
		"โดน -%.0f · หลบ %d · โดน %d · รู้จัก %d ท่า",
		lost,
		autoDodge.dodges,
		autoDodge.hitsTaken,
		learnedCount()
	))
end

function stopDodge()
	for _, c in ipairs(dodgeConns) do
		c:Disconnect()
	end
	table.clear(dodgeConns)
	for mob, c in pairs(watchedMobs) do
		c:Disconnect()
		watchedMobs[mob] = nil
	end
	table.clear(recentAnims)
	autoDodge.holdUntil = 0
end

local function startDodge()
	stopDodge()
	local restored = loadLearned()

	-- ต่อ Animator ของม็อบที่เข้ามาใกล้ ม็อบใหม่ spawn ตลอดเลยต้องกวาดเรื่อย ๆ
	-- ทุก 0.25 วิพอ เพราะม็อบที่อยู่ห่าง 18 stud ต้องใช้เวลาเดินเข้ามาอยู่แล้ว
	local lastScan = 0
	dodgeConns[#dodgeConns + 1] = game:GetService("RunService").Heartbeat:Connect(function()
		if os.clock() - lastScan < 0.25 then
			return
		end
		lastScan = os.clock()
		local _, hrp = selfParts()
		local folder = workspace:FindFirstChild("Humanoids")
		if not (hrp and folder) then
			return
		end
		for _, m in ipairs(folder:GetDescendants()) do
			if m:IsA("Model") and m:GetAttribute("IsMob") and not watchedMobs[m] then
				local r = m:FindFirstChild("HumanoidRootPart")
				if r and (r.Position - hrp.Position).Magnitude < 40 then
					watchMob(m)
				end
			end
		end
		for mob, c in pairs(watchedMobs) do
			if not mob.Parent then
				c:Disconnect()
				watchedMobs[mob] = nil
			end
		end
		while #recentAnims > 0 and os.clock() - recentAnims[1].t > 2 do
			table.remove(recentAnims, 1)
		end
	end)

	-- เชื่อมเลือดใหม่ทุกครั้งที่เกิดใหม่ Humanoid ตัวเก่าหายไปพร้อมตัวละคร
	local function hookHealth(char)
		local hum = char:WaitForChild("Humanoid", 5)
		if not hum then
			return
		end
		local last = hum.Health
		dodgeConns[#dodgeConns + 1] = hum.HealthChanged:Connect(function(health)
			local lost = last - health
			last = health
			if lost > 0 and autoDodge.on then
				onDamaged(lost)
			end
		end)
	end
	if LocalPlayer.Character then
		task.spawn(hookHealth, LocalPlayer.Character)
	end
	dodgeConns[#dodgeConns + 1] = LocalPlayer.CharacterAdded:Connect(hookHealth)

	dodgeRow.setDesc(string.format(
		"เฝ้าท่าตีอยู่ · รู้จัก %d ท่า%s",
		learnedCount(),
		restored > 0 and (" (โหลดจากไฟล์ " .. restored .. ")") or ""
	))
end

dodgeRow = switchRow("Auto-Dodge", "ปิดอยู่", 4, function(on)
	autoDodge.on = on
	if on then
		autoDodge.dodges, autoDodge.hitsTaken, autoDodge.learned = 0, 0, 0
		startDodge()
	else
		stopDodge()
		dodgeRow.setDesc("ปิดอยู่")
	end
end)

end

-- Kill Aura: ยิงคำสั่งตีตรงไปที่เซิร์ฟเวอร์ ไม่ผ่านการคลิก ----------------------

-- ดักจากหมัดจริงได้ว่าทุกหมัดเกมส่งแค่นี้ ไม่มีตัวระบุเป้าเลย:
--   SignalEvent.Event:FireServer("Combat_Service", "Combat", <ลำดับคอมโบ>, false, 0.13, false, nil)
-- เซิร์ฟเวอร์คิด hitbox จากตำแหน่งและทิศของตัวเราเอง เลยต้องยืน/ลอยติดม็อบอยู่ดี
-- วัดดาเมจกับโจรตามความถี่ที่ยิง:
--   ทุก 0.45 วิ ~11 ดาเมจ/วิ   ทุก 0.25 วิ ~11   ทุก 0.10 วิ ~1 (เซิร์ฟเวอร์ทิ้งคำสั่งที่ถี่เกิน)
local Aura = {
	-- ติ๊กหลายช่องแล้วสลับอาวุธ วัดกับโจร 2 รอบ รอบละ 15 วิ (ดาเมจ/วิ):
	--   หมัดอย่างเดียว 7.4 / 4.5   ดาบอย่างเดียว 2.4 / 6.3   สลับทุกหมัด 5.7 / 1.9
	-- สลับอาวุธไม่ได้ทำให้เร็วขึ้น เก็บไว้เพื่อใช้คอมโบของแต่ละอาวุธเท่านั้น
	-- เซิร์ฟเวอร์รับหมัดได้แค่ ~1.2-2.2 ครั้ง/วิ ดาเมจต่อหมัด ~5.3 คงที่ ยิงถี่กว่านี้ไม่ช่วย

	-- ม็อบโดนหมัดติดกัน ~4-5 ครั้งแล้วล้ม (Humanoid state = Physics) นาน ~1.0 วิทุกครั้ง
	-- ยิงตอนล้มไม่เข้าเลย วัดได้ 0/15 หมัด ทั้งที่ตอนยืนเข้า 30/46
	-- เลขคอมโบที่ส่งไปไม่เกี่ยว ลองวน 1-4 / ส่ง 1 ตลอด / ส่ง 2 ตลอด ยังล้ม 5-6 ครั้งต่อ 20 วิเท่าเดิม
	-- เปลี่ยนไปตีตัวที่ยืนอยู่ก็ไม่ช่วยที่ค่ายโจร เพราะเหลือตัวเป็นแค่ 1-2 ตัว (สลับได้ 1 ครั้งใน 60 วิ)
	-- ที่ได้ผลคือหยุดยิงตอนล้ม แล้วยิงทันทีที่ลุก วัดกับโจร รอบละ 20 วิ (ดาเมจ/วิ):
	--   ชุด 5 นัด +พัก 0.8 (แบบก่อนหน้า)   7.96 / 9.08
	--   รอลุก + ยิงทุก 0.1 วิ              10.84 / 12.25
	--   รอลุก + ยิงทุก 0.2 วิ              12.19 / 12.21   <- นิ่งสุด ยิงน้อยสุด
	--   รอลุก + ชุด 5 นัด +0.3             12.58 / 11.70
	Interval = 0.2,
	-- ล้มนานสุดที่เห็นคือ 1.07 วิ เกิน 2 วิถือว่าค้าง ยิงต่อไปเลย
	DownTimeout = 2,
	-- คอมโบหมัดที่เห็นจากการคลิกจริงนับ 1,2,3 ต่อเนื่อง ตั้งวน 5 ตามจำนวนท่าคอมโบของโจร
	ComboLength = 5,
	-- เว้นช่วงนานกว่านี้ เกมเริ่มคอมโบใหม่ที่ 1 เอง เลยรีเซ็ตตาม
	ComboReset = 1.2,
	-- hitbox ฝั่งเซิร์ฟเวอร์อยู่รอบตัวเรา ไม่ใช่แค่ด้านหน้า วัดกับโจรรอบละ 5 วิ (หมัดเข้า/ยิง):
	--   ยืนห่าง 3 stud 24%   5 stud 40%   7 / 9 / 11 / 14 / 18 / 25 stud 0%
	--   ลอยสูง 3 stud 50%   6 stud ขึ้นไป 0%   หันหลังให้ที่ 3 stud ยังเข้า 40%
	-- ตั้งระยะในโค้ดให้ไกลกว่านี้ไม่ช่วย เซิร์ฟเวอร์เป็นคนตัดสิน
	Range = 6,

	-- Kill Aura ระยะไกล: วาร์ปไปข้างม็อบแค่ช่วงยิง แล้ววาร์ปกลับที่เดิม
	-- ต้องค้างข้างม็อบให้เซิร์ฟเวอร์เห็นตำแหน่งก่อน วัดจากจุดห่าง 30 stud (หมัดเข้าใน 6 วิ):
	--   ยิงเฟรมเดียวกับที่วาร์ป 0   รอ 1 เฟรม 0   ค้าง 0.1 วิ 6   ค้าง 0.2 วิ 7   ค้าง 0.3 วิ 8
	--   (เทียบยืนติดม็อบตลอด 10)
	-- ระยะวาร์ปที่ยังตีเข้า ค้าง 0.3 วิ: 30 stud 28%   80 stud 41%   150 stud 65%
	-- 250 stud ขึ้นไปม็อบหายจากแมพ เพราะเกมลบม็อบที่ไม่มีผู้เล่นใกล้เกิน DespawnDistance = 250
	BlinkRange = 150,
	BlinkBefore = 0.12,
	BlinkAfter = 0.18,
}

local combatSignal = ReplicatedStorage:FindFirstChild("Communication")
combatSignal = combatSignal
	and combatSignal:FindFirstChild("ServerAndClient")
	and combatSignal.ServerAndClient:FindFirstChild("Signals")
	and combatSignal.ServerAndClient.Signals:FindFirstChild("SignalEvent")
	and combatSignal.ServerAndClient.Signals.SignalEvent:FindFirstChild("Event")


-- ม็อบที่ "ล้ม" ค้างนานเกิน DownTimeout ไม่ได้ล้มจริง บอสบางตัวอยู่ในสถานะ Physics ตลอด
-- (Gyutai 3000 HP ค้าง Physics ทั้ง 25 วิที่ดู) ถ้าไม่จำไว้ Aura จะนั่งรอลุกไม่จบ
-- เก็บแบบ weak key ม็อบตายแล้วถูกลบ แถวนี้หายไปเอง
local stuckDown = setmetatable({}, { __mode = "k" })

-- ม็อบที่ใกล้ที่สุดในระยะ คืน ม็อบ, ล้มอยู่ไหม
-- ต้องเป็นตัวที่ใกล้ที่สุดเสมอ เพราะเซิร์ฟเวอร์ตีตามตำแหน่งและทิศของเรา ไม่ได้ตีตามเป้าที่เลือก
-- เคยให้เลือกตัวที่ยืนอยู่ก่อน ผลคือ Auto-Attack ลอยอยู่เหนือตัวที่ล้ม แต่ Aura เห็นอีกตัวยืนเลยยิงไปเรื่อย
-- 17 นัดใน 5 วิ HP ค้าง 16/45 ไม่ลดเลย
-- skipBoss ใช้กับโหมดระยะไกล: วาร์ปไปตีบอสเองโดยไม่ได้สั่ง ทดสอบแล้วมันไปตี Gyutai 3000 HP
local function mobInReach(origin, range, skipBoss)
	local folder = workspace:FindFirstChild("Humanoids")
	local best, bestD
	for _, m in ipairs(folder and folder:GetDescendants() or {}) do
		-- เควส Kazu ต้องฆ่าสายลับที่ชื่อ *Civilian* ซึ่งอยู่ใน NeverTarget
		-- ตอน Auto-Quest ล็อกเป้าไว้ ลูปสู้ไม่คลิกเองเพราะ Aura เปิดอยู่ ถ้า Aura ข้ามตัวนี้ก็ไม่มีใครตีเลย
		local wanted = m.Name == autoAttack.target
		local allowed = wanted or not Combat.NeverTarget[m.Name]
		if m:IsA("Model") and m:GetAttribute("IsMob") and allowed then
			local hum = m:FindFirstChildOfClass("Humanoid")
			local root = m:FindFirstChild("HumanoidRootPart")
			local tierOk = not skipBoss or wanted or (hum and hum.MaxHealth <= Combat.SkipBossAbove)
			if hum and root and hum.Health > 0 and root.Position.Y > Combat.WorldFloorY and tierOk then
				local d = (root.Position - origin).Magnitude
				if d <= (range or Aura.Range) and (not bestD or d < bestD) then
					best, bestD = m, d
				end
			end
		end
	end
	local down = best ~= nil and not stuckDown[best] and isKnockedDown(best:FindFirstChildOfClass("Humanoid"))
	return best, down
end

-- ช่องถัดไปที่จะใช้ตี: วนตามช่องที่ติ๊กไว้ ข้ามช่องว่างใน toolbar
local function nextAuraSlot()
	local list = {}
	for i = 1, 5 do
		if weaponSlots[i] and slotHasItem(i) then
			list[#list + 1] = i
		end
	end
	if #list == 0 then
		return nil
	end
	killAura.slotIndex = killAura.slotIndex % #list + 1
	return list[killAura.slotIndex], #list
end



-- ยิงหมัดหนึ่งครั้งด้วยช่องอาวุธที่ถึงคิว คืนช่องที่ใช้ (nil = ไม่มีช่องให้ใช้)
-- หลายช่อง: สลับอาวุธทุกครบคอมโบ ตั้งค่า Items_Config ตรง ๆ ไม่มีดีเลย์กดปุ่ม
-- คอมโบแยกนับต่ออาวุธ สลับไปมาแล้วแต่ละอันยังเดินท่า 1,2,3 ต่อของมันเอง
local function auraFire()
	local now = os.clock()
	local slot = killAura.slot
	local combo = slot and killAura.comboBySlot[slot] or 1
	if not slot or combo == 1 then
		slot = nextAuraSlot()
		killAura.slot = slot
	end
	if not slot then
		return nil
	end
	equipSlot(slot)
	combo = killAura.comboBySlot[slot] or 1
	if now - (killAura.lastBySlot[slot] or 0) > Aura.ComboReset then
		combo = 1
	end
	combatSignal:FireServer("Combat_Service", "Combat", combo, false, 0, false, nil)
	killAura.comboBySlot[slot] = combo % Aura.ComboLength + 1
	killAura.lastBySlot[slot] = now
	killAura.lastFire = now
	killAura.fires += 1
	return slot
end

-- ค้างตัวเหนือหัวม็อบทุกเฟรมตามเวลาที่กำหนด ม็อบเดินอยู่ วาร์ปครั้งเดียวแล้วตำแหน่งจะเพี้ยน
local function holdAbove(hrp, root, seconds)
	local untilT = os.clock() + seconds
	repeat
		if not (root.Parent and hrp.Parent) then
			return false
		end
		local spot = root.Position + Vector3.new(0, Combat.HoverHeight, 0)
		placeAt(hrp, facing(spot, root.Position, hrp.CFrame.LookVector), "blink")
		hrp.AssemblyLinearVelocity = Vector3.zero
		game:GetService("RunService").Heartbeat:Wait()
	until os.clock() >= untilT
	return true
end

local function blinkShot(hrp, mob)
	local root = mob:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local home = hrp.CFrame
	local slot
	if holdAbove(hrp, root, Aura.BlinkBefore) then
		slot = auraFire()
		holdAbove(hrp, root, Aura.BlinkAfter)
	end
	placeAt(hrp, home, "blink-back")
	hrp.AssemblyLinearVelocity = Vector3.zero
	return slot
end

local function auraLoop()
	while killAura.on do
		local _, hrp, hum = selfParts()
		-- ระหว่างหลบ ตัวอยู่ไกลเป้า ยิงไปก็ไม่เข้า ได้แต่เผาโควตาความถี่ของเซิร์ฟเวอร์
		if hrp and hum and hum.Health > 0 and not isKnockedDown(hum) and os.clock() >= autoDodge.holdUntil then
			local mob, down = mobInReach(hrp.Position)
			local far = false
			-- ระยะไกลใช้ตอนไม่ได้เปิด Auto-Attack เท่านั้น Auto-Attack ลอยติดม็อบให้อยู่แล้ว
			-- ถ้าวาร์ปซ้อนกัน สองลูปจะแย่งเขียน CFrame
			if not mob and killAura.far and not autoAttack.on then
				mob, down = mobInReach(hrp.Position, Aura.BlinkRange, true)
				far = mob ~= nil
			end
			local mobHum = mob and mob:FindFirstChildOfClass("Humanoid")
			if mob and down then
				-- ม็อบล้มอยู่ ตีไม่เข้า รอจนลุกแล้วยิงทันที ไม่ต้องรอครบรอบ Interval
				local waitUntil = os.clock() + Aura.DownTimeout
				auraRow.setDesc(string.format("รอ %s ลุก · HP %d/%d", mob.Name,
					math.max(0, math.floor(mobHum.Health)), math.floor(mobHum.MaxHealth)))
				while killAura.on and mob.Parent and mobHum.Health > 0 and isKnockedDown(mobHum) and os.clock() < waitUntil do
					task.wait()
				end
				-- ล้มจริงลุกภายใน ~1.07 วิเสมอ ครบ DownTimeout ยังไม่ลุกคือสถานะถาวรของตัวนั้น ตีต่อได้เลย
				if mob.Parent and mobHum.Health > 0 and isKnockedDown(mobHum) then
					stuckDown[mob] = true
				end
			elseif mob then
				local slot = far and blinkShot(hrp, mob) or (not far and auraFire())
				if slot then
					auraRow.setDesc(string.format("%s %s · HP %d/%d · ช่อง %d · ยิงไป %d",
						far and "วาร์ปตี" or "ตี", mob.Name, math.max(0, math.floor(mobHum.Health)),
						math.floor(mobHum.MaxHealth), slot, killAura.fires))
				end
				-- วาร์ปตีใช้เวลาไปแล้ว BlinkBefore + BlinkAfter (0.3 วิ) ไม่ต้องรอซ้ำ
				task.wait(far and 0.05 or Aura.Interval)
			else
				task.wait(Aura.Interval)
			end
		else
			task.wait(Aura.Interval)
		end
	end
	auraRow.setDesc("ปิดอยู่")
end

auraRow = switchRow("Kill Aura", "ปิดอยู่", 5, function(on)
	if on and not combatSignal then
		auraRow.setDesc("หา SignalEvent ของเกมไม่เจอ")
		auraRow.set(false)
		return
	end
	killAura.on = on
	if on then
		killAura.fires = 0
		auraRow.setDesc("รอม็อบเข้าระยะ " .. Aura.Range .. " stud")
		task.spawn(auraLoop)
	end
end)

-- ใช้คู่กับ Kill Aura: ม็อบอยู่นอกระยะหมัด (6 stud) แต่ไม่เกิน 150 stud จะวาร์ปไปตีแล้วกลับที่เดิม
-- ไม่ทำงานตอนเปิด Auto-Attack เพราะ Auto-Attack ลอยติดม็อบอยู่แล้ว
switchRow("Kill Aura ระยะไกล", "วาร์ปไปตีม็อบในระยะ " .. Aura.BlinkRange .. " stud แล้วกลับที่เดิม", 6, function(on)
	killAura.far = on
	if on and not killAura.on then
		auraRow.set(true)
	end
end)

-- Auto-Quest อยู่เหนือไฟล์ อ้าง auraRow ตรง ๆ ไม่ได้ เลยผูกผ่าน Runner
-- ผ่าน auraRow.set เพื่อให้สวิตช์บนจอขยับตามจริง ไม่ใช่แค่ตั้ง flag เงียบ ๆ
function Runner.setAura(on)
	auraRow.set(on)
end

function Runner.auraOn()
	return killAura.on
end

-- Auto-Chest: เปิดหีบกับเก็บของดรอปที่เป็นของเรา ------------------------------

-- ตอนรันเควส Runner.hunt เป็นคนเก็บเองหลังฆ่าเสร็จ ลูปนี้ถอยให้ ไม่งั้นวาร์ปแย่งกัน
-- ตอนไม่ได้รันเควส (ตีเองหรือ Auto-Attack) ลูปนี้เก็บให้ทุก 1.5 วิ
-- ระหว่าง Auto-Attack ก็หยุดรอ ไม่งั้นมันวาร์ปไปเก็บของแล้วลูปสู้ดึงกลับกลางทาง
local autoChest = { on = false, got = 0 }
local chestRow

local function chestLoop()
	while autoChest.on do
		if not Runner.active and not autoAttack.on then
			local got = collectLoot({
				stop = function()
					return not autoChest.on or Runner.active
				end,
				say = function(text)
					chestRow.setDesc(text)
				end,
			})
			if #got > 0 then
				autoChest.got += #got
				chestRow.setDesc(string.format("ได้ %s · รวม %d ชิ้น", table.concat(got, ", "), autoChest.got))
			end
		end
		task.wait(1.5)
	end
	chestRow.setDesc("ปิดอยู่ · Auto-Quest จะไม่เปิดหีบ/เก็บของ")
end

chestRow = switchRow("Auto-Chest", "เปิดหีบบอสและเก็บของดรอปของเรา", 7, function(on)
	autoChest.on = on
	if on then
		chestRow.setDesc("รอหีบหรือของดรอปในระยะ " .. Loot.ChestRadius .. " stud")
		task.spawn(chestLoop)
	end
end)
-- เปิดไว้ตั้งแต่แรก ผู้เล่นที่ไม่อยากได้ของค่อยปิดเอง
chestRow.set(true)

function Runner.lootOn()
	return autoChest.on
end

placeholderTab("Settings")

-- การโต้ตอบหน้าต่าง ---------------------------------------------------------

local dragStart, startPos
track(titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragStart = input.Position
		startPos = root.Position
	end
end))
track(UserInputService.InputChanged:Connect(function(input)
	if not dragStart then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local d = input.Position - dragStart
	-- เซ็ตตรง ๆ ไม่ tween ระหว่างลาก ไม่งั้นหน้าต่างตามเมาส์ไม่ทันแล้วรู้สึกลื่นไถล
	root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
end))
track(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragStart = nil
	end
end))

local minimized = false
track(minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	minBtn.Text = minimized and "+" or "-"
	tween(root, { Size = UDim2.fromOffset(Config.Width, minimized and Config.TitleH or Config.Height) })
end))

local hidden = false
local function setVisible(show)
	hidden = not show
	if show then
		root.Visible = true
	end
	-- ย่อแค่ 0.96 เพราะ root ไม่มี AnchorPoint แบบ scale ย่อเยอะแล้วขอบกระตุก
	tween(root, {
		Size = UDim2.fromOffset(
			show and Config.Width or Config.Width * 0.96,
			(minimized and Config.TitleH or Config.Height) * (show and 1 or 0.96)
		),
	})
	if not show then
		task.delay(Config.SlideTime, function()
			if hidden then
				root.Visible = false
			end
		end)
	end
end

local function unload()
	_G.PathSlayerUnload = nil
	for _, conn in ipairs(conns) do
		conn:Disconnect()
	end
	table.clear(conns)
	table.clear(tabs)
	table.clear(shopRows)
	Runner.stop()
	-- ลูป auto-attack วนอยู่ใน task ของตัวเอง ต้องสั่งหยุดด้วย flag ไม่งั้นค้างหลัง UI หาย
	autoAttack.on = false
	autoDodge.on = false
	killAura.on = false
	autoChest.on = false
	stopDodge()
	table.clear(questRows)
	table.clear(mobRows)
	table.clear(features)
	activeTab = nil
	shopSelected = nil
	questSelected = nil
	questSelectedRow = nil
	itemCache = nil
	questCache = nil
	screen:Destroy()
end
_G.PathSlayerUnload = unload

track(closeBtn.MouseButton1Click:Connect(unload))

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Config.ToggleKey then
		setVisible(hidden)
	elseif input.KeyCode == Config.UnloadKey then
		unload()
	end
end))

-- เลือกแท็บแรกหลังเฟรมแรก เพราะ indicator อ่าน AbsolutePosition ที่ UIListLayout ยังไม่ได้คำนวณ
task.defer(function()
	selectTab(tabs[1])
end)

root.Size = UDim2.fromOffset(Config.Width, Config.Height * 0.94)
tween(root, { Size = UDim2.fromOffset(Config.Width, Config.Height) }, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out))
