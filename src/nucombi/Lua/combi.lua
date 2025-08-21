-- base.lua
local getCombiStuff = COMBI_GetCombiStuff
-- teams.lua
local updateTeams = COMBI_UpdateTeams
local resetTeams = COMBI_ResetTeams
local assignTeams = COMBI_AssignTeams
local isIngame = COMBI_IsInGame
-- friends.lua
local setFriends = COMBI_SetFriends
local setPendingFriend = COMBI_SetPendingFriend
local resetFriends = COMBI_ResetFriends
local getFriend = COMBI_GetFriend

local cv_active = CV_RegisterVar {
    name = "combi_active",
    defaultvalue = "On",
    possiblevalue = CV_OnOff,
    flags = CV_NETVAR,
}

-- Returns matching player + other potential results, used for printing "multiple match..."
local function findPlayer(name)
    local pnum = tonumber(name)

    if pnum ~= nil and pnum >= 0 and pnum <= #players then
        return players[pnum], {}
    end

    local results = {}

    local q = name:lower()
    for player in players.iterate do
        if player.name:lower():find(q) then
            table.insert(results, player)
        end
    end

    local p

    if #results == 1 then
        p = results[1]
    end

    return p, results
end

local offarg = {
    ["off"] = true,
    ["none"] = true,
    ["0"] = true,
}
local function combiFriend(p, arg, write)
    if #arg == 0 then
        write(p, "Usage: combi_friend <name>")

        -- Let em know just in case
        local friend = getFriend(p)
        if friend then
            write(p, "Your current combi friend: "..friend.name)
            write(p, "Use 'combi_friend none' reset combi friend")
        end
        return
    end

    -- Check if player wants to reset first
    if offarg[arg:lower()] then
        local friend = getFriend(p)
        if friend then
            resetFriends(p)
            write(p, "Combi friend has been reset")

            -- :c
            chatprintf(friend, "\x83"..p.name.." is no longer your combi friend :c")
        else
            -- Try to cancel pending request
            friend = getFriend(p, true)

            if friend then
                resetFriends(p)
                write(p, "Friend request canceled")
                chatprintf(friend, "\x83"..p.name.." canceled their friend request :c")
            else
                write(p, "You don't have combi friend set!")
            end
        end
        return
    end

    local target, results = findPlayer(arg)

    -- Don't friend yourself
    if target == p then
        write(p, "Thats you :v")
        return
    end

    if not target then
        if #results > 0 then
            write(p, "Multiple matches found:")
            for _, match in ipairs(results) do
                write(p, "(Player "..#match..") "..match.name)
            end
            write(p, "Try be more specific or use player number")
        else
            write(p, "Player not found")
        end
        return
    end

    -- Check if target player doesn't have friend already
    local friend = getFriend(target)
    if friend then
        write(p, "Player already has combi friend")
        return
    end

    -- Now check if we're accepting friend request
    if getFriend(target, true) == p then
        setFriends(target, p)

        -- Let both know in chat :D
        chatprintf(p, "\x83"..target.name.." will be your combi friend now!")
        chatprintf(target, "\x83"..p.name.." will be your combi friend now!")
        return
    end

    -- Else let other player know that we want to be their friend
    write(p, "Sent friend request to "..target.name.."!")
    chatprintf(target, "\x83"..p.name.." wants to be your combi friend! Use 'combi_friend "..p.name.."' to accept")
    setPendingFriend(p, target)
end

COM_AddCommand("combi_friend", function(p, ...)
    combiFriend(p, table.concat({...}, " "), CONS_Printf)
end)

addHook("PlayerMsg", function(p, type, target, msg)
    if type ~= 0 then return end

    local first, last = msg:find("friend ") -- space is intentional
    if first == 1 then
        combiFriend(p, msg:sub(last+1), function(p, str) chatprintf(p, "\x83"..str, false) end)
        return true
    end
end)

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

rawset(_G, "COMBI_STARTTIME", COMBI_STARTTIME)
