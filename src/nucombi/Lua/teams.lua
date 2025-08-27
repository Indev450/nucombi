-- base.lua
local getCombiStuff = COMBI_GetCombiStuff
local clearCombiStuff = COMBI_ClearCombiStuff
-- tether.lua
local tetherPull = COMBI_TetherPull
local doTeleport = COMBI_DoTeleport
local spawnTetherEffect = COMBI_SpawnTether
local updateTetherChain = COMBI_UpdateTetherChain

-- Multiples of TICRATE
local cv_maxairtime = CV_RegisterVar {
    name = "combi_maxairtime",
    defaultvalue = "3",
    possiblevalue = CV_Natural,
    flags = CV_NETVAR,
}

combi.teams = {}

local function addTeam(p1, p2)
    table.insert(combi.teams, { p1 = p1, p2 = p2 })

    local team = combi.teams[#combi.teams]

    if p1 then
        getCombiStuff(p1).team = team

        -- haya combi compatibility
        p1.combi = p2 and #p2
        p1.combi_p = p2
    end
    if p2 then
        getCombiStuff(p2).team = team

        -- haya combi compatibility
        p2.combi = p1 and #p1
        p2.combi_p = p1
    end

    if p1 and p2 then
        team.tether = spawnTetherEffect(p1, p2)
    end
end

local function isIngame(p)
    return p and p.valid and not p.spectator
end

local function isAlive(p)
    return p.deadtimer == 0 and p.kartstuff[k_respawn] == 0
end

-- Gentlemen, synchronize your death watches.
local function synchTimer(p1, p2, k)
    local timer = max(p1.kartstuff[k], p2.kartstuff[k])
    p1.kartstuff[k] = timer
    p2.kartstuff[k] = timer
end

local function sign(x)
    if x < 0 then return -1 end
    if x > 0 then return 1 end
    return 0
end

-- Normally you can only go shrink -> normal, or normal -> growth, and grow -> normal, so only those cases are handled
local function setGrowShrink(p, timer)
    local current = p.kartstuff[k_growshrinktimer]

    if timer == current then return end

    if sign(timer) ~= sign(current) then
        S_StartSound(p.mo, (sign(timer) > sign(current)) and sfx_kc5a or sfx_kc59)
    end

    p.mo.scalespeed = mapobjectscale/TICRATE
    if timer == 0 then
        p.mo.color = p.skincolor
        p.mo.destscale = mapobjectscale
    elseif timer > 0 then
        p.mo.destscale = 3*mapobjectscale/2
    end

    p.kartstuff[k_growshrinktimer] = timer
end

local function synchGrowCancel(p1, p2)
    if p2.kartstuff[k_growcancel] < p1.kartstuff[k_growcancel] then
        p1.kartstuff[k_growcancel] = min($, 20)
    end
end

local function setExiting(p, t, losing)
    if p.exiting > 0 then return end

    p.exiting = t
    S_StartSound(p.mo, losing and sfx_klose or sfx_kwin)
end

local function setLaps(p, laps)
    if p.laps == laps then return end
    p.laps = laps
    p.starpostnum = 0 -- Don't do 2 laps in one go pls
end

local function airTick(p)
    local cs = getCombiStuff(p)

    if P_IsObjectOnGround(p.mo) or not P_IsObjectOnGround(p.combi_p.mo) or p.kartstuff[k_respawn] > 0 then
        cs.airtime = 0
        return
    end

    cs.airtime = $ + 1

    if cs.airtime > cv_maxairtime.value*TICRATE then
        cs.airtime = 0
        doTeleport(p, p.combi_p)
    end
end

local function updateTeam(team)
    local p1, p2 = team.p1, team.p2

    if not isIngame(p1) then
        team.p1 = p2
        team.p2 = nil
        p1 = p2
        p2 = nil
    end

    -- Still no? Both players probably left then
    if not isIngame(p1) then
        team.p1 = nil
        team.maxposition = 0xff
        return
    end

    -- Does pretty much nothing if there's no tether or no teammate, so no need for any checks
    updateTetherChain(team.tether)

    local has_partner = isIngame(p2)

    if has_partner and isAlive(p1) and isAlive(p2) then
        tetherPull(p1, p2)
        tetherPull(p2, p1)
    end

    -- For sorting and assigning positions later
    team.maxposition = p1.kartstuff[k_position]
    if has_partner then
        team.maxposition = min($, p2.kartstuff[k_position])
    end

    if has_partner then
        synchTimer(p1, p2, k_sneakertimer)
        synchTimer(p1, p2, k_startboost)
        synchTimer(p1, p2, k_driftboost)
        synchTimer(p1, p2, k_hyudorotimer)
        synchTimer(p1, p2, k_invincibilitytimer)

        -- Grow/shrink is a bit more involved
        if p1.kartstuff[k_growshrinktimer] ~= 0 or p2.kartstuff[k_growshrinktimer] ~= 0 then
            local timer = max(p1.kartstuff[k_growshrinktimer], p2.kartstuff[k_growshrinktimer])

            setGrowShrink(p1, timer)
            setGrowShrink(p2, timer)
        end

        -- Allow canceling grow
        synchGrowCancel(p1, p2)
        synchGrowCancel(p2, p1)

        airTick(p1)
        airTick(p2)
    end

    -- FI(NI)SH!
    local exiting = max(p1.exiting, has_partner and p2.exiting or 0)

    if exiting > 0 then
        team.finish = true
        -- Hack so your character doesn't say lose quote when your team actually wins
        -- (in simplest case, happens when you have 1 team, 1st player who touches finish line says win quote
        -- but second would say lose one because according to game they are 2nd and are losing)
        local losing = K_IsPlayerLosing(p1) and (not has_partner or K_IsPlayerLosing(p2))
        setExiting(p1, exiting, losing)
        if has_partner then setExiting(p2, exiting, losing) end
    end

    -- Also synch laps
    local laps = max(p1.laps, has_partner and p2.laps or 0)

    setLaps(p1, laps)
    if has_partner then setLaps(p2, laps) end
end

local function updatePosition(p, position, oldposition)
    if not isIngame(p) then return end

    p.kartstuff[k_position] = position
    p.kartstuff[k_oldposition] = oldposition or position

    p.kartstuff[k_positiondelay] = 0
end

local cv_karteliminatelast
local function getEliminateLast()
    if cv_karteliminatelast == nil then
        cv_karteliminatelast = CV_FindVar("karteliminatelast")
    end

    return cv_karteliminatelast.value
end

local function eliminate(p)
    if not isIngame(p) then return end

    p.lives = 0
    p.pflags = $|PF_TIMEOVER
	P_DamageMobj(p.mo, nil, nil, 10000)

	local boom = P_SpawnMobj(p.mo.x, p.mo.y, p.mo.z, MT_FZEROBOOM)
	boom.scale = p.mo.scale
	boom.angle = p.mo.angle
	boom.target = p.mo
end

local function updateTeams()
    -- First, check if someone joined midgame, if so add them as single-player team
    for p in players.iterate do
        local cs = getCombiStuff(p)
        if not (p.spectator or cs.team) then
            addTeam(p, nil)
        end
    end

    local total = 0
    local racing = 0
    for _, team in ipairs(combi.teams) do
        updateTeam(team)

        if isIngame(team.p1) then
            total = total + 1

            if not team.finish then
                racing = racing + 1
            end
        end
    end

    -- Now assign positions
    table.sort(combi.teams, function(a, b) return a.maxposition < b.maxposition end)
    for i, team in ipairs(combi.teams) do
        team.oldposition = team.position -- may be nil
        team.position = i

        updatePosition(team.p1, team.position, team.oldposition)
        updatePosition(team.p2, team.position, team.oldposition)
    end

    -- >:3
    if getEliminateLast() and total > 1 and racing == 1 then
        local elimteam = nil

        for _, team in ipairs(combi.teams) do
            if not team.finish and isIngame(team.p1) then
                elimteam = team
                break
            end
        end

        assert(elimteam, "couldn't find last racing team for karteliminatelast?")

        -- Its a way to finish too... (also prevents loud fucking explosion)
        elimteam.finish = true

        eliminate(elimteam.p1)
        eliminate(elimteam.p2)
    end
end

local function resetTeams()
    combi.teams = {}

    for p in players.iterate do
        clearCombiStuff(p)
        p.combi = nil
        p.combi_p = nil
    end
end

local function takeRandomPlayer(plist)
    if #plist == 0 then return end

    local i = 1

    if #plist > 1 then
        i = P_RandomRange(1, #plist)
    end

    return table.remove(plist, i)
end

local function assignTeams()
    local plist = {}

    -- Players without combi friend go into plist, friend teams get created right away
    for p in players.iterate do
        if p.spectator then continue end
        if getCombiStuff(p).team ~= nil then continue end -- Don't assign team twice (for friend teams)

        local friend = COMBI_GetFriend(p)
        if isIngame(friend) then
            addTeam(p, friend)
        else
            table.insert(plist, p)
        end
    end

    while #plist > 0 do
        local p1 = takeRandomPlayer(plist)
        local p2 = takeRandomPlayer(plist)

        addTeam(p1, p2)
    end
end

rawset(_G, "COMBI_UpdateTeams", updateTeams)
rawset(_G, "COMBI_ResetTeams", resetTeams)
rawset(_G, "COMBI_AssignTeams", assignTeams)
rawset(_G, "COMBI_IsInGame", isIngame)
