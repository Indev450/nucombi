-- base.lua
local getCombiStuff = COMBI_GetCombiStuff

local cv_dist = CV_RegisterVar {
    name = "combi_tether_dist",
    defaultvalue = "300",
    possiblevalue = { MIN = 1, MAX=FRACUNIT-1 },
    flags = CV_NETVAR,
}

local cv_stiffness = CV_RegisterVar {
    name = "combi_tether_stiffness",
    defaultvalue = "0.0625",
    possiblevalue = { MIN = 16, MAX = INT32_MAX },
    flags = CV_FLOAT|CV_NETVAR,
}

local cv_damper = CV_RegisterVar {
    name = "combi_tether_damper",
    defaultvalue = "0.01",
    possiblevalue = { MIN = 0, MAX = INT32_MAX },
    flags = CV_FLOAT|CV_NETVAR,
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

rawset(_G, "COMBI_TetherPull", tetherPull)
rawset(_G, "COMBI_DoTeleport", doTeleport)
