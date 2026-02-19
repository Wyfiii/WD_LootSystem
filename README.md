Created By Wyatt / Wyfiii
This addon addon make it so u can create tier lootable props / entities.

-------------------------------------------------
-- CONFIG
-------------------------------------------------

Make sure you edit the config section in the wd_loot_init.lua file

There you can change the parameter of the chance of drop an item, and also edit items that may drop from the lootbox (You can only add an entity, or weapon currently). you may also choose what model appears for each lootable item

WD_Loot.RefreshTime = 300 -- Seconds before a loot container refreshes

WD_Loot.GlowDistance = 500 -- Units for glow to appear

WD_Loot.Tiers = {

    [1] = {
        color = Color(120,255,120),
        items = {
            { class = "weapon_ak47custom", chance = 50, model = "models/weapons/w_rif_ak47.mdl" },
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


commands: spawn in a prop and look at it and type in one of the commands and it will freeze it and make it lootable.
!createloot 1 
!createloot 2
!createloot 3
!createloot 4

This is one of my first addons, and for sure there are bugs in it that I didn't notice, so I will be very grateful if you write about errors, I will try to fix them from time to time.
