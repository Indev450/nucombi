-- base.lua
local getCombiStuff = COMBI_GetCombiStuff
local isIngame = COMBI_IsInGame

freeslot("S_COMBI_TETHER")

local cv_dist = CV_RegisterVar {
    name = "combi_tether_dist",
    defaultvalue = "450",
    possiblevalue = { MIN = 1, MAX=FRACUNIT-1 },
    flags = CV_NETVAR,
}

local cv_stiffness = CV_RegisterVar {
    name = "combi_tether_stiffness",
    defaultvalue = "0.04",
    possiblevalue = { MIN = 16, MAX = INT32_MAX },
    flags = CV_FLOAT|CV_NETVAR,
}

local cv_damper = CV_RegisterVar {
    name = "combi_tether_damper",
    defaultvalue = "0.01",
    possiblevalue = { MIN = 0, MAX = INT32_MAX },
    flags = CV_FLOAT|CV_NETVAR,
}

local function getTetherCount()
    return 2 + max(0, cv_dist.value/80 - 1)
end

local cv_swapcolors = CV_RegisterVar {
    name = "combi_tether_swapcolors",
    defaultvalue = "Off",
    PossibleValue = {
        On = 1,
        Off = 0,
        Pink = -1, -- :3
    },
    flags = CV_CALL|CV_NOINIT,
    func = function(cv)
        if not combi.running then return end

        local count = getTetherCount()

        for _, team in ipairs(combi.teams) do
            local p1 = isIngame(team.p1) and team.p1
            local p2 = isIngame(team.p2) and team.p2

            if not (p1 and p2) then continue end

            local tether = team.tether
            local i = 1

            while tether and tether.valid do
                if cv.value ~= -1 then
                    local targetcond = (i <= count/2)
                    if cv.value == 1 then targetcond = not targetcond end
                    tether.combitarget = targetcond and p1 or p2
                else
                    tether.combitarget = nil
                end

                tether = tether.hnext
                i = i + 1
            end
        end
    end,
}

local function applyAccel(mo, dirx, diry, dirz, accel)
    mo.momx = mo.momx + FixedMul(dirx, accel)
    mo.momy = mo.momy + FixedMul(diry, accel)
    mo.momz = mo.momz + FixedMul(dirz, accel)
end

local function mobjDist3D(mo1, mo2)
    return FixedHypot(FixedHypot(mo1.x - mo2.x, mo1.y - mo2.y), mo1.z - mo2.z)
end

local function doTeleport(p1, p2)
    p1.powers[pw_flashing] = TICRATE
    P_SetOrigin(p1.mo, p2.mo.x, p2.mo.y, p2.mo.z)
    p1.mo.momx = p2.mo.momx
    p1.mo.momy = p2.mo.momy
    p1.mo.angle = p2.mo.angle
end

-- Applies Hooke's law to p1 (only to p1)
local function tetherPull(p1, p2)
    local cs = getCombiStuff(p1)

    local mo1, mo2 = p1.mo, p2.mo

    local dist = mobjDist3D(mo1, mo2)

    if dist < FRACUNIT then return end

    local maxdist = cv_dist.value*mapobjectscale

    -- If distance is suddenly this high, then other player must've teleported...
    if dist > maxdist*3 then
        -- Very convinient fact: game always updates positions, so we can determine who has teleported by picking player with better position!
        -- relies on good map checkpoints tho
        if p1.kartstuff[k_position] > p2.kartstuff[k_position] then
            doTeleport(p1, p2)
        else
            doTeleport(p2, p1)
        end

        return
    end

    local diff = max(dist - maxdist, 0)

    -- Hooke's law
    local force = FixedMul(diff, cv_stiffness.value)
    local damper = 0

    -- Damper it a bit (should help prevent endless swinging in air probably?)
    if cs.last_dist ~= nil then
        damper = FixedMul(max(dist - cs.last_dist, 0), cv_damper.value)
    end

    -- Acceleration = Force / Mass
    local mass = FRACUNIT -- TODO?
    local a = FixedDiv(force + damper, mass)

    -- Calculate direction in which acceleration is applied
    local dirx, diry, dirz = FixedDiv(mo2.x - mo1.x, dist), FixedDiv(mo2.y - mo1.y, dist), FixedDiv(mo2.z - mo1.z, dist)

    -- Driving becomes a bit broken when z acceleration is applied
    if P_IsObjectOnGround(mo1) and P_IsObjectOnGround(mo2) then
        dirz = 0
    end

    applyAccel(mo1, dirx, diry, dirz, a)

    cs.last_dist = dist
end

local function lerp(a, b, t)
    return a + FixedMul(b-a, t)
end

local function lerpMo(mo1, mo2, t)
    return lerp(mo1.x, mo2.x, t), lerp(mo1.y, mo2.y, t), lerp(mo1.z, mo2.z, t)
end

-- Too lazy to calculate formula or use states
local anim = {0, 1, 2, 3, 4, 5, 6, 7, 8, 3, 2}
local function updateSingleTether(actor)
    local p1 = actor.combi_p1
    local p2 = actor.combi_p2

    local mo1 = p1 and p1.valid and p1.mo
    local mo2 = p2 and p2.valid and p2.mo

    if not (mo1 and mo2) then
        -- Don't remove yet, maybe player just respawned
        actor.sprite = SPR_NULL
        return
    end

    local zoff = 0
    local flip = 1
    if actor.eflags & MFE_VERTICALFLIP then flip = -1 end

    if actor.extravalue2 == 1 then
        -- Ring
        actor.sprite = states[actor.state].sprite
        actor.frame = A
    else
        -- Sparkle
        actor.sprite = SPR_SGNS
        actor.frame = anim[1 + (leveltime/2 % #anim)]
        zoff = 15*mapobjectscale -- Why does it have a weird offset???
        if isIngame(actor.combitarget) then
            actor.color = actor.combitarget.mo.color
        else
            actor.color = SKINCOLOR_BUBBLEGUM
        end
    end

    local x, y, z = lerpMo(mo1, mo2, actor.extravalue1)
    P_MoveOrigin(actor, x, y, z+zoff*flip)
end

local function updateTetherChain(first)
    local tether = first

    while tether and tether.valid do
        updateSingleTether(tether)
        tether = tether.hnext
    end
end

local function removeTetherChain(first)
    local tether = first

    while tether and tether.valid do
        local next = tether.hnext
        P_RemoveMobj(tether)
        tether = next
    end
end

local function spawnTetherEffect(p1, p2)
    local mo1, mo2 = p1.mo, p2.mo

    -- 2 rings + sparks
    local count = getTetherCount()

    -- This makes the t argument for lerp closer to center, so that rings aren't exactly on top of each player and are bit offset
    local mult = 4*FRACUNIT/5
    local offset = (FRACUNIT-mult)/2

    local prev
    local first

    for i = 1, count do
        local ring = i == 1 or i == count

        local t = FRACUNIT/(count-1)*(i-1)
        t = offset + FixedMul(mult, t)

        local x, y, z = lerpMo(mo1, mo2, t)
        local tether = P_SpawnMobj(x, y, z, MT_THOK)

        if prev then prev.hnext = tether end
        if not first then first = tether end

        tether.combi_p1 = p1
        tether.combi_p2 = p2
        tether.extravalue1 = t

        if ring then
            tether.extravalue2 = 1
        else
            if cv_swapcolors.value ~= -1 then
                local targetcond = (i <= count/2)
                if cv_swapcolors.value == 1 then targetcond = not targetcond end
                tether.combitarget = targetcond and p1 or p2
                tether.color = tether.combitarget.mo.color
            else
                tether.color = SKINCOLOR_BUBBLEGUM
            end
            tether.colorized = true
        end

        tether.state = S_COMBI_TETHER
        prev = tether
    end

    return first
end

states[S_COMBI_TETHER] = {
    sprite = SPR_RING,
    frame = A,
    tics = -1,
}

rawset(_G, "COMBI_TetherPull", tetherPull)
rawset(_G, "COMBI_DoTeleport", doTeleport)
rawset(_G, "COMBI_SpawnTether", spawnTetherEffect)
rawset(_G, "COMBI_UpdateTetherChain", updateTetherChain)
rawset(_G, "COMBI_RemoveTetherChain", removeTetherChain)
