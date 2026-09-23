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

-- หมวดในแผง = ชื่อโฟลเดอร์ใน ReplicatedStorage.Items
-- ของสวมใส่คือโฟลเดอร์ที่ทุกโมดูลมี EquipType 3-5 (ตรวจครบทั้ง 256 ตัว ไม่มีปนหมวดอื่น)
-- Quest Items / Materials / Potions ไม่ใส่ ใส่ไม่ได้และส่วนใหญ่ได้จากเควส
Game.WeaponGroups = { "Katana", "Weapons" }
Game.WearGroups = { "Head", "Face", "Ear", "Neck", "Back", "Waist", "Haori", "Outfits" }

-- โมดูลไอเทมรวมกว่า 300 ตัว require ครั้งเดียวแล้วแคช ไม่งั้นทุกครั้งที่รีเฟรชร้านจะ require ซ้ำ
local itemCache
local function allWeaponItems()
	if itemCache then
		return itemCache
	end
	itemCache = {}
	local items = ReplicatedStorage:FindFirstChild("Items")
	for _, groups in ipairs({ Game.WeaponGroups, Game.WearGroups }) do
		for _, folderName in ipairs(groups) do
			local folder = items and items:FindFirstChild(folderName)
			for _, m in ipairs(folder and folder:GetChildren() or {}) do
				if m:IsA("ModuleScript") then
					itemCache[#itemCache + 1] = {
						name = m.Name,
						group = folderName,
						wear = groups == Game.WearGroups,
						def = require(m),
					}
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
-- ยังหาสูตรไม่เจอ แต่ HUD ซ้ายบนเขียนไว้ "Lv 56" (LeftHudPortion.ExpFrame.Context.Level) อ่านจากตรงนั้น
-- attribute ของผู้เล่น/ตัวละครตรวจแล้วไม่มีเลเวล เก็บไว้เผื่อเกมเพิ่มทีหลัง
-- หาไม่เจอทั้งคู่คืน nil ฝั่ง UI แสดงเงื่อนไขเลเวลเป็นคำเตือนแทนการล็อก จะได้ไม่โกหกผู้ใช้
function Game.level()
	local hud = LocalPlayer.PlayerGui:FindFirstChild("ComponentsHolder")
	hud = hud and hud:FindFirstChild("LeftHudPortion")
	hud = hud and hud:FindFirstChild("ExpFrame")
	local label = hud and hud:FindFirstChild("Level", true)
	local shown = label and label:IsA("TextLabel") and tonumber(label.Text:match("(%d+)"))
	if shown then
		return shown
	end
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

-- สูตรตีที่ให้ของชิ้นนี้เป็นชิ้นใหม่ เรียงตามรหัสให้เลือกซ้ำได้ผลเดิมทุกครั้ง
-- สูตร _t2/_t3 คืออัปเทียร์ของที่ถืออยู่ (วัตถุดิบตัวแรกคือของชิ้นเดียวกัน) ไม่ได้ของเพิ่ม เลยตัดทิ้ง
-- ของบางชิ้นมีหลายสูตร เช่น Firstlight Katana ตีได้จากดาบฐาน 4 เล่ม
function Game.recipesFor(itemName)
	local list = {}
	for id, recipe in pairs(Crafting and Crafting.Definitions or {}) do
		local first = recipe.required and recipe.required[1]
		if recipe.result == itemName and not (first and first.name == itemName) then
			list[#list + 1] = { id = id, recipe = recipe }
		end
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

-- โรงตีที่ไปถึงได้จากแมพนี้ กับ NPC ที่ต้องไปยืนข้าง ๆ (เซิร์ฟตอบ "You need to be at the forge" ถ้ายืนไกล)
-- Crafting.StationNpcs บอก Ouwigahara = Blacksmith Togane ด้วย แต่ Togane ในแมพนี้มีตัวเดียวที่ Hidden Mist Village
-- และหน้าคุยของเขาเปิดโต๊ะ Station "Ouwland" ส่วน Ouwigahara อยู่อีกแมพหลังเควสประตู Lv 65
-- ลองยิง CraftRecipe ข้าง Togane แล้ว: shotgun (Ouwland) ตอบ "You need 100 Metal Scraps" = ยืนถูกโรง
Game.Forges = { ["Hidden Mist"] = "Yagane", Ouwland = "Blacksmith Togane" }

-- เงินไม่มีทางหาเพิ่มจากสคริปต์ ขาดเมื่อไรก็จบตรงนั้น
Game.Currencies = { Wen = true, RunPoints = true }

-- ของที่ไม่มีในตารางดรอป ร้าน หรือสูตร แต่บทพูดของเกมบอกไว้ว่าได้จากไหน
Game.SourceHints = {
	-- Yagane (Dialogues.Yap): "Crude Iron is issued at Final Selection" ไม่มีเควสไหนแจกตรง ๆ เซิร์ฟเวอร์ให้เอง
	["Crude Iron Ingot"] = "แจกที่ Final Selection",
}

-- ร้านที่ขายผ่านหน้าคุย NPC ไม่มีแผง เกมล็อกหน้าร้านไว้ด้วยเควส (BeforeRun ใน Dialogues.Yap)
-- ไม่ได้อยู่ใน RequiresQuestDone ของ itemsforsale เลยต้องจดเอง
Game.ShopGates = {
	-- Ginzo ขาย Metal Scraps / Silk Thread หลังคืนกล่องเครื่องประดับ ก่อนนั้นหน้าคุยไม่มีปุ่มดูของ
	Ginzo = "Ill find the jewelry box(Lv 45)",
}

function Game.questDone(questName)
	local Quests = require(ReplicatedStorage.CAM.Global.Subsets.Gameplay.Quests)
	return Quests.GetPlayerQuestState(LocalPlayer, questName) == "Done"
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

-- ตารางดรอปจริงของเกม: LiveConfig "NpcDataTable" (ม็อบ/บอสแต่ละตัวดรอปอะไร โอกาสเท่าไร หีบแบบไหน)
-- กับ "ChestsLootTable" (หีบแต่ละแบบมีอะไร) เกมใช้สองตารางนี้สร้างหน้าต่าง "ได้จากไหน" ของตัวเอง
-- (CAM.Client.Modules.ItemSources) เลยแม่นกว่าคู่มือในเว็บ เช่น Flame Katana = Rengu 5%, Spear = Rare Chest 7%
local liveTables
local function lootTables()
	if not liveTables then
		local ok, LiveConfig = pcall(require, ReplicatedStorage.CAM.Global.LiveConfig)
		local npc = ok and LiveConfig.get("NpcDataTable")
		local chests = ok and LiveConfig.get("ChestsLootTable")
		liveTables = {
			npc = type(npc) == "table" and npc or {},
			chests = type(chests) == "table" and chests or {},
			-- ชื่อไอเทม -> เส้นทาง (false = ไม่มี) แผงมีของกว่า 300 แถว วนตาราง NPC x หีบทุกแถวทุกรอบช้าเกิน
			routes = {},
		}
	end
	return liveTables
end

-- ทางที่ได้ของชิ้นนี้เร็วสุดจากการฟาร์มม็อบ: ดรอปตรงจากม็อบก่อน ไม่มีค่อยดูว่าหีบไหนมี แล้วใครดรอปหีบนั้น
-- เลือกโอกาสสูงสุด ถ้าเท่ากันเอาตัวเลือดน้อยกว่า (ฆ่าเร็วกว่า)
-- คืน { kind = "drop"|"chest", code = รหัสม็อบ (ตรงกับ NpcCode), npc, chance, level, night, chest }
function Game.dropRoute(itemName)
	local t = lootTables()
	if t.routes[itemName] == nil then
		t.routes[itemName] = Game.findRoute(t, itemName) or false
	end
	return t.routes[itemName] or nil
end

function Game.findRoute(t, itemName)
	local function better(a, b)
		if not b then
			return true
		end
		if a.chance ~= b.chance then
			return a.chance > b.chance
		end
		return (a.hp or math.huge) < (b.hp or math.huge)
	end

	local best
	for code, npc in pairs(t.npc) do
		local r = type(npc) == "table" and npc.Rewards and npc.Rewards[itemName]
		local chance = type(r) == "table" and r.Chance or (type(r) == "number" and r) or nil
		if chance then
			local cand = {
				kind = "drop",
				code = code,
				npc = npc.Name or code,
				chance = chance,
				level = type(r) == "table" and r.Level or nil,
				night = npc.OnlyAtNight == true,
				hp = npc.Stats and npc.Stats.MaxHealth,
			}
			if better(cand, best) then
				best = cand
			end
		end
	end
	if best then
		return best
	end

	for chestId, chest in pairs(t.chests) do
		local chance
		for _, e in ipairs(type(chest) == "table" and chest.loot or {}) do
			if e.itemId == itemName then
				chance = e.chance or 1
			end
		end
		if chance then
			for code, npc in pairs(t.npc) do
				local drops = type(npc) == "table" and npc.Chest == chestId
				for _, extra in ipairs(type(npc) == "table" and npc.ExtraChests or {}) do
					drops = drops or extra == chestId
				end
				if drops then
					local cand = {
						kind = "chest",
						chest = chestId,
						code = code,
						npc = npc.Name or code,
						chance = chance,
						night = npc.OnlyAtNight == true,
						hp = npc.Stats and npc.Stats.MaxHealth,
					}
					if better(cand, best) then
						best = cand
					end
				end
			end
		end
	end
	return best
end

function Game.routeText(route)
	local pct = string.format("%g%%", math.floor(route.chance * 1000 + 0.5) / 10)
	local text = route.kind == "drop" and string.format("ดรอป %s %s", route.npc, pct)
		or string.format("%s %s จาก %s", route.chest, pct, route.npc)
	if route.night then
		text ..= " · กลางคืน"
	end
	if route.level then
		text ..= " · Lv " .. route.level
	end
	return text
end

-- ร้านที่ขายของชิ้นนี้ด้วย Wen ได้จริงตอนนี้ คืน listing หรือ nil กับเหตุผล
-- ราคา Product = Robux ข้ามไป ของพวกนั้นเกือบทุกชิ้นดรอปหรือตีได้อยู่แล้ว
function Game.shopListing(itemName)
	local listing = Shop and Shop.itemsforsale[itemName]
	if not (listing and listing.Price) or listing.Price.Product then
		return nil
	end
	if listing.RequiresQuestDone and not Game.questDone(listing.RequiresQuestDone) then
		return nil, "ต้องจบเควส: " .. listing.RequiresQuestDone
	end
	local _, seller = Game.shopSpot(itemName)
	local gate = seller and Game.ShopGates[seller]
	if gate and not Game.questDone(gate) then
		return nil, string.format("ร้าน %s ต้องจบเควส: %s", seller, gate)
	end
	return listing
end

-- own = ข้อความของแถวตัวเอง ไม่ต้องขึ้นชื่อซ้ำ
function Game.noSourceText(itemName, own)
	local subject = own and "" or (itemName .. " ")
	if Game.SourceHints[itemName] then
		return string.format("ต้องมี %s (%s)", itemName, Game.SourceHints[itemName])
	end
	-- มาถึงตรงนี้คือไม่มีร้านที่ขายตอนนี้ ไม่มีม็อบดรอป และตีไม่ได้ ถามดัชนีแหล่งของเกมเอง (ตัวที่ทำ tooltip "ได้จากไหน")
	-- ที่เหลือจะเป็น: ร้านหมุนเวียน (Elara / Lynx สลับของทุกรอบ, Black Marketer โผล่ 30 นาที)
	-- ของพวกนี้ลงทะเบียนเข้า itemsforsale เฉพาะรอบที่มีขาย รอบไหนมีแถวจะเป็น BUY เอง
	-- หีบที่วางในแมพเอง (Snow Chest, Sealed Cache, หีบของ Ouwigahara) และของตกปลา
	local ItemSources = require(ReplicatedStorage.CAM.Client.Modules.ItemSources)
	for _, e in ipairs(ItemSources.Get(itemName)) do
		local seller = e.Where:match("^Sold by (.+)")
		local quest = e.Where:match("^Quest: (.+)")
		if seller then
			return string.format("%sขายที่ %s (ร้านหมุนเวียน รอบนี้ไม่มี)", subject, seller)
		elseif quest then
			return string.format("%sรางวัลเควส %s", subject, quest)
		elseif e.Where == "Fished up" then
			return subject .. "ได้จากตกปลา (ยังไม่รองรับ)"
		elseif lootTables().chests[e.Where] then
			return string.format("%sได้จากหีบ %s ในแมพ (ยังไม่รองรับ)", subject, e.Where)
		end
	end
	return own and "ยังไม่รู้แหล่งได้" or ("ยังไม่รู้แหล่งได้ " .. itemName)
end

-- วัตถุดิบทั้งสูตร เรียง: ของหลัก (อาจต้องตีต่ออีกชั้น) > วัตถุดิบเสริม > แบบพิมพ์ > เงิน
-- เงินไว้ท้ายสุดเพราะการซื้อวัตถุดิบข้างหน้ากิน Wen ก้อนเดียวกัน เช็กก่อนจะผ่านแล้วมาขาดทีหลัง
-- keep = แบบพิมพ์ต้องถือไว้แต่ตีแล้วไม่หาย (Crafting.keep เช่น Firstlight Katana Schematic)
function Game.recipeInputs(recipe)
	local list = {}
	for _, m in ipairs(recipe.required or {}) do
		list[#list + 1] = { name = m.name, amount = m.amount }
	end
	for _, m in ipairs(recipe.additionalMaterials or {}) do
		list[#list + 1] = { name = m.name, amount = m.amount }
	end
	for _, name in ipairs(recipe.keep or {}) do
		list[#list + 1] = { name = name, amount = 1, keep = true }
	end
	for _, p in ipairs(priceParts(recipe.price)) do
		list[#list + 1] = { name = p.currency, amount = p.amount }
	end
	return list
end

function Game.newPlan()
	return { buy = {}, farm = {}, craft = {}, spend = {}, how = {} }
end

-- จำลองการหาของทั้งต้นไม้บนกระเป๋าจำลอง w โดยไม่ยิงอะไรไปเซิร์ฟเวอร์ ใช้สองที่:
-- แถวในแผง (ทำได้ไหม ติดอะไร) กับ Runner.obtain (ชั้นนี้ต้องซื้อ ฟาร์ม หรือตีสูตรไหน)
-- ลำดับเลือกทาง: ร้าน > ฟาร์มม็อบ/บอส > ตี ตรงกับที่แถวอาวุธใช้มาตลอด
-- w ถูกหักตามที่ใช้ ทางที่เลือกบันทึกลง out.how[ชื่อ] คืน nil ถ้าหาได้ครบ ไม่งั้นคืนเหตุผลข้อแรกที่ติด
function Game.plan(name, need, w, out, depth)
	depth = depth or 0
	local have = w[name] or 0
	w[name] = math.max(have - need, 0)
	if Game.Currencies[name] then
		out.spend[name] = (out.spend[name] or 0) + need
		return have < need and string.format("ขาด %s %s", comma(need - have), name) or nil
	end
	if have >= need then
		return nil
	end
	local short = need - have
	-- สูตรที่ลึกสุดในเกมคือ 3 ชั้น (Firstlight Katana <- Thundercloud Katana <- Thunder Katana) เกินนี้แปลว่าวน
	if depth > 6 then
		return "สูตรวนกลับมาที่ " .. name
	end

	local listing, shopWhy = Game.shopListing(name)
	if listing then
		out.how[name] = { kind = "shop", listing = listing }
		out.buy[name] = (out.buy[name] or 0) + short
		for _, p in ipairs(priceParts(listing.Price)) do
			local err = Game.plan(p.currency, p.amount * short, w, out, depth + 1)
			if err then
				return err
			end
		end
		return nil
	end

	local route = Game.dropRoute(name)
	if route then
		out.how[name] = { kind = "farm", route = route }
		out.farm[#out.farm + 1] = { item = name, amount = short, route = route }
		return nil
	end

	local why
	for _, c in ipairs(Game.recipesFor(name)) do
		local station = c.recipe.station
		if not Game.Forges[station] then
			why = why or string.format("%s ต้องตีที่ %s (อีกแมพ ยังไม่รองรับ)", name, tostring(station))
		else
			-- ลองสูตรนี้บนสำเนา ติดก็ทิ้งไปลองสูตรถัดไป กระเป๋าจริงไม่ถูกแตะจนกว่าจะผ่าน
			local tw, to = table.clone(w), Game.newPlan()
			local times = math.ceil(short / (c.recipe.amount or 1))
			local err
			for _ = 1, times do
				for _, input in ipairs(Game.recipeInputs(c.recipe)) do
					err = Game.plan(input.name, input.amount, tw, to, depth + 1)
					if err then
						break
					end
					if input.keep then
						tw[input.name] = (tw[input.name] or 0) + input.amount
					end
				end
				if err then
					break
				end
			end
			if not err then
				table.clear(w)
				for k, v in pairs(tw) do
					w[k] = v
				end
				for k, v in pairs(to.buy) do
					out.buy[k] = (out.buy[k] or 0) + v
				end
				for k, v in pairs(to.spend) do
					out.spend[k] = (out.spend[k] or 0) + v
				end
				for k, v in pairs(to.how) do
					out.how[k] = out.how[k] or v
				end
				table.move(to.farm, 1, #to.farm, #out.farm + 1, out.farm)
				table.move(to.craft, 1, #to.craft, #out.craft + 1, out.craft)
				out.how[name] = { kind = "craft", id = c.id, recipe = c.recipe }
				out.craft[#out.craft + 1] = { item = name, station = station, times = times }
				return nil
			end
			why = why or err
		end
	end
	return why or shopWhy or Game.noSourceText(name)
end

-- สรุปแผนสั้น ๆ ให้พอดีแถว: ตีที่ไหน ต้องฟาร์มอะไร ซื้ออะไร ใช้เงินเท่าไร
function Game.planText(station, o)
	local parts = { "ตีที่ " .. tostring(station) }
	local farmed = {}
	for _, f in ipairs(o.farm) do
		farmed[#farmed + 1] = f.item
	end
	if #farmed > 0 then
		parts[#parts + 1] = "ฟาร์ม " .. table.concat(farmed, ", ")
	end
	local bought = {}
	for item in pairs(o.buy) do
		bought[#bought + 1] = item
	end
	table.sort(bought)
	if #bought > 0 then
		parts[#parts + 1] = "ซื้อ " .. table.concat(bought, ", ")
	end
	for _, currency in ipairs({ "Wen", "RunPoints" }) do
		if (o.spend[currency] or 0) > 0 then
			parts[#parts + 1] = comma(o.spend[currency]) .. " " .. currency
		end
	end
	if #parts == 1 then
		parts[2] = "ของครบแล้ว"
	end
	return table.concat(parts, " · ")
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
		local recipes = Game.recipesFor(item.name)
		-- ขายเป็น Robux แต่ดรอปหรือตีได้ด้วย ไปทางที่ไม่ต้องจ่ายเงินจริง
		if listing and listing.Price and listing.Price.Product and (Game.dropRoute(item.name) or #recipes > 0) then
			listing = nil
		end
		local route = not listing and Game.dropRoute(item.name) or nil
		row.have = wallet[item.name] or 0
		row.wear = item.wear

		if route then
			-- ฟาร์มม็อบ/บอสจนดรอป ไม่ต้องใช้เงิน เลยข้ามการเช็กราคาข้างล่าง (cost ว่าง)
			row.source = route.kind
			row.route = route
			row.farmable = true
			row.reason = Game.routeText(route)
		elseif listing then
			row.source = "shop"
			row.buyable = true
			row.cost = priceParts(listing.Price)
			-- เดิมล็อกทุกชิ้นที่มี RequiresQuestDone ทั้งที่จบเควสแล้ว (แผง Elara ทั้งร้านขึ้นล็อกหมด)
			if listing.RequiresQuestDone and not Game.questDone(listing.RequiresQuestDone) then
				row.locked = true
				row.reason = "ต้องจบเควส: " .. listing.RequiresQuestDone
			end
			if listing.Requirements and listing.Requirements.Level then
				row.reqLevel = listing.Requirements.Level
			end
		elseif #recipes > 0 then
			row.source = "craft"
			row.station = recipes[1].recipe.station
			for _, c in ipairs(recipes) do
				if Game.Forges[c.recipe.station] then
					row.station = c.recipe.station
					break
				end
			end
			-- ขอเพิ่มอีก 1 ชิ้นจากที่มี เหมือนแถวฟาร์ม ของที่มีอยู่แล้วไม่นับเป็นวัตถุดิบของตัวเอง
			local w = table.clone(wallet)
			w[item.name] = 0
			local o = Game.newPlan()
			local err = Game.plan(item.name, 1, w, o)
			if not Game.Forges[row.station] then
				row.locked = true
				row.reason = "ตีที่ " .. tostring(row.station) .. " (อีกแมพ ยังไม่รองรับ)"
			elseif err then
				row.locked = true
				row.reason = "ตีที่ " .. tostring(row.station) .. " · " .. err
			else
				row.station = o.how[item.name].recipe.station
				row.farmable = true
				row.reason = Game.planText(row.station, o)
			end
		else
			row.locked = true
			row.reason = Game.noSourceText(item.name, true)
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

-- แผงขายคือ ProximityPrompt "Purchase" ที่ ObjectText = ชื่อของ เช่น Raze's Shop.Regular Katana
-- โผล่ใน workspace เฉพาะตอน stream ถึง อยู่คนละโซนกับร้านจะหาไม่เจอ
function Game.findStand(itemName)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.ObjectText == itemName and d.ActionText == "Purchase" then
			return d
		end
	end
	return nil
end

-- ร้านไหนขายอะไรดูได้จากข้อมูลเกมโดยไม่ต้องรอ stream:
-- Ouwland.Content.<โซน>.Npcs.<NPC>.Shop มีโมเดลชื่อตามของที่ขาย (Raze: Fancy Katana, Regular Katana)
-- คืนตำแหน่งยืนของ NPC ร้านนั้น จาก Spawns[1] ของโมดูล NPC
-- ร้านแบบคุยกับ NPC ไม่มีโฟลเดอร์ Shop แต่มีตาราง Shop ในโมดูล (Ginzo: Metal Scraps, Silk Thread)
-- ตัวนี้ไม่มีแผง ต้องยืนข้าง NPC แทน เลยคืน true ตัวที่สาม
-- ยังไม่ได้ยืนยันว่าเซิร์ฟรับ PurchaseFromShop ข้าง Ginzo บัญชีที่ทดสอบยังไม่จบเควสกล่องของเขา
-- ร้านที่ไม่มี NPC ถือของเลย (หุ่นโชว์ชุดของ Elara) มีโมเดลโชว์ชื่อเดียวกับของวางใน workspace.Debree ตลอด
-- แม้ prompt ยังไม่ stream (เจอ ...Elara.outfit_stand.Manequin.DisplayClothing.Checkered Haori จาก Windy Peak)
function Game.shopSpot(itemName)
	if not Game.shopSpots then
		Game.shopSpots = {}
		for _, region in ipairs(ReplicatedStorage.Ouwland.Content:GetChildren()) do
			local npcs = region:FindFirstChild("Npcs")
			for _, m in ipairs(npcs and npcs:GetDescendants() or {}) do
				local ok, def = false, nil
				if m:IsA("ModuleScript") then
					ok, def = pcall(require, m)
				end
				local spawn = ok and type(def) == "table" and def.Spawns and def.Spawns[1]
				local pos = typeof(spawn) == "CFrame" and spawn.Position or (typeof(spawn) == "Vector3" and spawn)
				if pos then
					local seller = def.Name or m.Name
					local folder = m:FindFirstChild("Shop")
					for _, stock in ipairs(folder and folder:GetChildren() or {}) do
						Game.shopSpots[stock.Name] = { pos = pos, seller = seller }
					end
					for name in pairs(type(def.Shop) == "table" and def.Shop or {}) do
						Game.shopSpots[name] = { pos = pos, seller = seller, talk = true }
					end
				end
			end
		end
	end
	local spot = Game.shopSpots[itemName]
	if spot then
		return spot.pos, spot.seller, spot.talk
	end
	local debree = workspace:FindFirstChild("Debree")
	for _, d in ipairs(debree and debree:GetDescendants() or {}) do
		if d.Name == itemName and d:IsA("Model") then
			return d:GetPivot().Position, "แผงโชว์"
		end
	end
	return nil
end

-- Shop.Buy ใช้ไม่ได้จากฝั่งเรา บรรทัดแรกของมันคือ if not RunService:IsServer() then return end
-- เดิมเรียกตัวนั้นแล้วขึ้น "ส่งคำสั่งซื้อแล้ว" ทั้งที่ไม่มีอะไรไปถึงเซิร์ฟเวอร์เลย
-- ทางที่หน้าคุยร้านของเกมใช้จริง (Dialogue.ProceedWithPurchase):
--   SignalEvent.ToServer("PurchaseFromShop", ชื่อ, จำนวน)
-- ยิงจากที่ไหนก็ได้เซิร์ฟเวอร์เงียบ (ลองแล้ว Wen ค้าง 1880) ต้องยืนที่แผงขายของชิ้นนั้น
-- เซิร์ฟเวอร์ไม่ตอบกลับ เลยยืนยันผลจากเงินที่ลดลงจริงแทน
-- Shop.CanBuy ไม่ได้ใช้: เรียกจาก executor แล้วพังทุกครั้ง ("Cannot require a non-RobloxScript module")
-- amount: เซิร์ฟตัดเหลือ 1-99 (Shop.SanitizeAmount) และอาวุธได้ทีละ 1 เสมอ (EffectiveAmount)
-- คนเรียกที่ต้องการเยอะกว่านั้นให้วนเช็กจำนวนในกระเป๋าเอง
function Game.buy(row, amount)
	amount = amount or 1
	if not (Shop and SignalEvent) then
		return false, "ไม่พบโมดูลร้าน"
	end
	if row.source ~= "shop" then
		return false, "ซื้อผ่านร้านไม่ได้"
	end
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false, "ไม่พบตัวละคร"
	end

	local home = hrp.CFrame
	local function goHome()
		if hrp.Parent then
			hrp.CFrame = home
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
	end

	-- อยู่คนละโซนกับร้าน: วาร์ปไปที่ NPC ร้านก่อน แล้วรอแผง stream เข้ามา
	local standPos
	local stand = Game.findStand(row.name)
	if not stand then
		local spot, shopName, talk = Game.shopSpot(row.name)
		if not spot then
			return false, "ไม่รู้ว่าร้านไหนขาย " .. row.name
		end
		hrp.CFrame = CFrame.new(spot + Vector3.new(0, 3, 6), spot)
		local untilT = os.clock() + 6
		repeat
			task.wait(0.25)
			if talk then
				-- ร้านแบบคุย: ยืนข้างตัว NPC เหมือนตอนเปิดหน้าคุย ระยะ prompt ของเกมคือ 10
				for _, d in ipairs(workspace:GetDescendants()) do
					if d:IsA("Model") and d.Name == shopName and d:FindFirstChildWhichIsA("ProximityPrompt", true) then
						standPos = d:GetPivot().Position
						break
					end
				end
			else
				stand = Game.findStand(row.name)
			end
		until stand or standPos or os.clock() > untilT
		if not (stand or standPos) then
			goHome()
			return false, "วาร์ปไปร้าน " .. tostring(shopName) .. " แล้วแต่แผงขายไม่โหลด"
		end
	end

	standPos = standPos
		or stand.Parent:IsA("BasePart") and stand.Parent.Position
		or (stand.Parent:IsA("Attachment") and stand.Parent.WorldPosition)
		or stand.Parent:GetPivot().Position
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
	goHome()

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

-- compact: แถวหมวดของสวมใส่มี 9 เม็ด ขนาดปกติกว้างราว 520px ล้นแผง (ในแผงเหลือ ~450px)
-- ย่อเป็น 6px/ตัวอักษร + ขอบ 14 เหลือราว 410px
local function addPills(container, names, onChange, compact)
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
			Size = compact and UDim2.fromOffset(#name * 6 + 14, 24) or UDim2.fromOffset(#name * 7 + 22, 24),
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

-- ตัวรัน (คุยกับ NPC / ฆ่าม็อบ / เก็บของ) นิยามอยู่ล่างกว่า แต่ Get Weapons, Auto-Quest, Auto-Breathing ใช้ร่วมกัน
-- ประกาศไว้ก่อนแผงพวกนี้ ไม่งั้นโค้ดแผงอ้างถึงแล้วได้ global ว่าง ๆ
local Runner

local shopUI = makePanel("Get Weapons", true)
shopUI.search.PlaceholderText = "ค้นหาชื่อ หมวด หรือแหล่งได้ เช่น Rengu, ตีที่, ฟาร์ม…"

local buyLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Text = "GET",
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

-- top = เม็ดแถวบน (All / Katana / Weapons / Accessory) wear = หมวดย่อยของสวมใส่
-- แถวหมวดย่อยโชว์เฉพาะตอนเลือก Accessory รวมแถวเดียวไม่พอ 11 เม็ดกว้างเกินแผง
local shopFilter = {
	top = "All",
	wear = "All",
	wearRow = new("Frame", {
		Position = UDim2.fromOffset(0, 112),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = shopUI.panel,
	}, { new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) }),
}
-- ของที่ติ๊กไว้ เรียงตามลำดับที่ติ๊ก GET หาทีละชิ้นตามลำดับนี้
-- เก็บเป็นชื่อ ไม่ใช่แถว เพราะ rebuildShop สร้างแถวใหม่ทุกครั้ง แต่ชิ้นที่ยังหาไม่ได้ต้องติ๊กค้างไว้
local shopQueue = {}
local shopRows = {}

-- ข้อความจาก Runner ขึ้นแผงนี้พร้อมบอกว่ากำลังทำชิ้นที่เท่าไรของคิว
-- ต้องเป็นฟังก์ชันตัวเดิมตลอด ปุ่มเช็กว่าตัวรันเป็นของแผงนี้ไหมจาก Runner.statusSink == shopUI.queueStatus
function shopUI.queueStatus(text, color)
	shopUI.setStatus((shopUI.progress or "") .. text, color)
end

local function refreshBuyButton()
	if Runner and Runner.active and Runner.statusSink == shopUI.queueStatus then
		buyLabel.Text = "STOP"
		tween(buyBtn, { BackgroundColor3 = Theme.Danger }, FAST)
		tween(buyLabel, { TextColor3 = Theme.Text }, FAST)
		return
	end
	local enabled = #shopQueue > 0 and not (Runner and Runner.active)
	if Runner and Runner.active then
		buyLabel.Text = "มีระบบอื่นกำลังรันอยู่"
	elseif #shopQueue == 1 then
		buyLabel.Text = "GET  ·  " .. shopQueue[1]
	elseif #shopQueue > 1 then
		buyLabel.Text = string.format("GET  ·  %d ชิ้นตามลำดับ", #shopQueue)
	else
		buyLabel.Text = "GET"
	end
	tween(buyBtn, { BackgroundColor3 = enabled and Theme.Accent or Theme.Raised }, FAST)
	tween(buyLabel, { TextColor3 = enabled and Theme.Base or Theme.Dim }, FAST)
end

-- ติ๊กแล้วกล่องเต็มพร้อมเลขลำดับ ผู้ใช้จะได้เห็นว่าชิ้นไหนหาก่อน
-- hovered = แถวที่เพิ่งกดยกเลิก เมาส์ยังค้างอยู่ ให้อยู่สถานะ hover ไม่ใช่ปกติ
local function paintShopTicks(hovered)
	for _, r in ipairs(shopRows) do
		local order = table.find(shopQueue, r.data.name)
		tween(r.tickFill, {
			BackgroundTransparency = order and 0 or 1,
			Size = order and UDim2.fromOffset(14, 14) or UDim2.fromOffset(8, 8),
		}, FAST)
		r.tickNum.Text = order and tostring(order) or ""
		tween(r.frame, { BackgroundColor3 = (order or r == hovered) and Theme.Raised or Theme.Row }, FAST)
		r.tickStroke.Color = order and Theme.Accent or Theme.Stroke
	end
end

-- กดซ้ำแถวเดิม = เอาออกจากคิว ติ๊กเพิ่มระหว่างกำลังหาได้ ตัวรันอ่านคิวใหม่ทุกชิ้น
local function selectShopRow(row)
	if row.data.locked then
		return
	end
	local at = table.find(shopQueue, row.data.name)
	if at then
		table.remove(shopQueue, at)
	else
		table.insert(shopQueue, row.data.name)
	end
	paintShopTicks(row)
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
	local tickNum = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.Base,
		TextSize = 10,
		FontFace = font(Enum.FontWeight.Bold),
		ZIndex = 2,
		Parent = tickFill.Parent,
	})

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
	local right = (data.locked or data.farmable) and (data.reason or "ล็อก") or table.concat(costText, " + ")
	if #right == 0 then
		right = "-"
	end
	if (data.have or 0) > 0 then
		right = "มีแล้ว " .. data.have .. "  ·  " .. right
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

	local row = {
		frame = frame,
		tickFill = tickFill,
		tickStroke = tickStroke,
		tickNum = tickNum,
		data = data,
		haystack =table.concat({ data.name, data.group, right, data.note or "" }, " "):lower(),
	}

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
		if not data.locked and not table.find(shopQueue, data.name) then
			tween(frame, { BackgroundColor3 = Theme.Raised }, FAST)
		end
	end))
	track(hit.MouseLeave:Connect(function()
		if not table.find(shopQueue, data.name) then
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
		local okGroup
		if shopFilter.top == "Accessory" then
			okGroup = d.wear and (shopFilter.wear == "All" or d.group == shopFilter.wear)
		else
			okGroup = shopFilter.top == "All" or d.group == shopFilter.top
		end
		-- ค้นได้ทั้งชื่อ หมวด และข้อความแหล่งได้ที่โชว์ขวาแถว พิมพ์ชื่อบอสก็เจอของทุกชิ้นที่บอสนั้นให้
		local okText = query == "" or r.haystack:find(query, 1, true) ~= nil
		r.frame.Visible = okGroup and okText
		if r.frame.Visible then
			shown += 1
		end
	end
	if shown == 0 then
		shopUI.setStatus("ไม่พบของที่ตรงกับคำค้น", Theme.Muted)
	elseif query ~= "" or shopFilter.top ~= "All" then
		shopUI.setStatus(string.format("แสดง %d จาก %d ชิ้น", shown, #shopRows), Theme.Muted)
	end
end

local function rebuildShop()
	for _, r in ipairs(shopRows) do
		r.frame:Destroy()
	end
	table.clear(shopRows)

	local listings, wallet = Game.listings()
	for i, data in ipairs(listings) do
		shopRows[#shopRows + 1] = buildShopRow(data, i)
	end

	-- ติ๊กที่ค้างจากคิวรอบก่อน (ชิ้นที่ยังหาไม่ได้) คงไว้ถ้าแถวนั้นยังหาได้อยู่
	-- ได้ชิ้นแรกแล้วเงินลด แถวข้างหลังอาจกลายเป็นล็อก อันนั้นเอาออก
	for i = #shopQueue, 1, -1 do
		local keep = false
		for _, r in ipairs(shopRows) do
			keep = keep or (r.data.name == shopQueue[i] and not r.data.locked)
		end
		if not keep then
			table.remove(shopQueue, i)
		end
	end
	paintShopTicks()

	local parts = {}
	for _, currency in ipairs(Config.WalletShown) do
		parts[#parts + 1] = string.format(
			'<font color="#8f8f9e">%s</font> %s',
			Config.WalletShort[currency],
			comma(wallet[currency] or 0)
		)
	end
	shopUI.subtitle.Text = table.concat(parts, "   ")

	local sellable = 0
	for _, d in ipairs(listings) do
		if not d.locked then
			sellable += 1
		end
	end
	shopUI.setStatus(string.format("ของทั้งหมด %d · ได้ตอนนี้ %d", #listings, sellable), Theme.Muted)

	applyShopFilter()
	refreshBuyButton()
end

addPills(shopUI.filterRow, { "All", "Katana", "Weapons", "Accessory" }, function(name)
	shopFilter.top = name
	local wear = name == "Accessory"
	shopFilter.wearRow.Visible = wear
	shopUI.list.Position = UDim2.fromOffset(0, wear and 144 or 114)
	shopUI.list.Size = UDim2.new(1, 0, 1, wear and -200 or -170)
	applyShopFilter()
end)

do
	local wearPills = { "All" }
	for _, group in ipairs(Game.WearGroups) do
		wearPills[#wearPills + 1] = group
	end
	addPills(shopFilter.wearRow, wearPills, function(name)
		shopFilter.wear = name
		applyShopFilter()
	end, true)
end

track(shopUI.search:GetPropertyChangedSignal("Text"):Connect(applyShopFilter))

-- หาของที่ติ๊กไว้ทีละชิ้นตามลำดับที่ติ๊ก ได้ชิ้นไหนเอาติ๊กออกแล้วไปชิ้นถัดไป
-- ของร้านซื้อตรง ของที่ต้องฟาร์ม/ตีใช้ Runner.obtain ไล่หาวัตถุดิบทุกชั้นจนมีเพิ่มอีก 1 ชิ้น
-- ชิ้นที่ติด (เงินไม่พอ ของหมดรอบ) ข้ามไปก่อนแต่ติ๊กค้างไว้ ให้เห็นว่ายังไม่ได้
local function runShopQueue()
	Runner.active = true
	Runner.cancel = false
	Runner.lastStart = os.clock()
	Runner.statusSink = shopUI.queueStatus
	refreshBuyButton()
	local auraWasOn = Runner.auraOn and Runner.auraOn()
	if Runner.setAura and not auraWasOn then
		Runner.setAura(true)
	end
	-- แยก thread เพราะ Game.buy / Runner.obtain รอ ถ้า handler ถูกเรียกแบบห้าม yield
	-- (getconnections():Fire() ของ executor) จะพังด้วย "thread is not yieldable"
	task.spawn(function()
		local got, skipped, lastErr = {}, {}, nil
		while not Runner.cancel do
			-- อ่านคิวใหม่ทุกชิ้น ผู้ใช้ติ๊กเพิ่มหรือเอาออกระหว่างรันได้
			local target
			for _, name in ipairs(shopQueue) do
				if not skipped[name] then
					for _, r in ipairs(shopRows) do
						if r.data.name == name then
							target = r.data
						end
					end
					break
				end
			end
			if not target then
				break
			end

			shopUI.progress = string.format("[%d/%d] %s · ", #got + 1, #got + #shopQueue, target.name)
			shopUI.queueStatus("กำลังหา…", Theme.Accent)
			-- ครอบ pcall เสมอ ถ้าพังกลางทาง Runner.active จะค้างเป็น true แล้วปุ่มเงียบไปจนกว่าจะรีโหลด
			-- (เจอจริงสมัยปุ่ม BUY: สถานะค้าง "กำลังซื้อ Fancy Katana…")
			local done, ok, err
			if target.farmable then
				done, ok, err = pcall(Runner.obtain, target.name, (Game.wallet()[target.name] or 0) + 1)
			else
				done, ok, err = pcall(Game.buy, target)
			end
			if not done then
				ok, err = false, ok
			end

			if ok then
				got[#got + 1] = target.name
				local at = table.find(shopQueue, target.name)
				if at then
					table.remove(shopQueue, at)
				end
				paintShopTicks()
			elseif Runner.cancel then
				break
			else
				skipped[target.name] = true
				lastErr = target.name .. ": " .. tostring(err)
			end
		end
		shopUI.progress = nil

		if Runner.setAura and not auraWasOn then
			Runner.setAura(false)
		end
		local cancelled = Runner.cancel
		Runner.active = false
		Runner.statusSink = nil

		local gotText = #got > 0 and ("ได้ " .. table.concat(got, ", ")) or "ยังไม่ได้สักชิ้น"
		local summary, color
		if cancelled then
			summary, color = "หยุดแล้ว · " .. gotText, Theme.Warn
		elseif lastErr then
			summary, color = gotText .. " · ข้าม " .. lastErr, #got > 0 and Theme.Warn or Theme.Danger
		else
			summary, color = gotText .. " ครบแล้ว!", Theme.Accent
		end
		shopUI.setStatus(summary, color)
		refreshBuyButton()
		-- เงินกับคลังเปลี่ยนแล้ว สร้างแถวใหม่ แต่ rebuildShop เขียนสถานะนับของทับ เลยใส่สรุปกลับ
		if #got > 0 then
			task.delay(1, function()
				rebuildShop()
				shopUI.setStatus(summary, color)
			end)
		end
	end)
end

track(buyBtn.MouseButton1Click:Connect(function()
	-- getconnections ของ executor ยิงซ้ำได้ คลิกที่สองภายใน 1 วิจะกลายเป็น STOP ทันทีที่เพิ่งเริ่ม
	if os.clock() - Runner.lastStart < 1 then
		return
	end
	if Runner.active then
		if Runner.statusSink == shopUI.queueStatus then
			Runner.stop()
			shopUI.setStatus("กำลังยกเลิก…", Theme.Warn)
		end
		return
	end
	if #shopQueue > 0 then
		runShopQueue()
	end
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
							-- TaskSpecs บอกชนิดงาน: Pickup = เก็บของที่เกมวางไว้ (Liv, Kona, Betty)
							-- Deliver / Deposit / Dungeon ยังไม่รองรับ
							local spec = q.TaskSpecs and q.TaskSpecs[t.Name]
							local anchor = spec and (spec.Anchor
								or (type(spec.Positions) == "table" and spec.Positions[1]))
							tasks[#tasks + 1] = {
								name = t.Name,
								code = code and code.Value,
								max = max and max.Value or 1,
								kind = spec and spec.Type,
								anchor = typeof(anchor) == "Vector3" and anchor or nil,
								-- มีเฉพาะงานที่ของเกิดเป็นวงรอบจุดเดียว (เหรียญ Liv: Anchor + Radius 15)
								sweepAt = spec and typeof(spec.Anchor) == "Vector3" and spec.Anchor or nil,
								-- Deposit: เอาของชื่อนี้ไปใส่ลังที่ Position / Deliver: กลับไปคุยกับ TargetNpc
								item = spec and spec.RequiredItem,
								position = spec and typeof(spec.Position) == "Vector3" and spec.Position or nil,
								target = spec and spec.TargetNpc,
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
-- ใช้ได้เฉพาะเมื่อทุก task เป็นงานฆ่า (Code ตรง NpcCode ของม็อบจริง) หรืองานเก็บของ (Pickup)
-- ถ้ามีงานอื่นปน (วิดพื้น ตกปลา ส่งของ) ถือว่ายังไม่รองรับ
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
	-- งานส่งของทำทีหลังสุดเสมอ ลำดับลูกใน Tasks ไม่แน่นอน "Return to Runo" มาก่อนงานใส่ลังได้
	-- ส่งให้ NPC คนอื่นก่อน แล้วค่อยกลับไปรายงานคนให้เควส (Niko: ส่งกล่องให้ Shiori -> กลับไปหา Niko)
	local delivers, deposit = {}, nil
	for _, t in ipairs(data.tasks) do
		local mob = t.code and byCode[t.code]
		if t.kind == "Pickup" then
			-- งานเก็บของ: เกมวางของไว้เองตอนรับเควส (PickupState) ไปกดเก็บจนตัวนับครบ
			steps[#steps + 1] = { pickup = t.name, anchor = t.anchor, sweepAt = t.sweepAt, max = t.max }
		elseif t.kind == "Deposit" and t.item and t.position then
			-- ลังของ Runo มีงานละชนิดปลาแต่ใส่ที่จุดเดียวกัน รวมเป็นขั้นเดียว หาของให้ครบก่อนแล้ววางรวดเดียว
			if not deposit then
				deposit = { deposit = data.key, position = t.position, rows = {} }
				steps[#steps + 1] = deposit
			end
			deposit.rows[#deposit.rows + 1] = { task = t.name, item = t.item, max = t.max }
		elseif t.kind == "Deliver" and t.target then
			local answer = Game.deliverAnswer(t.target)
			if not answer then
				return nil
			end
			local step = { npc = t.target, answer = answer }
			if t.target == data.offerNpc then
				delivers[#delivers + 1] = step
			else
				table.insert(delivers, 1, step)
			end
		elseif mob then
			steps[#steps + 1] = { hunt = mob.name, center = mob.center, task = t.name, max = t.max }
		else
			return nil
		end
	end
	table.move(delivers, 1, #delivers, #steps + 1, steps)
	return steps
end

-- ปุ่มส่งของ/รายงานตัวกับ NPC หาจากบทพูดของเกม (Dialogues.Yap): ปุ่มที่ชี้ไป action ขึ้นต้น Deliver
--   Runo "The crate is loaded" -> DeliverHaulToRuno, Sofen "Hand over the permit stamp" -> DeliverPermitStampToSofen
-- ชื่อโมดูลไม่ตรงชื่อ NPC เสมอ (Dock Master Sofen อยู่ในโมดูล Sofen) เลยดูว่าโมดูลไหนมีโหนดชื่อ NPC คนนั้น
-- คืนทุกปุ่มที่เจอ NPC ที่รับของหลายเควสมีปุ่มส่งหลายอัน หน้าคุยจะโชว์เฉพาะอันของเควสที่ถืออยู่
-- (Shiori: "The infirmary is stocked" ของอีกเควส ส่วนกล่องของ Niko เป็นอีกปุ่ม)
Game.deliverAnswers = {}
function Game.deliverAnswer(npcName)
	if Game.deliverAnswers[npcName] then
		return #Game.deliverAnswers[npcName] > 0 and Game.deliverAnswers[npcName] or nil
	end
	local found = {}
	Game.deliverAnswers[npcName] = found
	for _, region in ipairs(ReplicatedStorage.Ouwland.Content:GetChildren()) do
		local dialogues = region:FindFirstChild("NpcContents")
		dialogues = dialogues and dialogues:FindFirstChild("Dialogues")
		local yap = dialogues and dialogues:FindFirstChild("Yap")
		for _, m in ipairs(yap and yap:GetChildren() or {}) do
			-- บทพูดบางตัว require component ฝั่ง UI ตอนโหลด เคยพังจาก executor ("Cannot require a non-RobloxScript module")
			-- ตัวที่พังข้ามไป ถือว่า NPC นั้นไม่มีปุ่มส่งของ
			local ok, nodes = false, nil
			if m:IsA("ModuleScript") then
				ok, nodes = pcall(require, m)
			end
			if ok and type(nodes) == "table" and nodes[npcName] then
				for _, node in pairs(nodes) do
					for text, action in pairs(type(node) == "table" and type(node.Answers) == "table" and node.Answers or {}) do
						if type(action) == "string" and action:find("^Deliver") and not table.find(found, text) then
							found[#found + 1] = text
						end
					end
				end
			end
		end
	end
	return #found > 0 and found or nil
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
			-- ต้องค้นทุกชั้น NPC บางตัวอยู่ในโฟลเดอร์ย่อยของสถานที่
			-- เช่น Bamboo Grove.Npcs.Bamboo Grove Sanctuary.Liv เคยค้นแค่ชั้นแรกแล้วเควส Liv ขึ้น "ไม่รู้ตำแหน่ง Liv"
			local npcs = region:FindFirstChild("Npcs")
			for _, m in ipairs(npcs and npcs:GetDescendants() or {}) do
				local ok, def = false, nil
				if m:IsA("ModuleScript") then
					ok, def = pcall(require, m)
				end
				if ok and type(def) == "table" then
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

-- c:Fire() รัน handler ของเกมใน thread เรา ถ้า handler รออะไรสักอย่าง เราค้างไปด้วย
-- เจอจริงกับ Liv: กด Close แล้วทั้ง Auto-Quest ค้างที่ "คุยกับ Liv" 150 วิ แยก thread ให้ทุกครั้ง
local function clickGui(btn)
	for _, c in ipairs(getconnections(btn.MouseButton1Click)) do
		task.spawn(function()
			c:Fire()
		end)
	end
end

Runner = { active = false, cancel = false, lastStart = 0, hasAlternative = false }
-- จุดแจ้งเหตุการณ์ให้ Webhook (ล็อกเป้าม็อบ / เก็บของ / จบเควส) ตัวจริงผูกทีหลังในแท็บ Settings
-- ต้องมีตัวว่างไว้ก่อน Auto-Chest เปิดตั้งแต่โหลดไฟล์ เก็บของได้ก่อนแท็บ Settings ถูกสร้าง
function Runner.hook() end
-- ค่าที่ Runner.hunt คืนเมื่อยกเลิกเควสบอสเพราะบอสตาย ไม่ใช่ความผิดพลาด ไม่ต้องตัดเควสออก
Runner.BOSS_GONE = "boss-gone"

-- Auto-Breathing ใช้ตัวรันชุดเดียวกัน (คุยกับ NPC / ฆ่าม็อบ / เก็บของ) แต่มีแผงของตัวเอง
-- ตอนมันรันจะตั้ง Runner.statusSink ให้ข้อความไปขึ้นแผงนั้นแทนแผง Auto-Quest
local function report(text, color)
	(Runner.statusSink or questUI.setStatus)(text, color or Theme.Muted)
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
				-- answer เป็นรายการได้: งานส่งของที่ NPC มีปุ่มส่งหลายอัน (Shiori รับของจากหลายเควส)
				local wanted = false
				for _, a in ipairs(type(answer) == "table" and answer or { answer }) do
					wanted = wanted or o.text:lower():find(a:lower(), 1, true) ~= nil
				end
				if wanted then
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
			local asked = type(answer) == "table" and table.concat(answer, '" หรือ "') or answer
			return false, 'ไม่มีตัวเลือก "' .. asked .. '" (มี: ' .. table.concat(names, " / ") .. ")", "not-offered"
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
	if step.pickup then
		return Runner.pickup(step, index, total)
	end
	if step.deposit then
		return Runner.deposit(step, index, total)
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

-- เควสที่ NPC ไม่ยอมเสนอจนกว่าจะทำอย่างอื่นก่อน อ่านจาก BeforeRun ในบทพูดของเกม (Dialogues.Yap)
-- quest = ต้องจบเควสนั้น (ดูจาก Completed) / item = ต้องมีของในกระเป๋า ได้จากเควส via
--   Chaka ไม่เปิดเควสถ้ายังไม่จบจดหมายของ Noote ("You should speak with Kazu ... before coming here")
--   Noote ให้เควสจดหมายเฉพาะตอนมี Suspicious Note ซึ่งเป็นรางวัลเควสฆ่าสายลับของ Kazu
--   (โน้ตเป็น NoSave ออกเกมแล้วหาย ต้องทำต่อกันในรอบเล่นเดียว)
--   Liv ให้เควส 500 เหรียญหลังจบเควสเพนนีแล้วเท่านั้น
-- เควสฆ่าม็อบไม่ถูกบันทึกลง Completed เลยใช้ quest เป็นเงื่อนไขไม่ได้ ต้องใช้ของที่ได้แทน
Runner.Prereqs = {
	["Ill clear out his subordinates(Lv 26)"] = { { quest = "Ill get this letter delivered" } },
	["Ill deal with Kaiden(Lv 34)"] = { { quest = "Ill get this letter delivered" } },
	["Ill get this letter delivered"] = { { item = "Suspicious Note", via = "Ill help clear them out" } },
	["Ill find the coins(Lv 21)"] = { { quest = "Ill look for the penny(Lv 14)" } },
	-- Runo ไม่ให้เควสลังปลาจนกว่าจะได้ใบอนุญาตจาก Sofen (BeforeRun -> Runo_NoPermit)
	-- และร้านเบ็ดของ Jeso ก็ล็อกด้วยเควสเดียวกัน (RequiresQuestDone ในโมดูล NPC)
	["Ill fill your crates(Lv 45)"] = { { quest = "Ill find the permit stamp(Lv 45)" } },
	["Ill land the good catch(Lv 60)"] = { { quest = "Ill find the permit stamp(Lv 45)" } },
}

function Runner.prereqMet(cond)
	if cond.quest then
		return questProgress(cond.quest) == "completed"
	end
	return (Game.wallet()[cond.item] or 0) > 0
end

-- list = เควสที่ติ๊กไว้ในแถวเดียวกัน เรียงบอสก่อนมาแล้ว (Krue: บอสโจร Lv 7 → โจร 3 ตัว)
-- วนทำทีละเควสตามลำดับ ครบรายการก็เริ่มรอบใหม่ จนกว่าจะกด STOP
function Runner.start(list)
	-- getconnections ของ executor ยิงซ้ำได้ กันไว้ 1 วิ ไม่งั้นวาร์ปซ้อนสองรอบ
	if Runner.active or os.clock() - Runner.lastStart < 1 then
		return false
	end

	-- ใส่เควสที่ต้องทำก่อนไว้หน้าเควสที่ติ๊ก (ไล่ย้อนหลายชั้นได้ Chaka → จดหมาย Noote → ฆ่าสายลับ)
	-- เควสที่เป็นแค่ขั้นก่อนหน้าทำรอบเดียวพอ ครบเงื่อนไขแล้วเลิกวน ส่วนที่ผู้ใช้ติ๊กเองวนตามปกติ
	local byKey, picked = {}, {}
	for _, d in ipairs(Game.quests()) do
		byKey[d.key] = d
	end
	for _, d in ipairs(list) do
		picked[d.key] = true
	end
	local queue, seen = {}, {}
	local function add(d, cond)
		if seen[d.key] then
			return
		end
		seen[d.key] = true
		local needs = Runner.Prereqs[d.key]
		for _, c in ipairs(needs or {}) do
			local pd = not Runner.prereqMet(c) and byKey[c.quest or c.via]
			if pd then
				add(pd, c)
			end
		end
		local steps = questPlan(d)
		if steps and questProgress(d.key) ~= "completed" then
			queue[#queue + 1] = {
				data = d,
				steps = steps,
				needs = needs,
				prereq = not picked[d.key] and cond or nil,
			}
		end
	end
	for _, d in ipairs(list) do
		add(d)
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
			if q.data.title == held.Name and q.steps[2] then
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
		q.notOffered, q.bossSkipped = nil, nil

		-- ขั้นก่อนหน้าอยู่หน้าคิวอยู่แล้ว ถ้ามาถึงตรงนี้ยังไม่ครบ แปลว่าขั้นนั้นทำไม่สำเร็จรอบนี้
		for _, c in ipairs(q.needs or {}) do
			if not Runner.prereqMet(c) then
				q.notOffered = d.title .. ": ต้องทำ " .. tostring(c.quest or c.via) .. " ก่อน"
				return false
			end
		end
		if q.prereq then
			report(string.format("รอบ %d · ทำ %s ก่อน (ต้องใช้ปลดล็อกเควสถัดไป)", round, d.title), Theme.Accent)
			task.wait(0.8)
		end

		-- เช็กก่อนรับ จะได้ไม่ต้องรับแล้วยกเลิก (รับเควสทีกินคูลดาวน์ 30 วิ)
		if boss and canSkip and firstStep == 1 and Runner.bossAlive and not Runner.bossAlive(boss) then
			report(string.format("รอบ %d · %s ยังไม่เกิด ข้ามไปทำเควสอื่นก่อน", round, boss.hunt), Theme.Warn)
			q.bossSkipped = true
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
			local ok, err, why = runStep(q.steps[i], i, #q.steps)
			if not ok then
				if why == "not-offered" and not Runner.cancel then
					-- NPC ยังไม่เสนอเควสนี้ เช่น Liv ให้เควส 500 เหรียญหลังจบเควสเพนนีแล้วเท่านั้น
					-- ไม่ตัดทิ้งถาวร ทำเควสอื่นในชุดก่อน รอบหน้ามาถามใหม่
					q.notOffered = d.title .. ": " .. tostring(err)
					report(string.format("รอบ %d · %s ยังรับไม่ได้ ข้ามไปก่อน", round, d.title), Theme.Warn)
					task.wait(1.5)
					return false
				elseif err == Runner.BOSS_GONE then
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
		Runner.hook("quest", d.title)

		-- ขั้นก่อนหน้าได้ของ/จบเควสที่ต้องใช้แล้ว ไม่ต้องวนทำซ้ำ (ฆ่าสายลับได้โน้ตแล้วพอ)
		-- รางวัลเข้ากระเป๋าช้ากว่าตัวนับเควสนิดหน่อย รอดูได้ถึง 3 วิ ไม่งั้นรอบหน้าทำซ้ำเปล่า ๆ
		if q.prereq then
			local untilT = os.clock() + 3
			while not Runner.prereqMet(q.prereq) and os.clock() < untilT and not Runner.cancel do
				task.wait(0.25)
			end
		end
		if q.prereq and Runner.prereqMet(q.prereq) then
			q.finished = true
		elseif questProgress(d.key) == "completed" then
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
				if not q.dropped and not q.finished then
					local others = 0
					for _, o in ipairs(queue) do
						if o ~= q and not o.dropped and not o.finished then
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

			-- ทั้งรอบไม่ได้ทำอะไรเลยและไม่ใช่เพราะรอบอส = ทุกเควสที่เหลือ NPC ยังไม่เสนอ วนต่อก็เปล่า
			if not ranAny and not Runner.cancel then
				local waitingBoss, reason = false, nil
				for _, q in ipairs(queue) do
					if not q.dropped and not q.finished then
						waitingBoss = waitingBoss or q.bossSkipped == true
						reason = reason or q.notOffered
					end
				end
				if not waitingBoss and reason then
					finish("หยุด: ยังรับเควสไม่ได้ (" .. reason .. ")", Theme.Danger)
					return
				end
			end

			if Runner.cancel then
				break
			end
			local left = 0
			for _, q in ipairs(queue) do
				if not q.dropped and not q.finished then
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
	"Get Weapons",
	"หาอาวุธและของสวมใส่ทุกชิ้นในเกม ซื้อ ฟาร์ม หรือตีที่ช่างให้เอง",
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

-- Auto-Breathing: เลือกปราณแล้วทำให้จนได้ ------------------------------------
-- แยกจาก Auto-Quest ทั้งแผงและรายการ แต่ใช้ตัวรันชุดเดียวกัน (runStep / Runner.hunt / Runner.pickup)
-- เลยห้ามรันพร้อมกัน ใช้ Runner.active ตัวเดียวกันกันชน
do
	local breathUI = makePanel("Auto-Breathing", true)
	breathUI.search.PlaceholderText = "ค้นหาปราณ…"

	-- งานฝึกแต่ละแบบ: Code ใน Tasks -> ชื่อโฟลเดอร์ใต้ workspace.Training
	-- ทุกด่านเริ่มด้วย ProximityPrompt "Train" บนแท่นฝึก แล้วเซิร์ฟเวอร์สร้าง Training (Type = ชื่อด่าน)
	-- ในโฟลเดอร์ค่าของผู้เล่น มินิเกมจบด้วย SignalEvent "training_signaler", "Stop", ผ่านไหม
	-- โค้ดเซิร์ฟเวอร์ของด่าน (CAM.Global.Training.<ด่าน>.Server) ไม่ได้ตรวจผลเอง Stop คืน true เสมอ
	-- ลองแล้ว: กด Train ที่เสื่อสมาธิ เซิร์ฟเวอร์สร้าง Training Type=Meditation ส่ง Stop true แล้วปิดให้ทันที
	local Stations = {
		Meditation = "Meditation",
		Pushups = "Pushups",
		["Boulder Split"] = "Boulder Split",
		["Target Shooting"] = "Aim Training",
		["Cup Game"] = "Cup Game",
		["Boulder Push"] = "Boulder Push",
		Squat = "Squat Rack",
	}

	local Breath = {
		-- แท่นฝึกโผล่ในแมพเฉพาะตอน stream ถึง ยืนข้าง ๆ แล้วยังต้องขอให้โหลดเอง (RequestStreamAroundAsync)
		PromptWait = 5,
		-- รอให้มินิเกมเปิดก่อนส่งผล ส่งเร็วเกินไปเซิร์ฟเวอร์อาจยังไม่ผูกตัวเรากับแท่น
		MinigameWait = 1.5,
		SettleWait = 0.8,
		Attempts = 3,
	}

	local breathList
	local function loadBreathing()
		if breathList then
			return breathList
		end
		breathList = {}
		local folder = ReplicatedStorage.Ouwland.Content.Misc.NpcContents.Dialogues.Quests
		for _, m in ipairs(folder:GetChildren()) do
			if m:IsA("ModuleScript") and m.Name:find("Trainer") then
				local ok, def = pcall(require, m)
				for key, q in pairs(ok and def or {}) do
					local power = q.Rewards and q.Rewards.Power
					local inst = q.QuestInstance
					if type(power) == "string" and typeof(inst) == "Instance" then
						-- เรียงงานตาม Need (งานถัดไปเปิดเมื่องานก่อนหน้าครบ) ไม่ใช่ตามลำดับลูกใน Tasks
						local tasks, byNeed = {}, {}
						for _, t in ipairs(inst.Tasks:GetChildren()) do
							local need = t:FindFirstChild("Need")
							local spec = q.TaskSpecs and q.TaskSpecs[t.Name]
							local entry = {
								name = t.Name,
								code = t.Code.Value,
								max = t.Max.Value,
								kind = spec and spec.Type,
								anchor = spec and type(spec.Positions) == "table" and spec.Positions[1] or nil,
							}
							byNeed[need and need.Value or ""] = entry
						end
						local prev = ""
						while byNeed[prev] do
							tasks[#tasks + 1] = byNeed[prev]
							prev = byNeed[prev].name
						end
						local items = {}
						for name, n in pairs(q.ItemCostOnAccept or {}) do
							items[#items + 1] = { name = name, need = n }
						end
						table.sort(items, function(a, b)
							return a.name < b.name
						end)
						breathList[#breathList + 1] = {
							key = key,
							answer = key:gsub("%(Lv %d+%)", ""),
							title = inst.Name,
							power = power,
							npc = q.OfferNpc,
							level = q.Requirements and q.Requirements.Level or 0,
							wen = q.WenCostOnAccept or 0,
							items = items,
							-- Stone ต้องมีอาวุธ Axe and Mace ชิ้นใดชิ้นหนึ่งในกระเป๋าก่อน
							anyOf = q.Requirements and q.Requirements.Items or nil,
							tasks = tasks,
						}
					end
				end
			end
		end
		table.sort(breathList, function(a, b)
			return a.power < b.power
		end)
		return breathList
	end

	local function currentBreathing()
		local slot = equippedSlot()
		local powers = slot and slot:FindFirstChild("Powers")
		local b = powers and powers:FindFirstChild("Breathing")
		return b and b.Value ~= "" and tostring(b.Value) or nil
	end

	-- คืน รายการของที่ขาด (ว่าง = พร้อมรับเควส)
	local function missingFor(b)
		local wallet = Game.wallet()
		local missing = {}
		if (wallet.Wen or 0) < b.wen then
			missing[#missing + 1] = string.format("Wen %s/%s", comma(wallet.Wen or 0), comma(b.wen))
		end
		for _, it in ipairs(b.items) do
			local have = wallet[it.name] or 0
			if have < it.need then
				missing[#missing + 1] = string.format("%s %d/%d", it.name, have, it.need)
			end
		end
		if b.anyOf then
			local ok = false
			for _, name in ipairs(b.anyOf) do
				ok = ok or (wallet[name] or 0) > 0
			end
			if not ok then
				missing[#missing + 1] = "อาวุธ " .. table.concat(b.anyOf, " / ")
			end
		end
		return missing
	end

	local unsupported = { Dungeon = "ด่าน Parkour Dungeon ยังไม่รองรับ" }
	local function supportNote(b)
		for _, t in ipairs(b.tasks) do
			if t.kind and unsupported[t.kind] then
				return unsupported[t.kind]
			end
		end
		return nil
	end

	-- ด่านฝึก --------------------------------------------------------------------

	-- ค่าชั่วคราวของผู้เล่น (Training ถูกสร้างที่นี่ตอนเริ่มฝึก) อยู่ที่ Player_Service.Values.<ชื่อ>
	-- เรียก Utility.getvaluesfolder ของเกมตรง ๆ ไม่ได้ พังด้วย "lacking capability Plugin" ตอนโหลดสคริปต์
	local function valuesFolder()
		local values = ReplicatedStorage:FindFirstChild("Player_Service")
		values = values and values:FindFirstChild("Values")
		return values and values:FindFirstChild(LocalPlayer.Name)
	end

	local function trainingPrompt(station)
		for _, d in ipairs(station:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.ActionText == "Train" then
				return d
			end
		end
		return nil
	end

	local function doTraining(task_)
		local folder = workspace:FindFirstChild("Training")
		folder = folder and folder:FindFirstChild(Stations[task_.code])
		if not folder then
			return false, "ไม่เจอแท่นฝึก " .. task_.code
		end
		local stations = {}
		for _, s in ipairs(folder:GetChildren()) do
			if s:IsA("Model") and s.Name ~= "Sign" then
				stations[#stations + 1] = s
			end
		end

		for attempt = 1, Breath.Attempts do
			for _, station in ipairs(stations) do
				if Runner.cancel then
					return false, "ยกเลิกแล้ว"
				end
				local before = taskProgress(task_.name) or 0
				if before >= task_.max then
					return true
				end
				local char = LocalPlayer.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if not hrp then
					return false, "ไม่พบตัวละคร"
				end
				local pos = station:GetPivot().Position
				report(string.format("ไปแท่น %s (%s) รอบ %d", task_.name, station.Name, attempt), Theme.Accent)
				hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 3), pos)
				hrp.AssemblyLinearVelocity = Vector3.zero
				pcall(function()
					LocalPlayer:RequestStreamAroundAsync(pos, 5)
				end)
				local prompt
				local untilT = os.clock() + Breath.PromptWait
				repeat
					prompt = trainingPrompt(station)
					if not prompt then
						task.wait(0.25)
					end
				until prompt or os.clock() > untilT

				if prompt and prompt.Enabled then
					-- กดทันทีหลังวาร์ป เซิร์ฟเวอร์ยังเห็นตัวเราอยู่ที่เดิม ไกลเกินระยะปุ่ม (10 stud) ด่านเลยไม่เริ่ม
					-- ทุกแท่นถูกข้ามรอบละ 4 วิจนหมด รอ 0.8 วิก่อนกดแล้วเริ่มทุกครั้ง
					task.wait(Breath.SettleWait)
					fireproximityprompt(prompt)
					local started
					untilT = os.clock() + 4
					repeat
						task.wait(0.1)
						local vf = valuesFolder()
						started = vf and vf:FindFirstChild("Training")
					until started or os.clock() > untilT
					if started then
						report(string.format("ฝึก %s …", task_.name), Theme.Accent)
						task.wait(Breath.MinigameWait)
						pcall(SignalEvent.ToServer, "training_signaler", "Stop", true)
						untilT = os.clock() + 5
						while started.Parent and os.clock() < untilT do
							task.wait(0.1)
						end
						-- ตัวนับเควสอัปเดตหลังปิดด่านนิดหน่อย
						untilT = os.clock() + 3
						while (taskProgress(task_.name) or 0) <= before and os.clock() < untilT do
							task.wait(0.2)
						end
						if (taskProgress(task_.name) or 0) > before then
							return true
						end
					end
				end
			end
		end
		return false, "ฝึก " .. task_.name .. " แล้วตัวนับไม่ขยับ (แท่นไม่ว่าง หรือเกมไม่นับ)"
	end

	-- ตัวรัน ----------------------------------------------------------------------

	local refreshBreathButton

	local function runBreathing(b)
		local auraWasOn = Runner.auraOn and Runner.auraOn()
		local function finish(text, color)
			report(text, color)
			if Runner.setAura and not auraWasOn then
				Runner.setAura(false)
			end
			Runner.active = false
			Runner.statusSink = nil
			refreshBreathButton()
		end

		if currentBreathing() == b.power then
			finish("มีปราณ " .. b.power .. " อยู่แล้ว", Theme.Accent)
			return
		end

		local quests = questFolder()
		local holder = quests and quests:FindFirstChild("Holder")
		local held = holder and holder:GetChildren()[1]
		local accepted = held ~= nil and held.Name == b.title

		if not accepted then
			-- ไอเทมที่ฟาร์มจากม็อบได้ (Demon Horns / Beast Core) ไปหามาเองก่อน
			-- Wen กับอาวุธของ Stone ฟาร์มให้ไม่ได้ ปล่อยให้ missingFor บอกว่าขาด
			if (Game.wallet().Wen or 0) >= b.wen then
				for _, it in ipairs(b.items) do
					if Runner.cancel then
						break
					end
					if (Game.wallet()[it.name] or 0) < it.need and Runner.farm and Runner.FarmSources[it.name] then
						if Runner.setAura and not auraWasOn then
							Runner.setAura(true)
						end
						local ok, err = Runner.farm(it.name, it.need)
						if not ok then
							finish("ฟาร์ม " .. it.name .. " ไม่สำเร็จ: " .. tostring(err), Theme.Danger)
							return
						end
					end
				end
			end
			local missing = missingFor(b)
			if #missing > 0 then
				finish("ของไม่พอรับเควส: " .. table.concat(missing, ", "), Theme.Danger)
				return
			end
			-- ฟาร์มของได้แม้ถือเควสอื่นอยู่ แต่รับเควสปราณต้องมือว่าง (เกมให้ถือได้ทีละ 1)
			local nowHeld = holder and holder:GetChildren()[1]
			if nowHeld then
				finish("ของครบแล้ว แต่มีเควสอื่นค้างอยู่: " .. nowHeld.Name .. " (ทำให้จบหรือยกเลิกก่อน)", Theme.Warn)
				return
			end
			while questCooldown() > 0 and not Runner.cancel do
				report("คูลดาวน์รับเควส " .. clockText(questCooldown()), Theme.Warn)
				task.wait(1)
			end
			if Runner.cancel then
				finish("ยกเลิกแล้ว", Theme.Warn)
				return
			end
			local ok, err = runStep({ npc = b.npc, answer = b.answer }, 1, #b.tasks + 1)
			if not ok then
				finish("รับเควสไม่สำเร็จ: " .. tostring(err), Theme.Danger)
				return
			end
			task.wait(1.5)
		end

		if Runner.setAura and not auraWasOn then
			Runner.setAura(true)
		end

		for i, t in ipairs(b.tasks) do
			if Runner.cancel then
				finish("ยกเลิกแล้ว", Theme.Warn)
				return
			end
			local count = taskProgress(t.name)
			if count == nil then
				break
			end
			if count < t.max then
				local ok, err
				if Stations[t.code] then
					ok, err = doTraining(t)
				elseif t.kind == "Pickup" then
					ok, err = Runner.pickup({ pickup = t.name, anchor = t.anchor, max = t.max }, i + 1, #b.tasks + 1)
				elseif t.kind and unsupported[t.kind] then
					ok, err = false, unsupported[t.kind]
				else
					-- ขั้นสุดท้ายคือสู้ Trainee (Code = FlameTrainee ...)
					local mob
					for _, m in ipairs(Game.mobs()) do
						if m.code == t.code then
							mob = m
						end
					end
					if not mob then
						ok, err = false, "ไม่รู้จักงาน " .. t.name
					else
						Runner.hasAlternative = false
						ok, err = Runner.hunt({ hunt = mob.name, center = mob.center, task = t.name, max = t.max }, i + 1, #b.tasks + 1)
					end
				end
				if not ok then
					finish("หยุดที่ " .. t.name .. ": " .. tostring(err), Theme.Danger)
					return
				end
			end
		end

		local untilT = os.clock() + 6
		while currentBreathing() ~= b.power and os.clock() < untilT do
			task.wait(0.3)
		end
		if currentBreathing() == b.power then
			finish("ได้ปราณ " .. b.power .. " แล้ว!", Theme.Accent)
		else
			finish("ทำครบทุกขั้นแล้ว แต่ยังไม่เห็นปราณ " .. b.power .. " ขึ้น ลองเช็กในเกม", Theme.Warn)
		end
	end

	-- หน้าจอ ---------------------------------------------------------------------

	local rows = {}
	local selected

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
		Parent = breathUI.panel,
	}, { corner(8), startLabel })

	refreshBreathButton = function()
		local text, ready
		if Runner.active and Runner.statusSink == breathUI.setStatus then
			text, ready = "STOP", nil
		elseif Runner.active then
			text, ready = "Auto-Quest กำลังทำงาน", false
		elseif not selected then
			text, ready = "START", false
		elseif currentBreathing() == selected.power then
			text, ready = "มีปราณนี้แล้ว", false
		elseif supportNote(selected) then
			text, ready = "ยังไม่รองรับ · " .. supportNote(selected), false
		else
			text, ready = "START · " .. selected.power .. " Breathing", true
		end
		startLabel.Text = text
		if ready == nil then
			tween(startBtn, { BackgroundColor3 = Theme.Danger }, FAST)
			tween(startLabel, { TextColor3 = Theme.Text }, FAST)
		else
			tween(startBtn, { BackgroundColor3 = ready and Theme.Accent or Theme.Raised }, FAST)
			tween(startLabel, { TextColor3 = ready and Theme.Base or Theme.Dim }, FAST)
		end
	end

	local function paintRows()
		for _, r in ipairs(rows) do
			local on = r.data == selected
			tween(r.tickFill, { BackgroundTransparency = on and 0 or 1 }, FAST)
			r.tickStroke.Color = on and Theme.Accent or Theme.Stroke
			tween(r.frame, { BackgroundColor3 = on and Theme.Raised or Theme.Row }, FAST)
			local missing = missingFor(r.data)
			local note = supportNote(r.data)
			r.right.Text = note and "ยังไม่รองรับ" or (#missing == 0 and "พร้อมรับเควส" or ("ขาด " .. #missing .. " อย่าง"))
			r.right.TextColor3 = note and Theme.Dim or (#missing == 0 and Theme.Accent or Theme.Warn)
			local costs = { comma(r.data.wen) .. " Wen" }
			for _, it in ipairs(r.data.items) do
				costs[#costs + 1] = string.format("%s %d", it.name, it.need)
			end
			r.sub.Text = r.data.npc .. "  ·  " .. table.concat(costs, " · ")
		end
	end

	local function rebuildBreathing()
		local current = currentBreathing()
		breathUI.subtitle.Text = current and ('<font color="#8f8f9e">ปราณตอนนี้</font> ' .. current)
			or '<font color="#8f8f9e">ยังไม่มีปราณ</font>'
		if #rows == 0 then
			for i, b in ipairs(loadBreathing()) do
				local frame = new("Frame", {
					Size = UDim2.new(1, -6, 0, 40),
					BackgroundColor3 = Theme.Row,
					BorderSizePixel = 0,
					LayoutOrder = i,
					Parent = breathUI.list,
				}, { corner(7) })
				local tickFill, tickStroke = tickBox(frame)
				new("TextLabel", {
					Position = UDim2.fromOffset(34, 5),
					Size = UDim2.new(1, -140, 0, 14),
					BackgroundTransparency = 1,
					Text = b.power .. " Breathing",
					TextColor3 = Theme.Text,
					TextSize = 12,
					FontFace = font(Enum.FontWeight.Medium),
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = frame,
				})
				local sub = new("TextLabel", {
					Position = UDim2.fromOffset(34, 20),
					Size = UDim2.new(1, -140, 0, 13),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Dim,
					TextSize = 11,
					FontFace = font(Enum.FontWeight.Regular),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = frame,
				})
				local right = new("TextLabel", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.fromOffset(100, 14),
					BackgroundTransparency = 1,
					TextSize = 11,
					FontFace = font(Enum.FontWeight.Medium),
					TextXAlignment = Enum.TextXAlignment.Right,
					Parent = frame,
				})
				local row = { frame = frame, tickFill = tickFill, tickStroke = tickStroke, sub = sub, right = right, data = b }
				rows[#rows + 1] = row
				local hit = new("TextButton", {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = "",
					Parent = frame,
				})
				track(hit.MouseButton1Click:Connect(function()
					if Runner.active then
						return
					end
					selected = selected ~= b and b or nil
					paintRows()
					if selected then
						local steps = {}
						for _, t in ipairs(b.tasks) do
							steps[#steps + 1] = t.name
						end
						breathUI.setStatus(table.concat(steps, " → "), Theme.Muted)
					end
					refreshBreathButton()
				end))
			end
		end
		local query = breathUI.search.Text:lower()
		for _, r in ipairs(rows) do
			r.frame.Visible = query == "" or r.data.power:lower():find(query, 1, true) ~= nil
		end
		paintRows()
		refreshBreathButton()
	end

	track(breathUI.search:GetPropertyChangedSignal("Text"):Connect(rebuildBreathing))

	track(startBtn.MouseButton1Click:Connect(function()
		if Runner.active then
			if Runner.statusSink == breathUI.setStatus then
				Runner.stop()
				breathUI.setStatus("กำลังยกเลิก…", Theme.Warn)
			end
			return
		end
		if not selected or supportNote(selected) or currentBreathing() == selected.power then
			return
		end
		Runner.active = true
		Runner.cancel = false
		Runner.statusSink = breathUI.setStatus
		refreshBreathButton()
		local target = selected
		task.spawn(function()
			local ok, err = pcall(runBreathing, target)
			if not ok then
				breathUI.setStatus("พัง: " .. tostring(err), Theme.Danger)
				Runner.active = false
				Runner.statusSink = nil
				refreshBreathButton()
			end
		end)
	end))

	local breathFeature = featureRow(
		"Auto-Breathing",
		"เลือกปราณ แล้วทำเควสฝึกให้จนได้ปราณ",
		4,
		function()
			rebuildBreathing()
			breathUI.show()
		end,
		breathUI.hide
	)
	track(breathUI.closeButton.MouseButton1Click:Connect(function()
		breathFeature.setOpen(false)
	end))
end

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

-- เลื่อนได้ แถวเกิน 7 แถวตั้งแต่มี Auto Skill ความสูงแผงรับได้ราว 6.5 แถว
local switchList = new("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 26),
	Size = UDim2.new(1, 0, 1, -26),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = Theme.Stroke,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
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

	-- opts.parent: แท็บ Settings ใช้สวิตช์หน้าตาเดียวกัน แต่วางในหน้าของตัวเอง
	frame.Parent = opts.parent or switchList

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
-- fastKill: Insta Kill โหมดได้ของกำลังยิงหมัดเองตามจังหวะคอมโบของเซิร์ฟ ลูปอื่นห้ามยิงแทรก
-- หมัดแทรกหนึ่งครั้งทำให้เลขคอมโบที่เซิร์ฟจำไว้ไม่ตรงกับที่ Insta Kill ส่ง แล้วเซิร์ฟทิ้งหมัดถัดไปทั้งชุด
local killAura = { on = false, far = false, fastKill = false, lastFire = 0, fires = 0, slotIndex = 0, comboBySlot = {}, lastBySlot = {} }
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
			if mob then
				Runner.hook("engage", mob)
			end
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
					if not killAura.on and not killAura.fastKill then
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
				Runner.hook("loot", tostring(d.item))
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

-- ของเควสเก็บของ: PickupState ของเกมสร้าง Part ไว้ตรง ๆ ใต้ workspace
-- ใส่ ProximityPrompt ActionText = "Pick Up" (ObjectText = "Coin" / "Lost Page" / "Lucky Penny")
-- กดแล้วเกมส่ง SignalEvent "QuestProgress" ให้เอง บาง TaskSpec มี MaxDistance = 25 เลยต้องวาร์ปไปข้างของ
-- ของเควสวางตรงใต้ workspace ได้สองแบบ: Part เปล่า (เหรียญ Liv) กับ Model ที่ prompt อยู่ในพาร์ตลูก
-- (ตราประทับของ Sofen = Workspace."Permit Stamp1".Plane) เดิมหาแต่แบบแรก ตัวละครเลยยืนรอข้างของเฉย ๆ
local function questPickups()
	local list = {}
	for _, child in ipairs(workspace:GetChildren()) do
		local prompt
		if child:IsA("BasePart") then
			prompt = child:FindFirstChildWhichIsA("ProximityPrompt")
		elseif child:IsA("Model") then
			prompt = child:FindFirstChildWhichIsA("ProximityPrompt", true)
		end
		if prompt and prompt.ActionText == "Pick Up" and prompt.Enabled and prompt.Parent:IsA("BasePart") then
			list[#list + 1] = { part = prompt.Parent, prompt = prompt }
		end
	end
	return list
end

Runner.Pickup = {
	-- ยืนที่จุดกลาง (Anchor) เหรียญ Liv ห่างไม่เกิน 15 stud
	-- ไม่ตั้งไกลกว่านี้ เควสบางอันเซิร์ฟเวอร์ให้เก็บได้ในระยะ MaxDistance = 25 เท่านั้น
	SweepRadius = 20,
	SweepGap = 0.03,
}

function Runner.pickup(step, index, total)
	-- ลูปสู้ต้องไม่ทำงาน ไม่งั้นมันดึงตัวกลับไปหาม็อบกลางทางเก็บของ
	attackRow.set(false)
	mobOnlyRow.set(false)
	autoAttack.on = false

	local lastCount, lastMove = nil, os.clock()
	while not Runner.cancel do
		local count = taskProgress(step.pickup)
		if count == nil or count >= step.max then
			return true
		end
		if count ~= lastCount then
			lastCount, lastMove = count, os.clock()
		end
		-- ตัวนับไม่ขยับนานเกินนี้ แปลว่าไม่มีของให้เก็บ หรือเซิร์ฟเวอร์ไม่รับ หยุดดีกว่าวนเปล่า
		if os.clock() - lastMove > 25 then
			return false, "ตัวนับ " .. step.pickup .. " ไม่ขยับ 25 วิ (ไม่เจอของ หรือเก็บไม่เข้า)"
		end

		local _, hrp = selfParts()
		local items = hrp and questPickups() or {}
		if #items == 0 then
			-- ของอาจยังไม่ถูกสร้าง (เกมรอ QuestInstance ก่อน) ไปรอตรงจุดวางของ
			if hrp and step.anchor and (hrp.Position - step.anchor).Magnitude > 20 then
				placeAt(hrp, CFrame.new(step.anchor + Vector3.new(0, 4, 0)), "pickup-anchor")
			end
			report(string.format("[%d/%d] รอของ %s  %d/%d", index, total, step.pickup, count, step.max), Theme.Warn)
			task.wait(0.5)
		else
			-- ของที่อยู่ในระยะ SweepRadius กดพร้อมกันทีเดียวโดยไม่ต้องขยับ ไกลกว่านั้นค่อยวาร์ปไปทีละชิ้น
			-- เหรียญ Liv เกิดวนรอบต้นไม้ในรัศมี 15 stud ครั้งละ 12 อัน เก็บแล้วเกิดใหม่ทันที วัดจริง:
			--   วาร์ปไปทีละเหรียญ รอ 0.4 วิ             2.2 เหรียญ/วิ
			--   ยืนกลางวง กดทุกเหรียญทุก 0.1 วิ         6.8 เหรียญ/วิ
			--   ยืนกลางวง กดทุกเหรียญทุก 0.03 วิ        8.4 เหรียญ/วิ  (500 เหรียญ ~1 นาที)
			-- ของเกิดเป็นวง (Anchor) ยืนกลางวง ของทุกชิ้นจะอยู่ในระยะกวาดพร้อมกัน
			if step.sweepAt and (hrp.Position - step.sweepAt).Magnitude > 5 then
				placeAt(hrp, CFrame.new(step.sweepAt + Vector3.new(0, 3, 0)), "pickup-anchor")
				task.wait(0.3)
			end
			local near, best, bestD = 0, nil, nil
			for _, it in ipairs(items) do
				local d = (it.part.Position - hrp.Position).Magnitude
				if d <= Runner.Pickup.SweepRadius then
					near += 1
					task.spawn(fireproximityprompt, it.prompt)
				end
				if not bestD or d < bestD then
					best, bestD = it, d
				end
			end
			report(string.format("[%d/%d] เก็บ %s  %d/%d", index, total, best.prompt.ObjectText, count, step.max), Theme.Accent)
			if near > 0 then
				-- ยืนนิ่งไว้ แรงโน้มถ่วงดึงตัวออกจากวงถ้าไม่ล้าง velocity
				hrp.AssemblyLinearVelocity = Vector3.zero
				task.wait(Runner.Pickup.SweepGap)
			else
				firePromptAt(best.prompt)
				local untilT = os.clock() + 1
				while best.part.Parent and os.clock() < untilT do
					task.wait(0.05)
				end
			end
		end
	end
	return false, "ยกเลิกแล้ว"
end

-- ฟาร์มไอเทมที่ต้องจ่ายตอนรับเควสปราณ ------------------------------------------
-- ข้อมูลเกมไม่มีตารางดรอป (อยู่ฝั่งเซิร์ฟเวอร์) ใช้จากคู่มือผู้เล่น:
--   Demon Horns  Hoyuzo Subordinate ในถ้ำหลังน้ำตก Bamboo Grove ดรอป 30% ต่อตัว (บอส Hoyuzo x3 ที่ 50%)
--   Beast Core   Beast Born Demon ที่ Mistfall Harbor ราว 1 ใน 3 ตัว
-- ที่มา: allthings.how / nerdschalk.com (ค้นเมื่อ 23 ก.ย. 2026)
Runner.FarmSources = {
	["Demon Horns"] = "HoyuzoSub",
	["Beast Core"] = "BeastBornDemon_MistfallHarbor",
}

local function itemCount(name)
	return Game.wallet()[name] or 0
end

-- ฆ่าม็อบแหล่งดรอปไปเรื่อย ๆ แล้วเก็บของที่ตกเป็นระยะ จนมีไอเทมครบ need ชิ้น
-- ของดรอปเป็น LootDrop ที่ต้องกด Claim เอง เลยหยุดลูปสู้ชั่วคราวตอนเก็บ ไม่งั้นมันดึงตัวกลับไปหาม็อบ
-- code = รหัสม็อบ (NpcCode) ถ้าไม่ส่งมาใช้ FarmSources (ไอเทมรับเควสปราณ)
function Runner.farm(item, need, code)
	code = code or Runner.FarmSources[item]
	local mob
	for _, m in ipairs(Game.mobs()) do
		if m.code == code then
			mob = m
		end
	end
	if not mob then
		return false, "ไม่รู้ว่า " .. item .. " ดรอปจากตัวไหน"
	end

	attackRow.set(false)
	mobOnlyRow.set(false)
	local function startAttack()
		autoAttack.target = mob.name
		autoAttack.onlySelected = false
		if not autoAttack.on then
			autoAttack.on = true
			task.spawn(attackLoop)
		end
	end
	local function stopAttack()
		autoAttack.on = false
		local untilT = os.clock() + 3
		while autoAttack.running and os.clock() < untilT do
			task.wait(0.05)
		end
	end

	goToSpawn(mob.center)
	startAttack()
	-- Webhook บอกในข้อความฆ่าบอสว่าของที่ตามหาดรอปหรือยัง
	Runner.farmTarget = item
	local emptySince
	while not Runner.cancel do
		local have = itemCount(item)
		if have >= need then
			break
		end
		report(string.format("ฟาร์ม %s จาก %s  %d/%d", item, mob.name, have, need), Theme.Accent)

		-- บอสใหญ่ไม่ได้ดรอปของตรง แต่ทิ้งหีบไว้ (Rengu = World Events Chest, Hoyuzo = Rare Chest) เปิดด้วย
		local _, me = selfParts()
		if #myDrops() > 0 or (me and #closedChests(me.Position) > 0) then
			stopAttack()
			local got = collectLoot({
				stop = function()
					return Runner.cancel
				end,
				say = function(text)
					report(string.format("ฟาร์ม %s · %s  %d/%d", item, text, itemCount(item), need), Theme.Accent)
				end,
			})
			if #got > 0 then
				report("เก็บได้: " .. table.concat(got, ", "), Theme.Accent)
			end
			startAttack()
		end

		if liveMobCount(mob.name) == 0 then
			emptySince = emptySince or os.clock()
			if os.clock() - emptySince > 3 then
				goToSpawn(mob.center)
				-- บอสใหญ่เกิดใหม่ทุก 300 วิ บางตัวออกเฉพาะกลางคืน (OnlyAtNight) บอกให้รู้ว่ารออะไรอยู่
				report(string.format("รอ %s เกิดใหม่ (%d วิแล้ว) · %s %d/%d", mob.name,
					math.floor(os.clock() - emptySince), item, itemCount(item), need), Theme.Warn)
			end
		else
			emptySince = nil
		end
		task.wait(1)
	end
	stopAttack()
	autoAttack.target = nil
	Runner.farmTarget = nil
	if Runner.cancel then
		return false, "ยกเลิกแล้ว"
	end
	return true
end

-- วาร์ปไปยืนข้างช่างของสูตรนี้แล้วสั่งตี แบบเดียวกับปุ่ม Craft ในหน้าคุยช่าง (Blacksmith.Recipe)
-- SignalFunction.ToServer("CraftRecipe", รหัสสูตร) ตอบ { Ok, Reason } ไม่ต้องเปิดหน้าคุยก่อน
-- Reason บอกของที่ขาดตัวแรกตรง ๆ เช่น "You need 1 Crude Iron Ingot" เลยส่งต่อให้ผู้ใช้เห็นเลย
function Runner.craftAt(id, recipe)
	local npcName = Game.Forges[recipe.station]
	local spawn = npcName and npcSpawnPoint(npcName)
	if not spawn then
		return false, "ไม่รู้ตำแหน่งช่างของ " .. tostring(recipe.station)
	end
	local _, hrp = selfParts()
	if not hrp then
		return false, "ไม่พบตัวละคร"
	end
	report(string.format("วาร์ปไปหา %s เพื่อตี %s", npcName, recipe.result), Theme.Accent)
	placeAt(hrp, CFrame.new(spawn.pos + Vector3.new(0, 3, 5), spawn.pos), "forge")

	local npc
	for _ = 1, 40 do
		if Runner.cancel then
			return false, "ยกเลิกแล้ว"
		end
		npc = findLiveNpc(npcName)
		if npc then
			break
		end
		task.wait(0.3)
	end
	if not npc then
		return false, npcName .. " ยังไม่ stream เข้ามาใน 12 วิ"
	end
	-- ระยะเดียวกับตอนคุยเควส (prompt ช่างทั้งสองคนยอมรับที่ 10) ลองแล้วเซิร์ฟนับว่ายืนที่โรงตี
	local pos = npc:GetPivot().Position
	placeAt(hrp, CFrame.new(pos + Vector3.new(0, 0, 4), pos), "forge")
	hrp.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.6)

	local before = itemCount(recipe.result)
	local SignalFunction = require(ReplicatedStorage.Communication.ServerAndClient.Signals.SignalFunction)
	local sent, res = pcall(SignalFunction.ToServer, "CraftRecipe", id)
	if not sent then
		return false, tostring(res)
	end
	if not (type(res) == "table" and res.Ok) then
		return false, string.format("%s ไม่ยอมตี: %s", npcName, type(res) == "table" and tostring(res.Reason) or "ไม่ตอบ")
	end
	-- ของเข้ากระเป๋าตามหลังคำตอบนิดหน่อย รอให้นับเจอก่อน ไม่งั้นรอบถัดไปคิดว่ายังไม่ได้แล้วตีซ้ำ
	local untilT = os.clock() + 3
	while itemCount(recipe.result) <= before and os.clock() < untilT do
		task.wait(0.2)
	end
	report(string.format("ตี %s สำเร็จ", recipe.result), Theme.Accent)
	return true
end

-- ทำให้มี name อย่างน้อย need ชิ้น เลือกทางด้วย Game.plan บนกระเป๋าจริง (ซื้อ > ฟาร์ม > ตี)
-- ตีได้หลายชั้น เช่น Nightfall Claws <- Damascus Claws <- Claws (ดรอป) + Mythic Refinement Ore (หีบบอส)
-- วางแผนใหม่ทุกชั้นทุกรอบ เพราะระหว่างฟาร์มอาจได้ของอื่นติดมา หรือการตีชั้นล่างกินวัตถุดิบไปแล้ว
function Runner.obtain(name, need)
	-- ซื้อ Metal Scraps 1000 ชิ้นใช้ 11 รอบ (ครั้งละ 99) เผื่อไว้ 3 เท่า เกินนี้แปลว่าวนไม่จบ
	local rounds = 0
	while not Runner.cancel do
		rounds += 1
		if rounds > 40 then
			return false, "หา " .. name .. " วนเกิน 40 รอบ ของไม่เพิ่ม"
		end
		local have = itemCount(name)
		if have >= need then
			return true
		end
		local o = Game.newPlan()
		local err = Game.plan(name, need, Game.wallet(), o)
		if err then
			return false, err
		end
		local how = o.how[name]
		if how.kind == "shop" then
			report(string.format("ซื้อ %s  %d/%d", name, have, need), Theme.Accent)
			-- ครั้งละไม่เกิน 99 ตามที่เซิร์ฟรับ (Shop.SanitizeAmount)
			local row = { name = name, source = "shop", cost = priceParts(how.listing.Price) }
			local ok, msg = Game.buy(row, math.min(need - have, 99))
			if not ok then
				return false, msg
			end
			task.wait(0.5)
		elseif how.kind == "farm" then
			return Runner.farm(name, need, how.route.code)
		else
			for _, input in ipairs(Game.recipeInputs(how.recipe)) do
				local ok, why = Runner.obtain(input.name, input.amount)
				if not ok then
					return false, why
				end
			end
			-- วัตถุดิบที่หามาทีหลังอาจกินของที่หามาก่อน (ซื้อด้วย Wen ก้อนเดียวกัน) วนกลับไปวางแผนใหม่ถ้าไม่ครบ
			local ready = true
			for _, input in ipairs(Game.recipeInputs(how.recipe)) do
				ready = ready and itemCount(input.name) >= input.amount
			end
			if ready then
				local ok, why = Runner.craftAt(how.id, how.recipe)
				if not ok then
					return false, why
				end
			end
		end
	end
	return false, "ยกเลิกแล้ว"
end

-- ตกปลากับงานใส่ลัง (เควสของ Angler Runo) -----------------------------------------

-- ฟังก์ชันที่เรียกทันทีแยกโควตา register จาก chunk หลัก เหตุผลเดียวกับแท็บ Settings
-- ข้างนอกใช้แค่ Runner.deposit (runStep) กับ Runner.fish
;(function()
local Fishing = {
	-- เรียงจากดีสุด มีตัวไหนใช้ตัวนั้น ไม่มีเลยซื้อ Basic (3,500 Wen ที่ Jeso ต้องจบเควสใบอนุญาตก่อน)
	Rods = { "Legendary Fishing Rod", "Rare Fishing Rod", "Basic Fishing Rod" },
	-- ระยะโยนจริงคือ CastRadius ของ FishingHandler ฝั่งเซิร์ฟ มองไม่เห็นจาก client
	-- เลือกจุดยืนที่น้ำห่างไม่เกินนี้ 8 เป็นค่าเผื่อ ยังไม่ได้วัดว่าเบ็ดโยนได้ไกลสุดเท่าไร
	CastReach = 8,
	-- เซิร์ฟสุ่มรอปลากิน 4-9 วิ / BiteSpeedMultiplier (Rare Fishing RodServer) 30 วิครอบเบ็ดที่ช้าสุด
	BiteTimeout = 30,
	-- รอก่อนบอกเซิร์ฟว่าชนะมินิเกม เซิร์ฟไม่ได้จับเวลา (รับ verdict ทันทีที่ token ตรง)
	-- แต่คนเล่นจริงใช้เวลาดันแถบจาก 50% ไป 100% ไม่ส่งทันทีจะได้ไม่ผิดสังเกต ค่าเดา ไม่ได้วัดเวลาคนเล่น
	-- ชนะแล้วยังได้ของไม่ทุกครั้ง เซิร์ฟสุ่ม CatchChance อีกชั้น เบ็ด Basic ไม่ใส่เหยื่อ ลอง 6 ครั้งได้ 2
	-- (OuwFwesh 1, Silk Thread 1) ที่เหลือ "slipped" ไม่มีตัวปลาโผล่
	WinDelay = 2,
	-- สแกนหาริมน้ำรอบจุดตั้งต้น น้ำเปิดที่ใกล้ลังของ Runo สุดอยู่ห่าง ~64 stud (วัดจากจุด -574,800,681)
	ScanRadius = 90,
	ScanStep = 3,
}

local ToolbarSlots = { "One", "Two", "Three", "Four", "Five" }
local FishFolder = ReplicatedStorage.Items:FindFirstChild("Fishing")

-- ปลา = ของในโฟลเดอร์ Fishing ที่ถือไม่ได้ (เบ็ดกับเหยื่อมี EquipType)
local function isFish(itemName)
	local m = FishFolder and FishFolder:FindFirstChild(itemName)
	return m ~= nil and require(m).EquipType == nil
end

-- มินิเกมตอนปลากิน (BarKeepup) ให้ชนะเองระหว่างตกปลาอัตโนมัติ นอกนั้นเล่นตามปกติ
-- rod script ถือตัวฟังก์ชันไว้เป็น upvalue แทนฟิลด์ไม่ได้ ต้อง hookfunction ตัวฟังก์ชันเลย
-- รันสคริปต์ใหม่แล้ว hook ซ้อนทับกันเรื่อย ๆ เก็บตัวจริงไว้ใน _G ทำครั้งเดียวต่อรอบเกม
if not _G.PathSlayerBarKeepup and typeof(hookfunction) == "function" then
	local BarKeepup = require(ReplicatedStorage.CAM.Client.Components.NonePackagedMisc.Minigames.BarKeepup)
	local real
	real = hookfunction(BarKeepup, newcclosure(function(gui, opts)
		local delay = _G.PathSlayerAutoFish
		if delay and type(opts) == "table" and opts.Stop then
			task.delay(delay, function()
				-- Stop ส่ง verdict ผ่าน portal ของเกม รันจาก thread ที่ executor สร้างอาจเจอปัญหา require
				-- แบบเดียวกับ Auto Skill เลยลด identity เป็นของ LocalScript ก่อน
				if setthreadidentity then
					setthreadidentity(2)
				end
				opts.Stop(true)
			end)
			return
		end
		return real(gui, opts)
	end))
	_G.PathSlayerBarKeepup = real
end
track({
	Disconnect = function()
		_G.PathSlayerAutoFish = nil
	end,
})

local function inventoryItem(name)
	local slot = equippedSlot()
	local bag = slot and slot.Inventory:FindFirstChild("Inventory")
	return bag and bag:FindFirstChild(name)
end

-- ใส่เบ็ดขึ้น toolbar ถ้ายังไม่มี แบบเดียวกับปุ่มในหน้ากระเป๋า: Toolbar_Equip(ชื่อช่อง, Id ของ)
-- ใช้แต่ช่องว่าง ไม่เอาของที่ผู้เล่นวางไว้ออก คืนเลขช่อง
local function rodSlot(rodName)
	local rod = inventoryItem(rodName)
	local id = rod and rod:FindFirstChild("Id")
	if not id then
		return nil, "ไม่พบ " .. rodName .. " ในกระเป๋า"
	end
	local bar = equippedSlot().Inventory.Toolbar
	for i, slotName in ipairs(ToolbarSlots) do
		if bar[slotName].Value == id.Value then
			return i
		end
	end
	for i, slotName in ipairs(ToolbarSlots) do
		if bar[slotName].Value == 0 then
			SignalEvent.ToServer("Toolbar_Equip", slotName, id.Value)
			local untilT = os.clock() + 3
			while bar[slotName].Value ~= id.Value and os.clock() < untilT do
				task.wait(0.1)
			end
			if bar[slotName].Value == id.Value then
				return i
			end
			return nil, "ใส่เบ็ดขึ้น toolbar ไม่ติด"
		end
	end
	return nil, "toolbar เต็มทั้ง 5 ช่อง เอาของออกหนึ่งช่องให้เบ็ดก่อน"
end

-- หาจุดยืนบนบกที่มีน้ำเปิดอยู่ในระยะโยน ใกล้ near ที่สุด
-- น้ำคือพาร์ตที่เกมแท็ก SwimParts (ตัวเดียวกับที่เซิร์ฟใช้เช็กว่าโยนลงน้ำไหม) ต้อง stream มาก่อนถึงจะเห็น
-- น้ำเปิด = ไม่มีอะไรบังข้างบน เซิร์ฟตัดทิ้งถ้ามีพื้นทับผิวน้ำ (findWater ใน Rare Fishing RodServer)
local spotCache = {}
local function fishingSpot(near)
	local key = tostring(near)
	if spotCache[key] then
		return spotCache[key].stand, spotCache[key].water
	end
	local waterParents = {}
	for _, v in ipairs(game:GetService("CollectionService"):GetTagged("SwimParts")) do
		waterParents[#waterParents + 1] = v.Parent or v
	end
	if #waterParents == 0 then
		return nil
	end
	local onlyWater = RaycastParams.new()
	onlyWater.FilterType = Enum.RaycastFilterType.Include
	onlyWater.FilterDescendantsInstances = waterParents
	onlyWater.BruteForceAllSlow = true
	local solid = RaycastParams.new()
	solid.FilterType = Enum.RaycastFilterType.Exclude
	solid.FilterDescendantsInstances = { LocalPlayer.Character, workspace:FindFirstChild("Debree"), workspace:FindFirstChild("Humanoids") }

	local waters, lands = {}, {}
	local r, s = Fishing.ScanRadius, Fishing.ScanStep
	for dx = -r, r, s do
		for dz = -r, r, s do
			local top = near + Vector3.new(dx, 80, dz)
			local w = workspace:Raycast(top, Vector3.new(0, -160, 0), onlyWater)
			local g = workspace:Raycast(top, Vector3.new(0, -160, 0), solid)
			local groundIsWater = g and w and g.Instance:IsDescendantOf(w.Instance.Parent)
			if w and (not g or groundIsWater or g.Position.Y <= w.Position.Y + 0.1) then
				waters[#waters + 1] = w.Position
			elseif g and not groundIsWater and (not w or g.Position.Y > w.Position.Y + 0.5) then
				lands[#lands + 1] = g.Position
			end
		end
	end
	table.sort(lands, function(a, b)
		return (a - near).Magnitude < (b - near).Magnitude
	end)
	for _, land in ipairs(lands) do
		for _, water in ipairs(waters) do
			local flat = Vector3.new(water.X - land.X, 0, water.Z - land.Z).Magnitude
			if flat >= 3 and flat <= Fishing.CastReach then
				spotCache[key] = { stand = land + Vector3.new(0, 3, 0), water = water }
				return spotCache[key].stand, water
			end
		end
	end
	return nil
end

local function click(pos)
	SignalEvent.ToServer("Tool_Mouse", "Down", pos)
	SignalEvent.ToServer("Tool_Mouse", "Up", pos)
end

local function waitFor(check, seconds)
	local untilT = os.clock() + seconds
	while not check() and os.clock() < untilT and not Runner.cancel do
		task.wait(0.1)
	end
	return check()
end

-- targets = { [ชื่อปลา] = จำนวนที่ต้องมีในกระเป๋า } ตกจนครบทุกชนิด near = จุดตั้งต้นหาริมน้ำ
-- ปลาหายาก (Clown / Zebra Fish) Runo บอกเองว่า "come up rare" ไม่มีวิธีเลือก ตกไปเรื่อย ๆ จนได้
function Runner.fish(targets, near, prefix)
	prefix = prefix or ""
	local rodName
	for _, name in ipairs(Fishing.Rods) do
		rodName = rodName or ((Game.wallet()[name] or 0) > 0 and name or nil)
	end
	if not rodName then
		rodName = Fishing.Rods[#Fishing.Rods]
		report(prefix .. "ยังไม่มีเบ็ด ไปซื้อ " .. rodName, Theme.Accent)
		local ok, err = Runner.obtain(rodName, 1)
		if not ok then
			return false, "ซื้อเบ็ดไม่ได้: " .. tostring(err)
		end
	end
	local slotIndex, err = rodSlot(rodName)
	if not slotIndex then
		return false, err
	end

	-- ลูปสู้กับ Kill Aura สลับไปถืออาวุธเองทุกรอบ ต้องหยุดก่อน ไม่งั้นเบ็ดหลุดมือกลางคัน
	attackRow.set(false)
	mobOnlyRow.set(false)
	autoAttack.on = false
	local auraWasOn = Runner.auraOn()
	if auraWasOn then
		Runner.setAura(false)
	end

	local _, hrp = selfParts()
	placeAt(hrp, CFrame.new(near + Vector3.new(0, 4, 0)), "fishing-scan")
	task.wait(2)
	local stand, water = fishingSpot(near)
	if not stand then
		if auraWasOn then
			Runner.setAura(true)
		end
		return false, "หาริมน้ำที่โยนเบ็ดได้ไม่เจอในระยะ " .. Fishing.ScanRadius .. " stud"
	end

	_G.PathSlayerAutoFish = Fishing.WinDelay
	local caught = 0
	local function done()
		for name, need in pairs(targets) do
			if (Game.wallet()[name] or 0) < need then
				return false
			end
		end
		return true
	end
	local function progress()
		local parts = {}
		for name, need in pairs(targets) do
			parts[#parts + 1] = string.format("%s %d/%d", name, math.min(Game.wallet()[name] or 0, need), need)
		end
		table.sort(parts)
		return table.concat(parts, " · ")
	end

	-- ปลาที่ติดเบ็ดไม่เข้ากระเป๋าเอง เซิร์ฟแขวนไว้เป็นโมเดล Debree.FishingCatch_N (attribute CatchItem)
	-- มี prompt "Collect" กดค้าง 2 วิ ของเข้ากระเป๋าตอนกด prompt นี้เท่านั้น
	local catchModel
	local watch = workspace.Debree.ChildAdded:Connect(function(child)
		if child.Name:find("^FishingCatch_") then
			catchModel = child
		end
	end)

	local result, why = true, nil
	local misses = 0
	while not done() do
		if Runner.cancel then
			result, why = false, "ยกเลิกแล้ว"
			break
		end
		_, hrp = selfParts()
		if not hrp then
			task.wait(1)
		else
			if (hrp.Position - stand).Magnitude > 4 then
				placeAt(hrp, CFrame.lookAt(stand, Vector3.new(water.X, stand.Y, water.Z)), "fishing")
				hrp.AssemblyLinearVelocity = Vector3.zero
				task.wait(0.5)
			end
			-- เช็กของในมือจริงทุกรอบ ไม่ใช่แค่เลขช่อง: ระหว่างทดสอบช่องที่ใส่เบ็ดไว้กลายเป็น Spear
			-- ช่องยังเป็นเลขเดิม แต่ในมือถือหอก โยนไป 5 ครั้งไม่มีอะไรเกิดขึ้นเลย
			local accessories = LocalPlayer.Character:FindFirstChild("Tool_Accessories")
			if not (accessories and accessories:FindFirstChild(rodName)) then
				local newSlot, slotErr = rodSlot(rodName)
				if not newSlot then
					result, why = false, slotErr
					break
				end
				slotIndex = newSlot
				-- เลขช่องเดิมซ้ำไม่ทำให้ .Changed ยิง เกมเลยไม่สลับของ ปลดก่อนแล้วค่อยถือใหม่
				if heldSlot() == slotIndex then
					equipSlot(0)
					task.wait(0.3)
				end
				equipSlot(slotIndex)
				task.wait(1)
			end

			report(string.format("%sโยนเบ็ด · ได้แล้ว %d ตัว · %s", prefix, caught, progress()), Theme.Accent)
			catchModel = nil
			-- สถานะสายดูจากเสียงที่เซิร์ฟเล่นใต้ HumanoidRootPart ไม่เดาจากเวลา
			-- PS2fishingCAST* = โยนออกแล้ว, PS2fishingRECALL = ดึงกลับ
			-- เคยเดาเอง: สายค้างอยู่ตอนเริ่ม (หยุดกลางคันแล้วรันใหม่) คลิกแรกเลยกลายเป็นดึงกลับ
			-- แล้วลูปเพี้ยนจังหวะไปตลอด โยนแล้วดึงกลับทุก 2.5 วิ ไม่มีปลากินเลย
			local heard
			local ear = hrp.ChildAdded:Connect(function(child)
				if child.Name:find("^PS2fishingCAST") then
					heard = "cast"
				elseif child.Name == "PS2fishingRECALL" then
					heard = "recall"
				end
			end)
			click(water)
			waitFor(function()
				return heard ~= nil
			end, 1.5)
			local cast = heard == "cast"
			if cast then
				heard = nil
				-- จบรอเมื่อปลากิน หรือเซิร์ฟดึงสายกลับเอง (โยนไม่ลงน้ำ เซิร์ฟ uncast ภายใน ~1 วิ)
				waitFor(function()
					return LocalPlayer:GetAttribute("FishingBite") == true or heard == "recall"
				end, Fishing.BiteTimeout)
			end
			ear:Disconnect()
			if not cast or LocalPlayer:GetAttribute("FishingBite") ~= true then
				if cast and heard ~= "recall" then
					-- ไม่มีปลากินในเวลาที่ควร (วัดได้ 7-12 วิทุกครั้ง) ดึงสายกลับก่อนโยนใหม่
					click(water)
				end
				misses += 1
				if misses >= 5 then
					result, why = false, "โยนเบ็ดแล้วไม่มีปลากิน 5 ครั้งติด (จุดนี้อาจโยนไม่ถึงน้ำ)"
					break
				end
				task.wait(2.5)
			else
				misses = 0
				report(string.format("%sปลากิน! · %s", prefix, progress()), Theme.Accent)
				waitFor(function()
					return LocalPlayer:GetAttribute("FishingBite") == nil
				end, Fishing.WinDelay + 5)
				-- ห้ามคลิกดึงสายเอง เซิร์ฟดึงให้ทันทีที่รับผลมินิเกม (uncast ใน startBiteLoop)
				-- เคยคลิกตรงนี้ กลายเป็นโยนสายใหม่ แล้วคลิกถัดไปดึงกลับ วนโยน-ดึงไม่รู้จบ ได้ปลา 0 ตัว
				waitFor(function()
					return catchModel ~= nil
				end, 3)
				local model = catchModel
				if model then
					-- ตัวปลาถูกดึงมาแขวนที่ปลายเบ็ดก่อน (finishCatchPull สูงสุด 4 วิ) รอ 2.2 วิแล้วกดเก็บทุกครั้งที่ลอง
					task.wait(2.2)
					local item = model:GetAttribute("CatchItem")
					local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
					local before = item and (Game.wallet()[item] or 0) or 0
					if prompt then
						fireproximityprompt(prompt)
					end
					if item and waitFor(function()
						return (Game.wallet()[item] or 0) > before
					end, 4) then
						caught += 1
						report(string.format("%sได้ %s · %s", prefix, item, progress()), Theme.Accent)
					end
				end
				-- เซิร์ฟรีเซ็ตสายหลังดึง 1.4 วิ โยนก่อนนั้นไม่ติด
				task.wait(2)
			end
		end
	end
	watch:Disconnect()
	_G.PathSlayerAutoFish = nil
	if auraWasOn then
		Runner.setAura(true)
	end
	return result, why
end

-- งานใส่ลัง (DepositState): หาของให้ครบ แล้วยืนที่ลังยิง QuestProgress ทีละชิ้น
-- เกมยิงแบบเดียวกันตอนกดค้างที่ลัง (ทุก 0.15 วิ) เซิร์ฟเช็กว่ายืนอยู่ที่ Position ของงาน
function Runner.deposit(step, index, total)
	local prefix = string.format("[%d/%d] ", index, total)
	local need, fish = {}, {}
	for _, row in ipairs(step.rows) do
		local left = row.max - (taskProgress(row.task) or 0)
		if left > 0 then
			need[row.item] = (need[row.item] or 0) + left
		end
	end
	for item, n in pairs(need) do
		if isFish(item) then
			fish[item] = n
		else
			local ok, err = Runner.obtain(item, n)
			if not ok then
				return false, err
			end
		end
	end
	if next(fish) then
		local ok, err = Runner.fish(fish, step.position, prefix)
		if not ok then
			return false, err
		end
	end

	local _, hrp = selfParts()
	placeAt(hrp, CFrame.new(step.position + Vector3.new(0, 3, 3), step.position), "deposit")
	hrp.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.8)
	for _, row in ipairs(step.rows) do
		while (taskProgress(row.task) or row.max) < row.max do
			if Runner.cancel then
				return false, "ยกเลิกแล้ว"
			end
			if itemCount(row.item) == 0 then
				return false, "ของไม่พอใส่ลัง: " .. row.item
			end
			local before = taskProgress(row.task)
			report(string.format("%sใส่ลัง %s  %d/%d", prefix, row.item, before, row.max), Theme.Accent)
			SignalEvent.ToServer("QuestProgress", step.deposit, row.task)
			if not waitFor(function()
				return (taskProgress(row.task) or row.max) > before
			end, 3) then
				return false, "ลังไม่รับ " .. row.item .. " (ยืนไม่ถึงจุดวาง หรือเซิร์ฟปฏิเสธ)"
			end
			task.wait(0.15)
		end
	end
	return true
end
end)()

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
		if killAura.fastKill then
			auraRow.setDesc("Insta Kill ยิงหมัดแทนอยู่")
			task.wait(Aura.Interval)
		-- ระหว่างหลบ ตัวอยู่ไกลเป้า ยิงไปก็ไม่เข้า ได้แต่เผาโควตาความถี่ของเซิร์ฟเวอร์
		elseif hrp and hum and hum.Health > 0 and not isKnockedDown(hum) and os.clock() >= autoDodge.holdUntil then
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
				Runner.hook("engage", mob)
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

-- Auto Skill: ใช้สกิลของอาวุธ/ปราณที่ถืออยู่ใส่ม็อบใกล้ตัว --------------------------

-- Mastery ของปราณ (Flame Mastery ฯลฯ) ขึ้นจากดาเมจของสกิลปราณเท่านั้น
-- หมัดจาก Auto-Attack / Kill Aura นับเข้า Mastery ของอาวุธ (Sword) เลยต้องมีตัวนี้
-- ฟังก์ชันที่เรียกทันทีแยกโควตา register จาก chunk หลัก เหตุผลเดียวกับแท็บ Settings
;(function()
local SkillCast = {
	-- ม็อบในระยะนี้ถึงจะใช้สกิล ยังไม่ได้วัดระยะสกิลจริงทีละท่า
	-- 15 เผื่อจากระยะหมัด 6 ของ Kill Aura สกิลปราณส่วนใหญ่พุ่งไปข้างหน้าไกลกว่าหมัด
	Range = 15,
	-- กดค้างแล้วปล่อย สกิลปราณชาร์จได้ถึง 5 วิ (Max_Hold) ปล่อยเร็วคือออกท่าแบบไม่ชาร์จ
	-- 0.15 เป็นค่าเดา ยังไม่ได้วัดว่าชาร์จนานขึ้นดาเมจเพิ่มคุ้มเวลาไหม
	HoldTime = 0.15,
	-- เว้นหลังออกท่าก่อนสั่งท่าถัดไป ให้แอนิเมชันเล่นจบ ค่าเดา ยังไม่ได้วัด
	Gap = 0.6,
	-- รอบเช็กตอนไม่มีท่าพร้อม ถี่พอให้กดได้ภายใน 0.1 วิหลังคูลดาวน์หมด การเช็กแค่อ่านลูกของ SHCS ไม่ได้ยิงอะไร
	Idle = 0.1,
}

local SkillController = require(ReplicatedStorage.CAM.Client.Controllers.Skill_Controller)
local SkillsProvider = require(ReplicatedStorage.CAM.Client.Controllers.Skills_Provider)
local PlatformHandler = require(ReplicatedStorage.CAM.Client.Controllers.Platform_Handler)
local InputHandler = require(ReplicatedStorage.CAM.Client.Components.Client.InputHandler)

-- สกิลเล็งจากตำแหน่งเมาส์ (Platform_Handler.mousepos) ระหว่างใช้สกิลให้มันคืนตัวม็อบแทน
-- Skill_Controller เรียกผ่านตารางทุกครั้ง แทนฟิลด์ในตารางจึงมีผลทันที
local aim = {}
local realMousePos = PlatformHandler.mousepos
PlatformHandler.mousepos = function(...)
	if aim.pos then
		return aim.pos
	end
	return realMousePos(...)
end
-- unload ไล่ Disconnect ทุกตัวใน conns ฝากตัวคืนค่าเดิมไว้ในรูปเดียวกัน
track({
	Disconnect = function()
		PlatformHandler.mousepos = realMousePos
	end,
})

-- ช่องสกิลบน HUD ผูกกับปุ่มตาม InputHandler (Skills_1st = F, Skills_2nd = Z ...) ผู้เล่นเปลี่ยนปุ่มเองได้
local SlotActions = { "Skills_1st", "Skills_2nd", "Skills_3rd", "Skills_4th", "Skills_5th", "Skills_6th", "Skills_7th" }
local function keyOf(slot)
	for _, k in ipairs(InputHandler.GetMapping(SlotActions[slot]) or {}) do
		if typeof(k) == "EnumItem" and not (k.Name:find("^Button") or k.Name:find("^DPad") or k.Name:find("^Thumb")) then
			return k.Name
		end
	end
	return tostring(slot)
end

-- ช่อง 1 คือ Blocking (F) เสมอ ไม่เอามาใช้ เลือกได้ตั้งแต่ช่อง 2 (Z) ถึงช่อง 7
local choices = {}
for slot = 2, #SlotActions do
	choices[#choices + 1] = keyOf(slot)
end
local autoSkill = { on = false, picked = {}, casts = 0 }
for i = 1, #choices do
	autoSkill.picked[i] = true
end

local skillRow
-- เรียกฟังก์ชันของ Skill_Controller ในฐานะ LocalScript ของเกม (identity 2) แล้วคืนกลับทันที
-- Attempt_Hold require โมดูลเพิ่มกลางทาง จาก thread ของ executor (identity 8) พังด้วย
-- "Cannot require a non-RobloxScript module from a RobloxScript"
-- เคยลดทั้งลูปเป็น 2: ใช้สกิลได้ครั้งเดียวแล้วลูปตายเงียบ เพราะ identity 2 แตะ GUI ของเรา (อยู่ใน gethui) ไม่ได้
-- skillRow.setDesc หลังใช้สกิลครั้งแรกเลย error ทิ้งทั้ง thread
-- ลองแบบลดเป็น 2 แล้วตั้งกลับ 8 หลังเรียกเสร็จ ก็ยังพัง: Attempt_Hold yield ข้างใน (~0.46 วิ)
-- หลัง resume thread กลับไปเป็น 2 อีก setDesc ถัดมาเจอ "lacking capability Plugin"
-- เลยแยกไปเรียกใน thread ลูกที่ตั้ง 2 ครั้งเดียวแล้วทิ้ง thread ลูปไม่เคยถูกเปลี่ยน identity
local function asGame(fn, ...)
	local args = table.pack(...)
	local result
	task.spawn(function()
		if setthreadidentity then
			setthreadidentity(2)
		end
		result = table.pack(pcall(fn, table.unpack(args, 1, args.n)))
	end)
	while not result do
		task.wait()
	end
	return table.unpack(result, 1, result.n)
end

-- คูลดาวน์อยู่ที่เซิร์ฟ: SHCS.<ชื่อ> ใต้ตัวละคร (replicate มาให้เห็น) ลบเลขฝั่ง client (SHC) แล้วกดซ้ำ
-- ท่าเล่นบนจอแต่ไม่มีดาเมจ วัดกับ Hoyuzo: ใช้จริง 374 -> 279, ลบคูลดาวน์แล้วกดซ้ำ 279 -> 264 (แค่ Kill Aura)
-- สแปมไม่ติดคูลดาวน์จึงทำไม่ได้ ทำได้แค่กดทันทีที่เซิร์ฟปลดคูลดาวน์ ท่าไหนใช้ชื่อคูลดาวน์ร่วม (CoolDownName) ดูชื่อนั้น
local function onCooldown(skill)
	local ch = LocalPlayer.Character
	local cdName = skill.CoolDownName or skill.Name
	for _, holder in ipairs({ "SHCS", "SHC" }) do
		local v = ch and ch:FindFirstChild(holder)
		if v and v:FindFirstChild(cdName) then
			return true
		end
	end
	return false
end

-- เวลาคูลดาวน์ที่เหลือ อ่านจาก SHC ฝั่ง client (Value = ทั้งหมด, attribute Started = os.clock ตอนเริ่ม)
-- SHCS ของเซิร์ฟใช้นาฬิกาเซิร์ฟ เทียบกับ os.clock ฝั่งเราไม่ได้
local function cooldownLeft(skill)
	local shc = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("SHC")
	local v = shc and shc:FindFirstChild(skill.CoolDownName or skill.Name)
	local started = v and v:GetAttribute("Started")
	return started and math.max(0, v.Value - (os.clock() - started)) or nil
end

-- สกิลมาจากของในมือ (get_current_keys ดูจาก tool ที่ถือ) Auto-Attack ถือช่องแรกที่ติ๊กใน Auto-Equip-Weapon
-- ทดสอบจริง: ช่อง 1 เป็น Axe and Mace มีแค่ Blocking ลูปเลยไม่มีสกิลให้กดเลยทั้งที่ม็อบอยู่ห่าง 3 stud
-- ส่วน Kill Aura ตอนนั้นถือช่อง 2 (Regular Katana ใช้ท่าปราณไฟได้) เลยเหมือนทำงานแค่บางที
-- หาช่องที่ติ๊กไว้ซึ่งมีสกิลจริง (ดาบที่ใช้ปราณเราได้ หรือมีท่าอื่นนอกจาก Blocking) เลือกในช่องที่ติ๊กเท่านั้น
-- Auto-Attack ยอมรับทุกช่องที่ติ๊ก (weaponReady) จะได้ไม่สลับแย่งกันไปมา
local ItemDefs = require(ReplicatedStorage.CAM.Global.Collectibles.Items)
local ToolbarSlotNames = { "One", "Two", "Three", "Four", "Five" }

-- อาวุธใช้ท่าปราณของเราได้ไหม เงื่อนไขเดียวกับ Skills_Provider.get_current_keys:
-- Breathing ของอาวุธเป็น "All" หรือมีชื่อปราณเรา และไม่มี "except<ชื่อปราณเรา>"
-- ห้ามดูแค่ว่ามีฟิลด์ Breathing: Axe and Mace ช่อง 1 เป็นอาวุธปราณหิน (Stone Breathing Weapon)
-- ตัวละครปราณไฟถือแล้วได้แค่ Blocking ลูปเลยเลือกช่องนี้แล้วไม่มีท่าให้กดตลอด
local function breathingFits(def)
	local weapon = type(def.Breathing) == "string" and def.Breathing:lower()
	local slot = equippedSlot()
	local mine = slot and slot:FindFirstChild("Powers") and slot.Powers:FindFirstChild("Breathing")
	mine = mine and mine.Value:lower() or ""
	return weapon and mine ~= ""
		and (weapon:find("all", 1, true) or weapon:find(mine, 1, true))
		and not weapon:find("except" .. mine, 1, true)
end

local function skillWeaponSlot()
	local slot = equippedSlot()
	local bar = slot and slot.Inventory:FindFirstChild("Toolbar")
	for i, slotName in ipairs(ToolbarSlotNames) do
		local id = weaponSlots[i] and bar and bar:FindFirstChild(slotName) and bar[slotName].Value or 0
		for _, item in ipairs(id ~= 0 and slot.Inventory.Inventory:GetChildren() or {}) do
			local itemId = item:FindFirstChild("Id")
			local def = itemId and itemId.Value == id and ItemDefs[item.Name]
			if def and (breathingFits(def) or (def.Skills and #def.Skills > 1)) then
				return i, item.Name
			end
		end
	end
	return nil
end

local function skillLoop()
	-- ท่าที่ยังล็อก (ไม่ได้ปลดใน Skill Tree) Attempt_Hold คืน nil ทั้งที่ไม่ติดคูลดาวน์ พักไว้ 5 วิ ไม่ต้องลองทุกรอบ
	local lockedUntil = {}
	local lastText, lastCast = nil, nil
	-- ย้ายการเรียกเกมไปไว้ thread ลูก (asGame) แล้วลูปยังพังเหมือนเดิม: หลังใช้สกิลแล้ว yield
	-- thread ลูปเองกลายเป็น identity ต่ำด้วย (executor ตัวนี้ identity ของลูกรั่วกลับมาที่แม่)
	-- จำ identity ตอนเริ่มไว้ แล้วตั้งคืนก่อนแตะ GUI ทุกครั้ง
	local myIdentity = getthreadidentity and getthreadidentity()
	-- แถวสถานะต้องขยับตลอด เดิมค้างข้อความใช้สกิลครั้งล่าสุด ม็อบหลุดระยะแล้วดูเหมือนลูปหยุด ทั้งที่ยังรออยู่
	local function show(text)
		if text ~= lastText then
			lastText = text
			if setthreadidentity and myIdentity then
				setthreadidentity(myIdentity)
			end
			skillRow.setDesc(text)
		end
	end
	while autoSkill.on do
		local _, hrp, hum = selfParts()
		local mob = hrp and hum and hum.Health > 0 and not isKnockedDown(hum) and mobInReach(hrp.Position, SkillCast.Range)
		local used = false
		local blocked
		if mob and #(SkillsProvider.get_current_keys() or {}) < 2 then
			local weaponSlot = skillWeaponSlot()
			if not weaponSlot then
				blocked = "อาวุธในมือไม่มีสกิล · ติ๊กช่องดาบที่ใช้ปราณได้ใน Auto-Equip-Weapon"
			elseif heldSlot() ~= weaponSlot then
				equipSlot(weaponSlot)
				task.wait(0.4)
			end
		end
		if blocked then
			show(blocked)
		elseif hum and isKnockedDown(hum) then
			-- ใช้สกิลตอนล้มไม่ติด (ทดสอบกับ Zuko: โดนตีล้มเป็นระยะ ป้ายเคยขึ้น "ไม่มีม็อบ" ทั้งที่ยืนห่าง 7 stud)
			show("โดนตีล้ม รอลุกก่อนใช้สกิล · ใช้ไป " .. autoSkill.casts .. " ครั้ง")
		elseif not mob then
			show(string.format("ไม่มีม็อบในระยะ %d stud · ใช้ไป %d ครั้ง", SkillCast.Range, autoSkill.casts))
		else
			local soonest
			for slot, skill in ipairs(SkillsProvider.get_current_keys() or {}) do
				local left = slot > 1 and autoSkill.picked[slot - 1] and cooldownLeft(skill)
				if left and (not soonest or left < soonest.left) then
					soonest = { left = left, key = keyOf(slot) }
				end
			end
			if soonest then
				show(string.format("%s · %s พร้อมใน %d วิ · ใช้ไป %d ครั้ง", lastCast or mob.Name, soonest.key,
					math.ceil(soonest.left), autoSkill.casts))
			end
			local keys = SkillsProvider.get_current_keys() or {}
			for slot = 2, math.min(#keys, #SlotActions) do
				local skill = keys[slot]
				local root = mob:FindFirstChild("HumanoidRootPart")
				local ready = skill.Name ~= "Blocking" and not onCooldown(skill)
					and os.clock() >= (lockedUntil[skill.Name] or 0)
				if autoSkill.on and autoSkill.picked[slot - 1] and ready and root and mob.Parent then
					aim.pos = root.Position
					local ok, started = asGame(SkillController.Attempt_Hold, skill.Name, keyOf(slot))
					if ok and started then
						-- สองค่านี้คือสิ่งที่ปุ่มบน HUD ตั้งหลังกดติด ลูปของเกมใช้ปล่อยท่าเองถ้าค้างเกิน Max_Hold
						SkillController.CurrentMax = skill.Max_Hold
						SkillController.HeldSkill = skill.Name
						task.wait(SkillCast.HoldTime)
						aim.pos = root.Position
						asGame(SkillController.StopHold, skill.Name)
						SkillController.HeldSkill, SkillController.CurrentMax = nil, nil
						autoSkill.casts += 1
						lastCast = string.format("ใช้ %s [%s] ใส่ %s", skill.Name, keyOf(slot), mob.Name)
						show(lastCast .. " · ใช้ไป " .. autoSkill.casts .. " ครั้ง")
						used = true
						task.wait(SkillCast.Gap)
					elseif not onCooldown(skill) then
						lockedUntil[skill.Name] = os.clock() + 5
					end
					aim.pos = nil
				end
			end
		end
		task.wait(used and 0.05 or SkillCast.Idle)
	end
	aim.pos = nil
	show("ปิดอยู่")
end

skillRow = switchRow("Auto Skill", "ปิดอยู่", 7, function(on)
	autoSkill.on = on
	if on then
		skillRow.setDesc("รอม็อบในระยะ " .. SkillCast.Range .. " stud · สกิลที่ยังล็อกจะถูกข้าม")
		task.spawn(skillLoop)
	end
end)

switchRow("สกิลที่ใช้", "ติ๊กปุ่มสกิลที่ให้ Auto Skill กด", 8, function() end, {
	choices = choices,
	multi = true,
	selected = (function()
		local all = {}
		for i = 1, #choices do
			all[i] = i
		end
		return all
	end)(),
	onChoice = function(_, picked)
		autoSkill.picked = picked
	end,
})

-- unload ปิดสวิตช์อื่นผ่าน flag ของมันเอง ตัวนี้อยู่ในฟังก์ชัน เลยผูกหยุดลูปไว้กับ conns แบบเดียวกับ mousepos
track({
	Disconnect = function()
		autoSkill.on = false
	end,
})
end)()

-- Insta Kill: ฆ่าเร็วแบบได้ของ (โหมด 1) หรือฆ่าทันทีแบบไม่ได้ของ (โหมด 2) -------------

-- เซิร์ฟจ่ายของ/เงิน/EXP จากระบบดาเมจของมันเท่านั้น ม็อบเก็บดาเมจของแต่ละคนไว้ใน StringValue "DMG"
-- (ลูก NumberValue ชื่อผู้เล่น) แล้วจ่ายตอนดาเมจของเซิร์ฟทำให้เลือดถึง 0 วัดแล้ว:
--   ตีคอมโบ 1-5 ห่างกัน 0.28 วิ ใส่ Bandit 45 HP   ตายใน 1.2 วิ Wen +17
--   สั่ง Humanoid เป็น Dead จากฝั่งเรา (โหมด 2)   เซิร์ฟลบ Humanoid ทิ้งทันที ไม่ได้อะไร ตีศพต่อก็ไม่ได้
--   ยกม็อบสูง 120 stud แล้วปล่อย                ม็อบไม่มีดาเมจตกที่สูง เลือดเท่าเดิม
--   พาลงน้ำ                                   เกมวาร์ปม็อบกลับจุดเกิด (NpcConfig.Signals.TouchedWater)
-- ทางที่ได้ของจึงมีทางเดียวคือตีให้ถี่ที่สุดที่เซิร์ฟยอมรับ
--
-- เซิร์ฟคุมความถี่หมัดด้วย Combat_presets.Check_can_do_combat_server (โมดูลอยู่ใน ReplicatedStorage อ่านได้)
--   หมัด n ต่อจาก n-1 ต้องห่าง Presets.Combat.default = 0.26 วิ
--   หมัด 1 ต่อจากหมัดปิด 5 ต้องห่าง final = 1.65 วิ   หมัด 1 ต่อจาก 1-4 ต้องห่าง combo_duration = 1.35 วิ
--   เร็วเกินเซิร์ฟรอให้ไม่เกิน 1 วิ แล้วเช็กใหม่ ถ้ายังไม่ถึง 95% ของเวลาที่ต้องรอ หมัดนั้นทิ้ง
--   เลขคอมโบไม่ต่อกัน (เช่นส่ง 1 ซ้ำตอนเพิ่งตี 3) รอ 10000 วิ = ทิ้งทุกครั้ง
-- Kill Aura ยิงทุก 0.2 วิแล้วรีเซ็ตคอมโบเองหลังเว้น 1.2 วิ สั้นกว่า 1.65 ที่เซิร์ฟต้องการ
-- หมัดหลังคอมโบปิดจึงโดนทิ้งเป็นชุด เหลือเข้าจริง ~1.2-2.2 ครั้ง/วิ ลูปนี้ยิงตามตารางด้านบนเป๊ะ
--
-- ห้ามส่งเลขคอมโบนอก 1-5 ที่ตัวเกมส่งเอง: ลองส่ง 6-20 ใส่ Zuko แล้วโดนเตะ "Exploiting (267)"
-- ฟังก์ชันที่เรียกทันทีแยกโควตา register จาก chunk หลัก เหตุผลเดียวกับแท็บ Settings
;(function()
local InstaKill = {
	-- โหมด 1 ตอนไม่ได้เปิด Auto-Attack: วาร์ปไปลอยเหนือม็อบที่ใกล้สุดในระยะนี้ (เท่ากับ Kill Aura ระยะไกล)
	-- เกิน 250 ม็อบหายจากแมพเอง (DespawnDistance) ตอนเปิด Auto-Attack ใช้ระยะหมัด Aura.Range แทน
	Range = 150,
	-- โหมด 2 สแกนทุกเท่านี้ ม็อบในแมพมีหลักสิบตัว วนทั้ง Humanoids ทุก 0.15 วิไม่หนัก
	Tick = 0.15,
	-- เผื่อจากเวลาที่เซิร์ฟต้องการ ส่ง 0.28 (เผื่อ 0.02) เข้าครบ 5/5 หมัด ปิงที่แกว่งทำให้หมัดถึงเซิร์ฟชิดกันได้
	Margin = 0.03,
	FinalCombo = 5,
}
local Presets = require(ReplicatedStorage.CAM.Global.Combat_presets)
-- ส่ง "Combat" เป็นชื่อท่าเหมือน Kill Aura เซิร์ฟเลยคิดเวลาจาก Presets.Combat
local ComboTiming = Presets.Presets.Combat

-- ตัวเลือกเปอร์เซ็นต์เลือดที่เหลือ ปุ่มกว้าง 24px ใส่ได้สองหลัก "–" = ไม่ยุ่งกับบอส
local MobChoices = { "95", "80", "60", "40", "20" }
local BossChoices = { "–", "95", "80", "60", "40", "20" }
-- บอสเริ่มที่ "–": โหมด 1 วาร์ปหาตัวใกล้สุด แถว Windy Peak มี Gyutai/Datai 3000 HP ห่างแค่ ~200 stud
local insta = { on = false, mode = 1, mobPct = 95, bossPct = nil, kills = 0, hits = 0 }

-- Attack Speed Factor ของผู้เล่นหารเวลารอทุกช่วง (Combat_presets.attackSpeedMult) เซิร์ฟใช้สูตรเดียวกัน
local function speedMult()
	local ok, mult = pcall(Presets.attackSpeedMult, LocalPlayer)
	return ok and type(mult) == "number" and mult > 0 and mult or 1
end

-- เลขคอมโบถัดไปกับเวลาที่ต้องรอนับจากหมัดก่อน ตามกติกา Check_can_do_combat_server
local chain = { last = 0, at = 0 }
local function nextCombo()
	local mult = speedMult()
	local since = os.clock() - chain.at
	if chain.last == InstaKill.FinalCombo then
		return 1, ComboTiming.final / mult + InstaKill.Margin
	end
	-- หยุดไปนานพอให้เริ่มคอมโบใหม่ได้แล้ว เริ่มที่ 1 เหมือนตัวเกม ต่อเลขเดิมก็ผ่าน แต่ 1 คือค่าที่เกมส่งจริง
	if chain.last == 0 or since >= Presets.combo_duration / mult + InstaKill.Margin then
		return 1, 0
	end
	local n = chain.last + 1
	local delay = ComboTiming.customDelay and ComboTiming.customDelay[n] or ComboTiming.default
	return n, delay / mult + InstaKill.Margin
end

local function isBoss(hum)
	-- บอส = ทุกตัวที่เลือดเกินเกณฑ์ม็อบธรรมดา (MobTier.Normal) Zuko 300 ก็นับเป็นบอสเควส
	return hum.MaxHealth > MobTier.Normal.max
end

-- ม็อบที่ใกล้สุดในระยะ ข้ามบอสถ้าตั้ง "–" ไว้ เควส Kazu ต้องตีสายลับ *Civilian* ที่ Auto-Quest ล็อกไว้
local function nearestMob(origin, range)
	local folder = workspace:FindFirstChild("Humanoids")
	local best, bestD
	for _, m in ipairs(folder and folder:GetDescendants() or {}) do
		local wanted = m.Name == autoAttack.target
		local hum = m:IsA("Model") and m:GetAttribute("IsMob") and (wanted or not Combat.NeverTarget[m.Name])
			and m:FindFirstChildOfClass("Humanoid")
		local root = hum and m:FindFirstChild("HumanoidRootPart")
		if root and hum.Health > 0 and root.Position.Y > Combat.WorldFloorY
			and (wanted or insta.bossPct or not isBoss(hum)) then
			local d = (root.Position - origin).Magnitude
			if d <= range and (not bestD or d < bestD) then
				best, bestD = m, d
			end
		end
	end
	return best
end

local killRow
local function show(text)
	killRow.setDesc(text)
end

-- โหมด 1 --------------------------------------------------------------------
local function fastLoop()
	killAura.fastKill = true
	chain.last = 0
	while insta.on and insta.mode == 1 do
		local _, hrp, hum = selfParts()
		-- Auto-Attack / Auto-Quest ลอยติดเป้าให้อยู่แล้ว ลูปนี้ยิงอย่างเดียว ห้ามย้ายตัวแย่งกัน
		local positioned = autoAttack.on or Runner.active
		local mob = hrp and hum and hum.Health > 0 and not isKnockedDown(hum) and os.clock() >= autoDodge.holdUntil
			and nearestMob(hrp.Position, positioned and Aura.Range or InstaKill.Range)
		local mobHum = mob and mob:FindFirstChildOfClass("Humanoid")
		local root = mob and mob:FindFirstChild("HumanoidRootPart")
		if not (mobHum and root) then
			show(string.format("รอม็อบในระยะ %d stud · ฆ่าไป %d ตัว",
				positioned and Aura.Range or InstaKill.Range, insta.kills))
			task.wait(0.1)
		elseif not positioned and airborneFor(hum) > Combat.MaxAirTime then
			-- เกมฆ่าตัวละครที่ค้าง Freefall ~9 วิ ลอยต่อหลายตัวติดกันต้องลงแตะพื้นก่อน (แบบเดียวกับ Auto-Attack)
			show("แตะพื้นรีเซ็ตเวลาลอย")
			touchGround(hrp, hum, root.Position)
		else
			Runner.hook("engage", mob)
			if not weaponReady() then
				equipSlot(primarySlot())
			end
			local combo, gap = nextCombo()
			-- รอจนถึงเวลาหมัดถัดไป ระหว่างนั้นลอยเหนือหัวเป้าทุกเฟรม (ม็อบเดิน วาร์ปครั้งเดียวตำแหน่งเพี้ยน)
			local fireAt = chain.at + gap
			-- เพิ่งวาร์ปมาถึง ต้องค้างให้เซิร์ฟเห็นตำแหน่งก่อน ยิงเฟรมเดียวกับที่วาร์ปเข้า 0 หมัด (ดู Aura.BlinkBefore)
			if not positioned and (hrp.Position - root.Position).Magnitude > Aura.Range then
				fireAt = math.max(fireAt, os.clock() + Aura.BlinkBefore)
			end
			repeat
				if not positioned and not pinAbove(hrp, root) then
					break
				end
				if os.clock() < fireAt then
					game:GetService("RunService").Heartbeat:Wait()
				end
			until os.clock() >= fireAt or not insta.on
			if insta.on and mob.Parent and mobHum.Health > 0 then
				if not positioned then
					pinAbove(hrp, root)
				end
				combatSignal:FireServer("Combat_Service", "Combat", combo, false, 0, false, nil)
				chain.last, chain.at = combo, os.clock()
				insta.hits += 1
				show(string.format("ตี %s หมัด %d · HP %d/%d · ฆ่าไป %d ตัว", mob.Name, combo,
					math.max(0, math.floor(mobHum.Health)), math.floor(mobHum.MaxHealth), insta.kills))
				-- นับตัวที่ตายจากดาเมจเซิร์ฟ (เลือดจริงลงถึง 0) ไว้โชว์เท่านั้น เควส/Webhook นับเองจาก HealthChanged
				if not mob:GetAttribute("PathSlayerCounted") then
					mob:SetAttribute("PathSlayerCounted", true)
					mobHum.HealthChanged:Connect(function(hp)
						if hp <= 0 and mob:GetAttribute("PathSlayerCounted") then
							mob:SetAttribute("PathSlayerCounted", nil)
							insta.kills += 1
						end
					end)
				end
			end
		end
	end
	killAura.fastKill = false
end

-- โหมด 2 --------------------------------------------------------------------
-- ตีโดนหนึ่งหมัด เซิร์ฟยกการคุมฟิสิกส์ของม็อบให้เครื่องเราช่วงที่ม็อบโดนสตัน (isnetworkowner เป็น true)
-- เจ้าของฟิสิกส์สั่ง Humanoid เข้าสถานะ Dead ได้ แล้วเซิร์ฟตามด้วย: Zuko ตายตอน 289/300 ไม่เกิดกลับ
-- แต่เซิร์ฟไม่นับว่ามีคนฆ่า ไม่ได้อะไรเลยไม่ว่าเลือดเหลือเท่าไร:
--   Bandit (45)              ฆ่าที่ 77% 22%        EXP +0 Wen +0 ตัวนับเควส Krue ไม่ขยับ (ตีปกติ EXP +22 Wen +5 นับ 1)
--   Hoyuzo Subordinate (190) ฆ่าที่ 58% 26%        EXP +0 ไม่มีของตก (ตีปกติ EXP +145 Wen +30)
--   Zuko (300 บอสเควส)       ฆ่าที่ 96% 78%        ไม่มีหีบ Common Chest ที่ปกติได้
-- ผู้ใช้รู้ผลนี้แล้ว ยังอยากได้ไว้ใช้เอง
local function forceLoop()
	if typeof(isnetworkowner) ~= "function" then
		show("executor นี้ไม่มี isnetworkowner ใช้โหมด 2 ไม่ได้")
		return
	end
	local shown
	while insta.on and insta.mode == 2 do
		local _, hrp = selfParts()
		local folder = workspace:FindFirstChild("Humanoids")
		for _, m in ipairs(hrp and folder and folder:GetDescendants() or {}) do
			local hum = m:IsA("Model") and m:GetAttribute("IsMob") and not Combat.NeverTarget[m.Name]
				and m:FindFirstChildOfClass("Humanoid")
			local root = hum and m:FindFirstChild("HumanoidRootPart")
			if root and hum.Health > 0 and hum.MaxHealth > 0 and (root.Position - hrp.Position).Magnitude <= InstaKill.Range
				and isnetworkowner(root) then
				-- เขียนแบบ a and b or c ไม่ได้: บอสตั้ง "–" (nil) จะหล่นไปใช้เกณฑ์ม็อบธรรมดาแล้วฆ่าบอส
				local pct
				if isBoss(hum) then
					pct = insta.bossPct
				else
					pct = insta.mobPct
				end
				local hpPct = hum.Health / hum.MaxHealth * 100
				if pct and hpPct <= pct then
					-- บอก Webhook ก่อนว่าตัวนี้ไม่นับเป็นการฆ่า ไม่งั้นสรุปขึ้นว่าฆ่าได้ทั้งที่ไม่ได้รางวัล
					Runner.hook("forced", m)
					hum:ChangeState(Enum.HumanoidStateType.Dead)
					hum.Health = 0
					insta.kills += 1
					local text = string.format("ฆ่า %s ตอนเลือด %d%% · รวม %d ตัว (ไม่ได้ EXP/ของ)", m.Name,
						math.floor(hpPct), insta.kills)
					if text ~= shown then
						shown = text
						show(text)
					end
				end
			end
		end
		task.wait(InstaKill.Tick)
	end
end

local function runInsta()
	-- สลับโหมดระหว่างเปิดอยู่: ลูปเก่าเห็น mode เปลี่ยนแล้วจบเอง รอบนี้เริ่มลูปของโหมดใหม่ต่อ
	while insta.on do
		local mode = insta.mode
		if mode == 1 then
			fastLoop()
		else
			forceLoop()
		end
		if insta.mode == mode then
			break
		end
	end
	killAura.fastKill = false
	show("ปิดอยู่")
end

killRow = switchRow("Insta Kill", "ปิดอยู่", 10, function(on)
	if on and not combatSignal then
		show("หา SignalEvent ของเกมไม่เจอ")
		killRow.set(false)
		return
	end
	local wasOn = insta.on
	insta.on = on
	if on and not wasOn then
		show("กำลังหาเป้า…")
		task.spawn(runInsta)
	end
end)

switchRow("โหมด Insta Kill", "1 = ฆ่าเร็ว ได้ของ/เงิน/EXP · 2 = ฆ่าทันที ไม่ได้อะไร", 11, function() end, {
	choices = { "1", "2" },
	selected = 1,
	onChoice = function(i)
		insta.mode = i
	end,
})

switchRow("เลือดม็อบเหลือ ≤ %", "โหมด 2: ม็อบธรรมดาเลือดเหลือเท่านี้แล้วฆ่าทันที", 12, function() end, {
	choices = MobChoices,
	selected = 1,
	onChoice = function(i)
		insta.mobPct = tonumber(MobChoices[i])
	end,
})

switchRow("บอส", "– = ไม่ยุ่งกับบอส (เลือดเกิน 100) · โหมด 2 ฆ่าเมื่อเลือดเหลือ ≤ %", 13, function() end, {
	choices = BossChoices,
	selected = 1,
	onChoice = function(i)
		insta.bossPct = tonumber(BossChoices[i])
	end,
})

track({
	Disconnect = function()
		insta.on = false
		killAura.fastKill = false
	end,
})
end)()

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

chestRow = switchRow("Auto-Chest", "เปิดหีบบอสและเก็บของดรอปของเรา", 9, function(on)
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

-- แท็บ Settings: Webhook Discord ---------------------------------------------

-- ทั้งก้อนอยู่ในฟังก์ชันที่เรียกทันที เพราะไฟล์ชนเพดาน local ระดับบนสุดของ Luau (200 ตัว)
-- do ... end แบบ Auto-Dodge ไม่พอ local ในนั้นยังกิน register ของ chunk หลัก
-- (ลองแล้ว: "Out of local registers when trying to allocate pendingBoss") ฟังก์ชันได้โควตา 200 ของตัวเอง
-- ข้างนอกคุยกับตรงนี้ผ่าน Runner.hook(ชนิด, ค่า) อย่างเดียว:
--   "engage" ม็อบที่ Auto-Attack / Kill Aura เพิ่งล็อกเป้า -> ดูต่อว่าตายไหม
--   "loot"   ชื่อของที่ collectLoot เก็บได้ / "quest" ชื่อเควสที่ Auto-Quest ทำครบทุกขั้น
--   "forced" ม็อบที่ Insta Kill กำลังจะฆ่า (ไม่ได้รางวัล ไม่นับในสรุป)
;(function()
local HttpService = game:GetService("HttpService")

local Hook = {
	SaveFile = "PathSlayer/webhook.json",
	-- ม็อบธรรมดาตายถี่ (Bandit เกิดใหม่ทุก 30 วิ ฆ่าได้หลายตัวต่อนาที) ส่งทีละตัวจะท่วมห้อง
	-- และชนเพดาน Discord 30 ข้อความ/นาที/webhook เลยรวบเป็นสรุปทุก 60 วิ
	SummaryEvery = 60,
	-- หีบบอสโผล่หลังบอสตาย แล้ว collectLoot ต้องวาร์ปไปเปิดกับเก็บทีละชิ้น (~0.8 วิ/ชิ้น)
	-- รอ 20 วิก่อนส่งข้อความบอส ของจากหีบจะได้อยู่ในข้อความเดียวกัน ยังไม่ได้จับเวลาหีบจริง เป็นค่าเผื่อ
	BossLootWindow = 20,
	-- ม็อบที่ล็อกเป้าไว้ แล้วตายภายในเท่านี้ นับว่าเราฆ่า เกมไม่ได้แปะว่าใครฆ่า (ตรวจ attribute ม็อบแล้ว)
	CreditWindow = 30,
	-- Legendary ขึ้นไป (Rarities.Order[5]) แจ้งทันทีไม่รอสรุป
	RareAt = 5,
	-- Discord ห้ามยิงเกิน 5 ครั้งต่อ 2 วิ เว้นไว้ 1 วิต่อข้อความพอ
	SendGap = 1,
}

local cfg = { url = "", on = false, boss = true, quest = true, mobs = true, rare = true }
if typeof(isfile) == "function" and isfile(Hook.SaveFile) then
	local ok, saved = pcall(HttpService.JSONDecode, HttpService, readfile(Hook.SaveFile))
	if ok and type(saved) == "table" then
		for k, v in pairs(saved) do
			cfg[k] = v
		end
	end
end
local function saveCfg()
	if typeof(writefile) == "function" then
		pcall(writefile, Hook.SaveFile, HttpService:JSONEncode(cfg))
	end
end

-- executor แต่ละตัวตั้งชื่อฟังก์ชันยิง HTTP ไม่เหมือนกัน HttpService:PostAsync ใช้ฝั่ง client ไม่ได้
local httpRequest = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

local Rarities = require(ReplicatedStorage.CAM.Global.Rarities)
-- สีตัวอักษรใน code block ```ansi ของ Discord มีแค่ 8 สี จับคู่ใกล้สีเกมที่สุด (Rarities.Colors)
-- Impossible เกมใช้ดำ ในแชตมองไม่เห็น เลยใช้ฟ้าแทน มือถือไม่แสดงสี ANSI เลยเขียนชื่อความหายากกำกับทุกบรรทัด
local AnsiColor = { "30", "32", "34", "35", "33", "31", "36" }

local rarityCache = {}
local function rarityOf(itemName)
	if rarityCache[itemName] == nil then
		rarityCache[itemName] = 1
		for _, m in ipairs(ReplicatedStorage.Items:GetDescendants()) do
			if m.Name == itemName and m:IsA("ModuleScript") then
				local def = require(m)
				rarityCache[itemName] = type(def) == "table" and def.Rarity or 1
				break
			end
		end
	end
	return rarityCache[itemName]
end

local function colorInt(rarity)
	local c = Rarities.Colors[rarity] or Color3.new(1, 1, 1)
	local n = math.floor(c.R * 255) * 65536 + math.floor(c.G * 255) * 256 + math.floor(c.B * 255)
	-- 0 ใน Discord คือ "ไม่มีสี" แถบข้างหายไปเลย
	return n == 0 and 1 or n
end

-- drops = { [ชื่อ] = จำนวน } เรียงหายากก่อน คืนข้อความ code block กับความหายากสูงสุด
local function dropBlock(drops)
	local list = {}
	for name, n in pairs(drops) do
		list[#list + 1] = { name = name, n = n, r = rarityOf(name) }
	end
	if #list == 0 then
		return nil, 0
	end
	table.sort(list, function(a, b)
		if a.r ~= b.r then
			return a.r > b.r
		end
		return a.name < b.name
	end)
	local lines = {}
	for i, e in ipairs(list) do
		-- ช่องใส่ข้อความ embed ยาวได้ 1024 ตัว ของเกิน 15 ชนิดรวบเป็นบรรทัดเดียว
		if i > 15 then
			lines[#lines + 1] = string.format("… อีก %d ชนิด", #list - 15)
			break
		end
		local label = Rarities.Order[e.r] or "?"
		lines[#lines + 1] = string.format("\27[1;%sm%-10s\27[0m %s  x%d", AnsiColor[e.r] or "37", label, e.name, e.n)
	end
	return "```ansi\n" .. table.concat(lines, "\n") .. "\n```", list[1].r
end

-- ค่าตั้งต้นของเลเวล/เงิน นับส่วนต่างจากข้อความก่อนหน้า ผู้อ่านเห็นว่าได้เพิ่มเท่าไรตั้งแต่ข้อความที่แล้ว
local last = { level = Game.level(), wen = Game.wallet().Wen or 0 }

-- หน้าตาตามการ์ดตัวอย่างที่ผู้ใช้ส่งมา: บรรทัด **ชื่อ:** ค่า แบ่งหมวดด้วยบรรทัดว่าง รูปผู้เล่นมุมขวาบน
-- ใส่ทุกอย่างใน description ก้อนเดียว ไม่ใช้ fields: fields แบบ inline บนมือถือเรียงเป็นคอลัมน์เพี้ยน
-- sections = { { "หัวหมวด", { บรรทัด, ... } }, ... } ต่อท้ายหมวดผู้เล่นกับสถานะเสมอ
local function card(title, color, sections)
	local level = Game.level()
	local wallet = Game.wallet()
	local wen = wallet.Wen or 0
	local lv = level and tostring(level) or "อ่านไม่ได้"
	if level and last.level and level > last.level then
		lv = string.format("%d  (อัปจาก %d)", level, last.level)
	end
	local diff = wen - last.wen
	local money = comma(wen)
	if diff ~= 0 then
		money ..= string.format("  (%s%s)", diff > 0 and "+" or "-", comma(math.abs(diff)))
	end
	last.level, last.wen = level or last.level, wen

	local lines = {
		"**ผู้เล่น:** " .. LocalPlayer.Name,
		"**เลเวล:** " .. lv,
		"",
		"**สถานะผู้เล่น**",
		"**Wen:** " .. money,
	}
	-- สกุลเดียวกับหัวแผง Get Weapons ผู้ใช้เห็นตัวเลขชุดเดียวกันทั้งในเกมและในห้อง
	for _, currency in ipairs(Config.WalletShown) do
		if currency ~= "Wen" then
			lines[#lines + 1] = string.format("**%s:** %s", currency, comma(wallet[currency] or 0))
		end
	end
	for _, s in ipairs(sections) do
		lines[#lines + 1] = ""
		lines[#lines + 1] = "**" .. s[1] .. "**"
		for _, line in ipairs(s[2]) do
			lines[#lines + 1] = line
		end
	end
	return {
		title = title,
		color = color,
		description = table.concat(lines, "\n"),
		thumbnail = Hook.avatar and { url = Hook.avatar } or nil,
	}
end

-- รูปผู้เล่นมุมขวาบน: ใช้ลิงก์รูปตรงบน rbxcdn ไม่ใช้ headshot-thumbnail/image แบบเก่า
-- ตัวเก่าเป็น redirect ไม่ใช่ไฟล์รูป Discord ไม่รับประกันว่าจะตามไปดึง
-- (เช็กจากคำตอบ ?wait=true ไม่ได้ Discord ตอบ width 0 ทุกลิงก์ก่อนดึงรูปเสร็จ)
-- ถาม thumbnails API ครั้งเดียวตอนเปิด ได้ไม่ได้ก็ส่งข้อความได้ตามปกติ แค่ไม่มีรูป
task.spawn(function()
	local ok, res = pcall(httpRequest, {
		Url = string.format(
			"https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%d&size=420x420&format=Png&isCircular=false",
			LocalPlayer.UserId
		),
		Method = "GET",
	})
	local okBody, body = pcall(HttpService.JSONDecode, HttpService, ok and res.Body or "")
	local entry = okBody and type(body) == "table" and body.data and body.data[1]
	Hook.avatar = entry and entry.imageUrl or nil
end)

-- ของดรอปหมวดเดียว: code block สีตามความหายาก หรือข้อความว่าง
local function dropsSection(drops, emptyText)
	local block, best = dropBlock(drops)
	return { "ของที่ได้", { block or emptyText } }, best
end

local outbox = {}
local function post(embed)
	embed.footer = { text = "PathSlayer" }
	embed.timestamp = DateTime.now():ToIsoDate()
	return httpRequest({
		Url = cfg.url,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = HttpService:JSONEncode({ username = "PathSlayer", embeds = { embed } }),
	})
end

local function validUrl(url)
	return url:match("^https://[%w%.]*discord[%w]*%.com/api/webhooks/%d+/[%w%-_]+$") ~= nil
end

local function queue(embed)
	if cfg.on and httpRequest and validUrl(cfg.url) then
		outbox[#outbox + 1] = embed
	end
end

-- สถิติตั้งแต่เปิดสคริปต์ ใช้บอก "ฆ่าไปกี่ครั้ง ดรอปรวมกี่ชิ้น" ในข้อความบอส
local bossStats = {}
-- ก้อนสรุปม็อบธรรมดา ล้างทุกครั้งที่ส่ง
local batch = { kills = {}, drops = {}, since = os.clock() }
-- บอสที่เพิ่งตาย รอเก็บของจากหีบก่อนส่ง ของที่เก็บได้ช่วงนี้นับเป็นของบอสตัวนี้
local pendingBoss
local engaged = setmetatable({}, { __mode = "k" })

-- ปิดสวิตช์ฆ่าบอสไว้ ของจากหีบบอสไม่หายไปไหน ย้ายไปอยู่ในสรุปรอบถัดไปแทน
local function sendBoss(b)
	local stats = bossStats[b.name]
	local got = 0
	for name, n in pairs(b.drops) do
		got += n
		if not cfg.boss then
			batch.drops[name] = (batch.drops[name] or 0) + n
		end
	end
	stats.drops += got
	if not cfg.boss then
		return
	end
	local bossLines = {
		"**ชื่อ:** " .. b.name,
		string.format("**ฆ่าไปแล้ว:** %d ครั้ง", stats.kills),
		string.format("**ดรอปรวม:** %d ชิ้น", stats.drops),
	}
	if b.target then
		bossLines[#bossLines + 1] = string.format("**กำลังฟาร์ม:** %s  (%s)", b.target,
			b.drops[b.target] and "ดรอปแล้ว!" or "ยังไม่ดรอป")
	end
	local drops, best = dropsSection(b.drops, Runner.lootOn() and "ไม่มีของตก" or "ไม่ได้เก็บ (Auto-Chest ปิดอยู่)")
	queue(card("ฆ่าบอส " .. b.name, best > 0 and colorInt(best) or 0xE25F5F, { { "บอส", bossLines }, drops }))
end

local function onKill(model, hum)
	local maxHealth = model:GetAttribute("BaseMaxHealth") or hum.MaxHealth
	if tierOf(maxHealth) == "Boss" then
		local stats = bossStats[model.Name] or { kills = 0, drops = 0 }
		stats.kills += 1
		bossStats[model.Name] = stats
		if pendingBoss then
			-- บอสตัวก่อนยังรอหีบอยู่ ส่งไปก่อนเลย ไม่ให้ของสองตัวปนกัน
			sendBoss(pendingBoss)
		end
		local b = { name = model.Name, drops = {}, target = Runner.farmTarget }
		pendingBoss = b
		task.delay(Hook.BossLootWindow, function()
			if pendingBoss == b then
				pendingBoss = nil
				sendBoss(b)
			end
		end)
	else
		batch.kills[model.Name] = (batch.kills[model.Name] or 0) + 1
	end
end

function Runner.hook(kind, value)
	if kind == "engage" then
		local model = value
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not hum then
			return
		end
		-- ลูปสู้ล็อกเป้าเดิมซ้ำทุกรอบ อัปเดตแค่เวลาล่าสุด ต่อ HealthChanged ครั้งเดียวต่อตัว
		local known = engaged[model] ~= nil
		engaged[model] = os.clock()
		if known then
			return
		end
		-- ใช้ HealthChanged ไม่ใช้ Died: Died ของม็อบที่เซิร์ฟเวอร์ถือ บางทีไม่ยิงฝั่ง client
		-- ส่วนเลือดลงถึง 0 replicate มาเสมอ (liveMobCount ก็นับตัวตายจาก Health อย่างเดียว)
		local conn
		conn = track(hum.HealthChanged:Connect(function(hp)
			if hp > 0 then
				return
			end
			conn:Disconnect()
			if os.clock() - (engaged[model] or 0) <= Hook.CreditWindow then
				onKill(model, hum)
			end
		end))
	elseif kind == "forced" then
		-- Insta Kill กำลังจะฆ่าตัวนี้ ตายแบบนี้ไม่ได้รางวัล ลบออกจากรายการล็อกเป้า HealthChanged จะไม่นับ
		engaged[value] = nil
	elseif kind == "loot" then
		local bucket = pendingBoss and pendingBoss.drops or batch.drops
		bucket[value] = (bucket[value] or 0) + 1
		if cfg.rare and rarityOf(value) >= Hook.RareAt then
			local drops, best = dropsSection({ [value] = 1 }, "-")
			local from = pendingBoss and ("หีบบอส " .. pendingBoss.name) or "ม็อบ / หีบ"
			queue(card("ได้ของหายาก!", colorInt(best), { drops, { "ที่มา", { "**จาก:** " .. from } } }))
		end
	elseif kind == "quest" then
		Hook.quests = (Hook.quests or 0) + 1
		if cfg.quest then
			queue(card("ผ่านเควส", 0x7AA2FF, {
				{ "เควส", {
					"**ชื่อ:** " .. value,
					string.format("**ผ่านไปแล้ว:** %d เควส (ตั้งแต่เปิดสคริปต์)", Hook.quests),
				} },
			}))
		end
	end
end

local function sendSummary()
	local kills, total = {}, 0
	for name, n in pairs(batch.kills) do
		kills[#kills + 1] = { name = name, n = n }
		total += n
	end
	local minutes = math.max(1, math.floor((os.clock() - batch.since) / 60 + 0.5))
	local drops, best = dropsSection(batch.drops, "ยังไม่มีของตก")
	local empty = total == 0 and next(batch.drops) == nil
	batch = { kills = {}, drops = {}, since = os.clock() }
	if empty then
		return
	end
	table.sort(kills, function(a, b)
		return a.n > b.n
	end)
	-- เลขนำหน้าแบบ [12] - ชื่อ ตามการ์ดตัวอย่าง ตาไล่แนวตั้งแล้วเห็นตัวที่ฆ่าเยอะสุดก่อน
	local lines = {}
	for _, k in ipairs(kills) do
		lines[#lines + 1] = string.format("[%d] - %s", k.n, k.name)
	end
	queue(card("สรุปการฟาร์ม", best > 0 and colorInt(best) or 0x6EBE82, {
		{ "ม็อบที่ฆ่า", #lines > 0 and lines or { "-" } },
		drops,
		{ "ช่วงเวลา", {
			string.format("**เวลา:** %d นาทีล่าสุด", minutes),
			string.format("**ฆ่ารวม:** %d ตัว", total),
		} },
	}))
end

-- ตัวส่ง: ทีละข้อความ เว้น SendGap โดน 429 ก็รอตามที่ Discord บอกแล้วส่งตัวเดิมซ้ำ
local lastStatus
task.spawn(function()
	local summaryAt = os.clock() + Hook.SummaryEvery
	while screen.Parent do
		if os.clock() >= summaryAt then
			summaryAt = os.clock() + Hook.SummaryEvery
			if cfg.mobs then
				sendSummary()
			else
				batch = { kills = {}, drops = {}, since = os.clock() }
			end
		end
		local embed = outbox[1]
		if embed then
			local ok, res = pcall(post, embed)
			local code = ok and type(res) == "table" and res.StatusCode or 0
			if code == 429 then
				local okBody, body = pcall(HttpService.JSONDecode, HttpService, res.Body)
				task.wait(okBody and tonumber(body.retry_after) or 2)
			else
				table.remove(outbox, 1)
				if lastStatus then
					lastStatus(code >= 200 and code < 300 and ("ส่งล่าสุด: " .. embed.title) or ("ส่งไม่ผ่าน HTTP " .. tostring(code)),
						code >= 200 and code < 300)
				end
			end
		end
		task.wait(Hook.SendGap)
	end
end)

-- หน้า Settings -------------------------------------------------------------

local settingsTab = addTab("Settings")

local page = new("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = Theme.Stroke,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = settingsTab.page,
}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 18),
	BackgroundTransparency = 1,
	Text = "Webhook (Discord)",
	TextColor3 = Theme.Muted,
	TextSize = 11,
	FontFace = font(Enum.FontWeight.Medium),
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 1,
	Parent = page,
})

local urlRow = new("Frame", {
	Size = UDim2.new(1, -6, 0, 30),
	BackgroundTransparency = 1,
	LayoutOrder = 2,
	Parent = page,
})

local urlBox = new("TextBox", {
	Size = UDim2.new(1, -92, 1, 0),
	BackgroundColor3 = Theme.Raised,
	BorderSizePixel = 0,
	Text = cfg.url,
	PlaceholderText = "วางลิงก์ Webhook ของ Discord ตรงนี้",
	PlaceholderColor3 = Theme.Dim,
	TextColor3 = Theme.Text,
	TextSize = 11,
	FontFace = font(Enum.FontWeight.Regular),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ClearTextOnFocus = false,
	Parent = urlRow,
}, { corner(7), new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })

local testLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Text = "ส่งทดสอบ",
	TextColor3 = Theme.Base,
	TextSize = 12,
	FontFace = font(Enum.FontWeight.SemiBold),
})
local testBtn = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0, 84, 1, 0),
	BackgroundColor3 = Theme.Accent,
	AutoButtonColor = false,
	Text = "",
	Parent = urlRow,
}, { corner(7), testLabel })

local statusLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 14),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = Theme.Muted,
	TextSize = 11,
	FontFace = font(Enum.FontWeight.Regular),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	LayoutOrder = 3,
	Parent = page,
})
function lastStatus(text, good)
	statusLabel.Text = text
	statusLabel.TextColor3 = good and Theme.Accent or Theme.Danger
end

if not httpRequest then
	lastStatus("executor นี้ไม่มีฟังก์ชัน request ยิง Webhook ไม่ได้", false)
elseif cfg.url ~= "" and not validUrl(cfg.url) then
	lastStatus("ลิงก์ที่บันทึกไว้ไม่ใช่ Webhook ของ Discord", false)
end

track(urlBox.FocusLost:Connect(function()
	local url = urlBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
	urlBox.Text = url
	cfg.url = url
	saveCfg()
	if url == "" then
		statusLabel.Text = ""
	elseif validUrl(url) then
		lastStatus("บันทึกลิงก์แล้ว", true)
	else
		lastStatus("ลิงก์นี้ไม่ใช่ Webhook ของ Discord (ต้องขึ้นต้น https://discord.com/api/webhooks/)", false)
	end
end))

-- ส่งตรงไม่ผ่านคิว ผู้ใช้กดแล้วอยากเห็นผลทันที และต้องส่งได้แม้ยังไม่เปิดสวิตช์หลัก
track(testBtn.MouseButton1Click:Connect(function()
	if not validUrl(cfg.url) then
		lastStatus("ใส่ลิงก์ Webhook ก่อน", false)
		return
	end
	lastStatus("กำลังส่ง…", true)
	task.spawn(function()
		local sample = {}
		for _, name in ipairs({ "Flame Katana", "Black Kumo Haori", "Metal Scraps" }) do
			sample[name] = 1
		end
		local drops = dropsSection(sample, "-")
		drops[1] = "ตัวอย่างของที่ได้ (สีตามความหายากในเกม)"
		local ok, res = pcall(post, card("เชื่อมต่อสำเร็จ", 0x7AA2FF, { drops }))
		local code = ok and type(res) == "table" and res.StatusCode or 0
		if code >= 200 and code < 300 then
			lastStatus("ส่งทดสอบสำเร็จ ดูในห้อง Discord ได้เลย", true)
		else
			lastStatus("ส่งไม่ผ่าน: " .. (ok and ("HTTP " .. tostring(code)) or tostring(res)), false)
		end
	end)
end))

local function settingSwitch(key, name, desc, order)
	local row = switchRow(name, desc, order, function(on)
		cfg[key] = on
		saveCfg()
	end, { parent = page })
	-- set(true) ยิง onChange ตอนสร้างด้วย เขียนค่าเดิมลงไฟล์ซ้ำ ไม่เสียหาย
	row.set(cfg[key] == true)
	return row
end

settingSwitch("on", "เปิด Webhook", "ปิดไว้ = ไม่ส่งอะไรเลย ปุ่มส่งทดสอบยังใช้ได้", 4)
settingSwitch("boss", "ฆ่าบอส", "ชื่อบอส ครั้งที่ฆ่า ของที่ดรอป และของที่กำลังฟาร์มดรอปหรือยัง", 5)
settingSwitch("quest", "ผ่านเควส", "ชื่อเควสที่ Auto-Quest ทำจบ พร้อมเลเวลและเงิน", 6)
settingSwitch("mobs", "สรุปฆ่าม็อบ", "ทุก " .. Hook.SummaryEvery .. " วิ: ฆ่าอะไรกี่ตัว ได้ของอะไร เงินเพิ่มเท่าไร", 7)
settingSwitch("rare", "ของหายาก", "ได้ของ " .. Rarities.Order[Hook.RareAt] .. " ขึ้นไป แจ้งทันทีไม่รอสรุป", 8)
end)()

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
	table.clear(shopQueue)
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
