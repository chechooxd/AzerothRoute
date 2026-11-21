-- AzerothRoute: talent plans imported from an Icy Veins WoW Forever talent calculator link, pasted in
-- the game. A link's "#tc-<letters>" holds one letter per point in the order the points were spent;
-- data.calc (Talents/IcyVeins.lua) maps each letter to a node of the class's tree. Imported plans are
-- saved per character (AzerothRouteCharData.talents.imports, the link and a name) and decoded again
-- at every refresh, so they follow the tree each AzerothRoute update brings.
-- Original AzerothRoute code (GPL-3.0-only).
--
--   T.Import.Decode(data, text) -> plan, nil | nil, why   a plan from a link (nothing saved)
--   T.Import.Add(text, name)    -> build, nil | nil, why  decode, save and list it as a plan
--   T.Import.Remove(key)        -> true when a saved plan was removed
--   T.Import.List()             -> the saved imports { id, name, link }
--   T.Import.Message(why)       -> the reason, as a sentence
-- why: "empty" (no #tc- part), "class" (another class's link), "letter" (not a talent),
-- "rank" (past a talent's ranks), "points" (more than 51), "noclass" (no plans for this class).

local ADDON, ns = ...
local T = ns.Talents
local L = ns.L
if not T then return end

local I = {}
T.Import = I

local MAX_POINTS = 51
local KEY = "import"
local SITE = "https://www.icy-veins.com/wow-forever/"

if GetLocale and (GetLocale() == "esMX" or GetLocale() == "esES") then
	L["Paste an Icy Veins talent calculator link first."] = "Primero pega un enlace del calculador de talentos de Icy Veins."
	L["That link is for a %s, not a %s."] = "Ese enlace es de un %s, no de un %s."
	L["That link has a talent this class's tree does not have."] = "Ese enlace tiene un talento que no está en el árbol de esta clase."
	L["That link spends more points on %s than it has ranks."] = "Ese enlace gasta en %s más puntos de los rangos que tiene."
	L["That link spends more than %d points."] = "Ese enlace gasta más de %d puntos."
	L["There are no talent plans for this class."] = "No hay planes de talentos para esta clase."
	L["Imported plan"] = "Plan importado"
	-- The Talents view's Import a plan tab (Talents/View.lua).
	L["Import a plan"] = "Importar un plan"
	L["From an Icy Veins talent calculator link"] = "Desde un enlace del calculador de talentos de Icy Veins"
	L["Build a plan in the Icy Veins WoW Forever talent calculator, or open a guide's \"Open in Calculator\", and copy the page's address. Its points keep the order you spent them in."] =
		"Arma un plan en el calculador de talentos de WoW Forever de Icy Veins, o abre \"Open in Calculator\" en una guía, y copia la dirección de la página. Sus puntos mantienen el orden en que los gastaste."
	L["Paste the calculator link here (Ctrl+V)"] = "Pega aquí el enlace del calculador (Ctrl+V)"
	L["A name for the plan (optional)"] = "Un nombre para el plan (opcional)"
	L["Import plan"] = "Importar plan"
	L["Imported plans"] = "Planes importados"
	L["None yet. Imported plans get a tab of their own above."] = "Ninguno aún. Cada plan importado tiene su propia pestaña arriba."
	L["Paste a link on the right; the plan shows here once imported."] = "Pega un enlace a la derecha; el plan aparece aquí una vez importado."
	L["Imported from %s, in the order of its points."] = "Importado de %s, en el orden de sus puntos."
	L["Remove plan"] = "Quitar plan"
end

local CLASS_NAMES = {
	druid = "DRUID", hunter = "HUNTER", mage = "MAGE", paladin = "PALADIN", priest = "PRIEST",
	rogue = "ROGUE", shaman = "SHAMAN", warlock = "WARLOCK", warrior = "WARRIOR",
}

local function className(token)
	local male = LOCALIZED_CLASS_NAMES_MALE
	return (male and male[token]) or (token:sub(1, 1) .. token:sub(2):lower())
end

function I.Message(reason, a, b)
	if reason == "class" then return string.format(L["That link is for a %s, not a %s."], className(a or "?"), className(b or "?")) end
	if reason == "rank" then return string.format(L["That link spends more points on %s than it has ranks."], a or "?") end
	if reason == "points" then return string.format(L["That link spends more than %d points."], MAX_POINTS) end
	if reason == "letter" then return L["That link has a talent this class's tree does not have."] end
	if reason == "noclass" then return L["There are no talent plans for this class."] end
	return L["Paste an Icy Veins talent calculator link first."]
end

-- A plan from a link: { picks = { { order, node, rank } }, spec, split, link } or nil, why, detail...
function I.Decode(data, text)
	if not (data and data.calc) then return nil, "noclass" end
	text = type(text) == "string" and text or ""
	local letters = text:match("tc%-(%w+)")
	if not letters then return nil, "empty" end
	local cls = text:match("wow%-forever/(%a+)%-talent%-calculator")
	cls = cls and CLASS_NAMES[cls:lower()]
	if cls and cls ~= data.class then return nil, "class", cls, data.class end
	if #letters > MAX_POINTS then return nil, "points" end
	local ranks, per, picks = {}, { 0, 0, 0 }, {}
	for i = 1, #letters do
		local id = data.calc[letters:sub(i, i)]
		local n = id and data.nodes[id]
		if not n then return nil, "letter" end
		local r = (ranks[id] or 0) + 1
		if r > n.max then return nil, "rank", n.name end
		ranks[id] = r
		per[n.spec] = (per[n.spec] or 0) + 1
		picks[i] = { order = i, node = id, rank = r }
	end
	local spec = 1
	for k = 2, 3 do if per[k] > per[spec] then spec = k end end
	local link = text:match("https?://%S+") or (SITE .. (data.class or ""):lower() .. "-talent-calculator#tc-" .. letters)
	return { picks = picks, spec = spec, split = table.concat(per, "/"), link = link }
end

-- The character's saved imports.
local function saved()
	local s = ns.CharState and ns.CharState()
	if not s then return nil end
	if type(s.talents) ~= "table" then s.talents = {} end
	local t = s.talents
	if type(t.imports) ~= "table" then t.imports = {} end
	return t
end

function I.List()
	local t = saved()
	return t and t.imports or {}
end

local function asBuild(data, entry, plan)
	return {
		key = KEY .. entry.id, spec = plan.spec, split = plan.split, picks = plan.picks, link = plan.link,
		notes = {}, data = data, specName = entry.name, imported = true, importId = entry.id,
	}
end

-- The saved imports as plans after the class's own: rebuilt each time, so a removed one goes and
-- every link is read against today's tree. A link that no longer decodes is kept but not listed.
function I.Attach(data)
	data = data or T.Data()
	if not data then return end
	local keep = {}
	for _, b in ipairs(data.builds) do if not b.imported then keep[#keep + 1] = b end end
	for _, entry in ipairs(I.List()) do
		local plan = I.Decode(data, entry.link)
		if plan then keep[#keep + 1] = asBuild(data, entry, plan) end
	end
	data.builds = keep
end

function I.Add(text, name)
	local data = T.Data()
	local plan, reason, a, b = I.Decode(data, text)
	if not plan then return nil, reason, a, b end
	local t = saved()
	if not t then return nil, "noclass" end
	t.nextImport = (t.nextImport or 0) + 1
	name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
	if name == "" then name = string.format("%s (%s)", L[data.specs[plan.spec]] or "?", L["Imported plan"]) end
	local entry = { id = t.nextImport, name = name, link = plan.link }
	t.imports[#t.imports + 1] = entry
	I.Attach(data)
	T.Queue()
	return T.BuildByKey(data, KEY .. entry.id)
end

function I.Remove(key)
	local t = saved()
	if not t then return false end
	for i, entry in ipairs(t.imports) do
		if KEY .. entry.id == key then
			table.remove(t.imports, i)
			if T.Choice() == key then T.Choose("auto") end
			I.Attach()
			T.Queue()
			return true
		end
	end
	return false
end

-- Every refresh sees the saved imports.
local refresh = T.Refresh
function T.Refresh(...)
	I.Attach()
	return refresh(...)
end
