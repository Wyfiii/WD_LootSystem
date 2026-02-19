if SERVER then
    AddCSLuaFile()
end

WD_Loot = WD_Loot or {}

-------------------------------------------------
-- CONFIG
-------------------------------------------------

WD_Loot.RefreshTime = 300 -- Seconds before a loot container refreshes
WD_Loot.GlowDistance = 500 -- Units for glow to appear

WD_Loot.Tiers = {
    [1] = {
        color = Color(120,255,120),
        items = {
            { class = "mg_357", chance = 50, model = "models/weapons/w_rif_ak47.mdl" },
            { class = "weapon_pistol", chance = 50, model = "models/weapons/w_pistol.mdl" },
            { class = "item_healthkit", chance = 50, model = "models/Items/HealthKit.mdl" }
        }
    },
    [2] = {
        color = Color(0,200,0),
        items = {
            { class = "weapon_smg1", chance = 60, model = "models/weapons/w_smg1.mdl" },
            { class = "weapon_shotgun", chance = 40, model = "models/weapons/w_shotgun.mdl" }
        }
    },
    [3] = {
        color = Color(0,150,255),
        items = {
            { class = "weapon_ar2", chance = 70, model = "models/weapons/w_irifle.mdl" },
            { class = "weapon_crossbow", chance = 30, model = "models/weapons/w_crossbow.mdl" }
        }
    },
    [4] = {
        color = Color(255,120,0),
        items = {
            { class = "weapon_rpg", chance = 20, model = "models/weapons/w_rocket_launcher.mdl" },
            { class = "weapon_ar2", chance = 80, model = "models/weapons/w_irifle.mdl" }
        }
    }
}

-------------------------------------------------
-- SERVER
-------------------------------------------------
if SERVER then

    util.AddNetworkString("WD_OpenLoot")
    util.AddNetworkString("WD_TakeLoot")
    util.AddNetworkString("WD_CloseLoot")

    local DATA_FOLDER = "wd_loot"
    local MAP_FILE = DATA_FOLDER .. "/" .. game.GetMap() .. ".json"

    if not file.Exists(DATA_FOLDER, "DATA") then
        file.CreateDir(DATA_FOLDER)
    end

    WD_Loot.Saved = WD_Loot.Saved or {}

    -------------------------------------------------
    -- ROLL LOOT TABLE
    -------------------------------------------------
    function WD_Loot.RollLootTable(tier)
        local data = WD_Loot.Tiers[tier]
        if not data then return {} end

        local items = {}
        local itemCount = math.random(1,3)

        for i = 1, itemCount do
            local total = 0
            for _, item in ipairs(data.items or {}) do
                total = total + (item.chance or 0)
            end
            if total <= 0 then continue end

            local roll = math.random(1, total)
            local cumulative = 0
            for _, item in ipairs(data.items) do
                cumulative = cumulative + item.chance
                if roll <= cumulative then
                    table.insert(items, { class = item.class, model = item.model })
                    break
                end
            end
        end
        return items
    end

    -------------------------------------------------
    -- BLOCK PHYS/GRAV/TOOLGUN
    -------------------------------------------------
    hook.Add("PhysgunPickup", "WD_BlockPhysgunLoot", function(ply, ent)
        if ent.WD_IsLoot then return false end
    end)

    hook.Add("GravGunPickupAllowed", "WD_BlockGravgunLoot", function(ply, ent)
        if ent.WD_IsLoot then return false end
    end)

    hook.Add("CanTool", "WD_BlockToolgunLoot", function(ply, trace, tool)
        if IsValid(trace.Entity) and trace.Entity.WD_IsLoot then return false end
    end)

    -------------------------------------------------
    -- APPLY LOOT TO ENTITY
    -------------------------------------------------
    local function ApplyLoot(ent, tier)
        ent.WD_IsLoot = true
        ent.WD_Tier = tier
        ent.WD_LootItems = WD_Loot.RollLootTable(tier) or {}

        if not istable(ent.WD_LootItems) then
            ent.WD_LootItems = {}
        end

        -- LOCK MOVEMENT
        ent:SetMoveType(MOVETYPE_NONE)
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:Sleep()
        end

        -- MAKE COMPLETELY INDESTRUCTIBLE
        ent:SetHealth(9999999)
        ent:SetMaxHealth(9999999)
        ent:SetCollisionGroup(COLLISION_GROUP_NONE)

        ent:AddCallback("OnTakeDamage", function() return true end)
        ent:AddCallback("EntityTakeDamage", function() return true end)

        -- NETWORK VALUES
        ent:SetNWBool("WD_HasLoot", #ent.WD_LootItems > 0)
        ent:SetNWInt("WD_Tier", tier)
    end

    -------------------------------------------------
    -- SAVE/LOAD
    -------------------------------------------------
    local function SaveAll()
        file.Write(MAP_FILE, util.TableToJSON(WD_Loot.Saved, true))
    end

    local function AddToSave(ent)
        table.insert(WD_Loot.Saved, {
            pos = ent:GetPos(),
            ang = ent:GetAngles(),
            model = ent:GetModel(),
            tier = ent.WD_Tier
        })
        SaveAll()
    end

    local function LoadAll()
        if not file.Exists(MAP_FILE, "DATA") then return end
        WD_Loot.Saved = util.JSONToTable(file.Read(MAP_FILE, "DATA") or "") or {}

        for _, data in ipairs(WD_Loot.Saved) do
            local ent = ents.Create("prop_physics")
            if not IsValid(ent) then continue end
            ent:SetModel(data.model)
            ent:SetPos(Vector(data.pos.x, data.pos.y, data.pos.z))
            ent:SetAngles(Angle(data.ang.p, data.ang.y, data.ang.r))
            ent:Spawn()
            ApplyLoot(ent, data.tier)
        end
    end

    hook.Add("InitPostEntity", "WD_LoadLoot", function()
        timer.Simple(1, LoadAll)
    end)

    -------------------------------------------------
    -- CREATE LOOT COMMAND
    -------------------------------------------------
    hook.Add("PlayerSay", "WD_CreateLootCommand", function(ply, text)
        if not ply:IsSuperAdmin() then return end
        local args = string.Explode(" ", string.Trim(text))
        if string.lower(args[1]) ~= "!createloot" then return end

        local tier = tonumber(args[2])
        if not tier or not WD_Loot.Tiers[tier] then
            ply:ChatPrint("Invalid tier. Use 1-4.")
            return ""
        end

        local trace = ply:GetEyeTrace()
        if not IsValid(trace.Entity) then
            ply:ChatPrint("Look at a prop.")
            return ""
        end

        local ent = trace.Entity
        ApplyLoot(ent, tier)
        AddToSave(ent)

        ply:ChatPrint("Created Persistent Loot Container (Tier " .. tier .. ")")
        return ""
    end)

    -------------------------------------------------
    -- OPEN LOOT
    -------------------------------------------------
    hook.Add("KeyPress", "WD_OpenLoot_KeyPress", function(ply, key)
        if key ~= IN_USE then return end
        local trace = ply:GetEyeTrace()
        local ent = trace.Entity
        if not IsValid(ent) or not ent.WD_IsLoot or not ent:GetNWBool("WD_HasLoot") then return end
        if ply:GetPos():DistToSqr(ent:GetPos()) > (WD_Loot.GlowDistance * WD_Loot.GlowDistance) then return end

        net.Start("WD_OpenLoot")
            net.WriteEntity(ent)
            net.WriteUInt(#ent.WD_LootItems, 8)
            for _, item in ipairs(ent.WD_LootItems) do
                net.WriteString(item.class)
                net.WriteString(item.model or "")
            end
        net.Send(ply)
    end)

    -------------------------------------------------
    -- TAKE ITEM
    -------------------------------------------------
    net.Receive("WD_TakeLoot", function(_, ply)
        if not IsValid(ply) then return end
        local ent = net.ReadEntity()
        local item = net.ReadString()
        if not IsValid(ent) or not ent.WD_IsLoot or not ent.WD_LootItems then return end

        ply.WD_NextLootTake = ply.WD_NextLootTake or 0
        if CurTime() < ply.WD_NextLootTake then return end
        ply.WD_NextLootTake = CurTime() + 0.2

        local foundIndex = nil
        for k, v in ipairs(ent.WD_LootItems) do
            if v.class == item then
                foundIndex = k
                break
            end
        end
        if not foundIndex then return end

        table.remove(ent.WD_LootItems, foundIndex)
        if not ply:HasWeapon(item) then ply:Give(item) end

        if #ent.WD_LootItems <= 0 then
            ent:SetNWBool("WD_HasLoot", false)
            ent.WD_NextRefresh = CurTime() + WD_Loot.RefreshTime

            net.Start("WD_CloseLoot")
            net.Send(ply)
        end
    end)

    -------------------------------------------------
    -- REFRESH LOOP
    -------------------------------------------------
    hook.Add("Think", "WD_LootRefreshThink", function()
        for _, ent in ipairs(ents.GetAll()) do
            if not ent.WD_IsLoot or ent:GetNWBool("WD_HasLoot") or not ent.WD_NextRefresh then continue end
            if CurTime() >= ent.WD_NextRefresh then
                local tier = ent.WD_Tier
                if tier and WD_Loot.Tiers[tier] then
                    ent.WD_LootItems = WD_Loot.RollLootTable(tier) or {}
                    ent:SetNWBool("WD_HasLoot", #ent.WD_LootItems > 0)
                end
                ent.WD_NextRefresh = nil
            end
        end
    end)

end

-------------------------------------------------
-- CLIENT
-------------------------------------------------
if CLIENT then

    hook.Add("PreDrawHalos", "WD_LootGlow", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        local plyPos = ply:GetPos()

        for tier, data in pairs(WD_Loot.Tiers) do
            local entsToHalo = {}
            for _, ent in ipairs(ents.FindByClass("prop_physics")) do
                if not ent:GetNWBool("WD_HasLoot") then continue end
                if ent:GetNWInt("WD_Tier") ~= tier then continue end
                if plyPos:DistToSqr(ent:GetPos()) > (WD_Loot.GlowDistance * WD_Loot.GlowDistance) then continue end
                table.insert(entsToHalo, ent)
            end
            if #entsToHalo > 0 then
                halo.Add(entsToHalo, data.color, 2,2,1,true,true)
            end
        end
    end)

    -- OPEN LOOT PANEL
    net.Receive("WD_OpenLoot", function()
        local ent = net.ReadEntity()
        local count = net.ReadUInt(8)
        if not IsValid(ent) then return end
        local items = {}
        for i = 1, count do
            table.insert(items, { class = net.ReadString(), model = net.ReadString() })
        end
        if #items <= 0 then return end

        WD_LootFrame = vgui.Create("DFrame")
        local frame = WD_LootFrame
        frame:SetSize(600,450)
        frame:Center()
        frame:SetTitle("Loot Container")
        frame:MakePopup()
        frame.OnClose = function() WD_LootFrame = nil end

        local main = vgui.Create("DPanel", frame)
        main:Dock(FILL)
        main:DockMargin(10,10,10,10)

        local grid = vgui.Create("DIconLayout", main)
        grid:Dock(FILL)
        grid:SetSpaceX(8)
        grid:SetSpaceY(8)

        local tier = ent:GetNWInt("WD_Tier")
        local rarityColor = WD_Loot.Tiers[tier] and WD_Loot.Tiers[tier].color or Color(255,255,255)

        for _, item in ipairs(items) do
            local slot = grid:Add("DPanel")
            slot:SetSize(100,100)
            slot.Paint = function(self,w,h)
                surface.SetDrawColor(30,30,30,240)
                surface.DrawRect(0,0,w,h)
                surface.SetDrawColor(rarityColor)
                surface.DrawOutlinedRect(0,0,w,h,3)
            end

            local icon = vgui.Create("SpawnIcon", slot)
            icon:SetSize(90,90)
            icon:SetPos(5,5)
            icon:SetModel(item.model ~= "" and item.model or "models/error.mdl")
            icon:SetTooltip(item.class)

            icon.DoClick = function()
                net.Start("WD_TakeLoot")
                    net.WriteEntity(ent)
                    net.WriteString(item.class)
                net.SendToServer()
                slot:Remove()
            end
        end
    end)

    net.Receive("WD_CloseLoot", function()
        if IsValid(WD_LootFrame) then
            WD_LootFrame:Close()
            WD_LootFrame = nil
        end
    end)
end
