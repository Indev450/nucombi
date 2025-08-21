rawset(_G, "combi", {
    running = false,
})

rawset(_G, "COMBI_GetCombiStuff", function(p)
    local cs = p.combistuff

    if cs == nil then
        cs = {
            last_dist = nil, -- distance to partner from last frame
            airtime = 0, -- When above certain threshold, teleport back to partner
            team = nil, -- Team this player belongs too
            friend = {
                player = nil,
                pending = false, -- Will be true until asked player will confirm
            },
        }
        p.combistuff = cs
    end

    return cs
end)

-- Clear things that should not persist between levels
rawset(_G, "COMBI_ClearCombiStuff", function(p)
    local cs = COMBI_GetCombiStuff(p)

    cs.last_dist = nil
    cs.airtime = 0
    cs.team = nil
end)

-- Maybe someone will want to check if its "nucombi" specifically?
rawset(_G, "NUCOMBI", true)

addHook("NetVars", function(net)
    combi = net($)
end)
