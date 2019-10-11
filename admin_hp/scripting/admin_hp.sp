#include <sourcemod>
#include <adminmenu>
#include <sdktools>
#define PLUGIN_VERSION    "2.4"

enum
{
	L4D_TEAM_SPECTATE = 1,
	L4D_TEAM_SURVIVOR = 2,
	L4D_TEAM_INFECTED = 3,
}

public Plugin:myinfo =
{
	name = "Adm Give full health",
	author = "Harry Potter",
	description = "Adm type !givehp to set survivor team full health",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/AkemiHomuraGoddess/"
}

public OnPluginStart(){
	RegAdminCmd("sm_hp", restore_hp, ADMFLAG_ROOT, "Restore all survivors full hp");
	RegAdminCmd("sm_givehp", restore_hp, ADMFLAG_ROOT, "Restore all survivors full hp");
}

public Action:restore_hp(client, args){
	if (client == 0)
	{
		PrintToServer("[TS] \"Restore_hp\" cannot be used by server.");
		return Plugin_Handled;
	}
	
	for( new i = 1; i < GetMaxClients(); i++ ) {
		if (IsClientInGame(i) && IsClientConnected(i) && GetClientTeam(i)==L4D_TEAM_SURVIVOR )
			SetEntityHealth(i, GetEntProp(i, Prop_Data, "m_iMaxHealth"));
	}
	
	PrintToChatAll("\x01[\x05TS\x01] Adm \x03%N \x01restores \x05all survivors \x04FULL HP", client);
	LogMessage("[TS] Adm %N restores all survivors FULL HP", client);
	
	return Plugin_Handled;
}
