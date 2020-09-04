#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY
ConVar ClearTime, Clear_UpradeGroundPack_Time;
float fItemDeleteTime[2048];
int iRoundStart;
bool L4D2Version;

static char upgradegroundpack[][] =
{
	"models/props/terror/incendiary_ammo.mdl",
	"models/props/terror/exploding_ammo.mdl"
};

static char ItemDeleteList[][] =
{
	"weapon_smg_mp5",
	"weapon_smg",
	"weapon_smg_silenced",
	"weapon_shotgun_chrome",
	"weapon_pumpshotgun",
	"weapon_hunting_rifle",
	"weapon_pistol",
	"weapon_rifle_m60",
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
	"weapon_chainsaw",
	"weapon_upgradepack_incendiary",
	"weapon_upgradepack_explosive",
	//"weapon_gascan",
	"weapon_fireworkcrate",
	"weapon_propanetank",
	"weapon_oxygentank"
};

public Plugin myinfo = 
{
	name = "Remove drop weapon + remove upgradepack when used",
	author = "AK978, HarryPotter",
	version = "2.1"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	EngineVersion test = GetEngineVersion();
	
	if( test == Engine_Left4Dead )
	{
		L4D2Version = false;
	}
	else if( test == Engine_Left4Dead2 )
	{
		L4D2Version = true;
	}
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	
	return APLRes_Success; 
}

public void OnPluginStart()
{
	ClearTime = CreateConVar("sm_drop_clear_weapon_time", "30.0", "time in seconds  to remove weapon after drops.", CVAR_FLAGS, true, 0.0);
	Clear_UpradeGroundPack_Time = CreateConVar("sm_drop_clear_ground_upgrade_pack_time", "30.0", "time in seconds to remove upgradepack when used", CVAR_FLAGS, true, 0.0);
	
	HookEvent("weapon_drop", Event_Weapon_Drop);
	HookEvent("round_start", Event_Round_Start);
	HookEvent("round_end", Event_Round_End);
	
	if (L4D2Version){
		HookEvent ("upgrade_pack_used",	Event_UpgradePack);
	}
	
	AutoExecConfig(true, "clear_weapon_drop");
}

public Action Event_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	iRoundStart = 1;
}

public Action Event_Round_End(Event event, const char[] name, bool dontBroadcast)
{
	iRoundStart = 0;
}

public Action Event_Weapon_Drop(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client) || !IsPlayerAlive(client)) return Plugin_Stop;
		
	int entity = event.GetInt("propid");
	if (!IsValidEntity(entity) || !IsValidEdict(entity)) return Plugin_Stop;

	char item[32];
	GetEdictClassname(entity, item, sizeof(item));
	fItemDeleteTime[entity] = GetEngineTime();
	//PrintToChatAll("%d - %s",entity,item);

	Handle pack = new DataPack();
	for(int j=0; j < sizeof(ItemDeleteList); j++)
	{
		if (StrContains(item, ItemDeleteList[j], false) != -1)
		{
			CreateDataTimer(ClearTime.FloatValue, Timer_KillWeapon, pack,TIMER_FLAG_NO_MAPCHANGE);
			break;
		}
	}

	WritePackCell(pack, EntIndexToEntRef(entity));
	WritePackCell(pack, fItemDeleteTime[entity]);
	return Plugin_Stop;
}

public void Event_UpgradePack(Event event, const char[] name, bool dontBroadcast)
{
	int entity = event.GetInt("upgradeid");
	if (!IsValidEntity(entity) || !IsValidEdict(entity)) return;

	if(Is_UpgradeGroundPack(entity, upgradegroundpack, sizeof(upgradegroundpack)))
		CreateTimer(Clear_UpradeGroundPack_Time.FloatValue, Timer_KillEntity, EntIndexToEntRef(entity),TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_KillWeapon(Handle timer, Handle pack)
{
	ResetPack(pack);
	int entity = ReadPackCell(pack);
	float fDeletetime = ReadPackCell(pack);
	if(entity && (entity = EntRefToEntIndex(entity)) != INVALID_ENT_REFERENCE)
	{
		if(iRoundStart == 1 && IsValidEntity(entity) && fItemDeleteTime[entity] == fDeletetime)
		{
			if ( IsInUse(entity) == false )
			{
				AcceptEntityInput(entity, "Kill");
			}
		}
	}
}

public Action Timer_KillEntity(Handle timer, int ref)
{
	if(ref && EntRefToEntIndex(ref) != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(ref, "kill"); //remove dead boddy entity
	}
	return Plugin_Continue;
}

bool IsInUse(int entity)
{	
	int client;
	if(HasEntProp(entity, Prop_Data, "m_hOwner"))
	{
		client = GetEntPropEnt(entity, Prop_Data, "m_hOwner");
		if (IsValidClient(client))
			return true;
	}
	
	if(HasEntProp(entity, Prop_Data, "m_hOwnerEntity"))
	{
		client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
		if (IsValidClient(client))
			return true;
	}

	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i) && GetActiveWeapon(i) == entity)
			return true;
	}

	return false;
}

stock int GetActiveWeapon(int client)
{
	int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if (!IsValidEntity(weapon)) 
	{
		return false;
	}
	
	return weapon;
}

stock bool IsValidClient(int client) 
{
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) return false;      
    return true; 
}

bool Is_UpgradeGroundPack(int entity, char [][] array, int size)
{
	char sModelName[256];
	GetEntPropString(entity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

	for (int i = 0; i < size; i++)
	{
		if (StrEqual(sModelName, array[i]))
		{
			return true;
		}
	}

	return false;
}