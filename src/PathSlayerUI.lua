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

-- สีทั้งชุดดูดมาจาก HUD ของเกมเอง (อ่าน PlayerGui ตอนรัน) ให้เมนูดูเป็นส่วนหนึ่งของเกม
-- ชุดเดิมเป็นเทาอมน้ำเงิน + ฟ้าไล่ม่วง ผู้เล่นทักว่าหน้าตาเหมือน UI ที่ AI ปั๊ม เพราะไม่เกี่ยวกับเกมเลย
-- กรอบของเกมใช้ดำโปร่ง/เทา 26 และ 38 ไม่มีสีอม ตัวหนังสือขาวล้วน ไฮไลต์เป็นแถบขาว
local Theme = {
	Base = Color3.fromRGB(10, 10, 10),
	Panel = Color3.fromRGB(10, 10, 10),
	Raised = Color3.fromRGB(38, 38, 38),
	Row = Color3.fromRGB(24, 24, 24),
	-- เส้นแบ่งทึบ ส่วนขอบปุ่ม/การ์ดใช้ขาวโปร่ง 0.85 แบบเกม (ดู stroke)
	Stroke = Color3.fromRGB(46, 46, 46),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(196, 196, 196),
	-- เดิม 120 บนพื้น 22 ตัวไทยขนาด 11 อ่านแทบไม่ออก
	Dim = Color3.fromRGB(150, 150, 150),
	-- สวิตช์เปิด ปุ่มที่เลือก ช่องติ๊ก: ขาวทึบแบบแถบ Mastery ของเกม ตัวหนังสือบนมันใช้ Base
	On = Color3.fromRGB(255, 255, 255),
	-- ทองของตัวเลข EXP/วงเลเวลมุมซ้ายล่าง ใช้กับข้อความสถานะที่กำลังทำงานและป้าย EXP
	Accent = Color3.fromRGB(255, 196, 84),
	-- ป้ายปราณ แยกจาก EXP ให้เห็นต่างกันในแถวเดียว
	Accent2 = Color3.fromRGB(140, 196, 255),
	-- เขียวของป้าย In safe zone
	Good = Color3.fromRGB(110, 225, 130),
	Warn = Color3.fromRGB(255, 140, 60),
	-- แดงหลอดเลือดของเกม (224,16,16) ยกความสว่างขึ้นให้อ่านเป็นตัวหนังสือบนพื้นดำได้
	Danger = Color3.fromRGB(236, 64, 52),
}

-- สีตาม Rarity (1-7) ชุดเดียวกับ CAM.Global.Rarities.Colors ของเกม ป้ายในแผงจะได้สีตรงกับกระเป๋าในเกม
-- ชุดเดิมตั้งเอง Epic กับ Legendary เพี้ยนจากเกมคนละโทน
-- ปรับสองตัวที่มองไม่เห็นบนพื้นดำ: Mythic เกมใช้แดงเข้ม (161,0,0) ยกความสว่างขึ้นแต่คงโทนแดงเลือดหมู
-- Impossible เกมใช้ดำล้วน (มีภาพพื้นหลังช่วย) ในแผงเราใช้ขาวแทน
local RarityColor = {
	Color3.fromRGB(223, 230, 204),
	Color3.fromRGB(127, 214, 119),
	Color3.fromRGB(79, 185, 255),
	Color3.fromRGB(217, 77, 217),
	Color3.fromRGB(255, 202, 44),
	Color3.fromRGB(230, 52, 52),
	Color3.fromRGB(255, 255, 255),
}

local Config = {
	-- แผงรายการ (ร้าน/เควส) กินพื้นที่ content ทั้งหมด ต่ำกว่า ~500 กว้างแล้วแถวของสวมใส่ล้น
	Width = 760,
	Height = 540,
	SidebarW = 186,
	TitleH = 54,
	-- ปุ่มหมวดสองบรรทัด (ชื่อ + ของในหมวด)
	TabH = 46,
	-- แถบ accent ซ้ายของปุ่มหมวดที่เลือก
	IndicatorX = 12,
	-- แถวในแผงรายการ สูงขึ้นจาก 34 ให้กดโดนง่าย
	RowH = 40,

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

-- Source Sans Pro = ฟอนต์หลักของ HUD เกม (66 จาก 150 ป้ายเป็นตัวหนา) ตัวเล็กกว่า Gotham ราว 2px
-- ที่ขนาดเดียวกัน ขนาดตัวอักษรทั้งไฟล์เลยบวก 2 จากตอนใช้ Gotham
local function font(weight)
	return Font.new("rbxasset://fonts/families/SourceSansPro.json", weight)
end

-- ฟอนต์พู่กันที่เกมใช้กับปุ่มลัดบนแถบสกิล (F Z X C V B) เอามาใช้กับโลโก้ที่เดียว
local MarkerFont = Font.new("rbxasset://fonts/families/PermanentMarker.json")

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

-- ปุ่ม สวิตช์ ป้ายของเกมเป็นทรงแคปซูลทั้งหมด (UICorner 1,0 มี 73 จาก 80 อัน)
local function capsule()
	return new("UICorner", { CornerRadius = UDim.new(1, 0) })
end

-- ไม่ส่งสี = ขอบแบบเกม: ขาวโปร่ง 0.85 หนา 1 ทับพื้นสีไหนก็เป็นขอบสว่างจาง ๆ เท่ากัน
local function stroke(color, thickness)
	return new("UIStroke", {
		Color = color or Color3.new(1, 1, 1),
		Transparency = color and 0 or 0.85,
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
-- identity ของ executor ตอนโหลด ใช้คืนค่าเมื่อ thread งานหล่นเป็น identity เกม (ดู report)
Game.loadIdentity = getthreadidentity and getthreadidentity()

-- จำค่าตามชื่อผู้เล่น: สวิตช์ ปุ่มตัวเลือก และงานที่กำลังทำ (คิว Craft / Get) ย้ายเซิร์ฟหรือเข้าอีกแมพ
-- สคริปต์โหลดตัวเองใหม่ (queue_on_teleport) แล้วเปิดคืน/ทำต่อ ผู้ใช้ไม่ต้องรัน loadstring ซ้ำ
-- บันทึกเฉพาะตอนผู้เล่นกดเอง ฟีเจอร์ที่เปิดสวิตช์อื่นชั่วคราว (Money-Farm เปิด Kill Aura) ไม่นับ
Game.SourceUrl = "https://raw.githubusercontent.com/nawapolmahamahawong-code/PathSlayer/main/src/PathSlayerUI.lua"
Game.persist = { file = "PathSlayer/config_" .. LocalPlayer.Name .. ".json", data = {}, choiceRows = {}, resumers = {} }
do
	local ok, raw = pcall(function()
		return isfile(Game.persist.file) and readfile(Game.persist.file) or nil
	end)
	if ok and raw then
		local ok2, decoded = pcall(function()
			return game:GetService("HttpService"):JSONDecode(raw)
		end)
		if ok2 and type(decoded) == "table" then
			Game.persist.data = decoded
		end
	end
	Game.persist.data.switches = Game.persist.data.switches or {}
	Game.persist.data.choices = Game.persist.data.choices or {}
end
-- เขียนไฟล์รวบตามหลัง 1 วิ กดสวิตช์ติดกันหลายตัวเขียนครั้งเดียว
function Game.save()
	if Game.persist.pending then
		return
	end
	Game.persist.pending = true
	task.delay(1, function()
		Game.persist.pending = false
		pcall(function()
			if not isfolder("PathSlayer") then
				makefolder("PathSlayer")
			end
			writefile(Game.persist.file, game:GetService("HttpService"):JSONEncode(Game.persist.data))
		end)
	end)
end
-- ตามไปทุกเซิร์ฟ/แมพ: ใส่คิวให้ executor โหลดสคริปต์นี้อีกฝั่ง (executor เก็บคิวแค่การย้ายครั้งถัดไป ต้องใส่ทุกครั้งที่โหลด)
-- ไฟล์ใน workspace ก่อน ลิงก์ GitHub ทีหลัง: เดิมลิงก์มาก่อน คนที่รันจากไฟล์ (run.lua) ย้ายเซิร์ฟแล้วได้ตัวเก่า
-- บน GitHub ที่ยังไม่อัปเดตแทน (ผู้ใช้เจอ 24 ก.ย. 2026) คนที่รันจากลิงก์ไม่มีไฟล์นี้ เลยได้ลิงก์เหมือนเดิม
-- Potassium ไม่ได้เก็บแค่คิวล่าสุด มันสะสมทุกครั้งที่รันแล้วรันเรียงกันอีกฝั่ง: ตัวเก่าที่ค้าง (ใน Lobby ค้างที่
-- Skill_Controller) ขวางตัวใหม่ไม่ให้ได้รันเลย ล้างคิวก่อนใส่ ให้เหลือตัวเดียวเสมอ
function Game.followTeleport()
	if typeof(queue_on_teleport) ~= "function" then
		return
	end
	local clear = clear_teleport_queue or clearteleportqueue or clearqueueonteleport
	if typeof(clear) == "function" then
		pcall(clear)
	end
	pcall(queue_on_teleport, string.format([[
repeat task.wait() until game:IsLoaded()
task.wait(3)
local file = "PathSlayer/PathSlayerUI.lua"
local ok = isfile and isfile(file) and pcall(function() loadstring(readfile(file))() end)
if not ok then
	pcall(function() loadstring(game:HttpGet(%q))() end)
end]], Game.SourceUrl))
end

-- งานยาวที่ต้องทำต่อหลังย้ายแมพ: { kind = "craft" | "shop", ... } ล้างเมื่อจบหรือผู้ใช้กด STOP
function Game.setResume(job)
	Game.persist.data.resume = job
	Game.save()
end

-- Lobby (Main Menu 16205713724) --------------------------------------------------
-- ในหน้าเมนูไม่มีตัวละครและไม่มี Ouwland ทั้งไฟล์รันต่อไม่ได้: require Skill_Controller ค้างรอตัวละครตลอดไป
-- (วัดจริง 24 ก.ย. 2026 สคริปต์ค้างที่บรรทัดนั้น หน้าต่างไม่ขึ้นเลย) เลยทำแผงเล็กปุ่มเดียว "กลับเกมหลัก" แล้วจบไฟล์ตรงนี้
if game.PlaceId == 16205713724 or workspace:GetAttribute("IsMenu") == true then
	-- ย้ายกลับแล้วต้องตามไปโหลดตัวเต็มอีกฝั่ง (โค้ดใส่คิวท้ายไฟล์ไปไม่ถึง)
	Game.followTeleport()

	local screen = new("ScreenGui", {
		Name = "PathSlayer_" .. tostring(math.random(1e6, 9e6)),
		ResetOnSpawn = false,
		DisplayOrder = 9999,
		IgnoreGuiInset = true,
		Parent = typeof(gethui) == "function" and gethui() or CoreGui,
	})
	_G.PathSlayerUnload = function()
		_G.PathSlayerUnload = nil
		screen:Destroy()
	end
	local box = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(360, 132),
		BackgroundColor3 = Theme.Base,
		BorderSizePixel = 0,
		Parent = screen,
	}, {
		corner(14),
		stroke(),
		new("UIPadding", {
			PaddingTop = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
		}),
	})
	new("TextLabel", {
		Size = UDim2.new(1, -40, 0, 22),
		BackgroundTransparency = 1,
		Text = "XIIIN",
		TextColor3 = Theme.Text,
		TextSize = 22,
		FontFace = Font.new("rbxasset://fonts/families/PermanentMarker.json"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = box,
	})
	local close = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, -2),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Theme.Raised,
		AutoButtonColor = false,
		Text = "X",
		TextColor3 = Theme.Muted,
		TextSize = 14,
		FontFace = font(Enum.FontWeight.Bold),
		Parent = box,
	}, { capsule(), stroke() })
	close.MouseButton1Click:Connect(_G.PathSlayerUnload)

	local origin = Game.persist.data.origin
	local info = new("TextLabel", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Text = origin and origin.jobId and "อยู่ Lobby · กดเพื่อกลับเซิร์ฟที่เล่นอยู่ก่อนหน้า"
			or "อยู่ Lobby · ไม่มีบันทึกเซิร์ฟเดิม กดแล้วเข้าเซิร์ฟใหม่ของ Ouwland",
		TextColor3 = Theme.Muted,
		TextSize = 14,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = box,
	})
	local go = new("TextButton", {
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.On,
		AutoButtonColor = false,
		Text = "กลับเกมหลัก  ›",
		TextColor3 = Theme.Base,
		TextSize = 15,
		FontFace = font(Enum.FontWeight.SemiBold),
		Parent = box,
	}, { capsule() })

	-- ทางเดียวกับปุ่มในเกม: Teleporter.Request ให้เซิร์ฟย้ายเอง (jobId เดิมก่อน ไม่ได้ค่อยเซิร์ฟใหม่)
	local function request(settings)
		local ok, Teleporter = pcall(require, ReplicatedStorage.CAM.Client.Modules.Teleporter)
		if setthreadidentity and Game.loadIdentity then
			setthreadidentity(Game.loadIdentity)
		end
		if not ok then
			return false, "ไม่เจอตัวย้ายเซิร์ฟของเกม"
		end
		local sent, res, why = pcall(Teleporter.Request, settings)
		if setthreadidentity and Game.loadIdentity then
			setthreadidentity(Game.loadIdentity)
		end
		return sent and res == true, sent and why or res
	end
	local busy = false
	go.MouseButton1Click:Connect(function()
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local o = Game.persist.data.origin
			local ok, why = false, nil
			if o and o.jobId and o.placeId == 136406881576517 then
				info.Text = "กำลังกลับเซิร์ฟเดิม …"
				-- ถ้าเซิร์ฟส่งไปห้องอื่น พอโหลดอีกฝั่งส่วน returning ของ Auto-Dungeon ย้ายเข้าห้องเดิมให้อีกรอบ
				-- เขียนไฟล์ตรง ๆ ไม่รอ Game.save (หน่วง 1 วิ) เพราะย้ายเซิร์ฟอาจตัดก่อนเขียนทัน
				Game.persist.data.returning = true
				Game.persist.data.returningAt = os.time()
				pcall(function()
					writefile(Game.persist.file, game:GetService("HttpService"):JSONEncode(Game.persist.data))
				end)
				ok, why = request({ placeId = o.placeId, jobId = o.jobId, allowFallback = false })
				if not ok and (o.ownerId or 0) > 0 then
					ok, why = request({ placeId = o.placeId, privateOwner = o.ownerId })
				end
			end
			if not ok then
				info.Text = "เซิร์ฟเดิมเข้าไม่ได้ · เข้าเซิร์ฟใหม่ของ Ouwland …"
				ok, why = request({ placeId = 136406881576517 })
			end
			info.Text = ok and "เซิร์ฟรับคำขอแล้ว กำลังย้าย …" or ("ย้ายไม่สำเร็จ: " .. tostring(why or "เซิร์ฟไม่ตอบ"))
			info.TextColor3 = ok and Theme.Good or Theme.Danger
			busy = false
		end)
	end)
	return
end

-- หมวดในแผง = ชื่อโฟลเดอร์ใน ReplicatedStorage.Items
-- ของสวมใส่คือโฟลเดอร์ที่ทุกโมดูลมี EquipType 3-5 (ตรวจครบทั้ง 256 ตัว ไม่มีปนหมวดอื่น)
-- Quest Items / Materials / Potions ไม่ใส่ ใส่ไม่ได้และส่วนใหญ่ได้จากเควส
Game.WeaponGroups = { "Katana", "Weapons" }
Game.WearGroups = { "Head", "Face", "Ear", "Neck", "Back", "Waist", "Haori", "Outfits" }
-- แผง Get Materials: ทุกโฟลเดอร์ที่ไม่ใช่ของสวมใส่ (104 ชิ้น) ไม่ใช่แค่ของที่อยู่ในสูตร
-- ผู้ใช้ขอ "ครบทุกอย่าง" รวมยา ออร์บ ของตกปลา ของเควส ที่ไม่ได้ใช้ตีอะไรเลยด้วย
-- ไม่เอา Mounts / Misc / Style (Horse, Clan Skills, Combat) มันคือระบบของเกม ไม่ใช่ของในกระเป๋า
Game.MaterialGroups = { "Materials", "Potions", "Schematics", "Gourds", "Evil Art Orbs", "Fishing", "Quest Items" }

-- ไอคอนของเกมสำหรับชื่อของ/สกุลเงิน: Wen / RunPoints ไม่ใช่ไอเทม ไอคอนอยู่ใน BunchaIcons
-- (ตัวเดียวกับที่ป้ายราคาหน้าช่างใช้) ที่เหลืออ่าน Icon จากโมดูลไอเทม
Game.iconCache = {}
function Game.iconOf(name)
	if Game.iconCache[name] == nil then
		local icon = false
		local okB, Buncha = pcall(require, ReplicatedStorage.CAM.Global.BunchaIcons)
		if okB and type(Buncha) == "table" then
			icon = (name == "RunPoints" and Buncha.OuwigaharaPoints) or (type(Buncha[name]) == "string" and Buncha[name]) or false
		end
		if not icon then
			local okI, defs = pcall(require, ReplicatedStorage.CAM.Global.Collectibles.Items)
			local def = okI and defs[name]
			icon = def and def.Icon or false
		end
		Game.iconCache[name] = icon
		-- require โมดูลเกมบางตัวทำ identity ของ thread หล่นเป็น 2 (เจอตอนโหลดแผง: สร้างป้ายต่อจากนี้พัง
		-- "lacking capability Plugin") คืนค่าตอนโหลดไฟล์ก่อนกลับไปสร้าง GUI ต่อ
		if setthreadidentity and Game.loadIdentity then
			setthreadidentity(Game.loadIdentity)
		end
	end
	return Game.iconCache[name] or nil
end

-- แบบพิมพ์เซ็ต Nightfall: แหล่งได้ไม่มีในตารางดรอป/ร้านของเกมเลย (ItemSources ว่าง) ทุกชิ้นเป็นปริศนาในแมพ
-- ข้อมูลจากสคริปต์เกม (WorldEvents.*, Dialogues ของ Tobei / Hatsu / Togane) แล้วลองเก็บจริงทุกทาง 24 ก.ย. 2026
-- how: study = กดค้าง Study ที่ของตั้งโชว์ (StudyProp) · sickles = ดึงคันโยก 10 อันก่อนแล้ว Study
-- serpent = ไล่ลองกุญแจงูกับกล่อง · gauntlet = ตีรูปปั้น 3 ตัว · trade = แลกของกับ NPC · capstone = Togane วาดให้
Game.SetSchematics = {
	["Nightfall Katana Schematic"] = { set = "Nightfall", how = "study", item = "Nightfall Katana",
		at = Vector3.new(-570, 815, 112), short = "Study ที่ดาบตั้งโชว์" },
	["Nightfall Mask Schematic"] = { set = "Nightfall", how = "study", item = "Nightfall Mask",
		at = Vector3.new(-1629, 1229, 1143), short = "Study ที่หน้ากากตั้งโชว์" },
	["Nightfall Axe and Mace Schematic"] = { set = "Nightfall", how = "study", item = "Nightfall Axe and Mace",
		at = Vector3.new(1083, 1584, -811), short = "Study ที่ขวาน-กระบองตั้งโชว์" },
	["Nightfall Scythe Schematic"] = { set = "Nightfall", how = "study", item = "Nightfall Scythe",
		at = Vector3.new(-1205, 969, -3187), short = "Study ที่เคียวใน Iceveil" },
	["Nightfall Claws Schematic"] = { set = "Nightfall", how = "study", item = "Nightfall Claws",
		at = Vector3.new(-1816, -44, 438), short = "Study ที่กรงเล็บในถ้ำใต้ดิน" },
	["Nightfall Sickles Schematic"] = { set = "Nightfall", how = "sickles", item = "Nightfall Sickles",
		at = Vector3.new(-1025, 812, 631), short = "ดึงคันโยก 10 อัน แล้ว Study ในท่อ" },
	["Nightfall Serpent Katana Schematic"] = { set = "Nightfall", how = "serpent",
		short = "ไล่ลองกุญแจงูกับกล่องจนเจอดอกจริง" },
	["Nightfall Gauntlet Schematic"] = { set = "Nightfall", how = "gauntlet",
		short = "ตีรูปปั้น 3 ตัว (ดาบ / สกิล / มือเปล่า)" },
	["Nightfall Cape Schematic"] = { set = "Nightfall", how = "trade", give = "Lost Cape", npc = "Weaver Hatsu",
		key = "Cape", short = "เอา Lost Cape ให้ Weaver Hatsu" },
	["Nightfall Top Schematic"] = { set = "Nightfall", how = "capstone", short = "Togane วาดให้เมื่อครบ 9 แบบ" },
	["Nightfall Bottom Schematic"] = { set = "Nightfall", how = "capstone", short = "Togane วาดให้เมื่อครบ 9 แบบ" },
}

-- คำอธิบายเต็มในกล่องข้อมูลของแต่ละวิธี
Game.SchematicSteps = {
	study = "วาร์ปไปที่ของตั้งโชว์ แล้วกดค้าง Study 3 วิ ได้แบบพิมพ์ทันที",
	sickles = "ดึงคันโยก Sickles Levers ครบ 10 อันทั่วแมพ (กดค้าง 3 วิ) ฝาท่อระบายน้ำที่ (-1025, 834, 582) เปิด"
		.. " แล้วลงไป Study เคียวในท่อ",
	serpent = "กุญแจงูวางริมน้ำ 23 ดอก มีดอกจริงดอกเดียว เก็บทีละดอกไปไขกล่องที่ (899, 879, 739)"
		.. " ผิดดอกขึ้น \"The key snaps in the lock\" กุญแจหาย ไล่ลองจนเจอ",
	gauntlet = "คุยกับ Stonemason Tobei (Hidden Mist) ให้รูปปั้นตื่น แล้วตีรูปปั้นสามตัวจนตาสว่างเต็ม:"
		.. " Weapon = ตีด้วยดาบ · Power = ใช้สกิลปราณ · Fighting = ต่อยด้วย Combat (มือเปล่า) แล้วกลับไปรับแบบจาก Tobei",
	trade = "เอาของเก่าไปให้ NPC วาดแบบให้ Lost Cape ได้จากตกปลาด้วย Legendary Fishing Rod หรือหีบ Lost Chest 0.9%",
	capstone = "Blacksmith Togane (Hidden Mist) วาดแบบ Top กับ Bottom ให้พร้อมกัน เมื่อมีแบบ Nightfall ครบ 9 ชิ้น",
}

-- โมดูลไอเทมรวมกว่า 300 ตัว require ครั้งเดียวแล้วแคช ไม่งั้นทุกครั้งที่รีเฟรชร้านจะ require ซ้ำ
-- mode = "gear" (อาวุธ + ของสวมใส่) หรือ "material" แคชแยกกัน
local itemCache
local function allWeaponItems(mode)
	mode = mode or "gear"
	itemCache = itemCache or {}
	if itemCache[mode] then
		return itemCache[mode]
	end
	local list = {}
	local items = ReplicatedStorage:FindFirstChild("Items")
	local sets = mode == "material" and { Game.MaterialGroups }
		or mode == "nightfall" and { { "Schematics" } }
		or { Game.WeaponGroups, Game.WearGroups }
	for _, groups in ipairs(sets) do
		for _, folderName in ipairs(groups) do
			local folder = items and items:FindFirstChild(folderName)
			for _, m in ipairs(folder and folder:GetChildren() or {}) do
				local guide = Game.SetSchematics[m.Name]
				if m:IsA("ModuleScript") and (mode ~= "nightfall" or (guide and guide.set == "Nightfall")) then
					list[#list + 1] = {
						name = m.Name,
						group = folderName,
						wear = groups == Game.WearGroups,
						def = require(m),
					}
				end
			end
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = a.def.Rarity or 0, b.def.Rarity or 0
		if ra ~= rb then
			return ra < rb
		end
		return a.name < b.name
	end)
	itemCache[mode] = list
	return list
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

	-- ออร์บทุกลูกขายที่ร้าน Spins (54 Spins) ต้องรู้ยอดถึงจะบอกได้ว่าซื้อได้ไหม หรือต้องไปเปิดหีบแทน
	local spins = slot:FindFirstChild("Spinning")
	spins = spins and spins:FindFirstChild("Spins")
	w["Spins"] = spins and spins.Value or 0

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
Game.Currencies = { Wen = true, RunPoints = true, Spins = true }

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

-- ของชิ้นนี้ในหีบนี้: คืน โอกาส, จำนวนต่อหีบ (ตัวเลข หรือ { ต่ำสุด, สูงสุด })
-- หีบมีสองส่วน: guaranteed = ได้ทุกครั้ง (Refinement Ore 4-7 ชิ้นจาก World Events Chest)
-- กับ loot = สุ่มตาม chance เดิมอ่านแค่ loot เลยขึ้น "20%" ทั้งที่ของนั้นได้แน่ทุกหีบ
-- ดัชนี ItemSources ของเกมก็ไม่ใส่ Chance ให้แถว guaranteed เพราะเหตุผลเดียวกัน
function Game.chestChance(chestId, itemName)
	local chest = lootTables().chests[chestId]
	if type(chest) ~= "table" then
		return nil
	end
	for _, g in ipairs(chest.guaranteed or {}) do
		if g.itemId == itemName then
			return 1, g.bulk
		end
	end
	for _, e in ipairs(chest.loot or {}) do
		if e.itemId == itemName then
			return e.chance, e.bulk
		end
	end
	return nil
end

function Game.bulkText(bulk)
	if type(bulk) == "table" then
		return string.format("%d-%d ชิ้น", bulk[1], bulk[2])
	elseif type(bulk) == "number" and bulk > 1 then
		return bulk .. " ชิ้น"
	end
	return nil
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
	-- ม็อบที่มีจุดเกิดประจำ (ActiveNpcs) มาก่อนเสมอ ม็อบอีเวนต์ (Lost, Yeti, Cache ...) ไม่รู้จะโผล่ที่ไหนเมื่อไร
	-- เคยได้ทาง "Lost Chest จาก Lost" ให้ Refinement Ore ทั้งที่ Lost ไม่มีจุดเกิดในแมพนี้ ฟาร์มรอไม่มีวันจบ
	local fixed = {}
	for _, m in ipairs(Game.mobs()) do
		if m.code and m.center then
			fixed[m.code] = true
		end
	end
	local function better(a, b)
		if not b then
			return true
		end
		if a.fixed ~= b.fixed then
			return a.fixed
		end
		if a.chance ~= b.chance then
			return a.chance > b.chance
		end
		-- World Events Chest มีบอส 18 ตัวดรอปเท่ากันหมด (3000 HP) เดิมเลือกได้ Sumari ที่ออกแต่กลางคืน
		if a.night ~= b.night then
			return not a.night
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
				fixed = fixed[code] == true,
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

	for chestId in pairs(t.chests) do
		local chance, bulk = Game.chestChance(chestId, itemName)
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
						fixed = fixed[code] == true,
						npc = npc.Name or code,
						chance = chance,
						bulk = bulk,
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
	if route.chance >= 1 then
		pct = "ได้แน่" .. (Game.bulkText(route.bulk) and (" " .. Game.bulkText(route.bulk)) or "")
	end
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
	-- ดัชนีของเกมว่างจริง (Health Potion, Legendary Fishing Rod, แบบพิมพ์ส่วนใหญ่) ไม่ใช่เราหาไม่เจอ
	local none = "เกมไม่มีแหล่งให้ (ไม่มีร้าน ดรอป หีบ สูตร หรือเควส)"
	return own and none or (itemName .. ": " .. none)
end

-- ร้านทุกเจ้าในเกม อ่านจาก ReplicatedStorage.Regions (ตัวเดียวกับที่ดัชนี "ได้จากไหน" ของเกมใช้)
-- ชื่อ NPC -> โซน ร้านหมุนเวียนไหม (สุ่มกี่ชิ้นจากกี่ชิ้น) เฉพาะกลางคืนไหม ต้องจบเควสอะไรก่อน
function Game.sellers()
	if Game.sellerCache then
		return Game.sellerCache
	end
	local sellerCache = {}
	Game.sellerCache = sellerCache
	local ok, Regions = pcall(require, ReplicatedStorage.Regions)
	for regionName, region in pairs(ok and Regions.Regions or {}) do
		for _, npc in ipairs(region.Npcs or {}) do
			if type(npc.Name) == "string" and (npc.Shop or npc.RotatingShop or npc.TimedVendor) then
				local rs, tv = npc.RotatingShop, npc.TimedVendor
				-- ราคาในร้านหมุนเวียน/ตลาดมืด: Price ใน Pool ก่อน ไม่มีค่อยใช้ Price ของโมดูลไอเทม
				-- (RotatingShop.RegisterStock -> Shop.RegisterItem) ร้านประจำใช้ราคาใน Shop.itemsforsale
				local prices = {}
				for _, list in ipairs({ rs and rs.Pool, tv and tv.Stock, tv and tv.Always }) do
					for _, e in ipairs(list or {}) do
						if type(e) == "table" and e.Name and e.Price then
							prices[e.Name] = e.Price
						end
					end
				end
				sellerCache[npc.Name] = {
					prices = prices,
					region = regionName,
					night = npc.NightOnly == true,
					quest = npc.RequiresQuestDone or (rs and rs.RequiresQuestDone),
					rotating = rs and { pool = #(rs.Pool or {}), slots = rs.SlotCount } or nil,
					-- Black Marketer: โผล่ในเมืองครั้งละ ActiveFor วิ ของสุ่มจาก Stock ตามความหายาก
					timed = tv and { minutes = math.floor((tv.ActiveFor or 0) / 60) } or nil,
				}
			end
		end
	end
	return sellerCache
end

-- โซนของม็อบ/บอส (ตามโฟลเดอร์ ActiveNpcs ที่มันเกิด) ค้นจากรหัส NpcCode หรือชื่อ
function Game.mobRegion(codeOrName)
	for _, m in ipairs(Game.mobs()) do
		if m.code == codeOrName or m.name == codeOrName or m.key == codeOrName then
			return m.region
		end
	end
	return nil
end

-- ม็อบที่ดรอปหีบแบบนี้ (NpcDataTable.Chest / ExtraChests) เรียงเลือดน้อยก่อน = ฟาร์มง่ายก่อน
function Game.chestDroppers(chestId)
	local list = {}
	for code, npc in pairs(lootTables().npc) do
		if type(npc) == "table" then
			local drops = npc.Chest == chestId
			for _, extra in ipairs(npc.ExtraChests or {}) do
				drops = drops or extra == chestId
			end
			if drops then
				list[#list + 1] = {
					name = npc.Name or code,
					code = code,
					hp = npc.Stats and npc.Stats.MaxHealth,
					night = npc.OnlyAtNight == true,
				}
			end
		end
	end
	table.sort(list, function(a, b)
		return (a.hp or math.huge) < (b.hp or math.huge)
	end)
	return list
end

-- แหล่งได้ทุกทางของไอเทมชิ้นนี้ จากดัชนีของเกมเอง (CAM.Client.Modules.ItemSources)
-- คืน { { kind = "shop"|"drop"|"chest"|"craft"|"quest"|"fish", where, chance }, ... }
-- ดัชนีว่าง = ในเกมไม่มีทางได้เลยตอนนี้ (Paper Bag, Ninja Scroll ฯลฯ ไม่มีร้าน ดรอป หรือสูตร)
function Game.itemSources(itemName)
	local ok, ItemSources = pcall(require, ReplicatedStorage.CAM.Client.Modules.ItemSources)
	local out = {}
	for _, e in ipairs(ok and ItemSources.Get(itemName) or {}) do
		local where = e.Where
		local kind, name
		if where:match("^Sold by ") then
			kind, name = "shop", where:match("^Sold by (.+)")
		elseif where:match("^Quest: ") then
			kind, name = "quest", where:match("^Quest: (.+)")
		elseif where:match("^Crafted at ") then
			kind, name = "craft", where:match("^Crafted at (.+)")
		elseif where == "Fished up" then
			kind, name = "fish", where
		elseif lootTables().chests[where] then
			kind, name = "chest", where
		else
			kind, name = "drop", where
		end
		out[#out + 1] = { kind = kind, where = name, chance = e.Chance }
	end
	return out
end

-- หีบอีเวนต์ที่เกิดเองในแมพ (Sealed Cache T1-T3) นิยามอยู่ในโมดูล NPC ที่มี WorldEvent
-- (Ouwland.Content.Misc.Npcs["Sealed Chest T2"]: ChestId, Guards, Spawns 12 จุด, ActiveCount 5, RespawnTime 1500)
-- หีบโผล่ใน workspace.Chests สถานะ ChestState = Locked และ prompt ปิดไว้จนกว่ายามจะตาย
-- คืน { [ChestId] = { guards = { ชื่อโมเดลยาม }, spawns = { Vector3 } } }
function Game.chestEvents()
	if Game.chestEventCache then
		return Game.chestEventCache
	end
	local events = {}
	for _, region in ipairs(ReplicatedStorage.Ouwland.Content:GetChildren()) do
		local npcs = region:FindFirstChild("Npcs")
		for _, m in ipairs(npcs and npcs:GetChildren() or {}) do
			local ok, def = false, nil
			if m:IsA("ModuleScript") then
				ok, def = pcall(require, m)
			end
			local ev = ok and type(def) == "table" and def.WorldEvent
			if ev and ev.ChestId then
				local e = { guards = {}, spawns = {} }
				for _, g in ipairs(ev.Guards or {}) do
					e.guards[#e.guards + 1] = g.Config
				end
				for _, cf in ipairs(def.Spawns or {}) do
					e.spawns[#e.spawns + 1] = typeof(cf) == "CFrame" and cf.Position or cf
				end
				events[ev.ChestId] = e
			end
		end
	end
	Game.chestEventCache = events
	return events
end

-- ทางที่ไม่ใช่ร้าน/ดรอป/ตี ลองเป็นทางสุดท้ายเมื่อทางหลักตันหมด:
--   sealed = เปิดหีบอีเวนต์ (Tanto, Scythe มีแค่ใน Sealed Cache)
--   fish   = ตกปลาจนได้ (Lost Shotgun) เกมไม่บอกโอกาส ItemSources ฝังรายชื่อของตกปลาไว้เฉย ๆ
--   vendor = ร้านหมุนเวียน / Black Marketer ที่รอบนี้ไม่มีของ รอจนมีแล้วซื้อ
function Game.altRoute(itemName)
	local sources = Game.itemSources(itemName)
	local events = Game.chestEvents()
	local sealed
	for _, s in ipairs(sources) do
		if s.kind == "chest" and events[s.where] then
			-- โอกาสอ่านจากตารางหีบตรง ดัชนี ItemSources ไม่ใส่ Chance ให้ของ guaranteed (Coin ใน T1) เคยขึ้น "0%"
			local chance, bulk = Game.chestChance(s.where, itemName)
			sealed = sealed or { kind = "sealed", chests = {}, best = s.where }
			sealed.chests[s.where] = chance or 0
			-- ได้แน่ทั้งคู่ให้ดูจำนวนสูงสุดต่อหีบ Coin Stack: T3 ได้ 4-7 ดีกว่า T2 ได้ 4-6
			local most = type(bulk) == "table" and bulk[2] or bulk or 1
			local bestMost = type(sealed.bulk) == "table" and sealed.bulk[2] or sealed.bulk or 1
			local sameChance = sealed.chance and (chance or 0) == sealed.chance
			if not sealed.chance or (chance or 0) > sealed.chance or (sameChance and most > bestMost) then
				sealed.best, sealed.chance, sealed.bulk = s.where, chance, bulk
			end
		end
	end
	if sealed then
		return sealed
	end
	for _, s in ipairs(sources) do
		if s.kind == "fish" then
			return { kind = "fish" }
		end
	end
	for _, s in ipairs(sources) do
		local info = s.kind == "shop" and Game.sellers()[s.where]
		if info and (info.rotating or info.timed) then
			return { kind = "vendor", seller = s.where, info = info }
		end
	end
	return nil
end

function Game.altText(alt)
	if alt.kind == "sealed" then
		local pct = alt.chance and string.format(" %g%%", math.floor(alt.chance * 1000 + 0.5) / 10) or ""
		if alt.chance and alt.chance >= 1 then
			pct = " ได้แน่" .. (Game.bulkText(alt.bulk) and (" " .. Game.bulkText(alt.bulk)) or "")
		end
		return string.format("เปิดหีบ %s%s (ฆ่ายามก่อน)", alt.best, pct)
	elseif alt.kind == "fish" then
		return "ตกปลาจนได้ (เกมไม่บอกโอกาส)"
	end
	local when = alt.info.timed and string.format("โผล่ครั้งละ %d นาที", alt.info.timed.minutes)
		or "สุ่มของทุกรอบ"
	return string.format("รอ %s มาขาย (%s)", alt.seller, when)
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
	-- ลองทางไหนก็ลองบนสำเนากระเป๋า/แผน ผ่านค่อยรวมเข้าของจริง ติดก็ไปทางถัดไป
	local function commit(tw, to)
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
	end

	-- ร้านจ่ายไม่ไหวไม่ได้แปลว่าหาไม่ได้: ออร์บขายที่ร้าน Spins แต่ก็อยู่ในหีบบอสด้วย
	-- เดิมเจอร้านแล้วคืนเหตุผลทันที ("ขาด 54 Spins") ไม่เคยไปดูทางอื่นเลย
	if listing then
		local tw, to = table.clone(w), Game.newPlan()
		local err
		for _, p in ipairs(priceParts(listing.Price)) do
			err = Game.plan(p.currency, p.amount * short, tw, to, depth + 1)
			if err then
				break
			end
		end
		if not err then
			commit(tw, to)
			out.how[name] = { kind = "shop", listing = listing }
			out.buy[name] = (out.buy[name] or 0) + short
			return nil
		end
		shopWhy = err
	end

	-- ม็อบอีเวนต์ไม่มีจุดเกิด ถ้ามีหีบอีเวนต์ในแมพให้ของชิ้นเดียวกัน ไปทางหีบที่หาเจอแน่กว่า
	local route = Game.dropRoute(name)
	local alt = route and not route.fixed and Game.altRoute(name)
	if route and not alt then
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
				commit(tw, to)
				out.how[name] = { kind = "craft", id = c.id, recipe = c.recipe }
				out.craft[#out.craft + 1] = { item = name, station = station, times = times }
				return nil
			end
			why = why or err
		end
	end

	alt = alt or Game.altRoute(name)
	if alt then
		out.how[name] = alt
		out.farm[#out.farm + 1] = { item = name, amount = short, route = alt }
		return nil
	end
	-- เหลือแต่ม็อบอีเวนต์ ยังดีกว่าบอกว่าหาไม่ได้ ฟาร์มจะรอให้มันโผล่เอง
	if route then
		out.how[name] = { kind = "farm", route = route }
		out.farm[#out.farm + 1] = { item = name, amount = short, route = route }
		return nil
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

-- แถวแบบพิมพ์เซ็ต: ไม่มีร้าน/ดรอป ใช้ข้อมูล Game.SetSchematics แทน ของที่ตีได้จากแบบนี้โชว์ในกล่องข้อมูล
function Game.schematicRow(row, guide, wallet)
	row.source = "schematic"
	row.guide = guide
	row.result = row.name:gsub(" Schematic$", "")
	if row.have > 0 then
		row.locked, row.owned, row.reason = true, true, "มีแล้ว ✓"
		return
	end
	-- ยังขาดของก่อนหน้าก็ยังติ๊กได้ ผู้ใช้กดแถวแล้วกลายเป็นเปิดข้อมูลแทน (แถวล็อก) คิดว่าติ๊กพัง
	-- ตัวรันบอกเองตอนถึงคิวว่าติดอะไร / capstone รอแบบอื่นในคิวเสร็จก่อน
	row.farmable = true
	row.reason = guide.short
	if guide.how == "trade" and (wallet[guide.give] or 0) == 0 then
		row.reason = "ต้องมี " .. guide.give .. " ก่อน (ตกด้วย Legendary Fishing Rod)"
	elseif guide.how == "capstone" then
		local Series = require(ReplicatedStorage.CAM.Global.Series)
		local missing = 0
		for _, name in ipairs(Series.CapstoneGate(guide.set)) do
			if (wallet[name] or 0) == 0 then
				missing += 1
			end
		end
		if missing > 0 then
			row.reason = string.format("ครบ 9 แบบแล้ว Togane วาดให้ (ขาดอีก %d)", missing)
		end
	end
end

function Game.listings(mode)
	local wallet = Game.wallet()
	local level = Game.level()
	local race = Game.race()
	local forSale = Shop and Shop.itemsforsale or {}

	local out = {}
	for _, item in ipairs(allWeaponItems(mode)) do
		local def = item.def
		local row = {
			name = item.name,
			group = item.group,
			rarity = def.Rarity or 1,
			icon = def.Icon,
			-- นิยามดิบ ใช้โชว์สเตตัส คำอธิบาย ราคาหน้าร้านหมุนเวียน ในกล่องข้อมูล
			def = def,
			mastery = def.Mastery,
			cost = {},
			locked = false,
			reason = nil,
			source = nil,
			buyable = false,
		}

		local listing = forSale[item.name]
		local recipes = Game.recipesFor(item.name)
		-- ขายเป็น Robux หรือ Spins (ได้จากหมุนกาชา ส่วนใหญ่ต้องเติมเงิน) แต่ดรอป ตี หรืออยู่ในหีบด้วย
		-- ไปทางที่ไม่ต้องจ่ายเงินจริง ออร์บทั้ง 9 ลูกเป็นแบบนี้: 54 Spins หรือหีบบอส 1-2%
		local special = listing and listing.Price and (listing.Price.Product
			or (listing.Price.Spins and (wallet.Spins or 0) < listing.Price.Spins))
		if special and (Game.dropRoute(item.name) or #recipes > 0 or Game.altRoute(item.name)) then
			listing = nil
		end
		local route = not listing and Game.dropRoute(item.name) or nil
		-- ลำดับเดียวกับ Game.plan: ม็อบอีเวนต์ไม่มีจุดเกิด ถ้ามีหีบอีเวนต์ให้ของเดียวกันไปทางหีบ
		local eventAlt = route and not route.fixed and Game.altRoute(item.name)
		if eventAlt then
			route = nil
		end
		row.have = wallet[item.name] or 0
		row.wear = item.wear

		local guide = mode == "nightfall" and Game.SetSchematics[item.name]
		if guide then
			Game.schematicRow(row, guide, wallet)
			out[#out + 1] = row
			continue
		end

		if route then
			-- ฟาร์มม็อบ/บอสจนดรอป ไม่ต้องใช้เงิน เลยข้ามการเช็กราคาข้างล่าง (cost ว่าง)
			row.source = route.kind
			row.route = route
			row.farmable = true
			row.reason = Game.routeText(route) .. (route.fixed and "" or " · ม็อบอีเวนต์ รอให้โผล่")
		elseif eventAlt then
			row.source = eventAlt.kind
			row.farmable = true
			row.reason = Game.altText(eventAlt)
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
				-- บอกค่า RunPoints ด้วย (Ouwigahara ทุกสูตร 90,000) เงินนี้ได้จากเล่นรอบในแมพนั้นเท่านั้น
				-- ไปถึงโรงตีได้ก็ยังตีไม่ได้ถ้าไม่มี ผู้ใช้ควรรู้ว่าติดที่ตรงไหนจริง
				local runPoints = recipes[1].recipe.price and recipes[1].recipe.price.RunPoints
				row.locked = true
				row.reason = "ตีที่ " .. tostring(row.station) .. " (อีกแมพ ยังไม่รองรับ)"
					.. (runPoints and (" · ใช้ " .. comma(runPoints) .. " RunPoints") or "")
			elseif err then
				row.locked = true
				row.reason = "ตีที่ " .. tostring(row.station) .. " · " .. err
			else
				row.station = o.how[item.name].recipe.station
				row.farmable = true
				row.reason = Game.planText(row.station, o)
			end
		else
			local alt = Game.altRoute(item.name)
			if alt then
				row.source = alt.kind
				row.farmable = true
				row.reason = Game.altText(alt)
			else
				row.locked = true
				row.reason = Game.noSourceText(item.name, true)
			end
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
					-- ราคาที่เป็นของ (Rare Fishing Rod = 10,000 Wen + Golden Fish 5) ให้ Runner.obtain ไปหาของก่อนแล้วซื้อ
					-- เดิมล็อกแถวทิ้ง "ขาด 5 Golden Fish" ทั้งที่ Golden Fish ตกได้ เงินจริง (Game.Currencies) ยังล็อกเหมือนเดิม
					if not Game.Currencies[p.currency] then
						row.farmable = true
						row.reason = string.format("หา %s %s ก่อนแล้วซื้อ", comma(p.amount - have), p.currency)
					else
						row.locked = true
						row.reason = string.format("ขาด %s %s", comma(p.amount - have), p.currency)
						break
					end
				end
			end
		end

		-- เผ่าเป็นเงื่อนไขสวมใส่ ไม่ใช่เงื่อนไขได้ของ เดิมล็อกแถวทิ้ง อาวุธ 17 ชิ้น (Sickles, Claws, War Fans ...)
		-- เลยขึ้น "เผ่าไม่ตรง" หาไม่ได้เลยทั้งที่ฟาร์มได้ ผู้ใช้อยากได้ไว้เก็บ/เปลี่ยนเผ่าทีหลัง บอกเป็นหมายเหตุพอ
		local raceReq = def.EquipRequirements and def.EquipRequirements.Race
		if raceReq and race then
			local allowed, ok = {}, false
			for _, r in pairs(raceReq) do
				allowed[#allowed + 1] = tostring(r)
				ok = ok or r == race
			end
			if not ok then
				row.note = "ใส่ได้เฉพาะ " .. table.concat(allowed, "/")
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
			-- Black Marketer ไม่มีโมดูลร้านใน Npcs โผล่เป็นตัว NPC ในเมืองรอบละ 30 นาที หาตัวจริงแล้วยืนคุยแทน
			-- ยังไม่ได้ลองซื้อจริง ตอนเขียนเขาไม่อยู่ในเซิร์ฟ
			for _, s in ipairs(Game.itemSources(row.name)) do
				for _, d in ipairs(s.kind == "shop" and workspace:GetDescendants() or {}) do
					if d:IsA("Model") and d.Name == s.where and d:FindFirstChildOfClass("Humanoid") then
						spot, shopName, talk = d:GetPivot().Position, s.where, true
						break
					end
				end
				if spot then
					break
				end
			end
		end
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
}, { corner(14), stroke() })

local titleBar = new("Frame", {
	Name = "TitleBar",
	Size = UDim2.new(1, 0, 0, Config.TitleH),
	BackgroundTransparency = 1,
	Parent = root,
}, {
	-- โลโก้เป็นตัวหนังสือพู่กันเฉย ๆ เดิมเป็นกล่องไล่สีฟ้า-ม่วงกับตัว X ซึ่งเป็นจุดแรกที่ทำให้ดูเหมือน AI ทำ
	new("TextLabel", {
		Position = UDim2.fromOffset(18, 4),
		Size = UDim2.fromOffset(200, 30),
		BackgroundTransparency = 1,
		Text = "XIIIN",
		TextColor3 = Theme.Text,
		TextSize = 28,
		FontFace = MarkerFont,
		TextXAlignment = Enum.TextXAlignment.Left,
	}),
	new("TextLabel", {
		Position = UDim2.fromOffset(18, 32),
		Size = UDim2.fromOffset(200, 13),
		BackgroundTransparency = 1,
		Text = "v0.3 · RightShift ซ่อน/แสดง",
		TextColor3 = Theme.Dim,
		TextSize = 12,
		FontFace = font(Enum.FontWeight.Regular),
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

-- glyph = nil วาดขีดย่อหน้าต่างเป็นแท่งแทนตัวอักษร: "-" ใน Source Sans ขนาด 16 ยาวแค่ ~5px
-- ผู้ใช้บอกเล็กไปจนแทบไม่เห็น แท่ง 12x2 คมเท่ากันทุกขนาดจอ
local function iconButton(glyph, xOffset, hoverColor)
	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, xOffset, 0, Config.TitleH / 2),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Theme.Raised,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = glyph or "",
		TextColor3 = Theme.Muted,
		TextSize = 17,
		FontFace = font(Enum.FontWeight.Bold),
		Parent = titleBar,
	}, { capsule(), stroke() })

	if not glyph then
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(12, 2),
			BackgroundColor3 = Theme.Muted,
			BorderSizePixel = 0,
			Parent = btn,
		}, { capsule() })
	end

	-- ไล่ทุกแท่งในปุ่ม เพราะตอนย่อหน้าต่างปุ่มนี้ได้แท่งตั้งเพิ่มเป็นเครื่องหมาย +
	local function paintBars(color)
		for _, bar in ipairs(btn:GetChildren()) do
			if bar:IsA("Frame") then
				tween(bar, { BackgroundColor3 = color }, FAST)
			end
		end
	end
	track(btn.MouseEnter:Connect(function()
		tween(btn, { BackgroundTransparency = 0, TextColor3 = hoverColor }, FAST)
		paintBars(hoverColor)
	end))
	track(btn.MouseLeave:Connect(function()
		tween(btn, { BackgroundTransparency = 1, TextColor3 = Theme.Muted }, FAST)
		paintBars(Theme.Muted)
	end))
	return btn
end

local closeBtn = iconButton("X", -12, Theme.Danger)
local minBtn = iconButton(nil, -48, Theme.Text)

-- ป้ายบอกว่ามีอะไรทำงานอยู่ (ต่อสายไว้ท้ายไฟล์ หลังทุกสวิตช์ถูกสร้าง)
-- เดิมต้องไล่เปิดทีละแท็บเพื่อดูว่าเปิดอะไรค้างไว้ สวิตช์อยู่คนละหน้าแล้วลืมปิด
-- เคยมีปุ่มแดง "หยุดทั้งหมด" ต่อท้าย ผู้ใช้สั่งเอาออก (รกหัวหน้าต่าง) ปิดทีละสวิตช์ในหน้าของมันแทน
local Chip = {}
Chip.frame = new("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -90, 0, Config.TitleH / 2),
	Size = UDim2.fromOffset(0, 28),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = Theme.Raised,
	BorderSizePixel = 0,
	Parent = titleBar,
}, {
	capsule(),
	stroke(),
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14) }),
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
Chip.dot = new("Frame", {
	Size = UDim2.fromOffset(8, 8),
	BackgroundColor3 = Theme.Dim,
	BorderSizePixel = 0,
	LayoutOrder = 1,
	Parent = Chip.frame,
}, { capsule() })
Chip.label = new("TextLabel", {
	Size = UDim2.fromOffset(0, 28),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Text = "ไม่มีอะไรทำงาน",
	TextColor3 = Theme.Muted,
	TextSize = 13,
	FontFace = font(Enum.FontWeight.Medium),
	LayoutOrder = 2,
	Parent = Chip.frame,
})

local sidebar = new("Frame", {
	Name = "Sidebar",
	Position = UDim2.fromOffset(0, Config.TitleH),
	Size = UDim2.new(0, Config.SidebarW, 1, -Config.TitleH),
	BackgroundColor3 = Theme.Panel,
	BorderSizePixel = 0,
	Parent = root,
}, {
	new("UIPadding", {
		PaddingTop = UDim.new(0, 14),
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

-- ปุ่มลัดอยู่ท้ายแถบซ้ายตลอด คนเพิ่งใช้ครั้งแรกไม่รู้ว่าปิดหน้าต่างแล้วเรียกกลับยังไง
local keysHint = new("TextLabel", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 20, 1, -12),
	Size = UDim2.new(0, Config.SidebarW - 30, 0, 28),
	BackgroundTransparency = 1,
	Text = "RightShift  ซ่อน/แสดง\nDelete  ปิดสคริปต์",
	TextColor3 = Theme.Dim,
	TextSize = 12,
	FontFace = font(Enum.FontWeight.Regular),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Bottom,
	Parent = root,
})

-- แถบ accent อยู่นอก sidebar เพราะ UIListLayout จะจัดตำแหน่งให้ถ้าอยู่ข้างใน
local indicator = new("Frame", {
	Name = "Indicator",
	Position = UDim2.fromOffset(Config.IndicatorX, Config.TitleH + 14),
	Size = UDim2.fromOffset(3, Config.TabH - 20),
	BackgroundColor3 = Theme.On,
	BorderSizePixel = 0,
	BackgroundTransparency = 1,
	Parent = root,
}, { capsule() })

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

-- ประกาศไว้ก่อนเพราะ selectTab ต้องปิดแผงตอนสลับแท็บ แต่แผงถูกสร้างทีหลัง
local closeShopPanel

local function selectTab(tab)
	if activeTab == tab then
		-- กดแท็บเดิมตอนแผงรายการเปิดทับอยู่ = กลับหน้าหมวด
		if closeShopPanel then
			closeShopPanel()
		end
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
		Position = UDim2.fromOffset(Config.IndicatorX, tab.button.AbsolutePosition.Y - root.AbsolutePosition.Y + 10),
	})

	tab.page.Position = UDim2.fromOffset(16, 0)
	tab.page.GroupTransparency = 1
	tab.page.Visible = true
	tween(tab.page, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })

	-- แผงรายการ (Get Weapons / Auto-Quest ฯลฯ) วางทับทั้ง content สลับหมวดแล้วต้องปิด ไม่งั้นบังหน้าใหม่
	if closeShopPanel then
		closeShopPanel()
	end
end

local function addTab(name, sub)
	local label = new("TextLabel", {
		Position = UDim2.fromOffset(16, 7),
		Size = UDim2.new(1, -24, 0, 16),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = Theme.Muted,
		TextSize = 16,
		FontFace = font(Enum.FontWeight.SemiBold),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local subLabel = new("TextLabel", {
		Position = UDim2.fromOffset(16, 24),
		Size = UDim2.new(1, -24, 0, 13),
		BackgroundTransparency = 1,
		Text = sub or "",
		TextColor3 = Theme.Dim,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local button = new("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, Config.TabH),
		BackgroundColor3 = Theme.Raised,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = #tabs + 1,
		Parent = sidebar,
	}, { corner(9), label, subLabel })

	local page = new("CanvasGroup", {
		Name = name .. "Page",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Parent = content,
	}, {
		new("UIPadding", {
			PaddingTop = UDim.new(0, 18),
			PaddingLeft = UDim.new(0, 20),
			PaddingRight = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 12),
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

-- หมวด / หัวข้อ / การ์ด ---------------------------------------------------------

-- เดิมมีแท็บ Visuals ที่รวมสวิตช์ต่อสู้ 14 แถวเรียงกันยาว ตัวเลือกย่อย (โหมด Insta Kill, ปุ่มสกิล)
-- ปนกับสวิตช์หลักจนไม่รู้ว่าแถวไหนเป็นของอะไร และตัวเปิดแผงเลือกม็อบอยู่คนละแท็บกับสวิตช์ของมัน
-- ตอนนี้: หมวด (แถบซ้าย) > หัวข้อ > การ์ดต่อหนึ่งฟีเจอร์ ตัวเลือกย่อยอยู่ในการ์ดของมันเอง
local Pages = {}
do
	local function makePage(key, name, sub)
		local tab = addTab(name, sub)
		local scroll = new("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme.Stroke,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = tab.page,
		}, {
			new("UIListLayout", { Padding = UDim.new(0, 20), SortOrder = Enum.SortOrder.LayoutOrder }),
			-- เว้นบน 4px: สระบนของไทย (ติ ที่) ล้นกล่องข้อความ หัวข้อแรกโดนขอบ ScrollingFrame ตัด
			new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8) }),
		})
		Pages[key] = { tab = tab, scroll = scroll, sections = {}, cards = {} }
		return Pages[key]
	end

	makePage("combat", "ต่อสู้", "โจมตี · สกิล · หลบ")
	makePage("quest", "เควส", "เควส · ฝึกปราณ")
	makePage("items", "ไอเทม", "อาวุธ · หีบ · ของดรอป")
	makePage("warp", "จุดวาร์ป", "Lobby · NPC · สถานที่")
	makePage("settings", "ตั้งค่า", "Discord · ปุ่มลัด")

	-- ลำดับหัวข้อในแต่ละหมวดตามลำดับในตารางนี้ ไม่ใช่ตามลำดับที่โค้ดฟีเจอร์สร้างแถว
	local Sections = {
		{ page = "combat", key = "attack", title = "โจมตี",
			hint = "Auto-Attack พาตัวไปหาม็อบ · Kill Aura หรือ Insta Kill เป็นตัวตี เปิดคู่กันได้" },
		{ page = "combat", key = "gear", title = "อาวุธและสกิล" },
		{ page = "combat", key = "defense", title = "ป้องกันตัว" },
		{ page = "quest", key = "quest", title = "ทำเควสอัตโนมัติ",
			hint = "กด เปิด เพื่อเลือกเควสหรือปราณ แล้วกดเริ่มในหน้านั้น" },
		{ page = "items", key = "gear", title = "อาวุธและของสวมใส่" },
		{ page = "items", key = "upgrade", title = "อัปเกรดอุปกรณ์ (Refine)",
			hint = "ตีเสริมอาวุธ / ของสวมใส่ / เบ็ดในกระเป๋า เลือกระดับเป้าหมาย สคริปต์ตีวนให้จนถึง" },
		{ page = "items", key = "material", title = "วัตถุดิบและของใช้" },
		{ page = "items", key = "set", title = "เซ็ตท็อปเกม" },
		{ page = "items", key = "loot", title = "เก็บของ" },
		{ page = "warp", key = "server", title = "ย้ายเซิร์ฟ",
			hint = "กลับหน้าเมนูของเกม หรือกลับเซิร์ฟที่เล่นอยู่ก่อนเข้าดันเจี้ยน / Lobby" },
		{ page = "warp", key = "find", title = "วาร์ปไปหา NPC",
			hint = "กด วาร์ป แล้วไปยืนหน้า NPC ทันที · ป้ายบอกโซน เลเวลขั้นต่ำ เผ่า และช่วงเวลาที่อยู่" },
		{ page = "warp", key = "forge", title = "ช่างตีและอัปเกรดอาวุธ" },
		{ page = "warp", key = "shop", title = "ร้านค้าและรับซื้อของ" },
		{ page = "warp", key = "trainer", title = "ครูฝึกปราณและสไตล์" },
		{ page = "warp", key = "fish", title = "ตกปลา" },
		{ page = "warp", key = "schem", title = "แบบพิมพ์เซ็ตและภารกิจพิเศษ" },
		{ page = "warp", key = "quest", title = "ให้เควส" },
		{ page = "warp", key = "place", title = "สถานที่สำคัญ" },
		{ page = "settings", key = "webhook", title = "แจ้งเตือน Discord",
			hint = "ส่งสรุปการฆ่า ของหายาก และเควสที่จบเข้าห้อง Discord" },
		{ page = "settings", key = "afk", title = "กันหลุด (Anti-AFK)" },
		{ page = "settings", key = "keys", title = "ปุ่มลัด" },
	}

	for i, s in ipairs(Sections) do
		local pg = Pages[s.page]
		local box = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = i,
			Parent = pg.scroll,
		}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
		-- หัวข้อหนาและใหญ่กว่าชื่อฟีเจอร์ชัด ๆ แบบป้าย Flame Mastery ของเกม เดิม 15 SemiBold เล็กกว่าชื่อการ์ดจนกลืน
		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			Text = s.title,
			TextColor3 = Theme.Text,
			TextSize = 21,
			FontFace = font(Enum.FontWeight.Bold),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = -2,
			Parent = box,
		})
		if s.hint then
			new("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = s.hint,
				TextColor3 = Theme.Dim,
				TextSize = 14,
				FontFace = font(Enum.FontWeight.Regular),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				LayoutOrder = -1,
				Parent = box,
			})
		end
		pg.sections[s.key] = box
	end
end

-- ที่อยู่ของทุกแถว ค้นจากชื่อที่โค้ดฟีเจอร์ส่งมา ย้ายหมวด เปลี่ยนชื่อที่โชว์ หรือคำอธิบาย แก้ที่นี่ที่เดียว
-- card = ชื่อกลุ่ม (แถวที่ child = nil คือหัวการ์ด) · child = ลำดับในกล่องตัวเลือกย่อย
-- help = คำอธิบายตอนปิดอยู่ ตอนเปิดแถวนั้นโชว์สถานะสดที่ฟีเจอร์ส่งมาแทน
local Layout = {
	switch = {
		-- ผู้ใช้สั่งเอาออก: ตีทุกตัวทั้งแมพไม่มีใครใช้ Auto-Quest ก็พาตัวไปตีเองอยู่แล้ว
		-- สวิตช์ยังต้องมีอยู่ (ลูป attackLoop กับ Runner.farm สั่ง attackRow.set) แค่ไม่โชว์
		["Auto-Attack"] = { page = "combat", section = "attack", card = "attack", hidden = true },
		["Auto-Attack-Mob"] = { page = "combat", section = "attack", card = "attackMob", order = 1,
			title = "Auto-Attack", help = "บินไปลอยเหนือม็อบที่เลือกไว้แล้วตี (Auto-Quest ตีให้เองอยู่แล้ว)" },
		["Auto-Money-Farm"] = { page = "quest", section = "quest", card = "money", order = 4,
			help = "วนฆ่าบอสที่ทิ้งหีบ Coin Pouch (คุ้มสุดต่อ HP) นอนใต้ดินตี แล้วเอาเหรียญไปขาย Ginzo เอง" },
		["Auto-Dungeon"] = { page = "quest", section = "quest", card = "dungeon", order = 5,
			help = "เข้าดันเจี้ยนเอง ไต่ชั้นด้วย Insta Kill เลือกการ์ดแต้มสูงสุด ยอมแพ้ตามชั้นที่ตั้ง แลกแต้มเป็นของ แล้วกลับ" },
		["ดันเจี้ยน"] = { page = "quest", section = "quest", card = "dungeon", child = 1, title = "ดันเจี้ยน" },
		["ยอมแพ้ที่ชั้น"] = { page = "quest", section = "quest", card = "dungeon", child = 2, title = "ยอมแพ้ที่ชั้น" },
		["Auto-Skip"] = { page = "quest", section = "quest", card = "dungeon", child = 4, title = "Auto-Skip",
			help = "ข้ามช่วงพัก 10 วิระหว่างชั้นทันที ไต่เร็วขึ้น" },
		["เปิด Ouwigahara Chest"] = { page = "quest", section = "quest", card = "dungeon", child = 5,
			title = "เปิด Ouwigahara Chest (30,000 แต้ม)",
			help = "กล่องโซนร้านหลังจบรอบที่ใช้แต้มเปิด · ปิดไว้ = ไม่กด เก็บแต้มไว้แลกของ" },
		["แลกแต้มเป็น"] = { page = "quest", section = "quest", card = "dungeon", child = 3,
			title = "แลกแต้มเป็น (ติ๊กหลายอย่าง = แบ่งเท่ากัน)" },
		["Auto-Final-Selection"] = { page = "quest", section = "quest", card = "finalsel", order = 3,
			help = "ไปรอหน้าประตูสอบ (Sisters, Final Selection Plains) ก่อนเปิดทุก 2 ชม. ต้อง Lv 45 + Human" },
		["ตีจากใต้ดิน"] = { page = "combat", section = "attack", card = "under", order = 2,
			help = "นอนหงายใต้พื้นใต้ม็อบ หมัดแรกทุกคอมโบยกม็อบลอย ม็อบสวนไม่ได้ (ใช้กับ Auto-Attack / Auto-Quest)" },
		["ความลึกใต้ดิน"] = { page = "combat", section = "attack", card = "under", child = 1,
			title = "ความลึก (stud)" },
		["Kill Aura"] = { page = "combat", section = "attack", card = "aura", order = 3,
			help = "ตามม็อบในระยะ 80 stud ไปยืนข้าง หันเข้าหา แล้วตีต่อเนื่องเอง" },
		["Kill Aura ระยะไกล"] = { page = "combat", section = "attack", card = "aura", child = 1,
			title = "ระยะไกล" },
		["Parry อัตโนมัติ"] = { page = "combat", section = "attack", card = "aura", child = 2,
			title = "Parry อัตโนมัติ", help = "ม็อบในระยะ 12 stud เริ่มท่าตี กดบล็อกให้ตรงจังหวะ ตีต่อได้ไม่ขาด" },
		["Insta Kill"] = { page = "combat", section = "attack", card = "insta", order = 4,
			help = "ตีเร็วที่สุดที่เซิร์ฟยอมรับ ได้ของ เงิน และ EXP ครบ" },
		["โหมด Insta Kill"] = { page = "combat", section = "attack", card = "insta", child = 1,
			title = "โหมด" },
		["บอส"] = { page = "combat", section = "attack", card = "insta", child = 2, title = "บอส" },
		["เลือดม็อบเหลือ ≤ %"] = { page = "combat", section = "attack", card = "insta", child = 3,
			title = "ฆ่าเมื่อเลือดม็อบเหลือ ≤ %" },
		["เลือดบอสเหลือ ≤ %"] = { page = "combat", section = "attack", card = "insta", child = 4,
			title = "ฆ่าเมื่อเลือดบอสเหลือ ≤ %" },
		["Auto-Equip-Weapon"] = { page = "combat", section = "gear", card = "weapon", order = 1,
			title = "ช่องอาวุธที่ใช้ตี" },
		["Auto Skill"] = { page = "combat", section = "gear", card = "skill", order = 2,
			help = "กดสกิลของอาวุธที่ถือใส่ม็อบใกล้ตัวทันทีที่คูลดาวน์หมด" },
		["สกิลที่ใช้"] = { page = "combat", section = "gear", card = "skill", child = 1,
			title = "ปุ่มสกิลที่ให้กด" },
		["Auto-Potion"] = { page = "combat", section = "defense", card = "potion", order = 2,
			help = "เลือดต่ำกว่าที่ตั้ง กินยาเอง (Elixir → Potion → Regen) ใส่ยาขึ้น toolbar ให้ กินเสร็จถือดาบคืน" },
		["กินยาเมื่อเลือดต่ำกว่า"] = { page = "combat", section = "defense", card = "potion", child = 1,
			title = "กินเมื่อเลือดต่ำกว่า" },
		["Auto-Dodge"] = { page = "combat", section = "defense", card = "dodge", order = 1,
			help = "วาร์ปหลบตอนม็อบเริ่มท่าตี จำท่าที่เคยโดนไว้ในไฟล์" },
		["Auto-Chest"] = { page = "items", section = "loot", card = "chest", order = 1,
			help = "เปิดหีบบอสและเก็บของดรอปของเราให้เอง" },
	},
	feature = {
		["Auto-Attack-Mob"] = { page = "combat", section = "attack", card = "attackMob", child = 1,
			title = "เลือกม็อบ", help = "ติ๊กชื่อม็อบที่จะให้ตี" },
		["Auto-Quest"] = { page = "quest", section = "quest", card = "quest", order = 1,
			help = "แท็บ แนะนำ / ทำซ้ำได้ / ครั้งเดียว / บอส / ปราณ · ติ๊กได้หลายเควส บอกรางวัลทุกอัน" },
		["Get Materials"] = { page = "items", section = "material", card = "material", order = 1,
			help = "แร่ เศษเหล็ก ด้าย ยา แบบพิมพ์ ออร์บ ของตกปลา ของเควส 104 ชิ้น · ใส่จำนวนได้" },
		["Get Nightfall Craft"] = { page = "items", section = "set", card = "nfcraft", order = 2,
			help = "ตีชิ้นเซ็ต Nightfall แบบโต๊ะช่าง · ขาดแบบ วัสดุ หรือเงิน หาให้เองจนตีได้ · ติ๊กหลายชิ้นได้" },
		["Get Nightfall Schematic"] = { page = "items", section = "set", card = "nightfall", order = 1,
			help = "แบบพิมพ์เซ็ต Nightfall 11 ชิ้น · Study / คันโยก / กุญแจงู / รูปปั้น / แลก · ติ๊กหลายชิ้นได้" },
		["Upgrade อุปกรณ์"] = { page = "items", section = "upgrade", card = "refine", order = 1,
			help = "เลือกของ (แยกที่ใส่อยู่ / ในกระเป๋า) ตั้งระดับ +1 ถึง +10 ดูโอกาส ค่าใช้จ่าย ของที่ขาด แล้วกดอัป" },
		["Log ดันเจี้ยน"] = { page = "quest", section = "quest", card = "dungeonlog", order = 6,
			help = "ทุกรอบที่จบ: ถึงชั้นไหน แต้มเท่าไร ได้อะไรจากหีบ แลกอะไรไป ได้กลับมาทั้งหมดเท่าไร" },
		["Get Weapons"] = { page = "items", section = "gear", card = "shop", order = 1,
			help = "อาวุธและของสวมใส่ทุกชิ้น · ร้าน / ดรอป / หีบ / คราฟต์ พร้อมแหล่งได้ทุกทาง" },
		["Auto-Breathing"] = { page = "quest", section = "quest", card = "breath", order = 2,
			help = "เลือกปราณ ดูของที่ขาดและวิธีหา แล้วสคริปต์ทำเควสฝึกให้จนได้" },
	},
}

local placeRow
do
	-- การ์ดหนึ่งใบ = หนึ่งฟีเจอร์ แถวหลักอยู่บนสุด ตัวเลือกย่อยอยู่ในกล่องเข้มด้านล่าง
	-- สร้างตอนแถวแรกของกลุ่มมาถึง แถวไหนมาก่อนก็ได้ (ตัวเปิดแผงเลือกม็อบถูกสร้างก่อนสวิตช์ของมัน)
	local function cardFor(where)
		local pg = Pages[where.page]
		local key = where.section .. "/" .. where.card
		local c = pg.cards[key]
		if c then
			return c
		end
		local frame = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Row,
			BorderSizePixel = 0,
			LayoutOrder = where.order or 99,
			Parent = pg.sections[where.section],
		}, {
			corner(10),
			stroke(),
			new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		c = { frame = frame }
		pg.cards[key] = c
		return c
	end

	local function subBoxOf(c)
		if c.sub then
			return c.sub
		end
		-- ตัวเลือกย่อยห้อยใต้หัวการ์ดด้วยเส้นตั้งซ้าย เดิมเป็นกล่องดำซ้อนในการ์ด (การ์ดในการ์ด)
		-- ทั้งหน้าเลยเห็นแต่กรอบซ้อนกันสามชั้น แยกไม่ออกว่าอะไรเป็นฟีเจอร์หลัก
		local holder = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 10,
			Parent = c.frame,
		}, {
			new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingBottom = UDim.new(0, 8) }),
			new("Frame", {
				Size = UDim2.new(0, 2, 1, 0),
				BackgroundColor3 = Theme.Raised,
				BorderSizePixel = 0,
			}, { capsule() }),
		})
		c.sub = new("Frame", {
			Position = UDim2.fromOffset(4, 0),
			Size = UDim2.new(1, -4, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = holder,
		}, { new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
		return c.sub
	end

	-- แถวในการ์ด: หัวการ์ดสูงกว่าและตัวหนังสือใหญ่กว่า แถวย่อยเตี้ยและเยื้องเข้าใน
	-- standalone = แถวที่ผู้เรียกระบุ parent เอง (หน้า ตั้งค่า) ได้กรอบการ์ดของตัวเอง
	local function rowShell(kind, name, where, parent, order)
		local sizes = { head = 60, child = 44, standalone = 56 }
		local frame = new("Frame", {
			Size = UDim2.new(1, 0, 0, sizes[kind]),
			BackgroundColor3 = Theme.Row,
			BackgroundTransparency = kind == "standalone" and 0 or 1,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = parent,
		})
		if kind == "standalone" then
			corner(10).Parent = frame
			stroke().Parent = frame
		end
		local indent = kind == "child" and 14 or 16
		local title = new("TextLabel", {
			Position = UDim2.fromOffset(indent, kind == "child" and 8 or 11),
			Size = UDim2.new(1, -indent, 0, 18),
			BackgroundTransparency = 1,
			Text = where and where.title or name,
			TextColor3 = kind == "child" and Theme.Muted or Theme.Text,
			TextSize = kind == "child" and 15 or 16,
			FontFace = font(kind == "child" and Enum.FontWeight.Medium or Enum.FontWeight.SemiBold),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		})
		local desc = new("TextLabel", {
			Position = UDim2.fromOffset(indent, kind == "child" and 26 or 32),
			Size = UDim2.new(1, -indent, 0, 15),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = Theme.Dim,
			TextSize = 14,
			FontFace = font(Enum.FontWeight.Regular),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		})
		return frame, title, desc
	end

	-- วางแถวตามตาราง Layout คืน frame, title, desc ของแถว
	function placeRow(kind, name, order, parentOverride)
		if parentOverride then
			return rowShell("standalone", name, nil, parentOverride, order)
		end
		local where = Layout[kind][name]
		if not where then
			-- ชื่อที่ยังไม่ได้จัดหมวด โผล่ท้ายหน้าต่อสู้ ดีกว่าหายไปเงียบ ๆ
			where = { page = "combat", section = "defense", card = name, order = 99 }
		end
		if where.hidden then
			return rowShell("head", name, where, nil, 0)
		end
		local c = cardFor(where)
		if where.child then
			return rowShell("child", name, where, subBoxOf(c), where.child)
		end
		-- การ์ดอาจถูกสร้างไว้ก่อนโดยแถวย่อยที่ไม่มีลำดับ หัวการ์ดเป็นคนกำหนดลำดับจริง
		c.frame.LayoutOrder = where.order or c.frame.LayoutOrder
		return rowShell("head", name, where, c.frame, 0)
	end
end

-- วัดความกว้างข้อความไว้ทำปุ่มเลือกที่กว้างพอดีคำ (เดิมปุ่มกว้าง 24px ตายตัว ใส่ได้แค่ "1" "2")
local function textWidth(text, size)
	return game:GetService("TextService"):GetTextSize(text, size, Enum.Font.SourceSansSemibold, Vector2.new(1000, 40)).X
end

local features = {}

-- แถวเปิดแผงรายการ (Get Weapons / Auto-Quest ฯลฯ) ปุ่มขวาสลับ เปิด/ปิด เอง ผู้เรียกไม่ต้องจัดการ
local function featureRow(name, desc, order, onOpen, onClose)
	local frame, _, descLabel = placeRow("feature", name, order)
	local where = Layout.feature[name]
	descLabel.Text = where and where.help or desc
	descLabel.Size = UDim2.new(1, -110, 0, 13)

	local toggleLabel = new("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "เปิด  ›",
		TextColor3 = Theme.Text,
		TextSize = 14,
		FontFace = font(Enum.FontWeight.SemiBold),
	})

	local toggle = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(76, 28),
		BackgroundColor3 = Theme.Raised,
		AutoButtonColor = false,
		Text = "",
		Parent = frame,
	}, { capsule(), stroke(), toggleLabel })

	track(toggle.MouseEnter:Connect(function()
		tween(toggle, { BackgroundColor3 = Theme.On }, FAST)
		tween(toggleLabel, { TextColor3 = Theme.Base }, FAST)
	end))
	track(toggle.MouseLeave:Connect(function()
		tween(toggle, { BackgroundColor3 = Theme.Raised }, FAST)
		tween(toggleLabel, { TextColor3 = Theme.Text }, FAST)
	end))

	local entry = {}
	local open = false

	function entry.setOpen(state)
		if open == state then
			return
		end
		open = state
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

	local titleLabel = new("TextLabel", {
		Size = UDim2.new(1, -84, 0, 18),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Theme.Text,
		TextSize = 16,
		FontFace = font(Enum.FontWeight.SemiBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})

	-- ปุ่ม X เดิมดูเหมือนปิดทั้งสคริปต์ คนไม่กล้ากด เปลี่ยนเป็น "กลับ" ให้รู้ว่าแค่ออกจากหน้ารายการ
	local closeBtn2 = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, -3),
		Size = UDim2.fromOffset(70, 26),
		BackgroundColor3 = Theme.Raised,
		BackgroundTransparency = 0,
		AutoButtonColor = false,
		Text = "‹  กลับ",
		TextColor3 = Theme.Muted,
		TextSize = 14,
		FontFace = font(Enum.FontWeight.SemiBold),
		Parent = panel,
	}, { capsule(), stroke() })

	track(closeBtn2.MouseEnter:Connect(function()
		tween(closeBtn2, { TextColor3 = Theme.Text }, FAST)
	end))
	track(closeBtn2.MouseLeave:Connect(function()
		tween(closeBtn2, { TextColor3 = Theme.Muted }, FAST)
	end))

	local subtitle = new("TextLabel", {
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.Muted,
		TextSize = 13,
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
		TextSize = 14,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = panel,
	}, { capsule(), new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })

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
		TextSize = 13,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})

	local self = {
		panel = panel,
		title = titleLabel,
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
			TextColor3 = name == current and Theme.Base or Theme.Muted,
			TextSize = 13,
			FontFace = font(Enum.FontWeight.Medium),
		})
		local pill = new("TextButton", {
			-- วัดจากความกว้างจริง #name นับไบต์ คำไทย 3 ไบต์ต่อตัว ปุ่ม "ฝึกวิชา" เลยกว้างเกินครึ่งแถว
			Size = UDim2.fromOffset(textWidth(name, 13) + (compact and 14 or 22), 24),
			BackgroundColor3 = Theme.On,
			BackgroundTransparency = name == current and 0 or 1,
			AutoButtonColor = false,
			Text = "",
			Parent = container,
		}, { capsule(), stroke(), label })
		buttons[#buttons + 1] = { pill = pill, label = label, name = name }

		track(pill.MouseButton1Click:Connect(function()
			current = name
			for _, b in ipairs(buttons) do
				local on = b.name == name
				tween(b.pill, { BackgroundTransparency = on and 0 or 1 }, FAST)
				tween(b.label, { TextColor3 = on and Theme.Base or Theme.Muted }, FAST)
			end
			onChange(name)
		end))
	end
end

-- ร้านอาวุธ -----------------------------------------------------------------

-- ตัวรัน (คุยกับ NPC / ฆ่าม็อบ / เก็บของ) นิยามอยู่ล่างกว่า แต่ Get Weapons, Auto-Quest, Auto-Breathing ใช้ร่วมกัน
-- ประกาศไว้ก่อนแผงพวกนี้ ไม่งั้นโค้ดแผงอ้างถึงแล้วได้ global ว่าง ๆ
local Runner

-- แถบเงินใต้หัวแผง: ไอคอนเกม + ตัวเลข ต่อกันแนวนอน (ป้ายตัวหนังสือล้วนเดิมอ่านยาก ผู้ใช้ขอไอคอนให้ครบ)
-- RichText ของ Roblox ใส่รูปไม่ได้ เลยทำเป็นชิปแยก
function Game.walletBar(parent, position, currencies)
	local bar = new("Frame", {
		Position = position,
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) })
	local labels = {}
	for i, currency in ipairs(currencies) do
		local chip = new("Frame", {
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			LayoutOrder = i,
			Parent = bar,
		}, { new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
		}) })
		new("ImageLabel", {
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Image = Game.iconOf(currency) or "",
			ScaleType = Enum.ScaleType.Fit,
			LayoutOrder = 1,
			Parent = chip,
		})
		labels[currency] = new("TextLabel", {
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = "0",
			TextColor3 = Theme.Text,
			TextSize = 13,
			FontFace = font(Enum.FontWeight.SemiBold),
			LayoutOrder = 2,
			Parent = chip,
		})
	end
	return {
		frame = bar,
		set = function(wallet)
			for currency, label in pairs(labels) do
				label.Text = comma(wallet[currency] or 0)
			end
		end,
	}
end

local shopUI = makePanel("Get Weapons / ไอเทม", true)
shopUI.search.PlaceholderText = "ค้นหาชื่อของ ประเภท หรือแหล่งได้ เช่น Rengu, Katana, คอ…"
shopUI.walletBar = Game.walletBar(shopUI.panel, UDim2.fromOffset(0, 22), Config.WalletShown)

local buyLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Text = "GET",
	TextColor3 = Theme.Dim,
	TextSize = 15,
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
}, { capsule(), buyLabel })

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
		local qty = shopFilter.qty()
		buyLabel.Text = "GET  ·  " .. (qty > 1 and (comma(qty) .. " × ") or "") .. shopQueue[1]
	elseif #shopQueue > 1 then
		local qty = shopFilter.qty()
		buyLabel.Text = string.format("GET  ·  %d ชนิดตามลำดับ%s", #shopQueue, qty > 1 and (" อย่างละ " .. comma(qty)) or "")
	else
		buyLabel.Text = "GET"
	end
	tween(buyBtn, { BackgroundColor3 = enabled and Theme.On or Theme.Raised }, FAST)
	tween(buyLabel, { TextColor3 = enabled and Theme.Base or Theme.Dim }, FAST)
end

-- ติ๊กแล้วกล่องเต็มพร้อมเลขลำดับ ผู้ใช้จะได้เห็นว่าชิ้นไหนหาก่อน
-- hovered = แถวที่เพิ่งกดยกเลิก เมาส์ยังค้างอยู่ ให้อยู่สถานะ hover ไม่ใช่ปกติ
local function paintShopTicks(hovered)
	for _, r in ipairs(shopRows) do
		local order = table.find(shopQueue, r.data.name)
		tween(r.tickFill, { BackgroundTransparency = order and 0 or 1 }, FAST)
		-- เลขคิวโชว์เฉพาะตอนติ๊กหลายชิ้น ชิ้นเดียวไม่ต้องบอกลำดับ
		r.tickNum.Text = order and tostring(order) or ""
		r.tickNum.Visible = order ~= nil and #shopQueue > 1
		tween(r.frame, { BackgroundColor3 = (order or r == hovered) and Theme.Raised or Theme.Row }, FAST)
		r.tickStroke.Color = order and Theme.On or Theme.Muted
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
-- ช่องติ๊ก 18px เต็มช่องสีฟ้า + เครื่องหมายถูก เดิมเป็นจุด 8px ในกรอบ 14px คนใช้บอกว่ามองไม่ออกว่าติ๊กแล้ว
-- ผู้เรียก tween แค่ BackgroundTransparency ของ fill เครื่องหมายถูกตามค่านั้นเอง
local function tickBox(parent)
	local mark = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "✓",
		TextColor3 = Theme.Base,
		TextTransparency = 1,
		TextSize = 15,
		FontFace = font(Enum.FontWeight.Bold),
	})
	local fill = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.On,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, { corner(5), mark })
	track(fill:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
		mark.TextTransparency = fill.BackgroundTransparency
	end))
	local outline = stroke(Theme.Muted, 1.5)
	new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { corner(5), outline, fill })
	return fill, outline
end

-- กล่องรายละเอียดใต้แถว (เควส / ปราณ): หัวข้อเล็ก แล้วตามด้วยป้าย (ชิป) ที่ขึ้นบรรทัดใหม่เองเมื่อเต็ม
-- chips = { { ข้อความ, สี }, ... } สีบอกความหมาย: ฟ้า = EXP/ปราณ ทอง = Wen เขียว = มีพอ แดง = ขาด
local Detail = {}
function Detail.box(parent, order)
	local box = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Visible = false,
		Parent = parent,
	}, { new("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 6),
	}) })
	local inner = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Base,
		BorderSizePixel = 0,
		Parent = box,
	}, {
		corner(8),
		new("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local api = { frame = box, count = 0 }
	function api.section(title, chips)
		if #chips == 0 then
			return
		end
		api.count += 1
		local sec = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = api.count,
			Parent = inner,
		}, { new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
			Text = title,
			TextColor3 = Theme.Dim,
			TextSize = 13,
			FontFace = font(Enum.FontWeight.SemiBold),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			Parent = sec,
		})
		local wrap = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Parent = sec,
		}, { new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}) })
		for i, chip in ipairs(chips) do
			-- chip[3] = ไอคอน (rbxassetid) วางซ้ายในชิป ดันตัวหนังสือออกไป 24px
			local label = new("TextLabel", {
				Size = UDim2.fromOffset(0, 22),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Theme.Raised,
				Text = chip[1],
				TextColor3 = chip[2] or Theme.Text,
				TextSize = 13,
				FontFace = font(Enum.FontWeight.Medium),
				LayoutOrder = i,
				Parent = wrap,
			}, { capsule(), new("UIPadding", { PaddingLeft = UDim.new(0, chip[3] and 26 or 8), PaddingRight = UDim.new(0, 8) }) })
			if chip[3] then
				new("ImageLabel", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, -21, 0.5, 0),
					Size = UDim2.fromOffset(17, 17),
					BackgroundTransparency = 1,
					Image = chip[3],
					ScaleType = Enum.ScaleType.Fit,
					Parent = label,
				})
			end
		end
	end
	-- ข้อความยาว (คำใบ้ / วิธีหาของ) ตัดบรรทัดเอง ชิปยืดตามคำจะล้นกล่อง
	function api.note(title, text, color)
		api.count += 1
		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			RichText = true,
			Text = string.format('<font color="#787b8c">%s</font>\n%s', title, text),
			TextColor3 = color or Theme.Muted,
			TextSize = 13,
			FontFace = font(Enum.FontWeight.Regular),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			LayoutOrder = api.count,
			Parent = inner,
		})
	end
	function api.clear()
		for _, c in ipairs(inner:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		api.count = 0
	end
	return api
end

-- ป้ายของมี/ต้องใช้: "Demon Horns 3/10" เขียวถ้าพอ แดงถ้าขาด ตัวที่สาม = ไอคอนของเกม
function Detail.have(name, have, need)
	return { string.format("%s %s/%s", name, comma(have), comma(need)), have >= need and Theme.Good or Theme.Danger,
		Game.iconOf(name) }
end

-- ชื่อประเภทภาษาไทย (ชื่อโฟลเดอร์ใน ReplicatedStorage.Items) ใช้ทั้งเม็ดกรองและบรรทัดรองของแถว
Game.TypeThai = {
	Katana = "ดาบ", Weapons = "อาวุธ", Head = "หัว", Face = "หน้า", Ear = "หู", Neck = "คอ",
	Back = "หลัง", Waist = "เอว", Haori = "ฮาโอริ", Outfits = "ชุด",
	Materials = "แร่/วัสดุ", Potions = "ยา", Schematics = "แบบพิมพ์", Gourds = "น้ำเต้า",
	["Evil Art Orbs"] = "ออร์บ", Fishing = "ตกปลา", ["Quest Items"] = "ของเควส",
}

function Game.priceText(price)
	local parts = {}
	for _, p in ipairs(priceParts(price)) do
		parts[#parts + 1] = p.currency == "Product" and "Robux" or (comma(p.amount) .. " " .. p.currency)
	end
	return table.concat(parts, " + ")
end

-- รายละเอียดไอเทม: สคริปต์จะทำอะไรตอนกด GET แล้วตามด้วยแหล่งได้ทุกทางแยกตามชนิด
-- ข้อมูลทั้งหมดอ่านจากตารางของเกม: ดัชนีแหล่งได้ (ItemSources) ร้าน (Regions / Shop) ดรอป (NpcDataTable)
-- หีบ (ChestsLootTable) สูตร (Crafting) ไม่มีค่าที่เดาเอง
function Detail.item(box, data)
	box.clear()
	local wallet = Game.wallet()
	local def = data.def or {}

	-- แบบพิมพ์เซ็ต: ไม่มีแหล่งในตารางเกม บอกวิธีที่สคริปต์ทำ + ของที่ตีได้จากแบบนี้แทน
	if data.guide then
		if data.owned then
			box.note("มีแบบนี้แล้ว", "ตีของได้ที่ Blacksmith Togane (แบบไม่หายตอนตี)", Theme.Good)
		elseif data.locked then
			box.note("กด GET ตอนนี้ไม่ได้", data.reason or "-", Theme.Warn)
		else
			box.note("กด GET แล้วสคริปต์จะ", Game.SchematicSteps[data.guide.how] or data.reason, Theme.Good)
		end
		if data.guide.at then
			local p = data.guide.at
			box.note("ตำแหน่ง", string.format("(%d, %d, %d)", p.X, p.Y, p.Z), Theme.Text)
		end
		local ok, defs = pcall(require, ReplicatedStorage.CAM.Global.Collectibles.Items)
		local made = ok and defs[data.result]
		local stats = {}
		local src = made and (made.Stats or made.ActiveToolStats) or {}
		for stat, v in pairs(src) do
			stats[#stats + 1] = { string.format("%s +%s", stat, tostring(v)), Theme.Accent }
		end
		table.sort(stats, function(a, b)
			return a[1] < b[1]
		end)
		box.section("ตีแล้วได้ " .. data.result .. " (Tier 1 · Tier 3 คูณ 1.3)", stats)
		local chips = {}
		for _, c in ipairs(Game.recipesFor(data.result)) do
			if not (c.recipe.required and c.recipe.required[1] and c.recipe.required[1].name == data.result) then
				for _, input in ipairs(Game.recipeInputs(c.recipe)) do
					if not input.keep then
						chips[#chips + 1] = Detail.have(input.name, wallet[input.name] or 0, input.amount)
					end
				end
				break
			end
		end
		box.section("วัตถุดิบตอนตี (มี/ต้องใช้)", chips)
		return
	end

	if data.locked then
		box.note("กด GET ตอนนี้ไม่ได้", data.reason or "-", Theme.Warn)
	else
		-- ร้านประจำไม่มี reason ราคาอยู่ใน data.cost (จาก Shop.itemsforsale) ไม่ใช่ def.Price
		-- Fancy Katana: def.Price = 6 Metal Scraps แต่ร้าน Raze ขาย 1,500 Wen
		local price = {}
		for _, p in ipairs(data.cost) do
			price[p.currency] = p.amount
		end
		box.note("กด GET แล้วสคริปต์จะ", data.reason or ("ซื้อ " .. Game.priceText(price)), Theme.Good)
	end

	local groups = { shop = {}, drop = {}, chest = {}, craft = {}, quest = {}, fish = {} }
	for _, s in ipairs(Game.itemSources(data.name)) do
		table.insert(groups[s.kind], s)
	end
	local function pct(c)
		return c and string.format("%g%%", math.floor(c * 1000 + 0.5) / 10) or ""
	end

	local shops = {}
	for _, s in ipairs(groups.shop) do
		local info = Game.sellers()[s.where] or {}
		local listing = Shop and Shop.itemsforsale[data.name]
		local price = (listing and listing.Price) or (info.prices and info.prices[data.name]) or def.Price
		local text = string.format("%s · %s", s.where, info.region or "?")
		if price then
			text ..= " · " .. Game.priceText(price)
		end
		local color = Theme.Text
		if info.rotating then
			-- ร้านหมุนเวียนสุ่มของขึ้นแผงทีละรอบ รอบนี้ไม่มีก็ต้องรอรอบถัดไป
			text ..= string.format(" · ร้านหมุนเวียน สุ่ม %s จาก %d ชิ้น", tostring(info.rotating.slots or "?"), info.rotating.pool)
			color = listing and Theme.Good or Theme.Warn
		end
		if info.timed then
			text ..= string.format(" · ตลาดมืด โผล่ครั้งละ %d นาที", info.timed.minutes)
			color = Theme.Warn
		end
		if info.night then
			text ..= " · เฉพาะกลางคืน"
		end
		if info.quest then
			text ..= " · ต้องจบเควส " .. info.quest
		end
		shops[#shops + 1] = { text, color }
	end
	box.section("ซื้อจากร้าน", shops)

	local drops = {}
	for _, s in ipairs(groups.drop) do
		local npc
		for code, n in pairs(lootTables().npc) do
			if type(n) == "table" and (n.Name == s.where or code == s.where) then
				npc = { code = code, def = n }
			end
		end
		local region = npc and Game.mobRegion(npc.code) or Game.mobRegion(s.where)
		local text = string.format("%s %s", s.where, pct(s.chance))
		if region then
			text ..= " · " .. region
		end
		if npc and npc.def.OnlyAtNight then
			text ..= " · กลางคืน"
		end
		local hp = npc and npc.def.Stats and npc.def.Stats.MaxHealth
		if hp then
			text ..= " · " .. comma(hp) .. " HP"
		end
		drops[#drops + 1] = { text, Theme.Text }
	end
	box.section("ดรอปจากม็อบ / บอส (โอกาสต่อตัว)", drops)

	for _, s in ipairs(groups.chest) do
		local who = {}
		for i, m in ipairs(Game.chestDroppers(s.where)) do
			if i > 5 then
				who[#who + 1] = "…"
				break
			end
			who[#who + 1] = m.name .. (m.hp and (" (" .. comma(m.hp) .. " HP)") or "")
		end
		box.note(string.format("%s · โอกาสได้ %s ต่อหีบ", s.where, pct(s.chance)),
			#who > 0 and ("หีบนี้ดรอปจาก: " .. table.concat(who, ", ")) or "หีบวางในแมพ ไม่ได้ดรอปจากม็อบ", Theme.Text)
	end

	for _, c in ipairs(Game.recipesFor(data.name)) do
		local station = c.recipe.station
		local chips = {}
		for _, input in ipairs(Game.recipeInputs(c.recipe)) do
			if input.keep then
				chips[#chips + 1] = { input.name .. " (ต้องมี ไม่หาย)", (wallet[input.name] or 0) > 0 and Theme.Good or Theme.Danger }
			else
				chips[#chips + 1] = Detail.have(input.name, wallet[input.name] or 0, input.amount)
			end
		end
		local where = Game.Forges[station] and ("ช่าง " .. Game.Forges[station]) or "อีกแมพ ยังไปไม่ได้"
		box.section(string.format("คราฟต์ที่ %s (%s) · มี/ต้องใช้", tostring(station), where), chips)
	end

	local quests = {}
	for _, s in ipairs(groups.quest) do
		quests[#quests + 1] = { "รางวัลเควส " .. s.where, Theme.Accent }
	end
	for _ in ipairs(groups.fish) do
		quests[#quests + 1] = { "ได้จากตกปลา", Theme.Accent }
	end
	box.section("อื่น ๆ", quests)

	if #Game.itemSources(data.name) == 0 and #Game.recipesFor(data.name) == 0 then
		box.note("แหล่งได้", "ในเกมตอนนี้ไม่มีร้าน ม็อบ หีบ หรือสูตรไหนให้ชิ้นนี้เลย (ดัชนี \"ได้จากไหน\" ของเกมก็ว่าง)",
			Theme.Danger)
	end

	local stats = {}
	for stat, v in pairs(type(def.Stats) == "table" and def.Stats or {}) do
		stats[#stats + 1] = { string.format("%s +%s", stat, tostring(v)), Theme.Accent }
	end
	table.sort(stats, function(a, b)
		return a[1] < b[1]
	end)
	local race = def.EquipRequirements and def.EquipRequirements.Race
	if race then
		local list = {}
		for _, r in pairs(race) do
			list[#list + 1] = r
		end
		stats[#stats + 1] = { "ใส่ได้เฉพาะเผ่า " .. table.concat(list, "/"), Theme.Warn }
	end
	box.section("สเตตัสตอนสวมใส่", stats)
	if type(def.Description) == "string" then
		box.note("คำอธิบาย", def.Description)
	end
end

-- แถวไอเทม: ช่องติ๊ก · ไอคอนจริงของเกม (ขอบสีตามความหายาก) · ชื่อ · ประเภท/ความหายาก · ทางที่จะได้ · ปุ่มข้อมูล
local function buildShopRow(data, order)
	local frame = new("Frame", {
		Size = UDim2.new(1, -6, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Row,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = shopUI.list,
	}, { corner(8), new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
	local head = new("Frame", {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = frame,
	})

	local tickFill, tickStroke = tickBox(head)
	-- ลำดับคิวเป็นป้ายกลมมุมขวาบนของช่องติ๊ก ในช่องเป็นเครื่องหมายถูกเหมือนแผงอื่น
	local tickNum = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(15, 15),
		BackgroundColor3 = Theme.Accent2,
		Text = "",
		TextColor3 = Theme.Base,
		TextSize = 11,
		FontFace = font(Enum.FontWeight.Bold),
		Visible = false,
		ZIndex = 3,
		Parent = tickFill.Parent,
	}, { capsule() })
	if data.locked then
		tickStroke.Color = Theme.Stroke
	end

	local rarityColor = RarityColor[data.rarity] or Theme.Muted
	new("ImageLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 40, 0.5, 0),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Theme.Base,
		Image = data.icon or "",
		ImageTransparency = data.locked and 0.4 or 0,
		ScaleType = Enum.ScaleType.Fit,
		Parent = head,
	}, { corner(8), stroke(rarityColor, 1.5) })

	local rarities = require(ReplicatedStorage.CAM.Global.Rarities)
	local rarityName = rarities.Order[data.rarity] or ("Rarity " .. data.rarity)
	new("TextLabel", {
		Position = UDim2.fromOffset(86, 8),
		Size = UDim2.new(0.5, -86, 0, 17),
		BackgroundTransparency = 1,
		Text = data.name,
		TextColor3 = data.locked and Theme.Muted or Theme.Text,
		TextSize = 15,
		FontFace = font(Enum.FontWeight.SemiBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = head,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(86, 27),
		Size = UDim2.new(0.5, -86, 0, 14),
		BackgroundTransparency = 1,
		RichText = true,
		Text = string.format('<font color="#%s">%s</font>  ·  %s%s', rarityColor:ToHex(), rarityName,
			Game.TypeThai[data.group] or data.group, (data.have or 0) > 0 and ("  ·  มีแล้ว " .. data.have) or ""),
		TextColor3 = Theme.Dim,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = head,
	})

	-- ทางที่สคริปต์จะใช้ (ร้าน / ฟาร์ม / ตี) หรือเหตุผลที่ยังทำไม่ได้ ชิดขวา
	local costText = {}
	for _, p in ipairs(data.cost) do
		costText[#costText + 1] = comma(p.amount) .. " " .. p.currency
	end
	local right = (data.locked or data.farmable) and (data.reason or "ล็อก") or ("ซื้อ " .. table.concat(costText, " + "))
	new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -86, 0, 10),
		Size = UDim2.new(0.5, -100, 0, 32),
		BackgroundTransparency = 1,
		Text = right .. (data.note and ("  ·  " .. data.note) or ""),
		TextColor3 = (data.owned and Theme.Good) or (data.locked and Theme.Warn) or Theme.Good,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.Medium),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = head,
	})

	local row = {
		frame = frame,
		tickFill = tickFill,
		tickStroke = tickStroke,
		tickNum = tickNum,
		data = data,
		haystack = table.concat({ data.name, data.group, Game.TypeThai[data.group] or "", right, data.note or "" }, " "):lower(),
	}

	local hit = new("TextButton", {
		Size = UDim2.new(1, -86, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		Parent = head,
	})
	local infoBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(66, 24),
		BackgroundColor3 = Theme.Raised,
		AutoButtonColor = false,
		Text = "ข้อมูล +",
		TextColor3 = Theme.Muted,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.Medium),
		Parent = head,
	}, { capsule(), stroke() })

	local detail
	local function toggleInfo()
		if not detail then
			detail = Detail.box(frame, 2)
		end
		local open = not detail.frame.Visible
		if open then
			Detail.item(detail, data)
		end
		detail.frame.Visible = open
		infoBtn.Text = open and "ข้อมูล –" or "ข้อมูล +"
		infoBtn.TextColor3 = open and Theme.Accent or Theme.Muted
	end
	track(infoBtn.MouseButton1Click:Connect(toggleInfo))

	track(hit.MouseButton1Click:Connect(function()
		-- มีแล้ว (แบบพิมพ์เซ็ต) ไม่ต้องหา บอกที่แถบสถานะ ไม่เปิดกล่องข้อมูลให้ดูเหมือนกดผิด
		if data.owned then
			shopUI.setStatus(data.name .. " มีแล้ว ไม่ต้องหา · กด ข้อมูล ดูสเตตัสกับวัตถุดิบตอนตี", Theme.Good)
			return
		end
		-- ติ๊กไม่ได้ กดแล้วเปิดข้อมูลแทน จะได้เห็นว่าได้จากไหน ติดอะไร
		if data.locked then
			toggleInfo()
			return
		end
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
	-- นับแยกระดับโดยไม่สนตัวกรอง Rarity เอง ชิประดับที่ได้ 0 จะจาง บอกว่ากดไปก็ไม่เจออะไร
	local perRarity = {}
	for _, r in ipairs(shopRows) do
		local d = r.data
		-- ชนิดแหล่งได้ของแถว อ่านจากดัชนีของเกมครั้งแรกที่ต้องใช้ แล้วเก็บไว้กับแถว
		if not r.kinds then
			r.kinds = {}
			for _, s in ipairs(Game.itemSources(d.name)) do
				r.kinds[s.kind] = true
			end
			-- ร้าน Spins / Gamepass ไม่อยู่ในดัชนีร้านของเกม (ไม่มี NPC) แต่ขายจริงใน Shop.itemsforsale
			r.kinds.shop = r.kinds.shop or d.source == "shop"
			r.kinds.craft = r.kinds.craft or #Game.recipesFor(d.name) > 0
		end
		local src, okSrc = shopFilter.src, true
		-- แผงแบบพิมพ์เซ็ตซ่อนแท็บแหล่งได้ (ไม่มีร้าน/ดรอป) โชว์ทุกชิ้นพร้อมสถานะ มีแล้ว / ยังขาดอะไร
		if shopFilter.mode == "nightfall" then
			src = "ทั้งหมด"
		end
		if src == "หาได้ตอนนี้" then
			okSrc = not d.locked
		elseif src == "ซื้อได้" then
			okSrc = r.kinds.shop == true
		elseif src == "ดรอป/หีบ" then
			okSrc = r.kinds.drop or r.kinds.chest or false
		elseif src == "คราฟต์" then
			okSrc = r.kinds.craft == true
		end
		local okType = shopFilter.type == "ทุกประเภท" or Game.TypeThai[d.group] == shopFilter.type
		-- ค้นได้ทั้งชื่อ หมวด และข้อความแหล่งได้ที่โชว์ขวาแถว พิมพ์ชื่อบอสก็เจอของทุกชิ้นที่บอสนั้นให้
		local okText = query == "" or r.haystack:find(query, 1, true) ~= nil
		local okRarity = next(shopFilter.rarity) == nil or shopFilter.rarity[d.rarity] == true
		if okSrc and okType and okText then
			perRarity[d.rarity] = (perRarity[d.rarity] or 0) + 1
		end
		r.frame.Visible = okSrc and okType and okText and okRarity
		if r.frame.Visible then
			shown += 1
		end
	end
	for tier, chip in pairs(shopFilter.rarityChips or {}) do
		local empty = (perRarity[tier] or 0) == 0
		if chip.empty ~= empty then
			chip.empty = empty
			chip.paint()
		end
	end
	if shown == 0 then
		shopUI.setStatus("ไม่พบของในแท็บนี้ ลองแท็บ ทั้งหมด หรือเปลี่ยนประเภท", Theme.Muted)
	else
		shopUI.setStatus(string.format("แสดง %d จาก %d ชิ้น · กดแถวเพื่อติ๊ก · กด ข้อมูล ดูแหล่งได้ทุกทาง", shown, #shopRows),
			Theme.Muted)
	end
end

local function rebuildShop()
	for _, r in ipairs(shopRows) do
		r.frame:Destroy()
	end
	table.clear(shopRows)

	local listings, wallet = Game.listings(shopFilter.mode)
	-- ของที่ได้ตอนนี้ขึ้นก่อน แล้วหายากก่อน เดิมเรียง Common ก่อน ของดีจมอยู่ท้ายรายการ
	table.sort(listings, function(a, b)
		if a.locked ~= b.locked then
			return not a.locked
		end
		if a.rarity ~= b.rarity then
			return a.rarity > b.rarity
		end
		return a.name < b.name
	end)
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

	shopUI.subtitle.Text = ""
	shopUI.walletBar.set(wallet)

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

-- แถวบน = แท็บตามแหล่งได้ แถวล่าง = ประเภทของ (โชว์ตลอด)
-- เดิมแถวบนเป็นประเภทอังกฤษ + ปุ่ม "เฉพาะที่หาได้" แยก คนใช้บอกว่าดูยาก หาของที่เอาได้จริงไม่เจอ
Game.ShopTabs = { "หาได้ตอนนี้", "ซื้อได้", "ดรอป/หีบ", "คราฟต์", "ทั้งหมด" }
shopFilter.src = Game.ShopTabs[1]
shopFilter.type = "ทุกประเภท"
shopFilter.wearRow.Visible = true
-- แถวที่สามคือ Rarity เลื่อนรายการลง 30 ตามความสูงแถว (24) + ช่องไฟ 6 แบบสองแถวบน
shopUI.list.Position = UDim2.fromOffset(0, 174)
shopUI.list.Size = UDim2.new(1, 0, 1, -230)

addPills(shopUI.filterRow, Game.ShopTabs, function(name)
	shopFilter.src = name
	applyShopFilter()
end)

-- จำนวนที่จะหา ใช้เฉพาะแผงวัตถุดิบ (ของสวมใส่หาทีละชิ้นเสมอ) ตีสูตรทีต้องใช้ Silk Thread 200-1000 ชิ้น
-- กดทีละชิ้นทีละรอบไม่ไหว ช่องนี้อยู่ซ้ายของปุ่ม GET ปุ่มหดให้ที่
shopFilter.qtyBox = new("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromOffset(116, 34),
	BackgroundColor3 = Theme.Raised,
	Visible = false,
	Parent = shopUI.panel,
}, {
	capsule(),
	stroke(),
	new("TextLabel", {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(0, 44, 1, 0),
		BackgroundTransparency = 1,
		Text = "จำนวน",
		TextColor3 = Theme.Dim,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
	}),
})
shopFilter.qtyInput = new("TextBox", {
	Position = UDim2.fromOffset(58, 0),
	Size = UDim2.new(1, -70, 1, 0),
	BackgroundTransparency = 1,
	Text = "1",
	TextColor3 = Theme.Text,
	TextSize = 16,
	FontFace = font(Enum.FontWeight.Bold),
	TextXAlignment = Enum.TextXAlignment.Right,
	ClearTextOnFocus = false,
	Parent = shopFilter.qtyBox,
})

-- 1-9999 เซิร์ฟรับซื้อครั้งละ 99 อยู่แล้ว Runner.obtain วนซื้อ/ฟาร์มจนครบเอง
function shopFilter.qty()
	if shopFilter.mode ~= "material" then
		return 1
	end
	return math.clamp(math.floor(tonumber(shopFilter.qtyInput.Text) or 1), 1, 9999)
end
track(shopFilter.qtyInput.FocusLost:Connect(function()
	shopFilter.qtyInput.Text = tostring(shopFilter.qty())
	refreshBuyButton()
end))

-- แผงเดียวใช้สองโหมด: Get Weapons (อาวุธ + ของสวมใส่) กับ Get Materials
-- ใช้ตัวกรอง คิว ตัวรัน ร่วมกัน สลับแค่รายการของ เม็ดประเภท หัวแผง กับช่องจำนวน
function shopFilter.setMode(mode)
	shopFilter.mode = mode
	for _, b in ipairs(shopFilter.wearRow:GetChildren()) do
		if b:IsA("GuiButton") then
			b:Destroy()
		end
	end
	local types = { "ทุกประเภท" }
	-- แบบพิมพ์เซ็ตเป็นหมวดเดียว ไม่ต้องมีเม็ดประเภท
	local sets = mode == "material" and { Game.MaterialGroups }
		or mode == "nightfall" and {}
		or { Game.WeaponGroups, Game.WearGroups }
	for _, groups in ipairs(sets) do
		for _, group in ipairs(groups) do
			types[#types + 1] = Game.TypeThai[group]
		end
	end
	shopFilter.type = "ทุกประเภท"
	addPills(shopFilter.wearRow, types, function(name)
		shopFilter.type = name
		applyShopFilter()
	end, true)

	local material = mode == "material"
	shopUI.title.Text = material and "Get Materials / วัตถุดิบ"
		or mode == "nightfall" and "Get Nightfall Schematic / แบบพิมพ์เซ็ต"
		or "Get Weapons / ไอเทม"
	shopUI.search.PlaceholderText = material and "ค้นหาชื่อของหรือแหล่งได้ เช่น Silk Thread, Demon Horns, Hoyuzo…"
		or mode == "nightfall" and "ค้นหาชื่อแบบหรือวิธี เช่น Katana, Study, กุญแจ…"
		or "ค้นหาชื่อของ ประเภท หรือแหล่งได้ เช่น Rengu, Katana, คอ…"
	shopFilter.qtyBox.Visible = material
	buyBtn.Position = UDim2.new(0, material and 124 or 0, 1, 0)
	buyBtn.Size = UDim2.new(1, material and -124 or 0, 0, 34)

	-- แบบพิมพ์เซ็ต: แท็บแหล่งได้ / ประเภท / ความหายาก ไม่มีความหมาย (11 ชิ้น Mythic หมวดเดียว ไม่มีร้าน)
	-- ซ่อนทั้งสามแถวแล้วดันรายการขึ้นไปแทนที่ เลข 82 = ตำแหน่งแถวแท็บ, -138 = 82 + ปุ่ม GET/สถานะ 56
	local plain = mode == "nightfall"
	shopUI.filterRow.Visible = not plain
	shopFilter.wearRow.Visible = not plain
	if shopFilter.rarityRow then
		shopFilter.rarityRow.Visible = not plain
		shopUI.list.Position = UDim2.fromOffset(0, plain and 82 or 174)
		shopUI.list.Size = UDim2.new(1, 0, 1, plain and -138 or -230)
	end
end
shopFilter.setMode("gear")

-- Rarity: เลือกได้หลายระดับพร้อมกัน ไม่เลือกเลย = ทุกระดับ (กดซ้ำเพื่อเอาออก)
-- ชิปมีจุดสีของระดับนั้น ตอนเลือกขอบกับตัวหนังสือเป็นสีระดับ พื้นทาสีเดียวกันจาง ๆ
-- ไม่ใช้พื้นขาวทึบแบบเม็ดแถวบน เพราะสีระดับคือข้อมูล ถ้าทุกเม็ดขาวเหมือนกันจะอ่านไม่ออกว่าเลือกระดับไหน
-- ระดับที่ไม่มีของเลยภายใต้แท็บ/ประเภท/คำค้นตอนนี้ จางลง applyShopFilter เป็นคนนับ
shopFilter.rarity = {}
shopFilter.rarityChips = {}
do
	local row = new("Frame", {
		Position = UDim2.fromOffset(0, 142),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Parent = shopUI.panel,
	}, { new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) })

	shopFilter.rarityRow = row
	local rarities = require(ReplicatedStorage.CAM.Global.Rarities)
	for tier, name in ipairs(rarities.Order) do
		local color = RarityColor[tier] or Theme.Muted
		local dot = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 9, 0.5, 0),
			Size = UDim2.fromOffset(7, 7),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, { capsule() })
		local label = new("TextLabel", {
			Position = UDim2.fromOffset(21, 0),
			Size = UDim2.new(1, -21, 1, 0),
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = Theme.Muted,
			TextSize = 13,
			FontFace = font(Enum.FontWeight.SemiBold),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local rim = stroke()
		local chip = new("TextButton", {
			-- 9 ขอบซ้าย + จุด 7 + ช่อง 5 + ชื่อ + ขอบขวา 9 = กว้างพอดีคำ ทั้งเจ็ดชิปรวมราว 520px พอดีแผง ~537
			Size = UDim2.fromOffset(30 + textWidth(name, 13), 24),
			BackgroundColor3 = color,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = tier,
			Parent = row,
		}, { capsule(), rim, dot, label })

		local entry = { chip = chip, label = label, dot = dot, rim = rim, color = color, empty = false }
		shopFilter.rarityChips[tier] = entry

		function entry.paint()
			local on = shopFilter.rarity[tier] == true
			tween(chip, { BackgroundTransparency = on and 0.82 or 1 }, FAST)
			tween(label, {
				TextColor3 = on and color or Theme.Muted,
				TextTransparency = (entry.empty and not on) and 0.55 or 0,
			}, FAST)
			tween(dot, { BackgroundTransparency = (entry.empty and not on) and 0.6 or 0 }, FAST)
			rim.Color = on and color or Color3.new(1, 1, 1)
			rim.Transparency = on and 0.25 or 0.85
		end

		track(chip.MouseButton1Click:Connect(function()
			shopFilter.rarity[tier] = not shopFilter.rarity[tier] or nil
			entry.paint()
			applyShopFilter()
		end))
		track(chip.MouseEnter:Connect(function()
			if not shopFilter.rarity[tier] then
				tween(label, { TextColor3 = Theme.Text }, FAST)
			end
		end))
		track(chip.MouseLeave:Connect(function()
			if not shopFilter.rarity[tier] then
				tween(label, { TextColor3 = Theme.Muted }, FAST)
			end
		end))
	end
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
	Game.setResume({ kind = "shop", mode = shopFilter.mode, queue = table.clone(shopQueue) })
	local auraWasOn = Runner.auraOn and Runner.auraOn()
	if Runner.setAura and not auraWasOn then
		Runner.setAura(true)
	end
	-- แยก thread เพราะ Game.buy / Runner.obtain รอ ถ้า handler ถูกเรียกแบบห้าม yield
	-- (getconnections():Fire() ของ executor) จะพังด้วย "thread is not yieldable"
	task.spawn(function()
		local got, skipped, lastErr = {}, {}, nil
		-- ชื่อ -> os.clock() ที่ม็อบแหล่งดรอปน่าจะเกิดใหม่ ระหว่างนั้นไปทำชิ้นอื่นในคิว
		local waitUntil = {}
		local goal = {}
		local function ready(name)
			return not skipped[name] and (waitUntil[name] or 0) <= os.clock()
		end
		-- Runner.farm ถามก่อนยืนรอเกิดใหม่: มีชิ้นอื่นที่ทำได้ตอนนี้ไหม ถ้ามีก็คืนคิว
		Runner.canYield = function(current)
			for _, name in ipairs(shopQueue) do
				if name ~= current and ready(name) then
					return true
				end
			end
			return false
		end
		while not Runner.cancel do
			-- อ่านคิวใหม่ทุกชิ้น ผู้ใช้ติ๊กเพิ่มหรือเอาออกระหว่างรันได้
			-- ของที่ต้องรอร้านมา (Black Marketer) อาจรอเป็นชั่วโมง ทำชิ้นอื่นในคิวให้หมดก่อน
			local function pick(usable)
				for pass = 1, 2 do
					for _, name in ipairs(shopQueue) do
						if usable(name) then
							for _, r in ipairs(shopRows) do
								if r.data.name == name and (pass == 2 or r.data.source ~= "vendor") then
									return r.data
								end
							end
						end
					end
				end
			end
			local target = pick(ready)
			if not target then
				-- ทุกชิ้นรอม็อบเกิดใหม่อยู่ ไปรอตัวที่จะเกิดก่อน (farm ยืนรอที่จุดเกิดเองเพราะ canYield = false)
				local soonest
				for _, name in ipairs(shopQueue) do
					if not skipped[name] and (not soonest or (waitUntil[name] or 0) < (waitUntil[soonest] or 0)) then
						soonest = name
					end
				end
				target = soonest and pick(function(name)
					return name == soonest
				end)
				if soonest then
					waitUntil[soonest] = nil
				end
			end
			if not target then
				break
			end

			shopUI.progress = string.format("[%d/%d] %s · ", #got + 1, #got + #shopQueue, target.name)
			shopUI.queueStatus("กำลังหา…", Theme.Accent)
			-- ครอบ pcall เสมอ ถ้าพังกลางทาง Runner.active จะค้างเป็น true แล้วปุ่มเงียบไปจนกว่าจะรีโหลด
			-- (เจอจริงสมัยปุ่ม BUY: สถานะค้าง "กำลังซื้อ Fancy Katana…")
			-- วัตถุดิบไปทาง Runner.obtain เสมอแม้ซื้อได้ มันวนซื้อครั้งละ 99 จนครบจำนวน Game.buy ซื้อรอบเดียว
			local done, ok, err, secsLeft
			if target.source == "schematic" then
				done, ok, err, secsLeft = pcall(Runner.schematic, target.name)
			elseif target.farmable or shopFilter.mode == "material" then
				-- จำนวนเป้าหมายตั้งครั้งแรกที่เริ่มชิ้นนี้ กลับมาทำต่อหลังสลับไปชิ้นอื่นไม่ต้องบวกเพิ่มอีกรอบ
				goal[target.name] = goal[target.name] or (Game.wallet()[target.name] or 0) + shopFilter.qty()
				done, ok, err, secsLeft = pcall(Runner.obtain, target.name, goal[target.name])
			else
				done, ok, err = pcall(Game.buy, target)
			end
			if not done then
				ok, err = false, ok
			end
			-- งานข้างในทำ identity หล่นได้ (ดู report) ต่อจากนี้แตะติ๊ก/ป้ายของแผง
			if setthreadidentity and Game.loadIdentity then
				setthreadidentity(Game.loadIdentity)
			end

			if err == Runner.RESPAWN and not Runner.cancel then
				-- ไม่ใช่พลาด ม็อบตายรอเกิด กลับมาอีกทีตอนใกล้เกิด (อย่างน้อย 10 วิ กันวนสลับถี่)
				waitUntil[target.name] = os.clock() + math.max(10, tonumber(secsLeft) or 60)
			elseif ok then
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
		Runner.canYield = nil
		Game.setResume(nil)

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

Game.persist.resumers.shop = function(job)
	if Runner.active or type(job.queue) ~= "table" or #job.queue == 0 then
		return
	end
	shopFilter.setMode(job.mode or "gear")
	rebuildShop()
	table.clear(shopQueue)
	for _, n in ipairs(job.queue) do
		shopQueue[#shopQueue + 1] = n
	end
	paintShopTicks()
	runShopQueue()
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
								-- จุดวางของทุกช่อง ใช้ยิง QuestProgress เองตอนเกมไม่สร้างของให้ (ดู Runner.pickup)
								positions = spec and type(spec.Positions) == "table" and spec.Positions or nil,
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
							-- นิยามดิบจากเกม ใช้โชว์รายละเอียด (รางวัล ค่ารับเควส เงื่อนไข เวลาจำกัด)
							raw = q,
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

-- ของแผง Auto-Quest รวมไว้ในตารางเดียว chunk หลักใช้ local ใกล้เพดาน 200 ของ Luau แล้ว
local QL = {}
-- แท็บในแผง: แนะนำ / ทำซ้ำได้ / ครั้งเดียว / บอส / ปราณ-สไตล์ / ที่เลือก (ดู QL.tabs)
QL.tab = "แนะนำ"
-- ติ๊กได้หลายเควส ข้าม NPC ได้ Runner.start รับรายการผสมอยู่แล้ว (ต่อคิวขั้นก่อนหน้าข้าม NPC เอง)
-- ที่ติ๊กเก็บตามคีย์เควส สลับแท็บแล้วสร้างแถวใหม่ ติ๊กเดิมยังอยู่
local questSelected
QL.picks = {}
local questRows = {}

-- เควสที่ติ๊กไว้ทั้งหมด เรียงตามลำดับในรายการเกม (เลเวลต่ำไปสูง) แต่เควสของ NPC เดียวกันเอาเลเวลสูงก่อน
-- ผู้ใช้อยากให้เคลียร์บอสก่อนเสมอ ใช้ sortLevel อย่างเดียวไม่ได้ เควสโจร 3 ตัวไม่มีเลเวล
-- เลยได้ค่าต่ำสุดของโซน (7) เท่ากับบอส Lv 7 พอดี ผลคือโจรมาก่อนบอส ใช้เลเวลจริงก่อน แล้วค่อย Exp ตัดสิน
local function pickedQuests()
	local byNpc, order = {}, {}
	for _, d in ipairs(Game.quests()) do
		if QL.picks[d.key] then
			local k = d.region .. "/" .. d.npc
			if not byNpc[k] then
				byNpc[k] = {}
				order[#order + 1] = k
			end
			table.insert(byNpc[k], d)
		end
	end
	local list = {}
	for _, k in ipairs(order) do
		local mine = byNpc[k]
		table.sort(mine, function(a, b)
			local la, lb = a.level or 0, b.level or 0
			if la ~= lb then
				return la > lb
			end
			return a.exp > b.exp
		end)
		for _, d in ipairs(mine) do
			list[#list + 1] = d
		end
	end
	return list
end

local applyQuestFilter
local refreshStartButton

local function questsChanged()
	local list = pickedQuests()
	questSelected = #list > 0 and list or nil
	if questSelected then
		local titles = {}
		for _, d in ipairs(list) do
			titles[#titles + 1] = d.title
		end
		questUI.setStatus(string.format("เลือก %d เควส: %s", #list, table.concat(titles, " → ")), Theme.Accent)
	else
		applyQuestFilter()
	end
	refreshStartButton()
end

local function levelText(data)
	return data.level and ("Lv " .. data.level)
		or (data.estimated and ("~Lv " .. data.sortLevel) or "เริ่มต้น")
end

-- ข้อมูลตัวเราที่ใช้ตัดสินว่าเควสไหนรับได้: เลเวล เผ่า ปราณ
-- เผ่าเก็บเป็น Human / Slayer / Demon / Hybrid (Data.Race) เกมเช็กด้วย table.find(Requirements.Race, Race)
-- ตรงตัว (BossHunts.Eligible) Human ไม่นับเป็น Slayer
function QL.player()
	local slot = equippedSlot()
	local race = slot and slot:FindFirstChild("Race")
	local powers = slot and slot:FindFirstChild("Powers")
	local breathing = powers and powers:FindFirstChild("Breathing")
	return {
		level = Game.level(),
		race = race and race.Value or "",
		breathing = breathing and breathing.Value ~= "" and breathing.Value or nil,
	}
end

-- หมวดของเควส อ่านจากนิยามเกมตรง ๆ ไม่เดาจากชื่อ:
--   power = รางวัลเป็นปราณ / Evil Art / สไตล์หมัด (Rewards.Power)
--   boss  = Boss Hunts (Category BossHunt) หรือเควสที่งานเดียวคือ Defeat <บอส> (Zuko, Mother Bear, Kaiden, Hoyuzo)
--   once  = เกมจดว่าจบแล้ว (LogCompletion) รับซ้ำไม่ได้
--   loop  = ที่เหลือ รับใหม่ได้เรื่อย ๆ (ฆ่าม็อบ ส่งของ ตกปลา)
function QL.category(d)
	local q = d.raw or {}
	if q.Rewards and q.Rewards.Power then
		return "power"
	end
	if q.Category == "BossHunt" or (#d.tasks == 1 and d.tasks[1].name:find("^Defeat ")) then
		return "boss"
	end
	if q.LogCompletion then
		return "once"
	end
	return "loop"
end

-- สถานะของเควสสำหรับตัวเราตอนนี้: "ok" / "locked" / "done" + เหตุผลที่อ่านรู้เรื่อง
function QL.state(d, me)
	local q = d.raw or {}
	local req = q.Requirements or {}
	local status = Runner.questStatus(d)
	if status == "completed" then
		return "done", "ทำจบแล้ว"
	end
	if q.Rewards and q.Rewards.Power and me.breathing and tostring(q.Rewards.Power) == me.breathing then
		return "done", "มีปราณนี้อยู่แล้ว"
	end
	if req.Race then
		local okRace = false
		for _, r in pairs(req.Race) do
			okRace = okRace or r == me.race
		end
		if not okRace then
			local list = {}
			for _, r in pairs(req.Race) do
				list[#list + 1] = r
			end
			return "locked", "เฉพาะเผ่า " .. table.concat(list, "/") .. " (คุณเป็น " .. (me.race ~= "" and me.race or "?") .. ")"
		end
	end
	if req.Level and me.level and me.level < req.Level then
		return "locked", string.format("ต้อง Lv %d (ตอนนี้ %d)", req.Level, me.level)
	end
	if req.MaxLevel and me.level and me.level > req.MaxLevel then
		return "locked", string.format("เลเวลเกิน %d แล้ว", req.MaxLevel)
	end
	if status == "unsupported" then
		if q.Rewards and q.Rewards.Power then
			return "locked", "ทำผ่านหน้า Auto-Breathing"
		end
		return "locked", "สคริปต์ยังทำเควสนี้ให้ไม่ได้"
	end
	return "ok", nil
end

local QuestInfo = {}

-- รายละเอียดเควส: ต้องทำอะไร ได้อะไร ต้องจ่ายอะไรตอนรับ เงื่อนไข และทำได้กี่รอบ
-- สร้างตอนกด ข้อมูล ครั้งแรก (83 เควส สร้างล่วงหน้าหมดเปลือง instance เป็นพัน)
-- ค่าที่ขึ้นกับตัวเรา (เงิน ของ เลเวล) อ่านใหม่ทุกครั้งที่เปิด
function QuestInfo.fill(box, d)
	box.clear()
	local q = d.raw or {}
	local wallet = Game.wallet()

	local todo = {}
	for _, t in ipairs(d.tasks) do
		todo[#todo + 1] = { t.max > 1 and (t.name .. "  ×" .. t.max) or t.name }
	end
	if #todo == 0 then
		todo[1] = { "คุยกับ " .. d.npc }
	end
	box.section("ต้องทำ", todo)

	local rewards = q.Rewards or {}
	local gain = {}
	if rewards.Exp then
		gain[#gain + 1] = { "+" .. comma(rewards.Exp) .. " EXP", Theme.Accent }
	end
	if rewards.Wen then
		gain[#gain + 1] = { "+" .. comma(rewards.Wen) .. " Wen", Theme.Warn }
	end
	if rewards.Power then
		gain[#gain + 1] = { "ปราณ " .. tostring(rewards.Power), Theme.Accent2 }
	end
	local items = {}
	for name, v in pairs(rewards) do
		if name ~= "Exp" and name ~= "Wen" and name ~= "Power" then
			local n = type(v) == "table" and (v.Quantity or 1) or tonumber(v) or 1
			items[#items + 1] = { name .. "  ×" .. n, Theme.Good }
		end
	end
	table.sort(items, function(a, b)
		return a[1] < b[1]
	end)
	for _, c in ipairs(items) do
		gain[#gain + 1] = c
	end
	box.section("ได้รับ", gain)

	local cost = {}
	if q.WenCostOnAccept then
		cost[#cost + 1] = Detail.have("Wen", wallet.Wen or 0, q.WenCostOnAccept)
	end
	for name, n in pairs(q.ItemCostOnAccept or {}) do
		cost[#cost + 1] = Detail.have(name, wallet[name] or 0, n)
	end
	box.section("ต้องจ่ายตอนรับเควส", cost)

	local req = q.Requirements or {}
	local lvl = Game.level()
	local cond = {}
	if req.Level then
		cond[#cond + 1] = { "Lv " .. req.Level .. " ขึ้นไป", (not lvl or lvl >= req.Level) and Theme.Good or Theme.Danger }
	end
	if req.MaxLevel then
		cond[#cond + 1] = { "ไม่เกิน Lv " .. req.MaxLevel, (not lvl or lvl <= req.MaxLevel) and Theme.Good or Theme.Danger }
	end
	if d.race then
		cond[#cond + 1] = { "เผ่า " .. d.race }
	end
	box.section("เงื่อนไข", cond)

	-- LogCompletion = เกมจดว่าจบแล้ว (Completed) รับซ้ำไม่ได้ ที่เหลือ (ฆ่าม็อบ / Boss Hunts) รับใหม่ได้เรื่อย ๆ
	-- เกมให้ถือได้ทีละเควส และพักระหว่างเควสตาม QuestCD
	local times = {}
	if q.LogCompletion then
		times[#times + 1] = { "ทำได้ครั้งเดียว" }
	elseif rewards.Power then
		times[#times + 1] = { "ทำจนได้ปราณ (ทำครั้งเดียวพอ)" }
	else
		times[#times + 1] = { "ทำซ้ำได้ไม่จำกัด", Theme.Good }
	end
	times[#times + 1] = { "พักระหว่างเควส " .. Runner.questCD() .. " วิ", Theme.Muted }
	if q.Timer then
		times[#times + 1] = { "จำกัดเวลา " .. math.floor(q.Timer / 60) .. " นาที", Theme.Warn }
	end
	local status = Runner.questStatus(d)
	if status == "completed" then
		times[#times + 1] = { "จบไปแล้ว", Theme.Good }
	elseif status == "unsupported" and rewards.Power then
		-- เควสปราณมีมินิเกมฝึก ตัวรันของ Auto-Quest ไม่รู้จัก แต่แผง Auto-Breathing ทำให้ได้
		times[#times + 1] = { "ทำผ่านหน้า Auto-Breathing แทน", Theme.Warn }
	elseif status == "unsupported" then
		times[#times + 1] = { "สคริปต์ยังทำเควสนี้ให้ไม่ได้", Theme.Danger }
	end
	box.section("ทำได้กี่รอบ", times)

	if type(q.Hint) == "string" then
		box.note("คำใบ้จากเกม", q.Hint)
	end
end

-- รายการเควส ----------------------------------------------------------------------
-- ผู้ใช้บอกว่าแบบจัดกลุ่มตาม NPC ดูยากมาก อยากเห็นว่า "อันไหนทำได้ อันไหนคุ้ม อันไหนทำแล้ว"
-- เลยแบ่งเป็นแท็บตามชนิดเควส แล้วในแท็บแบ่งหัวข้อตามสถานะของตัวเรา
-- รางวัลโชว์บนแถวเลย ไม่ต้องกดดู ตัวเลขมาจาก Rewards ในโมดูลเควสของเกม (ไม่ใช่ค่าประมาณ)

QL.tabs = { "แนะนำ", "ทำซ้ำได้", "ครั้งเดียว", "บอส", "ปราณ/สไตล์", "ที่เลือก" }

function QL.reward(d)
	local r = d.raw and d.raw.Rewards or {}
	return r.Exp or 0, r.Wen or 0
end

-- ป้ายเล็กชิดขวาของแถว
function QL.tag(parent, text, color, order, bg)
	return new("TextLabel", {
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = bg or Theme.Raised,
		BackgroundTransparency = bg == false and 1 or 0,
		Text = text,
		TextColor3 = color,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.SemiBold),
		LayoutOrder = order,
		Parent = parent,
	}, { capsule(), new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }) })
end

-- แถวเควสหนึ่งแถว: ช่องติ๊ก ชื่องาน · NPC · โซน · รางวัล · เลเวล · ปุ่มข้อมูล
-- state ไม่ใช่ ok = ติ๊กไม่ได้ บรรทัดที่สามบอกเหตุผล (เลเวลไม่ถึง เผ่าไม่ตรง ทำแล้ว)
-- inCard = อยู่ใต้หัวการ์ด NPC แล้ว ไม่ต้องเขียนชื่อ NPC · โซนซ้ำทุกแถว แถวเตี้ยลง
function QL.item(parent, d, order, state, reason, inCard)
	local ok = state == "ok"
	local wrap = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Row,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	}, { corner(8), stroke(), new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })

	local prereq = Runner.Prereqs[d.key]
	local note = reason
	if ok and prereq then
		-- เงื่อนไขที่ Auto-Quest ทำให้ไม่ได้ (มี hint แทนเควส เช่นเบ็ดของ Shiori) เขียนแยกให้ผู้ใช้รู้ว่าต้องหาเอง
		-- เดิมขึ้นเป็น "?" ต่อท้ายรายการ ดูไม่ออกว่าขาดอะไร
		local names, needs = {}, {}
		for _, c in ipairs(prereq) do
			if c.quest or c.via then
				names[#names + 1] = c.quest or c.via
			else
				needs[#needs + 1] = "ต้อง" .. c.hint
			end
		end
		local parts = {}
		if #names > 0 then
			parts[1] = "จะทำให้ก่อน: " .. table.concat(names, ", ")
		end
		table.move(needs, 1, #needs, #parts + 1, parts)
		note = table.concat(parts, " · ")
	end

	local item = new("TextButton", {
		Size = UDim2.new(1, 0, 0, inCard and (note and 46 or 32) or (note and 60 or 46)),
		BackgroundColor3 = Theme.On,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = 1,
		Parent = wrap,
	}, { corner(8) })
	local tickFill, tickStroke = tickBox(item)
	if not ok then
		tickStroke.Color = Theme.Stroke
		tickStroke.Transparency = 0.5
	end

	new("TextLabel", {
		Position = UDim2.fromOffset(40, inCard and 8 or 6),
		Size = UDim2.new(1, -330, 0, 17),
		BackgroundTransparency = 1,
		Text = d.title,
		TextColor3 = ok and Theme.Text or Theme.Muted,
		TextSize = 15,
		FontFace = font(Enum.FontWeight.SemiBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = item,
	})
	if not inCard then
		new("TextLabel", {
			Position = UDim2.fromOffset(40, 24),
			Size = UDim2.new(1, -330, 0, 14),
			BackgroundTransparency = 1,
			Text = d.npc .. "  ·  " .. d.region,
			TextColor3 = Theme.Dim,
			TextSize = 13,
			FontFace = font(Enum.FontWeight.Regular),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = item,
		})
	end
	if note then
		new("TextLabel", {
			Position = UDim2.fromOffset(40, inCard and 26 or 40),
			Size = UDim2.new(1, -52, 0, 14),
			BackgroundTransparency = 1,
			Text = (state == "done" and "✓ " or (ok and "› " or "🔒 ")) .. note,
			TextColor3 = state == "done" and Theme.Good or (ok and Theme.Muted or Theme.Warn),
			TextSize = 13,
			FontFace = font(Enum.FontWeight.Medium),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = item,
		})
	end

	-- รางวัล + เลเวล + ปุ่มข้อมูล ชิดขวาแถวบน
	local tags = new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, inCard and 6 or 12),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = item,
	}, { new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) })
	local exp, wen = QL.reward(d)
	local power = d.raw and d.raw.Rewards and d.raw.Rewards.Power
	if type(power) == "string" then
		QL.tag(tags, power, Theme.Accent2, 1)
	end
	if exp > 0 then
		QL.tag(tags, "+" .. comma(exp) .. " EXP", Theme.Accent, 2)
	end
	if wen > 0 then
		QL.tag(tags, "+" .. comma(wen) .. " Wen", Theme.Warn, 3)
	end
	QL.tag(tags, levelText(d), Theme.Muted, 4, false)
	local infoBtn = new("TextButton", {
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Raised,
		AutoButtonColor = false,
		Text = "ข้อมูล +",
		TextColor3 = Theme.Muted,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.Medium),
		LayoutOrder = 5,
		ZIndex = 2,
		Parent = tags,
	}, {
		capsule(),
		stroke(),
		new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }),
	})

	local detail
	local function toggleInfo()
		if not detail then
			detail = Detail.box(wrap, 2)
		end
		local open = not detail.frame.Visible
		if open then
			QuestInfo.fill(detail, d)
		end
		detail.frame.Visible = open
		infoBtn.Text = open and "ข้อมูล –" or "ข้อมูล +"
		infoBtn.TextColor3 = open and Theme.Accent or Theme.Muted
	end
	track(infoBtn.MouseButton1Click:Connect(toggleInfo))

	local function paint()
		local on = QL.picks[d.key] == true
		tween(tickFill, { BackgroundTransparency = on and 0 or 1 }, FAST)
		if ok then
			tickStroke.Color = on and Theme.On or Theme.Muted
		end
		-- ขอบแบบเกมเป็นขาวโปร่ง 0.85 อยู่แล้ว ตอนเลือกแค่ทำให้ทึบ (เปลี่ยนแค่สีจะมองไม่เห็นเพราะยังโปร่งอยู่)
		wrap:FindFirstChildOfClass("UIStroke").Transparency = on and 0 or 0.85
		tween(item, { BackgroundTransparency = on and 0.9 or 1 }, FAST)
	end
	paint()

	track(item.MouseButton1Click:Connect(function()
		-- ทำไม่ได้ติ๊กไม่ได้ กดแล้วเปิดข้อมูลแทน จะได้เห็นว่าติดอะไร
		if not ok then
			toggleInfo()
			return
		end
		-- เปลี่ยนตัวเลือกระหว่างที่กำลังรันไม่ได้ Runner ถือรายการของรอบนี้อยู่
		if Runner.active then
			return
		end
		QL.picks[d.key] = not QL.picks[d.key] or nil
		paint()
		questsChanged()
	end))

	local row = {
		frame = wrap,
		data = d,
		ok = ok,
		paint = paint,
		haystack = table.concat({ d.title, d.quest, d.npc, d.region }, " "):lower(),
	}
	questRows[#questRows + 1] = row
	return row
end

-- เควสของ NPC เดียวกันต้องอยู่ติดกันในการ์ดเดียว ผู้ใช้ขอ: Wagwan ให้ทั้ง Defeat Hoyuzo (หมวดบอส)
-- กับงานเคลียร์ลูกน้อง (หมวดทำซ้ำ) แบบเดิมสองเควสนี้อยู่คนละแท็บ ดูไม่ออกว่ามาจากคนเดียวกัน
-- เลยดึงเควสพี่น้องที่สถานะเดียวกันจากทุกหมวดมาไว้ในการ์ดด้วย (QL.groupCtx.all = เควสทั้งเกม)
-- NPC หนึ่งตัวขึ้นการ์ดเดียวต่อสถานะต่อแท็บ ไม่งั้นแท็บ แนะนำ มี Wagwan ทั้งหัวข้อฟาร์มซ้ำและหัวข้อครั้งเดียว
-- (ติ๊กอันหนึ่งแล้วเห็นเควสเดียวกันซ้ำสองที่) แบบจัดกลุ่มตาม NPC ล้วนที่เคยทำ ผู้ใช้บอกดูยาก
-- เลยคงแท็บกับหัวข้อตามสถานะไว้ จัดกลุ่มแค่ในหัวข้อ
function QL.group(rows)
	local ctx = QL.groupCtx
	local groups, byKey = {}, {}
	local function add(g, e)
		if not g.seen[e.d.key] then
			g.seen[e.d.key] = true
			g.entries[#g.entries + 1] = e
		end
	end
	-- Boss Hunts / Evil Art Cores เป็น "NPC" รวมของเกม ไม่ใช่คนให้เควสจริง ลองดึงพี่น้องแล้ว
	-- หัวข้อ ปราณของคุณ ได้บอสล่ามาทั้ง 30 ตัวแทนที่จะเหลือแค่ Flame Trainee เควสปราณกับบอสล่าไม่ดึง
	local function hasSiblings(e)
		return e.cat ~= "power" and not (e.d.raw and e.d.raw.Category == "BossHunt")
	end
	for _, e in ipairs(rows) do
		local key = e.d.region .. "/" .. e.d.npc
		local g = byKey[key]
		if not g and not (ctx and ctx.used[key .. "/" .. e.state]) then
			g = { npc = e.d.npc, region = e.d.region, entries = {}, seen = {} }
			byKey[key] = g
			groups[#groups + 1] = g
			if ctx and hasSiblings(e) then
				ctx.used[key .. "/" .. e.state] = true
				for _, s in ipairs(ctx.all) do
					if s.state == e.state and hasSiblings(s) and s.d.region .. "/" .. s.d.npc == key then
						add(g, s)
					end
				end
			end
		end
		if g then
			add(g, e)
		end
	end
	-- ลำดับเดียวกับที่ Runner ทำ (pickedQuests): เลเวลสูงก่อน บอสมาก่อนงานลูกน้อง
	for _, g in ipairs(groups) do
		table.sort(g.entries, function(a, b)
			local la, lb = a.d.level or 0, b.d.level or 0
			if la ~= lb then
				return la > lb
			end
			return QL.reward(a.d) > QL.reward(b.d)
		end)
	end
	return groups
end

-- การ์ด NPC: หัว = ชื่อ · โซน · จำนวนเควส + ปุ่มเลือกทั้งหมด ใต้หัวคือเควสทีละแถว
function QL.card(parent, g, order)
	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Row,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	}, {
		corner(10),
		stroke(),
		new("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local head = new("Frame", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Parent = card,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -120, 1, 0),
		BackgroundTransparency = 1,
		RichText = true,
		Text = string.format('%s  <font color="#969696">·  %s  ·  %d เควส</font>', g.npc, g.region, #g.entries),
		TextColor3 = Theme.Text,
		TextSize = 15,
		FontFace = font(Enum.FontWeight.Bold),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = head,
	})

	local rows = {}
	for i, e in ipairs(g.entries) do
		local row = QL.item(card, e.d, i, e.state, e.reason, true)
		row.card = card
		rows[#rows + 1] = row
	end

	local pickable = {}
	for _, r in ipairs(rows) do
		if r.ok then
			pickable[#pickable + 1] = r
		end
	end
	if #pickable < 2 then
		return card
	end
	-- ติ๊กทีละแถวยังได้เหมือนเดิม ปุ่มนี้ไว้เลือกเควสทั้งหมดของ NPC คนนี้ในคลิกเดียว (ติ๊กครบแล้วกด = เอาออกทั้งหมด)
	local allBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, 0),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Raised,
		AutoButtonColor = false,
		TextColor3 = Theme.Muted,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.Medium),
		Parent = head,
	}, {
		capsule(),
		stroke(),
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
	local function allPicked()
		for _, r in ipairs(pickable) do
			if not QL.picks[r.data.key] then
				return false
			end
		end
		return true
	end
	local function paintAll()
		allBtn.Text = allPicked() and "เอาออกทั้งหมด" or ("เลือกทั้ง " .. #pickable .. " เควส")
	end
	paintAll()
	track(allBtn.MouseButton1Click:Connect(function()
		if Runner.active then
			return
		end
		local on = not allPicked()
		for _, r in ipairs(pickable) do
			QL.picks[r.data.key] = on or nil
			r.paint()
		end
		paintAll()
		questsChanged()
	end))
	-- ติ๊กทีละแถวแล้วป้ายปุ่มต้องตาม defer ไว้ให้ handler ของแถวสลับ QL.picks ก่อน
	-- (ลำดับที่ connection ของสัญญาณเดียวกันถูกเรียกไม่แน่นอน)
	for _, r in ipairs(pickable) do
		track(r.frame:FindFirstChildOfClass("TextButton").MouseButton1Click:Connect(function()
			task.defer(paintAll)
		end))
	end
	return card
end

-- หัวข้อในแท็บ: ชื่อ + จำนวน กดพับ/กางได้ หัวข้อ "ทำแล้ว" พับไว้ตั้งแต่แรก
function QL.section(title, hint, color, rows, order, collapsed)
	local groups = QL.group(rows)
	local count = 0
	for _, g in ipairs(groups) do
		count += #g.entries
	end
	local box = new("Frame", {
		Size = UDim2.new(1, -6, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = questUI.list,
	}, { new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local head = new("TextButton", {
		Size = UDim2.new(1, 0, 0, hint and 36 or 24),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = 0,
		Parent = box,
	})
	local titleLabel = new("TextLabel", {
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 0, 18),
		BackgroundTransparency = 1,
		TextColor3 = color,
		TextSize = 15,
		FontFace = font(Enum.FontWeight.Bold),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = head,
	})
	if hint then
		new("TextLabel", {
			Position = UDim2.fromOffset(2, 20),
			Size = UDim2.new(1, -4, 0, 14),
			BackgroundTransparency = 1,
			Text = hint,
			TextColor3 = Theme.Dim,
			TextSize = 13,
			FontFace = font(Enum.FontWeight.Regular),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = head,
		})
	end
	local body = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Visible = not collapsed,
		Parent = box,
	}, { new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local function paintTitle()
		-- ▾ ▸ ↳ ไม่มีในฟอนต์ Gotham ขึ้นเป็นกล่องสี่เหลี่ยม ใช้ – + › ที่แสดงได้แทน
		titleLabel.Text = string.format("%s %s  ·  %d", body.Visible and "–" or "+", title, count)
	end
	paintTitle()
	track(head.MouseButton1Click:Connect(function()
		body.Visible = not body.Visible
		paintTitle()
	end))
	if count == 0 then
		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Text = "ไม่มี",
			TextColor3 = Theme.Dim,
			TextSize = 13,
			FontFace = font(Enum.FontWeight.Regular),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = body,
		}, { new("UIPadding", { PaddingLeft = UDim.new(0, 18) }) })
	end
	for i, g in ipairs(groups) do
		QL.card(body, g, i)
	end
	return box
end

-- ล้างที่ติ๊กทั้งหมด (ปุ่ม ล้าง ท้ายแผง)
local rebuildQuests
local function clearQuestPicks()
	if Runner.active then
		return
	end
	table.clear(QL.picks)
	questsChanged()
	rebuildQuests()
end

function applyQuestFilter()
	local query = questUI.search.Text:lower()
	local shown = 0
	local cardShown = {}
	for _, r in ipairs(questRows) do
		local visible = query == "" or r.haystack:find(query, 1, true) ~= nil
		r.frame.Visible = visible
		if visible then
			shown += 1
		end
		if r.card then
			cardShown[r.card] = cardShown[r.card] or visible
		end
	end
	-- การ์ดที่ค้นแล้วไม่เหลือแถวไหนเลย ซ่อนทั้งใบ ไม่งั้นเหลือหัวการ์ดลอยเปล่า ๆ
	for card, visible in pairs(cardShown) do
		card.Visible = visible
	end
	if not questSelected then
		questUI.setStatus(string.format("แท็บ %s · แสดง %d เควส · กดที่เควสเพื่อติ๊ก เลือกได้หลายอัน", QL.tab, shown),
			Theme.Muted)
	end
end

-- จัดเควสทั้งเกมเข้าแท็บที่เลือก แล้วสร้างหัวข้อตามสถานะ
function rebuildQuests()
	for _, c in ipairs(questUI.list:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	table.clear(questRows)

	local me = QL.player()
	local buckets = { ok = {}, locked = {}, done = {} }
	local all = {}
	for _, d in ipairs(Game.quests()) do
		local state, reason = QL.state(d, me)
		local e = { d = d, state = state, reason = reason, cat = QL.category(d) }
		all[#all + 1] = e
	end
	-- แท็บ ที่เลือก ไม่ดึงเควสพี่น้องที่ไม่ได้ติ๊กมาปน
	QL.groupCtx = QL.tab ~= "ที่เลือก" and { all = all, used = {} } or nil
	local function byExp(a, b)
		local ea, eb = QL.reward(a.d), QL.reward(b.d)
		if ea ~= eb then
			return ea > eb
		end
		return a.d.sortLevel < b.d.sortLevel
	end
	local function pick(filter)
		local out = { ok = {}, locked = {}, done = {} }
		for _, e in ipairs(all) do
			if filter(e) then
				table.insert(out[e.state], e)
			end
		end
		table.sort(out.ok, byExp)
		return out
	end
	local lv = me.level and ("Lv " .. me.level) or "เลเวลของคุณ"

	if QL.tab == "แนะนำ" then
		-- ทำได้ตอนนี้ เรียง EXP ต่อรอบมากไปน้อย: ทำซ้ำได้ (ฟาร์มยาว) กับครั้งเดียว (EXP ก้อน) แยกกัน
		local loop = pick(function(e)
			return e.cat == "loop" or (e.cat == "boss" and not (e.d.raw and e.d.raw.Category == "BossHunt"))
		end)
		local once = pick(function(e)
			return e.cat == "once"
		end)
		local top = {}
		for i = 1, math.min(8, #loop.ok) do
			top[i] = loop.ok[i]
		end
		QL.section("ฟาร์มซ้ำ คุ้มสุดสำหรับ " .. lv, "เรียงตาม EXP ต่อรอบ มากไปน้อย · ทำซ้ำได้เรื่อย ๆ", Theme.Good, top, 1)
		QL.section("ครั้งเดียว ยังไม่ได้ทำ", "EXP ก้อนใหญ่ ทำจบแล้วรับซ้ำไม่ได้", Theme.Accent, once.ok, 2)
	elseif QL.tab == "ทำซ้ำได้" then
		local b = pick(function(e)
			return e.cat == "loop"
		end)
		QL.section("ทำได้ตอนนี้", "ทำซ้ำได้ไม่จำกัด พักระหว่างเควส " .. Runner.questCD() .. " วิ · เรียง EXP มากไปน้อย",
			Theme.Good, b.ok, 1)
		QL.section("ยังทำไม่ได้", "เลเวลไม่ถึง / เผ่าไม่ตรง / สคริปต์ยังไม่รองรับ", Theme.Warn, b.locked, 2)
	elseif QL.tab == "ครั้งเดียว" then
		local b = pick(function(e)
			return e.cat == "once"
		end)
		QL.section("ยังไม่ได้ทำ", "ทำได้รอบเดียว เกมจดว่าจบแล้ว", Theme.Good, b.ok, 1)
		QL.section("ยังทำไม่ได้", nil, Theme.Warn, b.locked, 2)
		QL.section("ทำแล้ว", nil, Theme.Dim, b.done, 3, true)
	elseif QL.tab == "บอส" then
		local npc = pick(function(e)
			return e.cat == "boss" and not (e.d.raw and e.d.raw.Category == "BossHunt")
		end)
		local hunts = pick(function(e)
			return e.d.raw and e.d.raw.Category == "BossHunt"
		end)
		QL.section("บอสจาก NPC", "รับจาก NPC แล้วไปล้มบอส ทำซ้ำได้", Theme.Good, npc.ok, 1)
		QL.section("บอสจาก NPC · ยังทำไม่ได้", nil, Theme.Warn, npc.locked, 2)
		QL.section("Boss Hunts (ทำได้)", "ล่าบอสจำกัดเวลา 30 นาที · เกมส่งให้ตามเผ่า Slayer/Demon/Hybrid",
			Theme.Good, hunts.ok, 3)
		QL.section("Boss Hunts · ยังทำไม่ได้", nil, Theme.Warn, hunts.locked, 4, true)
	elseif QL.tab == "ปราณ/สไตล์" then
		-- ปราณที่ใช้อยู่ขึ้นก่อน: เควสเรียนปราณนั้น + Boss Hunt ของ Trainee ปราณเดียวกัน
		local mine = me.breathing and me.breathing:lower()
		local function isMine(e)
			if not mine then
				return false
			end
			local power = e.d.raw and e.d.raw.Rewards and e.d.raw.Rewards.Power
			return (type(power) == "string" and power:lower() == mine)
				or (e.d.raw and e.d.raw.Category == "BossHunt" and e.d.title:lower():find(mine, 1, true) ~= nil)
		end
		local own = {}
		for _, e in ipairs(all) do
			if isMine(e) then
				own[#own + 1] = e
			end
		end
		local rest = pick(function(e)
			return e.cat == "power" and not isMine(e)
		end)
		QL.section("ปราณของคุณ: " .. (me.breathing or "ยังไม่มี"),
			"เรียนปราณผ่านหน้า Auto-Breathing (มีมินิเกมฝึก) · Boss Hunt ของ Trainee ปราณเดียวกัน", Theme.Accent2, own, 1)
		local others = {}
		for _, e in ipairs(rest.ok) do
			others[#others + 1] = e
		end
		for _, e in ipairs(rest.locked) do
			others[#others + 1] = e
		end
		QL.section("ปราณ / Evil Art / สไตล์หมัด อื่น ๆ", nil, Theme.Muted, others, 2)
		QL.section("ได้แล้ว", nil, Theme.Dim, rest.done, 3, true)
	else
		local sel = {}
		for _, d in ipairs(pickedQuests()) do
			local state, reason = QL.state(d, me)
			sel[#sel + 1] = { d = d, state = state, reason = reason }
		end
		QL.section("ที่เลือกไว้ (ลำดับที่จะทำ)", "กด START ทำตามลำดับนี้ วนซ้ำเควสที่ทำซ้ำได้", Theme.Accent, sel, 1)
	end

	questUI.subtitle.Text = string.format(
		'<font color="#8f8f9e">เลเวล</font> %s   <font color="#8f8f9e">เผ่า</font> %s   <font color="#8f8f9e">ปราณ</font> %s   <font color="#8f8f9e">เควส</font> %d',
		me.level and tostring(me.level) or "?",
		me.race ~= "" and me.race or "?",
		me.breathing or "-",
		#Game.quests()
	)
	applyQuestFilter()
end

addPills(questUI.filterRow, QL.tabs, function(name)
	QL.tab = name
	rebuildQuests()
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
			steps[#steps + 1] = {
				pickup = t.name,
				anchor = t.anchor,
				sweepAt = t.sweepAt,
				max = t.max,
				quest = data.key,
				positions = t.positions,
			}
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

-- ป้ายสถานะในแผง Auto-Quest (แผงสร้างก่อน questPlan / questProgress เลยอ่านผ่านตรงนี้)
-- วินาทีที่เกมบังคับพักระหว่างจบเควสกับรับเควสถัดไป (QuestRules.QuestCD)
function Runner.questCD()
	return QuestRules.QuestCD or 30
end

function Runner.questStatus(d)
	if questProgress(d.key) == "completed" then
		return "completed"
	end
	if not questPlan(d) then
		return "unsupported"
	end
	return nil
end

-- จุดแจ้งเหตุการณ์ให้ Webhook (ล็อกเป้าม็อบ / เก็บของ / จบเควส) ตัวจริงผูกทีหลังในแท็บ Settings
-- ต้องมีตัวว่างไว้ก่อน Auto-Chest เปิดตั้งแต่โหลดไฟล์ เก็บของได้ก่อนแท็บ Settings ถูกสร้าง
function Runner.hook() end
-- ค่าที่ Runner.hunt คืนเมื่อยกเลิกเควสบอสเพราะบอสตาย ไม่ใช่ความผิดพลาด ไม่ต้องตัดเควสออก
Runner.BOSS_GONE = "boss-gone"

-- Auto-Breathing ใช้ตัวรันชุดเดียวกัน (คุยกับ NPC / ฆ่าม็อบ / เก็บของ) แต่มีแผงของตัวเอง
-- ตอนมันรันจะตั้ง Runner.statusSink ให้ข้อความไปขึ้นแผงนั้นแทนแผง Auto-Quest
-- identity ของ thread หล่นเป็น 2 กลางทางได้ (hook มินิเกมตกปลา/Auto Skill ตั้ง 2 ให้ thread ลูกแล้วรั่วมา)
-- แล้วเขียนป้ายใน gethui พัง "lacking capability Plugin" เจอจริงตอนซื้อเหยื่อก่อนตกปลาในคิว Get Materials
-- ทุกงานรายงานผ่านตรงนี้ คืน identity ตอนโหลดไฟล์ก่อนแตะ GUI จุดเดียวครอบทุกตัวรัน
local function report(text, color)
	if setthreadidentity and Game.loadIdentity then
		setthreadidentity(Game.loadIdentity)
	end
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

	-- หน้าคุยของ NPC ก่อนหน้าอาจยังค้าง: Shiori ปิดคุยแล้วเปิดบทข่าวลือ (Shiori_Rumour: What happened to her? / Close)
	-- ต่อทันทีทุกครั้งจนกว่าจะเปิดเบาะแส War Fans ถ้าไม่ปิดก่อน walkDialogue อ่านตัวเลือกจากหน้าต่างเก่าแล้วฟ้อง "ไม่มีตัวเลือก"
	local stale = dialogueActual()
	if stale then
		for _, o in ipairs(dialogueOptions(stale)) do
			if o.text:lower():find("close", 1, true) then
				clickGui(o.button)
			end
		end
		local closeBy = os.clock() + 3
		while dialogueActual() and os.clock() < closeBy do
			task.wait(0.2)
		end
	end

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
	-- Shiori เสนอเควสปลา (The Full Pantry) หลังจบเควสยาเท่านั้น และต้องมีเบ็ด Rare/Legendary ในกระเป๋า
	-- (BeforeRun: infirmary Done + holdsRod ไม่งั้นขึ้นบท Shiori_FoodNoRod ที่ไม่มีปุ่มรับเควส)
	-- ยังไม่จบเควสยา Shiori เสนอแต่ "Ill restock the infirmary(Lv 70)" Auto-Quest เคยหยุดที่ "ไม่มีตัวเลือก"
	-- เบ็ด Rare ขายที่ Fisherman Jeso 10,000 Wen + Golden Fish 5 ตัว (Shop.itemsforsale) ร้านเปิดหลังจบเควสใบอนุญาต
	-- Legendary ไม่มีขาย ยังไม่ให้ซื้อเอง: ใช้เงินผู้เล่นก้อนใหญ่ และต้องตก Golden Fish ก่อนซึ่งยังไม่ได้ลอง
	["Ill stock the reserves(Lv 75)"] = {
		{ quest = "Ill restock the infirmary(Lv 70)" },
		{ item = { "Rare Fishing Rod", "Legendary Fishing Rod" }, hint = "มี Rare Fishing Rod (Jeso: 10,000 Wen + Golden Fish 5)" },
	},
}

function Runner.prereqMet(cond)
	if cond.quest then
		return questProgress(cond.quest) == "completed"
	end
	local wallet = Game.wallet()
	for _, item in ipairs(type(cond.item) == "table" and cond.item or { cond.item }) do
		if (wallet[item] or 0) > 0 then
			return true
		end
	end
	return false
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

	-- เปิด Kill Aura / Auto Skill / Parry ให้ตอนกด START แล้วคืนสถานะเดิมตอนจบ ผู้ใช้เปิดไว้เองก็ไม่ไปปิดให้
	-- Auto Skill กดเฉพาะช่วงพักหลังหมัดปิด (comboPause) ไม่กินเวลาตี · Parry ตอนนอนใต้ม็อบ = มุดหลบคอมโบบอส
	local helpers = {}
	for _, h in ipairs({
		{ on = Runner.auraOn, set = Runner.setAura },
		{ on = Runner.skillOn, set = Runner.setSkill },
		{ on = Runner.parryRow and Runner.parryRow.isOn, set = Runner.parryRow and Runner.parryRow.set },
	}) do
		if h.on and h.set and not h.on() then
			h.set(true)
			helpers[#helpers + 1] = h
		end
	end

	local function finish(text, color)
		report(text, color)
		for _, h in ipairs(helpers) do
			h.set(false)
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
				q.notOffered = d.title .. ": ต้อง" .. (c.hint or ("ทำ " .. tostring(c.quest or c.via))) .. " ก่อน"
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
	TextSize = 15,
	FontFace = font(Enum.FontWeight.SemiBold),
})

local startBtn = new("TextButton", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, -84, 0, 34),
	BackgroundColor3 = Theme.Raised,
	AutoButtonColor = false,
	Text = "",
	Parent = questUI.panel,
}, { capsule(), startLabel })

-- ติ๊กได้หลายเควสแล้ว ต้องมีทางเอาออกทีเดียว ไม่ต้องไล่กดทีละแถว
do
	local clearBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(76, 34),
		BackgroundColor3 = Theme.Raised,
		AutoButtonColor = false,
		Text = "ล้าง",
		TextColor3 = Theme.Muted,
		TextSize = 15,
		FontFace = font(Enum.FontWeight.SemiBold),
		Parent = questUI.panel,
	}, { capsule(), stroke() })
	track(clearBtn.MouseButton1Click:Connect(clearQuestPicks))
end

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
		-- หลายเควสชื่อยาวต่อกันล้นปุ่ม บอกจำนวนแทน รายชื่อเต็มอยู่ในบรรทัดสถานะเหนือปุ่ม
		startLabel.Text = #questSelected > 1 and ("START  ·  " .. #questSelected .. " เควส") or ("START  ·  " .. names)
	end

	local ready = #runnable > 0 and (resumable or (not held and cd <= 0))
	tween(startBtn, { BackgroundColor3 = ready and Theme.On or Theme.Raised }, FAST)
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

-- ม็อบมาจากสองที่:
-- 1) Ouwland.Content.<โซน>.ActiveNpcs = ม็อบประจำที่ มีจุดเกิด บางโซนซ้อนโฟลเดอร์ย่อยอีกชั้น
--    (Dreamfall Hollow, Seasons Crossing, Veilfall Cavern, The White Terror Lair) เดิมอ่านแค่ชั้นแรก
--    เลยหาย 5 ตัว (Blood Hounded Demon, Mizunoto, Greater/Lesser Demon, Mizunoe) รวมจริง 50 ไม่ใช่ 45
-- 2) LiveConfig NpcDataTable (82 รายการ) = ม็อบที่ระบบอื่นเสกขึ้น (อีเวนต์ Cache/Raid, Yeti, Final Selection)
--    ไม่มีใน ActiveNpcs เลยไม่มีจุดเกิด Auto-Attack ต้องรอให้มันโผล่เอง
-- ค่าเลือดเอาจาก NpcDataTable.Stats.MaxHealth ตรง ๆ ทุกตัว (ตรงกับที่วัดในเกม Bandit 45 / Zuko 300)
-- เดิมรอให้ม็อบ stream เข้ามาก่อนถึงรู้ค่า ทั้งแมพเลยเห็นค่าเลือดแค่ 9 จาก 45
local MobTier = {
	-- tierOf ใช้เส้น HP นี้แค่ตอนแจ้งบอสเข้า Discord (ตัวที่อยู่ตรงหน้า) รายชื่อในแผงใช้ Rarity ของเกมแทน
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

-- Rarity ใน NpcDataTable คือการแบ่งของเกมเอง: 6 = บอสโลก (3000 HP), 5 = Trainee/Zuko/Mother Bear
-- (มีแถบบอส SendOver.Boss เหมือนกันแต่เลือด 300-1530), 1-4 = ม็อบฝูง
-- แบ่งด้วย HP แบบเดิมจัด Beast Born Demon (185, ม็อบฝูง 6 ตัว) เป็น Miniboss ผิด
local function tierOfRarity(rarity)
	if not rarity then
		return nil
	elseif rarity >= 6 then
		return "Boss"
	elseif rarity == 5 then
		return "Mini"
	end
	return "Normal"
end

local mobDefCache
function Game.mobs()
	if not mobDefCache then
		mobDefCache = {}
		local npcData = lootTables().npc
		local seenCode, seenName = {}, {}
		local function add(def)
			local data = def.code and npcData[def.code]
			def.maxHealth = data and data.Stats and data.Stats.MaxHealth
			def.tier = tierOfRarity(data and data.Rarity)
			mobDefCache[#mobDefCache + 1] = def
			if def.code then
				seenCode[def.code] = true
			end
			seenName[def.name] = true
		end

		for _, region in ipairs(ReplicatedStorage.Ouwland.Content:GetChildren()) do
			local active = region:FindFirstChild("ActiveNpcs")
			for _, m in ipairs(active and active:GetDescendants() or {}) do
				if m:IsA("ModuleScript") then
					local def = require(m)
					local send = def.SendOver or {}
					local spawning = send.Spawning or {}
					add({
						key = m.Name,
						name = def.Name or m.Name,
						region = region.Name,
						area = m.Parent ~= active and m.Parent.Name or nil,
						quantity = def.Quantity,
						icon = def.Icon,
						-- ตัวที่เควสนับคือ Settings.NpcCode ไม่ใช่ชื่อโมเดล (Bandit = KaruVillageBandit)
						code = send.Settings and send.Settings.NpcCode,
						-- ม็อบ stream เข้ามาเฉพาะตอนอยู่ใกล้ ต้องรู้ว่าจะวาร์ปไปรอที่ไหนก่อน
						center = spawning.Center or (spawning.Locations and spawning.Locations[1]),
						-- วิที่ตัวตายแล้วเกิดใหม่ (Bandit 30, บอส 300) คิวใช้ตัดสินว่าจะไปทำชิ้นอื่นก่อนนานแค่ไหน
						respawn = spawning.SpawnTime,
					})
				end
			end
		end

		-- ข้ามชื่อซ้ำ: Mizunoto / Lesser Demon มีทั้งสองที่ (คนละรหัส) ส่วน Rogue Demon มีสามรหัสชื่อเดียวกัน
		-- ตัวเลือกในแผงผูกกับชื่อโมเดล แถวซ้ำชื่อกดแล้วได้เป้าเดียวกันอยู่ดี
		-- Region "Test" = ม็อบทดสอบของผู้สร้าง (Dummy, Scythe Boss ...) ไม่มีในเซิร์ฟจริง
		for code, data in pairs(npcData) do
			local name = type(data) == "table" and data.Name
			if name and data.Region ~= "Test" and not seenCode[code] and not seenName[name] then
				add({
					key = code,
					name = name,
					region = data.Region or "?",
					area = "อีเวนต์",
					icon = data.Icon,
					code = code,
				})
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
		-- ตัวที่ NpcDataTable ไม่มีรหัส (ยังไม่เคยเจอ) ใช้ค่าจากตัวที่อยู่ตรงหน้าแทน
		local maxHealth = def.maxHealth or (seen and seen.maxHealth)
		out[#out + 1] = {
			key = def.key,
			name = def.name,
			region = def.region,
			area = def.area,
			quantity = def.quantity,
			maxHealth = maxHealth,
			alive = seen and seen.alive or 0,
			health = seen and seen.health or 0,
			tier = def.tier or tierOf(maxHealth),
			code = def.code,
			center = def.center,
			respawn = def.respawn,
		}
	end

	-- อ่อนสุดขึ้นก่อน ตัวที่ไม่รู้ค่าเลือดดันไปท้ายสุด ไม่ใช่มาปนข้างบน
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
		r.tickStroke.Color = on and Theme.On or Theme.Muted
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
		Position = UDim2.new(0, 40, 0.5, 0),
		Size = UDim2.fromOffset(3, 20),
		BackgroundColor3 = tier and tier.color or Theme.Dim,
		BorderSizePixel = 0,
		Parent = frame,
	}, { corner(2) })

	new("TextLabel", {
		Position = UDim2.fromOffset(52, 5),
		Size = UDim2.new(1, -150, 0, 14),
		BackgroundTransparency = 1,
		Text = data.name,
		TextColor3 = tier and tier.color or Theme.Muted,
		TextSize = 14,
		FontFace = font(Enum.FontWeight.Medium),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})

	new("TextLabel", {
		Position = UDim2.fromOffset(52, 20),
		Size = UDim2.new(1, -150, 0, 13),
		BackgroundTransparency = 1,
		Text = data.region .. (data.area and ("  ·  " .. data.area) or "") .. (tier and ("  ·  " .. tier.label) or ""),
		TextColor3 = Theme.Dim,
		TextSize = 13,
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
		TextSize = 13,
		FontFace = font(Enum.FontWeight.Medium),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	})

	new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 20),
		Size = UDim2.fromOffset(110, 13),
		BackgroundTransparency = 1,
		-- เกมโหลดม็อบเฉพาะที่อยู่ใกล้ ตัวที่ไม่เห็นอาจเกิดอยู่ไกล ๆ ไม่ได้แปลว่ายังไม่เกิด
		Text = data.alive > 0 and ("อยู่ใกล้ " .. data.alive .. " ตัว") or "ไม่อยู่ใกล้",
		TextColor3 = Theme.Dim,
		TextSize = 13,
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
			or (d.area and d.area:lower():find(query, 1, true) ~= nil)
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
			r.tickStroke.Color = Theme.On
			r.frame.BackgroundColor3 = Theme.Raised
		end
	end

	-- ค่าเลือดรู้ครบทุกตัวแล้ว (NpcDataTable) ตัวเลขที่มีประโยชน์กว่าคือมีกี่ชนิดที่อยู่ใกล้พอให้ตีได้เลย
	local nearby = 0
	for _, d in ipairs(list) do
		if d.alive > 0 then
			nearby += 1
		end
	end
	mobUI.subtitle.Text = string.format(
		'<font color="#969696">ม็อบทั้งหมด</font> %d   <font color="#969696">อยู่ใกล้ตอนนี้</font> %d',
		#list,
		nearby
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

-- สองแถวเปิดแผงเดียวกันคนละโหมด ปิดเฉพาะตอนแผงยังเป็นโหมดของแถวนั้น
-- เปิด Materials ตอน Weapons เปิดอยู่: featureRow ปิด Weapons ก่อน (โหมดยังเป็น gear เลยซ่อน) แล้วค่อยเปิดโหมดใหม่
local function shopModeRow(name, desc, order, mode)
	return featureRow(name, desc, order, function()
		shopFilter.setMode(mode)
		-- อ่านเงินกับคลังใหม่ทุกครั้งที่เปิด ไม่งั้นซื้อของที่อื่นแล้วตัวเลขในแผงค้าง
		rebuildShop()
		shopUI.show()
	end, function()
		if shopFilter.mode == mode then
			shopUI.hide()
		end
	end)
end
local shopFeature = shopModeRow("Get Weapons", "หาอาวุธและของสวมใส่ทุกชิ้นในเกม ซื้อ ฟาร์ม หรือตีที่ช่างให้เอง", 1, "gear")
local materialFeature = shopModeRow("Get Materials", "วัตถุดิบ ยา แบบพิมพ์ ออร์บ ของตกปลา ของเควส", 1, "material")
shopUI.nightfallFeature = shopModeRow("Get Nightfall Schematic", "แบบพิมพ์เซ็ต Nightfall", 1, "nightfall")

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
	materialFeature.setOpen(false)
	shopUI.nightfallFeature.setOpen(false)
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
							rewardExp = q.Rewards.Exp,
							rewardWen = q.Rewards.Wen,
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
		TextSize = 15,
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
	}, { capsule(), startLabel })

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
			tween(startBtn, { BackgroundColor3 = ready and Theme.On or Theme.Raised }, FAST)
			tween(startLabel, { TextColor3 = ready and Theme.Base or Theme.Dim }, FAST)
		end
	end

	-- ของที่ฟาร์มให้ได้ บอกชื่อม็อบกับที่อยู่ให้คนอ่านรู้เรื่อง (รหัสใน Runner.FarmSources อ่านไม่ออก)
	local FarmWhere = {
		["Demon Horns"] = "Hoyuzo Subordinate ในถ้ำหลังน้ำตก Bamboo Grove",
		["Beast Core"] = "Beast Born Demon ที่ Mistfall Harbor",
	}

	-- รายละเอียดปราณที่เลือก: ต้องมีอะไร มีแล้วเท่าไร ของที่ขาดหาได้ยังไง ขั้นตอนฝึก และรางวัล
	local function fillBreathDetail(box, b)
		box.clear()
		local wallet = Game.wallet()
		local lvl = Game.level()

		local need = {}
		if b.level > 0 then
			need[#need + 1] = { "Lv " .. b.level .. " ขึ้นไป", (not lvl or lvl >= b.level) and Theme.Good or Theme.Danger }
		end
		need[#need + 1] = Detail.have("Wen", wallet.Wen or 0, b.wen)
		for _, it in ipairs(b.items) do
			need[#need + 1] = Detail.have(it.name, wallet[it.name] or 0, it.need)
		end
		local weaponOk = true
		if b.anyOf then
			weaponOk = false
			for _, name in ipairs(b.anyOf) do
				weaponOk = weaponOk or (wallet[name] or 0) > 0
			end
			need[#need + 1] = { "อาวุธ " .. table.concat(b.anyOf, " / "), weaponOk and Theme.Good or Theme.Danger }
		end
		box.section("ต้องมีก่อนรับเควส (มี/ต้องใช้)", need)

		-- ตัวรันฟาร์มของให้เฉพาะตอน Wen พอแล้ว (runBreathing) Wen กับอาวุธฟาร์มให้ไม่ได้
		local how = {}
		local wenShort = b.wen - (wallet.Wen or 0)
		if wenShort > 0 then
			how[#how + 1] = string.format("• Wen ขาด %s  สคริปต์ฟาร์ม Wen ให้ไม่ได้ ทำเควสหรือตีม็อบเก็บก่อน", comma(wenShort))
		end
		for _, it in ipairs(b.items) do
			local short = it.need - (wallet[it.name] or 0)
			if short > 0 then
				if FarmWhere[it.name] and Runner.FarmSources[it.name] then
					how[#how + 1] = string.format("• %s ขาด %d  กด START แล้วสคริปต์ไปฟาร์มให้เองจาก %s%s", it.name, short,
						FarmWhere[it.name], wenShort > 0 and " (หลังมี Wen พอ)" or "")
				else
					how[#how + 1] = string.format("• %s ขาด %d  ต้องหาเอง สคริปต์ยังไม่รู้แหล่งดรอป", it.name, short)
				end
			end
		end
		if not weaponOk then
			how[#how + 1] = "• ต้องมีอาวุธ " .. table.concat(b.anyOf, " หรือ ") .. " ในกระเป๋า"
		end
		if #how > 0 then
			box.note("ของที่ขาด หาได้ยังไง", table.concat(how, "\n"), Theme.Text)
		end

		local steps = {}
		for i, t in ipairs(b.tasks) do
			local bad = t.kind and unsupported[t.kind]
			steps[#steps + 1] = { i .. ". " .. t.name .. (t.max > 1 and ("  ×" .. t.max) or "") .. (bad and "  (ยังไม่รองรับ)" or ""),
				bad and Theme.Danger or Theme.Text }
		end
		box.section("ขั้นตอนฝึก (สคริปต์ทำให้ตามลำดับ)", steps)

		local gain = { { "ปราณ " .. b.power, Theme.Accent2 } }
		if b.rewardExp then
			gain[#gain + 1] = { "+" .. comma(b.rewardExp) .. " EXP", Theme.Accent }
		end
		if b.rewardWen then
			gain[#gain + 1] = { "+" .. comma(b.rewardWen) .. " Wen", Theme.Warn }
		end
		box.section("ได้รับ", gain)
	end

	local function paintRows()
		for _, r in ipairs(rows) do
			local on = r.data == selected
			tween(r.tickFill, { BackgroundTransparency = on and 0 or 1 }, FAST)
			r.tickStroke.Color = on and Theme.On or Theme.Muted
			r.frame:FindFirstChildOfClass("UIStroke").Transparency = on and 0 or 0.85
			local missing = missingFor(r.data)
			local note = supportNote(r.data)
			-- ขาดอย่างเดียวบอกชื่อเลย ขาดหลายอย่างบอกจำนวน รายการเต็มอยู่ในกล่องรายละเอียด
			local right
			if note then
				right = "ยังไม่รองรับ"
			elseif #missing == 0 then
				right = "✓ พร้อมรับเควส"
			elseif #missing == 1 then
				right = "ขาด " .. missing[1]
			else
				right = "ขาด " .. #missing .. " อย่าง · กดดู"
			end
			r.right.Text = right
			r.right.TextColor3 = note and Theme.Dim or (#missing == 0 and Theme.Good or Theme.Warn)
			local costs = { comma(r.data.wen) .. " Wen" }
			for _, it in ipairs(r.data.items) do
				costs[#costs + 1] = string.format("%s %d", it.name, it.need)
			end
			r.sub.Text = r.data.npc .. "  ·  " .. table.concat(costs, " · ")
			if on then
				fillBreathDetail(r.detail, r.data)
			end
			r.detail.frame.Visible = on
		end
	end

	local function rebuildBreathing()
		local current = currentBreathing()
		breathUI.subtitle.Text = current and ('<font color="#8f8f9e">ปราณตอนนี้</font> ' .. current)
			or '<font color="#8f8f9e">ยังไม่มีปราณ</font>'
		if #rows == 0 then
			for i, b in ipairs(loadBreathing()) do
				-- กล่องต่อปราณ: หัว (กดเลือก) + รายละเอียดที่กางออกตอนเลือก
				local box = new("Frame", {
					Size = UDim2.new(1, -6, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = Theme.Row,
					BorderSizePixel = 0,
					LayoutOrder = i,
					Parent = breathUI.list,
				}, { corner(9), stroke(), new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
				local frame = new("Frame", {
					Size = UDim2.new(1, 0, 0, 44),
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					Parent = box,
				})
				local detail = Detail.box(box, 2)
				local tickFill, tickStroke = tickBox(frame)
				new("TextLabel", {
					Position = UDim2.fromOffset(40, 5),
					Size = UDim2.new(1, -200, 0, 14),
					BackgroundTransparency = 1,
					Text = b.power .. " Breathing",
					TextColor3 = Theme.Text,
					TextSize = 14,
					FontFace = font(Enum.FontWeight.Medium),
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = frame,
				})
				local sub = new("TextLabel", {
					Position = UDim2.fromOffset(40, 20),
					Size = UDim2.new(1, -200, 0, 13),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Dim,
					TextSize = 13,
					FontFace = font(Enum.FontWeight.Regular),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = frame,
				})
				local right = new("TextLabel", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.fromOffset(170, 14),
					BackgroundTransparency = 1,
					TextSize = 13,
					FontFace = font(Enum.FontWeight.Medium),
					TextXAlignment = Enum.TextXAlignment.Right,
					Parent = frame,
				})
				local row = {
					frame = box,
					head = frame,
					detail = detail,
					tickFill = tickFill,
					tickStroke = tickStroke,
					sub = sub,
					right = right,
					data = b,
				}
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
					-- ขั้นตอนเต็มอยู่ในกล่องรายละเอียดแล้ว บรรทัดสถานะสรุปแค่ว่าพร้อมหรือขาดอะไร
					if selected then
						local missing = missingFor(b)
						if #missing == 0 then
							breathUI.setStatus(b.power .. " Breathing · ของครบ กด START ได้เลย", Theme.Good)
						else
							breathUI.setStatus(b.power .. " Breathing · ขาด " .. table.concat(missing, ", "), Theme.Warn)
						end
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

-- สวิตช์ -----------------------------------------------------------------------

-- สวิตช์ฟีเจอร์ทุกตัว (ไม่นับแถวตัวเลือกกับสวิตช์หน้า ตั้งค่า) ปุ่ม หยุดทั้งหมด ไล่ปิดจากรายการนี้
local toggles = {}

-- แถวมีสองแบบ: สวิตช์ เปิด/ปิด กับแถวตัวเลือก (opts.choices) เช่นช่องอาวุธ ปุ่มสกิล โหมด
-- ที่อยู่ของแถวมาจากตาราง Layout ตามชื่อ ยกเว้น opts.parent (หน้า ตั้งค่า วางเอง)
local function switchRow(name, desc, order, onChange, opts)
	opts = opts or {}
	local frame, titleLabel, descLabel = placeRow("switch", name, order, opts.parent)
	local where = not opts.parent and Layout.switch[name] or nil
	local help = where and where.help or desc

	local entry = { frame = frame, name = where and where.title or name }
	local on = false
	-- identity ของ thread ลูปฟีเจอร์หล่นเองกลางทาง (executor ตัวนี้ identity ของ thread ลูกที่ Auto Skill
	-- ตั้งเป็น 2 รั่วไปถึง thread อื่น) แล้ว setDesc เจอ "lacking capability Plugin" ลูปตายเงียบ
	-- Kill Aura ค้างป้าย "รอม็อบเข้าระยะ" ทั้งที่ม็อบอยู่ห่าง 2 stud จำ identity ตอนสร้างแถว (thread หลัก)
	-- แล้วตั้งคืนก่อนแตะ GUI ทุกครั้ง ลูปไหนเรียก setDesc ก็หายจากอาการนี้หมด
	local rowIdentity = getthreadidentity and getthreadidentity()
	local function fixIdentity()
		if rowIdentity and setthreadidentity then
			setthreadidentity(rowIdentity)
		end
	end

	local function fitLabels(rightWidth)
		for _, label in ipairs({ titleLabel, descLabel }) do
			local x = label.Position.X.Offset
			label.Size = UDim2.new(1, -(x + rightWidth), 0, label.Size.Y.Offset)
		end
	end

	-- ตอนปิดโชว์คำอธิบายว่าฟีเจอร์ทำอะไร ตอนเปิดโชว์สถานะสดที่ลูปส่งมาเป็นสีฟ้า
	-- ลูปทุกตัวเขียน "ปิดอยู่" ตอนจบ ใช้ข้อความนั้นเป็นสัญญาณกลับไปโชว์คำอธิบาย
	function entry.setDesc(text)
		fixIdentity()
		if opts.choices then
			descLabel.Text = text
			return
		end
		if text == "ปิดอยู่" then
			descLabel.Text = help
			descLabel.TextColor3 = Theme.Dim
		else
			descLabel.Text = text
			descLabel.TextColor3 = on and Theme.Accent or Theme.Dim
		end
	end

	function entry.setVisible(visible)
		frame.Visible = visible
	end

	if opts.choices then
		-- ปุ่มเลือกแบบ segmented กว้างตามคำ ใส่คำไทยได้ ("ได้ของ" / "ไม่ตี") ไม่ต้องใช้รหัส 1/2 แล้วอ่านคำอธิบายเอา
		local seg = new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.Raised,
			BorderSizePixel = 0,
			Parent = frame,
		}, {
			capsule(),
			stroke(),
			new("UIPadding", {
				PaddingLeft = UDim.new(0, 3),
				PaddingRight = UDim.new(0, 3),
				PaddingTop = UDim.new(0, 3),
				PaddingBottom = UDim.new(0, 3),
			}),
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})

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
				local sel
				if opts.multi then
					sel = picked[i] == true
				else
					sel = i == current
				end
				tween(b, {
					BackgroundTransparency = sel and 0 or 1,
					TextColor3 = sel and Theme.Base or Theme.Muted,
				}, FAST)
			end
		end

		local total = 6
		for i, text in ipairs(opts.choices) do
			local w = math.max(26, textWidth(text, 13) + 16)
			total += w + (i > 1 and 2 or 0)
			local btn = new("TextButton", {
				Size = UDim2.fromOffset(w, 22),
				BackgroundColor3 = Theme.On,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = text,
				TextColor3 = Theme.Muted,
				TextSize = 13,
				FontFace = font(Enum.FontWeight.SemiBold),
				LayoutOrder = i,
				Parent = seg,
			}, { capsule() })
			buttons[i] = btn

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
				-- จำตัวเลือกไว้ (multi = รายการเลขที่เลือก)
				if opts.multi then
					local list = {}
					for k in pairs(picked) do
						list[#list + 1] = k
					end
					Game.persist.data.choices[name] = list
				else
					Game.persist.data.choices[name] = current
				end
				Game.save()
			end))
		end

		-- คืนค่าที่จำไว้ตอนโหลดเสร็จ (เรียกจากท้ายไฟล์ ตัวแปรที่ onChoice อ้างถึงพร้อมแล้ว)
		function entry.restore(saved)
			if opts.multi and type(saved) == "table" then
				table.clear(picked)
				for _, k in ipairs(saved) do
					if buttons[k] then
						picked[k] = true
					end
				end
				if next(picked) == nil then
					return
				end
			elseif type(saved) == "number" and buttons[saved] then
				current = saved
			else
				return
			end
			paint()
			if opts.onChoice then
				opts.onChoice(current, table.clone(picked))
			end
		end
		if not opts.parent or opts.persistKey then
			Game.persist.choiceRows[name] = entry
		end

		fitLabels(total + 24)
		-- ไม่เรียก onChoice ตอนสร้าง เพราะตัวแปรที่ callback อ้างถึงยังไม่ถูก assign
		paint()
		descLabel.Text = help
		return entry
	end

	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Theme.Muted,
		BorderSizePixel = 0,
	}, { capsule() })

	local rail = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(40, 22),
		BackgroundColor3 = Theme.Raised,
		BorderSizePixel = 0,
		Parent = frame,
	}, { capsule(), stroke(), knob })

	fitLabels(70)

	local hit = new("TextButton", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		Parent = frame,
	})

	function entry.set(state)
		fixIdentity()
		if on == state then
			return
		end
		on = state
		tween(rail, { BackgroundColor3 = on and Theme.On or Theme.Raised }, FAST)
		tween(knob, {
			Position = UDim2.new(0, on and 21 or 3, 0.5, 0),
			BackgroundColor3 = on and Theme.Base or Theme.Muted,
		}, FAST)
		onChange(on, entry)
		if not on then
			entry.setDesc("ปิดอยู่")
		end
	end

	function entry.isOn()
		return on
	end

	track(hit.MouseButton1Click:Connect(function()
		entry.set(not on)
		Game.persist.data.switches[name] = on
		Game.save()
	end))

	entry.key = name
	if not opts.parent then
		toggles[#toggles + 1] = entry
	end
	-- แถวที่มีคำอธิบายในตาราง Layout ใช้อันนั้นเสมอ ข้อความตอนสร้างของบางตัวเก่าแล้ว ("...หน้า Main")
	entry.setDesc(where and where.help and "ปิดอยู่" or desc)
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
	-- โหมด "ตีจากใต้ดิน": นอนหงายใต้ HumanoidRootPart ของม็อบลงไปเท่านี้ (ตัวเราจมอยู่ในพื้น)
	-- ลอกท่าจากสคริปต์อีกเจ้าที่ผู้ใช้ส่งคลิปมา (Stand = Under, Y Offset 8) วัดกับ Zuko 300 HP อัปดราฟหมัดแรก:
	--   ยืนตรง ลึก 3  ดาเมจเข้า 93 ใน 15 วิ   โดนตี 0   ตัวสั่น (ปักทุก 0.03 วิ + พื้นดันตัวออก)
	--   ยืนตรง ลึก 5  ดาเมจเข้า 109 ใน 10 วิ  โดนตี 6
	--   นอนหงาย ลึก 8 ดาเมจเข้า 215 ใน 15 วิ  โดนตี 0   Zuko ลอยขึ้น ~30 stud (ยืนตรงลอยแค่ ~8)
	-- นอนหงายแล้ว lookVector ชี้ขึ้น hitbox ของเซิร์ฟอยู่หน้าตัว (Get_Players_For_Combat) เลยชี้ตรงไปที่ม็อบพอดี
	UnderDepth = 8,
	-- มุดหลบตอนนอนใต้ม็อบแล้วม็อบออกท่าตี (Parry เปิดอยู่): ลงไปอีกเท่านี้ ค้างนานเท่านี้ ท่าใหม่ต่อเวลาให้
	-- 14 = ลึกรวม 22 เกินกล่องหมัดของบอสที่พุ่งมาเต็มที่ (หน้าตัว 13.25 ตามสูตร Get_Players_For_Combat) ยังไม่ได้วัดสกิล
	-- คอมโบบอสที่วัดได้ใช้ 1.2 วิ (หมัด 1 ถึง 4 ของ Akazo) แต่ทุกท่าใหม่ต่อเวลามุดให้อยู่แล้ว 0.8 พอ
	-- เวลาเทียบกับบอส 3000 HP (ตัวละคร Lv 78 เลือด ~370):
	--   มุดทุกท่า 1.2 วิ: Giyen 518 วิ ไม่ตาย · Gyorei 346 วิ ตาย 2 (อยู่ลึก 22 เกือบตลอด หมัดเข้าน้อย)
	--   มุดเมื่อเลือด < 60%: Nezura ตัวอยู่ลึก 78% ของเวลา ~4.8 ดาเมจ/วิ (เลือดฟื้นช้า พอต่ำแล้วต่ำค้างทั้งไฟต์)
	--   ไม่มุดเลย: Obari 310 วิ ตาย 1 · Zentaro 260 วิ ตาย 3 · Gyutai / Enru ตายซ้ำจนต้องทิ้ง
	-- เลยมุดเฉพาะตอนเลือดเหลือน้อยจริง ๆ ให้เวลาตีมากสุดแต่ยังกันตายตอนใกล้หมด
	DipDepth = 14,
	DipTime = 0.8,
	DipBelowHp = 0.35,
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

-- ถือของชิ้นนี้ในมือ: ช่างตีแบบ Awaken / อัปขั้นกินอาวุธ "ที่ถืออยู่" (Togane: "Hold the weapon you want reforged
-- ... The one in your hand is used up; half its refinement carries over") มีหลายเล่มเลือกเล่มที่ Refine สูงสุด
-- ไม่มีบน toolbar ใส่ช่องว่าง (Toolbar_Equip) คืน true เมื่อถือได้จริง
function Game.holdItem(name)
	local slot = equippedSlot()
	local bag = slot and slot.Inventory:FindFirstChild("Inventory")
	local best, bestLv
	for _, it in ipairs(bag and bag:GetChildren() or {}) do
		local id = it:FindFirstChild("Id")
		if it.Name == name and id then
			local lv = it:FindFirstChild("RefineLevel")
			lv = lv and lv.Value or 0
			if not bestLv or lv > bestLv then
				best, bestLv = id.Value, lv
			end
		end
	end
	if not best then
		return false, "ไม่มี " .. name .. " ในกระเป๋า"
	end
	local bar = slot.Inventory.Toolbar
	local names = { "One", "Two", "Three", "Four", "Five" }
	local index
	for i, s in ipairs(names) do
		if bar[s].Value == best then
			index = i
		end
	end
	if not index then
		for i, s in ipairs(names) do
			if not index and bar[s].Value == 0 then
				SignalEvent.ToServer("Toolbar_Equip", s, best)
				local untilT = os.clock() + 3
				while bar[s].Value ~= best and os.clock() < untilT do
					task.wait(0.1)
				end
				index = bar[s].Value == best and i or nil
			end
		end
	end
	if not index then
		return false, "toolbar เต็ม เว้นว่างหนึ่งช่องให้ " .. name
	end
	-- ระบบอื่น (Auto Skill / Kill Aura) สลับกลับไปถือดาบประจำได้ กันไว้ช่วงถือของไปตี
	Combat.drinkUntil = os.clock() + 6
	equipSlot(index)
	local untilT = os.clock() + 2
	while equippedValue() and equippedValue().Value ~= index and os.clock() < untilT do
		task.wait(0.1)
		equipSlot(index)
	end
	task.wait(0.4)
	return equippedValue() ~= nil and equippedValue().Value == index
end

-- ถือช่องที่ติ๊กไว้ช่องใดช่องหนึ่งอยู่ถือว่าพร้อมตี
local function weaponReady()
	return weaponSlots[heldSlot()] == true
end

local function equipWeapon()
	-- กำลังกินยา (Auto-Potion) ห้ามสลับกลับไปถือดาบ ยากำลังดื่มอยู่จะถูกยกเลิก
	if os.clock() < (Combat.drinkUntil or 0) then
		return false
	end
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
-- ผู้ใช้แจ้ง (24 ก.ย. 2026): ฟาร์มอยู่แล้วเปิดเมนูเกม / หน้าต่างเรา คลิกตีไปกดปุ่ม UI ของเกมที่ทับตัวม็อบด้วย
-- (และกดปุ่ม เปิด/ปิด ของเราเอง แผงเปิดปิดเอง) เลยหาจุดบนตัวม็อบที่ไม่มีปุ่มอะไรทับก่อน ไม่มีเลยค่อยดับ GUI ที่ทับชั่วคลิก
-- พิกัด: VIM ใช้พิกัดเต็มจอ (WorldToViewportPoint) · GetGuiObjectsAtPosition ใช้พิกัดหักแถบบน (GuiInset 58 px วัดจริง)
local swingAt
do
local GuiService = game:GetService("GuiService")
local SwingOffsets = {
	Vector3.new(0, 0, 0), Vector3.new(0, 1.5, 0), Vector3.new(0, -1.5, 0), Vector3.new(0, 2.5, 0),
	Vector3.new(1.2, 0, 0), Vector3.new(-1.2, 0, 0), Vector3.new(0, -2.5, 0),
}

local function overSelf(x, y)
	local pos, size = root.AbsolutePosition, root.AbsoluteSize
	return screen.Enabled and root.Visible and x >= pos.X and x <= pos.X + size.X and y >= pos.Y and y <= pos.Y + size.Y
end

-- ปุ่ม/ช่องพิมพ์/เฟรมที่รับคลิก (Active) ของเกมที่อยู่ตรงจุดนั้น
local function gameGuiAt(x, y)
	local inset = GuiService:GetGuiInset()
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return nil
	end
	for _, o in ipairs(pg:GetGuiObjectsAtPosition(x - inset.X, y - inset.Y)) do
		if o.Visible and (o:IsA("GuiButton") or o:IsA("TextBox") or o.Active) then
			return o
		end
	end
	return nil
end

function swingAt(worldPos)
	local cam = workspace.CurrentCamera
	local p, blockedBy
	for _, off in ipairs(SwingOffsets) do
		local v, onScreen = cam:WorldToViewportPoint(worldPos + off)
		if onScreen or not p then
			-- ปุ่มเกมใต้หน้าต่างเราก็นับ: ดับหน้าต่างเราแล้วคลิกทะลุไปโดนเมนูเกมข้างใต้ (เจอจริงตอนเปิด Inventory)
			local g = gameGuiAt(v.X, v.Y)
			local mine = overSelf(v.X, v.Y)
			if not mine and not g then
				p, blockedBy = v, nil
				break
			end
			if not p then
				p, blockedBy = v, g or "self"
			end
		end
	end

	-- ทุกจุดโดนทับ: หน้าต่างเราดับชั่วคลิก (~70ms) · ปุ่มเกม (ผู้เล่นเปิดเมนูเกมทับม็อบอยู่) ข้ามหมัดนี้ไป
	-- ไม่ดับ GUI เกม เดิมทีคิดจะดับ แต่เมนูเกมจะกะพริบทุกหมัด ผู้เล่นใช้เมนูไม่ได้
	local hidden = {}
	if blockedBy == "self" then
		screen.Enabled = false
		hidden[#hidden + 1] = screen
	elseif blockedBy then
		local trace = _G.PathSlayerTrace
		if trace then
			trace[#trace + 1] = string.format("%.2f SWING skip %s", os.clock(), blockedBy:GetFullName())
		end
		return false
	end
	local trace = _G.PathSlayerTrace
	if trace then
		trace[#trace + 1] = string.format("%.2f SWING %s", os.clock(), blockedBy and tostring(blockedBy) or "clear")
	end
	VIM:SendMouseButtonEvent(p.X, p.Y, 0, true, game, false)
	task.wait(0.06)
	VIM:SendMouseButtonEvent(p.X, p.Y, 0, false, game, false)
	for _, sg in ipairs(hidden) do
		sg.Enabled = true
	end
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
local killAura = { on = false, far = false, fastKill = false, lastFire = 0, fires = 0 }
-- parry: Kill Aura > Parry อัตโนมัติ ใช้ตัวจับท่าตีชุดเดียวกับ Auto-Dodge แต่กดบล็อกแทนการวาร์ปหลบ
-- blockUntil: กำลังค้างปุ่มบล็อกถึงเวลานี้ ห้ามยิงหมัด (ต่อยตอนบล็อกเกมยกเลิกบล็อก)
local autoDodge = { on = false, parry = false, holdUntil = 0, blockUntil = 0, dodges = 0, parries = 0, hitsTaken = 0, learned = 0 }

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
-- เปิด "ตีจากใต้ดิน" อยู่ ส่งไปปักใต้ม็อบทุกเฟรมแทน ม็อบตีลงมาไม่ถึง (ดู Combat.UnderDepth)
local function pinAbove(hrp, root)
	if not (root and root.Parent and hrp.Parent and root.Position.Y > Combat.WorldFloorY) then
		return false
	end
	if killAura.launch then
		killAura.pinUnder(root)
		return true
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

-- ตีจากใต้ดิน: ปักตัวนอนหงายใต้ม็อบทุกเฟรม (Stepped = ก่อนฟิสิกส์คิด) แทนลูป 0.03 วิ
-- ผู้ใช้เทียบคลิปแล้วบอกของเราสั่น ของอีกเจ้านิ่ง สาเหตุสามอย่างที่เจอใน log:
--   ปักทุก 2 เฟรม แรงโน้มถ่วงดึงลงระหว่างนั้น / ตัวจมในพื้นเลยโดนดันออก / Humanoid สลับ Running-Climbing-Freefall
-- แก้: ปักทุกเฟรม + ปิดชนตัวเรา (noclip) + PlatformStand ให้ Humanoid เลิกเปลี่ยนสถานะ
-- PlatformStanding ไม่ใช่ Freefall เลยไม่โดนเกมฆ่าตอนลอยเกิน 9 วิ และ airborneFor ก็ไม่สั่งให้ขึ้นไปแตะพื้น
killAura.LayFaceUp = CFrame.Angles(math.rad(90), 0, 0)

-- ความลึกตอนนี้: ปกติ UnderDepth ช่วงที่ parryNow สั่งมุดหลบบวก DipDepth
function killAura.depth()
	return Combat.UnderDepth + (os.clock() < (killAura.dipUntil or 0) and Combat.DipDepth or 0)
end

-- จำค่าชนเดิมของทุกชิ้นในตัวละครไว้คืนตอนเลิก ตายเกิดใหม่ = ตัวใหม่ จำใหม่
function killAura.rememberCollide(char)
	killAura.underChar = char
	killAura.underParts = {}
	for _, p in ipairs(char and char:GetDescendants() or {}) do
		if p:IsA("BasePart") then
			killAura.underParts[p] = p.CanCollide
		end
	end
end

function killAura.pinUnder(root)
	killAura.underRoot = root
	if killAura.underConn then
		return
	end
	killAura.rememberCollide(LocalPlayer.Character)
	killAura.underConn = track(game:GetService("RunService").Stepped:Connect(function()
		local r = killAura.underRoot
		local char, me, hum = selfParts()
		if not (me and hum and hum.Health > 0) then
			return
		end
		if char ~= killAura.underChar then
			killAura.rememberCollide(char)
		end
		for p in pairs(killAura.underParts) do
			p.CanCollide = false
		end
		hum.PlatformStand = true
		-- ม็อบตาย/หายระหว่างรอเป้าถัดไป: ลอยค้างที่เดิมด้วยการล้างความเร็วทุกเฟรม (ร่วงแค่ ~0.3 stud/วิ) ไม่เขียน CFrame ทับ
		-- เดิมเขียน underLast ทับทุกเฟรม: หอคอยย้ายแมพ เซิร์ฟวาร์ปเราไปแท่นเกิดแมพใหม่ แต่ตรงนี้ดึงกลับจุดเดิมทุกเฟรม
		-- แมพเก่าถูกลบ ตัวตกลงใต้แมพตาย (ผู้ใช้เสียหัวใจ 3 ดวงในชั้น 1 และอีกดวงแถวชั้น 30)
		-- ไม่มีเป้า: ตรึงไว้ที่จุดเดิมจริง ๆ (ล้างความเร็วอย่างเดียวยังร่วง ~0.3 stud/วิ ค้างนาน 15 นาทีจมไป 330 stud
		-- ผู้ใช้เจอตัวไปอยู่ใต้แมพชั้น 58) แต่ถ้าตัวถูกย้ายไกลในเฟรมเดียว (เซิร์ฟวาร์ปไปแท่นเกิดแมพใหม่) รับจุดใหม่แทน
		if r and r.Parent and r.Position.Y > Combat.WorldFloorY then
			killAura.underLast = CFrame.new(r.Position - Vector3.new(0, killAura.depth(), 0)) * killAura.LayFaceUp
			me.CFrame = killAura.underLast
			killAura.hoverAt = nil
		else
			if not killAura.hoverAt or (me.Position - killAura.hoverAt.Position).Magnitude > 20 then
				killAura.hoverAt = me.CFrame
			end
			me.CFrame = killAura.hoverAt
		end
		me.AssemblyLinearVelocity = Vector3.zero
		me.AssemblyAngularVelocity = Vector3.zero
	end))
	-- ปักซ้ำก่อนวาดภาพด้วย ม็อบยังขยับระหว่างรอบฟิสิกส์ (โดนยกลอยพุ่งขึ้นเร็ว)
	-- วัดตอนปักแค่ Stepped: ห่างจากจุดใต้ม็อบเฉลี่ย 1.41 stud สูงสุด 28 ตอนม็อบโดนยก เห็นเป็นตัวสั่นตามม็อบ
	killAura.underRender = track(game:GetService("RunService").RenderStepped:Connect(function()
		local r = killAura.underRoot
		local _, me = selfParts()
		if me and r and r.Parent and r.Position.Y > Combat.WorldFloorY then
			killAura.underLast = CFrame.new(r.Position - Vector3.new(0, killAura.depth(), 0)) * killAura.LayFaceUp
			me.CFrame = killAura.underLast
		end
	end))
end

-- เลิกนอนใต้ดิน คืนการชนกับสถานะ Humanoid ไม่งั้นตัวละครตกทะลุพื้นหรือล้มค้าง
function killAura.releaseUnder()
	killAura.hoverAt = nil
	killAura.underRoot = nil
	killAura.underLast = nil
	if not killAura.underConn then
		return
	end
	killAura.underConn:Disconnect()
	killAura.underConn = nil
	if killAura.underRender then
		killAura.underRender:Disconnect()
		killAura.underRender = nil
	end
	for p, collide in pairs(killAura.underParts or {}) do
		if p.Parent then
			p.CanCollide = collide
		end
	end
	local _, me, hum = selfParts()
	if hum then
		hum.PlatformStand = false
		-- ปิด PlatformStand เฉย ๆ Humanoid ค้างสถานะ Physics (ท่าล้ม) วัดได้หลังปิดสวิตช์ 2 วิ สั่งลุกเอง
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	-- ขึ้นมายืนบนพื้นเหนือจุดที่นอนอยู่ ไม่งั้นเปิดชนกลับตอนตัวยังจมดิน แล้วติดอยู่ในหิน
	if me then
		local stand = groundAt(me.Position + Vector3.new(0, Combat.UnderDepth, 0))
		if stand then
			placeAt(me, CFrame.new(stand), "under-release")
		end
		me.AssemblyLinearVelocity = Vector3.zero
	end
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
				-- ไม่มีเป้าเหลือทั้งแมพ ขึ้นมาบนพื้นก่อน นอนทะลุพื้นรอไปเรื่อย ๆ ไม่มีประโยชน์
				killAura.releaseUnder()
				combatStatus(wanted and ("ไม่เจอ " .. wanted .. " ทั้งแมพ") or "ไม่เจอม็อบทั้งแมพ")
				task.wait(0.8)
			else
				local mobHum = mob:FindFirstChildOfClass("Humanoid")
				local target = mobRoot.Position
				-- นอนใต้ดินอยู่ ระยะถึงม็อบคือความลึกอยู่แล้ว (8) ไม่งั้นทุกรอบตกกิ่ง "วาร์ปไป" แล้วไม่ตีเอง
				local engage = Combat.EngageDistance + (killAura.launch and Combat.UnderDepth or 0)

				if airborneFor(hum) > Combat.MaxAirTime then
					combatStatus("แตะพื้นรีเซ็ตเวลาลอย")
					touchGround(hrp, hum, target)
				elseif dist > engage then
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
	killAura.releaseUnder()
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
	-- Kill Aura / Insta Kill ตีด้วยของที่ถืออยู่เสมอ ช่องที่ติ๊กใช้ตอนมือเปล่า และตอน Auto-Attack หยิบให้
	return "มือเปล่าจะหยิบช่อง " .. table.concat(list, "/") .. " · ถืออาวุธอื่นอยู่ Kill Aura ก็ตีด้วยอันนั้น"
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
-- โหมดเจาะจงตัว: ใช้ชื่อที่ติ๊กไว้ในแผง เลือกม็อบ (การ์ดเดียวกัน)
mobOnlyRow = switchRow("Auto-Attack-Mob", "ปิดอยู่", 3, function(on)
	if not on then
		autoAttack.on = false
		autoAttack.onlySelected = false
		mobOnlyRow.setDesc("ปิดอยู่")
		return
	end
	if not selectedMob then
		mobOnlyRow.set(false)
		-- ตั้งข้อความหลังปิด ไม่งั้น set(false) เขียนคำอธิบายทับ
		mobOnlyRow.setDesc("ยังไม่ได้เลือกม็อบ กด เปิด › ที่ เลือกม็อบ ด้านล่างก่อน")
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
	-- หีบที่เปิดด้วยแต้มหอคอย (Ouwigahara Chest "Open (30,000 points)" ที่โซนร้านหลังจบรอบ) เปิดเฉพาะผู้ใช้ติ๊กไว้
	-- ผู้ใช้เจอ: Auto-Chest ไปกดเองทั้งที่แต้มไม่พอ ขึ้น "Not enough points" และถ้าพอจะกินแต้มที่ควรไปแลก Wen
	pointChests = false,
	-- หีบที่อยู่ไกลกว่านี้ไม่ใช่ของบอสที่เพิ่งฆ่า อาจเป็นหีบอีเวนต์อีกฟากแมพ
	ChestRadius = 250,
	-- ยังไม่ได้วัดว่าหีบโผล่ช้ากว่าบอสตายกี่วิ 3 วิคือค่าเผื่อ รอเฉพาะเควสบอส (ฆ่า 1 ตัว)
	ChestWait = 3,
	-- ของบินออกจากหีบใช้ DropFlightTime ~0.52 วิ รอให้ลงพื้นก่อนค่อยกด
	LandWait = 0.8,
	-- เก็บพร้อมกันจากกลางกอง: prompt Claim มีระยะ 10 เผื่อไว้ 1 · ยืนนิ่งให้เซิร์ฟเห็นตำแหน่งก่อนกด
	-- (วาร์ปแล้วยิงทันทีเซิร์ฟยังเห็นที่เดิม แบบเดียวกับที่เจอกับลังของ Shiori) 0.3 ค่าเดา สั้นกว่า 0.4 ของ firePromptAt
	GrabRadius = 9,
	GrabSettle = 0.3,
	-- ย้ายจุดยืนเก็บเป็นกลุ่มได้กี่ครั้ง เกินนี้ที่เหลือไล่เก็บทีละชิ้น
	GrabStops = 4,
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
		-- บางหีบใน Chests ไม่มี ChestPrompt (เจอตอนกดคราฟในดันเจี้ยน) prompt เป็น nil ต้องเช็กก่อนอ่าน ActionText
		local costsPoints = prompt ~= nil and tostring(prompt.ActionText):lower():find("point") ~= nil
		if pos and chest:GetAttribute("IsOpen") == false and prompt.Enabled and (Loot.pointChests or not costsPoints)
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
	local function claimed(d)
		got[#got + 1] = tostring(d.item)
		Runner.hook("loot", tostring(d.item))
	end

	-- เก็บทุกชิ้นพร้อมกัน: ของจากหีบบอสตกเป็นกองรอบหีบ ยืนกลางกองแล้วกด prompt ทุกชิ้นในระยะทีเดียว
	-- เดิมวาร์ปไปทีละชิ้น รอ 0.4 วิ แล้วรอของหาย World Events Chest ออก 6-8 ชิ้นใช้หลายวินาที ผู้ใช้บอกช้ามาก
	-- ชิ้นที่อยู่นอกระยะ Claim (10) ค่อยไล่เก็บทีละชิ้นแบบเดิมข้างล่าง
	-- ของกระจายกว้างกว่าระยะ Claim รอบจุดกึ่งกลาง (World Events Chest 5 ชิ้น ยืนกลางกองแล้วเข้าระยะแค่ 1)
	-- เลยยืนที่ของชิ้นที่มีเพื่อนในระยะมากสุด ทุกชิ้นในกลุ่มห่างจุดยืนไม่เกิน GrabRadius แน่นอน เก็บทีละกลุ่ม
	local left = myDrops()
	for _ = 1, Loot.GrabStops do
		if #left == 0 or stop() then
			break
		end
		local spot, group
		for _, a in ipairs(left) do
			local members = {}
			for _, b in ipairs(left) do
				if (b.part.Position - a.part.Position).Magnitude <= Loot.GrabRadius then
					members[#members + 1] = b
				end
			end
			if not group or #members > #group then
				spot, group = a.part.Position, members
			end
		end
		placeAt(hrp, CFrame.new(spot + Vector3.new(0, 2, 0)), "loot-group")
		hrp.AssemblyLinearVelocity = Vector3.zero
		task.wait(Loot.GrabSettle)
		for _, d in ipairs(group) do
			task.spawn(fireproximityprompt, d.prompt)
		end
		say(string.format("เก็บพร้อมกัน %d ชิ้น", #group))
		local until_ = os.clock() + 1.2
		repeat
			task.wait(0.1)
			local waiting = 0
			for _, d in ipairs(group) do
				if d.part.Parent then
					waiting += 1
				elseif not d.done then
					d.done = true
					claimed(d)
				end
			end
		until waiting == 0 or os.clock() > until_ or stop()
		local rest = {}
		for _, d in ipairs(left) do
			if d.part.Parent then
				rest[#rest + 1] = d
			end
		end
		left = rest
	end

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
				claimed(d)
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
				step.waitingSince = os.clock()
			end
			step.waitingSince = step.waitingSince or os.clock()
			-- ของเควสสร้างฝั่งเรา (PickupState) ตอนเกมเริ่มงานนั้น บางทีไม่สร้างเลย: กล่องของ Ginzo (บัญชี izen1843)
			-- ยืนตรงจุดแล้วไม่มีอะไรใน workspace ปุ่มของมันก็แค่ยิง QuestProgress(เควส, งาน, ช่อง) เซิร์ฟเช็กระยะ 25 (MaxDistance)
			-- ยิงเองแบบเดียวกันทีละจุด ลองแล้วตัวนับขึ้น 0 -> 1 ได้ Jewelry Box เข้ากระเป๋า
			if hrp and step.positions and step.quest and os.clock() - (step.waitingSince or os.clock()) > 4 then
				for i, pos in ipairs(step.positions) do
					if (taskProgress(step.pickup) or step.max) >= step.max or Runner.cancel then
						break
					end
					placeAt(hrp, CFrame.new(pos + Vector3.new(0, 3, 0)), "pickup-direct")
					hrp.AssemblyLinearVelocity = Vector3.zero
					task.wait(0.6)
					SignalEvent.ToServer("QuestProgress", step.quest, step.pickup, i)
					task.wait(0.6)
				end
				step.waitingSince = os.clock()
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

-- สั่งลูปสู้ไล่ตีชื่อนี้ (ทั้งแมพ เอาตัวใกล้สุด) ใช้ร่วมกันระหว่างฟาร์มดรอปกับฆ่ายามหีบ
function Runner.attackMob(name)
	autoAttack.target = name
	autoAttack.onlySelected = false
	if not autoAttack.on then
		autoAttack.on = true
		task.spawn(attackLoop)
	end
end

-- หยุดลูปสู้แล้วรอให้ออกจริง ไม่งั้นลูปยังเขียน CFrame แย่งตอนเราวาร์ปไปเปิดหีบ/เก็บของ
function Runner.haltAttack()
	autoAttack.on = false
	local untilT = os.clock() + 3
	while autoAttack.running and os.clock() < untilT do
		task.wait(0.05)
	end
end

-- ฆ่าม็อบแหล่งดรอปไปเรื่อย ๆ แล้วเก็บของที่ตกเป็นระยะ จนมีไอเทมครบ need ชิ้น
-- ของดรอปเป็น LootDrop ที่ต้องกด Claim เอง เลยหยุดลูปสู้ชั่วคราวตอนเก็บ ไม่งั้นมันดึงตัวกลับไปหาม็อบ
-- code = รหัสม็อบ (NpcCode) ถ้าไม่ส่งมาใช้ FarmSources (ไอเทมรับเควสปราณ)
-- ค่าคืนพิเศษของ Runner.farm: ม็อบตายหมดรอเกิดใหม่ ตามด้วยวิที่เหลือโดยประมาณ ไม่ใช่ความล้มเหลว
Runner.RESPAWN = "__respawn"

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
		Runner.attackMob(mob.name)
	end
	local stopAttack = Runner.haltAttack

	goToSpawn(mob.center)
	startAttack()
	-- Webhook บอกในข้อความฆ่าบอสว่าของที่ตามหาดรอปหรือยัง
	Runner.farmTarget = item
	local emptySince, sawAlive
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
			-- ผู้เล่นแจ้ง: ติ๊ก Reaper's Outfit กับ Stone Haori ไว้ ฆ่า Gyorei ตายแล้วยืนรอเกิดใหม่ 300 วิ
			-- ไม่ไปตีอีกตัวในคิว คืนให้คิวเลือกชิ้นอื่นแทน (Runner.canYield ตั้งโดยคิวที่มีงานอื่นรออยู่)
			-- 5 วิ = เผื่อของดรอปโผล่หลังตายให้รอบบนเก็บก่อน
			-- ยังไม่เคยเห็นตัวเลยรอบนี้ใช้ 10 วิ เพิ่งวาร์ปมาม็อบยังไม่ stream เข้า นับว่าตายไม่ได้
			local giveUpAfter = sawAlive and 5 or 10
			if os.clock() - emptySince > giveUpAfter and Runner.canYield and Runner.canYield(item) then
				stopAttack()
				autoAttack.target = nil
				Runner.farmTarget = nil
				return false, Runner.RESPAWN, (mob.respawn or 300) - (os.clock() - emptySince)
			end
			if os.clock() - emptySince > 3 then
				goToSpawn(mob.center)
				-- บอสใหญ่เกิดใหม่ทุก 300 วิ บางตัวออกเฉพาะกลางคืน (OnlyAtNight) บอกให้รู้ว่ารออะไรอยู่
				report(string.format("รอ %s เกิดใหม่ (%d วิแล้ว) · %s %d/%d", mob.name,
					math.floor(os.clock() - emptySince), item, itemCount(item), need), Theme.Warn)
			end
		else
			emptySince = nil
			sawAlive = true
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

-- ริมน้ำใกล้ลังของ Runo (Mistfall Harbor) จุดเดียวกับที่ตกปลาเควสทดสอบแล้วว่าโยนถึงน้ำ
-- ใช้ตกของที่ไม่ได้ผูกกับเควส เช่น Lost Shotgun
Runner.FishSpot = Vector3.new(-574, 800, 681)

Runner.Sealed = {
	-- ยามยืนห่างหีบ 11-16 stud ตอนตรวจ (Cache Lancer x2, Lancer Captain) Leash ของ Captain 100
	GuardRadius = 120,
	-- ทดสอบจริงกับ T2 (ยาม 400+400+1200 HP) ตัวละคร 330 HP ตายใน 35 วิ ยามเสียไปรวมแค่ ~220
	-- ตายซ้ำที่ใบเดิมเกินนี้ = ยามหนักเกินตัวละครตอนนี้ ข้ามไปหาใบอื่น (T1 ยามเบากว่า) แล้วค่อยกลับมา
	MaxDeaths = 2,
	DeathSkipFor = 600,
	-- ไม่เห็นยามแล้วแต่หีบยังล็อกเกินนี้ = ยามอีกตัวยังไม่ stream หรือหีบค้าง ไปหีบอื่นก่อน ค่าเผื่อ ยังไม่ได้วัด
	StuckAfter = 20,
	SkipFor = 120,
	-- รอ stream หลังวาร์ปไปจุดเกิดหีบ ค่าเดียวกับ Runner.Hunt.StreamWait
	StreamWait = 3,
}

-- ยามที่ยังไม่ตายรอบหีบ เลือดเหลือน้อยสุดก่อน: ยามน้อยลงเร็วที่สุด = โดนรุมน้อยลงเร็วที่สุด
-- เดิมเลือกตัวใกล้หีบสุด ยามเดินไปมาเลยสลับเป้าทุก 0.5 วิ ดาเมจกระจายไม่มีตัวไหนตาย
function Runner.sealedGuard(chestPos, names)
	local folder = workspace:FindFirstChild("Humanoids")
	local best, bestHp
	for _, m in ipairs(folder and folder:GetDescendants() or {}) do
		if m:IsA("Model") and m:GetAttribute("IsMob") and table.find(names, m.Name) then
			local hum = m:FindFirstChildOfClass("Humanoid")
			local root = m:FindFirstChild("HumanoidRootPart")
			local near = root and (root.Position - chestPos).Magnitude <= Runner.Sealed.GuardRadius
			if hum and hum.Health > 0 and near and (not bestHp or hum.Health < bestHp) then
				best, bestHp = m, hum.Health
			end
		end
	end
	return best
end

-- หีบ Sealed Cache: หาหีบที่มีของชิ้นนี้ (โอกาสสูงก่อน ใกล้ก่อน) ฆ่ายามจนปลดล็อก เปิด เก็บ วนจนครบ
-- ไม่เห็นหีบเลยก็วาร์ปไล่จุดเกิดทั้ง 12 จุดให้ stream เข้ามา หีบเกิดพร้อมกันได้ 5 ใบ เกิดใหม่ทุก 25 นาที
function Runner.sealed(item, need, alt)
	local events = Game.chestEvents()
	local spots = {}
	for chestId in pairs(alt.chests) do
		for _, p in ipairs(events[chestId] and events[chestId].spawns or {}) do
			spots[#spots + 1] = p
		end
	end
	if #spots == 0 then
		return false, "ไม่รู้จุดเกิดของหีบ " .. alt.best
	end

	attackRow.set(false)
	mobOnlyRow.set(false)
	Runner.farmTarget = item
	local skip, lockedSince, deaths, spotAt = {}, {}, {}, 0
	-- ยามตัวที่กำลังตี ตีจนตายค่อยเปลี่ยน attackLoop เลือกตัวใกล้สุดตามชื่อ ชื่อเดียวกันก็ยังติดตัวเดิมได้
	local guard, fighting
	local deathConn = LocalPlayer.CharacterAdded:Connect(function()
		if fighting then
			deaths[fighting] = (deaths[fighting] or 0) + 1
			if deaths[fighting] >= Runner.Sealed.MaxDeaths then
				skip[fighting] = os.clock() + Runner.Sealed.DeathSkipFor
				deaths[fighting] = nil
			end
		end
	end)
	while not Runner.cancel do
		local have = itemCount(item)
		if have >= need then
			break
		end
		local _, me, myHum = selfParts()
		if not (me and myHum and myHum.Health > 0) then
			-- ตายอยู่ รอเกิดใหม่ก่อน ไม่งั้นลูปคิดว่าไม่มีหีบแล้ววาร์ปไล่จุดทั้งที่ยังไม่มีตัว
			task.wait(1)
			continue
		end
		local chests = workspace:FindFirstChild("Chests")
		local pick, pickChance, pickD
		for _, chest in ipairs(chests and chests:GetChildren() or {}) do
			local chance = alt.chests[chest:GetAttribute("ChestId")]
			if chance and me and chest:GetAttribute("IsOpen") == false and (skip[chest] or 0) < os.clock() then
				local d = (chest:GetPivot().Position - me.Position).Magnitude
				if not pick or chance > pickChance or (chance == pickChance and d < pickD) then
					pick, pickChance, pickD = chest, chance, d
				end
			end
		end

		fighting = pick
		if not pick then
			Runner.haltAttack()
			guard = nil
			spotAt = spotAt % #spots + 1
			report(string.format("ตามหาหีบ Sealed Cache จุด %d/%d · %s %d/%d", spotAt, #spots, item, have, need), Theme.Warn)
			goToSpawn(spots[spotAt])
			task.wait(Runner.Sealed.StreamWait)
		else
			local id = pick:GetAttribute("ChestId")
			local pos = pick:GetPivot().Position
			local prompt = pick:FindFirstChild("ChestPrompt", true)
			if prompt and prompt.Enabled then
				Runner.haltAttack()
				goToSpawn(pos)
				local got = collectLoot({
					stop = function()
						return Runner.cancel
					end,
					say = function(text)
						report(string.format("%s · %s  %d/%d", id, text, itemCount(item), need), Theme.Accent)
					end,
				})
				if #got > 0 then
					report("ได้จาก " .. id .. ": " .. table.concat(got, ", "), Theme.Accent)
				end
				-- เปิดไม่ติด (คนอื่นเปิดก่อน / prompt หายระหว่างทาง) อย่าวนเปิดใบเดิมซ้ำ
				if pick.Parent and pick:GetAttribute("IsOpen") == false then
					skip[pick] = os.clock() + Runner.Sealed.SkipFor
				end
			else
				local gHum = guard and guard.Parent and guard:FindFirstChildOfClass("Humanoid")
				if not (gHum and gHum.Health > 0) then
					guard = Runner.sealedGuard(pos, events[id] and events[id].guards or {})
				end
				if guard then
					lockedSince[pick] = nil
					Runner.attackMob(guard.Name)
					report(string.format("ฆ่ายาม %s ที่ %s · %s %d/%d", guard.Name, id, item, have, need), Theme.Accent)
				else
					Runner.haltAttack()
					goToSpawn(pos)
					lockedSince[pick] = lockedSince[pick] or os.clock()
					if os.clock() - lockedSince[pick] > Runner.Sealed.StuckAfter then
						skip[pick] = os.clock() + Runner.Sealed.SkipFor
						lockedSince[pick] = nil
					end
					report(string.format("รอหีบ %s ปลดล็อก · %s %d/%d", id, item, have, need), Theme.Warn)
				end
			end
		end
		task.wait(0.5)
	end
	deathConn:Disconnect()
	Runner.haltAttack()
	autoAttack.target = nil
	Runner.farmTarget = nil
	if Runner.cancel then
		return false, "ยกเลิกแล้ว"
	end
	return true
end

-- ร้านหมุนเวียน / Black Marketer: ของลงทะเบียนเข้า Shop.itemsforsale เฉพาะรอบที่มีขาย
-- เช็กทุก 5 วิจนมี แล้วคืนให้ Runner.obtain วางแผนใหม่ (รอบนั้นจะเป็นทางร้านปกติ)
-- Black Marketer อยู่ครั้งละ 30 นาที ไม่รู้รอบมา ปล่อยรอข้ามคืนได้ (Anti-AFK กันหลุดให้)
function Runner.waitVendor(item, alt)
	local since = os.clock()
	while not Runner.cancel do
		if Game.shopListing(item) then
			return true
		end
		report(string.format("รอ %s มาขาย %s · รอมา %d นาที", alt.seller, item, math.floor((os.clock() - since) / 60)),
			Theme.Warn)
		task.wait(5)
	end
	return false, "ยกเลิกแล้ว"
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
	-- สูตรที่ต่อยอดจากอาวุธเดิม (refineKept: ค่า Refine ติดไปครึ่งหนึ่ง) เกมกินเล่ม "ที่ถืออยู่" ต้องถือก่อนกดตี
	local base = recipe.refineKept and recipe.required and recipe.required[1]
	if base then
		local held, why = Game.holdItem(base.name)
		if not held then
			Combat.drinkUntil = 0
			return false, "ถือ " .. base.name .. " ไม่ได้: " .. tostring(why)
		end
	end
	local SignalFunction = require(ReplicatedStorage.Communication.ServerAndClient.Signals.SignalFunction)
	local sent, res = pcall(SignalFunction.ToServer, "CraftRecipe", id)
	Combat.drinkUntil = 0
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
			-- ราคาที่เป็นของ (ยาของ Meku = Demon Horns 2 + Wen) ต้องมีในกระเป๋าก่อน แผนรู้ว่าต้องฟาร์ม แต่เดิมซื้อเลย
			-- เจอจริง: เควส Restock the Infirmary ซื้อยาได้สองชนิด Horns หมด ขวดที่สามเซิร์ฟเงียบ ("เงินไม่ลด")
			local count = math.min(need - have, 99)
			for _, p in ipairs(priceParts(how.listing.Price)) do
				if not Game.Currencies[p.currency] and itemCount(p.currency) < p.amount * count then
					local ok, why = Runner.obtain(p.currency, p.amount * count)
					if not ok then
						return false, why
					end
				end
			end
			report(string.format("ซื้อ %s  %d/%d", name, have, need), Theme.Accent)
			-- ครั้งละไม่เกิน 99 ตามที่เซิร์ฟรับ (Shop.SanitizeAmount)
			local row = { name = name, source = "shop", cost = priceParts(how.listing.Price) }
			local ok, msg = Game.buy(row, count)
			if not ok then
				return false, msg
			end
			task.wait(0.5)
		elseif how.kind == "farm" then
			return Runner.farm(name, need, how.route.code)
		elseif how.kind == "sealed" then
			return Runner.sealed(name, need, how)
		elseif how.kind == "fish" then
			return Runner.fish({ [name] = need }, Runner.FishSpot, "")
		elseif how.kind == "vendor" then
			-- รอจนร้านมีของแล้ววนกลับไปวางแผนใหม่ รอบหน้าแผนจะออกมาเป็น shop เอง
			local ok, why = Runner.waitVendor(name, how)
			if not ok then
				return false, why
			end
		else
			for _, input in ipairs(Game.recipeInputs(how.recipe)) do
				-- ค่าที่สามคือวิรอเกิดใหม่ตอน why = Runner.RESPAWN ส่งต่อให้คิวรู้ว่าจะกลับมาเมื่อไร
				local ok, why, extra = Runner.obtain(input.name, input.amount)
				if not ok then
					return false, why, extra
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

-- เหยื่อตามเบ็ด จากบทพูด Jeso (Jeso_Pairing): "Rich bait on that Basic Fishing Rod ... small fry all day"
-- "On the Rare Fishing Rod, a Fish Head" "the Golden Tentacle pulls the deep things up. Only the Legendary"
-- เบ็ดกำหนดว่าตกอะไรได้ (CatchTier) เหยื่อเพิ่ม CatchChance / FishLuck = ได้ของบ่อยขึ้น
-- เดิมไม่ใส่เหยื่อเลย เบ็ด Basic ได้ปลา 1 ตัวใน 90 วิ ที่เหลือ "slipped"
-- Golden Tentacle ซื้อด้วย Wen ไม่ได้ (Robux หรือหีบ Sealed Chest) มีก็ใช้ ไม่มีก็ถอยไปตัวถัดไป
Fishing.BaitFor = {
	-- Jeso บอกว่าเหยื่อดีบนเบ็ด Basic ไม่ช่วย แต่วัดจริงสวน: Worm 61 ครั้งได้ปลา R3 1 ตัว (1.6%)
	-- Fish Head 45 ครั้งได้ Clown Fish 3 ตัว (6.7%) Golden Fish ที่ต้องใช้แลกเบ็ด Rare อยู่กลุ่ม R3 เดียวกัน
	-- refine เบ็ด Basic +5 ไม่ช่วย (33 ครั้ง R3 = 0) เบ็ดนี้ FishLuck ฐานเป็น 0 คูณเท่าไรก็ 0
	["Basic Fishing Rod"] = { "Fish Head", "Worm" },
	["Rare Fishing Rod"] = { "Fish Head", "Worm" },
	["Legendary Fishing Rod"] = { "Golden Tentacle", "Fish Head", "Worm" },
}
Fishing.BaitBuyable = { Worm = true, ["Fish Head"] = true }
-- ซื้อครั้งละเท่านี้ (Worm 6 Wen / Fish Head 9 Wen ต่อชิ้น) กินหนึ่งชิ้นต่อหนึ่งครั้งที่ปลากิน
Fishing.BaitStock = 40

local function equippedBaitId()
	local slot = equippedSlot()
	local misc = slot and slot:FindFirstChild("Misc")
	local v = misc and misc:FindFirstChild("EquippedBaitId")
	return v and v.Value or 0
end

local function inventoryEntry(name)
	local slot = equippedSlot()
	local bag = slot and slot.Inventory:FindFirstChild("Inventory")
	return bag and bag:FindFirstChild(name)
end

-- ใส่เหยื่อที่ดีที่สุดที่เบ็ดนี้ใช้ได้ ไม่มีสักอันก็ซื้อตัวที่ซื้อได้ คืนชื่อเหยื่อ (nil = ตกเบ็ดเปล่า)
local function ensureBait(rodName)
	-- ไล่จากดีสุด: มีอยู่ก็ใช้ ไม่มีแต่ซื้อได้ก็ซื้อ เดิมเลือกตัวที่มีอยู่ก่อน
	-- ได้เบ็ด Rare แล้วยังใช้ Worm เหลือค้างแทนที่จะซื้อ Fish Head
	local order = Fishing.BaitFor[rodName] or {}
	local pick
	for _, name in ipairs(order) do
		if not pick then
			if (Game.wallet()[name] or 0) > 0 then
				pick = name
			elseif Fishing.BaitBuyable[name] and Runner.obtain(name, Fishing.BaitStock) then
				pick = name
			end
		end
	end
	local entry = pick and inventoryEntry(pick)
	local id = entry and entry:FindFirstChild("Id")
	if id and equippedBaitId() ~= id.Value then
		-- เดียวกับปุ่มใส่เหยื่อในกระเป๋าเกม (EquippedOptions.Bait): EquipBait(Id), 0 = ถอด
		SignalEvent.ToServer("EquipBait", id.Value)
		task.wait(0.5)
	end
	return pick
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
	-- Auto Skill ก็หยิบดาบเองตอนมีม็อบในระยะท่า (Flame Tiger ไกลถึง 100 stud) เบ็ดหลุดมือแบบเดียวกัน
	local skillWasOn = Runner.skillOn and Runner.skillOn()
	if skillWasOn then
		Runner.setSkill(false)
	end

	local _, hrp = selfParts()
	placeAt(hrp, CFrame.new(near + Vector3.new(0, 4, 0)), "fishing-scan")
	task.wait(2)
	local stand, water = fishingSpot(near)
	if not stand then
		if auraWasOn then
			Runner.setAura(true)
		end
		if skillWasOn then
			Runner.setSkill(true)
		end
		return false, "หาริมน้ำที่โยนเบ็ดได้ไม่เจอในระยะ " .. Fishing.ScanRadius .. " stud"
	end

	_G.PathSlayerAutoFish = Fishing.WinDelay
	local bait = ensureBait(rodName)
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

			-- เหยื่อหมดกลางทาง (กินชิ้นละครั้งที่ปลากิน) ซื้อ/ใส่ใหม่ ไม่งั้นตกเบ็ดเปล่าต่อจนจบ
			if bait and (Game.wallet()[bait] or 0) == 0 then
				bait = ensureBait(rodName)
				-- ไปซื้อที่ร้านมา ต้องกลับมายืนริมน้ำก่อน
				local _, back = selfParts()
				if back and (back.Position - stand).Magnitude > 4 then
					placeAt(back, CFrame.lookAt(stand, Vector3.new(water.X, stand.Y, water.Z)), "fishing")
					task.wait(0.5)
				end
			end
			report(string.format("%sโยนเบ็ด%s · ได้แล้ว %d ตัว · %s", prefix, bait and (" (" .. bait .. ")") or "", caught, progress()), Theme.Accent)
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
	if skillWasOn then
		Runner.setSkill(true)
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
			-- วาร์ปข้ามแมพมาจากร้าน (Meku -> ลังของ Shiori ~2,000 stud) แล้วยิงหลังรอ 0.8 วิ เซิร์ฟยังเห็นเราที่เดิม
			-- ลังไม่รับ ทั้งที่ยิงซ้ำตอนยืนนิ่งแล้วผ่าน (0 -> 1) เลยลองซ้ำ วางตัวใหม่แล้วรอเพิ่มก่อนยอมแพ้
			local took = false
			for attempt = 1, 3 do
				if attempt > 1 then
					placeAt(hrp, CFrame.new(step.position + Vector3.new(0, 3, 3), step.position), "deposit")
					hrp.AssemblyLinearVelocity = Vector3.zero
					task.wait(1.5)
				end
				SignalEvent.ToServer("QuestProgress", step.deposit, row.task)
				took = waitFor(function()
					return (taskProgress(row.task) or row.max) > before
				end, 3)
				if took then
					break
				end
			end
			if not took then
				return false, "ลังไม่รับ " .. row.item .. " (ยืนไม่ถึงจุดวาง หรือเซิร์ฟปฏิเสธ)"
			end
			task.wait(0.15)
		end
	end
	return true
end
end)()

-- แบบพิมพ์เซ็ต (Get Nightfall Schematic) -------------------------------------
-- ทุกวิธีข้างล่างลองเก็บจริงครบแล้ว 24 ก.ย. 2026 (ได้ 8 แบบ) บทเรียนที่ใช้ร่วมกัน:
--   prompt กดค้าง (Study 3 วิ, คันโยก 3 วิ, กุญแจ 0.5 วิ) ต้อง InputHoldBegin/End ตามเวลาจริง
--   fireproximityprompt ข้ามการกดค้าง เซิร์ฟไม่ให้ของ (ลองที่ Study 6 วิ ไม่ได้อะไร)
--   ของอยู่ไกลต้อง RequestStreamAroundAsync ก่อน ไม่งั้นมีแค่โครงโมเดล ไม่มี prompt
--   ต้องตรึงตัวทุกเฟรมระหว่างกดค้าง Money-Farm ดึงตัวกลับไปตีม็อบกลางคัน (ระยะหลุด 866-1390 stud) hold พัง
;(function()
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Puzzle = {
	-- Workspace.Map.Puzzles.Sickles Levers (สแกนตอนเขียน) ต้องดึงครบ 10 อัน เซิร์ฟตั้ง attribute SicklesSewerOpen ให้ผู้เล่น
	Levers = {
		Vector3.new(1941, 1323, -225), Vector3.new(758, 928, -365), Vector3.new(859, 1230, 477),
		Vector3.new(-1420, 159, 523), Vector3.new(1868, 690, -734), Vector3.new(-1692, 125, 603),
		Vector3.new(-1249, 1383, -1762), Vector3.new(654, 1052, -2165), Vector3.new(2755, 970, -821),
		Vector3.new(1053, 1552, -787),
	},
	SerpentBox = Vector3.new(899, 879, 739),
	-- กุญแจ 23 ดอกริมน้ำ Mistfall stream มาทีละกลุ่ม วาร์ปไล่จุดพวกนี้ให้เห็นครบ
	KeySweep = {
		Vector3.new(-345, 733, 1168), Vector3.new(-142, 733, 1088), Vector3.new(-58, 735, 911),
		Vector3.new(-213, 733, 844), Vector3.new(-89, 734, 758), Vector3.new(-320, 734, 666),
		Vector3.new(-389, 733, 603), Vector3.new(-217, 733, 461), Vector3.new(-483, 733, 545),
		Vector3.new(-692, 733, 552), Vector3.new(-766, 746, 279), Vector3.new(-169, 733, 199),
	},
	Statues = {
		Weapon = Vector3.new(-1382, 1010, 1109),
		Power = Vector3.new(-697, 1387, -1914),
		Fighting = Vector3.new(2083, 1544, -216),
	},
	-- ตีรูปปั้นจริง: Weapon ครบใน 37 วิ, Power 65 วิ, Fighting 45 วิ (หมัดละ ~1.4%) เผื่อเป็นสองเท่า
	StatueTimeout = 150,
	-- มุมยืนที่ลองต่อกันถ้า prompt ไม่ติด คันโยกบางอันติดผนัง ยืนหน้าเดียวกดไม่ติด 3 รอบ ย้ายข้างแล้วติด
	Offsets = {
		Vector3.new(0, 0.5, 3.5), Vector3.new(3.5, 0.5, 0), Vector3.new(0, 0.5, -3.5),
		Vector3.new(-3.5, 0.5, 0), Vector3.new(0, 4, 0),
	},
	SkillKeys = { Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V },
	Tobei = Vector3.new(1876, 659, -206),
	Togane = Vector3.new(1732, 694, -764),
}

local function have(name)
	return (Game.wallet()[name] or 0) > 0
end

local function stream(pos)
	local done = false
	task.spawn(function()
		pcall(function()
			LocalPlayer:RequestStreamAroundAsync(pos, 4)
		end)
		done = true
	end)
	-- บางครั้งไม่คืนเลย (เจอตอนทดสอบกุญแจ สคริปต์ค้างทั้งตัว) รอไม่เกิน 4 วิ
	local untilT = os.clock() + 4
	while not done and os.clock() < untilT do
		task.wait(0.1)
	end
end

local pin = {}
local function pinTo(cf)
	pin.cf = cf
	if not pin.conn then
		pin.conn = RunService.Heartbeat:Connect(function()
			local _, hrp = selfParts()
			if hrp and pin.cf then
				hrp.CFrame = pin.cf
				hrp.AssemblyLinearVelocity = Vector3.zero
			end
		end)
	end
end
-- ต้องปลดทุกทางออก เคยลืมปลดตอนสคริปต์ทดสอบพัง ตัวละครค้างที่รูปปั้นวาร์ปไปไหนไม่ได้อีกเลย
local function unpin()
	pin.cf = nil
	if pin.conn then
		pin.conn:Disconnect()
		pin.conn = nil
	end
end

local function promptPos(prompt)
	local p = prompt.Parent
	if p:IsA("BasePart") then
		return p.Position
	elseif p:IsA("Attachment") then
		return p.WorldPosition
	end
	return p:GetPivot().Position
end

-- คืน true ถ้า prompt ยิง Triggered (ฝั่ง client) ลองทีละมุมยืน
local function hold(prompt)
	-- line of sight เช็กแค่ฝั่ง client ปิดได้ คันโยกหลายอันมีกิ่งไม้บัง prompt ไม่ขึ้น
	prompt.RequiresLineOfSight = false
	for _, off in ipairs(Puzzle.Offsets) do
		if Runner.cancel or not prompt.Parent then
			return false
		end
		local p = promptPos(prompt)
		pinTo(CFrame.lookAt(p + off, p))
		task.wait(1.2)
		local fired = false
		local conn = prompt.Triggered:Connect(function()
			fired = true
		end)
		prompt:InputHoldBegin()
		task.wait(prompt.HoldDuration + 0.5)
		prompt:InputHoldEnd()
		task.wait(1)
		conn:Disconnect()
		if fired then
			return true
		end
	end
	return false
end

local function waitHave(name, seconds)
	local untilT = os.clock() + seconds
	while not have(name) and os.clock() < untilT do
		task.wait(0.2)
	end
	return have(name)
end

local function npcSpot(name)
	for _, region in ipairs(ReplicatedStorage.Ouwland.Content:GetChildren()) do
		local npcs = region:FindFirstChild("Npcs")
		local m = npcs and npcs:FindFirstChild(name, true)
		if m and m:IsA("ModuleScript") then
			local ok, def = pcall(require, m)
			local s = ok and type(def) == "table" and def.Spawns and def.Spawns[1]
			if typeof(s) == "CFrame" then
				return s.Position
			elseif typeof(s) == "Vector3" then
				return s
			end
		end
	end
end

local function goNpc(name, fallback)
	local at = npcSpot(name) or fallback
	if not at then
		return false
	end
	stream(at)
	pinTo(CFrame.new(at + Vector3.new(0, 1, 5), at))
	task.wait(1.5)
	return true
end

local function tagged(tag, test)
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		if test(inst) then
			return inst
		end
	end
end

local Methods = {}

function Methods.study(guide, schem)
	stream(guide.at)
	pinTo(CFrame.new(guide.at + Vector3.new(0, 4, 0)))
	local prompt
	local untilT = os.clock() + 8
	repeat
		task.wait(0.3)
		local prop = tagged("StudyProp", function(p)
			return p:GetAttribute("Item") == guide.item
		end)
		prompt = prop and prop:FindFirstChildWhichIsA("ProximityPrompt", true)
	until prompt or os.clock() > untilT
	if not prompt then
		return false, "ของตั้งโชว์ของ " .. guide.item .. " ไม่โหลด"
	end
	for _ = 1, 3 do
		if have(schem) or Runner.cancel then
			break
		end
		report("Study " .. guide.item, Theme.Accent)
		hold(prompt)
		waitHave(schem, 3)
	end
	return have(schem), "กด Study แล้วไม่ได้แบบ"
end

function Methods.sickles(guide, schem)
	if not LocalPlayer:GetAttribute("SicklesSewerOpen") then
		for i, pos in ipairs(Puzzle.Levers) do
			if Runner.cancel then
				return false, "ยกเลิกแล้ว"
			end
			report(string.format("ดึงคันโยก %d/%d", i, #Puzzle.Levers), Theme.Accent)
			stream(pos)
			pinTo(CFrame.new(pos + Vector3.new(0, 4, 3)))
			local lever
			local untilT = os.clock() + 8
			repeat
				task.wait(0.3)
				lever = tagged("SicklesLever", function(l)
					local a = l:FindFirstChild("A_")
					return (l:GetPivot().Position - pos).Magnitude < 3 and a ~= nil and a:FindFirstChild("LeverMain") ~= nil
				end)
			until lever or os.clock() > untilT
			local a = lever and lever:FindFirstChild("A_")
			local prompt = lever and lever:FindFirstChildWhichIsA("ProximityPrompt", true)
			-- On = ดึงแล้ว (จำฝั่ง client) ดึงซ้ำไม่ได้ prompt ปิดอยู่
			if prompt and not a:GetAttribute("On") then
				-- ติดแบบสุ่ม วัดจริง 10 อันรอบแรกติด 6 ต้องวนมุมยืนซ้ำ
				for _ = 1, 2 do
					if a:GetAttribute("On") or hold(prompt) then
						break
					end
				end
			end
		end
		local untilT = os.clock() + 5
		while not LocalPlayer:GetAttribute("SicklesSewerOpen") and os.clock() < untilT do
			task.wait(0.2)
		end
		if not LocalPlayer:GetAttribute("SicklesSewerOpen") then
			return false, "ดึงคันโยกแล้วท่อยังไม่เปิด (บางอันยังไม่ติด) กด GET อีกรอบเพื่อไล่ใหม่"
		end
	end
	return Methods.study(guide, schem)
end

function Methods.serpent(_, schem)
	-- เก็บตำแหน่งกุญแจทั้งหมดก่อน ลองทีละดอก ดอกจริงรอบทดสอบคือ Key8 ไม่รู้ว่าสุ่มใหม่ไหม เลยไม่ฝังชื่อไว้
	local keys = {}
	for _, p in ipairs(Puzzle.KeySweep) do
		stream(p)
		pinTo(CFrame.new(p + Vector3.new(0, 30, 0)))
		task.wait(0.4)
		for _, k in ipairs(CollectionService:GetTagged("SerpentKey")) do
			keys[k.Name] = k.Position
		end
	end
	local order = {}
	for name, pos in pairs(keys) do
		order[#order + 1] = { name = name, pos = pos }
	end
	table.sort(order, function(a, b)
		return a.name < b.name
	end)
	if #order == 0 then
		return false, "หากุญแจงูไม่เจอ"
	end
	Runner.triedKeys = Runner.triedKeys or {}
	for i, k in ipairs(order) do
		if have(schem) or Runner.cancel then
			break
		end
		if not Runner.triedKeys[k.name] then
			report(string.format("ลองกุญแจงู %d/%d (%s)", i, #order, k.name), Theme.Accent)
			if not have("Serpent Key") then
				stream(k.pos)
				pinTo(CFrame.new(k.pos + Vector3.new(0, 4, 0)))
				task.wait(1)
				local key = tagged("SerpentKey", function(x)
					return (x.Position - k.pos).Magnitude < 1
				end)
				local prompt = key and key:FindFirstChildWhichIsA("ProximityPrompt", true)
				if prompt then
					hold(prompt)
					waitHave("Serpent Key", 2)
				end
			end
			if have("Serpent Key") then
				stream(Puzzle.SerpentBox)
				pinTo(CFrame.new(Puzzle.SerpentBox + Vector3.new(0, 4, 0)))
				task.wait(1.5)
				local box = CollectionService:GetTagged("SerpentBox")[1]
				local prompt = box and box:FindFirstChildWhichIsA("ProximityPrompt", true)
				if not prompt then
					return false, "กล่องงูไม่โหลด"
				end
				hold(prompt)
				waitHave(schem, 3)
				-- กุญแจผิดดอกหักทิ้ง ("The key snaps in the lock") จำไว้ไม่ลองซ้ำในรอบเกมนี้
				Runner.triedKeys[k.name] = true
				if have("Serpent Key") and not have(schem) then
					return false, "กล่องไม่รับกุญแจ (ยืนไม่ถึงหรือเซิร์ฟปฏิเสธ)"
				end
			end
		end
	end
	return have(schem), "ลองกุญแจครบทุกดอกแล้วไม่ได้แบบ"
end

-- toolbar ที่มีไอเทม Combat (มือเปล่า) คืนเลขช่อง ไม่มีก็ใส่ช่องว่าง คืน true ตัวที่สองถ้าใส่เอง (ต้องถอดคืน)
-- รูปปั้น Fighting นับเฉพาะหมัดตอนถือ Combat ถอดทุกอย่าง (ช่อง 0) ต่อยแล้วไม่ขยับเลย 75 วิ
local ToolbarNames = { "One", "Two", "Three", "Four", "Five" }
local function combatId()
	local entry = equippedSlot().Inventory.Inventory:FindFirstChild("Combat")
	local id = entry and entry:FindFirstChild("Id")
	return id and id.Value
end
local function combatSlot()
	local id = combatId()
	if not id then
		return nil
	end
	local bar = equippedSlot().Inventory.Toolbar
	for i, n in ipairs(ToolbarNames) do
		if bar[n].Value == id then
			return i, false
		end
	end
	for i, n in ipairs(ToolbarNames) do
		if bar[n].Value == 0 then
			SignalEvent.ToServer("Toolbar_Equip", n, id)
			local untilT = os.clock() + 3
			while bar[n].Value ~= id and os.clock() < untilT do
				task.wait(0.1)
			end
			return bar[n].Value == id and i or nil, true
		end
	end
	return nil
end

function Methods.gauntlet(_, schem)
	local GSC = require(ReplicatedStorage.CAM.Client.Controllers.GauntletStatuesController)
	local ratios = {}
	local original = GSC.handle
	-- เซิร์ฟส่งความคืบหน้าแต่ละตัว (Type, Ratio 0-1) มาทาง WorldEvents.GauntletStatue ทุกครั้งที่ตีโดน
	GSC.handle = function(p)
		ratios[p.Type] = p.Ratio
		return original(p)
	end
	local cam = workspace.CurrentCamera
	local camType = cam.CameraType
	local tempCombat
	local ok, res, why = pcall(function()
		if not goNpc("Stonemason Tobei", Puzzle.Tobei) then
			return false, "หา Stonemason Tobei ไม่เจอ"
		end
		SignalEvent.ToServer("GauntletStatuesBegin")
		task.wait(1.5)
		for _, kind in ipairs({ "Weapon", "Power", "Fighting" }) do
			if Runner.cancel then
				return false, "ยกเลิกแล้ว"
			end
			local at = Puzzle.Statues[kind]
			stream(at)
			pinTo(CFrame.new(at + Vector3.new(0, 8, 0)))
			task.wait(1.5)
			local statue = tagged("GauntletStatue", function(s)
				return s:GetAttribute("type") == kind
			end)
			if not statue then
				return false, "รูปปั้น " .. kind .. " ไม่โหลด"
			end
			local spos = statue:GetPivot().Position
			local look = statue:GetPivot().LookVector
			local stand = spos + look * 4
			pinTo(CFrame.lookAt(stand, Vector3.new(spos.X, stand.Y, spos.Z)))
			if kind == "Fighting" then
				local slot, added = combatSlot()
				tempCombat = tempCombat or added
				if not slot then
					return false, "ใส่ Combat (มือเปล่า) ขึ้น toolbar ไม่ได้ toolbar เต็ม"
				end
				equipSlot(slot)
			else
				equipSlot(primarySlot())
			end
			task.wait(1)
			-- คลิกต้องโดนตัวรูปปั้นบนจอ ล็อกกล้องมองรูปปั้นจากหลังตัวเรา
			cam.CameraType = Enum.CameraType.Scriptable
			local untilT = os.clock() + Puzzle.StatueTimeout
			local k = 0
			while (ratios[kind] or 0) < 1 and os.clock() < untilT and not Runner.cancel do
				cam.CFrame = CFrame.new(stand + look * 8 + Vector3.new(0, 3, 0), spos)
				report(string.format("ตีรูปปั้น %s %d%%", kind, math.floor((ratios[kind] or 0) * 100)), Theme.Accent)
				if kind == "Power" then
					k = k % #Puzzle.SkillKeys + 1
					local p = cam:WorldToViewportPoint(spos)
					VIM:SendMouseMoveEvent(p.X, p.Y, game)
					VIM:SendKeyEvent(true, Puzzle.SkillKeys[k], false, game)
					task.wait(0.1)
					VIM:SendKeyEvent(false, Puzzle.SkillKeys[k], false, game)
					task.wait(1.2)
				else
					swingAt(spos)
					task.wait(0.3)
				end
			end
			cam.CameraType = camType
			if (ratios[kind] or 0) < 1 then
				return false, string.format("ตีรูปปั้น %s ไม่ครบใน %d วิ (%d%%)", kind, Puzzle.StatueTimeout,
					math.floor((ratios[kind] or 0) * 100))
			end
		end
		goNpc("Stonemason Tobei", Puzzle.Tobei)
		SignalEvent.ToServer("GauntletGiveSchematic")
		return waitHave(schem, 4), "Tobei ไม่ให้แบบ (รูปปั้นอาจยังตื่นไม่ครบ)"
	end)
	GSC.handle = original
	cam.CameraType = camType
	equipSlot(primarySlot())
	if tempCombat then
		local id = combatId()
		for _, n in ipairs(ToolbarNames) do
			if id and equippedSlot().Inventory.Toolbar[n].Value == id then
				SignalEvent.ToServer("Toolbar_Equip", n, 0)
			end
		end
	end
	if not ok then
		return false, tostring(res)
	end
	return res, why
end

function Methods.trade(guide, schem)
	if not have(guide.give) then
		-- Lost Cape ตกได้เฉพาะเบ็ด CatchTier "Items" (Legendary) เบ็ดอื่นตกไปก็ไม่มีวันได้ ห้ามปล่อยตกค้าง
		if not have("Legendary Fishing Rod") then
			return false, "ต้องมี " .. guide.give .. " ก่อน · ได้จากตกปลาด้วย Legendary Fishing Rod (ยังไม่มี)"
				.. " หรือหีบ Lost Chest 0.9%"
		end
		local ok, why = Runner.fish({ [guide.give] = 1 }, Runner.FishSpot, "หา " .. guide.give .. " · ")
		if not ok then
			return false, why
		end
	end
	if not goNpc(guide.npc) then
		return false, "หา " .. guide.npc .. " ไม่เจอ"
	end
	-- ตรงกับปุ่ม "Hand it over" ในบทพูด (SeriesTradeActions.CapeTrade)
	SignalEvent.ToServer("SeriesTrade", guide.key)
	return waitHave(schem, 4), guide.npc .. " ไม่รับของ"
end

function Methods.capstone(guide, schem)
	local Series = require(ReplicatedStorage.CAM.Global.Series)
	local missing = {}
	for _, name in ipairs(Series.CapstoneGate(guide.set)) do
		if not have(name) then
			missing[#missing + 1] = name
		end
	end
	if #missing > 0 then
		-- แบบอื่นที่ติ๊กไว้ในคิวอาจยังไม่ถึงตา ให้คิวไปทำอันนั้นก่อนแล้ววนกลับมา (ใช้ทางเดียวกับรอบอสเกิด)
		if Runner.canYield and Runner.canYield(schem) then
			return false, Runner.RESPAWN, 20
		end
		return false, string.format("Togane วาดให้เมื่อมีแบบ %s ครบ 9 ชิ้น ยังขาด: %s", guide.set,
			table.concat(missing, ", "):gsub(" Schematic", ""))
	end
	if not goNpc("Blacksmith Togane", Puzzle.Togane) then
		return false, "หา Blacksmith Togane ไม่เจอ"
	end
	-- ปุ่ม "The set drawings" -> ชื่อเซ็ต (SeriesCapstoneActions) ได้ Top + Bottom พร้อมกัน
	SignalEvent.ToServer("SeriesCapstone", guide.set)
	return waitHave(schem, 4), "Togane ไม่ให้แบบ (แบบอื่นในเซ็ตยังไม่ครบ?)"
end

function Runner.schematic(name)
	local guide = Game.SetSchematics[name]
	if not guide or not Methods[guide.how] then
		return false, "ยังไม่รู้วิธีหา " .. name
	end
	if have(name) then
		return true
	end
	-- ลูปสู้ / Kill Aura / Auto Skill เขียน CFrame กับถือดาบแย่งตลอด ปิดก่อนแล้วคืนทีหลัง เหมือน Runner.fish
	attackRow.set(false)
	mobOnlyRow.set(false)
	autoAttack.on = false
	local auraWasOn = Runner.auraOn()
	if auraWasOn then
		Runner.setAura(false)
	end
	local skillWasOn = Runner.skillOn and Runner.skillOn()
	if skillWasOn then
		Runner.setSkill(false)
	end
	local ok, res, why, extra = pcall(Methods[guide.how], guide, name)
	unpin()
	if auraWasOn then
		Runner.setAura(true)
	end
	if skillWasOn then
		Runner.setSkill(true)
	end
	if not ok then
		return false, tostring(res)
	end
	if Runner.cancel then
		return false, "ยกเลิกแล้ว"
	end
	if res then
		return true
	end
	return false, why, extra
end
end)()

-- Get Nightfall Craft --------------------------------------------------------
-- หน้าสูตรแบบโต๊ะช่าง Togane ในเกม: ทุกสูตรแยกแถว (T1 ของแต่ละดาบฐาน / T2 / T3) รายละเอียดขวาเป็นขั้นตอนตามลำดับ
-- ข้อมูลสูตรจาก Crafting.Definitions (อ่าน 24 ก.ย. 2026):
--   T1 อาวุธ = ดาบฐาน V2 1 เล่ม (Nightfall Katana มี 4 แบบ: Thundercloud / Tidal / Tornadic / Volcanic Katana)
--     + Scraps 1,000 + Silk 1,000 + 1,000,000 Wen · T1 ชุด = วัสดุเซ็ต 5/5/5 แทนดาบฐาน
--   ดาบฐาน V2 ตีได้ที่ Togane ในหอคอยเท่านั้น: ดาบธรรมดา (Flame Katana → Volcanic) + 90,000 แต้ม + Mythic Ore 10
--     + Scraps 500 + Silk 300 · แต้มอยู่แค่รอบนั้น ต้องได้ครบ 90,000 ในรอบเดียว
--   T2 = ชิ้น T1 + Scraps/Silk 750 + วัสดุเซ็ต 6+6 + 750,000 Wen · T3 = ชิ้น T2 + วัสดุเซ็ต 12+12 + 1,500,000 Wen
-- GET ทำตามลำดับที่ผู้ใช้สั่ง: แบบพิมพ์ → ดาบฐาน (ของธรรมดา → อัปในดันเจี้ยน) → วัสดุเพิ่ม → Wen (ดันเจี้ยน Wen 100% จบชั้น 70)
;(function()
local SeriesMod = require(ReplicatedStorage.CAM.Global.Series)
local Rarities = require(ReplicatedStorage.CAM.Global.Rarities)
local okDefs, ItemDefs = pcall(require, ReplicatedStorage.CAM.Global.Collectibles.Items)
ItemDefs = okDefs and ItemDefs or {}

local Craft = {
	Pieces = {
		"Nightfall Katana", "Nightfall Serpent Katana", "Nightfall Scythe", "Nightfall Claws", "Nightfall Gauntlet",
		"Nightfall Sickles", "Nightfall Axe and Mace", "Nightfall Mask", "Nightfall Cape", "Nightfall Top",
		"Nightfall Bottom",
	},
	-- Series.TierMultiplier ของเกม { 1, 1.15, 1.3 } สเตตัสของชิ้นเซ็ตคูณตามขั้น
	TierMult = SeriesMod.TierMultiplier or { 1, 1.15, 1.3 },
	MaxTier = SeriesMod.MaxTier or 3,
	-- วัสดุเซ็ต 6 ชนิด (Nightfall 3 + Firstlight 3) Togane แลกกันได้ 1:1 ทุกคู่ ("Any of the six for any other")
	SetMats = {},
	WalletShown = { "Wen", "Metal Scraps", "Silk Thread", "Mythic Refinement Ore", "Nightfall Forged Ingot",
		"Nightfall Weaver's Cloth", "Nightfall Reinforced Plating" },
	-- หอคอย: Wen 1,000 ต่อ 2,500 แต้ม (Shop.itemsforsale ฝั่งหอคอย ดู Ouwi.Rewards)
	WenPerPoint = 1000 / 2500,
}
for _, name in ipairs(SeriesMod.Materials()) do
	Craft.SetMats[name] = true
end

local function wallet()
	return Game.wallet()
end

-- ทุกสูตรของชิ้นเซ็ต เรียงแบบหน้าช่าง: ชิ้น > T1 (ทุกดาบฐาน) > T2 > T3 · สูตรไม่เปลี่ยนระหว่างเล่น แคชครั้งเดียว
function Craft.recipes()
	if Craft.list then
		return Craft.list
	end
	local list, byId = {}, {}
	for _, piece in ipairs(Craft.Pieces) do
		local rs = {}
		for id, r in pairs(Crafting and Crafting.Definitions or {}) do
			if r.result == piece and r.station == "Ouwland" then
				rs[#rs + 1] = { id = id, recipe = r, piece = piece, tier = r.tier or 1 }
			end
		end
		table.sort(rs, function(a, b)
			if a.tier ~= b.tier then
				return a.tier < b.tier
			end
			return a.id < b.id
		end)
		for _, e in ipairs(rs) do
			local first = e.recipe.required and e.recipe.required[1]
			-- ดาบฐาน = ของชิ้นแรกที่ไม่ใช่ชิ้นเดิม (อัปขั้น) และไม่ใช่วัสดุเซ็ต (T1 ชุด)
			if first and first.name ~= piece and not Craft.SetMats[first.name] then
				e.base = first.name
			end
			list[#list + 1] = e
			byId[e.id] = e
		end
	end
	Craft.list, Craft.byId = list, byId
	return list
end

-- ชิ้นที่มีอยู่ ขั้นสูงสุด (ถือซ้ำได้หลายชิ้น Tier เก็บในค่า Tier ของโฟลเดอร์ไอเทม ไม่มี = 1)
function Craft.owned(name)
	local bag = equippedSlot().Inventory.Inventory
	local tier
	for _, e in ipairs(bag:GetChildren()) do
		if e.Name == name then
			local t = e:FindFirstChild("Tier")
			tier = math.max(tier or 0, t and t.Value or 1)
		end
	end
	return tier
end

-- สูตรหอคอยที่ตีดาบฐานเล่มนี้ (Damascus Sickles มีสองสูตร: Sickles / Blood Sickles เลือกเล่มที่มีอยู่แล้วก่อน)
function Craft.v2Of(baseName)
	local pick
	for id, r in pairs(Crafting and Crafting.Definitions or {}) do
		if r.result == baseName and r.station == "Ouwigahara" then
			local raw = r.required and r.required[1]
			if not pick or (raw and itemCount(raw.name) > 0) then
				pick = { id = id, recipe = r }
			end
		end
	end
	return pick
end

-- T1 ที่จะใช้ตอนต้องตีขั้นล่างให้เอง: ดาบฐานที่มีอยู่แล้ว > ของธรรมดาของดาบฐานที่มี > สูตรแรก
function Craft.pickTier(piece, tier)
	local best, score
	for _, e in ipairs(Craft.recipes()) do
		if e.piece == piece and e.tier == tier then
			local s = 0
			if e.base and itemCount(e.base) > 0 then
				s = 2
			elseif e.base then
				local v2 = Craft.v2Of(e.base)
				local raw = v2 and v2.recipe.required and v2.recipe.required[1]
				s = raw and itemCount(raw.name) > 0 and 1 or 0
			end
			if not score or s > score then
				best, score = e, s
			end
		end
	end
	return best
end

-- Wen ที่ต้องใช้ซื้อของที่ขาด (ราคาจากแผนซื้อจริงของ Game.plan) 0 = มีครบหรือไม่ต้องใช้เงิน
function Craft.buyCost(name, need)
	if itemCount(name) >= need then
		return 0
	end
	local w = table.clone(wallet())
	w.Wen = math.huge
	local o = Game.newPlan()
	if Game.plan(name, need, w, o) then
		return 0
	end
	return o.spend.Wen or 0
end

-- สถานะสั้นของแถว
function Craft.state(e)
	local owned = Craft.owned(e.piece) or 0
	if owned >= e.tier then
		return string.format("มีแล้ว T%d", owned), Theme.Good
	end
	if e.tier > 1 and owned < e.tier - 1 then
		return string.format("ต้องมี T%d ก่อน · ตีต่อกันให้", e.tier - 1), Theme.Warn
	end
	if e.base and itemCount(e.base) == 0 then
		return "ขาดดาบฐาน · ต้องอัปในดันเจี้ยน", Theme.Warn
	end
	if (wallet().Wen or 0) < ((e.recipe.price or {}).Wen or 0) then
		return "ของพร้อมไหม ดูขวา · ขาด Wen", Theme.Accent
	end
	return "ตีได้ / หาของที่ขาดให้", Theme.Accent
end

-- วัสดุเซ็ตที่สูตรกินทั้งหมด (ช่อง required ของ T1 ชุด + additionalMaterials)
function Craft.setNeeds(recipe)
	local mats = {}
	for _, list in ipairs({ recipe.required or {}, recipe.additionalMaterials or {} }) do
		for _, m in ipairs(list) do
			if Craft.SetMats[m.name] then
				mats[m.name] = (mats[m.name] or 0) + m.amount
			end
		end
	end
	return mats
end

-- พอไหม: วัสดุเซ็ตนับรวมทั้ง 6 ชนิด (แลกกันได้ 1:1)
function Craft.setEnough(mats)
	local w = wallet()
	local need, pool = 0, 0
	for _, n in pairs(mats) do
		need += n
	end
	for name in pairs(Craft.SetMats) do
		pool += w[name] or 0
	end
	return pool >= need, pool, need
end

-- แลกวัสดุเซ็ตที่ขาดจากชนิดที่เหลือเกิน ที่ Togane (MaterialExchange { Give, Take, Amount } เหมือนหน้า Swap materials)
function Craft.balance(mats)
	local w = wallet()
	local swaps = {}
	for take, need in pairs(mats) do
		local short = need - (w[take] or 0)
		for give in pairs(Craft.SetMats) do
			if short <= 0 then
				break
			end
			local spare = (w[give] or 0) - (mats[give] or 0)
			if give ~= take and spare > 0 then
				local n = math.min(spare, short)
				swaps[#swaps + 1] = { Give = give, Take = take, Amount = n }
				w[give] -= n
				w[take] = (w[take] or 0) + n
				short -= n
			end
		end
	end
	if #swaps == 0 then
		return true
	end
	local spawn = npcSpawnPoint("Blacksmith Togane")
	local _, hrp = selfParts()
	if not (spawn and hrp) then
		return false, "หา Blacksmith Togane ไม่เจอ"
	end
	placeAt(hrp, CFrame.new(spawn.pos + Vector3.new(0, 3, 5), spawn.pos), "forge")
	local npc
	for _ = 1, 40 do
		npc = findLiveNpc("Blacksmith Togane")
		if npc then
			break
		end
		task.wait(0.3)
	end
	if npc then
		local pos = npc:GetPivot().Position
		placeAt(hrp, CFrame.new(pos + Vector3.new(0, 0, 4), pos), "forge")
		task.wait(0.6)
	end
	local SignalFunction = require(ReplicatedStorage.Communication.ServerAndClient.Signals.SignalFunction)
	for _, s in ipairs(swaps) do
		report(string.format("แลก %d %s → %s ที่ Togane", s.Amount, s.Give, s.Take), Theme.Accent)
		local ok, res = pcall(SignalFunction.ToServer, "MaterialExchange", s)
		if not ok or res ~= true then
			return false, "Togane ไม่ยอมแลก " .. s.Give .. " → " .. s.Take
		end
		task.wait(0.5)
	end
	return true
end

-- ประมาณรอบดันเจี้ยนที่ต้องลงเพื่อ Wen ที่ขาด จากแต้มรอบล่าสุดที่ Auto-Dungeon จดไว้
function Craft.wenRuns(short)
	local last = Game.persist.data.lastRun
	local perRun = last and last.points and last.points * Craft.WenPerPoint or 0
	if short <= 0 or perRun <= 0 then
		return nil, perRun
	end
	return math.ceil(short / perRun), perRun
end

-- ตีสูตรนี้ให้ได้ หาทุกอย่างที่ขาดตามลำดับ · ค่าคืน Runner.TOWER + goal = ต้องลงหอคอยก่อน
-- (คิวเก็บงานค้างไว้ Auto-Dungeon พาไปแล้วกลับมาทำต่อจากขั้นที่ค้าง)
Runner.TOWER = "__tower"

-- ของที่ซื้อด้วย Wen (Scraps / Silk): เงินไม่พอซื้อ = ลงดันเจี้ยนเอา Wen ก่อน
local function ensureBought(name, need, say)
	if itemCount(name) >= need then
		return true
	end
	-- ซื้อเองเฉพาะผู้ใช้เปิดไว้ในแผง (ค่าเริ่มปิด) ผู้ใช้เจอ 25 ก.ย. 2026: กด GET แล้ววาร์ปไปซื้อ Silk ที่ Ginzo ทันที
	-- ทั้งที่คิดว่ามีครบ (แผงเดิมติ๊ก ✓ แยกขั้น 2 กับ 3 แต่ต้องใช้รวมกัน) ขาดแล้วหยุดบอกยอด ให้ผู้ใช้หาเอง
	if not Game.persist.data.craftBuy then
		return false, string.format("%s ขาด %s (มี %s ต้องใช้ %s) · ไม่ได้เปิด \"ซื้อที่ Ginzo\"", name,
			comma(need - itemCount(name)), comma(itemCount(name)), comma(need))
	end
	local cost = Craft.buyCost(name, need)
	if cost > (wallet().Wen or 0) then
		say(string.format("Wen ไม่พอซื้อ %s (ต้อง %s) · ลงดันเจี้ยนเอา Wen", name, comma(cost)))
		return false, Runner.TOWER, { kind = "wen", need = cost }
	end
	say(string.format("หา %s %s/%s", name, comma(itemCount(name)), comma(need)))
	return Runner.obtain(name, need)
end

-- carry = งานคั่นของขั้นบนที่ส่งลงมา (ดู fillerJobs) ทำสลับกับงานของขั้นนี้ได้
function Runner.craftRecipe(id, carry)
	Craft.recipes()
	local e = Craft.byId[id]
	if not e then
		return false, "ไม่พบสูตร " .. tostring(id)
	end
	local r = e.recipe
	local owned = Craft.owned(e.piece) or 0
	if owned >= e.tier then
		return true
	end
	local function say(text)
		report(string.format("%s T%d · %s", e.piece, e.tier, text), Theme.Accent)
	end

	local mats = Craft.setNeeds(r)
	-- งานที่ไม่ใช้ของฐาน (แบบพิมพ์ / วัสดุเซ็ต) ส่งลงไปให้การตีขั้นล่างใช้เป็นงานคั่นตอนรอบอสเกิดได้ด้วย
	-- (ตี T3 แต่ยังไม่มี T1: ระหว่างรอบอสดรอปดาบ ไปฟาร์มวัสดุเซ็ตของ T2/T3 ไว้ก่อน)
	local function fillerJobs()
		local jobs = {}
		for _, schem in ipairs(r.keep or {}) do
			jobs[#jobs + 1] = {
				name = schem,
				done = function()
					return (wallet()[schem] or 0) > 0
				end,
				run = function()
					say("1/4 หา " .. schem)
					local ok, why, extra = Runner.schematic(schem)
					if not ok and why ~= Runner.RESPAWN then
						why = schem .. ": " .. tostring(why)
					end
					return ok, why, extra
				end,
			}
		end
		-- วัสดุเซ็ต: ฟาร์มหีบบอส (ลูป Auto-Money-Farm) ถ้ามีงานรอบอสเกิดอยู่ ฟาร์มแค่ถึงเวลาเกิดแล้วกลับไป
		if next(mats) then
			local function prog()
				local _, pool, need = Craft.setEnough(mats)
				return string.format("วัสดุเซ็ต %d/%d", math.min(pool, need), need)
			end
			jobs[#jobs + 1] = {
				name = "วัสดุเซ็ต",
				filler = true,
				done = function()
					return (Craft.setEnough(mats))
				end,
				run = function(deadline)
					say("3/4 ฟาร์มหีบบอสหาวัสดุเซ็ต · " .. prog())
					local ok, why = Runner.moneyUntil(function()
						return Craft.setEnough(mats) or (deadline ~= nil and os.clock() >= deadline)
					end, function(t)
						say("3/4 " .. prog() .. (deadline and string.format(" · กลับไปตีบอสในอีก %d วิ",
							math.max(0, math.floor(deadline - os.clock()))) or "") .. " · " .. t)
					end)
					return ok, why or "หยุดก่อนวัสดุเซ็ตครบ"
				end,
			}
		end
		return jobs
	end

	-- ขั้นล่างยังไม่มี: ตีขั้นล่างก่อน (T3 ต้องมี T2, T2 ต้องมี T1)
	if e.tier > 1 and owned < e.tier - 1 then
		local lower = Craft.pickTier(e.piece, e.tier - 1)
		if not lower then
			return false, "ไม่พบสูตร T" .. (e.tier - 1)
		end
		say("ต้องมี T" .. lower.tier .. " ก่อน")
		local down = fillerJobs()
		for _, j in ipairs(carry or {}) do
			down[#down + 1] = j
		end
		local ok, why, extra = Runner.craftRecipe(lower.id, down)
		if not ok then
			return false, why, extra
		end
	end

	-- ขั้น 1-3 เป็นงานย่อยที่ไม่ขึ้นต่อกัน ทำสลับกันได้: ผู้ใช้สั่ง ตีบอสดรอปดาบตายแล้วรอเกิดใหม่ (บอส 300 วิ)
	-- อย่ายืนรอเปล่า ไปหาของอย่างอื่นที่สูตรต้องใช้ก่อน ใกล้เวลาเกิดค่อยกลับไปตี (ทางเดียวกับคิว Get Weapons:
	-- Runner.farm ถาม Runner.canYield ก่อนยืนรอ ตอบ true = คืน RESPAWN + วิที่เหลือ)
	-- เรียงตามที่ผู้ใช้สั่ง: ดาบฐานก่อน → แบบพิมพ์ → วัสดุเพิ่ม
	local jobs = {}
	local v2
	if e.base and itemCount(e.base) < 1 then
		v2 = Craft.v2Of(e.base)
		local raw = v2 and v2.recipe.required[1] or { name = e.base, amount = 1 }
		jobs[#jobs + 1] = {
			name = raw.name,
			done = function()
				return itemCount(raw.name) >= raw.amount
			end,
			run = function()
				say(v2 and string.format("2/4 หา %s (ดาบธรรมดาที่จะอัปเป็น %s)", raw.name, e.base) or ("2/4 หา " .. e.base))
				local ok, why, extra = Runner.obtain(raw.name, raw.amount)
				if not ok and why ~= Runner.RESPAWN then
					why = raw.name .. ": " .. tostring(why)
				end
				return ok, why, extra
			end,
		}
		for _, m in ipairs(v2 and v2.recipe.additionalMaterials or {}) do
			if m.name ~= "Mythic Refinement Ore" then
				jobs[#jobs + 1] = {
					name = m.name,
					done = function()
						return itemCount(m.name) >= m.amount
					end,
					run = function()
						return ensureBought(m.name, m.amount, function(t)
							say("2/4 " .. t .. " (ใช้อัปดาบฐาน)")
						end)
					end,
				}
			end
		end
	end
	for _, j in ipairs(fillerJobs()) do
		jobs[#jobs + 1] = j
	end
	for _, m in ipairs(r.additionalMaterials or {}) do
		if not Craft.SetMats[m.name] then
			-- ดาบฐานยังไม่ได้อัป = Scraps / Silk ก้อนนี้จะโดนสูตรอัปกินไปก่อน ซื้อเผื่อรวมกันทีเดียว
			local function target()
				local extra = 0
				for _, x in ipairs(v2 and itemCount(e.base) < 1 and v2.recipe.additionalMaterials or {}) do
					if x.name == m.name then
						extra = x.amount
					end
				end
				return m.amount + extra
			end
			jobs[#jobs + 1] = {
				name = m.name,
				done = function()
					return itemCount(m.name) >= target()
				end,
				run = function()
					return ensureBought(m.name, target(), function(t)
						say("3/4 " .. t)
					end)
				end,
			}
		end
	end

	for _, j in ipairs(carry or {}) do
		jobs[#jobs + 1] = j
	end

	-- วนทำงานที่พร้อม · งานที่รอบอสเกิดพักไว้ · งานที่ต้องลงดันเจี้ยน (Wen ไม่พอซื้อ) พักไว้ ไปรวบทีเดียวตอนท้าย
	local waitUntil, tower = {}, nil
	local pending, deferred = {}, {}
	for _, j in ipairs(jobs) do
		if not j.done() then
			pending[#pending + 1] = j
		end
	end
	-- งานคั่นตอนเหลือแต่รอบอสเกิด: ฟาร์มบอสตัวอื่น (ลูป Auto-Money-Farm) ได้ Wen จาก Coin Pouch + Mythic Ore
	-- กับวัสดุเซ็ตจากหีบบอส ถึงเวลาเกิดแล้วกลับไป · ผู้ใช้เจอจริง: ยืนรอ Rengu 5 นาทีเพราะ Scraps / Silk
	-- ต้องรอ Wen (1,000 ชิ้น = 500,000 Wen) งานอื่นเลยไม่เหลือ
	local function farmOthers(deadline)
		local w0 = wallet().Wen or 0
		say(string.format("รอบอสเกิดอีก %d วิ · ไปฟาร์มบอสตัวอื่นก่อน", math.floor(deadline - os.clock())))
		local ok, why = Runner.moneyUntil(function()
			return os.clock() >= deadline
		end, function(t)
			say(string.format("รอบอสเกิดอีก %d วิ · ฟาร์มบอสตัวอื่น Wen +%s · %s", math.max(0, math.floor(deadline - os.clock())),
				comma((wallet().Wen or 0) - w0), t))
		end)
		return ok, why
	end
	local current
	local prevYield = Runner.canYield
	-- Runner.farm ถามก่อนยืนรอบอสเกิด: มีงานอื่นพร้อม หรือฟาร์มบอสตัวอื่นคั่นได้ = ตอบ true
	-- ยกเว้นแบบพิมพ์ Top/Bottom (capstone ถามด้วยชื่อแบบ) ไม่งั้นวนฟาร์มคั่นทุก 20 วิไม่จบ
	Runner.canYield = function(item)
		for _, j in ipairs(pending) do
			if j ~= current and (waitUntil[j] or 0) <= os.clock() then
				return true
			end
		end
		if type(item) == "string" and not item:find("Schematic$") then
			return true
		end
		return prevYield ~= nil and prevYield(item) or false
	end
	local function finish(...)
		Runner.canYield = prevYield
		return ...
	end
	while #pending > 0 do
		if Runner.cancel then
			return finish(false, "ยกเลิกแล้ว")
		end
		local job, soonest
		for _, j in ipairs(pending) do
			if (waitUntil[j] or 0) <= os.clock() then
				job = job or j
			elseif not soonest or waitUntil[j] < waitUntil[soonest] then
				soonest = j
			end
		end
		if not job and soonest and waitUntil[soonest] - os.clock() > 20 then
			-- ไม่มีอะไรทำนอกจากรอ: ฟาร์มบอสตัวอื่นจนถึงเวลาเกิด แล้วลองงานที่พักไว้เพราะเงินไม่พออีกรอบ
			local ok, why = farmOthers(waitUntil[soonest])
			if not ok and not Runner.cancel and os.clock() < waitUntil[soonest] then
				return finish(false, why)
			end
			for _, j in ipairs(deferred) do
				pending[#pending + 1] = j
			end
			table.clear(deferred)
		else
			-- เหลือไม่ถึง 20 วิ ไปยืนรอที่จุดเกิดเลย (canYield ตอบ true ก็แค่วนกลับมาที่นี่)
			job = job or soonest
			waitUntil[job] = nil
			current = job
			local deadline = soonest and soonest ~= job and waitUntil[soonest] or nil
			local okRun, ok, why, extra = pcall(job.run, deadline)
			current = nil
			if not okRun then
				return finish(false, tostring(ok))
			end
			if why == Runner.RESPAWN and not Runner.cancel then
				waitUntil[job] = os.clock() + math.max(10, tonumber(extra) or 60)
				say(string.format("บอสของ %s ตาย รอเกิดใหม่ ~%d วิ · ไปหาของอื่นก่อน", job.name,
					math.floor(waitUntil[job] - os.clock())))
			elseif why == Runner.TOWER then
				tower = tower or extra
				table.remove(pending, table.find(pending, job))
				deferred[#deferred + 1] = job
			elseif job.done() then
				table.remove(pending, table.find(pending, job))
			elseif not ok then
				return finish(false, why, extra)
			elseif not (job.filler and deadline) then
				-- บอกว่าสำเร็จแต่ของยังไม่ครบ วนต่อได้แค่ 3 ครั้งกันค้าง (ฟาร์มวัสดุเซ็ตที่หยุดเพราะถึงเวลากลับไปตีบอสไม่นับ)
				job.tries = (job.tries or 0) + 1
				if job.tries >= 3 then
					return finish(false, job.name .. " หาแล้วของไม่เพิ่ม")
				end
			end
		end
		task.wait(0.2)
	end
	-- งานที่พักไว้แต่ตอนนี้ครบแล้ว (ฟาร์มบอสคั่นได้เงินพอซื้อ) ไม่ต้องลงดันเจี้ยน
	local stillShort = false
	for _, j in ipairs(deferred) do
		stillShort = stillShort or not j.done()
	end
	if not stillShort then
		tower = nil
	end
	Runner.canYield = prevYield
	-- ลงดันเจี้ยนรอบไหนก่อน: ของที่ต้องพกเข้าไปอัปดาบฐานครบ = รอบอัปดาบ (แต้มที่เหลือเป็น Wen อยู่แล้ว)
	-- ยังขาด (Wen ไม่พอซื้อ Scraps / Silk ของสูตรอัป) = รอบ Wen ก่อน
	if v2 and itemCount(e.base) < 1 then
		local ready = true
		for _, m in ipairs(Game.recipeInputs(v2.recipe)) do
			if m.name ~= "RunPoints" and m.name ~= "Mythic Refinement Ore" and itemCount(m.name) < m.amount then
				ready = false
			end
		end
		if ready then
			say(string.format("2/4 อัป %s → %s ในดันเจี้ยน (90,000 แต้ม + Mythic Ore ขาดก็แลกแต้มให้)",
				v2.recipe.required[1].name, e.base))
			return false, Runner.TOWER, { kind = "v2", recipe = v2.id }
		end
	end
	if tower then
		return false, Runner.TOWER, tower
	end
	if Runner.cancel then
		return false, "ยกเลิกแล้ว"
	end
	local okSwap, whySwap = Craft.balance(mats)
	if not okSwap then
		return false, whySwap
	end

	-- 4 Wen ค่าตี: ลงดันเจี้ยน แต้มเป็น Wen 100% จบชั้น 70 วนจนพอ
	local price = (r.price or {}).Wen or 0
	if (wallet().Wen or 0) < price then
		local short = price - (wallet().Wen or 0)
		local runs = Craft.wenRuns(short)
		say(string.format("4/4 ขาด %s Wen · ลงดันเจี้ยน (Wen 100%%, จบชั้น 70)%s", comma(short),
			runs and string.format(" อีกราว %d รอบ", runs) or ""))
		return false, Runner.TOWER, { kind = "wen", need = short }
	end

	say("ตีที่ Togane")
	return Runner.craftAt(id, r)
end

-- แผง ------------------------------------------------------------------------

-- ข้อมูลสูตร (Game.plan / recipesFor) require โมดูลเกมกลางทาง identity หล่นเป็น 2 แล้วสร้างป้ายพัง
-- (เจอตอนเปิดแผงครั้งแรก: "lacking capability Plugin") คืนค่าก่อนแตะ GUI ทุกครั้ง
local function fixIdentity()
	if setthreadidentity and Game.loadIdentity then
		setthreadidentity(Game.loadIdentity)
	end
end

local craftUI = makePanel("Get Nightfall Craft / ตีเซ็ต", true)
craftUI.search.Visible = false
craftUI.filterRow.Visible = false
craftUI.walletBar = Game.walletBar(craftUI.panel, UDim2.fromOffset(0, 22), Craft.WalletShown)
-- ซ้าย = รายการสูตร 42% ขวา = ขั้นตอน เลข 48 = ใต้แถบเงิน, -104 = 48 + ปุ่ม GET 34 + สถานะ 14 + ช่องไฟ
craftUI.list.Position = UDim2.fromOffset(0, 48)
craftUI.list.Size = UDim2.new(0.42, -6, 1, -104)
local detail = new("ScrollingFrame", {
	Position = UDim2.new(0.42, 6, 0, 48),
	Size = UDim2.new(0.58, -6, 1, -104),
	BackgroundColor3 = Theme.Row,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = Theme.Stroke,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = craftUI.panel,
}, {
	corner(10),
	new("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}),
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local getLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Text = "GET",
	TextColor3 = Theme.Dim,
	TextSize = 15,
	FontFace = font(Enum.FontWeight.SemiBold),
})
local getBtn = new("TextButton", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = Theme.Raised,
	AutoButtonColor = false,
	Text = "",
	Parent = craftUI.panel,
}, { capsule(), getLabel })

-- queue = id สูตร เรียงตามที่ติ๊ก
local queue, rows, selected = {}, {}, nil

function craftUI.queueStatus(text, color)
	craftUI.setStatus((craftUI.progress or "") .. text, color)
end

local function label(e)
	return string.format("%s T%d", e.piece, e.tier)
end

local function refreshGet()
	if Runner.active and Runner.statusSink == craftUI.queueStatus then
		getLabel.Text = "STOP"
		tween(getBtn, { BackgroundColor3 = Theme.Danger }, FAST)
		tween(getLabel, { TextColor3 = Theme.Text }, FAST)
		return
	end
	local enabled = #queue > 0 and not Runner.active
	local first = queue[1] and Craft.byId[queue[1]]
	getLabel.Text = Runner.active and "มีระบบอื่นกำลังรันอยู่"
		or #queue == 1 and first and ("GET  ·  ตี " .. label(first) .. (first.base and (" (" .. first.base .. ")") or ""))
		or #queue > 1 and string.format("GET  ·  ตี %d สูตรตามลำดับ", #queue)
		or "GET  ·  ติ๊กสูตรทางซ้ายก่อน"
	tween(getBtn, { BackgroundColor3 = enabled and Theme.On or Theme.Raised }, FAST)
	tween(getLabel, { TextColor3 = enabled and Theme.Base or Theme.Dim }, FAST)
end

-- การ์ดของหนึ่งอย่าง: ไอคอน · ชื่อ · ต้องใช้ ×N · มี M (เขียวพอ / แดงขาด) แบบช่องวัตถุดิบหน้าช่าง
local function itemCard(parent, order, i)
	local ok = i.have >= i.need
	local card = new("Frame", {
		Size = UDim2.new(0.5, -4, 0, 50),
		BackgroundColor3 = Theme.Raised,
		LayoutOrder = order,
		Parent = parent,
	}, { corner(8), stroke(ok and Theme.Good or Theme.Danger, 1) })
	card:FindFirstChildOfClass("UIStroke").Transparency = 0.55
	local defn = ItemDefs[i.name]
	new("ImageLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = Theme.Base,
		Image = Game.iconOf(i.name) or "",
		ScaleType = Enum.ScaleType.Fit,
		Parent = card,
	}, { corner(6), stroke(RarityColor[defn and defn.Rarity or 1] or Theme.Stroke, 1) })
	if i.badge then
		new("TextLabel", {
			Position = UDim2.fromOffset(4, 2),
			Size = UDim2.fromOffset(22, 13),
			BackgroundColor3 = Theme.Accent,
			Text = i.badge,
			TextColor3 = Theme.Base,
			TextSize = 10,
			FontFace = font(Enum.FontWeight.Bold),
			ZIndex = 2,
			Parent = card,
		}, { capsule() })
	end
	new("TextLabel", {
		Position = UDim2.fromOffset(50, 5),
		Size = UDim2.new(1, -54, 0, 15),
		BackgroundTransparency = 1,
		Text = i.name,
		TextColor3 = Theme.Text,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.SemiBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(50, 20),
		Size = UDim2.new(1, -54, 0, 13),
		BackgroundTransparency = 1,
		Text = i.note or ("ต้องใช้ ×" .. comma(i.need)),
		TextColor3 = Theme.Dim,
		TextSize = 12,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(50, 33),
		Size = UDim2.new(1, -54, 0, 13),
		BackgroundTransparency = 1,
		Text = i.haveText or string.format("มี %s%s", comma(i.have),
			ok and "  ✓" or string.format("  (ขาด %s)", comma(i.need - i.have))),
		TextColor3 = ok and Theme.Good or Theme.Danger,
		TextSize = 12,
		FontFace = font(Enum.FontWeight.SemiBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
end

local function text(str, order, color, size, weight)
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		BackgroundTransparency = 1,
		Text = str,
		TextColor3 = color or Theme.Dim,
		TextSize = size or 13,
		FontFace = font(weight or Enum.FontWeight.SemiBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Parent = detail,
	})
end

-- หัวขั้นตอน: เลขในวง + ชื่อขั้น + สถานะ (เสร็จ = เขียว)
local function stepHead(n, title, done, order)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = detail,
	})
	new("TextLabel", {
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = done and Theme.Good or Theme.Raised,
		Text = done and "✓" or tostring(n),
		TextColor3 = done and Theme.Base or Theme.Text,
		TextSize = 12,
		FontFace = font(Enum.FontWeight.Bold),
		Parent = row,
	}, { capsule() })
	new("TextLabel", {
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -28, 1, 0),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = done and Theme.Good or Theme.Text,
		TextSize = 14,
		FontFace = font(Enum.FontWeight.Bold),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
end

local function grid(order)
	return new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = detail,
	}, { new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0, 50),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) })
end

local function cardsOf(list)
	local w = wallet()
	local out = {}
	for _, m in ipairs(list or {}) do
		out[#out + 1] = { name = m.name, need = m.amount, have = w[m.name] or 0 }
	end
	return out
end

local function showDetail(id)
	for _, c in ipairs(detail:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local e = id and Craft.byId[id]
	if not e then
		return
	end
	local r = e.recipe
	local defn = ItemDefs[e.piece] or {}
	local w = wallet()
	local owned = Craft.owned(e.piece) or 0
	fixIdentity()
	local rarityColor = RarityColor[defn.Rarity or 1] or Theme.Muted
	local sText, sColor = Craft.state(e)
	fixIdentity()

	local head = new("Frame", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = detail,
	})
	local icon = new("ImageLabel", {
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = Theme.Base,
		Image = defn.Icon or "",
		ScaleType = Enum.ScaleType.Fit,
		Parent = head,
	}, { corner(10), stroke(rarityColor, 1.5) })
	new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, 2),
		Size = UDim2.fromOffset(22, 14),
		BackgroundColor3 = Theme.Accent,
		Text = "T" .. e.tier,
		TextColor3 = Theme.Base,
		TextSize = 11,
		FontFace = font(Enum.FontWeight.Bold),
		ZIndex = 2,
		Parent = icon,
	}, { capsule() })
	new("TextLabel", {
		Position = UDim2.fromOffset(66, 2),
		Size = UDim2.new(1, -66, 0, 20),
		BackgroundTransparency = 1,
		Text = string.format("%s  T%d", e.piece, e.tier),
		TextColor3 = Theme.Text,
		TextSize = 17,
		FontFace = font(Enum.FontWeight.Bold),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = head,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(66, 24),
		Size = UDim2.new(1, -66, 0, 14),
		BackgroundTransparency = 1,
		RichText = true,
		Text = string.format('<font color="#%s">%s</font>  ·  %s%s', rarityColor:ToHex(),
			Rarities.Order[defn.Rarity or 1] or "?", Game.TypeThai[defn.Category] or tostring(defn.Category),
			e.base and ("  ·  ฐาน " .. e.base) or ""),
		TextColor3 = Theme.Dim,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = head,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(66, 42),
		Size = UDim2.new(1, -66, 0, 14),
		BackgroundTransparency = 1,
		Text = sText,
		TextColor3 = sColor,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.SemiBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = head,
	})

	-- สเตตัสที่ได้ตอนขั้นนี้ (คูณ Series.TierMultiplier แบบที่เกมคิด)
	local mult = Craft.TierMult[e.tier] or 1
	local stats = {}
	for stat, v in pairs(defn.Stats or defn.ActiveToolStats or {}) do
		if typeof(v) == "number" then
			stats[#stats + 1] = string.format("%s +%s", stat, tostring(math.round(v * mult * 1000) / 1000))
		end
	end
	table.sort(stats)
	if #stats > 0 then
		local wrap = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Parent = detail,
		}, { new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, 4),
		}) })
		for i, chip in ipairs(stats) do
			new("TextLabel", {
				Size = UDim2.fromOffset(0, 20),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Theme.Raised,
				Text = chip,
				TextColor3 = Theme.Accent,
				TextSize = 12,
				FontFace = font(Enum.FontWeight.Medium),
				LayoutOrder = i,
				Parent = wrap,
			}, { capsule(), new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }) })
		end
	end

	-- 1 แบบพิมพ์
	local schem = r.keep and r.keep[1]
	if schem then
		local have = w[schem] or 0
		stepHead(1, "แบบพิมพ์", have > 0, 10)
		itemCard(grid(11), 1, { name = schem, need = 1, have = have, note = "ใช้ได้ตลอด ไม่หาย",
			haveText = have > 0 and "มีแล้ว  ✓" or "ยังไม่มี · สคริปต์หาให้" })
	end

	-- 2 ของฐาน: ดาบ V2 (T1 อาวุธ) · ชิ้นขั้นก่อน (T2/T3) · วัสดุเซ็ต (T1 ชุด อยู่ขั้น 3)
	if e.base then
		local have = itemCount(e.base)
		stepHead(2, "ดาบฐาน · " .. e.base, have > 0, 20)
		local g = grid(21)
		itemCard(g, 1, { name = e.base, need = 1, have = have, note = "สูตรนี้ใช้เล่มนี้",
			haveText = have > 0 and "มีแล้ว  ✓" or "ยังไม่มี" })
		local v2 = have == 0 and Craft.v2Of(e.base)
		if v2 then
			local raw = v2.recipe.required[1]
			local pts = (v2.recipe.price or {}).RunPoints or 0
			text(string.format("ได้จาก: เอา %s ไปอัปที่ Togane ในดันเจี้ยน Ouwigahara · ใช้ %s แต้ม (ต้องได้ครบในรอบเดียว)"
				.. " · Mythic Ore ขาดสคริปต์แลกแต้มให้ก่อน", raw.name, comma(pts)), 22, Theme.Muted, 13, Enum.FontWeight.Regular)
			local g2 = grid(23)
			local list = { { name = raw.name, need = raw.amount, have = w[raw.name] or 0, note = "ดาบธรรมดาที่จะอัป" } }
			for _, c in ipairs(cardsOf(v2.recipe.additionalMaterials)) do
				list[#list + 1] = c
			end
			for n, c in ipairs(list) do
				itemCard(g2, n, c)
			end
		end
	elseif e.tier > 1 then
		local ok = owned >= e.tier - 1
		stepHead(2, string.format("ชิ้นเดิม T%d", e.tier - 1), ok, 20)
		itemCard(grid(21), 1, { name = e.piece, need = 1, have = ok and 1 or 0, badge = "T" .. (e.tier - 1),
			note = "อัปจากชิ้นนี้ (ค่า Refine ติดไปด้วย)",
			haveText = ok and string.format("มี T%d  ✓", owned) or (owned > 0 and string.format("มี T%d · ตี T%d ให้ก่อน", owned,
				e.tier - 1) or string.format("ยังไม่มี · ตี T1→T%d ให้ก่อน", e.tier - 1)) })
	end

	-- 3 วัสดุเพิ่ม (รวมวัสดุเซ็ตในช่อง required ของ T1 ชุด)
	local mats = {}
	for _, m in ipairs(r.required or {}) do
		if Craft.SetMats[m.name] then
			mats[#mats + 1] = m
		end
	end
	for _, m in ipairs(r.additionalMaterials or {}) do
		mats[#mats + 1] = m
	end
	if #mats > 0 then
		local cards = cardsOf(mats)
		-- ดาบฐานยังไม่ได้อัป: Scraps / Silk ชุดเดียวกันโดนสูตรอัปกินก่อน ต้องมีรวมสองขั้น (craftRecipe ก็นับแบบนี้)
		-- เดิมติ๊กแยกกัน มี Silk 1,000 ขึ้น ✓ ทั้งสองช่อง แต่จริงต้อง 1,300
		local v2 = e.base and itemCount(e.base) < 1 and Craft.v2Of(e.base)
		for _, c in ipairs(cards) do
			for _, x in ipairs(v2 and v2.recipe.additionalMaterials or {}) do
				if x.name == c.name and not Craft.SetMats[c.name] then
					c.note = string.format("ต้องใช้ ×%s +%s อัปดาบฐาน", comma(c.need), comma(x.amount))
					c.need += x.amount
				end
			end
		end
		local done = true
		for _, c in ipairs(cards) do
			done = done and c.have >= c.need
		end
		stepHead(3, "วัสดุเพิ่ม (Additional Materials)", done, 30)
		local g = grid(31)
		for n, c in ipairs(cards) do
			itemCard(g, n, c)
		end
		if next(Craft.setNeeds(r)) then
			text("วัสดุเซ็ตฟาร์มจากหีบบอส แลกชนิดกันได้ 1:1 ที่ Togane · Scraps / Silk ซื้อที่ Ginzo", 32, Theme.Muted, 13,
				Enum.FontWeight.Regular)
		else
			text("Scraps / Silk ต้องมีเองในกระเป๋า · เปิดปุ่มล่างถ้าให้สคริปต์ซื้อที่ Ginzo ตอนขาด", 32, Theme.Muted, 13,
				Enum.FontWeight.Regular)
		end
		local buy = Game.persist.data.craftBuy == true
		local buyBtn = new("TextButton", {
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = buy and Theme.On or Theme.Raised,
			AutoButtonColor = false,
			Text = buy and "ซื้อ Scraps / Silk ที่ Ginzo ถ้าขาด: เปิด" or "ซื้อ Scraps / Silk ที่ Ginzo ถ้าขาด: ปิด",
			TextColor3 = buy and Theme.Base or Theme.Dim,
			TextSize = 12,
			FontFace = font(Enum.FontWeight.SemiBold),
			LayoutOrder = 33,
			Parent = detail,
		}, { capsule(), new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }) })
		buyBtn.MouseButton1Click:Connect(function()
			Game.persist.data.craftBuy = not buy or nil
			Game.save()
			showDetail(id)
		end)
	end

	-- 4 ค่าตี Wen จากดันเจี้ยน
	local price = (r.price or {}).Wen or 0
	if price > 0 then
		local have = w.Wen or 0
		stepHead(4, "ค่าตี (Wen)", have >= price, 40)
		itemCard(grid(41), 1, { name = "Wen", need = price, have = have })
		local runs, perRun = Craft.wenRuns(price - have)
		local tail
		if have >= price then
			tail = "เงินพอแล้ว"
		elseif runs then
			tail = string.format("รอบล่าสุดได้ ~%s Wen/รอบ · อีกราว %d รอบ", comma(perRun), runs)
		else
			tail = "ยังไม่มีสถิติรอบ จะจดหลังลงรอบแรก"
		end
		text("หาเงิน: ลงดันเจี้ยน Ouwigahara แลกแต้มเป็น Wen 100% · จบที่ชั้น 70 ทุกรอบ · " .. tail, 42, Theme.Muted, 13,
			Enum.FontWeight.Regular)
	end

	text("กด GET แล้วสคริปต์ทำตามลำดับ 1 → 4 แล้วตีที่ Blacksmith Togane · ลงดันเจี้ยนแล้วกลับมาทำคิวต่อเอง", 50,
		Theme.Dim, 12, Enum.FontWeight.Regular)
end

local function paintRows()
	for _, r in ipairs(rows) do
		local order = table.find(queue, r.id)
		tween(r.tickFill, { BackgroundTransparency = order and 0 or 1 }, FAST)
		r.tickStroke.Color = order and Theme.On or Theme.Muted
		r.tickNum.Text = order and tostring(order) or ""
		r.tickNum.Visible = order ~= nil and #queue > 1
		tween(r.frame, { BackgroundColor3 = r.id == selected and Theme.Raised or Theme.Row }, FAST)
		r.rim.Transparency = r.id == selected and 0.2 or 1
	end
end

local function buildRows()
	for _, c in ipairs(craftUI.list:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	table.clear(rows)
	local lastPiece
	for n, e in ipairs(Craft.recipes()) do
		local defn = ItemDefs[e.piece] or {}
		-- หัวกลุ่มต่อชิ้น: ชื่อชิ้น + ขั้นที่มีอยู่
		if e.piece ~= lastPiece then
			lastPiece = e.piece
			local owned = Craft.owned(e.piece)
			new("TextLabel", {
				Size = UDim2.new(1, -6, 0, 22),
				BackgroundTransparency = 1,
				RichText = true,
				Text = string.format("<b>%s</b>  <font color=\"#%s\">%s</font>", e.piece:gsub("^Nightfall ", ""),
					(owned and Theme.Good or Theme.Dim):ToHex(), owned and ("มี T" .. owned) or "ยังไม่มี"),
				TextColor3 = Theme.Text,
				TextSize = 14,
				FontFace = font(Enum.FontWeight.Regular),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Bottom,
				LayoutOrder = n * 2 - 1,
				Parent = craftUI.list,
			})
		end
		local sText, sColor = Craft.state(e)
		fixIdentity()
		local frame = new("Frame", {
			Size = UDim2.new(1, -6, 0, 46),
			BackgroundColor3 = Theme.Row,
			BorderSizePixel = 0,
			LayoutOrder = n * 2,
			Parent = craftUI.list,
		}, { corner(8) })
		local rim = stroke(Theme.Accent, 1)
		rim.Transparency = 1
		rim.Parent = frame
		local tickFill, tickStroke = tickBox(frame)
		local tickNum = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(15, 15),
			BackgroundColor3 = Theme.Accent2,
			Text = "",
			TextColor3 = Theme.Base,
			TextSize = 11,
			FontFace = font(Enum.FontWeight.Bold),
			Visible = false,
			ZIndex = 3,
			Parent = tickFill.Parent,
		}, { capsule() })
		-- ไอคอน: ดาบฐานสำหรับ T1 อาวุธ (แยกแถวได้ด้วยตา) ที่เหลือใช้ไอคอนชิ้นเซ็ต + ป้าย T
		local iconName = e.base or e.piece
		local iconDef = ItemDefs[iconName] or defn
		local icon = new("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 40, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
			BackgroundColor3 = Theme.Base,
			Image = Game.iconOf(iconName) or defn.Icon or "",
			ScaleType = Enum.ScaleType.Fit,
			Parent = frame,
		}, { corner(7), stroke(RarityColor[iconDef.Rarity or 1] or Theme.Stroke, 1.5) })
		new("TextLabel", {
			Position = UDim2.fromOffset(-4, -5),
			Size = UDim2.fromOffset(20, 13),
			BackgroundColor3 = Theme.Accent,
			Text = "T" .. e.tier,
			TextColor3 = Theme.Base,
			TextSize = 10,
			FontFace = font(Enum.FontWeight.Bold),
			ZIndex = 2,
			Parent = icon,
		}, { capsule() })
		new("TextLabel", {
			Position = UDim2.fromOffset(80, 6),
			Size = UDim2.new(1, -84, 0, 16),
			BackgroundTransparency = 1,
			Text = e.base and ("T1 · " .. e.base) or (e.tier > 1 and string.format("T%d · อัปจาก T%d", e.tier, e.tier - 1))
				or "T1 · ตีจากวัสดุเซ็ต",
			TextColor3 = Theme.Text,
			TextSize = 14,
			FontFace = font(Enum.FontWeight.SemiBold),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		})
		new("TextLabel", {
			Position = UDim2.fromOffset(80, 25),
			Size = UDim2.new(1, -84, 0, 14),
			BackgroundTransparency = 1,
			Text = sText,
			TextColor3 = sColor,
			TextSize = 12,
			FontFace = font(Enum.FontWeight.Medium),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		})
		local row = { id = e.id, frame = frame, rim = rim, tickFill = tickFill, tickStroke = tickStroke, tickNum = tickNum }
		-- สองจุดกด: ช่องติ๊กซ้ายสุด = เข้า/ออกคิว · ที่เหลือ = ดูขั้นตอน (ผู้ใช้เคยเจอกดติ๊กแล้วกลายเป็นเปิดข้อมูล)
		local tickHit = new("TextButton", {
			Size = UDim2.new(0, 36, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			Parent = frame,
		})
		local selHit = new("TextButton", {
			Position = UDim2.fromOffset(36, 0),
			Size = UDim2.new(1, -36, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			Parent = frame,
		})
		track(tickHit.MouseButton1Click:Connect(function()
			if (Craft.owned(e.piece) or 0) >= e.tier then
				fixIdentity()
				craftUI.setStatus(label(e) .. " มีอยู่แล้ว", Theme.Good)
				return
			end
			fixIdentity()
			local at = table.find(queue, e.id)
			if at then
				table.remove(queue, at)
				-- เอาติ๊กสูตรที่กำลังทำออก = หยุดเลย (เดิมลบแค่ในรายการ งานที่ค้างโหลดกลับมาทำต่อจนผู้ใช้หยุดไม่ได้)
				local running = Runner.active and Runner.statusSink == craftUI.queueStatus
				if running and craftUI.current == e.id then
					Runner.stop()
					craftUI.setStatus("หยุด " .. label(e) .. " แล้ว", Theme.Warn)
				end
				if #queue == 0 then
					Game.setResume(nil)
					Game.persist.data.ouwiGo = nil
					Game.persist.data.ouwiGoal = nil
				elseif running then
					Game.setResume({ kind = "craft", queue = table.clone(queue) })
				end
			else
				-- สูตรชิ้นเดียวกันขั้นเดียวกันเลือกได้ทางเดียว (ดาบฐานคนละเล่ม) เลือกใหม่แทนที่อันเดิม
				for i = #queue, 1, -1 do
					local q = Craft.byId[queue[i]]
					if q and q.piece == e.piece and q.tier == e.tier then
						table.remove(queue, i)
					end
				end
				queue[#queue + 1] = e.id
			end
			selected = e.id
			showDetail(e.id)
			paintRows()
			refreshGet()
		end))
		track(selHit.MouseButton1Click:Connect(function()
			selected = e.id
			showDetail(e.id)
			fixIdentity()
			paintRows()
		end))
		rows[#rows + 1] = row
	end
	paintRows()
end

local function rebuild()
	local w = wallet()
	fixIdentity()
	craftUI.walletBar.set(w)
	Craft.recipes()
	selected = selected or (Craft.list[1] and Craft.list[1].id)
	buildRows()
	showDetail(selected)
	fixIdentity()
	paintRows()
	refreshGet()
end

-- คิวเก่า (ก่อนแยกสูตร) เก็บชื่อชิ้น แปลงเป็นสูตรขั้นถัดไปของชิ้นนั้น
local function toRecipeId(entry)
	Craft.recipes()
	if Craft.byId[entry] then
		return entry
	end
	local owned = Craft.owned(entry) or 0
	local e = Craft.pickTier(entry, math.min(owned + 1, Craft.MaxTier))
	return e and e.id
end

local function runQueue()
	Runner.active = true
	Runner.cancel = false
	Runner.lastStart = os.clock()
	Runner.statusSink = craftUI.queueStatus
	refreshGet()
	Game.setResume({ kind = "craft", queue = table.clone(queue) })
	task.spawn(function()
		local done, lastErr = {}, nil
		local towerGoal
		for _ = 1, #queue do
			if Runner.cancel then
				break
			end
			local id = queue[1]
			if not id then
				break
			end
			local e = Craft.byId[id]
			craftUI.progress = string.format("[%d/%d] ", #done + 1, #done + #queue)
			craftUI.current = id
			local okRun, ok, err, extra = pcall(Runner.craftRecipe, id)
			craftUI.current = nil
			fixIdentity()
			if okRun and err == Runner.TOWER then
				-- งานค้างยังอยู่ในไฟล์ (ไม่ล้าง) กลับจากหอคอยแล้วโหลดใหม่ทำคิวนี้ต่อจากขั้นที่ค้าง
				towerGoal = extra or { kind = "wen" }
				break
			elseif okRun and ok then
				done[#done + 1] = e and label(e) or id
			elseif not Runner.cancel then
				lastErr = (e and label(e) or id) .. ": " .. tostring(okRun and err or ok)
			end
			-- ลบตาม id ผู้ใช้อาจเอาติ๊กออกระหว่างทำ ตัวแรกในรายการอาจไม่ใช่สูตรนี้แล้ว
			local at = table.find(queue, id)
			if at then
				table.remove(queue, at)
			end
			Game.setResume(#queue > 0 and { kind = "craft", queue = table.clone(queue) } or nil)
		end
		craftUI.progress = nil
		-- จบเองหรือกด STOP ไม่ต้องทำต่อ (ย้ายแมพกลางทาง = ไม่ถึงบรรทัดนี้ งานค้างยังอยู่ในไฟล์)
		-- กดยกเลิกจังหวะที่สูตรเพิ่งตอบ TOWER ก็ต้องล้าง ไม่งั้นงานค้างในไฟล์ทำให้โหลดครั้งหน้าตีต่อเอง
		if not towerGoal or Runner.cancel then
			Game.setResume(nil)
			Game.persist.data.ouwiGoal = nil
		end
		local cancelled = Runner.cancel
		Runner.active = false
		Runner.statusSink = nil
		local summary = #done > 0 and ("ตีสำเร็จ: " .. table.concat(done, ", ")) or "ยังไม่ได้ตีสักสูตร"
		if cancelled then
			summary = "หยุดแล้ว · " .. summary
		elseif lastErr then
			summary = summary .. " · ติด " .. lastErr
		end
		rebuild()
		craftUI.setStatus(summary, lastErr and Theme.Warn or Theme.Good)
		if towerGoal and not cancelled and Game.ouwiRequest then
			craftUI.setStatus(towerGoal.kind == "v2" and "ไปอัปดาบฐานในดันเจี้ยน · กลับมาแล้วทำคิวต่อเอง"
				or "ไปหา Wen ในดันเจี้ยน (Wen 100% จบชั้น 70) · กลับมาแล้วทำคิวต่อเอง", Theme.Accent)
			Game.ouwiRequest(towerGoal)
		end
	end)
end

track(getBtn.MouseButton1Click:Connect(function()
	if os.clock() - (Runner.lastStart or 0) < 1 then
		return
	end
	if Runner.active then
		if Runner.statusSink == craftUI.queueStatus then
			Runner.stop()
			craftUI.setStatus("กำลังหยุด…", Theme.Warn)
		end
		return
	end
	if #queue > 0 then
		runQueue()
	end
end))

-- ย้ายแมพ/เซิร์ฟกลางคิว โหลดใหม่แล้วทำคิวที่เหลือต่อ
Game.persist.resumers.craft = function(job)
	if Runner.active or type(job.queue) ~= "table" or #job.queue == 0 then
		return
	end
	table.clear(queue)
	for _, entry in ipairs(job.queue) do
		local id = toRecipeId(entry)
		if id and not table.find(queue, id) then
			queue[#queue + 1] = id
		end
	end
	fixIdentity()
	if #queue == 0 then
		Game.setResume(nil)
		return
	end
	rebuild()
	runQueue()
end

local craftFeature = featureRow("Get Nightfall Craft", "ตีชิ้นเซ็ต Nightfall ทุกขั้น หาแบบ ดาบฐาน วัสดุ เงินให้เอง", 2, function()
	rebuild()
	craftUI.setStatus("ติ๊กสูตรทางซ้ายเพื่อเข้าคิว · กดแถวเพื่อดูขั้นตอน", Theme.Muted)
	craftUI.show()
end, function()
	craftUI.hide()
end)
track(craftUI.closeButton.MouseButton1Click:Connect(function()
	craftFeature.setOpen(false)
end))

-- ปุ่มยกเลิกลอยใต้ตัวละคร โผล่ตลอดที่งาน Craft ยังค้าง (รันอยู่ / รอทำต่อหลังย้ายแมพ / ไปหอคอยแทนคิว)
-- ผู้ใช้ขอ: เดิมต้องเปิดหน้าต่างหลัก ไล่เอาติ๊กออกทีละสูตร ระหว่างนั้นระบบก็ยังพาวิ่งต่อ
local cancelBtn = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	-- ตัวละครอยู่กลางจอในมุมกล้องปกติ 90 px ใต้กลางจอ = ประมาณเท้า ไม่บังตัวละครกับหลอดเลือดด้านบน
	Position = UDim2.new(0.5, 0, 0.5, 90),
	Size = UDim2.fromOffset(0, 32),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = Theme.Danger,
	AutoButtonColor = false,
	Text = "ยกเลิก Auto Get Nightfall Craft",
	TextColor3 = Theme.Text,
	TextSize = 14,
	FontFace = font(Enum.FontWeight.SemiBold),
	Visible = false,
	Parent = screen,
}, {
	capsule(),
	stroke(),
	new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
})

local function craftPending()
	local data = Game.persist.data
	-- กดยกเลิกแล้ว runQueue ยังค้างรอสูตรที่ทำอยู่คืนค่าอีกพัก ไม่นับช่วงนั้น ปุ่มจะได้ไม่เด้งกลับ
	return Runner.active and Runner.statusSink == craftUI.queueStatus and not Runner.cancel
		or data.resume ~= nil and data.resume.kind == "craft"
		or data.ouwiGo ~= nil
end

track(cancelBtn.MouseButton1Click:Connect(function()
	cancelBtn.Visible = false
	-- ล้างคิวก่อนสั่งหยุด runQueue ตอนจบวาดติ๊กใหม่จากคิวนี้ และเขียนงานค้างเป็น nil เพราะคิวว่าง
	table.clear(queue)
	if Runner.active and Runner.statusSink == craftUI.queueStatus then
		Runner.stop()
	end
	-- Auto-Dungeon ที่คิวสั่งเปิดให้ (ouwiGo) ปิดด้วย ส่วนที่ผู้ใช้เปิดเองไม่ยุ่ง
	local data = Game.persist.data
	if data.ouwiGo then
		for _, entry in ipairs(toggles) do
			if entry.key == "Auto-Dungeon" and entry.isOn() then
				pcall(entry.set, false)
			end
		end
	end
	data.ouwiGo = nil
	data.ouwiGoal = nil
	Game.setResume(nil)
	fixIdentity()
	paintRows()
	refreshGet()
	craftUI.setStatus("ยกเลิก Auto Get Nightfall Craft แล้ว", Theme.Warn)
end))

-- สถานะงานค้างเปลี่ยนได้จากหลายที่ (runQueue, หอคอย, resumer, สวิตช์) เช็กเป็นรอบง่ายกว่าไล่ผูกทุกจุด
local alive = true
track({
	Disconnect = function()
		alive = false
	end,
})
task.spawn(function()
	while alive do
		cancelBtn.Visible = craftPending()
		task.wait(0.5)
	end
end)
end)()

-- Auto-Potion ------------------------------------------------------------------
-- ยาในเกมเป็นเครื่องมือถือ (EquipType 2, ToolScript "Health Potion") อ่านจากโค้ดเกม 24 ก.ย. 2026:
--   ถือแล้วกดค้าง (Tool_Mouse Down) เซิร์ฟดื่มให้ 1.85 วิแล้วค่อยให้ผล ปล่อยก่อน (Up) = ยกเลิก
--   Health Potion +25 HP · Health Elixir +60 HP · Regen Potion/Elixir = เร่งฟื้นเลือดช่วงสั้น
--   ระหว่างดื่มโดนตี/ทำท่าอื่น (ManuelCancel) ยกเลิก ไม่เสียยา → ช่วงดื่มหยุด Kill Aura / Auto Skill / สลับดาบ
-- ในหอคอยเกมแจก Health Potion 3 ขวดทุกรอบ (MinigameSettings.StartPotion)
;(function()
local Potion = {
	-- เรียงจากฟื้นมากสุดก่อน เลือดต่ำใช้ตัวที่ได้เลือดทันทีก่อน Regen
	Order = { "Health Elixir", "Health Potion", "Health Regen Elixir", "Health Regen Potion" },
	Heal = { ["Health Elixir"] = 60, ["Health Potion"] = 25 },
	Thresholds = { 30, 40, 50, 60, 70 },
	threshold = 40,
	-- เซิร์ฟตัดยา+ให้เลือดที่ 1.85 วิหลังกด (0.3 + 0.95 + 0.2 + 0.4 ใน Health PotionServer) ปล่อยเมาส์ (Tool_Mouse Up)
	-- ก่อนนั้นเซิร์ฟยกเลิกทั้งขวด วัดจริง: ปล่อยที่ 1.75 เสียงเปิด+ดื่มครบแต่ยาไม่ลด เลยค้างไว้ 2.3
	DrinkTime = 2.3,
	-- เว้นระหว่างขวด ให้ค่าเลือดใหม่ replicate มาก่อน ไม่งั้นกินซ้อนสองขวดทั้งที่ขวดแรกพอแล้ว
	Gap = 1.5,
	on = false,
	loop = 0,
	drinks = 0,
	last = 0,
}

-- โฟลเดอร์สถานะตัวละครของเกม (Player_Service.Values.<ชื่อ>) ที่ Checker อ่าน
function Potion.values()
	local ok, U = pcall(require, ReplicatedStorage.CAM.Global.Utility)
	local vf = ok and U.getvaluesfolder(LocalPlayer) or nil
	if setthreadidentity and Game.loadIdentity then
		setthreadidentity(Game.loadIdentity)
	end
	return vf
end

local function bagItem(name)
	local slot = equippedSlot()
	local bag = slot and slot.Inventory:FindFirstChild("Inventory")
	return bag and bag:FindFirstChild(name)
end

local function countOf(name)
	local it = bagItem(name)
	if not it then
		return 0
	end
	local amount = it:FindFirstChild("Amount")
	return amount and amount.Value or 1
end

-- ใส่ยาขึ้น toolbar ช่องว่าง (Toolbar_Equip แบบปุ่มในกระเป๋า) ไม่เอาของที่ผู้เล่นวางไว้ออก คืนเลขช่อง
local function potionSlot(name)
	local it = bagItem(name)
	local id = it and it:FindFirstChild("Id")
	if not id then
		return nil, "ไม่มี " .. name
	end
	local bar = equippedSlot().Inventory.Toolbar
	local slots = { "One", "Two", "Three", "Four", "Five" }
	for i, s in ipairs(slots) do
		if bar[s].Value == id.Value then
			return i
		end
	end
	for i, s in ipairs(slots) do
		if bar[s].Value == 0 then
			SignalEvent.ToServer("Toolbar_Equip", s, id.Value)
			local untilT = os.clock() + 3
			while bar[s].Value ~= id.Value and os.clock() < untilT do
				task.wait(0.1)
			end
			if bar[s].Value == id.Value then
				return i
			end
			return nil, "ใส่ยาขึ้น toolbar ไม่ติด"
		end
	end
	return nil, "toolbar เต็ม 5 ช่อง เว้นว่างไว้หนึ่งช่องให้ยา"
end

local function pickPotion()
	for _, name in ipairs(Potion.Order) do
		if countOf(name) > 0 then
			return name
		end
	end
	return nil
end

local function stockText()
	local parts = {}
	for _, name in ipairs(Potion.Order) do
		local n = countOf(name)
		if n > 0 then
			parts[#parts + 1] = string.format("%s %d", name:gsub("Health ", ""), n)
		end
	end
	return #parts > 0 and table.concat(parts, " · ") or "ไม่มียาในกระเป๋า"
end

local row
local function drink(name)
	local _, hrp, hum = selfParts()
	if not (hrp and hum) then
		return false
	end
	local slot, why = potionSlot(name)
	if not slot then
		return false, why
	end
	local prev = heldSlot()
	local before, hpBefore = countOf(name), hum.Health
	-- หยุดทุกอย่างที่จะไปยกเลิกท่าดื่ม: หมัด (blockUntil) สกิล + สลับดาบ (drinkUntil)
	-- รอถือยานิ่ง (สูงสุด 2 วิ) + รอว่าง (3) + ดื่ม 2.3 วิ ตั้งกันไว้ 8 วิ จบแล้วล้างเป็น 0 เอง
	local untilT = os.clock() + 8
	Combat.drinkUntil = untilT
	autoDodge.blockUntil = math.max(autoDodge.blockUntil, untilT)
	-- Auto Skill ที่อยู่กลางรอบ (ผ่านจุดเช็ก drinkUntil ไปแล้ว) สลับกลับไปถือดาบได้อีกครั้ง
	-- วัดจริง: ตั้งช่องยาแล้ว 0.8 วิโดนดึงกลับช่อง 1 เลยย้ำช่องยาจนถือนิ่ง 0.5 วิก่อนดื่ม
	equipSlot(slot)
	local steady = os.clock()
	local giveUp = os.clock() + 2
	while os.clock() - steady < 0.5 and os.clock() < giveUp do
		task.wait(0.05)
		if heldSlot() ~= slot then
			equipSlot(slot)
			steady = os.clock()
		end
	end
	if heldSlot() ~= slot then
		Combat.drinkUntil = 0
		return false, "ถือยาไม่ได้ (ระบบอื่นสลับดาบกลับ)"
	end
	-- เซิร์ฟเช็ก Checker.check ก่อนดื่ม: ห้ามมี pause_gameplay / Stun / CombatStun / Blocking และท่าสกิลค้าง (SHC)
	-- วัดในหอคอย: pause_gameplay โผล่ 43% ของเวลา (ท่าสกิลที่เพิ่งกด / เลือกการ์ด) กดตอนนั้นเซิร์ฟเงียบ ยาไม่ลด
	local vf = Potion.values()
	local waitFree = os.clock() + 3
	while os.clock() < waitFree do
		local shc = hrp.Parent and (hrp.Parent:FindFirstChild("SHC") or hrp.Parent:FindFirstChild("SHCS"))
		local busy = shc and shc.Value ~= ""
		for _, n in ipairs({ "pause_gameplay", "Stun", "CombatStun", "Strict_Stun", "Blocking", "Swapping" }) do
			busy = busy or (vf and vf:FindFirstChild(n) ~= nil)
		end
		if not busy then
			break
		end
		task.wait(0.05)
	end
	SignalEvent.ToServer("Tool_Mouse", "Down", hrp.Position)
	task.wait(Potion.DrinkTime)
	SignalEvent.ToServer("Tool_Mouse", "Up", hrp.Position)
	task.wait(0.2)
	Combat.drinkUntil = 0
	-- ปลดล็อกหมัดทันที ไม่รอครบ 5 วิที่กันไว้ (ถ้า parry กดค้างอยู่ช่วงนี้ก็แค่ปล่อยเร็วขึ้น)
	if autoDodge.blockUntil == untilT then
		autoDodge.blockUntil = 0
	end
	if prev ~= 0 and prev ~= slot then
		equipSlot(prev)
	end
	local used = countOf(name) < before
	if used then
		Potion.drinks += 1
	end
	return used, used and string.format("กิน %s · เลือด %d → %d", name, hpBefore, hum.Health) or "ท่าดื่มโดนยกเลิก (โดนตี?)"
end

local function loop(mine)
	while Potion.on and Potion.loop == mine do
		local _, _, hum = selfParts()
		if hum and hum.Health > 0 and hum.MaxHealth > 0 then
			local pct = hum.Health / hum.MaxHealth * 100
			if pct < Potion.threshold and os.clock() - Potion.last > Potion.Gap then
				local name = pickPotion()
				if name then
					Potion.last = os.clock()
					local ok, msg = drink(name)
					Potion.last = os.clock()
					row.setDesc(string.format("%s · กินไป %d ขวด · เหลือ %s", tostring(msg), Potion.drinks, stockText()))
				else
					row.setDesc(string.format("เลือด %d%% ต่ำกว่า %d%% แต่ไม่มียา · ซื้อที่ Rika / Alchemist Meku", pct, Potion.threshold))
				end
			elseif os.clock() - Potion.last > 5 then
				row.setDesc(string.format("เฝ้าเลือด %d%% · กินเมื่อต่ำกว่า %d%% · มี %s", pct, Potion.threshold, stockText()))
			end
		end
		task.wait(0.25)
	end
end

row = switchRow("Auto-Potion", "ปิดอยู่", 2, function(on)
	Potion.on = on
	Potion.loop += 1
	Combat.drinkUntil = 0
	if on then
		task.spawn(loop, Potion.loop)
	end
end)

switchRow("กินยาเมื่อเลือดต่ำกว่า", "เลือดต่ำกว่าเท่านี้ (% ของเลือดเต็ม) กินยาทันที", 3, function() end, {
	choices = { "30%", "40%", "50%", "60%", "70%" },
	selected = 2,
	onChoice = function(i)
		Potion.threshold = Potion.Thresholds[i]
	end,
})

track({
	Disconnect = function()
		Potion.on = false
		Potion.loop += 1
		Combat.drinkUntil = 0
	end,
})
end)()

-- Upgrade อุปกรณ์ (Refine) ---------------------------------------------------
-- ระบบเดียวกับหน้า Refiner Hagane ในเกม (CAM.Global.Refinement อ่าน 24 ก.ย. 2026):
--   ระดับ 0-10 · แต่ละขั้นใช้ Wen + Refinement Ore (ขั้น 0-4) หรือ Mythic Refinement Ore (ขั้น 5-9)
--   ผล: Success +1 · Great ข้ามได้ถึง +3 (GreatStep) · Fail ระดับตก · Refinement Guard กันระดับตก (เผาทีละใบ)
--   Mythic ไม่พอ เซิร์ฟหลอม Refinement Ore 5 ก้อนแทนให้ 1 (ResolveOreCost)
--   ยิง SignalFunction "RefinementRequest" { action = "Attempt", Id, UseGuard } ได้จากทุกที่ ไม่ต้องยืนหน้า Hagane
--   (ทดสอบจริง: ห่าง Hagane 3,072 stud ตอบ { Ok = true, Level = 1, Outcome = "Success" })
-- ไม่ใช้ Runner: ไม่ขยับตัวละคร เลยอัปไปพร้อมคิว Craft / ฟาร์มได้
;(function()
local Refinement = require(ReplicatedStorage.CAM.Global.Refinement)
local Utility = require(ReplicatedStorage.CAM.Global.Utility)
local Rarities = require(ReplicatedStorage.CAM.Global.Rarities)
local okDefs, ItemDefs = pcall(require, ReplicatedStorage.CAM.Global.Collectibles.Items)
ItemDefs = okDefs and ItemDefs or {}

local function fixIdentity()
	if setthreadidentity and Game.loadIdentity then
		setthreadidentity(Game.loadIdentity)
	end
end

local Up = {
	Max = Refinement.MaxLevel or 10,
	Guard = Refinement.GuardItem or "Refinement Guard",
	-- เว้นระหว่างครั้ง เท่าจังหวะคนกดเร็ว ๆ ในหน้าเกม (พิธีกรรมตีในเกมยาว ~1 วิ กดข้ามได้)
	Gap = 0.35,
	Filters = { "ทั้งหมด", "อาวุธ", "ของสวมใส่", "เบ็ด" },
	filter = "ทั้งหมด",
	-- ชื่อช่อง toolbar ของเกม → เลขที่ผู้เล่นเห็น
	Slots = { One = 1, Two = 2, Three = 3, Four = 4, Five = 5 },
	OutcomeThai = {
		Success = { "สำเร็จ", Theme.Good },
		Great = { "สำเร็จใหญ่ ข้ามขั้น!", Theme.Accent },
		Fail = { "พลาด ระดับตก", Theme.Danger },
		Guarded = { "พลาด แต่ Guard กันระดับไว้", Theme.Accent2 },
	},
	target = {},
	useGuard = false,
	busy = false,
	cancel = false,
}

local function data()
	local d = Utility.GetData(LocalPlayer)
	fixIdentity()
	return d
end

-- ของที่อัปได้ทุกชิ้นในกระเป๋า (กฎเดียวกับหน้าเกม: IsRefinable ไม่ใช่ของเควส/ของยืม) แยกที่อยู่บน toolbar
function Up.items()
	local d = data()
	local onBar = {}
	for _, v in ipairs(d.Inventory.Toolbar:GetChildren()) do
		if v:IsA("ValueBase") and v.Value ~= 0 then
			onBar[v.Value] = Up.Slots[v.Name] or v.Name
		end
	end
	local list = {}
	for _, child in ipairs(d.Inventory.Inventory:GetChildren()) do
		local id = child:FindFirstChild("Id")
		if id and child:FindFirstChild("NoSave") == nil and child:FindFirstChild("QuestGrant") == nil
			and Refinement.IsRefinable(child.Name) then
			local def = ItemDefs[child.Name] or {}
			local lvl = child:FindFirstChild("RefineLevel")
			list[#list + 1] = {
				name = child.Name,
				id = id.Value,
				level = lvl and lvl.Value or 0,
				slot = onBar[id.Value],
				kind = def.HasCombat == true and "อาวุธ" or (def.Stats == nil and "เบ็ด" or "ของสวมใส่"),
			}
		end
	end
	fixIdentity()
	table.sort(list, function(a, b)
		if (a.slot ~= nil) ~= (b.slot ~= nil) then
			return a.slot ~= nil
		end
		if a.slot and b.slot then
			return tostring(a.slot) < tostring(b.slot)
		end
		if a.level ~= b.level then
			return a.level > b.level
		end
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.id < b.id
	end)
	return list
end

function Up.levelOf(id)
	local d = data()
	for _, c in ipairs(d.Inventory.Inventory:GetChildren()) do
		local i = c:FindFirstChild("Id")
		if i and i.Value == id then
			local r = c:FindFirstChild("RefineLevel")
			return r and r.Value or 0
		end
	end
	return nil
end

function Up.held(name)
	local n = Refinement.GetHeldCount(data(), name)
	fixIdentity()
	return n
end

-- ขั้นนี้ใช้ Guard ไหม: ขั้นที่ไม่มีโอกาสพลาด (0→1) ไม่เผาใบ Guard ทิ้ง
function Up.guardFor(level)
	local rung = Refinement.GetRung(level, false)
	return Up.useGuard and rung and rung.FailBp > 0 and Up.held(Up.Guard) > 0
end

-- ค่าใช้จ่ายของครั้งถัดไปจริง (รวมหลอม Refinement Ore แทน Mythic ที่ขาด) + ของที่ขาด
function Up.cost(level)
	local guard = Up.guardFor(level)
	local rung = Refinement.GetRung(level, guard)
	if not rung then
		return nil
	end
	local d = data()
	local ores = Refinement.ResolveOreCost(d, rung)
	fixIdentity()
	local need = { { name = "Wen", need = rung.Wen, have = d.Wen.Value } }
	for name, n in pairs(ores) do
		need[#need + 1] = { name = name, need = n, have = Up.held(name) }
	end
	if guard then
		need[#need + 1] = { name = Up.Guard, need = 1, have = Up.held(Up.Guard) }
	end
	local missing = {}
	for _, n in ipairs(need) do
		if n.have < n.need then
			missing[#missing + 1] = string.format("%s ขาด %s", n.name, comma(n.need - n.have))
		end
	end
	return { rung = rung, guard = guard, need = need, missing = missing }
end

-- แผง ------------------------------------------------------------------------

local ui = makePanel("Upgrade อุปกรณ์ / Refine", true)
ui.search.Visible = false
ui.walletBar = Game.walletBar(ui.panel, UDim2.fromOffset(0, 22), { "Wen", "Refinement Ore", "Mythic Refinement Ore", Up.Guard })
-- ปุ่มกรองแบบหน้า Hagane (All / Weapons / Gear / Rods) ใต้แถบเงิน
ui.filterRow.Position = UDim2.fromOffset(0, 48)
ui.list.Position = UDim2.fromOffset(0, 80)
ui.list.Size = UDim2.new(0.42, -6, 1, -136)
local detail = new("ScrollingFrame", {
	Position = UDim2.new(0.42, 6, 0, 48),
	Size = UDim2.new(0.58, -6, 1, -104),
	BackgroundColor3 = Theme.Row,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = Theme.Stroke,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = ui.panel,
}, {
	corner(10),
	new("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}),
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local goLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Text = "เลือกของทางซ้ายก่อน",
	TextColor3 = Theme.Dim,
	TextSize = 15,
	FontFace = font(Enum.FontWeight.SemiBold),
})
local goBtn = new("TextButton", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = Theme.Raised,
	AutoButtonColor = false,
	Text = "",
	Parent = ui.panel,
}, { capsule(), goLabel })

local rows, selected = {}, nil
local rebuild, showDetail

local function selectedItem()
	if not selected then
		return nil
	end
	for _, it in ipairs(Up.items()) do
		if it.id == selected then
			return it
		end
	end
	return nil
end

local function targetOf(it)
	local t = Up.target[it.id]
	if not t or t <= it.level then
		t = math.min(it.level + 1, Up.Max)
		Up.target[it.id] = t
	end
	return t
end

local function refreshGo()
	local it = selectedItem()
	if Up.busy then
		goLabel.Text = "STOP"
		tween(goBtn, { BackgroundColor3 = Theme.Danger }, FAST)
		tween(goLabel, { TextColor3 = Theme.Text }, FAST)
		return
	end
	local enabled = it ~= nil and it.level < Up.Max
	goLabel.Text = not it and "เลือกของทางซ้ายก่อน"
		or it.level >= Up.Max and ("+" .. Up.Max .. " สูงสุดแล้ว")
		or string.format("UPGRADE  ·  %s  +%d → +%d", it.name, it.level, targetOf(it))
	tween(goBtn, { BackgroundColor3 = enabled and Theme.On or Theme.Raised }, FAST)
	tween(goLabel, { TextColor3 = enabled and Theme.Base or Theme.Dim }, FAST)
end

-- ชิ้นส่วนหน้ารายละเอียด ------------------------------------------------------

local function label(parent, text, order, color, size, weight, wrap)
	return new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = wrap ~= false,
		BackgroundTransparency = 1,
		RichText = true,
		Text = text,
		TextColor3 = color or Theme.Dim,
		TextSize = size or 13,
		FontFace = font(weight or Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Parent = parent,
	})
end

-- หัวหัวข้อ: แถบสีซ้าย + ชื่อหัวข้อตัวหนา แยกส่วนให้เห็นชัด (ผู้ใช้ขอ "แยกหัวข้อให้ชัดเจน")
local function section(title, order, color)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = detail,
	})
	new("Frame", {
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.fromOffset(3, 14),
		BackgroundColor3 = color or Theme.Accent,
		BorderSizePixel = 0,
		Parent = row,
	}, { capsule() })
	new("TextLabel", {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -10, 1, 0),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Theme.Text,
		TextSize = 14,
		FontFace = font(Enum.FontWeight.Bold),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
end

-- การ์ดของ: ไอคอนเกม · ชื่อ · ต้องใช้ · มี (เขียวพอ / แดงขาด) แบบเดียวกับหน้าตีเซ็ต
local function costCard(parent, order, i)
	local ok = i.have >= i.need
	local card = new("Frame", {
		BackgroundColor3 = Theme.Raised,
		LayoutOrder = order,
		Parent = parent,
	}, { corner(8), stroke(ok and Theme.Good or Theme.Danger, 1) })
	card:FindFirstChildOfClass("UIStroke").Transparency = 0.55
	local def = ItemDefs[i.name]
	new("ImageLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Theme.Base,
		Image = Game.iconOf(i.name) or "",
		ScaleType = Enum.ScaleType.Fit,
		Parent = card,
	}, { corner(6), stroke(RarityColor[def and def.Rarity or 1] or Theme.Stroke, 1) })
	new("TextLabel", {
		Position = UDim2.fromOffset(48, 5),
		Size = UDim2.new(1, -52, 0, 15),
		BackgroundTransparency = 1,
		Text = i.name,
		TextColor3 = Theme.Text,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.SemiBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(48, 20),
		Size = UDim2.new(1, -52, 0, 13),
		BackgroundTransparency = 1,
		Text = i.note or ("ต่อครั้ง ×" .. comma(i.need)),
		TextColor3 = Theme.Dim,
		TextSize = 12,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(48, 33),
		Size = UDim2.new(1, -52, 0, 13),
		BackgroundTransparency = 1,
		Text = string.format("มี %s%s", comma(i.have), ok and "  ✓" or string.format("  (ขาด %s)", comma(i.need - i.have))),
		TextColor3 = ok and Theme.Good or Theme.Danger,
		TextSize = 12,
		FontFace = font(Enum.FontWeight.SemiBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
end

local function grid(order)
	return new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = detail,
	}, { new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0, 48),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) })
end

-- แถบโอกาสสามสี (สำเร็จ / สำเร็จใหญ่ / พลาด) กว้างตามเปอร์เซ็นต์จริง แบบ OddsBar ของเกม
local function oddsBar(rung, order)
	local wrap = new("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = detail,
	})
	local bar = new("Frame", {
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = Theme.Raised,
		ClipsDescendants = true,
		Parent = wrap,
	}, { capsule(), new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal }) })
	local parts = {
		{ rung.SuccessBp, Theme.Good, "สำเร็จ" },
		{ rung.GreatBp, Theme.Accent, "ข้ามขั้น" },
		{ rung.FailBp, Theme.Danger, "พลาด" },
	}
	local texts = {}
	for i, p in ipairs(parts) do
		if p[1] > 0 then
			new("Frame", {
				Size = UDim2.new(p[1] / 10000, 0, 1, 0),
				BackgroundColor3 = p[2],
				BorderSizePixel = 0,
				LayoutOrder = i,
				Parent = bar,
			})
		end
		texts[#texts + 1] = string.format('<font color="#%s">● %s %s%%</font>', p[2]:ToHex(), p[3], tostring(p[1] / 100))
	end
	new("TextLabel", {
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		RichText = true,
		Text = table.concat(texts, "   "),
		TextColor3 = Theme.Muted,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.SemiBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = wrap,
	})
end

-- เลือกระดับเป้าหมาย +1..+10 ปุ่มระดับที่มีแล้วเป็นสีทึบ เป้าหมายขอบทอง ช่วงที่จะตีขอบจาง
local function levelPicker(it, order)
	local target = targetOf(it)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = detail,
	}, { new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) })
	for lv = 1, Up.Max do
		local have = lv <= it.level
		local isTarget = lv == target
		local inRange = lv > it.level and lv <= target
		local b = new("TextButton", {
			Size = UDim2.new(1 / Up.Max, -4, 1, 0),
			BackgroundColor3 = have and Theme.Accent2 or (isTarget and Theme.Accent or Theme.Raised),
			BackgroundTransparency = inRange and not isTarget and 0.55 or 0,
			AutoButtonColor = false,
			Text = "+" .. lv,
			TextColor3 = (have or isTarget) and Theme.Base or Theme.Muted,
			TextSize = 13,
			FontFace = font(Enum.FontWeight.Bold),
			LayoutOrder = lv,
			Parent = row,
		}, { corner(6) })
		if inRange and not isTarget then
			stroke(Theme.Accent, 1).Parent = b
		end
		track(b.MouseButton1Click:Connect(function()
			if Up.busy then
				return
			end
			if lv <= it.level then
				ui.setStatus(string.format("%s อยู่ +%d แล้ว เลือกระดับที่สูงกว่านี้", it.name, it.level), Theme.Muted)
				return
			end
			Up.target[it.id] = lv
			showDetail()
			refreshGo()
		end))
	end
end

-- ตารางทุกขั้นจากระดับตอนนี้ถึงเป้าหมาย: ค่าใช้จ่ายต่อครั้ง + โอกาส ดูรวดเดียวว่าขั้นไหนยาก
local function ladder(it, target, order)
	local box = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Base,
		LayoutOrder = order,
		Parent = detail,
	}, {
		corner(8),
		new("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	-- หัวตารางใช้ช่องเดียวกับแถว ตัวอักษรไทยกว้างไม่เท่ากัน เว้นวรรคเอาเองแล้วคอลัมน์เบี้ยว
	local head = new("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 0, Parent = box })
	for _, h in ipairs({ { 0, "ขั้น" }, { 0.16, "Wen" }, { 0.37, "แร่ต่อครั้ง" }, { 0.7, "สำเร็จ" }, { 0.85, "พลาด" } }) do
		new("TextLabel", {
			Position = UDim2.new(h[1], 0, 0, 0),
			Size = UDim2.new(0.2, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = h[2],
			TextColor3 = Theme.Dim,
			TextSize = 12,
			FontFace = font(Enum.FontWeight.SemiBold),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = head,
		})
	end
	local wenSum = 0
	for lv = it.level, target - 1 do
		local guard = Up.useGuard and (Refinement.GetRung(lv, false) or {}).FailBp > 0
		local rung = Refinement.GetRung(lv, guard)
		if rung then
			wenSum += rung.Wen
			local ok = (rung.SuccessBp + rung.GreatBp) / 100
			local color = ok >= 50 and Theme.Good or (ok >= 10 and Theme.Accent or Theme.Danger)
			local line = new("Frame", {
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				LayoutOrder = lv + 1,
				Parent = box,
			})
			local function cell(x, w, text, c, align)
				new("TextLabel", {
					Position = UDim2.new(x, 0, 0, 0),
					Size = UDim2.new(w, 0, 1, 0),
					BackgroundTransparency = 1,
					RichText = true,
					Text = text,
					TextColor3 = c or Theme.Muted,
					TextSize = 12,
					FontFace = font(Enum.FontWeight.SemiBold),
					TextXAlignment = align or Enum.TextXAlignment.Left,
					Parent = line,
				})
			end
			cell(0, 0.16, string.format("+%d→+%d", lv, lv + 1), Theme.Text)
			cell(0.16, 0.2, comma(rung.Wen))
			new("ImageLabel", {
				Position = UDim2.new(0.37, 0, 0, 2),
				Size = UDim2.fromOffset(16, 16),
				BackgroundTransparency = 1,
				Image = Game.iconOf(rung.Ore) or "",
				ScaleType = Enum.ScaleType.Fit,
				Parent = line,
			})
			cell(0.37, 0.33, "     ×" .. rung.OreCount .. (rung.Ore:find("Mythic") and " Mythic" or " Ore"))
			cell(0.7, 0.15, tostring(ok) .. "%", color)
			cell(0.85, 0.15, tostring(rung.FailBp / 100) .. "%", rung.FailBp > 0 and Theme.Danger or Theme.Dim)
		end
	end
	label(box, string.format("Wen ถ้าผ่านทุกขั้นครั้งแรก: %s · ขั้นที่โอกาสต่ำต้องตีหลายครั้ง พลาดแล้วระดับตกต้องตีซ้ำ",
		comma(wenSum)), 99, Theme.Dim, 12)
end

function showDetail()
	for _, c in ipairs(detail:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local it = selectedItem()
	if not it then
		label(detail, "เลือกอาวุธ ของสวมใส่ หรือเบ็ดจากรายการทางซ้าย", 1, Theme.Muted, 14)
		return
	end
	local def = ItemDefs[it.name] or {}
	local rarityColor = RarityColor[def.Rarity or 1] or Theme.Muted

	-- หัว: ไอคอน + ป้าย +ระดับ · ชื่อ · ความหายาก ประเภท · ใส่อยู่ช่องไหน
	local head = new("Frame", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = detail,
	})
	local icon = new("ImageLabel", {
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = Theme.Base,
		Image = def.Icon or Game.iconOf(it.name) or "",
		ScaleType = Enum.ScaleType.Fit,
		Parent = head,
	}, { corner(10), stroke(rarityColor, 1.5) })
	if it.level > 0 then
		new("TextLabel", {
			Position = UDim2.fromOffset(3, 2),
			Size = UDim2.fromOffset(26, 15),
			BackgroundColor3 = Theme.Accent2,
			Text = "+" .. it.level,
			TextColor3 = Theme.Base,
			TextSize = 12,
			FontFace = font(Enum.FontWeight.Bold),
			ZIndex = 2,
			Parent = icon,
		}, { capsule() })
	end
	new("TextLabel", {
		Position = UDim2.fromOffset(66, 2),
		Size = UDim2.new(1, -66, 0, 20),
		BackgroundTransparency = 1,
		Text = it.name .. (it.level > 0 and ("  +" .. it.level) or ""),
		TextColor3 = Theme.Text,
		TextSize = 17,
		FontFace = font(Enum.FontWeight.Bold),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = head,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(66, 24),
		Size = UDim2.new(1, -66, 0, 14),
		BackgroundTransparency = 1,
		RichText = true,
		Text = string.format('<font color="#%s">%s</font>  ·  %s', rarityColor:ToHex(),
			(Rarities and Rarities.Order[def.Rarity or 1]) or "?", it.kind),
		TextColor3 = Theme.Dim,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = head,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(66, 42),
		Size = UDim2.new(1, -66, 0, 14),
		BackgroundTransparency = 1,
		Text = it.slot and ("กำลังใส่อยู่ · ช่อง " .. tostring(it.slot)) or "อยู่ในกระเป๋า (ไม่ได้ใส่)",
		TextColor3 = it.slot and Theme.Good or Theme.Muted,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.SemiBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = head,
	})

	if it.level >= Up.Max then
		section("ระดับ", 10, Theme.Good)
		label(detail, string.format("+%d สูงสุดแล้ว อัปต่อไม่ได้", Up.Max), 11, Theme.Good, 14, Enum.FontWeight.SemiBold)
	else
		local target = targetOf(it)

		-- 1 เป้าหมาย
		section("1  อัปถึงระดับ", 10)
		levelPicker(it, 11)
		label(detail, string.format("ตอนนี้ +%d · เป้าหมาย +%d · กดตัวเลขเพื่อเปลี่ยน สคริปต์ตีวนจนถึงเป้าหมาย", it.level, target),
			12, Theme.Muted)

		-- 2 ครั้งถัดไป
		local c = Up.cost(it.level)
		fixIdentity()
		if c then
			section(string.format("2  ครั้งถัดไป  +%d → +%d", it.level, it.level + 1), 20)
			oddsBar(c.rung, 21)
			local g = grid(22)
			for n, need in ipairs(c.need) do
				costCard(g, n, need)
			end
			if #c.missing > 0 then
				label(detail, "ขาด: " .. table.concat(c.missing, " · "), 23, Theme.Danger, 13, Enum.FontWeight.SemiBold)
			else
				label(detail, "ของครบสำหรับครั้งนี้", 23, Theme.Good, 13, Enum.FontWeight.SemiBold)
			end
			if c.rung.Ore == "Mythic Refinement Ore" and Up.held("Mythic Refinement Ore") < c.rung.OreCount then
				label(detail, "Mythic ไม่พอ เกมหลอม Refinement Ore 5 ก้อนแทน Mythic 1 ก้อนให้เอง (นับรวมในการ์ดแล้ว)", 24,
					Theme.Dim, 12)
			end
		end

		-- 3 Guard
		section("3  Refinement Guard (กันระดับตก)", 30, Theme.Accent2)
		local guards = Up.held(Up.Guard)
		local gRow = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = Theme.Base,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = 31,
			Parent = detail,
		}, { corner(8) })
		new("ImageLabel", {
			Position = UDim2.fromOffset(6, 5),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Image = Game.iconOf(Up.Guard) or "",
			ScaleType = Enum.ScaleType.Fit,
			Parent = gRow,
		})
		new("TextLabel", {
			Position = UDim2.fromOffset(38, 0),
			Size = UDim2.new(1, -96, 1, 0),
			BackgroundTransparency = 1,
			Text = string.format("ใช้ Guard ตอนพลาดได้ (มี %d ใบ) · โอกาสข้ามขั้นเพิ่ม 1.5 เท่า", guards),
			TextColor3 = guards > 0 and Theme.Text or Theme.Dim,
			TextSize = 13,
			FontFace = font(Enum.FontWeight.SemiBold),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Parent = gRow,
		})
		local knob = new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(40, 22),
			BackgroundColor3 = Up.useGuard and Theme.On or Theme.Raised,
			Parent = gRow,
		}, { capsule(), stroke() })
		new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = Up.useGuard and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = Up.useGuard and Theme.Base or Theme.Muted,
			Parent = knob,
		}, { capsule() })
		track(gRow.MouseButton1Click:Connect(function()
			if guards == 0 and not Up.useGuard then
				ui.setStatus("ไม่มี Refinement Guard ในกระเป๋า", Theme.Warn)
				return
			end
			Up.useGuard = not Up.useGuard
			showDetail()
		end))
		label(detail, "เผาทีละใบเฉพาะขั้นที่มีโอกาสพลาด · หมดใบแล้วตีต่อแบบไม่มี Guard", 32, Theme.Dim, 12)

		-- 4 ตารางทุกขั้น
		section(string.format("4  ทุกขั้นถึง +%d", target), 40)
		ladder(it, target, 41)
	end

	-- 5 สเตตัส: ตัวคูณจาก Refinement.GetStatMultiplier (สเตตัสหลัก ×เต็ม · รอง ×ครึ่ง) ตอนนี้ → เป้าหมาย
	local stats = Refinement.GetRefineStats(it.name)
	local base = def.ActiveToolStats or def.Stats or {}
	local target = math.max(targetOf(it), it.level)
	section("5  สเตตัสที่อัปขึ้น", 50, Theme.Good)
	for i, stat in ipairs(stats) do
		local v = base[stat]
		local now = Refinement.GetStatMultiplier(it.name, stat, it.level)
		local to = Refinement.GetStatMultiplier(it.name, stat, target)
		local text
		if typeof(v) == "number" and v ~= 0 then
			text = string.format("%s  %s → <font color=\"#%s\">%s</font>  (×%s → ×%s)", stat,
				tostring(math.round(v * now * 100) / 100), Theme.Good:ToHex(), tostring(math.round(v * to * 100) / 100),
				tostring(now), tostring(to))
		else
			text = string.format("%s  ×%s → <font color=\"#%s\">×%s</font>", stat, tostring(now), Theme.Good:ToHex(), tostring(to))
		end
		label(detail, text, 50 + i, Theme.Muted, 13, Enum.FontWeight.SemiBold)
	end
	fixIdentity()
end

-- รายการซ้าย: หัวกลุ่ม "กำลังใส่อยู่" / "ในกระเป๋า" แถวละชิ้น (ชิ้นซ้ำแยกแถวตาม Id แบบหน้าเกม)
local function buildRows()
	for _, c in ipairs(ui.list:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	table.clear(rows)
	local list = Up.items()
	local shown, lastGroup = 0, nil
	for n, it in ipairs(list) do
		if Up.filter == "ทั้งหมด" or Up.filter == it.kind then
			shown += 1
			local group = it.slot and "กำลังใส่อยู่ (toolbar)" or "ในกระเป๋า"
			if group ~= lastGroup then
				lastGroup = group
				new("TextLabel", {
					Size = UDim2.new(1, -6, 0, 22),
					BackgroundTransparency = 1,
					Text = group,
					TextColor3 = it.slot and Theme.Good or Theme.Muted,
					TextSize = 13,
					FontFace = font(Enum.FontWeight.Bold),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Bottom,
					LayoutOrder = n * 2 - 1,
					Parent = ui.list,
				})
			end
			local def = ItemDefs[it.name] or {}
			local frame = new("TextButton", {
				Size = UDim2.new(1, -6, 0, 46),
				BackgroundColor3 = it.id == selected and Theme.Raised or Theme.Row,
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = n * 2,
				Parent = ui.list,
			}, { corner(8) })
			local rim = stroke(Theme.Accent, 1)
			rim.Transparency = it.id == selected and 0.2 or 1
			rim.Parent = frame
			local icon = new("ImageLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(34, 34),
				BackgroundColor3 = Theme.Base,
				Image = def.Icon or Game.iconOf(it.name) or "",
				ScaleType = Enum.ScaleType.Fit,
				Parent = frame,
			}, { corner(7), stroke(RarityColor[def.Rarity or 1] or Theme.Stroke, 1.5) })
			if it.level > 0 then
				new("TextLabel", {
					Position = UDim2.fromOffset(-4, -5),
					Size = UDim2.fromOffset(24, 13),
					BackgroundColor3 = Theme.Accent2,
					Text = "+" .. it.level,
					TextColor3 = Theme.Base,
					TextSize = 10,
					FontFace = font(Enum.FontWeight.Bold),
					ZIndex = 2,
					Parent = icon,
				}, { capsule() })
			end
			new("TextLabel", {
				Position = UDim2.fromOffset(50, 6),
				Size = UDim2.new(1, -54, 0, 16),
				BackgroundTransparency = 1,
				Text = it.name,
				TextColor3 = Theme.Text,
				TextSize = 14,
				FontFace = font(Enum.FontWeight.SemiBold),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = frame,
			})
			new("TextLabel", {
				Position = UDim2.fromOffset(50, 25),
				Size = UDim2.new(1, -54, 0, 14),
				BackgroundTransparency = 1,
				Text = string.format("+%d/%d · %s%s", it.level, Up.Max, it.kind, it.slot and (" · ช่อง " .. tostring(it.slot)) or ""),
				TextColor3 = it.level >= Up.Max and Theme.Good or Theme.Dim,
				TextSize = 12,
				FontFace = font(Enum.FontWeight.Medium),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = frame,
			})
			track(frame.MouseButton1Click:Connect(function()
				if Up.busy then
					ui.setStatus("กำลังอัปอยู่ กด STOP ก่อนเปลี่ยนชิ้น", Theme.Warn)
					return
				end
				selected = it.id
				rebuild()
			end))
			rows[#rows + 1] = frame
		end
	end
	if shown == 0 then
		label(ui.list, "ไม่มีของที่อัปได้ในหมวดนี้", 1, Theme.Muted, 13)
	end
end

function rebuild()
	local d = data()
	local w = Game.wallet()
	fixIdentity()
	w.Wen = d.Wen.Value
	w[Up.Guard] = Up.held(Up.Guard)
	fixIdentity()
	ui.walletBar.set(w)
	if not selected then
		local list = Up.items()
		selected = list[1] and list[1].id
	end
	buildRows()
	showDetail()
	refreshGo()
end

addPills(ui.filterRow, Up.Filters, function(name)
	Up.filter = name
	rebuild()
end)

-- ตีวน ------------------------------------------------------------------------

local function run()
	local it = selectedItem()
	if not it or it.level >= Up.Max then
		return
	end
	local target = targetOf(it)
	Up.busy, Up.cancel = true, false
	refreshGo()
	task.spawn(function()
		local SignalFunction = require(ReplicatedStorage.Communication.ServerAndClient.Signals.SignalFunction)
		local tally = { tries = 0, Success = 0, Great = 0, Fail = 0, Guarded = 0 }
		local wen0, ore0, myth0 = data().Wen.Value, Up.held("Refinement Ore"), Up.held("Mythic Refinement Ore")
		local level = it.level
		local stopWhy
		while not Up.cancel and level < target do
			local c = Up.cost(level)
			if not c then
				stopWhy = "ไม่มีข้อมูลขั้น +" .. level
				break
			end
			if #c.missing > 0 then
				stopWhy = "ของไม่พอ: " .. table.concat(c.missing, " · ")
				break
			end
			local ok, res = pcall(SignalFunction.ToServer, "RefinementRequest", { action = "Attempt", Id = it.id, UseGuard = c.guard })
			fixIdentity()
			if not ok or type(res) ~= "table" or res.Ok ~= true then
				stopWhy = "เกมไม่ยอม: " .. tostring(type(res) == "table" and res.Reason or res)
				break
			end
			tally.tries += 1
			local outcome = res.GuardSaved and "Guarded" or tostring(res.Outcome)
			tally[outcome] = (tally[outcome] or 0) + 1
			local before = level
			level = tonumber(res.Level) or Up.levelOf(it.id) or level
			local th = Up.OutcomeThai[outcome] or { outcome, Theme.Muted }
			ui.setStatus(string.format("ครั้งที่ %d · +%d → %s (+%d) · เป้าหมาย +%d", tally.tries, before, th[1], level, target), th[2])
			task.wait(Up.Gap)
		end
		Up.busy = false
		local spent = string.format("ใช้ Wen %s · Ore %d · Mythic %d", comma(wen0 - data().Wen.Value),
			ore0 - Up.held("Refinement Ore"), myth0 - Up.held("Mythic Refinement Ore"))
		local summary = string.format("%s +%d · ตี %d ครั้ง (สำเร็จ %d · ข้ามขั้น %d · พลาด %d · Guard กัน %d) · %s", it.name,
			level, tally.tries, tally.Success, tally.Great, tally.Fail, tally.Guarded, spent)
		fixIdentity()
		rebuild()
		if level >= target then
			ui.setStatus("ถึงเป้าหมายแล้ว! " .. summary, Theme.Good)
		elseif Up.cancel then
			ui.setStatus("หยุดแล้ว · " .. summary, Theme.Warn)
		else
			ui.setStatus(tostring(stopWhy) .. " · " .. summary, Theme.Danger)
		end
	end)
end

track(goBtn.MouseButton1Click:Connect(function()
	if Up.busy then
		Up.cancel = true
		ui.setStatus("กำลังหยุด…", Theme.Warn)
		return
	end
	run()
end))

local feature = featureRow("Upgrade อุปกรณ์", "ตีเสริมของในกระเป๋าถึงระดับที่เลือก", 1, function()
	rebuild()
	ui.setStatus("เลือกของทางซ้าย · ตั้งระดับเป้าหมาย · กด UPGRADE", Theme.Muted)
	ui.show()
end, function()
	ui.hide()
end)
track(ui.closeButton.MouseButton1Click:Connect(function()
	feature.setOpen(false)
end))
track({
	Disconnect = function()
		Up.cancel = true
	end,
})
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

-- Parry: กดปุ่มบล็อกค้างทันทีที่ม็อบในระยะเริ่มท่าตี -----------------------------
-- วัดแล้ว: กดปุ่มผ่าน VirtualInputManager เกมสร้าง Values.Blocking พร้อม PerfectNpc ที่ 0.076 วิ
-- PerfectNpc (หน้าต่าง parry ใส่ NPC) หายที่ 0.317 วิ ท่าตีม็อบดาเมจเข้าหลังเริ่มท่า 0.14-0.37 วิ
-- กดทันทีที่เห็นท่าจึงครอบเกือบทุกท่า Checker.check_victim คืน "Perfect" ตอน Blocking มี PerfectNpc
-- ต้องกดปุ่มจริง: Skill_Controller ปล่อยบล็อกเองทุกเฟรมถ้า IsKeyDown(ปุ่มบล็อก) เป็น false
-- เรียก Attempt_Hold ตรง ๆ บล็อกอยู่ได้แค่ 0.06 วิ
local Parry = {
	-- ค้างปุ่มเท่านี้ ครอบท่าช้าสุด 0.37 วิ ปล่อยเร็วไป Blocking หายก่อนดาเมจมา
	Hold = 0.45,
}

local function blockKey()
	-- ปุ่มบล็อกคือช่องสกิลแรก (Skills_1st) ผู้เล่นเปลี่ยนปุ่มได้ อ่านจาก InputHandler ของเกม
	local ok, map = pcall(function()
		return require(ReplicatedStorage.CAM.Client.Components.Client.InputHandler).GetMapping("Skills_1st")
	end)
	for _, k in ipairs(ok and map or {}) do
		if typeof(k) == "EnumItem" and k.EnumType == Enum.KeyCode and not k.Name:find("^Button") then
			return k
		end
	end
	return Enum.KeyCode.F
end

local function parryNow()
	if os.clock() < autoDodge.blockUntil then
		return
	end
	-- นอนใต้ม็อบอยู่ไม่บล็อก แต่มุดลึกลงไปอีกช่วงสั้น ๆ (pinUnder อ่าน dipUntil)
	-- บล็อกไม่เหมาะกับท่านี้: ระหว่างค้างปุ่ม Chain.fire ไม่ยิงหมัด และบอสอยู่ห่างแค่ความลึก (8) ในรัศมีเฝ้า 12 เสมอ
	-- ตอน Auto-Quest ตี Hoyuzo (ไม่รู้ว่าตอนนั้น Parry เปิดไหม) หมัดเข้าแค่ 2 ครั้งใน 15 วิ ปกติ 25 ครั้งใน 16 วิ
	-- ม็อบเล็กแทบตีไม่ถึง (Zuko 37 วิเข้า 12 ดาเมจ) แต่บอส 3000 HP ถึง: Obari / Zentaro / Akazo ฆ่าเราได้ 4 ครั้ง
	-- ใน 10 นาทีตอน Auto-Money-Farm log ตอน Akazo: ท่า 117989400565423 เริ่ม แล้วหมัด -46.5 เข้าหลังจากนั้น 0.1 วิ
	-- ตามด้วยคอมโบอีก 2-3 หมัดใน 1.2 วิ (last_combo 1 -> 4 บนโมเดลบอส) ตัวเราตอนนั้นอยู่ลึก 8 ใต้บอสที่เพิ่งตกลงมา
	if killAura.underConn then
		-- มุดทุกท่าแล้วตัวอยู่ลึก 22 เกือบตลอด หมัดเข้าแค่ 24 ครั้งต่อนาทีจาก ~70 มุดเฉพาะตอนเลือดใกล้หมด (ดู DipBelowHp)
		local _, _, myHum = selfParts()
		if not myHum or myHum.Health > myHum.MaxHealth * Combat.DipBelowHp then
			return
		end
		if os.clock() >= (killAura.dipUntil or 0) then
			autoDodge.dips = (autoDodge.dips or 0) + 1
			if autoDodge.parryRow then
				autoDodge.parryRow.setDesc("นอนใต้ม็อบ: มุดหลบไป " .. autoDodge.dips .. " ครั้ง · parry ไป " .. autoDodge.parries .. " ครั้ง")
			end
		end
		killAura.dipUntil = os.clock() + Combat.DipTime
		return
	end
	local key = blockKey()
	autoDodge.blockUntil = os.clock() + Parry.Hold
	autoDodge.parries += 1
	if autoDodge.parryRow then
		autoDodge.parryRow.setDesc("parry ไป " .. autoDodge.parries .. " ครั้ง · เฝ้าท่าตีในระยะ 12 stud")
	end
	VIM:SendKeyEvent(true, key, false, game)
	task.delay(Parry.Hold, function()
		VIM:SendKeyEvent(false, key, false, game)
	end)
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
		if not (autoDodge.on or autoDodge.parry) then
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

		if attackAnims[id] and dist <= Dodge.ThreatRadius and autoDodge.parry then
			-- เปิด Parry อยู่ใช้ parry แทนหลบ ยืนตีต่อได้ไม่ต้องวาร์ปออกไป
			parryNow()
		elseif attackAnims[id] and dist <= Dodge.ThreatRadius then
			blinkAwayFrom(mobRoot)
			dodgeRow.setDesc(string.format("หลบท่า %s · หลบไป %d ครั้ง", mob.Name, autoDodge.dodges))
		elseif autoDodge.parry and not autoDodge.on then
			-- parry อย่างเดียว ไม่ต้องกันเดินกลับเข้าไปแบบโหมดหลบ
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
	if autoDodge.on then
		dodgeRow.setDesc(string.format(
			"โดน -%.0f · หลบ %d · โดน %d · รู้จัก %d ท่า",
			lost,
			autoDodge.dodges,
			autoDodge.hitsTaken,
			learnedCount()
		))
	end
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
			if lost > 0 and (autoDodge.on or autoDodge.parry) then
				onDamaged(lost)
			end
		end)
	end
	if LocalPlayer.Character then
		task.spawn(hookHealth, LocalPlayer.Character)
	end
	dodgeConns[#dodgeConns + 1] = LocalPlayer.CharacterAdded:Connect(hookHealth)

	-- เปิดจาก Parry อย่างเดียว แถว Auto-Dodge ยังปิดอยู่ ไม่ต้องเขียนสถานะทับ
	if autoDodge.on then
		dodgeRow.setDesc(string.format(
			"เฝ้าท่าตีอยู่ · รู้จัก %d ท่า%s",
			learnedCount(),
			restored > 0 and (" (โหลดจากไฟล์ " .. restored .. ")") or ""
		))
	end
end
-- แถว Parry ในการ์ด Kill Aura อยู่นอกบล็อกนี้ เรียกผ่าน autoDodge
autoDodge.start = startDodge

dodgeRow = switchRow("Auto-Dodge", "ปิดอยู่", 4, function(on)
	autoDodge.on = on
	if on then
		autoDodge.dodges, autoDodge.hitsTaken, autoDodge.learned = 0, 0, 0
		startDodge()
	else
		-- Parry ยังเปิดอยู่ใช้ตัวจับท่าชุดเดียวกัน ห้ามถอดทิ้ง
		if not autoDodge.parry then
			stopDodge()
		end
		dodgeRow.setDesc("ปิดอยู่")
	end
end)

end

-- Kill Aura: ยิงคำสั่งตีตรงไปที่เซิร์ฟเวอร์ ไม่ผ่านการคลิก ----------------------

-- หมัดจริงของเกม (CU.Combat -> Main_Combat_Script_Client) ส่งแค่นี้ ไม่มีตัวระบุเป้า:
--   SignalEvent.ToServer("Combat_Service", <ชื่อท่าของอาวุธ>, <เลขคอมโบ 1-Max>, วิ่งตี, ดีเลย์ก่อนโดน, อัปดราฟ, <ชื่อชุดท่าฟัน>)
-- เซิร์ฟเวอร์คิด hitbox จากตำแหน่งและทิศของตัวเราเอง เลยต้องยืน/ลอยติดม็อบอยู่ดี
local Aura = {
	-- hitbox ฝั่งเซิร์ฟเวอร์อยู่รอบตัวเรา ไม่ใช่แค่ด้านหน้า วัดกับโจรรอบละ 5 วิ (หมัดเข้า/ยิง):
	--   ยืนห่าง 3 stud 24%   5 stud 40%   7 / 9 / 11 / 14 / 18 / 25 stud 0%
	--   ลอยสูง 3 stud 50%   6 stud ขึ้นไป 0%   หันหลังให้ที่ 3 stud ยังเข้า 40%
	-- ตั้งระยะในโค้ดให้ไกลกว่านี้ไม่ช่วย เซิร์ฟเวอร์เป็นคนตัดสิน
	Range = 6,
	-- ยืนห่างม็อบเท่านี้ หันหน้าเข้าหา (ดู standBeside)
	Beside = 2.5,
	-- ม็อบในระยะนี้ Kill Aura เดินตามไปยืนข้างเอง ไม่ต้องรอให้เข้ามาใน Range
	-- เดิมรอม็อบเข้า 6 stud เฉย ๆ ตีโดนหมัดเดียวม็อบกระเด็นออกนอกระยะ แล้วค้าง "รอม็อบเข้าระยะ"
	-- ตั้ง 25 แล้ววัดที่ค่ายโจร 30 วิ: ยืนรอ 23 วิ ฆ่าได้ 2 ตัว เพราะโจรเกิดห่างกันเกิน 25
	-- ต้องไม่เกิน ~150 ม็อบที่ไม่มีผู้เล่นใกล้เกิน DespawnDistance หายจากแมพ
	Follow = 80,
	-- ตัวที่ต้องเดิน/วาร์ปไปหา ข้ามตัวที่เลือดเกินนี้ (บอสจริง Gyutai / Datai 3000)
	-- เดิมใช้ Combat.SkipBossAbove 120 ตัด Hoyuzo Subordinate 190 HP ที่ฟาร์ม Demon Horns ทิ้งด้วย
	-- วัดแล้ว: ห่าง 75 stud ยืนรอเฉย 40 วิ
	SkipAbove = 1000,

	-- Kill Aura ระยะไกล: วาร์ปไปยืนข้างม็อบ ตีจนจบคอมโบ แล้ววาร์ปกลับที่เดิมช่วงพักหลังหมัดปิด
	-- ต้องค้างให้เซิร์ฟเวอร์เห็นตำแหน่งก่อนหมัดแรก วัดจากจุดห่าง 30 stud (หมัดเข้าใน 6 วิ):
	--   ยิงเฟรมเดียวกับที่วาร์ป 0   ค้าง 0.1 วิ 6   ค้าง 0.2 วิ 7   ค้าง 0.3 วิ 8   (ยืนติดม็อบตลอด 10)
	-- วาร์ปมา 50 stud แล้วยิงหลัง 0.25 วิ สองหมัดแรกหลุดทั้งคู่ เลยใช้ 0.3
	-- 250 stud ขึ้นไปม็อบหายจากแมพ เพราะเกมลบม็อบที่ไม่มีผู้เล่นใกล้เกิน DespawnDistance = 250
	BlinkRange = 150,
	BlinkBefore = 0.3,
	BlinkAfter = 0.18,
	-- รอบวนตอนรอหมัดถัดไป เวลาหมัดจริงมาจาก Chain ไม่ใช่ตัวนี้
	Poll = 0.03,
}

local combatSignal = ReplicatedStorage:FindFirstChild("Communication")
combatSignal = combatSignal
	and combatSignal:FindFirstChild("ServerAndClient")
	and combatSignal.ServerAndClient:FindFirstChild("Signals")
	and combatSignal.ServerAndClient.Signals:FindFirstChild("SignalEvent")
	and combatSignal.ServerAndClient.Signals.SignalEvent:FindFirstChild("Event")

-- จังหวะคอมโบตามเซิร์ฟ + ชื่อท่าตามอาวุธที่ถือ ใช้ร่วมกันทั้ง Kill Aura และ Insta Kill ----------
--
-- เซิร์ฟคุมความถี่หมัดด้วย Combat_presets.Check_can_do_combat_server (โมดูลใน ReplicatedStorage อ่านได้)
--   หมัด n ต่อจาก n-1 ต้องห่าง preset.default (0.25-0.43 แล้วแต่อาวุธ) หาร Attack Speed
--   หมัด 1 ต่อจากหมัดปิด (Max ปกติ 5) ต้องห่าง preset.final = 1.65   ต่อจาก 1-4 ต้องห่าง combo_duration = 1.35
--   เร็วเกินเซิร์ฟรอให้ไม่เกิน 1 วิ แล้วเช็กใหม่ ถ้ายังไม่ถึง 95% หมัดนั้นทิ้ง
--   เลขคอมโบไม่ต่อกัน รอ 10000 วิ = ทิ้งทุกครั้ง
-- Kill Aura เดิมยิงทุก 0.2 วิ (เร็วกว่า 0.25) และรีเซ็ตคอมโบเองหลังเว้น 1.2 วิ (สั้นกว่า 1.65)
-- หมัดเลยโดนทิ้งเป็นชุด เหลือเข้าจริง ~1.2-2.2 ครั้ง/วิ ดูเหมือน "ม็อบไม่ยอมโดน" ตอนเล่นท่า/ล้ม
-- ตีตามตารางนี้เป๊ะ: Bandit 45 HP ตายใน 1.2 วิ ได้ Wen ครบ
--
-- ช่วงม็อบล้มหลังหมัดปิด (~1.07 วิ) ตรงกับช่วงที่เซิร์ฟบังคับพัก 1.65 วิพอดี ไม่มีหมัดให้ตีอยู่แล้ว
-- ห้ามส่งเลขคอมโบนอก 1-Max ที่ตัวเกมส่งเอง: ลองส่ง 6-20 ใส่ Zuko แล้วโดนเตะ "Exploiting (267)"
local Chain = { last = 0, at = 0, Margin = 0.03 }
do
	local Presets = require(ReplicatedStorage.CAM.Global.Combat_presets)
	local ItemDefs = require(ReplicatedStorage.CAM.Global.Collectibles.Items)
	local CharInfo = require(ReplicatedStorage.CAM.Global.Character_info_provider)
	local Anims = ReplicatedStorage.Assets.Animations
	local Swings = ReplicatedStorage.Effects.Swings
	local ClientEffects = ReplicatedStorage.Communication.CnC.ClientEffects
	local CurPower = ReplicatedStorage.CAM.Client.Controllers.Skills_Provider.CurPower

	-- ชื่อท่าเดียวกับที่ตัวเกมส่ง ลอกจาก get_equipped_Combat + punch ใน CU.Combat
	-- ดาบส่วนใหญ่ไม่มี preset ของตัวเอง ใช้ CombatPreset ของไอเทม ไม่มีก็ "Regular Katana"
	-- (Fancy Katana -> "Regular Katana") มือเปล่าหรืออ่านไม่ออกใช้ "Combat" แบบ Kill Aura เดิม
	-- ส่ง "Combat" ตอนถือดาบ ดาเมจเท่ากัน (6.4 ต่อหมัดทั้งคู่) แต่ช่วงเวลาหมัดคิดจาก preset ผิดตัว
	function Chain.style()
		local tool = CharInfo.Get_equipped_tool(LocalPlayer)
		local item = tool and ItemDefs[tool.Name]
		local name
		if item and item.CombatPreset and item.CombatPreset ~= "Combat" then
			name = tool.Name
		else
			for _, power in ipairs(string.split(CurPower.Value, ",")) do
				if Anims:FindFirstChild(power .. "_Combat_Anims") then
					name = power
					break
				end
			end
			if not name and tool and ((item and item.HasCombat) or Anims:FindFirstChild(tool.Name .. "_Combat_Anims")) then
				name = tool.Name
			end
		end

		local preset = name and Presets.Presets[name]
		local style, swing = name, nil
		if name and not preset then
			local def = ItemDefs[name]
			if def and (def.Breathing ~= nil or def.HasCombat or def.CombatPreset ~= nil) then
				style = def.CombatPreset or "Regular Katana"
				swing = Swings:FindFirstChild(name .. "_Swings") and name or nil
				preset = Presets.Presets[style]
			end
		end
		if not preset then
			return "Combat", Presets.Presets.Combat, nil
		end
		return style, preset, swing
	end

	local function speed()
		local ok, mult = pcall(Presets.attackSpeedMult, LocalPlayer)
		return ok and type(mult) == "number" and mult > 0 and mult or 1
	end

	-- เลขหมัดถัดไป กับเวลา (os.clock) ที่ยิงได้
	function Chain.next(preset)
		local mult = speed()
		local max = preset.Max or 5
		if Chain.last >= max then
			return 1, Chain.at + preset.final / mult + Chain.Margin
		end
		-- หยุดไปนานพอให้เริ่มคอมโบใหม่ได้แล้ว เริ่มที่ 1 เหมือนตัวเกม
		if Chain.last == 0 or os.clock() - Chain.at >= Presets.combo_duration / mult + Chain.Margin then
			return 1, 0
		end
		local n = Chain.last + 1
		local gap = (preset.customDelay and preset.customDelay[n]) or preset.default or 0.25
		return n, Chain.at + gap / mult + Chain.Margin
	end

	-- ยิงหมัดถัดไปถ้าถึงเวลา คืน เลขหมัด, ชื่อท่า / nil, เวลาที่ต้องรออีก
	function Chain.fire()
		-- ต่อยตอนค้างบล็อก เกมยกเลิกบล็อกทิ้ง parry เลยพลาด รอจนปล่อยปุ่มก่อน
		if os.clock() < autoDodge.blockUntil then
			return nil, autoDodge.blockUntil - os.clock()
		end
		-- มุดหลบอยู่ ห่างบอส 22 หมัดไม่ถึง ยิงไปก็เสียเลขคอมโบเปล่า ๆ
		if os.clock() < (killAura.dipUntil or 0) then
			return nil, killAura.dipUntil - os.clock()
		end
		local style, preset, swing = Chain.style()
		local combo, readyAt = Chain.next(preset)
		local left = readyAt - os.clock()
		if left > 0 then
			return nil, left
		end
		-- อัปดราฟ (อาร์กิวเมนต์ที่ 5) ส่งแบบที่ตัวเกมส่งเองเท่านั้น: Main_Combat_Script_Client ส่ง true
		-- เมื่อกดกระโดดค้างตอนต่อยและ CanAirCombo ยังเป็น true ซึ่งเกมตั้งกลับเป็น true ทุกครั้งที่คอมโบขาด
		-- 1.35 วิ (combo_duration) = ใช้ได้ครั้งเดียวต่อคอมโบ หมัด 1 ของเราตามหลังช่วงพัก 1.65 วิเสมอ
		-- วัดกับ Zuko: อัปดราฟหมัด 5 = แค่ล้ม 1 วิเหมือนหมัดปิดปกติ (ท่ายก Swing_6 ออกเฉพาะหมัดที่ยังไม่ใช่หมัดปิด)
		-- อัปดราฟหมัด 1 = ม็อบลอยขึ้น ~8 stud หมัด 2-5 ตีค้างกลางอากาศ ~1.8 วิ แล้วตก ไม่ได้สวนเลย
		-- เกมรีเซ็ต CanAirCombo หลัง combo_duration แบบไม่หารความเร็วตี ส่วนช่วงพักหมัดปิดของเราหาร (final/mult)
		-- ความเร็วตีเกิน ~1.22 หมัด 1 จะมาก่อนเกมรีเซ็ต = ส่งค่าที่ client จริงส่งไม่ได้ เช็กเวลาจริงก่อน
		local updraft = killAura.launch == true and combo == 1
			and os.clock() - Chain.at >= Presets.combo_duration + Chain.Margin
		combatSignal:FireServer("Combat_Service", style, combo, false, 0, updraft, swing)
		Chain.last, Chain.at = combo, os.clock()
		-- ท่าที่ตัวเกมเล่นคู่กับหมัดนี้: อัปดราฟหมัดที่ยังไม่ใช่หมัดปิด = Swing_6 (ท่ายก) ไม่งั้นเลขเดียวกับหมัด
		pcall(Chain.playSwing, style, swing, (updraft and combo < (preset.Max or 5)) and 6 or combo)
		return combo, style
	end

	-- เล่นท่าฟันกับเอฟเฟกต์ในเครื่องเรา แบบเดียวกับ Main_Combat_Script_Client ตอนกดตีจริง
	-- Kill Aura ยิงหมัดตรงถึงเซิร์ฟ ไม่ผ่านสคริปต์ตีของเกม ตัวละครเลยนิ่งทั้งที่หมัดเข้า ~98% (วัด 279 ดาเมจ / 20 วิ
	-- เทียบเพดานเซิร์ฟ ~36 หมัด) ผู้ใช้เห็นแล้วบอก "หนืด ตีไม่โดน" เทียบกับอีกเจ้าที่มีท่าฟันกับประกายทุกหมัด
	-- ความเร็วหมัดจริงเท่ากันทุกอาวุธอยู่แล้ว (Combat_presets: ห่าง 0.25-0.43 พัก 1.65 หลังหมัด 5)
	Chain.tracks = {}
	function Chain.playSwing(style, swing, index)
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if not animator then
			return
		end
		-- ชุดท่าของอาวุธบางชิ้นมีโฟลเดอร์แต่ว่าง (Fancy Katana_Combat_Anims) ไล่หาชุดที่มีท่านี้จริง
		local anim
		for _, setName in ipairs({ swing, style, "Combat" }) do
			local set = setName and Anims:FindFirstChild(setName .. "_Combat_Anims")
			anim = anim or (set and set:FindFirstChild("Swing_" .. index))
		end
		if anim then
			-- LoadAnimation ซ้ำทุกหมัดสะสมแทร็กจนเกมเตือนเกิน 256 เก็บไว้ใช้ซ้ำต่อ Animator
			local key = anim
			local cached = Chain.tracks[key]
			if not cached or cached.animator ~= animator then
				cached = { animator = animator, track = animator:LoadAnimation(anim) }
				Chain.tracks[key] = cached
			end
			cached.track:Play()
		end
		ClientEffects:Fire((swing or style) .. "_Swings", char, index, false)
	end

	function Chain.waitLeft()
		local _, preset = Chain.style()
		local _, readyAt = Chain.next(preset)
		return readyAt - os.clock()
	end
end

-- ม็อบที่ใกล้ที่สุดในระยะ
-- ต้องเป็นตัวที่ใกล้ที่สุดเสมอ เพราะเซิร์ฟเวอร์ตีตามตำแหน่งและทิศของเรา ไม่ได้ตีตามเป้าที่เลือก
-- skipBoss ใช้ตอนต้องเดิน/วาร์ปไปหาเอง: เคยวาร์ปไปตี Gyutai 3000 HP เองโดยไม่ได้สั่ง
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
			local tierOk = not skipBoss or wanted or (hum and hum.MaxHealth <= Aura.SkipAbove)
			if hum and root and hum.Health > 0 and root.Position.Y > Combat.WorldFloorY and tierOk then
				local d = (root.Position - origin).Magnitude
				if d <= (range or Aura.Range) and (not bestD or d < bestD) then
					best, bestD = m, d
				end
			end
		end
	end
	return best
end

-- ใช้อาวุธที่ผู้เล่นถืออยู่ ถ้ามือเปล่าค่อยหยิบช่องแรกที่ติ๊กใน ช่องอาวุธที่ใช้ตี
-- เดิมบังคับสลับไปช่องที่ติ๊กทุกคอมโบ ถือดาบอื่นอยู่ก็โดนดึงกลับ
local function auraFire()
	if heldSlot() == 0 and slotHasItem(primarySlot()) then
		equipSlot(primarySlot())
	end
	local combo, style = Chain.fire()
	if combo then
		killAura.lastFire = os.clock()
		killAura.fires += 1
	end
	return combo, style
end

-- ยืนข้างม็อบแล้วหันหน้าเข้าหา ทุกเฟรมตามเวลาที่กำหนด (0 = เฟรมเดียว) ม็อบเดิน/กระเด็นอยู่ วาร์ปครั้งเดียวตำแหน่งเพี้ยน
-- hitbox ของเซิร์ฟอยู่หน้าตัวเรา (Combat_presets.Get_Players_For_Combat ใช้ lookVector ตอนยืนนิ่ง)
-- วัดกับ Zuko 12 วิ ยิง 21 หมัดเท่ากัน:
--   ยืนข้าง 2.5 stud หันเข้า   เข้า 13 (95 ดาเมจ)
--   ยืนข้าง หันหลังให้         เข้า 2
--   ลอยเหนือหัว 3 stud แบบเดิม  เข้า 0
local function standBeside(hrp, root, seconds)
	local untilT = os.clock() + (seconds or 0)
	repeat
		if not (root.Parent and hrp.Parent) then
			return false
		end
		local dir = (root.Position - hrp.Position) * Vector3.new(1, 0, 1)
		if dir.Magnitude < 0.1 then
			dir = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
		end
		if dir.Magnitude < 0.1 then
			dir = Vector3.new(0, 0, -1)
		end
		dir = dir.Unit
		local spot = root.Position - dir * Aura.Beside
		if not placeAt(hrp, CFrame.lookAt(spot, spot + dir), "beside") then
			return false
		end
		hrp.AssemblyLinearVelocity = Vector3.zero
		if seconds and seconds > 0 then
			game:GetService("RunService").Heartbeat:Wait()
		end
	until os.clock() >= untilT
	return true
end

-- วาร์ปไปตีจนจบคอมโบ (5 หมัดใน ~1.1 วิ) แล้วค่อยกลับ ช่วงพัก 1.65 วิหลังหมัดปิดอยู่ที่เดิม
-- เดิมวาร์ปไปกลับทุกหมัด เสียเวลาค้าง 0.3 วิต่อหมัด ได้ ~2 หมัด/วิ
local function blinkCombo(hrp, mob)
	local root = mob:FindFirstChild("HumanoidRootPart")
	local mobHum = mob:FindFirstChildOfClass("Humanoid")
	if not (root and mobHum) or Chain.waitLeft() > Aura.BlinkBefore then
		return 0
	end
	local home = hrp.CFrame
	local arrived = os.clock()
	local fired = 0
	local _, preset = Chain.style()
	while killAura.on and not killAura.fastKill and root.Parent and mobHum.Health > 0 do
		if not standBeside(hrp, root) then
			break
		end
		if os.clock() - arrived >= Aura.BlinkBefore then
			local combo = auraFire()
			if combo then
				fired += 1
				if combo >= (preset.Max or 5) then
					break
				end
			end
		end
		game:GetService("RunService").Heartbeat:Wait()
	end
	if root.Parent then
		standBeside(hrp, root, Aura.BlinkAfter)
	end
	placeAt(hrp, home, "blink-back")
	hrp.AssemblyLinearVelocity = Vector3.zero
	return fired
end

-- หนึ่งรอบของ Kill Aura แยกออกมาเพื่อครอบ pcall: error กลางลูปเคยทำให้ลูปตายเงียบ
-- ทั้งที่สวิตช์ยังเปิดค้าง คนใช้เห็นแค่ว่า "Kill Aura ไม่ทำงาน"
local function auraStep()
	local _, hrp, hum = selfParts()
	if killAura.fastKill then
		auraRow.setDesc("Insta Kill ยิงหมัดแทนอยู่")
		task.wait(0.2)
	-- ระหว่างหลบ ตัวอยู่ไกลเป้า ยิงไปก็ไม่เข้า ได้แต่เผาโควตาความถี่ของเซิร์ฟเวอร์
	-- โดนตีล้มเองก็ตีไม่ได้ เกมเช็ก Checker.check(combat) ก่อนทุกหมัด
	elseif hrp and hum and hum.Health > 0 and not isKnockedDown(hum) and os.clock() >= autoDodge.holdUntil then
		-- Auto-Attack พาตัวไปเองอยู่แล้ว ใช้ระยะหมัดตรง ๆ ไม่งั้นเดินตามม็อบในระยะ Follow
		-- ตัวที่ยืนติดอยู่แล้วตีได้ทุกตัวรวมบอส ตัวที่ต้องตามไปข้ามบอส (ไม่ลากไปตี Gyutai 3000 HP เอง)
		-- นอนใต้ดินอยู่ ม็อบห่างเท่าความลึก (8) เกิน Range 6 ของหมัดปกติ ขยายให้พอ
		-- hitbox ของเซิร์ฟชี้ขึ้นตาม lookVector ตอนนอนหงาย วัดแล้วหมัดเข้าที่ลึก 8 (ดู Combat.UnderDepth)
		local mob = mobInReach(hrp.Position, killAura.underConn and (Combat.UnderDepth + Aura.Range) or nil)
		if not mob and not autoAttack.on then
			mob = mobInReach(hrp.Position, Aura.Follow, true)
		end
		local far = false
		-- ระยะไกลใช้ตอนไม่ได้เปิด Auto-Attack เท่านั้น Auto-Attack ลอยติดม็อบให้อยู่แล้ว
		-- ถ้าวาร์ปซ้อนกัน สองลูปจะแย่งเขียน CFrame
		if not mob and killAura.far and not autoAttack.on then
			mob = mobInReach(hrp.Position, Aura.BlinkRange, true)
			far = mob ~= nil
		end
		local mobHum = mob and mob:FindFirstChildOfClass("Humanoid")
		if mobHum then
			Runner.hook("engage", mob)
			-- ม็อบล้ม/เล่นท่าอยู่ก็ยิงต่อ ไม่รอลุกแบบเดิม ช่วงล้มหลังหมัดปิดเซิร์ฟพักให้อยู่แล้ว
			local style
			if far then
				if blinkCombo(hrp, mob) > 0 then
					auraRow.setDesc(string.format("วาร์ปตี %s · HP %d/%d · ยิงไป %d", mob.Name,
						math.max(0, math.floor(mobHum.Health)), math.floor(mobHum.MaxHealth), killAura.fires))
				end
			else
				-- ยืนข้างม็อบหันหน้าเข้าหาทุกรอบ รวมช่วงพักหลังหมัดปิด ม็อบกระเด็นไปก็ตามไปทันที
				-- นอนใต้ดินอยู่ (หอคอยตรึงใต้ม็อบเอง) ห้ามดึงขึ้นมายืนข้าง: สองฝั่งแย่งเขียนตำแหน่งทุกเฟรม
				-- ผู้ใช้เจอ "ตีไม่ค่อยโดน โดนม็อบรุม" วัดได้ตัวละครเด้งขึ้นมาระดับม็อบ (dy 0) ทั้งที่ควรอยู่ลึก 8
				if not autoAttack.on and not killAura.underConn then
					local root = mob:FindFirstChild("HumanoidRootPart")
					-- ย้ายไกลเกินระยะหมัด ต้องค้างให้เซิร์ฟเห็นตำแหน่งใหม่ก่อน ยิงทันทีหมัดหลุด (ดู BlinkBefore)
					if (root.Position - hrp.Position).Magnitude > Aura.Range then
						killAura.settleUntil = os.clock() + Aura.BlinkBefore
					end
					standBeside(hrp, root)
				end
				local combo
				if os.clock() >= (killAura.settleUntil or 0) then
					combo, style = auraFire()
				end
				if combo then
					auraRow.setDesc(string.format("ตี %s หมัด %d · HP %d/%d · %s", mob.Name, combo,
						math.max(0, math.floor(mobHum.Health)), math.floor(mobHum.MaxHealth), style))
				end
			end
			task.wait(Aura.Poll)
		else
			auraRow.setDesc("รอม็อบเข้าระยะ " .. (autoAttack.on and Aura.Range or Aura.Follow) .. " stud")
			task.wait(0.1)
		end
	else
		task.wait(0.1)
	end
end

local function auraLoop()
	Chain.last = 0
	while killAura.on do
		local ok, err = pcall(auraStep)
		if not ok then
			auraRow.setDesc("ผิดพลาด: " .. tostring(err):sub(1, 80))
			task.wait(1)
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
		auraRow.setDesc("รอม็อบเข้าระยะ " .. (autoAttack.on and Aura.Range or Aura.Follow) .. " stud")
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

-- ผู้ใช้ขอ: ม็อบออกท่าใส่ระหว่างตี โดนตีล้ม/ชะงักแล้วคอมโบขาด parry กลับทำให้ตีต่อเนื่องได้
-- ตัวจับท่าเป็นชุดเดียวกับ Auto-Dodge (ท่าที่เรียนไว้ในไฟล์ใช้ร่วมกัน)
-- Auto-Money-Farm เปิดให้ระหว่างฟาร์ม (ตอนนอนใต้บอส Parry = มุดหลบ ดู parryNow)
Runner.parryRow = switchRow("Parry อัตโนมัติ", "ปิดอยู่", 7, function(on, row)
	autoDodge.parry = on
	-- parryNow อยู่ในบล็อก Auto-Dodge อัปเดตตัวนับผ่านตรงนี้
	autoDodge.parryRow = row
	if on then
		if not autoDodge.on then
			autoDodge.start()
		end
		row.setDesc("เฝ้าท่าตีของม็อบในระยะ 12 stud · parry ไป " .. autoDodge.parries .. " ครั้ง")
	elseif not autoDodge.on then
		stopDodge()
	end
end)
track({
	Disconnect = function()
		autoDodge.parry = false
	end,
})

-- ตีจากใต้ดิน: เป็นการตั้งค่าของ Auto-Attack / Auto-Quest ไม่ใช่ฟีเจอร์ที่ "กำลังทำงาน" (ป้ายหัวหน้าต่างข้ามตัวนี้)
-- เปิดไว้ตั้งแต่ต้น ผู้ใช้ขอท่านี้มาใช้กับ Auto-Quest ตีบอสแล้วบอสไม่สวน
do
	local row = switchRow("ตีจากใต้ดิน", "ปิดอยู่", 2, function(on, row)
		killAura.launch = on
		if on then
			row.setDesc("Auto-Attack/Auto-Quest นอนหงายใต้พื้นลึก " .. Combat.UnderDepth
				.. " stud หมัดแรกทุกคอมโบยกม็อบลอย ม็อบสวนไม่ได้")
		else
			killAura.releaseUnder()
		end
	end)
	row.setting = true
	row.set(true)

	-- ค่าเดียวกับช่อง Y Axis Offset ของอีกเจ้า (เขาตั้ง 8) วัดแล้วที่ 3 / 5 / 8 หมัดเข้าทั้งหมด 10 ยังไม่ได้วัด
	local depths = { 4, 6, 8, 10 }
	local depthRow
	depthRow = switchRow("ความลึกใต้ดิน", "", 3, function() end, {
		choices = { "4", "6", "8", "10" },
		selected = table.find(depths, Combat.UnderDepth) or 3,
		onChoice = function(i)
			Combat.UnderDepth = depths[i]
			depthRow.setDesc("นอนใต้ HumanoidRootPart ของม็อบ " .. depths[i] .. " stud")
			if killAura.launch then
				row.setDesc("Auto-Attack/Auto-Quest นอนหงายใต้พื้นลึก " .. depths[i]
					.. " stud หมัดแรกทุกคอมโบยกม็อบลอย ม็อบสวนไม่ได้")
			end
		end,
	})
	depthRow.setDesc("นอนใต้ HumanoidRootPart ของม็อบ " .. Combat.UnderDepth .. " stud")
end

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
	-- ระยะของท่าที่อ่าน Config ไม่ออก (ท่ายิงกระสุน / ท่าที่ตั้งชื่อ hitbox ไม่เหมือนเพื่อน)
	-- ท่าอื่นใช้ระยะจริงจาก Config ของเกม (ดู skillReach)
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

-- ระยะที่ท่าตีถึง อ่านจาก ReplicatedStorage.Skills.<ปราณ>.<ท่า>.Config ตัวเดียวกับที่โค้ดเซิร์ฟของท่าใช้
-- (โค้ดเซิร์ฟ <ท่า>Server อยู่ข้างกันใน ReplicatedStorage อ่านได้ทั้งหมด) เซิร์ฟสร้างกล่อง hitbox เป็น
-- HumanoidRootPart.CFrame * <X>_HITBOX_OFFSET ขนาด <X>_HITBOX_SIZE ไม่มีเช็กระยะอื่นเลย (Checker.check_victim ไม่ดูระยะ)
-- ขอบหน้ากล่องจึงอยู่ที่ -offset.Z + size.Z/2 ปราณไฟได้: Flame Tiger 100 (หัวเสือดิ่ง -80 กว้าง 40)
-- Flame Undulation 40, Purgatory 23, Blazing Universe 19.5, Unknowing Fire 13.5 (กล่อง 27 รอบตัว)
-- ท่าที่มี AIM_RANGE พุ่งตัวไปหาจุดเล็งก่อนฟัน (Unknowing Fire 40, Blazing Universe 45) แต่ Kill Aura /
-- Auto-Attack ปักตำแหน่งเราทุกเฟรม ตัวไม่ได้พุ่งจริง นับระยะพุ่งเฉพาะตอนไม่มีลูปไหนคุมตำแหน่ง
local reachCache = {}
local function skillReach(name)
	local cached = reachCache[name]
	if cached == nil then
		cached = false
		for _, folder in ipairs(ReplicatedStorage.Skills:GetChildren()) do
			local config = folder:FindFirstChild(name) and folder[name]:FindFirstChild("Config")
			-- require Config ครบทั้ง 143 ท่าจากฝั่งเราไม่มีตัวไหน error (ลองแล้ว) เลยไม่ครอบ pcall
			local cfg = config and require(config)
			if type(cfg) == "table" then
				local box = 0
				for key, size in pairs(cfg) do
					if typeof(size) == "Vector3" and key:find("HITBOX_SIZE") then
						local offset = cfg[key:gsub("HITBOX_SIZE.*$", "") .. "HITBOX_OFFSET"] or cfg.HITBOX_OFFSET
						local ahead = typeof(offset) == "CFrame" and math.max(0, -offset.Position.Z) or 0
						box = math.max(box, ahead + size.Z / 2, size.X / 2)
					end
				end
				cached = box > 0 and { box = box, dash = type(cfg.AIM_RANGE) == "number" and cfg.AIM_RANGE or 0 }
				break
			end
		end
		reachCache[name] = cached
	end
	if not cached then
		return SkillCast.Range
	end
	local pinned = autoAttack.on or killAura.on or killAura.underConn ~= nil
	return cached.box + (pinned and 0 or cached.dash)
end

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

-- Kill Aura ตีอยู่: กดสกิลเฉพาะช่วงหลังหมัดปิด (หมัด 5) ที่เซิร์ฟบังคับพัก 1.65 วิ หมัดยิงไม่ได้อยู่แล้ว
-- กดตอนไหนก็ได้แบบเดิม วัดกับ Zuko: ตีล้วน 21.2 วิ ใส่ Unknowing Fire ด้วย 23.9 วิ เพราะท่าล็อกตัว 3 วิ
-- (pause_gameplay) ทับกลางคอมโบ เสียหมัดไป ~43 ดาเมจ ได้ท่าคืนมา 49
-- Kill Aura ไม่ได้ยิงเกิน 2 วิ (ไม่มีม็อบในระยะหมัด) ไม่ต้องรอจังหวะ
local function comboPause()
	if not killAura.on or os.clock() - killAura.lastFire > 2 then
		return true
	end
	local _, preset = Chain.style()
	return Chain.last >= (preset.Max or 5) and os.clock() - Chain.at < 0.5
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
		-- หาม็อบในระยะของท่าที่ไกลที่สุดที่ติ๊กไว้ แล้วค่อยเช็กระยะทีละท่าตอนกด
		local farthest = SkillCast.Range
		for slot, skill in ipairs(SkillsProvider.get_current_keys() or {}) do
			if slot > 1 and autoSkill.picked[slot - 1] then
				farthest = math.max(farthest, skillReach(skill.Name))
			end
		end
		local mob = hrp and hum and hum.Health > 0 and not isKnockedDown(hum) and os.clock() >= (Combat.drinkUntil or 0)
			and mobInReach(hrp.Position, farthest)
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
			show(string.format("ไม่มีม็อบในระยะ %d stud · ใช้ไป %d ครั้ง", farthest, autoSkill.casts))
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
					and root and (root.Position - hrp.Position).Magnitude <= skillReach(skill.Name)
					and comboPause()
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
		skillRow.setDesc("รอม็อบเข้าระยะของแต่ละท่า · สกิลที่ยังล็อกจะถูกข้าม")
		task.spawn(skillLoop)
	end
end)

-- งานตกปลาของ Auto-Quest ปิด Auto Skill ชั่วคราวผ่าน Runner (Auto-Quest อยู่เหนือไฟล์ อ้าง skillRow ตรง ๆ ไม่ได้)
function Runner.setSkill(on)
	skillRow.set(on)
end

function Runner.skillOn()
	return autoSkill.on
end

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
-- ทางที่ได้ของจึงมีทางเดียวคือตีให้ถี่ที่สุดที่เซิร์ฟยอมรับ จังหวะหมัดอยู่ใน Chain (ส่วน Kill Aura)
-- ฟังก์ชันที่เรียกทันทีแยกโควตา register จาก chunk หลัก เหตุผลเดียวกับแท็บ Settings
;(function()
local InstaKill = {
	-- โหมด 1 ตอนไม่ได้เปิด Auto-Attack: วาร์ปไปลอยเหนือม็อบที่ใกล้สุดในระยะนี้ (เท่ากับ Kill Aura ระยะไกล)
	-- เกิน 250 ม็อบหายจากแมพเอง (DespawnDistance) ตอนเปิด Auto-Attack ใช้ระยะหมัด Aura.Range แทน
	Range = 150,
	-- โหมด 2 สแกนทุกเท่านี้ ม็อบในแมพมีหลักสิบตัว วนทั้ง Humanoids ทุก 0.15 วิไม่หนัก
	Tick = 0.15,
}

local PctChoices = { "95", "80", "60", "40", "20" }
-- บอสเริ่มที่ ไม่ตี: โหมด ได้ของ วาร์ปหาตัวใกล้สุด แถว Windy Peak มี Gyutai/Datai 3000 HP ห่างแค่ ~200 stud
local insta = { on = false, mode = 1, bossOn = false, mobPct = 95, bossPct = 80, kills = 0, hits = 0 }

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
			and (wanted or insta.bossOn or not isBoss(hum)) then
			local d = (root.Position - origin).Magnitude
			if d <= range and (not bestD or d < bestD) then
				best, bestD = m, d
			end
		end
	end
	return best
end

local killRow
-- identity ของ thread ลูปหล่นเองกลางทาง (executor ตัวนี้ เหมือนที่ Auto Skill เจอ) วัดได้สองรอบ:
-- ฆ่าได้ 2-3 ตัวแล้ว setDesc เจอ "lacking capability Plugin" ลูปตายเงียบ ป้ายค้าง "แตะพื้นรีเซ็ตเวลาลอย"
-- จำ identity ตอนเริ่มไว้ ตั้งคืนทุกรอบลูปและก่อนแตะ GUI ทุกครั้ง
local startIdentity
local function keepIdentity()
	if startIdentity and setthreadidentity then
		setthreadidentity(startIdentity)
	end
end

local function show(text)
	keepIdentity()
	killRow.setDesc(text)
end

-- โหมด 1 --------------------------------------------------------------------
local function fastLoop()
	killAura.fastKill = true
	Chain.last = 0
	while insta.on and insta.mode == 1 do
		keepIdentity()
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
			-- มือเปล่าค่อยหยิบช่องที่ติ๊กไว้ ถืออาวุธอะไรอยู่ก็ตีด้วยอันนั้น (ชื่อท่ามาจาก Chain.style)
			if heldSlot() == 0 and slotHasItem(primarySlot()) then
				equipSlot(primarySlot())
			end
			-- รอจนถึงเวลาหมัดถัดไป ระหว่างนั้นยืนข้างเป้าหันเข้าหาทุกเฟรม (ม็อบเดิน วาร์ปครั้งเดียวตำแหน่งเพี้ยน)
			local fireAt = os.clock() + math.max(0, Chain.waitLeft())
			-- เพิ่งวาร์ปมาถึง ต้องค้างให้เซิร์ฟเห็นตำแหน่งก่อน ยิงเฟรมเดียวกับที่วาร์ปเข้า 0 หมัด (ดู Aura.BlinkBefore)
			if not positioned and (hrp.Position - root.Position).Magnitude > Aura.Range then
				fireAt = math.max(fireAt, os.clock() + Aura.BlinkBefore)
			end
			repeat
				if not positioned and not standBeside(hrp, root) then
					break
				end
				if os.clock() < fireAt then
					game:GetService("RunService").Heartbeat:Wait()
				end
			until os.clock() >= fireAt or not insta.on
			local combo, style
			if insta.on and mob.Parent and mobHum.Health > 0 then
				if not positioned then
					standBeside(hrp, root)
				end
				combo, style = Chain.fire()
			end
			if combo then
				insta.hits += 1
				show(string.format("ตี %s หมัด %d · HP %d/%d · ฆ่าไป %d ตัว · %s", mob.Name, combo,
					math.max(0, math.floor(mobHum.Health)), math.floor(mobHum.MaxHealth), insta.kills, style))
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
		keepIdentity()
		local _, hrp = selfParts()
		local folder = workspace:FindFirstChild("Humanoids")
		for _, m in ipairs(hrp and folder and folder:GetDescendants() or {}) do
			local hum = m:IsA("Model") and m:GetAttribute("IsMob") and not Combat.NeverTarget[m.Name]
				and m:FindFirstChildOfClass("Humanoid")
			local root = hum and m:FindFirstChild("HumanoidRootPart")
			if root and hum.Health > 0 and hum.MaxHealth > 0 and (root.Position - hrp.Position).Magnitude <= InstaKill.Range
				and isnetworkowner(root) then
				-- เขียนแบบ isBoss and bossPct or mobPct ไม่ได้: บอสที่ปิดไว้ (nil) จะหล่นไปใช้เกณฑ์ม็อบธรรมดาแล้วฆ่าบอส
				local pct
				if isBoss(hum) then
					pct = insta.bossOn and insta.bossPct or nil
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
	startIdentity = getthreadidentity and getthreadidentity()
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

-- ตัวเลือกเปอร์เซ็นต์ใช้เฉพาะโหมด ทันที ซ่อนไว้ตอนโหมด ได้ของ ไม่งั้นคนเห็นแล้วนึกว่ามีผล
local pctRows = {}
local function showPctRows()
	for _, row in ipairs(pctRows) do
		row.setVisible(insta.mode == 2)
	end
end

switchRow("โหมด Insta Kill", "ได้ของ = ตีจริงเร็วสุด ได้ของ/เงิน/EXP · ทันที = ตายทันทีแต่ไม่ได้อะไรเลย", 11, function() end, {
	choices = { "ได้ของ", "ทันที" },
	selected = 1,
	onChoice = function(i)
		insta.mode = i
		showPctRows()
	end,
})

switchRow("บอส", "บอส/มินิบอส = เลือดเกิน 100 เช่น Zuko 300", 12, function() end, {
	choices = { "ไม่ตี", "ตีด้วย" },
	selected = 1,
	onChoice = function(i)
		insta.bossOn = i == 2
	end,
})

pctRows[1] = switchRow("เลือดม็อบเหลือ ≤ %", "ม็อบธรรมดาเลือดเหลือเท่านี้แล้วฆ่าทันที", 13, function() end, {
	choices = PctChoices,
	selected = 1,
	onChoice = function(i)
		insta.mobPct = tonumber(PctChoices[i])
	end,
})

pctRows[2] = switchRow("เลือดบอสเหลือ ≤ %", "ใช้เมื่อเลือก บอส = ตีด้วย", 14, function() end, {
	choices = PctChoices,
	selected = 2,
	onChoice = function(i)
		insta.bossPct = tonumber(PctChoices[i])
	end,
})
showPctRows()

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

local cfg = { url = "", on = false, boss = true, quest = true, mobs = true, rare = true, dungeon = true }
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
	return "```ansi\n" .. table.concat(lines, "\n") .. "\n```", list[1].r, list
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
-- คืนรายการที่เรียงแล้วด้วย ให้ post ทำการ์ดไอคอนต่อท้าย
local function dropsSection(drops, emptyText)
	local block, best, list = dropBlock(drops)
	return { "ของที่ได้", { block or emptyText } }, best, list
end

-- ไอคอนไอเทม: Items[ชื่อ].Icon เป็น rbxassetid (ครบทุกชิ้นในเกม ตรวจแล้ว 0 ชิ้นที่ไม่มี)
-- Discord ดึง rbxassetid ไม่ได้ ต้องแปลงเป็นลิงก์ tr.rbxcdn.com ผ่าน thumbnails API ก่อน
-- ถามทีละชุดแล้วเก็บไว้ ชิ้นเดิมไม่ต้องถามซ้ำ ถามไม่ผ่านก็ส่งข้อความได้ตามปกติแค่ไม่มีรูป
local IconDefs = require(ReplicatedStorage.CAM.Global.Collectibles.Items)
local iconUrl = {}
local function fetchIcons(names)
	local ids, byId = {}, {}
	for _, name in ipairs(names) do
		local def = IconDefs[name]
		local id = iconUrl[name] == nil and def and tostring(def.Icon or ""):match("%d+")
		if id then
			ids[#ids + 1] = id
			byId[id] = name
		elseif iconUrl[name] == nil then
			iconUrl[name] = false
		end
	end
	if #ids == 0 then
		return
	end
	local ok, res = pcall(httpRequest, {
		Url = "https://thumbnails.roblox.com/v1/assets?size=150x150&format=Png&isCircular=false&assetIds="
			.. table.concat(ids, ","),
		Method = "GET",
	})
	local okBody, body = pcall(HttpService.JSONDecode, HttpService, ok and res.Body or "")
	for _, e in ipairs(okBody and type(body) == "table" and body.data or {}) do
		local name = byId[tostring(e.targetId)]
		if name and e.state == "Completed" and e.imageUrl then
			iconUrl[name] = e.imageUrl
		end
	end
end

-- การ์ดเล็กต่อไอเทม: ไอคอนเกม + ชื่อ × จำนวน แถบสีตามความหายาก ข้อความเดียวใส่ embed ได้ 10 อัน
-- อันแรกเป็นการ์ดหลัก เหลือให้ไอเทม 9 ชิ้น ที่เกินจากนั้นยังอยู่ในรายการ code block ของการ์ดหลัก
local MaxItemCards = 9
local function itemCards(list)
	local names = {}
	for i = 1, math.min(#list, MaxItemCards) do
		names[i] = list[i].name
	end
	fetchIcons(names)
	local cards = {}
	for i = 1, #names do
		local e = list[i]
		cards[i] = {
			color = colorInt(e.r),
			author = {
				name = string.format("%s  ×%d  ·  %s", e.name, e.n, Rarities.Order[e.r] or "?"),
				icon_url = iconUrl[e.name] or nil,
			},
		}
	end
	return cards
end

local outbox = {}
local function post(embed)
	-- ทำสำเนา ไม่แก้ตัวในคิว: โดน 429 แล้วส่งตัวเดิมซ้ำ items ต้องยังอยู่
	-- items / iconOf ใช้ภายใน ห้ามส่งไป Discord (ช่องที่ไม่รู้จักทำให้ทั้งข้อความโดนปฏิเสธได้)
	local main = table.clone(embed)
	main.items, main.iconOf = nil, nil
	main.footer = { text = "XIIIN" }
	main.timestamp = DateTime.now():ToIsoDate()
	local items, iconOf = embed.items, embed.iconOf
	local embeds = { main }
	if iconOf then
		fetchIcons({ iconOf })
		if iconUrl[iconOf] then
			main.thumbnail = { url = iconUrl[iconOf] }
		end
	end
	for _, c in ipairs(items and itemCards(items) or {}) do
		embeds[#embeds + 1] = c
	end
	return httpRequest({
		Url = cfg.url,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = HttpService:JSONEncode({ username = "XIIIN", embeds = embeds }),
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
	local drops, best, list = dropsSection(b.drops, Runner.lootOn() and "ไม่มีของตก" or "ไม่ได้เก็บ (Auto-Chest ปิดอยู่)")
	local embed = card("ฆ่าบอส " .. b.name, best > 0 and colorInt(best) or 0xE25F5F, { { "บอส", bossLines }, drops })
	embed.items = list
	queue(embed)
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
			local embed = card("ได้ของหายาก!", colorInt(best), { drops, { "ที่มา", { "**จาก:** " .. from } } })
			-- ชิ้นเดียว ใช้รูปไอเทมใหญ่มุมขวาแทนรูปผู้เล่น
			embed.iconOf = value
			queue(embed)
		end
	elseif kind == "dungeon" then
		-- สรุปหนึ่งรอบหอคอย (ดู Ouwi.logRun) ส่งทันทีตอนจบรอบ ไม่รอสรุปรวม
		local run = value
		if cfg.on and cfg.dungeon then
			local lines = {
				string.format("**ถึงชั้น:** %s  ·  **แต้มรวม:** %s  ·  **หีบ Cache:** %s",
					tostring(run.floor or "?"), comma(run.points or 0), tostring(run.caches or 0)),
			}
			if run.goal then
				lines[#lines + 1] = "**รอบนี้เพื่อ:** " .. run.goal
			end
			local spent = {}
			for _, s in ipairs(run.spent or {}) do
				spent[#spent + 1] = string.format("%s × %s  (%s แต้ม)", s.item, comma(s.n), comma(s.points))
			end
			local sections = {
				{ "รอบดันเจี้ยน", lines },
				dropsSection(run.got or {}, "ไม่ได้ของ"),
				{ "แลกแต้ม / ตี", #spent > 0 and spent or { "ไม่ได้แลก" } },
			}
			if run.craftFail then
				table.insert(sections[3][2], 1, run.craftFail)
			end
			-- ส่งตรงไม่เข้าคิว: จบรอบแล้วย้ายเซิร์ฟในไม่กี่วิ คิวยังไม่ทันรอบส่งสคริปต์ก็ถูกปิดไปก่อน
			if httpRequest and validUrl(cfg.url) then
				pcall(post, card("จบรอบดันเจี้ยน Ouwigahara", 0xE0A040, sections))
			end
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
	local drops, best, list = dropsSection(batch.drops, "ยังไม่มีของตก")
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
	local embed = card("สรุปการฟาร์ม", best > 0 and colorInt(best) or 0x6EBE82, {
		{ "ม็อบที่ฆ่า", #lines > 0 and lines or { "-" } },
		drops,
		{ "ช่วงเวลา", {
			string.format("**เวลา:** %d นาทีล่าสุด", minutes),
			string.format("**ฆ่ารวม:** %d ตัว", total),
		} },
	})
	embed.items = list
	queue(embed)
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


-- หน้า ตั้งค่า -----------------------------------------------------------------

local webhookBox = Pages.settings.sections.webhook

-- การ์ดลิงก์: ช่องวางลิงก์ + ปุ่มส่งทดสอบ + บรรทัดสถานะ สวิตช์เลือกเรื่องที่จะส่งเป็นการ์ดแยกข้างล่าง
local page = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Theme.Row,
	BorderSizePixel = 0,
	LayoutOrder = 1,
	Parent = webhookBox,
}, {
	corner(10),
	stroke(),
	new("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	}),
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 16),
	BackgroundTransparency = 1,
	Text = "ลิงก์ Webhook",
	TextColor3 = Theme.Text,
	TextSize = 15,
	FontFace = font(Enum.FontWeight.SemiBold),
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 1,
	Parent = page,
})

local urlRow = new("Frame", {
	Size = UDim2.new(1, 0, 0, 32),
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
	TextSize = 13,
	FontFace = font(Enum.FontWeight.Regular),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ClearTextOnFocus = false,
	Parent = urlRow,
}, { capsule(), new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })

local testLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Text = "ส่งทดสอบ",
	TextColor3 = Theme.Base,
	TextSize = 14,
	FontFace = font(Enum.FontWeight.SemiBold),
})
local testBtn = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0, 84, 1, 0),
	BackgroundColor3 = Theme.On,
	AutoButtonColor = false,
	Text = "",
	Parent = urlRow,
}, { capsule(), testLabel })

local statusLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 14),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = Theme.Muted,
	TextSize = 13,
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
		local drops, _, list = dropsSection(sample, "-")
		drops[1] = "ตัวอย่างของที่ได้ (สีตามความหายากในเกม)"
		local embed = card("เชื่อมต่อสำเร็จ", 0x7AA2FF, { drops })
		embed.items = list
		local ok, res = pcall(post, embed)
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
	end, { parent = webhookBox })
	-- set(true) ยิง onChange ตอนสร้างด้วย เขียนค่าเดิมลงไฟล์ซ้ำ ไม่เสียหาย
	row.set(cfg[key] == true)
	return row
end

settingSwitch("on", "เปิด Webhook", "ปิดไว้ = ไม่ส่งอะไรเลย ปุ่มส่งทดสอบยังใช้ได้", 4)
settingSwitch("boss", "ฆ่าบอส", "ชื่อบอส ครั้งที่ฆ่า ของที่ดรอป และของที่กำลังฟาร์มดรอปหรือยัง", 5)
settingSwitch("quest", "ผ่านเควส", "ชื่อเควสที่ Auto-Quest ทำจบ พร้อมเลเวลและเงิน", 6)
settingSwitch("mobs", "สรุปฆ่าม็อบ", "ทุก " .. Hook.SummaryEvery .. " วิ: ฆ่าอะไรกี่ตัว ได้ของอะไร เงินเพิ่มเท่าไร", 7)
settingSwitch("rare", "ของหายาก", "ได้ของ " .. Rarities.Order[Hook.RareAt] .. " ขึ้นไป แจ้งทันทีไม่รอสรุป", 8)
settingSwitch("dungeon", "จบรอบดันเจี้ยน", "ถึงชั้นไหน แต้มเท่าไร ได้อะไรจากหีบ แลกอะไรไป ของที่ได้กลับมาทั้งหมด", 9)

-- ปุ่มลัด: แสดงอย่างเดียว ปุ่มจริงอยู่ที่ Config.ToggleKey / UnloadKey
local keysCard = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Theme.Row,
	BorderSizePixel = 0,
	LayoutOrder = 1,
	Parent = Pages.settings.sections.keys,
}, {
	corner(10),
	stroke(),
	new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	}),
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
})
for i, pair in ipairs({
	{ Config.ToggleKey.Name, "ซ่อน / แสดงหน้าต่าง" },
	{ Config.UnloadKey.Name, "ปิดสคริปต์ หยุดทุกอย่าง" },
	{ "ลากแถบบน", "ย้ายหน้าต่าง" },
}) do
	local line = new("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = i,
		Parent = keysCard,
	})
	new("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Raised,
		Text = pair[1],
		TextColor3 = Theme.Text,
		TextSize = 13,
		FontFace = font(Enum.FontWeight.SemiBold),
		Parent = line,
	}, { capsule(), new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
	new("TextLabel", {
		Position = UDim2.fromOffset(110, 0),
		Size = UDim2.new(1, -110, 1, 0),
		BackgroundTransparency = 1,
		Text = pair[2],
		TextColor3 = Theme.Muted,
		TextSize = 14,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = line,
	})
end
end)()

-- Anti-AFK -------------------------------------------------------------------

-- Roblox เตะคนที่ไม่มีอินพุตครบ 20 นาที เกมนี้ไม่มีระบบ AFK ของตัวเอง (ค้นชื่อ afk/idle
-- ทั้ง ReplicatedStorage, PlayerScripts, PlayerGui แล้วไม่เจอ) เลยกันแค่ของ Roblox ก็พอ
-- เปิดเองทุกครั้งที่รันสคริปต์ ไม่มีสวิตช์ ผู้ใช้ปล่อยฟาร์มข้ามคืนแล้วหลุดกลางทาง
local AntiAfk = { saves = 0, muted = {} }
do
	-- ชั้นแรก: ปิดตัวรับ Idled ที่มีอยู่ก่อนสคริปต์ (ตอนตรวจมี 1 ตัว source ถูกซ่อน = CoreScript ตัวเตะ)
	-- ทางนี้ไม่ส่งอินพุตอะไรเข้าเกมเลย ต้องทำก่อนต่อตัวของเราเอง ไม่งั้นปิดตัวเองไปด้วย
	if getconnections then
		for _, c in ipairs(getconnections(LocalPlayer.Idled)) do
			c:Disable()
			AntiAfk.muted[#AntiAfk.muted + 1] = c
		end
	end

	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = Theme.Row,
		BorderSizePixel = 0,
		Parent = Pages.settings.sections.afk,
	}, { corner(10), stroke() })
	new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Theme.Good,
		BorderSizePixel = 0,
		Parent = card,
	}, { capsule() })
	new("TextLabel", {
		Position = UDim2.fromOffset(34, 10),
		Size = UDim2.new(1, -48, 0, 18),
		BackgroundTransparency = 1,
		Text = "ทำงานอยู่ · เปิดเองทุกครั้งที่รันสคริปต์",
		TextColor3 = Theme.Text,
		TextSize = 16,
		FontFace = font(Enum.FontWeight.SemiBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	local status = new("TextLabel", {
		Position = UDim2.fromOffset(34, 30),
		Size = UDim2.new(1, -48, 0, 15),
		BackgroundTransparency = 1,
		Text = "ปล่อยทิ้งไว้ได้ทั้งคืน ไม่โดนเตะเพราะไม่ได้กดอะไร 20 นาที",
		TextColor3 = Theme.Dim,
		TextSize = 14,
		FontFace = font(Enum.FontWeight.Regular),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})

	-- ชั้นสอง เผื่อตัวเตะไม่ได้อยู่ในตัวรับที่ปิดไป: Idled ยังยิงเมื่อว่างครบ 2 นาที
	-- คลิกขวาปลอมผ่าน VirtualUser = นับเวลาว่างใหม่ ใช้คลิกขวาเพราะคลิกซ้ายที่มุม (0,0) โดนปุ่มเมนู Roblox
	local VirtualUser = game:GetService("VirtualUser")
	track(LocalPlayer.Idled:Connect(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
		AntiAfk.saves += 1
		status.Text = string.format("กันหลุดไปแล้ว %d ครั้ง · ล่าสุด %s", AntiAfk.saves, os.date("%H:%M"))
	end))
end

-- Auto-Money-Farm ------------------------------------------------------------

-- ทางหาเงินทั้งหมดที่ไล่ดู (ตัวเลขจากตารางของเกม LiveConfig NpcDataTable / ChestsLootTable กับ Shop.GetSellTotals):
--   ขายเหรียญให้ Ginzo: Coin Pouch 1,000 · Coin Pile 300 · Coin Stack 100 · Coin 25 (ราคาไอเทม x sellReturnFactor 0.44)
--     ต้อง Lv 45 + จบเควสกล่องเครื่องประดับของ Ginzo (เว็บ allthings.how / slayers2-game.wiki บอกตรงกัน)
--   บอส 3000 HP 17 ตัว (Rengu, Gyutai, Obari, Datai ...) ดรอป 450 Wen + World Events Chest ที่ได้ Coin Pouch แน่ 2-3 อัน
--     = ~2,950 Wen ต่อตัว คิดเป็น ~0.98 Wen ต่อ HP ที่ต้องตี
--   ม็อบธรรมดา: Bandit 5/45 HP (0.11) Kaiden Subordinate 23/125 (0.18) Hoyuzo 160/1445 + Rare Chest ไม่มีเหรียญ (0.11)
--   หีบ Sealed Cache T3 เฉลี่ย ~930 Wen ต่อหีบ แต่มีแค่ 5 หีบทั้งแมพ เกิดใหม่ 25 นาที ต้องฆ่ายามก่อน
--   เควสวนซ้ำให้ Wen 500-2,250 ต่อรอบ แต่พักรับเควส 30 วิทุกครั้ง และส่วนใหญ่เป็นงานฆ่าม็อบเล็ก
--   Boss Hunts (เควสอีกา) ได้เพิ่ม 1,215-1,890 ต่อบอส แต่เกมให้แค่เผ่า Slayer/Demon/Hybrid
-- บอสคุ้มกว่าม็อบ 5-9 เท่าต่อ HP และท่านอนใต้ดินโดนตีแทบเป็นศูนย์ (Zuko / Hoyuzo) ผู้เล่นอ่อนก็ฟาร์มได้ แค่ช้ากว่า
-- บอสฟื้นเลือด 2%/วิ ถ้าไม่โดนตีเกิน 5 วิ (RegenRate / RegenCooldown บนโมเดล) ห้ามปล่อยช่วงว่างนาน
;(function()
local Money = {
	-- ม็อบที่ได้ Wen ต่อ HP ต่ำกว่านี้ไม่ไปตี บอส World Events ได้ ~0.98 ม็อบธรรมดาดีสุด ~0.18
	MinWenPerHp = 0.5,
	-- ไปถึงจุดเกิดแล้วรอ stream เท่านี้ ไม่เห็นบอสถือว่ายังไม่เกิด
	StreamWait = 4,
	-- บอสเกิดใหม่ทุก 300 วิ (ดู Runner.farm) ตัวที่เพิ่งตายหรือไม่อยู่ ไม่ต้องแวะซ้ำก่อนนี้
	RespawnWait = 300,
	MissingRetry = 90,
	-- ตีไปนานเท่านี้แล้วเลือดบอสไม่ลดเลย (ตีไม่เข้า / ติดที่) ทิ้งไปตัวอื่น
	StuckAfter = 40,
	-- ตายกับตัวเดียวกันครบเท่านี้ในการตีรอบเดียว ทิ้งไปตัวอื่น
	-- เดิม 3: บัญชีเลือด 290 ทิ้ง Enru ตอนบอสเหลือ 1,024/3000 เสียทั้งไฟต์ ส่วนตายแต่ละครั้งเสียแค่เวลาเกิดใหม่
	-- กับเลือดที่บอสฟื้นระหว่างนั้น ตีต่อคุ้มกว่า ตัวที่ตีไม่ลงจริง ๆ ตัว StuckAfter จับได้อยู่แล้ว
	MaxDeaths = 8,
	-- มีเหรียญมูลค่าเท่านี้แล้วค่อยไปขาย วาร์ปไปกลับครั้งหนึ่งใช้ราว 5 วิ เทียบกับฆ่าบอสตัวละ 3-5 นาที
	-- ขายทุก ~2 ตัว (บอสหนึ่งตัวได้ Coin Pouch 2-3 ถุง) เงินเข้ากระเป๋าให้เห็นเร็ว
	SellAt = 5000,
	Ginzo = Vector3.new(273.8, 941.5, 528.2),
	GinzoQuest = "Ill find the jewelry box(Lv 45)",
	Coins = { "Coin Pouch", "Coin Pile", "Coin Stack", "Coin" },
}
local farm = { on = false, loop = 0 }

-- ราคาขายต่อชิ้นจากโค้ดขายของเกมเอง (Shop.GetSellTotals = ราคาไอเทม x sellReturnFactor)
function Money.payout(item)
	local totals = Shop and Shop.GetSellTotals({ [item] = 1 }) or {}
	return totals.Wen or 0
end

-- Wen ที่คาดว่าได้จากหีบหนึ่งใบ นับเฉพาะเหรียญ ของอื่นขายไม่ได้ (Metal Scraps / Refinement Ore เป็น NoSell)
function Money.chestWen(chestId)
	local total = 0
	for _, coin in ipairs(Money.Coins) do
		local chance, bulk = Game.chestChance(chestId, coin)
		if chance then
			local avg = type(bulk) == "table" and (bulk[1] + bulk[2]) / 2 or bulk or 1
			total += chance * avg * Money.payout(coin)
		end
	end
	return total
end

-- เป้าที่คุ้ม เรียง Wen ต่อ HP มากไปน้อย ต้องมีจุดเกิดประจำ (ม็อบอีเวนต์ไม่รู้ว่าจะโผล่ที่ไหน)
function Money.targets()
	if Money.list then
		return Money.list
	end
	local npc = lootTables().npc
	local list = {}
	for _, m in ipairs(Game.mobs()) do
		local data = m.code and npc[m.code]
		local hp = type(data) == "table" and data.Stats and data.Stats.MaxHealth
		if hp and hp > 0 and m.center then
			local wen = (data.Rewards and tonumber(data.Rewards.Wen) or 0) + (data.Chest and Money.chestWen(data.Chest) or 0)
			if wen / hp >= Money.MinWenPerHp then
				list[#list + 1] = { name = m.name, center = m.center, hp = hp, wen = wen, night = data.OnlyAtNight == true }
			end
		end
	end
	table.sort(list, function(a, b)
		if a.wen / a.hp ~= b.wen / b.hp then
			return a.wen / a.hp > b.wen / b.hp
		end
		return a.name < b.name
	end)
	Money.list = list
	return list
end

function Money.coinValue()
	local wallet, total = Game.wallet(), 0
	for _, coin in ipairs(Money.Coins) do
		total += (wallet[coin] or 0) * Money.payout(coin)
	end
	return total
end

function Money.canSell()
	local level = Game.level()
	if level and level < 45 then
		return false, "ขายเหรียญได้ตอน Lv 45"
	end
	if not Game.questDone(Money.GinzoQuest) then
		return false, "ยังไม่จบเควสกล่องของ Ginzo"
	end
	return true
end

-- ขายผ่านทางเดียวกับหน้าคุยของ Ginzo (MerchantActions.GinzoSell): SignalFunction.ToServer("SellItems", { ชื่อ = จำนวน })
-- เซิร์ฟตอบตารางเงินที่ได้ ว่างเปล่า = ไม่ขาย ยืนข้าง Ginzo ก่อนเหมือนคนกดจริง (ร้านซื้อของต้องยืนใกล้แผง)
function Money.sell(say)
	local wallet = Game.wallet()
	local pick = {}
	for _, coin in ipairs(Money.Coins) do
		local n = wallet[coin] or 0
		if n > 0 then
			-- เซิร์ฟรับครั้งละไม่เกิน 999 ต่อชนิด (GetSellTotals clamp)
			pick[coin] = math.min(n, 999)
		end
	end
	if not next(pick) then
		return 0
	end
	local _, hrp = selfParts()
	if not hrp then
		return 0
	end
	say("วาร์ปไปขายเหรียญให้ Ginzo")
	local stand = groundAt(Money.Ginzo + Vector3.new(0, 0, 5)) or Money.Ginzo + Vector3.new(0, 3, 5)
	placeAt(hrp, facing(stand, Money.Ginzo, hrp.CFrame.LookVector), "money-sell")
	hrp.AssemblyLinearVelocity = Vector3.zero
	task.wait(1.5)
	local before = Game.wallet().Wen or 0
	local SignalFunction = require(ReplicatedStorage.Communication.ServerAndClient.Signals.SignalFunction)
	local ok, res = pcall(SignalFunction.ToServer, "SellItems", pick)
	local got = (Game.wallet().Wen or 0) - before
	if not ok or type(res) ~= "table" or not res.Wen then
		say("Ginzo ไม่รับซื้อ: " .. tostring(ok and "ตอบว่างเปล่า" or res))
		return 0
	end
	return math.max(got, res.Wen)
end

-- บอส 3000 HP เท่ากันหมดบนกระดาษ แต่ตีจริงต่างกันมาก (ตัวละคร Lv 78 เลือด ~370 ท่านอนใต้ดิน):
--   Obari 5 นาที ตาย 1 · Zentaro 4.3 นาที ตาย 3 · Gyutai 2.5 นาทีได้แค่ 600 HP ตาย 2 (สกิลหลายจังหวะ + เลือดไหล)
--   Datai 40 วิเลือดไม่ลดเลยสองรอบ
-- เลยจดผลจริงของแต่ละตัวลงไฟล์ แล้วเลือกจาก Wen ต่อวินาทีที่ได้จริง ตัวที่ยังไม่เคยตีได้ลองก่อน
-- แยกไฟล์ตามบัญชี: ผลขึ้นกับความแรงของตัวละคร ตัวที่เก่งกว่าอาจฆ่า Gyutai ได้สบาย
Money.StatsFile = "PathSlayer/money_stats_" .. LocalPlayer.UserId .. ".json"
function Money.stats()
	if not Money.statCache then
		local ok, data = pcall(function()
			return game:GetService("HttpService"):JSONDecode(readfile(Money.StatsFile))
		end)
		Money.statCache = ok and type(data) == "table" and data or {}
	end
	return Money.statCache
end

function Money.record(name, secs, killed, deaths)
	local s = Money.stats()[name] or { fights = 0, kills = 0, deaths = 0, secs = 0 }
	s.fights += 1
	s.kills += killed and 1 or 0
	s.deaths += deaths
	s.secs += secs
	Money.stats()[name] = s
	pcall(writefile, Money.StatsFile, game:GetService("HttpService"):JSONEncode(Money.stats()))
end

-- Wen ต่อวินาทีที่คาดว่าได้: ยังไม่เคยตี = สูงสุด (ลองก่อน) · ตีมาแล้ว = ของจริง (เวลาที่ตายรวมอยู่ในนั้นแล้ว)
-- ตีสองรอบแล้วไม่เคยฆ่าได้ = ตัดทิ้ง (คืน nil) ไม่ตัดจากจำนวนตาย บัญชีเลือด 290 ตายเฉลี่ย 2 ครั้งทุกตัว
function Money.score(t)
	local s = Money.stats()[t.name]
	if not s or s.fights == 0 then
		return math.huge
	end
	if s.kills == 0 and s.fights >= 2 then
		return nil
	end
	return s.kills * t.wen / math.max(s.secs, 1)
end

-- ตัวถัดไป: คะแนนดีสุดในตัวที่ไม่ได้อยู่ในช่วงรอเกิด คะแนนเท่ากันเอาตัวที่ stream อยู่แล้ว (ไม่ต้องวาร์ปไปดู)
function Money.next()
	local now = os.clock()
	local best, bestScore
	for _, t in ipairs(Money.targets()) do
		local score = Money.score(t)
		if score and now >= (farm.wait[t.name] or 0) then
			if liveMobCount(t.name) > 0 then
				score += 1e-6
			end
			if not bestScore or score > bestScore then
				best, bestScore = t, score
			end
		end
	end
	return best
end

-- ฆ่าตัวเดียวจนจบ คืน "killed" / "missing" / "stuck" / "stopped"
function Money.fight(t, alive, say)
	goToSpawn(t.center)
	local streamBy = os.clock() + Money.StreamWait
	while liveMobCount(t.name) == 0 and os.clock() < streamBy and alive() do
		task.wait(0.25)
	end
	if liveMobCount(t.name) == 0 then
		return "missing"
	end
	Runner.attackMob(t.name)
	local deathsAt = farm.deaths
	-- นับว่าตีเข้าจากเลือดที่ลดลงรอบต่อรอบ ไม่ใช่เลือดต่ำสุด: ตายแล้วเกิดใหม่บอสฟื้นเลือด 2%/วิ
	-- (Datai 2807 -> 2989) ดูต่ำสุดแล้วนึกว่าตีไม่เข้า ทิ้งบอสทั้งที่ตีเข้าปกติ
	local lastHp, lastDrop = math.huge, os.clock()
	while alive() do
		local mob
		for _, m in ipairs(workspace.Humanoids:GetDescendants()) do
			if m:IsA("Model") and m.Name == t.name and m:GetAttribute("IsMob") then
				local hum = m:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					mob = hum
				end
			end
		end
		-- หายไปตอนเลือดยังเยอะ = ไม่ได้ตาย (Domae บอสกลางคืนหายตอนสว่างที่ 2843/3000 เคยถูกนับว่าฆ่าได้ใน 5 วิ
		-- ระบบจำผลเลยคิดว่าตัวนี้คุ้มสุด) เช็กทุก 0.5 วิ บอสตีเหลือ 25% แล้วหายถือว่าตาย
		if not mob then
			return lastHp < t.hp * 0.25 and "killed" or "gone"
		end
		if mob.Health < lastHp - 1 then
			lastDrop = os.clock()
		elseif os.clock() - lastDrop > Money.StuckAfter then
			return "stuck"
		end
		-- ตายซ้ำกับตัวเดียวกัน ตัวนี้แรงเกินตัวละครตอนนี้ ทุกครั้งที่ตายบอสฟื้นเลือด 2%/วิระหว่างเราเดินกลับ
		if farm.deaths - deathsAt >= Money.MaxDeaths then
			return "stuck"
		end
		lastHp = mob.Health
		say(string.format("ตี %s · HP %d/%d", t.name, math.floor(mob.Health), math.floor(mob.MaxHealth)))
		task.wait(0.5)
	end
	return "stopped"
end

-- หีบแดง (Sealed Cache) ที่ stream อยู่รอบตัว ใกล้สุดก่อน · ไกลเกินระยะ stream มองไม่เห็นอยู่แล้ว
-- ผู้ใช้สั่ง 25 ก.ย. 2026: ฆ่าบอสเสร็จแวะเคลียร์หีบแดงแถวนั้นก่อน แล้วค่อยไปบอสตัวถัดไป
function Money.nextSealed()
	local events = Game.chestEvents()
	local _, me = selfParts()
	local folder = workspace:FindFirstChild("Chests")
	local best, bestD
	for _, chest in ipairs(me and folder and folder:GetChildren() or {}) do
		if events[chest:GetAttribute("ChestId")] and chest:GetAttribute("IsOpen") == false
			and (farm.sealedSkip[chest] or 0) < os.clock() then
			local d = (chest:GetPivot().Position - me.Position).Magnitude
			if not best or d < bestD then
				best, bestD = chest, d
			end
		end
	end
	return best
end

-- ใบเดียวจนจบ: ฆ่ายาม (เลือดน้อยสุดก่อน ดู Runner.sealedGuard) → prompt เปิด → เปิดแล้วเก็บของ
-- เกณฑ์ทิ้งใช้ชุดเดียวกับ Runner.sealed: ตายครบ MaxDeaths = ยามแรงเกินตัว · ไม่เห็นยามแต่ยังล็อก StuckAfter วิ = ค้าง
function Money.sealed(chest, alive, say)
	local id = chest:GetAttribute("ChestId")
	local pos = chest:GetPivot().Position
	local guards = Game.chestEvents()[id].guards
	local deathsAt = farm.deaths
	local guard, lockedSince
	while alive() and chest.Parent and chest:GetAttribute("IsOpen") == false do
		if farm.deaths - deathsAt >= Runner.Sealed.MaxDeaths then
			farm.sealedSkip[chest] = os.clock() + Runner.Sealed.DeathSkipFor
			say("ยามหีบแดง " .. id .. " แรงเกิน ข้ามไปก่อน")
			break
		end
		local _, me, myHum = selfParts()
		if not (me and myHum and myHum.Health > 0) then
			task.wait(1)
			continue
		end
		local prompt = chest:FindFirstChild("ChestPrompt", true)
		if prompt and prompt.Enabled then
			Runner.haltAttack()
			goToSpawn(pos)
			collectLoot({
				stop = function()
					return not alive()
				end,
				say = say,
			})
			-- เปิดไม่ติด (คนอื่นเปิดก่อน / prompt หาย) อย่าวนกลับมาใบเดิม
			if chest.Parent and chest:GetAttribute("IsOpen") == false then
				farm.sealedSkip[chest] = os.clock() + Runner.Sealed.SkipFor
			end
			break
		end
		local gHum = guard and guard.Parent and guard:FindFirstChildOfClass("Humanoid")
		if not (gHum and gHum.Health > 0) then
			guard = Runner.sealedGuard(pos, guards)
		end
		if guard then
			lockedSince = nil
			Runner.attackMob(guard.Name)
			say(string.format("หีบแดง %s · ฆ่ายาม %s", id, guard.Name))
		else
			Runner.haltAttack()
			goToSpawn(pos)
			lockedSince = lockedSince or os.clock()
			if os.clock() - lockedSince > Runner.Sealed.StuckAfter then
				farm.sealedSkip[chest] = os.clock() + Runner.Sealed.SkipFor
				break
			end
			say("รอหีบแดง " .. id .. " ปลดล็อก")
		end
		task.wait(0.5)
	end
	Runner.haltAttack()
	autoAttack.target = nil
end

local moneyRow
local function farmLoop(mine)
	-- identity ของ thread หล่นเป็น 2 กลางทาง (Auto Skill ตั้งให้ thread ลูก แล้วรั่วมาถึงนี่ เหมือนที่ skillLoop เจอ)
	-- แล้ว screen.Parent (อยู่ใน gethui) พังด้วย "lacking capability Plugin" ตอนรอเควสของ Ginzo วินาทีที่ 33
	-- คืนค่าทุกครั้งที่เช็ก alive ซึ่งลูปเรียกก่อนแตะอย่างอื่นทุกรอบ
	local myIdentity = getthreadidentity and getthreadidentity()
	local function alive()
		if setthreadidentity and myIdentity then
			setthreadidentity(myIdentity)
		end
		return farm.on and farm.loop == mine and not Runner.cancel and screen.Parent ~= nil
			and not (farm.untilDone and farm.untilDone())
	end
	farm.wait = {}
	-- ไม่ล้างข้ามรอบ: Craft ยืมลูปนี้ทีละช่วงสั้น ๆ ล้างทุกครั้ง = กลับไปตายกับยามใบเดิมซ้ำ
	farm.sealedSkip = farm.sealedSkip or {}
	farm.kills, farm.earned = 0, 0
	local started = os.clock()
	local wenAt = Game.wallet().Wen or 0
	local auraWasOn = Runner.auraOn()
	if not auraWasOn then
		Runner.setAura(true)
	end
	-- Parry ตอนนอนใต้บอส = มุดหลบคอมโบบอส ไม่มีตัวนี้ตายบ่อย (Zentaro 3 ครั้งใน 260 วิ)
	local parryWasOn = Runner.parryRow.isOn()
	Runner.parryRow.set(true)
	-- สกิลกดในช่วงพักหลังหมัดปิด (comboPause) เพิ่มดาเมจโดยไม่กินเวลาตี
	local skillWasOn = Runner.skillOn()
	Runner.setSkill(true)
	attackRow.set(false)
	mobOnlyRow.set(false)
	-- กันตัวรันอื่น (Auto-Quest / Auto-Chest ตอนว่าง) มาวาร์ปแย่ง ระหว่างฟาร์ม collectLoot เราเรียกเอง
	Runner.active = true
	Runner.cancel = false

	local function say(text)
		-- Wen ต่อชั่วโมงนับจากเงินจริงที่เพิ่ม + มูลค่าเหรียญที่ยังไม่ได้ขาย
		local mins = (os.clock() - started) / 60
		local gained = (Game.wallet().Wen or 0) - wenAt + Money.coinValue() - farm.coinsAtStart
		local rate = mins > 1 and string.format(" · ~%s/ชม.", comma(math.floor(gained / mins * 60))) or ""
		moneyRow.setDesc(string.format("%s · ฆ่า %d ตาย %d · +%s Wen%s%s", text, farm.kills, farm.deaths,
			comma(math.floor(gained)), rate, farm.note and (" · " .. farm.note) or ""))
		if farm.relay then
			farm.relay(text, farm.kills, gained)
		end
	end
	farm.deaths = 0
	local deathConn = LocalPlayer.CharacterAdded:Connect(function()
		farm.deaths += 1
	end)
	farm.coinsAtStart = Money.coinValue()

	if #Money.targets() == 0 then
		moneyRow.setDesc("ไม่เจอเป้าที่คุ้ม (ข้อมูลม็อบของเกมยังไม่โหลด?)")
	end
	while alive() do
		-- จบเควสของ Ginzo ให้ก่อน ขายเหรียญได้ถึงจะเป็นเงิน (ครั้งเดียว ทำได้ตั้งแต่ Lv 45)
		local canSell, why = Money.canSell()
		local level = Game.level()
		-- เกมให้ถือเควสได้ทีละอัน ถ้าผู้เล่นถือเควสอื่นอยู่ Runner.start ปฏิเสธ (เจอจริง: ถือ Defeat Hoyuzo ไว้)
		-- ไม่ยกเลิกเควสของผู้เล่นให้ บอกไว้บนแถวแล้วลองใหม่ทุกรอบจนกว่าจะว่าง
		local quests = questFolder()
		local held = quests and quests:FindFirstChild("Holder") and quests.Holder:GetChildren()[1]
		-- ถือเควสของ Ginzo อยู่เอง (รับแล้วค้างกลางทาง) ไม่ใช่ตัวขวาง Runner.start ทำต่อจากขั้นที่ค้างให้
		local heldString = held and held:FindFirstChild("QuestString")
		if heldString and heldString.Value == Money.GinzoQuest then
			held = nil
		end
		if not canSell and held then
			why = "ถือเควส " .. held.Name .. " อยู่ จบก่อนถึงจะทำเควสของ Ginzo (ปลดล็อกการขาย) ได้"
		end
		-- ลองซ้ำทุก 5 นาที ครั้งแรกอาจไม่ผ่าน (เคยค้างที่กล่องไม่โผล่ ก่อนมีทางยิง QuestProgress เองใน Runner.pickup)
		if not canSell and not held and os.clock() - farm.triedGinzo > 300 and (not level or level >= 45) then
			farm.triedGinzo = os.clock()
			for _, d in ipairs(Game.quests()) do
				if d.key == Money.GinzoQuest then
					say("ทำเควสกล่องของ Ginzo ก่อน (ปลดล็อกการขายเหรียญ)")
					Runner.haltAttack()
					Runner.active = false
					if Runner.start({ d }) then
						while Runner.active and alive() do
							task.wait(1)
						end
					end
					Runner.active = true
					Runner.cancel = false
				end
			end
			canSell, why = Money.canSell()
		end
		farm.note = not canSell and why or nil

		if canSell and Money.coinValue() >= Money.SellAt then
			Runner.haltAttack()
			Money.sell(say)
		end

		local chest = Money.nextSealed()
		local t = not chest and Money.next()
		if chest then
			Money.sealed(chest, alive, say)
		elseif not t then
			say("บอสทุกตัวยังไม่เกิด รอรอบถัดไป")
			task.wait(3)
		else
			local fightAt, deathsAt = os.clock(), farm.deaths
			local result = Money.fight(t, alive, say)
			Runner.haltAttack()
			autoAttack.target = nil
			if result == "killed" or result == "stuck" then
				Money.record(t.name, os.clock() - fightAt, result == "killed", farm.deaths - deathsAt)
			end
			if result == "killed" then
				farm.kills += 1
				farm.wait[t.name] = os.clock() + Money.RespawnWait
				collectLoot({
					wait = true,
					stop = function()
						return not alive()
					end,
					say = say,
				})
			elseif result == "missing" then
				-- บอสกลางคืน (Sumari, Reaper, Domae, Yahari) กลางวันไม่เกิดเลย แวะทุก 90 วิเปลืองเวลาเปล่า
				farm.wait[t.name] = os.clock() + (t.night and Money.RespawnWait or Money.MissingRetry)
			elseif result == "gone" then
				farm.wait[t.name] = os.clock() + Money.RespawnWait
			elseif result == "stuck" then
				farm.wait[t.name] = os.clock() + Money.RespawnWait
				say("ตี " .. t.name .. " ไม่เข้า ข้ามไปตัวอื่น")
				task.wait(1)
			end
		end
	end

	deathConn:Disconnect()
	Runner.haltAttack()
	autoAttack.target = nil
	-- ปิดสวิตช์ก็เพิ่ม farm.loop ด้วย เดิมเช็กแค่ loop == mine เลยไม่คืน Runner.active ตอนปิด
	-- Auto-Quest ค้าง (กดเลือกเควส / START ไม่ติดเลย) ต้องคืนเสมอ ยกเว้นเปิดรอบใหม่ทับไปแล้ว
	if farm.loop == mine or not farm.on then
		Runner.active = false
	end
	-- ผู้ยืมลูป (Runner.moneyUntil) จบด้วยเงื่อนไข farm.on ยังเป็น true อยู่ ต้องคืน Kill Aura / Parry / Skill ด้วย
	if not farm.on or farm.untilDone then
		if not auraWasOn then
			Runner.setAura(false)
		end
		if not parryWasOn then
			Runner.parryRow.set(false)
		end
		if not skillWasOn then
			Runner.setSkill(false)
		end
	end
end

moneyRow = switchRow("Auto-Money-Farm", "ปิดอยู่", 4, function(on)
	farm.loop += 1
	farm.on = on
	if on then
		if Runner.active then
			moneyRow.setDesc("มีตัวรันอื่นทำงานอยู่ (Auto-Quest?) หยุดก่อนแล้วเปิดใหม่")
			farm.on = false
			return
		end
		farm.triedGinzo = -math.huge
		moneyRow.setDesc("กำลังหาบอสที่คุ้มที่สุด…")
		local mine = farm.loop
		task.spawn(function()
			local ok, err = pcall(farmLoop, mine)
			if not ok then
				Runner.active = false
				moneyRow.setDesc("ผิดพลาด: " .. tostring(err):sub(1, 90))
			end
		end)
	else
		Runner.haltAttack()
	end
end)

-- ตัวรันอื่นยืมลูปฟาร์มเงินไปใช้จน done() เป็นจริง (Get Nightfall Craft: เงินค่าตี + วัสดุเซ็ตจากหีบบอส
-- World Events Chest ได้ไปพร้อมกันในลูปเดียว) relay(ข้อความ, ฆ่าได้, Wen ที่ได้) ส่งความคืบหน้าให้แผงผู้ยืม
-- ลูปตัดสิทธิ์ Runner.active ตอนจบ แต่ผู้ยืมยังทำงานต่อ (ซื้อวัตถุดิบ / ตี) เลยคืนให้หลังจบ
function Runner.moneyUntil(done, relay)
	if farm.on then
		return false, "Auto-Money-Farm เปิดอยู่ ปิดก่อนแล้วกด GET ใหม่"
	end
	farm.loop += 1
	local mine = farm.loop
	farm.on = true
	farm.untilDone = done
	farm.relay = relay
	farm.triedGinzo = farm.triedGinzo or -math.huge
	local ok, err = pcall(farmLoop, mine)
	farm.on = false
	farm.untilDone = nil
	farm.relay = nil
	Runner.active = true
	if not ok then
		return false, tostring(err)
	end
	return done()
end

track({
	Disconnect = function()
		farm.on = false
	end,
})
end)()

-- Auto-Final-Selection -------------------------------------------------------

-- ข้อมูลทั้งหมดอ่านจากเกม (ไม่ได้เดาจากเว็บ):
--   CAM.Global.Subsets.Gameplay.TimedEvents.FinalSelection = { Every = 7200, Requirements = { Level = 45, Race = "Human" } }
--   นับถอยหลังแบบเดียวกับป้ายของเกม (UITimedEvent): Every - ServerTimeNow % Every = เปิดทุกเลขชั่วโมงคู่ตามเวลาเซิร์ฟ
--   ประตูคือป้ายนับถอยหลัง Debree["Final Selection Assets"].PersistentModel ที่ (-2625.6, 291.5, -203.4)
--   เหนือหัวพี่น้อง UbuSister1/2 ในเขต Safezone "Final Selection" ของ Final Selection Plains
-- ตัวสนามสอบไม่อยู่ในแมพนี้: NPC ในสนาม (ที่เว็บบอก Rem, Vael, Klien ...) ไม่มีในข้อมูลของแมพนี้เลย
-- ม็อบสนาม (HandDemon, LesserDemon, Lost, RogueDemon) มีแต่สเตตัส ไม่มีจุดเกิด = เกมส่งคนไปอีกเซิร์ฟ
-- สคริปต์เลยต้องตามไปรันต่อฝั่งนั้นเอง (queue_on_teleport) แล้วเก็บข้อมูลสนามลงไฟล์ก่อน
do
local FinalSel = {
	MainPlace = 136406881576517,
	Gate = Vector3.new(-2625.6, 288, -190),
	-- ไปรอหน้าประตูก่อนเปิดเท่านี้ วาร์ปครั้งเดียวไม่กี่วิ แต่เผื่อ stream และเควสที่กำลังรันต้องหยุดก่อน
	ArriveBefore = 90,
	-- ห่างประตูเกินนี้ระหว่างรอ (โดนตีกระเด็น / ตาย) วาร์ปกลับ
	Leash = 30,
	ScoutFile = "PathSlayer/fs_scout.txt",
}
do
	local ok, TimedEvents = pcall(require, ReplicatedStorage.CAM.Global.Subsets.Gameplay.TimedEvents)
	local ev = ok and TimedEvents.FinalSelection or { Every = 7200, Requirements = { Level = 45, Race = "Human" } }
	FinalSel.Every = ev.Every
	FinalSel.Req = ev.Requirements or {}
end

function FinalSel.left()
	return FinalSel.Every - workspace:GetServerTimeNow() % FinalSel.Every
end

-- คืน nil ถ้าผ่านทุกข้อ ไม่งั้นคืนข้อที่ไม่ผ่าน
function FinalSel.blocker()
	local level, race = Game.level(), Game.race()
	if FinalSel.Req.Level and level and level < FinalSel.Req.Level then
		return string.format("ต้อง Lv %d (ตอนนี้ %d)", FinalSel.Req.Level, level)
	end
	if FinalSel.Req.Race and race and race ~= FinalSel.Req.Race then
		return string.format("ต้องเป็นเผ่า %s (ตอนนี้ %s)", FinalSel.Req.Race, race)
	end
	return nil
end

-- ในสนามสอบ: เก็บทุกอย่างที่เห็นลงไฟล์ ใช้เขียนส่วนทำเควสในสนามต่อจากข้อมูลจริง
function FinalSel.scout()
	local out = {
		"PlaceId " .. game.PlaceId .. "  JobId " .. game.JobId .. "  " .. os.date("!%Y-%m-%d %H:%M:%S UTC"),
	}
	local function dump(v, ind, depth)
		for k, x in pairs(v) do
			if type(x) == "table" and depth < 5 then
				out[#out + 1] = ind .. tostring(k) .. ":"
				dump(x, ind .. "  ", depth + 1)
			elseif type(x) ~= "function" then
				out[#out + 1] = ind .. tostring(k) .. " = " .. tostring(x)
			end
		end
	end
	out[#out + 1] = "== workspace attributes"
	for k, v in pairs(workspace:GetAttributes()) do
		out[#out + 1] = "  " .. k .. " = " .. tostring(v)
	end
	out[#out + 1] = "== player attributes"
	for k, v in pairs(LocalPlayer:GetAttributes()) do
		out[#out + 1] = "  " .. k .. " = " .. tostring(v)
	end
	out[#out + 1] = "== workspace top"
	for _, c in ipairs(workspace:GetChildren()) do
		out[#out + 1] = "  " .. c.ClassName .. " " .. c.Name .. " (" .. #c:GetChildren() .. ")"
	end
	out[#out + 1] = "== prompts"
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			local p = d.Parent:IsA("BasePart") and d.Parent.Position or (d.Parent:IsA("Attachment") and d.Parent.WorldPosition)
			out[#out + 1] = string.format("  %s | %s | %s | %s", d:GetFullName(), d.ActionText, d.ObjectText, tostring(p))
		end
	end
	out[#out + 1] = "== humanoid models"
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") and d ~= LocalPlayer.Character then
			out[#out + 1] = string.format("  %s mob=%s at %s", d:GetFullName(), tostring(d:GetAttribute("IsMob")), tostring(d:GetPivot().Position))
		end
	end
	out[#out + 1] = "== Ouwland regions"
	for _, region in ipairs(ReplicatedStorage.Ouwland.Content:GetChildren()) do
		out[#out + 1] = "## " .. region.Name
		local okR, def = pcall(require, region)
		if okR and type(def) == "table" then
			dump({ Quests = def.Quests, Npcs = def.Npcs, Situations = def.Situations, Dialogues = def.Dialogues }, "  ", 0)
		end
	end
	writefile(FinalSel.ScoutFile, table.concat(out, "\n"))
	return #out
end

-- ในสนามสอบ: เควสต่อกันเป็นสาย เกมใส่เควสถัดไป (NextQuest) ให้เองตอนจบ ไม่ต้องไปรับจากหน้าคุย
-- นิยามอยู่ที่ ReplicatedStorage["Minigames Place"].Content["Final Selection"] (อ่านจากเกม 25 ก.ย. 2026):
--   Locate Rem → Help Rem (เก็บ Apple/Banana/Grapes) → Find Vael → Defeat Demons for Vael (Lesser Demon)
--   → Find Klien → Speak with Klien (เก็บ Nichirin Katana) → Find Rika → Treat Klien (Bandage 25 Wen ร้าน Rika)
--   → Find Mizuto → Defeat Lost (ใต้บ่อน้ำ Y -125 + Submerged Key) → The Dungeon (Parkour Dungeon)
--   → Find Lavato → Mountain Survival (Checkpoints) → Rescue and Hold the Zone → Find Steve → Defeat the Hand Demon
-- ยังไม่รู้วิธีทำ: Parkour Dungeon / Checkpoints / Capture the Zone / Rescue the Civilian ไม่มี TaskSpecs บอก
-- ถึงงานพวกนี้หยุดรอให้ผู้เล่นทำเอง จบแล้วรันต่อเอง
FinalSel.Arena = workspace:GetAttribute("MinigameKey") == "FinalSelection"
-- บ่อของ Lost อยู่ Y -125 ต่ำกว่าพื้นกันตกของแมพหลัก (Combat.WorldFloorY 0) ในสนามนี้พื้นจริงอยู่ Y 0-70
FinalSel.FloorY = -300
-- ของเควส (Bandage) ซื้อที่ Rika ครั้งละชิ้น prompt Purchase เปิดหลังจบ Find Rika
FinalSel.ShopWait = 1.5
-- วาร์ปแล้วรอให้เซิร์ฟเห็นตำแหน่งใหม่ก่อนส่ง remote ที่เซิร์ฟเช็กระยะ (สวิตช์ Parkour 20 stud / Final 75 stud)
FinalSel.ReplicateWait = 1.5
FinalSel.DungeonTries = 2

function FinalSel.content()
	if FinalSel.data then
		return FinalSel.data
	end
	local root = ReplicatedStorage:FindFirstChild("Minigames Place")
	local content = root and root.Content:FindFirstChild("Final Selection")
	if not content then
		return nil
	end
	local data = { quests = {}, npcs = {}, mobs = {}, answers = {} }
	for _, m in ipairs(content.NpcContents.Dialogues.Quests:GetChildren()) do
		for name, q in pairs(require(m)) do
			data.quests[name] = q
		end
	end
	for _, m in ipairs(content.Npcs:GetChildren()) do
		local def = require(m)
		local spawn = def.Spawns and def.Spawns[1]
		if spawn then
			data.npcs[def.Name] = typeof(spawn) == "CFrame" and spawn.Position or spawn
		elseif def.SendOver and def.SendOver.Spawning then
			data.mobs[#data.mobs + 1] = { name = def.Name, center = def.SendOver.Spawning.Center }
		end
	end
	-- คำตอบที่เดินเรื่องต่อของทุก NPC ("Ill find your fruits", "Treat his wounds" ...) ทุกอันที่ไม่ใช่ Close
	-- ส่งเป็นรายการให้ walkDialogue หน้าคุยแต่ละหน้ามีคำตอบที่ใช้ได้แค่อันเดียวอยู่แล้ว
	data.answers[1] = "Locate Rem"
	for _, m in ipairs(content.NpcContents.Dialogues.Yap:GetChildren()) do
		for _, line in pairs(require(m)) do
			if type(line.Answers) == "table" then
				for text in pairs(line.Answers) do
					if text ~= "Close" then
						data.answers[#data.answers + 1] = text
					end
				end
			end
		end
	end
	FinalSel.data = data
	return data
end

function FinalSel.held()
	local quests = questFolder()
	local holder = quests and quests:FindFirstChild("Holder")
	local q = holder and holder:GetChildren()[1]
	if not q then
		return nil
	end
	local str = q:FindFirstChild("QuestString")
	return str and str.Value or q.Name
end

-- หน้าคุยที่ค้างอยู่ (บทมาถึงสนาม / NPC แจ้งจบงาน) กดต่อจนปิด
function FinalSel.clearDialogue()
	local actual = dialogueActual()
	if actual then
		-- หน้ายืนยันซื้อของ Rika มีแค่ Buy / Cancel ตัวปิดของ walkDialogue รู้จักแค่ Close หน้านี้เลยค้างข้ามรอบ
		-- แล้วทุกครั้งที่คุยกับ Rika อ่านได้หน้าเดิม (เจอจริง: ติด Find Rika วน "มี: Cancel / Buy")
		for _, o in ipairs(dialogueOptions(actual)) do
			if o.text:lower():find("cancel", 1, true) then
				clickGui(o.button)
				task.wait(0.5)
			end
		end
		walkDialogue(FinalSel.content().answers, os.clock() + 15)
		local closeBy = os.clock() + 3
		while dialogueActual() and os.clock() < closeBy do
			task.wait(0.2)
		end
	end
end

function FinalSel.talk(npcName)
	local pos = FinalSel.content().npcs[npcName]
	local _, hrp = selfParts()
	if not (pos and hrp) then
		return false, "ไม่รู้ตำแหน่ง " .. npcName
	end
	report("วาร์ปไปคุยกับ " .. npcName, Theme.Accent)
	placeAt(hrp, CFrame.new(pos + Vector3.new(0, 3, 5), pos), "fs-talk")
	local npc
	for _ = 1, 40 do
		npc = findLiveNpc(npcName)
		if npc or Runner.cancel then
			break
		end
		task.wait(0.3)
	end
	if not npc then
		return false, npcName .. " ยังไม่ stream เข้ามา"
	end
	local at = npc:GetPivot().Position
	placeAt(hrp, CFrame.new(at + Vector3.new(0, 0, 4), at), "fs-talk")
	hrp.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.8)
	FinalSel.clearDialogue()
	-- โมเดล Rika มี prompt ซื้อ Bandage (ในร้าน) อยู่ข้างใน หยิบตัวแรกเจอ prompt ซื้อ ขึ้นหน้า Buy / Cancel แทนหน้าคุย
	local chat
	for _, d in ipairs(npc:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.ActionText == "Chat" then
			chat = d
		end
	end
	fireproximityprompt(chat or npc:FindFirstChildWhichIsA("ProximityPrompt", true))
	local openBy = os.clock() + 8
	while os.clock() < openBy and not dialogueActual() do
		task.wait(0.2)
	end
	if not dialogueActual() then
		return false, "เปิดหน้าคุย " .. npcName .. " ไม่ขึ้น"
	end
	local ok, why = walkDialogue(FinalSel.content().answers, os.clock() + 30)
	FinalSel.clearDialogue()
	return ok, why
end

function FinalSel.buy(item)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.ActionText == "Purchase" and d.ObjectText == item then
			report("ซื้อ " .. item .. " ที่ร้าน Rika", Theme.Accent)
			-- กด Buy ในหน้ายืนยันผ่าน getconnections แล้วเงินไม่ลดเลย (Wen ค้าง 101 วนสิบรอบ) handler ค้างรออะไรสักอย่าง
			-- ใช้ทางเดียวกับ Game.buy: ยืนที่แผงแล้วยิง PurchaseFromShop เอง เซิร์ฟเช็กแค่ระยะ ยืนยันผลจากเงินที่ลด
			firePromptAt(d)
			FinalSel.clearDialogue()
			local before = Game.wallet().Wen or 0
			SignalEvent.ToServer("PurchaseFromShop", item, 1)
			local untilT = os.clock() + 4
			while os.clock() < untilT and (Game.wallet().Wen or 0) >= before do
				task.wait(0.25)
			end
			task.wait(FinalSel.ShopWait)
			FinalSel.clearDialogue()
			return (Game.wallet().Wen or 0) < before, "ซื้อ " .. item .. " ไม่เข้า (Wen " .. before .. ")"
		end
	end
	return false, "ไม่เจอปุ่มซื้อ " .. item
end

function FinalSel.kill(mob, taskName, max)
	local _, hrp = selfParts()
	if hrp and (hrp.Position - mob.center).Magnitude > 60 then
		goToSpawn(mob.center)
	end
	Runner.attackMob(mob.name)
	local p = taskProgress(taskName) or 0
	report(string.format("ฆ่า %s  %d/%d", mob.name, p, max), Theme.Accent)
	task.wait(0.5)
end

-- Mountain Survival: คุย Lavato "Im ready" เริ่มด่านก่อน แล้วผ่านธง 4 จุดตามลำดับ
-- ธงแต่ละอันมี TouchPart ใส 3x28x29 (Debree.MountainCheckpoints.CheckpointN) วาร์ปเข้าไปแล้วยิง touch เอง
function FinalSel.checkpoints()
	local folder = workspace.Debree:FindFirstChild("MountainCheckpoints")
	local _, hrp = selfParts()
	if not (folder and hrp) then
		return false, "ไม่เจอ MountainCheckpoints"
	end
	-- ปุ่ม "Im ready" ของ Lavato (QuestActions.StartMountainTrial) ส่งแค่ StartMountainTrial ถ้ายังไม่มีด่านวิ่งอยู่
	-- ด่านที่วิ่งอยู่มี MountainTrialEndsAt บนตัวผู้เล่น หมดเวลาแล้วหาย เริ่มใหม่ได้
	if LocalPlayer:GetAttribute("MountainTrialEndsAt") == nil then
		FinalSel.talk("Lavato")
		SignalEvent.ToServer("StartMountainTrial")
		task.wait(1)
	end
	for i = 1, #folder:GetChildren() do
		local cp = folder:FindFirstChild("Checkpoint" .. i)
		local touch = cp and cp:FindFirstChild("TouchPart")
		if touch and not Runner.cancel then
			report(string.format("Mountain Survival · ธง %d/%d", i, #folder:GetChildren()), Theme.Accent)
			placeAt(hrp, CFrame.new(touch.Position), "fs-checkpoint")
			hrp.AssemblyLinearVelocity = Vector3.zero
			task.wait(0.5)
			firetouchinterest(hrp, touch, 0)
			task.wait(0.1)
			firetouchinterest(hrp, touch, 1)
			task.wait(1)
		end
	end
	return true
end

-- The Dungeon = Parkour Dungeon (ถอดโค้ด CAM.Global.Training["Parkour Dungeon"].Server ดู 25 ก.ย. 2026):
--   เข้าได้ต้องมีสกิล Double Jump + Wall Climb (prompt Train ที่ Debree["Parkour Dungeon"].Ref)
--   ตอน Stop เซิร์ฟให้เครดิตเมื่อ ยืนห่าง Final ไม่เกิน 75 และดึงสวิตช์ครบทุกตัวใน Switchs (7 ตัว)
--   สวิตช์นับจาก training_signaler "StateChanged" + โมเดลสวิตช์ ตอนตัวละครห่างสวิตช์ไม่เกิน 20
-- เลยไม่ต้องปีนจริง วาร์ปไปข้างสวิตช์ทีละตัวส่งเอง แล้วไปยืนที่ Final ส่ง Stop
function FinalSel.dungeon()
	-- ไม่มีสกิลสองตัวนี้ prompt Train ไม่เปิดด่านเลย สวิตช์ / Stop ที่ส่งไปเซิร์ฟทิ้งหมด
	-- ส่ง QuestProgress("The Dungeon", "Complete Dungeon") ตรง ๆ ก็ไม่รับ (ลองแล้ว ตัวนับค้าง 0)
	-- เกมเก็บเป็นตัวนับต่อหมวด ไม่ใช่ชื่อสกิล (Stats.IsSkillUnlocked): SkillTreeUnlockedList["Innate Skills"] = ปลดถึงลำดับไหน
	-- วัดจาก GetSkillInfoFor: Double Jump ลำดับ 1 · Wall Climb ลำดับ 2 ต้องได้ 2 ขึ้นไป
	local slot = equippedSlot()
	local innate = slot and slot:FindFirstChild("SkillTreeUnlockedList")
	innate = innate and innate:FindFirstChild("Innate Skills")
	if not (innate and innate.Value >= 2) then
		report("The Dungeon ต้องปลด Double Jump + Wall Climb (Innate Skills) ก่อน · สอบรอบนี้ไปต่อไม่ได้", Theme.Danger)
		task.wait(10)
		return true
	end
	-- วาร์ปส่งสวิตช์ครบ 7 + ยืนที่ Final ตอน Stop แล้วเซิร์ฟยังไม่ให้เครดิต (ลอง 4 รอบ 25 ก.ย. 2026 ตัวนับค้าง 0)
	-- เซิร์ฟคงเช็กมากกว่าที่ฝั่ง client เห็น ลองเองครบ DungeonTries รอบแล้วหยุดวาร์ป ให้ผู้เล่นวิ่งเอง จบแล้วรันต่อ
	FinalSel.dungeonTries = (FinalSel.dungeonTries or 0) + 1
	if FinalSel.dungeonTries > FinalSel.DungeonTries then
		Runner.haltAttack()
		report("Parkour Dungeon · วิ่งเองตอนนี้ (สคริปต์ไม่วาร์ปแล้ว) จบด่านแล้วระบบไปหา Mizuto ต่อเอง", Theme.Warn)
		task.wait(3)
		return true
	end
	local _, hrp = selfParts()
	-- prompt Train อยู่ที่ Debree["Parkour Dungeon"].Ref ยืนไกลแล้วมันไม่ stream มา (เจอจริง: Ref หายตอนอยู่แมพ Parkour)
	local door = FinalSel.content().quests["The Dungeon"].Markers["Complete Dungeon"].Position
	if hrp and (hrp.Position - door).Magnitude > 60 then
		placeAt(hrp, CFrame.new(door + Vector3.new(0, 3, 6), door), "fs-parkour")
		hrp.AssemblyLinearVelocity = Vector3.zero
		task.wait(2)
	end
	local dungeon = workspace.Debree:FindFirstChild("Parkour Dungeon")
	local prompt = dungeon and dungeon:FindFirstChild("Ref") and dungeon.Ref:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt and hrp then
		report("เข้า Parkour Dungeon (ต้องมี Double Jump + Wall Climb)", Theme.Accent)
		firePromptAt(prompt)
		-- เกมเล่นฉากตัดแล้ววาร์ปเข้าแมพเองราว 6 วิหลังกด (วัด 01:22:35 → 01:22:41) แมพลอยอยู่ Y ~890-1040
		-- เดิมรอ 4 วิ วาร์ปไปสวิตช์แรกก่อน เกมวาร์ปทับทีหลัง สวิตช์แรกหลุด รอจนตัวขึ้นไปอยู่ในแมพจริง
		local inBy = os.clock() + 12
		while os.clock() < inBy and hrp.Position.Y < 800 do
			task.wait(0.25)
		end
		task.wait(1)
	end
	-- Final อยู่ปลายแมพ ยังไม่ stream มาตอนยืนนอกด่าน (เจอจริง: "ไม่เจอแมพ Parkour" ทั้งที่ Switchs มี)
	-- ไปยืนที่สวิตช์ตัวสูงสุด (ปลายทาง) ให้ stream ก่อนค่อยหา
	local map = workspace.Map.DetachedMaps:FindFirstChild("ParkourTraining")
	local switches = map and map:FindFirstChild("Switchs")
	if not (switches and hrp) then
		return false, "ไม่เจอแมพ Parkour"
	end
	-- Lever ต้องดึงเรียง Switch_1 → Switch_7: เกมสร้าง prompt "Pull" (ปุ่ม T) ให้ทีละด่านตาม attribute Level
	-- ดึงแล้วด่านเลื่อน ประตูเปิด แล้วค่อยมี prompt ตัวถัดไป เดิมส่ง StateChanged เองเรียงตาม GetChildren ไม่ได้เครดิต
	local count = #switches:GetChildren()
	for i = 1, count do
		if Runner.cancel then
			return false, "ยกเลิกแล้ว"
		end
		local sw = switches:FindFirstChild("Switch_" .. i)
		if sw then
			local pos = sw:GetPivot().Position
			report(string.format("Parkour · ดึง Lever %d/%d", i, count), Theme.Accent)
			placeAt(hrp, CFrame.new(pos + Vector3.new(0, 3, 4), pos), "fs-parkour")
			hrp.AssemblyLinearVelocity = Vector3.zero
			-- เซิร์ฟวัดระยะ 20 จากตำแหน่งที่มันเห็น 1.5 วิ ค่าเผื่อ ping ยังไม่ได้วัดว่าต่ำสุดเท่าไร
			task.wait(FinalSel.ReplicateWait)
			local pull
			for _ = 1, 12 do
				for _, d in ipairs(sw:GetDescendants()) do
					if d:IsA("ProximityPrompt") and d.Enabled then
						pull = d
					end
				end
				if pull then
					break
				end
				task.wait(0.25)
			end
			if pull then
				fireproximityprompt(pull)
			else
				SignalEvent.ToServer("training_signaler", "StateChanged", sw)
			end
			task.wait(1)
		end
	end
	local final
	for _ = 1, 20 do
		final = map:FindFirstChild("Final", true)
		if final and final:IsA("BasePart") then
			break
		end
		task.wait(0.25)
	end
	if not final then
		SignalEvent.ToServer("training_signaler", "Stop")
		return false, "ไม่เจอจุด Final ของ Parkour"
	end
	report("Parkour · ไปจุด Final", Theme.Accent)
	placeAt(hrp, CFrame.new(final.Position + Vector3.new(0, 4, 0)), "fs-parkour")
	hrp.AssemblyLinearVelocity = Vector3.zero
	-- ไม่ยิง touch ให้ Final: มันอยู่คนละ WorldModel firetouchinterest พัง "new overlap in different world"
	-- เซิร์ฟเช็กแค่ระยะ 75 ตอน Stop อยู่แล้ว
	task.wait(FinalSel.ReplicateWait)
	SignalEvent.ToServer("training_signaler", "Stop")
	task.wait(4)
	return true
end

-- Rescue and Hold the Zone (ถอดโค้ด Minigames Place.ZoneRescue ดู 25 ก.ย. 2026) เซิร์ฟคุมทั้งหมด:
--   Capture the Zone: ยืนในวงรอบ RescueZonePos (attribute บนผู้เล่น) ความคืบหน้าขึ้นทีละ 0.25 วิ
--     ออกนอกวง = รีเป็น 0 ระหว่างนั้นเกมปล่อยม็อบ ZoneDemon มาเป็นระลอก (Kill Aura ตีให้โดยไม่ต้องขยับ)
--   Rescue the Civilian: ยึดวงเสร็จ เกิดโมเดล RescueCivilian มี prompt Rescue (ค้าง 5 วิ) กดแล้วแบกบนตัว
--   Return to Levi: แบกไปถึงห่าง Levi ไม่เกิน 12 เซิร์ฟนับให้เอง
function FinalSel.zone(taskName)
	local _, hrp = selfParts()
	if not hrp then
		return false, "ไม่พบตัวละคร"
	end
	local levi = FinalSel.content().npcs.Levi
	local state = LocalPlayer:GetAttribute("RescueZoneState")
	if state == "Carrying" then
		report("แบก Civilian ไปส่ง Levi", Theme.Accent)
		placeAt(hrp, CFrame.new(levi + Vector3.new(0, 3, 4), levi), "fs-zone")
		hrp.AssemblyLinearVelocity = Vector3.zero
		task.wait(1)
		return true
	end
	if taskName == "Rescue the Civilian" or state == "Captured" then
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.ActionText == "Rescue" and d.Enabled then
				report("ช่วย Civilian (ค้างปุ่ม 5 วิ)", Theme.Accent)
				firePromptAt(d)
				task.wait(1)
				return true
			end
		end
	end
	local pos = LocalPlayer:GetAttribute("RescueZonePos")
	if typeof(pos) ~= "Vector3" then
		report("รอเกมเปิดวง Zone", Theme.Muted)
		task.wait(1)
		return true
	end
	if (hrp.Position - pos).Magnitude > 6 then
		placeAt(hrp, CFrame.new(pos + Vector3.new(0, 3, 0)), "fs-zone")
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
	report(string.format("ยึดวง Zone · %s · %s", tostring(state), tostring(LocalPlayer:GetAttribute("RescueZoneProgress") or "")),
		Theme.Accent)
	task.wait(0.5)
	return true
end

-- ทำเควสที่ถืออยู่หนึ่งจังหวะ แล้วกลับไปอ่านสถานะใหม่ (เควสเปลี่ยนเองตอนจบ)
function FinalSel.step(key)
	local data = FinalSel.content()
	local q = data.quests[key]
	if not q then
		return false, "ไม่รู้จักเควส " .. tostring(key)
	end
	local inst = q.QuestInstance
	local tasks = {}
	for _, t in ipairs(typeof(inst) == "Instance" and inst:FindFirstChild("Tasks") and inst.Tasks:GetChildren() or {}) do
		local maxV = t:FindFirstChild("Max")
		local spec = q.TaskSpecs and q.TaskSpecs[t.Name] or {}
		local p = taskProgress(t.Name)
		local max = maxV and maxV.Value or 1
		if p == nil or p < max then
			tasks[#tasks + 1] = { name = t.Name, spec = spec, max = max, progress = p }
		end
	end
	-- งานคุยส่งของต้องมาหลังงานอื่นเสมอ (Markers.After) ไปคุยก่อน NPC ตอบแค่ "ยังไม่เสร็จ"
	table.sort(tasks, function(a, b)
		return (a.spec.Type == "Deliver" and 1 or 0) < (b.spec.Type == "Deliver" and 1 or 0)
	end)
	local t = tasks[1]
	if not t then
		task.wait(1)
		return true
	end
	if t.spec.Type == "Pickup" then
		return Runner.pickup({ pickup = t.name, max = t.max, anchor = t.spec.Positions and t.spec.Positions[1],
			positions = t.spec.Positions, quest = key }, 1, 1)
	elseif t.spec.Type == "Deliver" then
		local need = t.spec.RequiredItem
		-- Bandage เป็น NoSave อาจไม่โผล่ในกระเป๋าที่ wallet อ่าน ซื้อติดแล้วเว้น 60 วิ ไม่งั้นซื้อซ้ำทุกรอบจน Wen หมด
		FinalSel.boughtAt = FinalSel.boughtAt or {}
		if need and itemCount(need) < (t.spec.Count or 1) and os.clock() - (FinalSel.boughtAt[need] or -math.huge) > 60 then
			local ok, why = FinalSel.buy(need)
			if not ok then
				return false, why
			end
			FinalSel.boughtAt[need] = os.clock()
		end
		local ok, why = FinalSel.talk(t.spec.TargetNpc)
		-- ปุ่มคำตอบของเกม (Functions.QuestActions ถอดโค้ดดู 25 ก.ย. 2026) ส่งแค่ QuestProgress(เควส, งาน)
		-- Treat Klien เปิดมินิเกมแถบเลื่อน 20 วิก่อน ผ่านแล้วค่อยส่ง QuestProgress("Treat Klien", "Treat Klien")
		-- ยืนข้าง NPC อยู่แล้วหลังคุย ส่งเองเลย ไม่ต้องเล่นมินิเกม (กดคำตอบผ่าน getconnections ก็ไม่ติดอยู่ดี)
		if (taskProgress(t.name) or 0) < t.max then
			SignalEvent.ToServer("QuestProgress", key, t.name)
			task.wait(1)
			return (taskProgress(t.name) or t.max) >= t.max or ok, why
		end
		return true
	elseif t.name == "Checkpoints" then
		return FinalSel.checkpoints()
	elseif t.spec.Type == "Dungeon" then
		return FinalSel.dungeon()
	elseif key == "Rescue and Hold the Zone" then
		return FinalSel.zone(t.name)
	end
	for _, mob in ipairs(data.mobs) do
		if t.name:find(mob.name, 1, true) then
			FinalSel.kill(mob, t.name, t.max)
			return true
		end
	end
	Runner.haltAttack()
	report(string.format("%s · งาน \"%s\" สคริปต์ยังทำไม่เป็น ทำเองก่อน จบแล้วรันต่อเอง", key, t.name), Theme.Warn)
	task.wait(2)
	return true
end

function FinalSel.run(alive)
	Combat.WorldFloorY = FinalSel.FloorY
	Runner.active = true
	Runner.cancel = false
	local auraWas = Runner.auraOn()
	Runner.setAura(true)
	local fails = 0
	while alive() do
		local key = FinalSel.held()
		if not key then
			Runner.haltAttack()
			if dialogueActual() then
				FinalSel.clearDialogue()
			else
				report("ไม่มีเควสค้าง · รอเกมให้เควสถัดไป / จบสนาม", Theme.Muted)
				task.wait(2)
			end
		else
			local ok, why = FinalSel.step(key)
			if not ok and alive() then
				fails += 1
				report(string.format("%s · ติด: %s (ลองใหม่ %d)", key, tostring(why), fails), Theme.Warn)
				task.wait(2)
			else
				fails = 0
			end
		end
		task.wait(0.2)
	end
	Runner.haltAttack()
	autoAttack.target = nil
	if not auraWas then
		Runner.setAura(false)
	end
	Runner.active = false
end

do
	local loop = 0
	local row = switchRow("Auto-Final-Selection", "ปิดอยู่", 3, function(on, row)
		loop += 1
		if not on then
			if FinalSel.Arena then
				Runner.stop()
			end
			return
		end
		local mine = loop
		if FinalSel.Arena then
			task.spawn(function()
				local prevSink = Runner.statusSink
				-- จดทุกข้อความลงไฟล์ด้วย ในสนามดู console ของ executor ไม่ได้ ตามรอยจากไฟล์นี้แทน
				local lines = {}
				local function log(text)
					lines[#lines + 1] = os.date("%X ") .. text
					if #lines > 200 then
						table.remove(lines, 1)
					end
					pcall(writefile, "PathSlayer/fs_log.txt", table.concat(lines, "\n"))
				end
				Runner.statusSink = function(text)
					row.setDesc(text)
					log(text)
				end
				local ok, err = pcall(FinalSel.run, function()
					return loop == mine and screen.Parent ~= nil and not Runner.cancel
				end)
				Runner.statusSink = prevSink
				Runner.active = false
				local why = ok and ("หยุดแล้ว (cancel=" .. tostring(Runner.cancel) .. ")") or ("ผิดพลาด: " .. tostring(err):sub(1, 160))
				log(why)
				row.setDesc(why)
			end)
			return
		end
		task.spawn(function()
			local waiting = false
			local lastLeft = FinalSel.left()
			while loop == mine and screen.Parent do
				local left = FinalSel.left()
				local blocker = FinalSel.blocker()
				local clock = string.format("%d:%02d", math.floor(left / 60), math.floor(left % 60))
				if blocker then
					row.setDesc("สอบไม่ได้: " .. blocker .. " · รอบถัดไปอีก " .. clock)
				elseif left <= FinalSel.ArriveBefore then
					if not waiting then
						waiting = true
						-- เควส/ฟาร์มที่กำลังรันจะพาตัวออกจากประตู หยุดก่อน
						if Runner.active then
							Runner.stop()
						end
						attackRow.set(false)
						mobOnlyRow.set(false)
						-- ตามไปสนามสอบเองอยู่แล้ว (queue_on_teleport ท้ายไฟล์) เดิมใส่คิวซ้ำแบบอ่านไฟล์ในเครื่อง
						-- executor เก็บแค่คิวล่าสุด ผู้ใช้ที่รันจากลิงก์ไม่มีไฟล์นั้น เลยโหลดไม่ขึ้นในสนาม
					end
					local _, hrp = selfParts()
					if hrp and (hrp.Position - FinalSel.Gate).Magnitude > FinalSel.Leash then
						local stand = groundAt(FinalSel.Gate) or FinalSel.Gate
						placeAt(hrp, CFrame.lookAt(stand, Vector3.new(-2625.6, stand.Y, -203.4)), "final-selection")
						hrp.AssemblyLinearVelocity = Vector3.zero
					end
					row.setDesc("รอหน้าประตูสอบ · เปิดในอีก " .. clock .. " · เกมจะส่งเข้าสนามเอง")
				else
					row.setDesc(string.format("รอบถัดไปอีก %s · จะไปรอหน้าประตูก่อน %d วิ", clock, FinalSel.ArriveBefore))
				end
				-- นับถอยหลังวนกลับขึ้นไปแปลว่าเลยเวลาเปิดแล้ว ยังอยู่แมพนี้ = ไม่ได้ถูกส่งเข้าสนาม
				if waiting and left > lastLeft then
					waiting = false
					row.setDesc("เลยเวลาเปิดแล้วแต่ไม่ถูกส่งเข้าสนาม (สอบผ่านแล้ว/เซิร์ฟไม่รับ?) · รอรอบถัดไป")
					task.wait(5)
				end
				lastLeft = left
				task.wait(1)
			end
		end)
	end)
	-- เพิ่งโดนส่งมาอีกเซิร์ฟ (สนามสอบ): เก็บข้อมูลลงไฟล์ บอกในแถว
	-- สนามสอบเก็บข้อมูลครบแล้ว (ดูหัว FinalSel.content) และไม่มี Ouwland ให้ scout อ่าน พังทุกครั้ง
	if game.PlaceId ~= FinalSel.MainPlace and not FinalSel.Arena then
		task.delay(5, function()
			local okS, n = pcall(FinalSel.scout)
			row.setDesc(okS and ("อยู่เซิร์ฟสนามสอบ · เก็บข้อมูลสนาม " .. n .. " บรรทัดลง " .. FinalSel.ScoutFile)
				or ("อยู่เซิร์ฟสนามสอบ · เก็บข้อมูลพัง: " .. tostring(n)))
		end)
	end
end
end

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
-- แท่งตั้งที่ทำให้ขีดกลายเป็น + ตอนย่ออยู่
local plusBar = minBtn:FindFirstChildOfClass("Frame"):Clone()
plusBar.Rotation = 90
plusBar.Visible = false
plusBar.Parent = minBtn
track(minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	plusBar.Visible = minimized
	-- ป้ายปุ่มลัดยึดขอบล่างของหน้าต่าง ย่อเหลือแค่หัวแล้วมันเลื่อนขึ้นมาทับโลโก้
	keysHint.Visible = not minimized
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
	-- ต้องก่อนตัดการเชื่อมต่อทั้งหมด ไม่งั้นตัวละครค้าง PlatformStand + ทะลุพื้นหลังปิดสคริปต์
	killAura.releaseUnder()
	for _, conn in ipairs(conns) do
		conn:Disconnect()
	end
	table.clear(conns)
	-- คืนตัวเตะ AFK ของ Roblox ปิดสคริปต์แล้วต้องกลับเป็นเกมปกติ รันใหม่ก็ปิดซ้ำเอง
	for _, c in ipairs(AntiAfk.muted) do
		c:Enable()
	end
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
	itemCache = nil
	questCache = nil
	screen:Destroy()
end
_G.PathSlayerUnload = unload

track(closeBtn.MouseButton1Click:Connect(unload))

-- Auto-Dungeon (Ouwigahara) ------------------------------------------------
-- หอคอย Ouwigahara อยู่คนละเซิร์ฟ (PlaceId 75556147183481) เข้าทางประตูหน้า Hidden Mist (-1605, 1014, 1142)
-- สคริปต์ตามไปเองด้วย queue_on_teleport + สวิตช์นี้จำไว้ในไฟล์ config เลยทำต่อทันทีที่โหลดขึ้นมาอีกฝั่ง
-- วงจร: เข้าประตู → Ready Up → ไต่ชั้นด้วย Insta Kill + เลือกการ์ดแต้มสูงสุด → จบที่ชั้นที่ตั้ง (70)
-- → เปิดหีบ Cache → ตีอาวุธ V2 ที่ Togane ถ้าของครบ → แลกแต้มเป็น Mythic Ore / Wen ที่ Zeni → Leave กลับ
-- แต้ม (RunPoints) อยู่แค่ในเซิร์ฟหอคอยรอบนั้น ออกแล้วหาย ต้องใช้ให้หมดก่อน Leave เสมอ
-- ตัวเลขทดสอบจริง 24 ก.ย. 2026 (Insta Kill ทันที + Kill Aura): ชั้น 7-16 ใน 4 นาที แต้มรวม 4,830 ไม่เสียหัวใจ
;(function()
local RunService = game:GetService("RunService")
local Ouwi = {
	Place = 75556147183481,
	Portal = Vector3.new(-1605.633, 1014.179, 1142.769),
	-- โซนร้านหลังจบรอบ (Shop.PlaceCaches / NPC ของ Content.Ouwigahara)
	Zeni = Vector3.new(-2290.288, 1141.71, -2634.784),
	Togane = Vector3.new(-2312.125, 1144.3, -2684.875),
	Caches = Vector3.new(-2339.874, 1142, -2635.096),
	WenPack = "1,000 Wen",
	WenPackPrice = 2500,
	MythicPrice = 30000,
	-- ทุกสูตร V2 ที่ Togane ฝั่งหอคอย: 90,000 แต้ม + Mythic Ore 10 + Scraps 500 + Silk 300
	V2Mythic = 10,
	-- ชั้นที่จบรอบเอง: สไลด์ 10-200 ทีละ 5 (ผู้ใช้สั่ง 200 · เกมไม่มีเพดานชั้นใน MinigameSettings เลยใช้ตามผู้ใช้)
	-- ชั้นลึกกว่า 50 ม็อบโตแบบทวีคูณ (Waves.DeepFloor 50, DeepRateDoubleFloors 15) ตั้งสูงเสี่ยงหัวใจหมดก่อนถึง
	-- ค่าเดิมเก็บเป็นลำดับปุ่ม { 30, 40, 50, 60, 70, 80 } แปลงให้ครั้งแรก
	StopChoices = { 30, 40, 50, 60, 70, 80 },
	StopMin = 10,
	StopMax = 200,
	StopStep = 5,
	stopFloor = 70,
	-- ของที่แลกด้วยแต้มตอนจบรอบ (ติ๊กหลายอย่าง = แบ่งแต้มเท่ากัน) ชื่อ/ราคาจาก Shop.itemsforsale ฝั่งหอคอย
	Rewards = {
		{ key = "Wen", item = "1,000 Wen", price = 2500 },
		{ key = "Mythic Ore", item = "Mythic Refinement Ore", price = 30000 },
		{ key = "Refinement Ore", item = "Refinement Ore", price = 1500 },
		{ key = "EXP", item = "1,000 Exp", price = 3500 },
	},
	rewardPick = { [1] = true, [2] = true },
	-- ข้ามช่วงพัก 10 วิระหว่างชั้น (เล่นคนเดียวโหวตเดียวผ่าน) ค่าเริ่มต้นเปิด ผู้ใช้ปิดได้ในแถว Auto-Skip
	autoSkip = Game.persist.data.switches["Auto-Skip"] ~= false,
	on = false,
	loop = 0,
}
local inTower = game.PlaceId == Ouwi.Place or workspace:GetAttribute("MinigameKey") == "Ouwigahara"
local ouwiRow

local function fixIdentity()
	if setthreadidentity and Game.loadIdentity then
		setthreadidentity(Game.loadIdentity)
	end
end

local function say(text)
	fixIdentity()
	if ouwiRow then
		ouwiRow.setDesc(text)
	end
end

local function stream(pos)
	local done = false
	task.spawn(function()
		pcall(function()
			LocalPlayer:RequestStreamAroundAsync(pos, 4)
		end)
		done = true
	end)
	local untilT = os.clock() + 4
	while not done and os.clock() < untilT do
		task.wait(0.1)
	end
end

-- กดค้าง prompt จริง (Ready Up / Enter / Leave 0.5 วิ) ตรึงตัวไว้ระหว่างกด
local function holdPrompt(prompt)
	local _, hrp = selfParts()
	if not (prompt and hrp) then
		return false
	end
	local p = prompt.Parent
	local pos = p:IsA("BasePart") and p.Position or (p:IsA("Attachment") and p.WorldPosition) or p:GetPivot().Position
	local goal = CFrame.new(pos + Vector3.new(0, 3, 3), pos)
	local pin = RunService.Heartbeat:Connect(function()
		hrp.CFrame = goal
		hrp.AssemblyLinearVelocity = Vector3.zero
	end)
	task.wait(1)
	prompt.RequiresLineOfSight = false
	local fired = false
	local c = prompt.Triggered:Connect(function()
		fired = true
	end)
	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.4)
	prompt:InputHoldEnd()
	task.wait(0.8)
	c:Disconnect()
	pin:Disconnect()
	return fired
end

local function findPrompt(action, near, radius)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.ActionText == action then
			local p = d.Parent
			local pos = p:IsA("BasePart") and p.Position or (p:IsA("Attachment") and p.WorldPosition) or nil
			if not near or (pos and (pos - near).Magnitude <= (radius or 80)) then
				return d
			end
		end
	end
end

local function persistData()
	return Game.persist.data
end

-- รอบที่คิว Get Nightfall Craft สั่งมา (ouwiGoal) ผู้ใช้สั่งให้จบชั้น 70 ทุกครั้ง ไม่สนค่าที่ตั้งในแถว
-- ชั้นลึกกว่า 50 ม็อบโตแบบทวีคูณ (Waves.DeepFloor) 70 คือจุดที่ยังรอดสบายและแต้มคุ้ม
local CraftStopFloor = 70
local function stopAt()
	return persistData().ouwiGoal and CraftStopFloor or Ouwi.stopFloor
end

-- ฝั่งแมพหลัก --------------------------------------------------------------

-- เซิร์ฟต้นทาง: ผู้เล่นเล่นใน VIP แต่ปุ่ม Leave ของหอคอย (TeleportHandler.ToOrigin) ส่งกลับเซิร์ฟ public
-- (ผู้ใช้เจอจริง 24 ก.ย.) จำไว้ก่อนเข้าแล้วขอย้ายกลับเซิร์ฟนี้เองด้วย Teleporter.Request { placeId, jobId }
local function rememberOrigin()
	persistData().origin = {
		placeId = game.PlaceId,
		jobId = game.JobId,
		privateId = game.PrivateServerId,
		ownerId = game.PrivateServerOwnerId,
	}
	Game.save()
end

local function requestTeleport(settings)
	local ok, Teleporter = pcall(require, ReplicatedStorage.CAM.Client.Modules.Teleporter)
	fixIdentity()
	if not ok then
		return false
	end
	local sent, res = pcall(Teleporter.Request, settings)
	fixIdentity()
	return sent and res == true
end

-- กลับเซิร์ฟต้นทาง: ตาม jobId ก่อน (VIP ของผู้เล่นยังเปิดอยู่) ไม่ได้ลองทางเจ้าของเซิร์ฟ
local function goOrigin()
	local o = persistData().origin
	if not o or not o.jobId then
		return false
	end
	if requestTeleport({ placeId = o.placeId, jobId = o.jobId, allowFallback = false }) then
		return true
	end
	if (o.ownerId or 0) > 0 then
		return requestTeleport({ placeId = o.placeId, privateOwner = o.ownerId })
	end
	return false
end

local function enterTower()
	local Quests = require(ReplicatedStorage.CAM.Global.Subsets.Gameplay.Quests)
	rememberOrigin()
	fixIdentity()
	-- ประตูเปิดให้หลังรับเควสของ Togane ("Ill find the forge(Lv 65)") เดินเข้าประตูคือจบเควสนั้นเอง
	if Quests.GetPlayerQuestState(LocalPlayer, "Ill find the forge(Lv 65)") == "None" then
		say("รับเควส Ill find the forge ที่ Togane ก่อน")
		local spot = npcSpawnPoint("Blacksmith Togane")
		local _, hrp = selfParts()
		if spot and hrp then
			placeAt(hrp, CFrame.new(spot.pos + Vector3.new(0, 3, 5), spot.pos), "forge")
			task.wait(2)
			SignalEvent.ToServer("AddQuest", "Ill find the forge(Lv 65)")
			task.wait(1.5)
		end
	end
	say("ไปประตู Ouwigahara")
	stream(Ouwi.Portal)
	local _, hrp = selfParts()
	if hrp then
		placeAt(hrp, CFrame.new(Ouwi.Portal + Vector3.new(0, 4, 0)), "ouwigahara")
	end
	task.wait(1.5)
	local pad = workspace.Map:FindFirstChild("OuwigaharaPromptPad")
	local prompt = pad and pad:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		return false, "ประตู Ouwigahara ไม่โหลด"
	end
	holdPrompt(prompt)
	say("กำลังย้ายเข้าหอคอย…")
	-- เซิร์ฟย้ายตัวเราเอง (OnTeleport RequestedFromServer) สคริปต์นี้จบตรงนั้น ที่เหลืออีกฝั่งทำต่อ
	task.wait(20)
	return false, "กด Enter แล้วยังไม่ย้าย (ลองใหม่)"
end

-- ปุ่ม เข้าดันเจี้ยน ในหน้าจุดวาร์ปใช้ทางเดียวกัน (รับเควส Togane ถ้ายังไม่รับ → ไปประตู → กด Enter)
Game.enterTower = enterTower

-- ฝั่งหอคอย --------------------------------------------------------------

-- คะแนนการ์ด: ผู้ใช้สั่งเน้นแต้มสูงสุด (ตายแล้วแต้มยังอยู่ เอาไปแลกเงิน/ของได้) แต่ต้องรอดถึงชั้นที่ตั้ง
-- เลยให้ชีวิตเพิ่มสูงสุด รองลงมาการ์ดแต้ม/ตัวคูณแต้ม สเตตัสป้องกันมีค่ามากขึ้นเมื่อชั้นลึก
local function cardScore(c, floor)
	local t = c:GetAttribute("Type")
	local title = tostring(c:GetAttribute("Title") or "")
	local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	local hpPct = hum and hum.MaxHealth > 0 and hum.Health / hum.MaxHealth or 1
	if t == "ExtraLife" or t == "Revive" then
		return 150
	elseif t == "Points" or t == "Fortune" then
		return (tonumber(c:GetAttribute("Points")) or 50) / 4
	elseif t == "Event" then
		-- เดิมพัน/จับเวลาเสียแต้มได้ มือเปล่า/ห้ามสกิลทำ Insta Kill ตีไม่ได้
		for _, bad in ipairs({ "Wager", "Time Attack", "Tribute", "Bare Hands", "Iron Discipline" }) do
			if title:find(bad) then
				return -100
			end
		end
		local mult = tonumber(title:match("x(%d+%.?%d*)")) or 1
		return (mult - 1) * 150
	elseif t == "Stat" then
		if title:find("Health") or title:find("Reduction") then
			return floor >= 40 and 45 or 30
		elseif title:find("Damage") or title:find("Attack Speed") then
			return 35
		end
		return 8
	elseif t == "Heal" then
		return hpPct < 0.5 and 80 or 1
	elseif t == "Potion" then
		return 20
	elseif t == "Weapon" or t == "Forge" then
		return 15
	elseif t == "Skip" then
		return 0
	end
	return 4
end

local function pickCards()
	local offers = LocalPlayer:FindFirstChild("OuwigaharaOffers")
	local cards = offers and offers:GetChildren() or {}
	if #cards == 0 then
		return
	end
	local floor = workspace:GetAttribute("MinigameFloor") or 1
	local best, bestScore
	for _, c in ipairs(cards) do
		local s = cardScore(c, floor)
		if not bestScore or s > bestScore then
			best, bestScore = c, s
		end
	end
	-- ของใน hand ไม่คุ้มเลย (คะแนน < 5) มีรีโรลเหลือใช้รีโรลก่อน
	if bestScore < 5 and (offers:GetAttribute("Rerolls") or 0) > 0 then
		SignalEvent.ToServer("OuwigaharaRequest", { action = "Reroll" })
		task.wait(0.8)
		return
	end
	SignalEvent.ToServer("OuwigaharaRequest", { action = "Pick", id = best.Name })
	task.wait(0.8)
end

-- โหวตข้ามพักครั้งเดียวต่อชั้น ตอนเซิร์ฟตั้ง MinigameWaveBreak (เวลาจบพัก) ไว้
local skippedFloor
local function autoSkip()
	local floor = workspace:GetAttribute("MinigameFloor")
	local offers = LocalPlayer:FindFirstChild("OuwigaharaOffers")
	-- รอเลือกการ์ดให้ครบก่อน (เล่นคนเดียวมีมือที่สองเป็นการ์ดอีเวนต์) โหวตข้ามตอนมือยังเปิด เซิร์ฟสุ่มการ์ดให้เอง
	local choosing = offers and #offers:GetChildren() > 0
	if Ouwi.autoSkip and not choosing and workspace:GetAttribute("MinigameWaveBreak") and skippedFloor ~= floor then
		skippedFloor = floor
		SignalEvent.ToServer("OuwigaharaRequest", { action = "Skip" })
	end
end

-- ม็อบหอคอยอยู่ลึก Humanoids.Regions.Temporary.ActiveNpcs.<ชื่อ>.<ชื่อ> (เกมย้ายที่ 24 ก.ย. 2026 เดิมเป็นลูกตรงของ
-- Humanoids) ผู้ใช้เจอ: ไม่วาร์ปไปตี ยืนรอม็อบเดินมาหาเอง · ไล่ทุกชั้นแล้วกรองด้วย IsMob + OuwigaharaMark
local function nearestEnemy(hrp)
	local best, bestD
	for _, m in ipairs(workspace.Humanoids:GetDescendants()) do
		local h = m:IsA("Model") and m:GetAttribute("IsMob") and m:FindFirstChildOfClass("Humanoid")
		local root = h and m:FindFirstChild("HumanoidRootPart")
		-- ไม่บังคับ OuwigaharaMark: ม็อบที่ Captain เรียกออกมา (ชั้น 58: Prowler / Raid Captain ฯลฯ) ไม่มีป้ายนี้
		-- เดิมกรองทิ้งหมด เหลือแต่ตัวพวกนี้ = ไม่มีเป้า ตัวลอยค้างใต้แมพ (ผู้ใช้เจอ) ในหอคอยม็อบทุกตัวคือศัตรู
		if root and h.Health > 0 and root.Position.Y > Combat.WorldFloorY then
			local d = (root.Position - hrp.Position).Magnitude
			if not bestD or d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best, bestD
end

local function setSwitch(key, state)
	for _, entry in ipairs(toggles) do
		if entry.key == key and entry.isOn() ~= state then
			pcall(entry.set, state)
		end
	end
end

-- ตีจริงด้วย Insta Kill โหมดทันที (ผู้ใช้สั่ง ไม่ต้องได้ของ) ตีบอสด้วย + Kill Aura ตามม็อบ + Auto Skill
local function combatOn()
	local mode = Game.persist.choiceRows["โหมด Insta Kill"]
	local boss = Game.persist.choiceRows["บอส"]
	if mode then
		pcall(mode.restore, 2)
	end
	if boss then
		pcall(boss.restore, 2)
	end
	setSwitch("Insta Kill", true)
	setSwitch("Kill Aura", true)
	setSwitch("Auto Skill", true)
end

-- ออกจากรอบด้วยการตาย (หอคอยไม่มีปุ่มออกตอนยังมีชีวิต) ตายไม่เสียแต้ม หัวใจหมดแล้วเซิร์ฟพาไปโซนร้าน
local function endRun()
	say(string.format("ครบชั้น %d แล้ว จบรอบ (ตายไม่เสียแต้ม)", stopAt()))
	setSwitch("Insta Kill", false)
	setSwitch("Kill Aura", false)
	local untilT = os.clock() + 120
	while os.clock() < untilT and not LocalPlayer:GetAttribute("Spectating") do
		local phase = ReplicatedStorage:FindFirstChild("Intermission") and ReplicatedStorage.Intermission:GetAttribute("Phase")
		if phase == "Ended" then
			break
		end
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum:ChangeState(Enum.HumanoidStateType.Dead)
			hum.Health = 0
		end
		task.wait(1)
	end
end

-- บันทึกรอบ: ของในกระเป๋าตอนเริ่มรอบจดลงไฟล์ (สคริปต์โหลดใหม่กลางรอบยังเทียบได้) จบรอบเทียบว่าได้อะไร
local function snapshot()
	local s = {}
	for k, v in pairs(Game.wallet()) do
		s[k] = v
	end
	fixIdentity()
	return s
end

-- ของที่เปลี่ยน b - a (ไม่นับแต้มรอบ) · onlyGain = เอาแค่ที่เพิ่ม
local function walletDiff(a, b, onlyGain)
	local out = {}
	for k, v in pairs(b) do
		local d = v - (a[k] or 0)
		if k ~= "RunPoints" and d ~= 0 and (d > 0 or not onlyGain) then
			out[k] = d
		end
	end
	if not onlyGain then
		for k, v in pairs(a) do
			if b[k] == nil and k ~= "RunPoints" and v ~= 0 then
				out[k] = -v
			end
		end
	end
	return out
end

local function beginRunLog()
	local cur = persistData().ouwiRunStart
	if not cur or cur.jobId ~= game.JobId then
		persistData().ouwiRunStart = { jobId = game.JobId, at = os.time(), wallet = snapshot() }
		Game.save()
	end
	Ouwi.spent = Ouwi.spent or {}
end

-- ใต้ดินแบบเดียวกับ "ตีจากใต้ดิน": นอนหงายใต้ม็อบ ม็อบตีลงมาไม่ถึง (ผู้ใช้เจอยืนสู้บนพื้นในหอคอยแล้วโดนตี)
local function holdUnder(root)
	if killAura and killAura.pinUnder then
		killAura.pinUnder(root)
	end
end

local function releaseUnder()
	if killAura and killAura.underConn then
		killAura.releaseUnder()
	end
end

local function climb()
	combatOn()
	beginRunLog()
	local lastMap = workspace:GetAttribute("MinigameMap")
	local pauseUntil = 0
	-- จดทุกครั้งที่เสียหัวใจ (ชั้น ระดับ Y ใต้ดินอยู่ไหม ม็อบใกล้สุด) ลง Log ดันเจี้ยน ไว้หาว่าอะไรฆ่า
	local hearts = LocalPlayer:GetAttribute("Hearts")
	Ouwi.deaths = Ouwi.deaths or {}
	while Ouwi.on and workspace:GetAttribute("MinigameState") == "Climbing" do
		fixIdentity()
		local floor = workspace:GetAttribute("MinigameFloor") or 1
		if floor > stopAt() then
			releaseUnder()
			endRun()
			return
		end
		-- ย้ายแมพ (ทุก 10 ชั้น) เซิร์ฟเช็กว่าตัวเราอยู่ใกล้แท่นเกิดหลัง 3.5 วิ ห้ามวาร์ปไปไหนช่วงนั้น
		-- ห้ามปล่อยจากใต้ดินตรงนี้ (เปิดชนคืนตอนตัวยังจมใต้แมพเก่าที่กำลังถูกลบ = ร่วงตาย) แค่ทิ้งเป้าเดิม
		-- ตัวลอยค้างให้เซิร์ฟวาร์ปไปแท่นเกิด พ้นช่วงพักแล้วค่อยตรึงใต้ม็อบแมพใหม่
		local map = workspace:GetAttribute("MinigameMap")
		if map ~= lastMap then
			lastMap = map
			pauseUntil = os.clock() + 4
			if killAura then
				killAura.underRoot = nil
			end
		end
		local nowHearts = LocalPlayer:GetAttribute("Hearts")
		if hearts and nowHearts and nowHearts < hearts then
			local _, me = selfParts()
			local near = me and nearestEnemy(me)
			Ouwi.deaths[#Ouwi.deaths + 1] = string.format("ชั้น %s · Y %s · %s · ม็อบใกล้สุด %s", tostring(floor),
				me and tostring(math.floor(me.Position.Y)) or "?", killAura and killAura.underConn and "ใต้ดิน" or "บนพื้น",
				near and near.Name or "-")
		end
		hearts = nowHearts
		pickCards()
		autoSkip()
		local _, hrp = selfParts()
		if hrp and os.clock() > pauseUntil and not LocalPlayer:GetAttribute("Spectating") then
			local enemy = nearestEnemy(hrp)
			if enemy then
				holdUnder(enemy.HumanoidRootPart)
			end
		elseif os.clock() <= pauseUntil and killAura then
			killAura.underRoot = nil
		end
		say(string.format("ชั้น %d/%d · แต้ม %s · หัวใจ %s · ม็อบเหลือ %s", floor, stopAt(),
			comma(LocalPlayer:GetAttribute("RunPoints") or 0), tostring(LocalPlayer:GetAttribute("Hearts") or "?"),
			tostring(workspace:GetAttribute("MinigameEnemiesLeft") or "?")))
		task.wait(0.3)
	end
	releaseUnder()
end

-- สูตร V2 ฝั่งหอคอยที่ทำได้ตอนนี้ (มีของฐาน Mythic Scraps Silk แต้มครบ) เลือกตัวที่เป็นของฐานของเซ็ต Nightfall ก่อน
local function craftableV2(points)
	local w = Game.wallet()
	local best
	for id, r in pairs(Crafting and Crafting.Definitions or {}) do
		local price = r.price or {}
		if r.station == "Ouwigahara" and price.RunPoints and not price.Wen and points >= price.RunPoints then
			local ok = true
			for _, input in ipairs(Game.recipeInputs(r)) do
				if input.name ~= "RunPoints" and (w[input.name] or 0) < input.amount then
					ok = false
				end
			end
			if ok then
				local forNightfall = false
				for _, c in pairs(Crafting.Definitions) do
					local first = c.required and c.required[1]
					if first and first.name == r.result and tostring(c.result):find("^Nightfall") then
						forNightfall = true
					end
				end
				if not best or (forNightfall and not best.nf) then
					best = { id = id, recipe = r, nf = forNightfall }
				end
			end
		end
	end
	return best
end

-- มีของฐานของสูตร V2 ในกระเป๋าไหม (จะได้เก็บ Mythic Ore ไว้ตี)
local function wantsMythic()
	local w = Game.wallet()
	for _, r in pairs(Crafting and Crafting.Definitions or {}) do
		local first = r.required and r.required[1]
		if r.station == "Ouwigahara" and first and (w[first.name] or 0) > 0 and first.name ~= r.result then
			return true
		end
	end
	return false
end

local function buyAt(where, item, count)
	if count <= 0 then
		return true
	end
	local _, hrp = selfParts()
	stream(where)
	if hrp then
		hrp.CFrame = CFrame.new(where + Vector3.new(0, 2, 5), where)
	end
	task.wait(1)
	local SignalFunction = require(ReplicatedStorage.Communication.ServerAndClient.Signals.SignalFunction)
	-- ตะกร้าเดียวกับหน้าคุย NPC (Dialogue.ProceedWithCartPurchase): { [ชื่อของ] = จำนวน } ครั้งละไม่เกิน 99
	local left = count
	local before = LocalPlayer:GetAttribute("RunPoints") or 0
	local function logSpent()
		local bought = count - left
		if bought > 0 then
			Ouwi.spent = Ouwi.spent or {}
			Ouwi.spent[#Ouwi.spent + 1] = { item = item, n = bought,
				points = before - (LocalPlayer:GetAttribute("RunPoints") or 0) }
		end
	end
	while left > 0 do
		local n = math.min(left, 99)
		local ok, res = pcall(SignalFunction.ToServer, "PurchaseSelection", { [item] = n })
		fixIdentity()
		if not ok or not res then
			logSpent()
			return false
		end
		left -= n
		task.wait(0.4)
	end
	logSpent()
	return true
end

local function shops()
	say("จบรอบ เปิดหีบ Cache")
	task.wait(3)
	-- หีบ Cache ชั้นละ 10 วางเรียงกันที่จุดเดียว เปิดฟรี
	stream(Ouwi.Caches)
	for _ = 1, 12 do
		local prompt
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.Enabled and d.Parent and (d.Parent:IsA("BasePart") or d.Parent:IsA("Attachment")) then
				local pos = d.Parent:IsA("BasePart") and d.Parent.Position or d.Parent.WorldPosition
				local paid = tostring(d.ActionText):lower():find("point") ~= nil
				if (pos - Ouwi.Caches).Magnitude < 40 and d.ActionText ~= "Chat" and (Loot.pointChests or not paid) then
					prompt = d
					break
				end
			end
		end
		if not prompt then
			break
		end
		holdPrompt(prompt)
		task.wait(0.5)
	end
	pcall(collectLoot, { wait = true })
	fixIdentity()

	-- ของที่ได้จากรอบนี้ (หีบ Cache + ของดรอประหว่างไต่) = กระเป๋าตอนนี้ - ตอนเริ่มรอบ ก่อนแลกแต้ม
	-- ใช้กระเป๋าตอนเริ่มเฉพาะที่จดในเซิร์ฟหอคอยนี้ ของรอบก่อน (เกมเด้ง / รอบที่ไม่ได้จด) จะนับของที่ฟาร์มนอกหอคอยปนมา
	-- เจอจริง: รอบหลังเกมเด้งขึ้น Wen +293,176 ที่จริงมาจากฟาร์มบอสในแมพหลักทั้งบ่าย
	local runStart = persistData().ouwiRunStart
	if runStart and runStart.jobId ~= game.JobId then
		runStart = nil
	end
	local startWallet = runStart and runStart.wallet or snapshot()
	local log = {
		at = os.time(),
		floor = LocalPlayer:GetAttribute("OuwigaharaReached") or workspace:GetAttribute("MinigameFloor"),
		points = LocalPlayer:GetAttribute("RunPoints") or 0,
		caches = workspace:GetAttribute("MinigameCaches"),
		got = walletDiff(startWallet, snapshot(), true),
		goal = persistData().ouwiGoal and (persistData().ouwiGoal.kind == "v2"
			and ("อัปดาบฐาน " .. tostring((Crafting and Crafting.Definitions[persistData().ouwiGoal.recipe] or {}).result))
			or "หา Wen ให้คิว Get Nightfall Craft") or nil,
	}
	Ouwi.spent = {}

	local points = LocalPlayer:GetAttribute("RunPoints") or 0
	-- จดแต้มที่ได้ต่อรอบ แผง Get Nightfall Craft เอาไปประมาณว่าต้องลงอีกกี่รอบถึงจะได้ Wen ครบ
	persistData().lastRun = { points = points, floor = workspace:GetAttribute("MinigameFloor"), at = os.time() }
	Game.save()

	-- รอบที่คิว Craft สั่ง: v2 = ตีดาบฐานเล่มที่ต้องใช้ (ขาด Mythic ก็แลกแต้มเป็น Mythic ก่อน) · wen = แต้มทั้งหมดเป็น Wen
	local goal = persistData().ouwiGoal
	local v2
	if goal and goal.kind == "v2" and Crafting and Crafting.Definitions[goal.recipe] then
		local r = Crafting.Definitions[goal.recipe]
		local w = Game.wallet()
		local ready = points >= ((r.price or {}).RunPoints or 0)
		for _, input in ipairs(Game.recipeInputs(r)) do
			if input.name ~= "RunPoints" and (w[input.name] or 0) < input.amount then
				ready = false
			end
		end
		if ready then
			v2 = { id = goal.recipe, recipe = r }
		end
	elseif not goal then
		v2 = craftableV2(points)
	end
	if v2 then
		say("ตี " .. v2.recipe.result .. " ที่ Togane")
		stream(Ouwi.Togane)
		local _, hrp = selfParts()
		if hrp then
			hrp.CFrame = CFrame.new(Ouwi.Togane + Vector3.new(0, 2, 4), Ouwi.Togane)
		end
		task.wait(1.2)
		local SignalFunction = require(ReplicatedStorage.Communication.ServerAndClient.Signals.SignalFunction)
		local had = Game.wallet()[v2.recipe.result] or 0
		-- Awaken Weapon กินดาบฐาน "ที่ถืออยู่" (Togane: Hold the weapon you want reforged) ถือก่อนกด
		local raw = v2.recipe.required and v2.recipe.required[1]
		if raw then
			pcall(Game.holdItem, raw.name)
		end
		local okCraft, res = pcall(SignalFunction.ToServer, "CraftRecipe", v2.id)
		Combat.drinkUntil = 0
		fixIdentity()
		task.wait(1.5)
		local before = points
		points = LocalPlayer:GetAttribute("RunPoints") or 0
		if (Game.wallet()[v2.recipe.result] or 0) > had then
			log.crafted = v2.recipe.result
			Ouwi.spent[#Ouwi.spent + 1] = { item = "ตี " .. v2.recipe.result, n = 1, points = before - points }
		else
			log.craftFail = string.format("ตี %s ไม่สำเร็จ: %s", v2.recipe.result,
				tostring(okCraft and type(res) == "table" and res.Reason or res))
		end
	end

	-- ดาบฐานยังตีไม่ได้เพราะ Mythic ไม่ครบ: แลกแต้มเป็น Mythic เท่าที่ขาดก่อน ที่เหลือเป็น Wen
	if goal and goal.kind == "v2" and not v2 and Crafting and Crafting.Definitions[goal.recipe] then
		local short = 0
		for _, m in ipairs(Crafting.Definitions[goal.recipe].additionalMaterials or {}) do
			if m.name == "Mythic Refinement Ore" then
				short = m.amount - (Game.wallet()[m.name] or 0)
			end
		end
		local n = math.min(math.max(short, 0), math.floor(points / Ouwi.MythicPrice))
		if n > 0 then
			say(string.format("แลก Mythic Refinement Ore × %d (ขาด %d สำหรับดาบฐาน)", n, short))
			buyAt(Ouwi.Zeni, "Mythic Refinement Ore", n)
			points = LocalPlayer:GetAttribute("RunPoints") or 0
		end
	end

	-- แต้มที่เหลือแบ่งเท่ากันตามของที่ติ๊ก ส่วนแบ่งที่ไม่พอซื้อสักชิ้น (Mythic 30,000) โยกไปของที่ติ๊กตัวอื่น
	-- รอบของคิว Craft: ที่เหลือเป็น Wen 100% (ผู้ใช้สั่ง ค่าตีชิ้นเซ็ตเป็นหลักล้าน)
	local picked = {}
	for i, r in ipairs(Ouwi.Rewards) do
		if goal and r.key == "Wen" or not goal and Ouwi.rewardPick[i] then
			picked[#picked + 1] = r
		end
	end
	if #picked == 0 then
		picked = { Ouwi.Rewards[1] }
	end
	local share = math.floor(points / #picked)
	local afford = {}
	for _, r in ipairs(picked) do
		if share >= r.price then
			afford[#afford + 1] = r
		end
	end
	if #afford == 0 then
		table.sort(picked, function(x, y)
			return x.price < y.price
		end)
		afford = { picked[1] }
	end
	share = math.floor(points / #afford)
	for _, r in ipairs(afford) do
		local n = math.floor(math.min(share, LocalPlayer:GetAttribute("RunPoints") or 0) / r.price)
		if n > 0 then
			say(string.format("แลก %s × %d", r.item, n))
			buyAt(Ouwi.Zeni, r.item, n)
		end
	end
	-- เศษที่เหลือจากการปัด ซื้อของถูกสุดที่ติ๊กไว้ให้หมด (ออกแล้วแต้มหาย)
	table.sort(afford, function(x, y)
		return x.price < y.price
	end)
	local rest = LocalPlayer:GetAttribute("RunPoints") or 0
	local cheap = afford[1]
	if cheap and rest >= cheap.price then
		buyAt(Ouwi.Zeni, cheap.item, math.floor(rest / cheap.price))
	end

	-- ลงบันทึกรอบ (เก็บ 20 รอบล่าสุด ดูได้ที่แถว Log ดันเจี้ยน) + ส่ง Discord ถ้าเปิดไว้
	log.spent = Ouwi.spent
	log.deaths = Ouwi.deaths
	Ouwi.deaths = {}
	log.net = walletDiff(startWallet, snapshot(), false)
	local history = persistData().ouwiLog or {}
	table.insert(history, 1, log)
	while #history > 20 do
		table.remove(history)
	end
	persistData().ouwiLog = history
	persistData().ouwiRunStart = nil
	pcall(Runner.hook, "dungeon", log)
	fixIdentity()

	say("กลับเซิร์ฟเดิม")
	persistData().ouwiGo = nil
	-- เป้าหมายใช้แค่รอบนี้ กลับไปแล้วคิว Craft เช็กของใหม่แล้วสั่งรอบถัดไปเอง
	persistData().ouwiGoal = nil
	persistData().returning = true
	Game.save()
	if not goOrigin() then
		local leave = findPrompt("Leave")
		if leave then
			holdPrompt(leave)
		end
	end
	task.wait(20)
end

local function towerLoop(mine)
	while Ouwi.on and Ouwi.loop == mine do
		fixIdentity()
		local inter = ReplicatedStorage:FindFirstChild("Intermission")
		local phase = inter and inter:GetAttribute("Phase")
		local state = workspace:GetAttribute("MinigameState")
		if state == "Climbing" then
			climb()
		elseif phase == "Ended" or LocalPlayer:GetAttribute("InShops") then
			shops()
		elseif phase == "Lobby" or phase == "Starting" then
			beginRunLog()
			if not LocalPlayer:GetAttribute("Readied") then
				say("Ready Up")
				local pad = workspace.Map:FindFirstChild("Minigame Map") and workspace.Map["Minigame Map"]:FindFirstChild("StartPad")
				local prompt = pad and pad:FindFirstChildWhichIsA("ProximityPrompt", true)
				if prompt then
					holdPrompt(prompt)
				end
			else
				-- Countdown เป็นเวลาเซิร์ฟตอนเริ่ม ไม่ใช่วินาทีที่เหลือ (เดิมโชว์ "รอเริ่มรอบ 1790244400s")
				local at = tonumber(inter:GetAttribute("Countdown"))
				local left = at and math.max(0, math.floor(at - workspace:GetServerTimeNow())) or nil
				say(left and string.format("รอเริ่มรอบ %d วิ", left) or "รอเริ่มรอบ")
			end
		end
		task.wait(1)
	end
end

local function worldLoop(mine)
	-- รอให้งานที่ค้าง (คิว Craft) ได้เริ่มก่อน ถ้างานนั้นยังต้องใช้หอคอย มันส่งต่อมาทาง ouwiGo เอง
	task.wait(8)
	if persistData().returning then
		return
	end
	while Ouwi.on and Ouwi.loop == mine do
		fixIdentity()
		local data = persistData()
		if not Runner.active and (not data.resume or data.ouwiGo) then
			pcall(enterTower)
		else
			say(Runner.active and "รอตัวรันอื่นทำงานให้จบก่อน" or "รองานที่ค้างทำต่อ")
		end
		task.wait(5)
	end
end

local function start()
	Ouwi.loop += 1
	local mine = Ouwi.loop
	task.spawn(function()
		local ok, err = pcall(inTower and towerLoop or worldLoop, mine)
		if not ok then
			say("ผิดพลาด: " .. tostring(err):sub(1, 90))
		end
	end)
end

ouwiRow = switchRow("Auto-Dungeon", "ปิดอยู่", 5, function(on)
	Ouwi.on = on
	if on then
		start()
		return
	end
	-- ปิด = หยุดจริงทุกทาง: ลูปนี้ งานที่คิว Craft ส่งมา (ouwiGo) และคิว Craft ที่รอกลับมาทำต่อ
	-- เดิมคิว Craft สั่งเริ่มโดยไม่เปิดสวิตช์ ผู้ใช้เห็นสวิตช์ปิดแต่ระบบยังวิ่ง ปิดไม่ได้
	Ouwi.loop += 1
	local data = persistData()
	data.ouwiGo = nil
	data.ouwiGoal = nil
	data.returning = nil
	if data.resume and data.resume.kind == "craft" then
		data.resume = nil
	end
	Game.save()
	setSwitch("Insta Kill", false)
	setSwitch("Kill Aura", false)
	-- ปิดกลางรอบต้องปล่อยจากใต้ดินด้วย ไม่งั้นค้างนอนใต้พื้นชนไม่ได้ ม็อบรุมจนหัวใจหมด
	releaseUnder()
end)

switchRow("ดันเจี้ยน", "Ouwigahara = หอคอยไต่ชั้น (Normal ไม่จัดอันดับ) ต้อง Lv 65", 6, function() end, {
	choices = { "Ouwigahara" },
	selected = 1,
	onChoice = function() end,
})

-- สไลด์ชั้นที่จบรอบ: ลาก / คลิกบนราง / ปุ่ม − + ทีละ 5 · จำค่าใน config (stopFloor) ข้ามเซิร์ฟได้
do
	local data = persistData()
	local oldIdx = data.choices and data.choices["ยอมแพ้ที่ชั้น"]
	if type(data.stopFloor) == "number" then
		Ouwi.stopFloor = data.stopFloor
	elseif type(oldIdx) == "number" and Ouwi.StopChoices[oldIdx] then
		Ouwi.stopFloor = Ouwi.StopChoices[oldIdx]
	end
	Ouwi.stopFloor = math.clamp(Ouwi.stopFloor, Ouwi.StopMin, Ouwi.StopMax)

	local frame, _, descLabel = placeRow("switch", "ยอมแพ้ที่ชั้น", 7)
	descLabel.Size = UDim2.new(1, -270, 0, 15)
	local W = 170
	local box = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(W + 90, 28),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	local function smallBtn(text, x)
		return new("TextButton", {
			Position = UDim2.fromOffset(x, 2),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = Theme.Raised,
			AutoButtonColor = false,
			Text = text,
			TextColor3 = Theme.Text,
			TextSize = 15,
			FontFace = font(Enum.FontWeight.Bold),
			Parent = box,
		}, { capsule(), stroke() })
	end
	local minus = smallBtn("−", 0)
	local rail = new("TextButton", {
		Position = UDim2.fromOffset(30, 11),
		Size = UDim2.fromOffset(W - 30, 6),
		BackgroundColor3 = Theme.Raised,
		AutoButtonColor = false,
		Text = "",
		Parent = box,
	}, { capsule() })
	local fill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = rail,
	}, { capsule() })
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Theme.On,
		Parent = rail,
	}, { capsule(), stroke(Theme.Accent, 1.5) })
	local plus = smallBtn("+", W + 6)
	local valueLabel = new("TextLabel", {
		Position = UDim2.fromOffset(W + 34, 0),
		Size = UDim2.fromOffset(56, 28),
		BackgroundColor3 = Theme.Raised,
		Text = "",
		TextColor3 = Theme.Text,
		TextSize = 15,
		FontFace = font(Enum.FontWeight.Bold),
		Parent = box,
	}, { capsule() })

	local function paint()
		local v = Ouwi.stopFloor
		local a = (v - Ouwi.StopMin) / (Ouwi.StopMax - Ouwi.StopMin)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		valueLabel.Text = tostring(v)
		-- เตือนเป็นสี: ลึกกว่า 50 ม็อบโตเร็ว · เกิน 100 เสี่ยงมาก
		valueLabel.TextColor3 = v > 100 and Theme.Danger or (v > 50 and Theme.Warn or Theme.Text)
		descLabel.Text = string.format("จบรอบที่ชั้น %d · หีบ Cache %d ใบ%s", v, math.floor(v / 10),
			v > 50 and " · เกินชั้น 50 ม็อบโตแบบทวีคูณ" or "")
		descLabel.TextColor3 = v > 50 and Theme.Warn or Theme.Dim
	end
	local function set(v)
		v = math.clamp(math.floor((v + Ouwi.StopStep / 2) / Ouwi.StopStep) * Ouwi.StopStep, Ouwi.StopMin, Ouwi.StopMax)
		if v ~= Ouwi.stopFloor then
			Ouwi.stopFloor = v
			persistData().stopFloor = v
			Game.save()
		end
		paint()
	end
	local function fromX(x)
		local a = math.clamp((x - rail.AbsolutePosition.X) / math.max(rail.AbsoluteSize.X, 1), 0, 1)
		set(Ouwi.StopMin + a * (Ouwi.StopMax - Ouwi.StopMin))
	end
	local dragging = false
	track(rail.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromX(input.Position.X)
		end
	end))
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
	track(minus.MouseButton1Click:Connect(function()
		set(Ouwi.stopFloor - Ouwi.StopStep)
	end))
	track(plus.MouseButton1Click:Connect(function()
		set(Ouwi.stopFloor + Ouwi.StopStep)
	end))
	paint()
	Ouwi.setStopFloor = set
end

-- ค่าเริ่มต้นไม่เปิด: ผู้ใช้สั่งให้ติ๊กเลือกได้ว่าไม่เอากล่องนี้ (แต้มควรไปแลก Wen / Mythic ตามที่ตั้ง)
switchRow("เปิด Ouwigahara Chest", "กล่องโซนร้านที่ใช้ 30,000 แต้มเปิด · ปิดไว้ = ไม่กด เก็บแต้มไว้แลกของ", 10, function(on)
	Loot.pointChests = on
end)

local skipRow = switchRow("Auto-Skip", "ข้ามช่วงพัก 10 วิระหว่างชั้นทันที ไต่เร็วขึ้น", 9, function(on)
	Ouwi.autoSkip = on
end)
if Ouwi.autoSkip then
	skipRow.set(true)
end

switchRow("แลกแต้มเป็น", "ติ๊กหลายอย่าง = แบ่งแต้มเท่ากัน · ของครบตีอาวุธ V2 ให้ก่อน", 8, function() end, {
	choices = { "Wen", "Mythic Ore", "Ore", "EXP" },
	multi = true,
	selected = { 1, 2 },
	onChoice = function(_, picked)
		Ouwi.rewardPick = picked
	end,
})

-- กลับจากหอคอยแล้วไม่ได้อยู่เซิร์ฟต้นทาง (หลุดไป public) ย้ายกลับ VIP เองก่อนทำอย่างอื่น
if not inTower and persistData().returning then
	task.delay(5, function()
		local o = persistData().origin or {}
		local home = game.JobId == o.jobId or (o.privateId ~= nil and o.privateId ~= "" and game.PrivateServerId == o.privateId)
		if home or not o.jobId or o.privateId == "" then
			persistData().returning = nil
			Game.save()
			if Ouwi.on then
				start()
			end
			return
		end
		say("หลุดมาเซิร์ฟ public · ย้ายกลับเซิร์ฟ VIP เดิม")
		for _ = 1, 3 do
			if goOrigin() then
				return
			end
			task.wait(10)
		end
		-- ย้ายไม่ได้ (VIP ปิดไปแล้ว) เล่นต่อเซิร์ฟนี้
		persistData().returning = nil
		Game.save()
		if Ouwi.on then
			start()
		end
	end)
end

-- คิว Craft เจอของฐานที่ตีได้แค่ในหอคอย: สั่งไปหอคอย (งานค้างยังอยู่ กลับมาแล้วคิวทำต่อเอง)
-- goal = { kind = "v2", recipe = id } ตีดาบฐาน · { kind = "wen" } แต้มเป็น Wen ทั้งหมด (ดู shops / stopAt)
function Game.ouwiRequest(goal)
	persistData().ouwiGo = true
	persistData().ouwiGoal = goal
	Game.save()
	-- เปิดสวิตช์ให้เห็นว่ากำลังทำ (ไม่บันทึกเป็นค่าที่ผู้ใช้ตั้ง) ผู้ใช้กดปิดได้ = หยุดทั้งหมด
	ouwiRow.set(true)
end

-- ปิดสคริปต์ (Delete / X / รันใหม่ทับ) ต้องหยุดลูปนี้ด้วย ไม่งั้นตัวเก่ายังพาตัวละครวิ่งต่อ
track({
	Disconnect = function()
		Ouwi.on = false
		Ouwi.loop += 1
	end,
})

-- จดกระเป๋าตอนเข้าหอคอยทุกครั้ง แม้ไม่ได้เปิด Auto-Dungeon (ผู้เล่นเล่นเอง) Log ดันเจี้ยนจะได้เทียบถูกเซิร์ฟ
if inTower then
	task.delay(3, function()
		pcall(beginRunLog)
	end)
end

-- เข้าหอคอยเพราะคิว Craft สั่ง (สวิตช์ไม่ได้เปิดค้าง) ก็ต้องทำรอบให้จบแล้วกลับ
if inTower and persistData().ouwiGo and not Ouwi.on then
	task.delay(4, function()
		ouwiRow.set(true)
	end)
end

-- Log ดันเจี้ยน: ประวัติ 20 รอบล่าสุดจาก shops() ในไฟล์ config (ข้ามเซิร์ฟได้) ผู้ใช้ขอดูว่าจบรอบได้อะไร แลกอะไร
do
	local logUI = makePanel("Log ดันเจี้ยน Ouwigahara", false)
	logUI.search.Visible = false
	logUI.filterRow.Visible = false
	logUI.list.Position = UDim2.fromOffset(0, 48)
	logUI.list.Size = UDim2.new(1, 0, 1, -70)
	logUI.list:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 8)

	local function text(parent, str, order, color, size, weight)
		return new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 14),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			RichText = true,
			TextWrapped = true,
			Text = str,
			TextColor3 = color or Theme.Muted,
			TextSize = size or 13,
			FontFace = font(weight or Enum.FontWeight.Regular),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
			Parent = parent,
		})
	end

	-- ชิปไอคอนเกม + ชื่อ + จำนวน (เขียว = ได้ · แดง = เสีย) เรียงจำนวนมากไปน้อย
	local function chips(parent, order, items, signed)
		local wrap = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = parent,
		}, { new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}) })
		local list = {}
		for name, n in pairs(items or {}) do
			list[#list + 1] = { name = name, n = n }
		end
		table.sort(list, function(a, b)
			return math.abs(a.n) > math.abs(b.n)
		end)
		if #list == 0 then
			text(wrap, "—", 1, Theme.Dim, 12)
		end
		for i, it in ipairs(list) do
			local chip = new("Frame", {
				Size = UDim2.fromOffset(0, 22),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Theme.Raised,
				LayoutOrder = i,
				Parent = wrap,
			}, {
				capsule(),
				new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }),
				new("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 4),
				}),
			})
			new("ImageLabel", {
				Size = UDim2.fromOffset(16, 16),
				BackgroundTransparency = 1,
				Image = Game.iconOf(it.name) or "",
				ScaleType = Enum.ScaleType.Fit,
				Parent = chip,
			})
			new("TextLabel", {
				Size = UDim2.fromOffset(0, 22),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Text = string.format("%s %s%s", it.name, signed and (it.n > 0 and "+" or "−") or "×", comma(math.abs(it.n))),
				TextColor3 = signed and (it.n > 0 and Theme.Good or Theme.Danger) or Theme.Text,
				TextSize = 12,
				FontFace = font(Enum.FontWeight.SemiBold),
				Parent = chip,
			})
		end
	end

	local function rebuildLog()
		for _, c in ipairs(logUI.list:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local history = persistData().ouwiLog or {}
		local totalPts, totalWen = 0, 0
		for _, run in ipairs(history) do
			totalPts += run.points or 0
			totalWen += (run.net or {}).Wen or 0
		end
		logUI.subtitle.Text = string.format("%d รอบ · แต้มรวม %s · Wen สุทธิ %s%s", #history, comma(totalPts),
			totalWen >= 0 and "+" or "−", comma(math.abs(totalWen)))
		if #history == 0 then
			text(logUI.list, "ยังไม่มีรอบที่จบ · จบรอบแรกแล้วจะขึ้นที่นี่ (ได้อะไร แลกอะไร ได้กลับมาเท่าไร)", 1, Theme.Muted, 14)
		end
		for i, run in ipairs(history) do
			local card = new("Frame", {
				Size = UDim2.new(1, -6, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Row,
				LayoutOrder = i,
				Parent = logUI.list,
			}, {
				corner(10),
				stroke(),
				new("UIPadding", {
					PaddingTop = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
				}),
				new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
			})
			text(card, string.format("<b>รอบ %s</b>   %s   ·   ถึงชั้น <b>%s</b>   ·   <font color=\"#%s\">%s แต้ม</font>   ·   หีบ Cache %s",
				i == 1 and "ล่าสุด" or ("#" .. i), os.date("%d/%m %H:%M", run.at or 0), tostring(run.floor or "?"),
				Theme.Accent:ToHex(), comma(run.points or 0), tostring(run.caches or 0)), 1, Theme.Text, 14)
			if run.goal then
				text(card, "รอบนี้เพื่อ: " .. run.goal, 2, Theme.Accent2, 12, Enum.FontWeight.SemiBold)
			end
			text(card, "ได้จากดัน (หีบ + ของดรอป)", 3, Theme.Dim, 12, Enum.FontWeight.Bold)
			chips(card, 4, run.got)
			text(card, "แลกแต้ม / ตีที่ Togane", 5, Theme.Dim, 12, Enum.FontWeight.Bold)
			local spent = {}
			for _, s in ipairs(run.spent or {}) do
				spent[#spent + 1] = string.format("%s × %s  <font color=\"#%s\">(%s แต้ม)</font>", s.item, comma(s.n),
					Theme.Dim:ToHex(), comma(s.points or 0))
			end
			if run.craftFail then
				spent[#spent + 1] = string.format("<font color=\"#%s\">%s</font>", Theme.Danger:ToHex(), run.craftFail)
			end
			text(card, #spent > 0 and table.concat(spent, "\n") or "ไม่ได้แลก", 6, Theme.Text, 13)
			text(card, "ได้กลับมาทั้งหมด (เทียบกระเป๋าก่อนเข้า → ตอนออก)", 7, Theme.Dim, 12, Enum.FontWeight.Bold)
			chips(card, 8, run.net, true)
			if run.deaths and #run.deaths > 0 then
				text(card, string.format("เสียหัวใจ %d ครั้ง", #run.deaths), 9, Theme.Danger, 12, Enum.FontWeight.Bold)
				text(card, table.concat(run.deaths, "\n"), 10, Theme.Muted, 12)
			end
		end
		fixIdentity()
	end

	local logRow = featureRow("Log ดันเจี้ยน", "ประวัติรอบดันเจี้ยน", 6, function()
		rebuildLog()
		logUI.show()
	end, function()
		logUI.hide()
	end)
	track(logUI.closeButton.MouseButton1Click:Connect(function()
		logRow.setOpen(false)
	end))
end
end)()

-- จุดวาร์ป ----------------------------------------------------------------------
-- ย้ายเซิร์ฟใช้ทางเดียวกับปุ่ม Back To Main Menu ในเมนูของเกม (Menu.Sidebar.SidebarOption):
--   Teleporter.Request { placeId = Worlds.ByName["Main Menu"].Id } เซิร์ฟย้ายให้เอง ไม่ต้องแตะ TeleportService
-- ตำแหน่ง NPC อ่านจาก Spawns[1] ของโมดูล NPC ในเกม (ไม่ฝังพิกัด) หน้าที่ของแต่ละตัวไล่อ่านจาก
-- Shop / Quests.Holder (OfferNpc) / บทพูด Yap / สูตร Crafting ตามสถานี เมื่อ 24 ก.ย. 2026
;(function()
local RunService = game:GetService("RunService")

local Places = { Menu = 16205713724, Main = 136406881576517, Minigames = 75556147183481 }
do
	local ok, Worlds = pcall(require, ReplicatedStorage.CAM.Worlds)
	if ok and type(Worlds) == "table" and Worlds.ByName then
		Places.Menu = Worlds.ByName["Main Menu"] and Worlds.ByName["Main Menu"].Id or Places.Menu
		Places.Main = Worlds.ByName.Ouwland and Worlds.ByName.Ouwland.Id or Places.Main
	end
end

local function fixIdentity()
	if setthreadidentity and Game.loadIdentity then
		setthreadidentity(Game.loadIdentity)
	end
end
fixIdentity()

local inMenu = game.PlaceId == Places.Menu
local inMain = game.PlaceId == Places.Main and not workspace:GetAttribute("IsMinigame")

-- เซิร์ฟที่ผู้เล่นมา: จดทุกครั้งที่โหลดในเกมหลัก (คีย์เดียวกับ Auto-Dungeon ใช้กลับ VIP)
-- ยกเว้นตอนเพิ่งหลุดกลับจากหอคอยมาเซิร์ฟ public (returning) ไม่งั้นทับ VIP เดิมก่อน Auto-Dungeon ย้ายกลับ
local function rememberOrigin()
	Game.persist.data.origin = {
		placeId = game.PlaceId,
		jobId = game.JobId,
		privateId = game.PrivateServerId,
		ownerId = game.PrivateServerOwnerId,
	}
	Game.save()
end
-- เซิร์ฟเดิมที่คนเล่นคนเดียวปิดทันทีที่ออก (วัดจริง: ออกไป Lobby แล้ว jobId เดิมหายไป) แต่เซิร์ฟยังตอบ
-- "Joining." แล้วค่อยย้ายพังเงียบ ๆ ธง returning เลยค้าง Auto-Dungeon ไม่ยอมทำงานต่อ
-- ล้างธงเมื่อย้ายพัง หรือธงที่ปุ่มกลับเกมหลักตั้งไว้เก่าเกิน 3 นาที แล้วถือเซิร์ฟนี้เป็นเซิร์ฟเดิมแทน
local function dropReturning()
	Game.persist.data.returning = nil
	Game.persist.data.returningAt = nil
	rememberOrigin()
end
if inMain then
	local at = Game.persist.data.returningAt
	if Game.persist.data.returning and at and os.time() - at > 180 then
		dropReturning()
	elseif not Game.persist.data.returning then
		rememberOrigin()
	end
	track(game:GetService("TeleportService").TeleportInitFailed:Connect(function(player)
		if player == LocalPlayer and Game.persist.data.returning then
			dropReturning()
		end
	end))
end

local function requestTeleport(settings)
	local ok, Teleporter = pcall(require, ReplicatedStorage.CAM.Client.Modules.Teleporter)
	fixIdentity()
	if not ok then
		return false, "ไม่เจอตัวย้ายเซิร์ฟของเกม"
	end
	local sent, res, why = pcall(Teleporter.Request, settings)
	fixIdentity()
	if not sent then
		return false, tostring(res)
	end
	return res == true, why
end

-- NPC --------------------------------------------------------------------------

-- ทุกตัวที่มีหน้าที่ในเกม เรียงตามกลุ่ม ชื่อ = def.Name ในโมดูล NPC (ใช้หาตำแหน่ง/ไอคอน/เงื่อนไข)
-- ตัดทิ้ง: Horse (สุ่มจุดเกิด) Muzan (เดินทั้งแมพตอนกลางคืน) UbuSister (ยืนเฝ้าประตูสอบ อยู่ในสถานที่แทน)
local Catalog = {
	forge = {
		{ "Yagane", "คลังอาวุธ · ตีดาบนิจิรินเล่มแรก",
			"ตี Enryu / Shinkage / Tengoku Katana ต้องมี Crude Iron Ingot (ได้จาก Final Selection)" },
		{ "Blacksmith Togane", "ช่างตีเซ็ต Firstlight / Nightfall",
			"โต๊ะช่างสูตรชุดเซ็ตและ Lost Shotgun · แลกวัตถุดิบ · ครบ 9 แบบวาดแบบ Top/Bottom ให้"
				.. " · ให้เควสเปิดประตูหอคอย Ouwigahara" },
		{ "Refiner Hagane", "ตีเสริมพลัง (Refine)",
			"ใช้ Refinement Ore อัปค่าพลังอาวุธและเบ็ดตกปลา" },
	},
	shop = {
		{ "Raze", "ร้านดาบคาตานะ", "ขาย Regular Katana และ Fancy Katana" },
		{ "Rika", "ร้านยา", "Health Regen Potion · Stamina Regen Potion" },
		{ "Alchemist Meku", "ร้านยาขั้นสูง (Elixir)",
			"Health Elixir · Health / Stamina Regen Elixir · Underwater Breathing Potion" },
		{ "Ginzo", "รับซื้อของ · ขาย Scraps และ Silk",
			"ขายเหรียญ (Coin Pouch ฯลฯ) ได้ Wen · ขาย Metal Scraps / Silk Thread หลังจบเควสกล่องเครื่องประดับ" },
		{ "Elara", "ร้านเสื้อผ้า (ของหมุนเวียน)",
			"ฮาโอริ ชุด หน้ากาก สลับ 6 ช่องตามรอบ · ต้องส่งพัสดุของ MoldySugar ให้ก่อนถึงซื้อได้" },
		{ "Kuro", "พ่อค้าของสวมใส่หายาก",
			"หน้ากาก Urokodaki ผ้าคลุม สร้อย ต่างหู เขามังกร และยา · อยู่เฉพาะกลางคืน" },
		{ "Winter Store Rep Lynx", "ร้านชุดกันหนาว · ขายพลั่ว",
			"Shovel (ใช้ขุด Chest Mounds) · เสื้อกันหนาวสลับทุกชั่วโมง · ต้องผ่านเควสของ Iceveil Guard Shiro" },
		{ "Ren", "ขายน้ำเต้าฝึกปราณ",
			"Small / Medium / Large Gourd (เฉพาะ Slayer) หลังช่วยตามหาดาบให้ · เดินไปมาในสวน" },
		{ "Black Marketer", "ตลาดมืด (มาเป็นรอบ)",
			"ของสวมใส่หายากสุ่มตามความหายาก · โผล่ในเมืองเป็นรอบ ไม่ได้อยู่ตลอด" },
	},
	trainer = {
		{ "Water Trainer Urokodaki", "ครูปราณน้ำ", "เควสฝึก Water Breathing" },
		{ "Flame Trainer Rengu", "ครูปราณเพลิง", "เควสฝึก Flame Breathing" },
		{ "Thunder Trainer Zentaro", "ครูปราณสายฟ้า", "เควสฝึก Thunder Breathing" },
		{ "Wind Trainer Saneri", "ครูปราณวายุ", "เควสฝึก Wind Breathing" },
		{ "Stone Trainer Gyorei", "ครูปราณศิลา", "เควสฝึก Stone Breathing" },
		{ "Serpent Trainer Obari", "ครูปราณอสรพิษ", "เควสฝึก Serpent Breathing" },
		{ "Insect Trainer Shinora", "ครูปราณแมลง", "เควสฝึก Insect Breathing" },
		{ "Sound Trainer Tengai", "ครูปราณเสียง", "เควสฝึก Sound Breathing" },
		{ "Soryu Expert Kazuma", "ครูสไตล์ Soryu", "เควสฝึก Soryu Style (ท่าต่อสู้ฝั่งอสูร)" },
		{ "Tai Chi Expert Renjiro", "ครูสไตล์ Tai Chi", "เควสฝึก Tai Chi Style (ท่าต่อสู้ฝั่งนักล่า)" },
		{ "Harvester of Souls Zurinyz", "ครูสไตล์ Reaping Blades", "เควสฝึก Reaping Blades Style" },
	},
	fish = {
		{ "Dock Master Sofen", "ใบอนุญาตตกปลา",
			"เควส Permit Stamp (ปลดล็อกร้านเบ็ด) · ขายบันทึกเบาะแสเบ็ดตำนาน 2,500 Wen" },
		{ "Fisherman Jeso", "ร้านเบ็ดและเหยื่อ",
			"Basic / Rare Fishing Rod · Worm · แลก Golden Fish เป็นเบ็ดที่ดีกว่า · ต้องจบเควส Permit Stamp" },
		{ "Baitmonger Nori", "ร้านเหยื่อชั้นดี",
			"Fish Head · Golden Tentacle · ต้องจบเควส Restock the Infirmary" },
		{ "Angler Runo", "เควสส่งปลา", "ส่งปลาเต็มลัง (Lv 45) · ส่งปลาหายาก Clown / Zebra Fish (Lv 60)" },
		{ "Legendary Fisherman Isao", "เบ็ดตำนาน",
			"ส่ง Crustadon 2 + Krathulon 2 แล้วบอกที่จม Legendary Fishing Rod · อยู่เฉพาะกลางคืน" },
	},
	schem = {
		{ "Weaver Hatsu", "แบบพิมพ์ Nightfall Cape", "เอา Lost Cape ไปให้ วาดแบบพิมพ์ให้" },
		{ "Stonemason Tobei", "แบบพิมพ์ Nightfall Gauntlet",
			"คุยให้รูปปั้นตื่น ตีรูปปั้น 3 ตัว (ดาบ / สกิล / มือเปล่า) แล้วกลับมารับแบบ" },
		{ "Tailor Omi", "แบบพิมพ์ Firstlight Haori", "เอา Lost Outfit ไปให้ วาดแบบพิมพ์ให้" },
		{ "Duelist Hibiki", "แบบพิมพ์ Firstlight Sound Cleavers", "ท้าดวลตัวต่อตัว ชนะแล้วได้แบบ" },
		{ "Lamplighter Isamu", "แบบพิมพ์ Firstlight Lantern",
			"เกมจำลำดับแผ่นไฟ กระโดดตามให้ครบ 5 รอบ" },
		{ "Wagasa Maker Genzo", "แบบพิมพ์ Firstlight Bladed Wagasa",
			"ถือ Damascus Bladed Wagasa แล้วดันหินขึ้นเขามาหา" },
		{ "Old Trapper Retsu", "เบาะแสถ้ำ White Terror",
			"จ่าย 2,500 Wen บอกที่เก็บของเติมตะเกียง (ถามตอนกลางคืน)" },
	},
	quest = {
		{ "Krue", "ปราบโจร", "ฆ่าโจร 3 ตัว · ปราบหัวหน้าโจร (Lv 7)" },
		{ "Kazu", "เควสเริ่มต้น", "นำบันทึกไปส่ง · ช่วยกำจัดศัตรู" },
		{ "Noote", "ส่งจดหมาย", "เอาจดหมายไปส่งให้ถึงมือ" },
		{ "MoldySugar", "ส่งพัสดุ", "ส่งพัสดุให้ Elara (ปลดล็อกร้าน Elara)" },
		{ "Kona", "ตามหาหน้ากระดาษ", "เก็บหน้ากระดาษที่หายไป" },
		{ "Lucy", "เติมเสบียงครัว", "หาวัตถุดิบให้ ได้ Cooked Bear Meat (ใช้ในเควส Iceveil)" },
		{ "Tom", "ไล่หมี", "ไล่ฝูงหมี (Lv 10) · ล้ม Mother Bear (Lv 18)" },
		{ "Betty", "ตามหาของหาย", "ตามหาของที่ทำหาย" },
		{ "Liv", "หาเหรียญ · โยนเหรียญพนัน",
			"หาเหรียญนำโชค (Lv 14) · เก็บเหรียญ 500 อัน (Lv 21) · โยนหัวก้อยเงินทั้งหมด ชนะได้ 1.5 เท่า" },
		{ "Chaka", "ปราบกลุ่ม Kaiden", "กำจัดลูกน้อง (Lv 26) · ปราบ Kaiden (Lv 34)" },
		{ "Wagwan", "ปราบกลุ่ม Hoyuzo", "กำจัดองครักษ์ (Lv 40) · ปราบ Hoyuzo (Lv 50)" },
		{ "Rin", "ขับไล่ศัตรู", "ไล่ศัตรูที่บุกท่าเรือ (Lv 47)" },
		{ "Shady Individual Rooyi", "ภารกิจฝั่งอสูร", "กำจัดนักล่า Mizunoto (Lv 62)" },
		{ "Jugg", "เคลียร์ถ้ำ", "เคลียร์ถ้ำ Dreamfall Hollow (Lv 62)" },
		{ "Estate Worker Niko", "ส่งกล่องเสบียง", "ส่งกล่องเสบียงให้ Shiori แล้วกลับมารายงาน (Lv 70)" },
		{ "Shiori", "ห้องพยาบาล Butterfly Estate", "เติมยาห้องพยาบาล (Lv 70) · เติมคลังเสบียงด้วยปลา (Lv 75)" },
		{ "Demon Slayer Goro", "ล่าอสูร Veilfall Cavern", "ลดจำนวนอสูร (Lv 75) · ล่าอสูรตัวใหญ่ (Lv 83)" },
		{ "Demon Mokuro", "ภารกิจฝั่งอสูร", "ทลายเวรยาม (Lv 75)" },
		{ "Wounded Slayer Tomoi", "ช่วยนักล่าบาดเจ็บ", "ช่วยปราบศัตรู (Lv 90)" },
		{ "Demon Delroy", "ภารกิจฝั่งอสูร", "ไล่ผู้บุกรุก (Lv 90)" },
		{ "Iceveil Guard Shiro", "ประตู Iceveil Settlement",
			"ส่งเสบียงช่วยผ่านหน้าหนาว = เปิดประตูหมู่บ้าน (Lv 100) · ส่งปลาเข้าคลัง (Lv 105)" },
		{ "Demon Slayer Mitsu", "ภารกิจนักล่าระดับสูง", "ขับไล่ความหนาว (Lv 105) · ดับไฟ (Lv 115)" },
		{ "Shrine Messenger Akio", "ผู้ส่งสารศาลเจ้า", "คุ้มกันไป Windy Peak (Lv 105) · ตกปลาน้ำลึก (Lv 125)" },
	},
}

-- สถานที่ที่ไม่ใช่ NPC พิกัดเดียวกับที่ Auto-Dungeon / Auto-Final-Selection / Get Nightfall Schematic ใช้
local Spots = {
	{ "ประตูหอคอย Ouwigahara", "ดันเจี้ยนไต่ชั้น", "หน้า Hidden Mist · ต้อง Lv 65 และรับเควสของ Blacksmith Togane ก่อน",
		Vector3.new(-1605.6, 1014.2, 1142.8), Vector3.new(0, 0, -1) },
	{ "ประตูสอบ Final Selection", "สอบคัดเลือก", "เปิดทุก 2 ชั่วโมงตามเวลาเซิร์ฟ · ต้อง Lv 45 และเป็น Human",
		Vector3.new(-2625.6, 284, -203.4), Vector3.new(0, 0, 1) },
	{ "กล่องกุญแจงู (Serpent Box)", "แบบพิมพ์ Nightfall Serpent Katana", "ไขด้วยกุญแจงูที่วางริมน้ำ มีดอกจริงดอกเดียว",
		Vector3.new(899, 879, 739), Vector3.new(0, 0, -1) },
}

-- ข้อมูล NPC จากเกม: ตำแหน่ง ทิศที่หัน ไอคอน เงื่อนไข · Spawns[1] เป็น CFrame (บางตัว Vector3)
local npcDefs = {}
local okContent = pcall(function()
	for _, region in ipairs(ReplicatedStorage.Ouwland.Content:GetChildren()) do
		local npcs = region:FindFirstChild("Npcs")
		for _, m in ipairs(npcs and npcs:GetDescendants() or {}) do
			local ok, def = false, nil
			if m:IsA("ModuleScript") then
				ok, def = pcall(require, m)
			end
			if ok and type(def) == "table" and def.Name then
				local s = def.Spawns and def.Spawns[1]
				local pos, look
				if typeof(s) == "CFrame" then
					pos, look = s.Position, s.LookVector
				elseif typeof(s) == "Vector3" then
					pos = s
				end
				npcDefs[def.Name] = { def = def, pos = pos, look = look, region = region.Name }
			end
		end
	end
end)
fixIdentity()

-- ป้ายเล็กใต้คำอธิบาย: โซน · เลเวลขั้นต่ำ · เผ่า · กลางคืน อ่านจากเงื่อนไขของเกม (Requirements / NightOnly)
local function tagsOf(info)
	local tags = {}
	if not info then
		return tags
	end
	local def = info.def
	tags[#tags + 1] = { text = def.SubArea and (info.region .. " › " .. def.SubArea) or info.region }
	local req = def.Requirements or {}
	if req.Level then
		tags[#tags + 1] = { text = "Lv " .. req.Level .. "+", color = Theme.Accent }
	end
	if type(req.Race) == "table" then
		tags[#tags + 1] = { text = table.concat(req.Race, " / "), color = Theme.Accent2 }
	end
	if def.NightOnly then
		tags[#tags + 1] = { text = "กลางคืน", color = Color3.fromRGB(170, 160, 255) }
	end
	return tags
end

local statusLabel
local function status(text, color)
	fixIdentity()
	if statusLabel then
		statusLabel.Text = text
		statusLabel.TextColor3 = color or Theme.Muted
	end
end

local function stream(pos)
	local done = false
	task.spawn(function()
		pcall(function()
			LocalPlayer:RequestStreamAroundAsync(pos, 4)
		end)
		done = true
	end)
	-- บางครั้งไม่คืนเลย รอไม่เกิน 4 วิ (เจอตอนทดสอบกุญแจงู)
	local untilT = os.clock() + 4
	while not done and os.clock() < untilT do
		task.wait(0.1)
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
-- ยิงจากเหนือจุดยืนแค่ 4 stud ไม่ใช่ 25 แบบ groundAt: NPC หลายตัวยืนในบ้าน (Yagane, Meku)
-- ยิงจากสูงโดนหลังคาแล้วไปยืนบนหลังคา
local function floorAt(pos)
	local exclude = { LocalPlayer.Character }
	local humanoids = workspace:FindFirstChild("Humanoids")
	if humanoids then
		exclude[#exclude + 1] = humanoids
	end
	rayParams.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), rayParams)
	return hit and hit.Position + Vector3.new(0, 3, 0) or nil
end

local busy = false
-- ยืนหน้าเป้า 5 stud หันเข้าหา ตรึงตัวไว้จนพื้นโหลด (ไม่งั้นวาร์ปไกลแล้วตกทะลุก่อนแมพ stream มาถึง)
local function warpTo(pos, look, name)
	if busy then
		return false
	end
	if not inMain then
		status("วาร์ปได้เฉพาะในเกมหลัก · ตอนนี้อยู่" .. (inMenu and " Lobby" or "ในดันเจี้ยน") .. " กด กลับเกมหลัก ก่อน", Theme.Warn)
		return false
	end
	if Runner.active then
		status("ตัวรัน (เควส / ฟาร์ม / Get) ทำงานอยู่ จะพาตัวกลับ · กดหยุดก่อนแล้ววาร์ปใหม่", Theme.Warn)
		return false
	end
	local _, hrp, hum = selfParts()
	if not (hrp and hum and hum.Health > 0) then
		status("ตัวละครยังไม่เกิด / ตายอยู่", Theme.Warn)
		return false
	end
	busy = true
	status("กำลังไป " .. name .. " …", Theme.Accent)
	stream(pos)
	-- NPC ที่เดินไปมา (Ren, Niko) หรือมาเป็นรอบ ใช้ตัวจริงถ้าโหลดมาแล้ว ตำแหน่งตรงกว่าจุดเกิด
	local live = findLiveNpc(name)
	if live and live:IsDescendantOf(workspace) then
		local cf = live:GetPivot()
		if (cf.Position - pos).Magnitude < 400 then
			pos, look = cf.Position, cf.LookVector
		end
	end
	look = look and Vector3.new(look.X, 0, look.Z)
	if not look or look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	local spot = pos + look.Unit * 5
	local goal = CFrame.lookAt(spot + Vector3.new(0, 3, 0), Vector3.new(pos.X, spot.Y + 3, pos.Z))
	local pin = RunService.Heartbeat:Connect(function()
		if hrp.Parent then
			placeAt(hrp, goal, "warp")
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
	end)
	local untilT = os.clock() + 3
	repeat
		local floor = floorAt(spot)
		if floor then
			goal = CFrame.lookAt(floor, Vector3.new(pos.X, floor.Y, pos.Z))
			break
		end
		task.wait(0.25)
	until os.clock() > untilT
	task.wait(0.4)
	pin:Disconnect()
	busy = false
	return true
end

-- หน้า -------------------------------------------------------------------------

local page = Pages.warp

local function actionButton(parent, text)
	local label = new("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Theme.Text,
		TextSize = 14,
		FontFace = font(Enum.FontWeight.SemiBold),
	})
	local button = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(textWidth(text, 14) + 34, 28),
		BackgroundColor3 = Theme.Raised,
		AutoButtonColor = false,
		Text = "",
		Parent = parent,
	}, { capsule(), stroke(), label })
	track(button.MouseEnter:Connect(function()
		tween(button, { BackgroundColor3 = Theme.On }, FAST)
		tween(label, { TextColor3 = Theme.Base }, FAST)
	end))
	track(button.MouseLeave:Connect(function()
		tween(button, { BackgroundColor3 = Theme.Raised }, FAST)
		tween(label, { TextColor3 = Theme.Text }, FAST)
	end))
	return button, label
end

-- การ์ดย้ายเซิร์ฟ: ปุ่มละแถว + บรรทัดสถานะร่วมกับการ์ด NPC
local function serverRow(order, title, desc, btnText)
	local frame, _, descLabel = placeRow("switch", title, order, page.sections.server)
	descLabel.Text = desc
	descLabel.Size = UDim2.new(1, -150, 0, 15)
	local button, label = actionButton(frame, btnText)
	return frame, descLabel, button, label
end

local lobbyFrame, lobbyDesc, lobbyBtn, lobbyLabel = serverRow(1, "กลับ Lobby",
	inMenu and "อยู่ Lobby อยู่แล้ว" or "ไปหน้าเมนูหลักของเกม (เลือกช่องตัวละคร / เซิร์ฟ)", "Lobby  ›")
local mainFrame, mainDesc, mainBtn = serverRow(2, "กลับเกมหลัก",
	inMain and "อยู่เกมหลักอยู่แล้ว · ออกจากดันเจี้ยน / Lobby แล้วกดปุ่มนี้กลับเซิร์ฟเดิม"
		or "กลับเซิร์ฟที่เล่นอยู่ก่อนหน้า (VIP ก็กลับห้องเดิม) · ไม่ได้ก็เข้าเซิร์ฟใหม่ของ Ouwland",
	"กลับ  ›")
-- เข้าหอคอย Ouwigahara เองกับมือ (ไม่เปิด Auto-Dungeon ให้ เข้าไปแล้วเล่นเองหรือเปิดสวิตช์เองก็ได้)
local towerDesc = "วาร์ปไปประตูหน้า Hidden Mist แล้วกด Enter ให้ · รับเควส Ill find the forge ที่ Togane ให้ถ้ายังไม่รับ · ต้อง Lv 65"
local towerFrame, towerDescLabel, towerBtn = serverRow(3, "เข้าดันเจี้ยน Ouwigahara",
	inMain and towerDesc or "ต้องอยู่เกมหลักก่อน (กด กลับเกมหลัก)", "เข้า  ›")
if not inMain then
	towerFrame.BackgroundTransparency = 0.4
end
local towerBusy = false
track(towerBtn.MouseButton1Click:Connect(function()
	if not inMain then
		status("เข้าดันเจี้ยนได้จากเกมหลักเท่านั้น · กด กลับเกมหลัก ก่อน", Theme.Warn)
		return
	end
	if towerBusy then
		return
	end
	if Runner.active then
		status("ตัวรัน (เควส / ฟาร์ม / Get) ทำงานอยู่ จะพาตัวไปที่อื่น · กดหยุดก่อน", Theme.Warn)
		return
	end
	local lv = Game.level()
	fixIdentity()
	if lv and lv < 65 then
		status(string.format("หอคอยต้อง Lv 65 (ตอนนี้ %d)", lv), Theme.Warn)
		return
	end
	if not Game.enterTower then
		status("ไม่พบส่วนเข้าหอคอย", Theme.Danger)
		return
	end
	towerBusy = true
	towerDescLabel.Text = "กำลังไปประตู Ouwigahara …"
	status("กำลังไปประตูดันเจี้ยน · ถึงแล้วกด Enter ให้ รอเซิร์ฟย้ายสักครู่", Theme.Accent)
	task.spawn(function()
		local ok, res, why = pcall(Game.enterTower)
		fixIdentity()
		towerBusy = false
		towerDescLabel.Text = towerDesc
		-- สำเร็จ = เซิร์ฟย้ายไปหอคอย สคริปต์นี้จบก่อนถึงบรรทัดนี้ มาถึงแปลว่าไม่ได้ย้าย
		status("เข้าดันเจี้ยนไม่สำเร็จ: " .. tostring(ok and (why or "ไม่ย้ายเซิร์ฟ") or res), Theme.Danger)
	end)
end))

if inMenu then
	lobbyFrame.BackgroundTransparency = 0.4
end
if inMain then
	mainFrame.BackgroundTransparency = 0.4
end

-- กดสองครั้งกันเผลอ (เกมเองก็ถามยืนยันก่อน Back To Main Menu)
local lobbyArmedUntil = 0
track(lobbyBtn.MouseButton1Click:Connect(function()
	if inMenu then
		status("อยู่ Lobby อยู่แล้ว", Theme.Muted)
		return
	end
	if os.clock() > lobbyArmedUntil then
		lobbyArmedUntil = os.clock() + 3
		lobbyLabel.Text = "ยืนยัน?"
		lobbyDesc.Text = "กดอีกครั้งภายใน 3 วิ เพื่อไป Lobby"
		lobbyDesc.TextColor3 = Theme.Warn
		task.delay(3, function()
			if os.clock() >= lobbyArmedUntil then
				lobbyLabel.Text = "Lobby  ›"
				lobbyDesc.Text = "ไปหน้าเมนูหลักของเกม (เลือกช่องตัวละคร / เซิร์ฟ)"
				lobbyDesc.TextColor3 = Theme.Dim
			end
		end)
		return
	end
	lobbyArmedUntil = 0
	lobbyLabel.Text = "Lobby  ›"
	task.spawn(function()
		if inMain then
			rememberOrigin()
		end
		status("กำลังย้ายไป Lobby …", Theme.Accent)
		local ok, why = requestTeleport({ placeId = Places.Menu })
		status(ok and "เซิร์ฟรับคำขอแล้ว กำลังย้ายไป Lobby" or ("ย้ายไม่สำเร็จ: " .. tostring(why or "เซิร์ฟไม่ตอบ")),
			ok and Theme.Good or Theme.Danger)
	end)
end))

local function goMain()
	-- ออกจากหอคอยแล้วห้าม Auto-Dungeon พากลับเข้าอีก (ทั้งสวิตช์และงานที่คิว Craft สั่งไว้)
	for _, entry in ipairs(toggles) do
		if entry.key == "Auto-Dungeon" and entry.isOn() then
			pcall(entry.set, false)
		end
	end
	local data = Game.persist.data
	data.ouwiGo = nil
	data.ouwiGoal = nil
	local o = data.origin
	if o and o.jobId and o.placeId == Places.Main then
		-- หลุดไป public ระหว่างทาง Auto-Dungeon ย้ายกลับห้องเดิมให้อีกรอบ (ดูส่วน returning)
		data.returning = true
		Game.save()
		status("กำลังกลับเซิร์ฟเดิม …", Theme.Accent)
		if requestTeleport({ placeId = o.placeId, jobId = o.jobId, allowFallback = false }) then
			return true
		end
		if (o.ownerId or 0) > 0 and requestTeleport({ placeId = o.placeId, privateOwner = o.ownerId }) then
			return true
		end
		data.returning = nil
	end
	Game.save()
	status("เซิร์ฟเดิมปิดไปแล้ว / ไม่มีบันทึก · เข้าเซิร์ฟใหม่ของ Ouwland", Theme.Accent)
	local ok, why = requestTeleport({ placeId = Places.Main })
	if not ok then
		status("ย้ายไม่สำเร็จ: " .. tostring(why or "เซิร์ฟไม่ตอบ"), Theme.Danger)
	end
	return ok
end

track(mainBtn.MouseButton1Click:Connect(function()
	if inMain then
		status("อยู่เกมหลักอยู่แล้ว", Theme.Muted)
		return
	end
	task.spawn(goMain)
end))

-- ค้นหา + สถานะ ------------------------------------------------------------------

local findBox = page.sections.find
local search = new("TextBox", {
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundColor3 = Theme.Raised,
	BorderSizePixel = 0,
	Text = "",
	PlaceholderText = "ค้นหาชื่อ NPC หรือหน้าที่ เช่น ตีดาบ, ยา, เบ็ด, Water",
	PlaceholderColor3 = Theme.Dim,
	TextColor3 = Theme.Text,
	TextSize = 14,
	FontFace = font(Enum.FontWeight.Regular),
	TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false,
	LayoutOrder = 1,
	Parent = findBox,
}, { capsule(), new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }) })

statusLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 16),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = Theme.Muted,
	TextSize = 14,
	FontFace = font(Enum.FontWeight.Medium),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	LayoutOrder = 2,
	Parent = findBox,
})
if not inMain then
	status(inMenu and "อยู่ Lobby · วาร์ปหา NPC ได้หลังกลับเกมหลัก" or "อยู่ในดันเจี้ยน · วาร์ปหา NPC ได้หลังกลับเกมหลัก", Theme.Warn)
elseif not okContent then
	status("อ่านข้อมูล NPC ของเกมไม่ได้", Theme.Danger)
end

-- การ์ดหนึ่งใบต่อหนึ่ง NPC: ไอคอนของเกม · ชื่อ · หน้าที่ (สีทอง) · รายละเอียด · ป้ายเงื่อนไข
local cards = {}
local function card(group, order, name, role, detail, tags, icon, go)
	local frame = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Row,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = page.sections[group],
	}, {
		corner(10),
		stroke(),
		new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }),
	})

	local iconBox = new("Frame", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Theme.Raised,
		Parent = frame,
	}, { corner(8) })
	if icon and icon ~= "" then
		new("ImageLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Image = icon,
			ScaleType = Enum.ScaleType.Crop,
			Parent = iconBox,
		}, { corner(8) })
	else
		new("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = name:sub(1, 1),
			TextColor3 = Theme.Muted,
			TextSize = 20,
			FontFace = font(Enum.FontWeight.Bold),
			Parent = iconBox,
		})
	end

	local col = new("Frame", {
		Position = UDim2.fromOffset(64, 0),
		Size = UDim2.new(1, -160, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = frame,
	}, { new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local function line(text, size, color, weight, order2)
		return new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = color,
			TextSize = size,
			FontFace = font(weight),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			LayoutOrder = order2,
			Parent = col,
		})
	end
	line(name, 16, Theme.Text, Enum.FontWeight.SemiBold, 1)
	line(role, 14, Theme.Accent, Enum.FontWeight.SemiBold, 2)
	line(detail, 14, Theme.Muted, Enum.FontWeight.Regular, 3)

	if #tags > 0 then
		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			LayoutOrder = 4,
			Parent = col,
		}, { new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}) })
		for i, t in ipairs(tags) do
			new("TextLabel", {
				Size = UDim2.fromOffset(textWidth(t.text, 12) + 14, 18),
				BackgroundColor3 = Theme.Raised,
				Text = t.text,
				TextColor3 = t.color or Theme.Muted,
				TextSize = 12,
				FontFace = font(Enum.FontWeight.Medium),
				LayoutOrder = i,
				Parent = row,
			}, { capsule() })
		end
	end

	local button, label = actionButton(frame, "วาร์ป  ›")
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -12, 0, 6)
	if not go then
		button.BackgroundTransparency = 0.6
		label.TextColor3 = Theme.Dim
	end
	track(button.MouseButton1Click:Connect(function()
		if not go then
			status("ไม่รู้ตำแหน่ง " .. name .. " (เกมไม่ได้ระบุจุดเกิด)", Theme.Warn)
			return
		end
		label.Text = "…"
		task.spawn(function()
			local ok = go()
			fixIdentity()
			label.Text = "วาร์ป  ›"
			if ok then
				status("ถึง " .. name .. " แล้ว", Theme.Good)
			end
		end)
	end))

	local tagText = {}
	for _, t in ipairs(tags) do
		tagText[#tagText + 1] = t.text
	end
	cards[#cards + 1] = {
		frame = frame,
		group = group,
		text = (name .. " " .. role .. " " .. detail .. " " .. table.concat(tagText, " ")):lower(),
	}
end

for group, list in pairs(Catalog) do
	for i, entry in ipairs(list) do
		local name, role, detail = entry[1], entry[2], entry[3]
		local info = npcDefs[name]
		local go = info and info.pos and function()
			return warpTo(info.pos, info.look, name)
		end or nil
		card(group, i, name, role, detail, tagsOf(info), info and info.def.Icon, go)
	end
end
for i, s in ipairs(Spots) do
	card("place", i, s[1], s[2], s[3], {}, nil, function()
		return warpTo(s[4], s[5], s[1])
	end)
end

-- ค้นหาจากชื่อ หน้าที่ รายละเอียด และป้าย หัวข้อกลุ่มที่ไม่เหลือการ์ดซ่อนทั้งหัวข้อ
track(search:GetPropertyChangedSignal("Text"):Connect(function()
	local q = search.Text:lower():gsub("^%s+", ""):gsub("%s+$", "")
	local shown = {}
	for _, c in ipairs(cards) do
		local match = q == "" or c.text:find(q, 1, true) ~= nil
		c.frame.Visible = match
		if match then
			shown[c.group] = true
		end
	end
	for group in pairs(Catalog) do
		page.sections[group].Visible = shown[group] == true
	end
	page.sections.place.Visible = shown.place == true
end))
end)()

Game.followTeleport()

-- เปิดสวิตช์/ตัวเลือกที่ผู้เล่นตั้งไว้คืน แล้วทำงานที่ค้างต่อ รอแผงสร้างเสร็จและตัวละครพร้อมก่อน
-- ถ้ามีงานค้าง (resume) ไม่เปิดตัวรันที่จองตัวละครทั้งตัว ไม่งั้นแย่งกันแล้วงานค้างไม่ได้ทำต่อ
task.delay(2, function()
	if not screen.Parent then
		return
	end
	local data = Game.persist.data
	for name, saved in pairs(data.choices) do
		local row = Game.persist.choiceRows[name]
		if row then
			pcall(row.restore, saved)
		end
	end
	local busyRunners = { ["Auto-Money-Farm"] = true, ["Auto-Final-Selection"] = true }
	for _, entry in ipairs(toggles) do
		if data.switches[entry.key] and not entry.isOn() and not (data.resume and busyRunners[entry.key]) then
			pcall(entry.set, true)
		end
	end
	local job = data.resume
	local resume = job and Game.persist.resumers[job.kind]
	-- ในเซิร์ฟดันเจี้ยนไม่ทำคิว Craft/Get (ของพวกนั้นอยู่แมพหลัก) รอกลับไปก่อน
	if resume and not workspace:GetAttribute("IsMinigame") then
		task.wait(3)
		pcall(resume, job)
	end
end)

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

-- ป้ายบนหัวหน้าต่าง: อะไรเปิดอยู่บ้าง ----------------------------------------------
do
	local function runningNames()
		local names = {}
		for _, t in ipairs(toggles) do
			if t.isOn() and not t.setting then
				names[#names + 1] = t.name
			end
		end
		-- Auto-Quest / Auto-Breathing / Get Weapons ไม่ใช่สวิตช์ แต่ใช้ตัวรันเดียวกัน
		if Runner.active then
			names[#names + 1] = "เควส/ตัวรัน"
		end
		return names
	end

	task.spawn(function()
		local shown
		while screen.Parent do
			local names = runningNames()
			local text
			if #names == 0 then
				text = "ไม่มีอะไรทำงาน"
			elseif #names <= 2 then
				text = table.concat(names, " · ")
			else
				text = names[1] .. " · " .. names[2] .. "  +" .. (#names - 2)
			end
			if text ~= shown then
				shown = text
				Chip.label.Text = text
				Chip.label.TextColor3 = #names > 0 and Theme.Text or Theme.Muted
				Chip.dot.BackgroundColor3 = #names > 0 and Theme.Good or Theme.Dim
			end
			task.wait(0.4)
		end
	end)
end

-- เลือกแท็บแรกหลังเฟรมแรก เพราะ indicator อ่าน AbsolutePosition ที่ UIListLayout ยังไม่ได้คำนวณ
task.defer(function()
	selectTab(tabs[1])
end)

root.Size = UDim2.fromOffset(Config.Width, Config.Height * 0.94)
tween(root, { Size = UDim2.fromOffset(Config.Width, Config.Height) }, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out))
