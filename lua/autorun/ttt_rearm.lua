AddCSLuaFile()

-- ConVars

CreateConVar('ttt_rearm_enabled', '1', {FCVAR_ARCHIVE}, 'Whether or not re-arm is enabled.', 0, 1)

-- TTT ULX Compatibility

hook.Add('TTTUlxInitCustomCVar', 'RearmTTTUlxInitCustomCVar', function(panel)
    ULib.replicatedWritableCvar('ttt_rearm_enabled', 'rep_ttt_rearm_enabled', GetConVar('ttt_rearm_enabled'):GetBool(), true, false, panel)
end)

if CLIENT then
    hook.Add('TTTUlxModifyAddonSettings', 'RearmTTTUlxModifyAddonSettings', function(panel)
        local tttrspnl = xlib.makelistlayout{w = 415, h = 318, parent = xgui.null}

        -- Basic Settings
        local tttrsclp1 = vgui.Create('DCollapsibleCategory', tttrspnl)
        tttrsclp1:SetSize(390, 50)
        tttrsclp1:SetExpanded(1)
        tttrsclp1:SetLabel('Basic Settings')

        local tttrslst1 = vgui.Create('DPanelList', tttrsclp1)
        tttrslst1:SetPos(5, 25)
        tttrslst1:SetSize(390, 150)
        tttrslst1:SetSpacing(5)

        local tttrsdh11 = xlib.makecheckbox{label = 'ttt_rearm_enabled (def. 1)', repconvar = 'rep_ttt_rearm_enabled', parent = tttrslst1}
        tttrslst1:AddItem(tttrsdh11)

        xlib.hookEvent('onProcessModules', nil, tttrspnl.processModules)
        xgui.addSubModule('Rearm', tttrspnl, nil, panel)
    end)
end

-- <a href="https://www.flaticon.com/free-icons/reset" title="reset icons">Reset icons created by inkubators - Flaticon</a>
-- ammo box by Monjin Friends from <a href="https://thenounproject.com/browse/icons/term/ammo-box/" target="_blank" title="ammo box Icons">Noun Project</a> (CC BY 3.0)

rearm = rearm or {}

function rearm.Log(message)
    print('[Rearm] ' .. message)
end

function rearm.HasMap(map)
    if not isstring(map) then return false end

    return file.Exists('lua/maps/' .. map .. '_ttt.lua', 'GAME')
end

function rearm.LoadSettings(map)
    local settings = {}

    local buffer = file.Read('lua/maps/' .. map .. '_ttt.lua', 'GAME')
    local lines = string.Explode('\n', buffer)
    for _, line in ipairs(lines) do
        if string.StartWith(line, 'setting:') then
            local key, value = string.match(line, '^setting:%s*(%w*)%s*(%d*)')

            if key and value then
                settings[key] = tonumber(value)

                rearm.Log('Loaded re-arm script setting: ' .. key .. ' = ' .. value)
            else
                rearm.Log('Failed to parse re-arm script setting: ' .. line)
            end
        end
    end

    rearm.Log('Loaded ' .. table.Count(settings) .. ' re-arm script settings')

    return settings
end

local ignored_lines = {'#', '--[[', '--]]', 'setting:'}
local class_remapping = {
    ['ttt_playerspawn'] = 'info_player_deathmatch'
}

local function createEntity(cls, pos, ang, kv)
    rearm.Log('Creating entity: ' .. cls)

    local ent = ents.Create(cls)
    if not IsValid(ent) then return NULL end

    ent:SetPos(pos)
    ent:SetAngles(ang)

    if kv then
        for key, value in pairs(kv) do
            ent:SetKeyValue(key, value)
        end
    end

    ent:Spawn()
    ent:Activate()
    ent:PhysWake()

    return ent
end

function rearm.LoadEntities(map)
    local buffer = file.Read('lua/maps/' .. map .. '_ttt.lua', 'GAME')
    local lines = string.Explode('\n', buffer)

    local entities = {}

    for _, line in ipairs(lines) do
        if line == '' then continue end
        local skip = false
        for _, ignored in ipairs(ignored_lines) do
            if string.StartsWith(line, ignored) then
                skip = true
                break
            end
        end

        if skip then continue end

        local valid = false
        local data = string.Explode('\t', line)
        if data[2] and data[3] then
            local cls = data[1]
            local ang, pos

            -- Pos in the form of 'x y z'
            local posData = string.Explode('%s', data[2], true)
            if #posData == 3 then
                pos = Vector(tonumber(posData[1]), tonumber(posData[2]), tonumber(posData[3]) + 16)
            else
                rearm.Log('Failed to parse re-arm script entity position: ' .. line)
            end

            -- Ang in the form of 'p y r'
            local angData = string.Explode('%s', data[3], true)
            if #angData == 3 then
                ang = Angle(tonumber(angData[1]), tonumber(angData[2]), tonumber(angData[3]))
            else
                rearm.Log('Failed to parse re-arm script entity angle: ' .. line)
            end

            local kv = {}
            if data[4] then
                local kvData = string.Explode('%s', data[4], true)
                local key = kvData[1]
                local value = kvData[2]

                if key and value then
                    kv[key] = value
                else
                    rearm.Log('Failed to parse re-arm script entity key-value: ' .. line)
                end
            end

            cls = class_remapping[cls] or cls

            local ent = createEntity(cls, pos, ang, kv)
            if IsValid(ent) then
                table.insert(entities, ent)
                valid = true
            else
                rearm.Log('Failed to create entity: ' .. line)
            end
        end

        if not valid then
            rearm.Log('Failed to parse re-arm script entity: ' .. line)
        end
    end

    rearm.Log('Loaded ' .. #entities .. ' entities')

    return entities
end

local function removeSpawns()
    for k, v in ipairs(GetSpawnEnts(false, true)) do
        v.BeingRemoved = true
        SafeRemoveEntityDelayed(v, 0)
    end
end

local hl2_ammo_replace = {
    ['item_ammo_pistol'] = 'item_ammo_pistol_ttt',
    ['item_box_buckshot'] = 'item_box_buckshot_ttt',
    ['item_ammo_smg1'] = 'item_ammo_smg1_ttt',
    ['item_ammo_357'] = 'item_ammo_357_ttt',
    ['item_ammo_357_large'] = 'item_ammo_357_ttt',
    ['item_ammo_revolver'] = 'item_ammo_revolver_ttt', -- zm
    ['item_ammo_ar2'] = 'item_ammo_pistol_ttt',
    ['item_ammo_ar2_large'] = 'item_ammo_smg1_ttt',
    ['item_ammo_smg1_grenade'] = 'weapon_zm_pistol',
    ['item_battery'] = 'item_ammo_357_ttt',
    ['item_healthkit'] = 'weapon_zm_shotgun',
    ['item_suitcharger'] = 'weapon_zm_mac10',
    ['item_ammo_ar2_altfire'] = 'weapon_zm_mac10',
    ['item_rpg_round'] = 'item_ammo_357_ttt',
    ['item_ammo_crossbow'] = 'item_box_buckshot_ttt',
    ['item_healthvial'] = 'weapon_zm_molotov',
    ['item_healthcharger'] = 'item_ammo_revolver_ttt',
    ['item_ammo_crate'] = 'weapon_ttt_confgrenade',
    ['item_item_crate'] = 'ttt_random_ammo'
}

local hl2_weapon_replace = {
    ['weapon_smg1'] = 'weapon_zm_mac10',
    ['weapon_shotgun'] = 'weapon_zm_shotgun',
    ['weapon_ar2'] = 'weapon_ttt_m16',
    ['weapon_357'] = 'weapon_zm_rifle',
    ['weapon_crossbow'] = 'weapon_zm_pistol',
    ['weapon_rpg'] = 'weapon_zm_sledge',
    ['weapon_slam'] = 'item_ammo_pistol_ttt',
    ['weapon_frag'] = 'weapon_zm_revolver',
    ['weapon_crowbar'] = 'weapon_zm_molotov'
 }

local function removeWeapons()
    for k, v in ipairs(ents.GetAll()) do
        local cls = v:GetClass()
        if string.StartsWith(cls, 'item_') then
            if hl2_ammo_replace[cls] then
                v:Remove()
            end
        elseif string.StartsWith(cls, 'weapon_') then
            if hl2_weapon_replace[cls] then
                v:Remove()
            end
        end
    end

    if istable(ents.TTT) then
        if isfunction(ents.TTT.GetSpawnableAmmo) then
            for _, cls in ipairs(ents.TTT.GetSpawnableAmmo()) do
                for _, v in ipairs(ents.FindByClass(cls)) do
                    v:Remove()
                end
            end
        end

        if isfunction(ents.TTT.GetSpawnableSWEPs) then
            for _, wep in ipairs(ents.TTT.GetSpawnableSWEPs()) do
                local cls = WEPS.GetClass(wep)
                for _, v in ipairs(ents.FindByClass(cls)) do
                    v:Remove()
                end
            end
        end

        if isfunction(ents.TTT.RemoveRagdolls) then
            ents.TTT.RemoveRagdolls(false)
        end
    end

    for _, v in ipairs(ents.FindByClass('weapon_zm_improvised')) do
        v:Remove()
     end
end

hook.Add('TTTPrepareRound', 'RearmPrepareRound', function()
    if CLIENT then return end

    if not GetConVar('ttt_rearm_enabled'):GetBool() then
        rearm.Log('Rearm is disabled, skipping weapon rearm')
        return
    end

    local map = game.GetMap()
    if not rearm.HasMap(map) then
        rearm.Log('Map ' .. map .. ' is not supported, skipping weapon rearm')
    end

    rearm.Log('Loading re-arm script for map ' .. map)

    rearm.Log('Loading re-arm script settings for map ' .. map)
    rearm.Settings = rearm.LoadSettings(map)

    if tobool(rearm.Settings['replacespawns']) then
        rearm.Log('Removing existing player spawns')
        removeSpawns()
    end

    rearm.Log('Removing existing weapons')
    removeWeapons()

    rearm.Log('Loading re-arm script entities for map ' .. map)
    rearm.Entities = rearm.LoadEntities(map)

    if isfunction(SpawnWillingPlayers) then
        SpawnWillingPlayers()
    end

    rearm.Log('Re-arm script loaded successfully')
end)

if SERVER then
    hook.Remove('TTTBeginRound', 'StigMapWeaponsInstallMessage')
end
