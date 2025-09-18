-- base.lua
local getCombiStuff = COMBI_GetCombiStuff
local isIngame = COMBI_IsInGame
-- friends.lua
local getFriend = COMBI_GetFriend

local cv_signalscale = CV_RegisterVar {
    name = "combi_signal_scale",
    defaultvalue = "1.0",
    possiblevalue = CV_Natural,
    flags = CV_FLOAT,
}

-- Cache for patches
local PATCH
-- Cache for item patches, instead of strings it uses item ids
local ITEMPATCH = {}

local cv_highresportrait
local function useHighresPortrait()
    if not cv_highresportrait then
        cv_highresportrait = CV_FindVar("highresportrait") or { value = 0 }
    end

    return cv_highresportrait.value
end

local function getIcon(p)
    local highres = useHighresPortrait()
    local scale = highres and FRACUNIT/2 or FRACUNIT
    local icon

    if APPEAR_GetAppearance and APPEAR_GetAppearance(p) ~= "default" then
        icon = highres and APPEAR_GetWantedGFX(p) or APPEAR_GetRankGFX(p)
    else
        icon = skins[p.mo.skin][highres and "facewant" or "facerank"]
    end

    return icon, scale
end

local function drawIcon(v, x, y, p, flags, blink)
    local icon, scale
    local cmap

    if isIngame(p) then
        local name
        name, scale = getIcon(p)
        icon = v.cachePatch(name)
        local tc = TC_DEFAULT
        if blink then tc = TC_BLINK end
        cmap = v.getColormap(tc, p.mo.color)

        local spin = max(p.kartstuff[k_spinouttimer], p.kartstuff[k_wipeoutslow])

        y = y + FixedMul(sin(14*leveltime*ANG1), min(spin, 2*TICRATE)*FRACUNIT/3)/FRACUNIT

        if spin == 0 and p.kartstuff[k_respawn] == 0 and p.powers[pw_flashing] > 0 and leveltime % 2 == 0 then
            icon = PATCH["COMBINP"]
        end
    else
        icon = PATCH["COMBINP"]
        scale = FRACUNIT
    end

    v.drawScaled(x*FRACUNIT, y*FRACUNIT, scale, icon, flags, cmap)
end

local dirs = { [-1] = "CMBDIR_L", [0] = "CMBDIR_F", [1] = "CMBDIR_R" }
local function drawDirection(v, x, y, scale, dir, flags)
    local t = v.localTransFlag()>>V_ALPHASHIFT
    if leveltime % 8 < 4 then
        if t < 9 then
            t = min(t+1, 9)
        else
            t = t-1
        end
    end
    flags = (flags & ~V_HUDTRANS)|(t<<V_ALPHASHIFT)

    local patch = PATCH[dirs[dir]]
    x = x - FixedMul(scale, patch.width*FRACUNIT/2)
    v.drawScaled(x, y, scale, patch, flags)
end

local function drawPartner(v, p)
    local maxoffset = 60

    -- Doesn't matter before partner is assigned
    if not isIngame(p.combi_p) then
        maxoffset = 120
    end

    local yoffset = max(0, min(maxoffset, (leveltime - (COMBI_STARTTIME+TICRATE))*2))
    local x = 160-13

    -- Only happens when there's no partner
    if yoffset == 120 then return end

    local flags = V_HUDTRANS|V_SNAPTOBOTTOM

    drawIcon(v, x-14, 100+yoffset-3, p, flags)
    v.drawString(x-16, 100+yoffset, p.name, flags|V_ALLOWLOWERCASE, "thin-right")

    local color_l = v.getColormap(TC_DEFAULT, p.mo.color)
    local patch_l = PATCH["COMBH_L"]

    v.draw(x+2, 92+yoffset, patch_l, flags, color_l)

    local color_r = v.getColormap(TC_DEFAULT, SKINCOLOR_GREY)
    local patch_r = PATCH["COMBH_R"]
    local growcancel = false

    local partner = "???"

    -- For blinking after your partner gets selected
    local blink = leveltime < COMBI_STARTTIME+TICRATE/2 and leveltime % 2 == 0

    -- Will be false before COMBI_STARTTIME every time
    if isIngame(p.combi_p) then
        partner = blink and "" or p.combi_p.name

        -- ee not sure if ternary will work here
        local tc = TC_DEFAULT
        if blink then tc = TC_BLINK end

        color_r = v.getColormap(tc, p.combi_p.mo.color)
        growcancel = p.combi_p.kartstuff[k_growcancel] > 4
    elseif leveltime <= COMBI_STARTTIME then
        -- Slower blinking before partner is selected
        if leveltime % 8 < 4 then
            partner = ""
            patch_r = nil
        end
    else
        partner = blink and "" or "no one, sorry"

        -- ee not sure if ternary will work here
        local tc = TC_RAINBOW
        if blink then tc = TC_BLINK end

        color_r = v.getColormap(tc, SKINCOLOR_GREY)
    end

    if leveltime == COMBI_STARTTIME+1 then
        if p.combi_p and p.combi_p.valid then
            S_StartSound(nil, p.combi_p == getFriend(p) and sfx_yeeeah or sfx_kc48, p)
        else
            S_StartSound(nil, sfx_kc49, p)
        end
    end

    v.drawString(x+42, 100+yoffset, partner, flags|V_ALLOWLOWERCASE, "thin")
    if patch_r then
        drawIcon(v, x+24, 100+yoffset-3, p.combi_p, flags, blink)
        v.draw(x+2, 92+yoffset, patch_r, flags, color_r)
    end

    if growcancel then
        v.drawString(x-16, 100+yoffset-14, "CANCEL GROW", flags|((leveltime % 8 < 4 and V_BLUEMAP) or 0), "thin")
    end

    local cs = getCombiStuff(p, true)
    if cs and cs.signal.timer > 0 then
        drawDirection(v, 160*FRACUNIT, (100+yoffset-32)*FRACUNIT, FRACUNIT/4, cs.signal.direction, flags)
    end
end

local darkbg = {
    [KITEM_INVINCIBILITY] = true,
    [KITEM_SPB] = true,
    [KITEM_THUNDERSHIELD] = true,
}

local function getItemPatch(v, itemtype)
    if itemtype == KITEM_INVINCIBILITY then
        local anim = ((leveltime / 3) % 6) + 1
        return v.cachePatch("K_ISINV"..anim)
    end

    local patch = ITEMPATCH[itemtype]

    if patch == nil then
        patch = v.cachePatch(K_GetItemPatch(itemtype, true))
        ITEMPATCH[itemtype] = patch
    end

    return patch
end

local function drawItem(v, x, y, itemtype, itemamount, flags, cmap)
    v.draw(x, y, PATCH[darkbg[itemtype] and "K_ISBGD" or "K_ISBG"], flags)
    if itemtype ~= 0 then v.draw(x, y, getItemPatch(v, itemtype), flags, cmap) end

    if itemamount > 1 then
        v.draw(x, y, PATCH["K_ISMUL"], flags)
        v.drawString(x+28, y+32, "x"..itemamount, flags)
    end
end

-- (note - here is combi_p, not display player)
local function drawPartnerItem(v, p)
    if not isIngame(p) then return end

    local offx, offy = 0, 0
    if hud.getOffsets then offx, offy = hud.getOffsets("item") end

    local x, y = 50+offx, offy
    local flags = V_SNAPTOLEFT|V_SNAPTOTOP|V_HUDTRANS

    local ks = p.kartstuff
    local item = ks[k_itemtype]
    local amount = ks[k_itemamount]
    local cmap
    local itembar, maxl
    local barlength = 12
    local itemtime = 8*TICRATE

    if ks[k_itemroulette] then
        item = ((leveltime / 3) % 14) + 1
        amount = 1
        cmap = v.getColormap(TC_RAINBOW, p.skincolor)
    else
        if ks[k_stolentimer] > 0 then
            if leveltime & 2 then
                item = KITEM_HYUDORO
                amount = 1
            else
                item = 0
            end
        elseif ks[k_stealingtimer] > 0 and (leveltime & 2) then
            item = KITEM_HYUDORO
            amount = 1
        elseif ks[k_eggmanexplode] > 1 then
            if leveltime & 1 then
                item = KITEM_EGGMAN
                amount = 1
            else
                item = 0
            end
        elseif ks[k_rocketsneakertimer] > 1 then
            itembar = ks[k_rocketsneakertimer]
            maxl = (itemtime*3) - barlength

            if leveltime & 1 then
                item = KITEM_ROCKETSNEAKER
            else
                item = 0
            end
        elseif ks[k_growshrinktimer] > 0 then
            if ks[k_growcancel] > 0 then
                itembar = ks[k_growcancel]
                maxl = 26
            end

            if leveltime & 1 then
                item = KITEM_GROW
            else
                item = 0
            end
        elseif ks[k_sadtimer] > 0 then
            if leveltime & 2 then
                item = KITEM_SAD
            else
                item = 0
            end
        else
            if item == 0 or amount <= 0 then return end

            if ks[k_itemheld] and not (leveltime & 1) then
                item = 0
            end

            if ks[k_itemblink] and (leveltime & 1) then
                local skincolor = SKINCOLOR_WHITE

                if ks[k_itemblinkmode] == 2 then
                    skincolor = (1 + (leveltime % (MAXSKINCOLORS-1)))
                elseif ks[k_itemblinkmode] == 1 then
                    skincolor = SKINCOLOR_RED
                end

                cmap = v.getColormap(TC_BLINK, skincolor)
            end
        end
    end

    drawItem(v, x, y, item, amount, flags, cmap)
    v.draw(x+32, y+8, v.cachePatch(skins[p.mo.skin].facemmap), flags, v.getColormap(TC_DEFAULT, p.mo.color))

    if itembar then
        local fill = (itembar * barlength) / maxl
        local length = min(barlength, fill)
        local height = 1

        local bx = 17
        local by = 27

        v.draw(x + bx, y + by, PATCH["K_ISIMER"], flags)
        v.drawFill(x + bx + 1, y + by + 1, (length == 2) and 2 or 1, height, 12|flags)

        if length > 2 then
            v.drawFill(x + bx + length, y + by + 1, 1, height, 12|flags)

            v.drawFill(x + bx + 2, y + by + 1, length-2, 1, 120|flags)
        end
	end
end

local function drawPartnerDirection(v, p)
    if not isIngame(p) then return end

    local cs = getCombiStuff(p, true)

    if cs and cs.signal.timer > 0 then
        -- left/right signals can be moved a bit up
        local ofs = 0
        if cs.signal.direction ~= 0 then
            ofs = -18
        end

        drawDirection(v, 160*FRACUNIT, (2+ofs)*FRACUNIT, cv_signalscale.value, cs.signal.direction, V_HUDTRANS|V_SNAPTOTOP)
    end
end

local function cachePatches(v)
    PATCH = {}

    local function addpatch(name)
        PATCH[name] = v.cachePatch(name)
    end

    addpatch("COMBH_L")
    addpatch("COMBH_R")
    addpatch("COMBINP")

    addpatch("K_ISBG")
    addpatch("K_ISBGD")
    addpatch("K_ISMUL")
    addpatch("K_ISIMER") -- isimer

    addpatch("CMBDIR_L")
    addpatch("CMBDIR_R")
    addpatch("CMBDIR_F")
end

hud.add(function(v, p)
    if not combi.running then return end
    if p.spectator then return end
    if p ~= displayplayers[0] then return end -- TODO

    if not PATCH then cachePatches(v) end

    drawPartner(v, p)
    drawPartnerItem(v, p.combi_p)
    drawPartnerDirection(v, p.combi_p)
end)
