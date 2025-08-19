-- base.lua
local getCombiStuff = COMBI_GetCombiStuff
-- tether.lua
local tetherPull = COMBI_TetherPull

local combiteams = {}

local function addTeam(p1, p2)
    table.insert(combiteams, { p1 = p1, p2 = p2 })
    if p1 then
        getCombiStuff(p1).team = combiteams[#combiteams]

        -- haya combi compatibility
        p1.combi = p2 and #p2
        p1.combi_p = p2
    end
    if p2 then
        getCombiStuff(p2).team = combiteams[#combiteams]

        -- haya combi compatibility
        p2.combi = p1 and #p1
        p2.combi_p = p1
    end
end

local function isIngame(p)
    return p and p.valid and not p.spectator
end

local function isAlive(p)
    return p.deadtimer == 0 and p.kartstuff[k_respawn] == 0
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

    if isIngame(p2) and isAlive(p1) and isAlive(p2) then
        tetherPull(p1, p2)
        tetherPull(p2, p1)
    end

    -- For sorting and assigning positions later
    team.maxposition = p1.kartstuff[k_position]
    if isIngame(p2) then
        team.maxposition = min($, p2.kartstuff[k_position])
    end

    -- TODO - timers (sneaker, driftboost, etc)
end

local function updatePosition(p, position, oldposition)
    if not isIngame(p) then return end

    p.kartstuff[k_position] = position
    p.kartstuff[k_oldposition] = oldposition or position

    p.kartstuff[k_positiondelay] = 0
end

local function updateTeams()
    -- First, check if someone joined midgame, if so add them as single-player team
    for p in players.iterate do
        local cs = getCombiStuff(p)
        if not (p.spectator or cs.team) then
            addTeam(p, nil)
        end
    end

    for _, team in ipairs(combiteams) do
        updateTeam(team)
    end

    -- Now assign positions
    table.sort(combiteams, function(a, b) return a.maxposition < b.maxposition end)
    for i, team in ipairs(combiteams) do
        team.oldposition = team.position -- may be nil
        team.position = i

        updatePosition(team.p1, team.position, team.oldposition)
        updatePosition(team.p2, team.position, team.oldposition)
    end
end

local function resetTeams()
    combiteams = {}

    for p in players.iterate do
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

    for p in players.iterate do
        if not p.spectator then table.insert(plist, p) end
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
