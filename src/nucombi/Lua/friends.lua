-- frens :D

-- base.lua
local getCombiStuff = COMBI_GetCombiStuff
-- teams.lua
local isIngame = COMBI_IsInGame

local function setFriend(p1, p2)
    local cs = getCombiStuff(p1)
    cs.friend.player = p2
    cs.friend.pending = false
end

local function setPendingFriend(p1, p2)
    local cs = getCombiStuff(p1)
    cs.friend.player = p2
    cs.friend.pending = true
end

local function setFriends(p1, p2)
    setFriend(p1, p2)
    setFriend(p2, p1)
end

local function getFriend(p, allow_pending)
    local cs = getCombiStuff(p)

    if (allow_pending or not cs.friend.pending) and cs.friend.player and cs.friend.player.valid then return cs.friend.player end
end

local function resetFriend(p)
    if not (p and p.valid) then return end
    local cs = getCombiStuff(p)
    cs.friend.player = nil
    cs.friend.pending = false
end

-- Only needs 1 of friends as argument
local function resetFriends(p1)
    local p2 = getFriend(p1)
    resetFriend(p1)
    resetFriend(p2)
end

rawset(_G, "COMBI_SetFriends", setFriends)
rawset(_G, "COMBI_SetPendingFriend", setPendingFriend)
rawset(_G, "COMBI_ResetFriends", resetFriends)
rawset(_G, "COMBI_GetFriend", getFriend)
