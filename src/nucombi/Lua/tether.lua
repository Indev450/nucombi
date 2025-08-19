-- base.lua
local getCombiStuff = COMBI_GetCombiStuff

local STIFFNESS = FRACUNIT/16
local DAMPER = FRACUNIT/2
local DIST = 300*FRACUNIT

local function applyAccel(mo, dirx, diry, dirz, accel)
    mo.momx = mo.momx + FixedMul(dirx, accel)
    mo.momy = mo.momy + FixedMul(diry, accel)
    mo.momz = mo.momz + FixedMul(dirz, accel)
end

local function mobjDist3D(mo1, mo2)
    return FixedHypot(FixedHypot(mo1.x - mo2.x, mo1.y - mo2.y), mo1.z - mo2.z)
end

-- Applies Hooke's law to p1 (only to p1)
local function tetherPull(p1, p2)
    local cs = getCombiStuff(p1)

    local mo1, mo2 = p1.mo, p2.mo

    local dist = mobjDist3D(mo1, mo2)

    local diff = max(dist - FixedMul(DIST, mapobjectscale), 0)

    if diff > 0 then
        -- Hooke's law
        local force = FixedMul(diff, STIFFNESS)
        local damper = 0

        -- Damper it a bit (should help prevent endless swinging in air probably?)
        if cs.last_dist[p2] ~= nil then
            damper = FixedMul(dist - cs.last_dist[p2], DAMPER)
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
    end

    cs.last_dist[p2] = dist
end

rawset(_G, "COMBI_TetherPull", tetherPull)
