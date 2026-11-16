-- AzerothRoute: One-Button Contextual Action Hint (MagicKey) (SPEC-10)

local AR = _G.AzerothRoute
local MagicKey = {}
AR.MagicKey = MagicKey

function MagicKey:GetPrimaryHint()
    if AR.ActionBar and AR.ActionBar.buttons[1] then
        local macro = AR.ActionBar.buttons[1]:GetAttribute("macrotext1")
        if macro and AR.ActionBar.buttons[1]:IsShown() then
            -- Do not advertise a key binding that the addon has not registered.
            return AR.ActionBar.buttons[1].actionLabel or macro:gsub("\n.*", "")
        end
    end
    return nil
end

return MagicKey
