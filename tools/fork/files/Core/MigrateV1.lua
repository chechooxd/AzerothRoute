-- AzerothRoute: carries AzerothRoute 1's settings into AzerothRoute 2, once per account.
-- AzerothRoute 1 kept them in AzerothRouteSavedDB (AceDB: profiles by character, a global
-- minimap entry). The ones AzerothRoute 2 has an equivalent for are copied at login; the old table
-- is then marked (migratedToV2) and never read again. Original AzerothRoute code (GPL-3.0-only).

local ADDON, ns = ...

-- AzerothRoute 1 profile key -> AzerothRoute 2 setting.
local MAP = {
	autoaccept = "behavior.autoAccept",
	autoturnin = "behavior.autoTurnin",
	targetmacro = "qol.targetButton",
	automark = "qol.markTarget",
}

local function profileOf(old)
	local profiles = type(old.profiles) == "table" and old.profiles or nil
	if not profiles then return nil end
	local name, realm = UnitName("player"), GetRealmName and GetRealmName() or ""
	local key = type(old.profileKeys) == "table" and old.profileKeys[(name or "") .. " - " .. (realm or "")]
	return profiles[key or "Default"] or profiles.Default
end

function ns.MigrateV1()
	local old = AzerothRouteSavedDB
	if type(old) ~= "table" or old.migratedToV2 then return 0 end
	local n = 0
	local p = profileOf(old)
	if type(p) == "table" then
		for from, to in pairs(MAP) do
			if type(p[from]) == "boolean" then
				ns.Set(to, p[from])
				n = n + 1
			end
		end
	end
	local mm = type(old.global) == "table" and old.global.minimap
	if type(mm) == "table" and type(mm.hide) == "boolean" then
		ns.Set("maps.minimapButton", not mm.hide)
		n = n + 1
	end
	old.migratedToV2 = true
	return n
end

ns.OnLogin(function() ns.MigrateV1() end)
