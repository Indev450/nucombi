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

local cv_friendlyfire = CV_RegisterVar {
    name = "combi_friendlyfire",
    defaultvalue = "Off",
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

    -- interop
    hcombi.combi_on = combi.running
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

    -- Wait until your partner is on ground
    if not P_IsObjectOnGround(p2.mo) then
        p.kartstuff[k_respawn] = max($, 5)
    end

    P_MoveOrigin(p.mo, p2.mo.x, p2.mo.y, p2.mo.z + mapobjectscale*128)
    p.mo.momx = p2.mo.momx
    p.mo.momy = p2.mo.momy
    p.mo.momz = 0
    p.mo.angle = p2.mo.angle
end

local function doSignal(p, direction)
    local signal = getCombiStuff(p).signal

    if signal.direction ~= direction or signal.timer == 0 then
        -- TODO - sound
    end

    signal.direction = direction
    signal.timer = TICRATE
end

local function handleSignal(p)
    if not isIngame(p.combi_p) then return end

    local cs = getCombiStuff(p)
    cs.signal.timer = max(0, $ - 1)

    if not cs.signal.use_custom_buttons then return end

    local direction

    if p.cmd.buttons & BT_CUSTOM1 then
        direction = -1
    elseif p.cmd.buttons & BT_CUSTOM2 then
        direction = 1
    elseif p.cmd.buttons & BT_CUSTOM3 then
        direction = 0
    end

    if direction ~= nil then
        doSignal(p, direction)
    end
end

local onopt = {
    on = true,
    yes = true,
    ["1"] = true,
    off = false,
    no = false,
    ["0"] = false,
}
COM_AddCommand("combi_usecustombuttons", function(p, opt)
    local signal = getCombiStuff(p).signal

    if not opt then
        CONS_Printf(p, "combi_usecustombuttons is currently "..(signal.use_custom_buttons and "On" or "Off"))
        return
    end

    local v = onopt[opt:lower()]

    if v == nil then
        CONS_Printf(p, "Usage: combi_usecustombuttons on/off")
        return
    end

    signal.use_custom_buttons = v

    CONS_Printf(p, "combi_usecustombuttons has been set to "..(v and "On" or "Off"))

    if not v then
        CONS_Printf(p, "You can bind other buttons to combi_signal command (for example, bind q \"combi_signal left\")")
    end
end)

local diropt = {
    left = -1,
    ["-1"] = -1,
    forward = 0,
    ["0"] = 0,
    right = 1,
    ["1"] = 1,
}
COM_AddCommand("combi_signal", function(p, dir)
    if not dir or diropt[dir:lower()] == nil then
        CONS_Printf(p, "Usage: combi_signal left/forward/right")
        return
    end

    if not isIngame(p.combi_p) then
        return
    end

    doSignal(p, diropt[dir:lower()])
end)

addHook("ThinkFrame", function()
    if not combi.running then return end

    if leveltime < COMBI_STARTTIME then
        return
    elseif leveltime == COMBI_STARTTIME then
        assignTeams()
    end

    -- Restore "true" positions because some combi team logic relies on that
    -- They will be back to "team" positions after updateTeams()
    for p in players.iterate do
        if p.combirealposition ~= nil then
            p.kartstuff[k_position] = p.combirealposition
        end
    end

    updateTeams()

    for p in players.iterate do
        handleRespawn(p)
        handleSignal(p)
    end
end)

local function playerFriendlyFire(player, inflictor, source)
    if not combi.running then return end
    if cv_friendlyfire.value == 1 then return end
    if source and source.valid and source.player and source.player == player.combi_p then return true end
end

addHook("PlayerSpin", playerFriendlyFire)
addHook("PlayerSquish", playerFriendlyFire)
--addHook("PlayerExplode", playerFriendlyFire) -- Not sure about that one...

-- Damage hooks are not enough :AAAAAAAAAAAA:
local items = {
    MT_BANANA, MT_BANANA_SHIELD,
    MT_EGGMANITEM, MT_EGGMANITEM_SHIELD,
    MT_ORBINAUT, MT_ORBINAUT_SHIELD,
    MT_JAWZ, MT_JAWZ_SHIELD, MT_JAWZ_DUD,
    MT_SPB,
    MT_BALLHOG,
}

local function itemFriendlyFire(mo, pmo)
    if not (mo.valid and pmo.valid and pmo.player) then return end
    if not combi.running then return end
    if cv_friendlyfire.value == 1 then return end

    -- Item source
    local p1 = mo.target and mo.target.player

    -- Player being hit
    local p2 = pmo.player

    -- Disable collision
    if p1 == p2.combi_p then
        return false
    end
end

for _, mt in ipairs(items) do
    addHook("MobjCollide", itemFriendlyFire, mt)
    addHook("MobjMoveCollide", itemFriendlyFire, mt)
end

-- Jawz pls
addHook("MobjThinker", function(mo)
    if not mo.valid then return end
    if not combi.running then return end
    --if cv_friendlyfire.value == 1 then return end -- Don't target partner even if friendly fire is enabled

    local source_p = mo.target and mo.target.player
    local target_p = mo.tracer and mo.tracer.player

    if not (source_p and target_p) then return end

    if target_p == source_p.combi_p then
        mo.tracer = nil -- No
        return
    end
end, MT_JAWZ)

-- JAWZ I SWEAR TO GOD
addHook("MobjThinker", function(pmo)
    if not pmo.valid and pmo.player then return end
    if not combi.running then return end
    if leveltime < COMBI_STARTTIME+1 then return end

    local p = pmo.player
    local team = getCombiStuff(p).team

    if team.position ~= nil then
        p.combirealposition = p.kartstuff[k_position]
        p.kartstuff[k_position] = team.position -- <- this is what makes jawz not target teammates, because it ignores players in same position
    end
end, MT_PLAYER)

rawset(_G, "COMBI_STARTTIME", COMBI_STARTTIME)
