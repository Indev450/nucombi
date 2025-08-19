rawset(_G, "COMBI_GetCombiStuff", function(p)
    local cs = p.combistuff

    if cs == nil then
        cs = {
            last_dist = {}, -- key - player, value - distance from last frame
        }
        p.combistuff = cs
    end

    return cs
end)
