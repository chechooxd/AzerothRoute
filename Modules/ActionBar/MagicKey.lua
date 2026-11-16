-- AzerothRoute: One-Button Contextual Action Hint (MagicKey) (SPEC-10)

local AR = _G.AzerothRoute
local MagicKey = {}
AR.MagicKey = MagicKey

function MagicKey:GetPrimaryHint()
    if AR.ActionBar then
        for _, pool in ipairs({ AR.ActionBar.buttons, AR.ActionBar.itemButtons }) do
            local btn = pool and pool[1]
            if btn and btn:IsShown() then
                local macro = btn:GetAttribute("macrotext1") or btn:GetAttribute("macrotext")
                if macro then
                    -- Do not advertise a key binding that the addon has not registered.
                    return btn.actionLabel or macro:gsub("\n.*", "")
                end
            end
        end
    end
    return nil
end

return MagicKey
