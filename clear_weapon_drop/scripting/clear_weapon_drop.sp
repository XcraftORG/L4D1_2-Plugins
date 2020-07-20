#include <sourcemod>
#include <sdktools>

new Handle:ClearTime = INVALID_HANDLE;
new Handle:g_timer = INVALID_HANDLE;
Address address[2048];
new aaa;

new const String:ItemDeleteList[][] =
{
	"weapon_smg_mp5",
	"weapon_smg",
	"weapon_smg_silenced",
	"weapon_shotgun_chrome",
	"weapon_pumpshotgun",
	"weapon_hunting_rifle",
	"weapon_pistol",
	//"weapon_rifle_m60",
	//"weapon_first_aid_kit",
	"weapon_autoshotgun",
	"weapon_shotgun_spas",
	"weapon_sniper_military",
	"weapon_rifle",
	"weapon_rifle_ak47",
	"weapon_rifle_desert",
	"weapon_sniper_awp",
	"weapon_rifle_sg552",
	"weapon_sniper_scout",
	"weapon_grenade_launcher",
	"weapon_pistol_magnum",
	"weapon_molotov",
	"weapon_pipe_bomb",
	"weapon_vomitjar",
	"weapon_defibrillator",
	"weapon_pain_pills",
	"weapon_adrenaline",
	"weapon_melee",
	"weapon_upgradepack_incendiary",
	"weapon_upgradepack_explosive",
	//"weapon_gascan",
	"weapon_fireworkcrate",
	"weapon_propanetank",
	"weapon_oxygentank"
};

public Plugin:myinfo = 
{
	name = "[l4d2]remove drop weapon",
	author = "AK978",
	version = "1.7"
}

public OnPluginStart()
{
	ClearTime = CreateConVar("sm_drop_clear_time", "30.0", "clear time", 0);
	
	HookEvent("weapon_drop", Event_Weapon_Drop);
	HookEvent("round_start", Event_Round_Start);
	HookEvent("round_end", Event_Round_End);
	
	AutoExecConfig(true, "clear_weapon_drop");
}

public OnMapEnd()
{
	if (g_timer != INVALID_HANDLE)
	{
		KillTimer(g_timer);
		g_timer = INVALID_HANDLE;
	}
}

public Action:Event_Round_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	aaa = 1;
}

public Action:Event_Round_End(Handle:event, const String:name[], bool:dontBroadcast)
{
	aaa = 0;
}

public Action:Event_Weapon_Drop(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	if (!IsValidClient(client) || !IsPlayerAlive(client)) return Plugin_Stop;
		
	new entity = GetEventInt(event, "propid");
	address[entity] = GetEntityAddress(entity);
	
	new String:item[32];
	
	if (!IsValidEntity(entity) || !IsValidEdict(entity)) return Plugin_Stop;
	
	GetEdictClassname(entity, item, sizeof(item));
	//PrintToChatAll("掉落物品: %s",item);
	
	for(new j=0; j < sizeof(ItemDeleteList); j++)
	{
		if (StrContains(item, ItemDeleteList[j], false) != -1)
		{
			g_timer = CreateTimer(GetConVarFloat(ClearTime), del_weapon, entity);
		}
	}
	return Plugin_Stop;
}

public Action:del_weapon(Handle:timer, any:entity)
{
	if (IsValidEntity(entity) && aaa == 1)
	{
		if (address[entity] == GetEntityAddress(entity))
		{
			for(new j=0; j < sizeof(ItemDeleteList); j++)
			{
				new String:item[32];
				GetEdictClassname(entity, item, sizeof(item));
				
				if (StrContains(item, ItemDeleteList[j], false) != -1)
				{
					if(!IsWeaponInUse(entity))
					{
						AcceptEntityInput(entity, "Kill");
						address[entity] = Address_Null;
					}
				}
			}
		}
	}
	g_timer = INVALID_HANDLE;
}

bool:IsWeaponInUse(entity)
{	
	new client = GetEntPropEnt(entity, Prop_Data, "m_hOwner");
	if (IsValidClient(client))
		return true;
	
	client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	if (IsValidClient(client))
		return true;

	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i) && GetActiveWeapon(i) == entity)
			return true;
	}
	
	return false;
}

stock GetActiveWeapon(client)
{
	new weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if (!IsValidEntity(weapon)) 
	{
		return false;
	}
	
	return weapon;
}

stock bool:IsValidClient(client) 
{
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) return false;      
    return true; 
}