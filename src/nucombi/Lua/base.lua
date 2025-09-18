rawset(_G, "combi", {
    running = false,
})

-- Haya combi interop
rawset(_G, "hcombi", {
    combi_on = false,

    -- ...do we need anything else?
})

rawset(_G, "COMBI_GetCombiStuff", function(p, ishud)
    local cs = p.combistuff

    -- Do nOt aLtEr pLaYeR_T In hUd rEnDeRiNg cOdE
    if cs == nil and not ishud then
        cs = {
            last_dist = nil, -- distance to partner from last frame
            airtime = 0, -- When above certain threshold, teleport back to partner
            team = nil, -- Team this player belongs too
            friend = {
                player = nil,
                pending = false, -- Will be true until asked player will confirm
            },
            signal = {
                direction = 0,
                timer = 0,
                use_custom_buttons = true,
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
    cs.signal.direction = 0
    cs.signal.timer = 0
end)

rawset(_G, "COMBI_IsInGame", function(p)
    return p and p.valid and not p.spectator
end)

-- Maybe someone will want to check if its "nucombi" specifically?
rawset(_G, "NUCOMBI", true)

addHook("NetVars", function(net)
    combi = net($)

    hcombi.combi_on = net($)
end)
