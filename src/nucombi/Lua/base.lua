rawset(_G, "combi", {
    running = false,
})

rawset(_G, "COMBI_GetCombiStuff", function(p)
    local cs = p.combistuff

    if cs == nil then
        cs = {
            last_dist = {}, -- key - player, value - distance from last frame
            airtime = 0, -- When above certain threshold, teleport back to partner
        }
        p.combistuff = cs
    end

    return cs
end)

-- Maybe someone will want to check if its "nucombi" specifically?
rawset(_G, "NUCOMBI", true)
