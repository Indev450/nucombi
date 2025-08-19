local cv_active = CV_RegisterVar {
    name = "combi_active",
    defaultvalue = "On",
    possiblevalue = CV_OnOff,
    flags = CV_NETVAR,
}

-- base.lua
local getCombiStuff = COMBI_GetCombiStuff
-- teams.lua
local updateTeams = COMBI_UpdateTeams
local resetTeams = COMBI_ResetTeams
local assignTeams = COMBI_AssignTeams
local isIngame = COMBI_IsInGame

local COMBI_STARTTIME = 6*TICRATE + (3*TICRATE/4) - TICRATE

addHook("MapLoad", function()
    if combi.running then
        resetTeams()
    end

    combi.running = cv_active.value == 1
end)

local function handleRespawn(p)
    if p.kartstuff[k_respawn] <= 1 then return end
    if not isIngame(p.combi_p) then return end -- Let vanilla handle respawn

    local p2 = p.combi_p
    local cs = getCombiStuff(p)
    local team = cs.team

    -- Don't respawn into deathpit
    if p2.deadtimer > 0 then
        return
    end

    -- Prevent respawning on top of each other endlessly
    if p2.kartstuff[k_respawn] > 0 and p ~= team.p1 then
        return
    end

    P_MoveOrigin(p.mo, p2.mo.x, p2.mo.y, p2.mo.z + mapobjectscale*128)
    p.mo.momx = p2.mo.momx
    p.mo.momy = p2.mo.momy
    p.mo.momz = 0
    p.mo.angle = p2.mo.angle
end

addHook("ThinkFrame", function()
    if not combi.running then return end

    if leveltime < COMBI_STARTTIME then
        return
    elseif leveltime == COMBI_STARTTIME then
        assignTeams()
    end

    updateTeams()

    for p in players.iterate do
        handleRespawn(p)
    end
end)

addHook("NetVars", function(net)
    combi.running = net($)
end)
