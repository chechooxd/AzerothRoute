-- AzerothRoute: One-Button Contextual Action Hint (MagicKey) (SPEC-10)

local AR = _G.AzerothRoute
local MagicKey = {
    binding = "F",
}
AR.MagicKey = MagicKey

function MagicKey:GetPrimaryHint()
    if AR.ActionBar and AR.ActionBar.buttons[1] then
        local macro = AR.ActionBar.buttons[1]:GetAttribute("macrotext1")
        if macro then
            return string.format("[%s] %s", self.binding, macro:gsub("\n.*", ""))
        end
    end
    return nil
end

return MagicKey
