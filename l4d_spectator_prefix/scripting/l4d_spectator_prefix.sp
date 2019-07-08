#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define TEAM_SPECTATOR 1


new String:g_sPrefixType[32];
new Handle:g_hPrefixType;

public Plugin:myinfo = 
{
	name = "Spectator Prefix",
	author = "Nana & Harry Potter",
	description = "when player in spec team, add prefix",
	version = "1.1",
	url = "https://steamcommunity.com/id/fbef0102/"
};

public OnPluginStart()
{
	g_hPrefixType = CreateConVar("sp_prefix_type", "(Spec)", "Determine your preferred type of Spectator Prefix");
	GetConVarString(g_hPrefixType, g_sPrefixType, sizeof(g_sPrefixType));
	HookConVarChange(g_hPrefixType, ConVarChange_PrefixType);
	
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_PostNoCopy);
	HookEvent("player_changename", Event_NameChanged);
}

public ConVarChange_PrefixType(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarString(g_hPrefixType, g_sPrefixType, sizeof(g_sPrefixType));
}

public Action:Event_NameChanged(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(1.0,PlayerNameCheck,client,TIMER_FLAG_NO_MAPCHANGE);//延遲一秒檢查

	return Plugin_Continue;
}

public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(1.0,PlayerNameCheck,client,TIMER_FLAG_NO_MAPCHANGE);//延遲一秒檢查

	return Plugin_Continue;
}

public Action:PlayerNameCheck(Handle:timer,any:client)
{
	if(!IsClientInGame(client) || IsFakeClient(client)) return Plugin_Continue;
	
	new team = GetClientTeam(client);
	
	//PrintToChatAll("client: %N - %d",client,team);
	if (IsClientAndInGame(client) && !IsFakeClient(client))
	{
		new String:sOldname[256],String:sNewname[256];
		GetClientName(client, sOldname, sizeof(sOldname));
		if (team == TEAM_SPECTATOR)
		{
			if(!CheckClientHasPreFix(sOldname))
			{
				Format(sNewname, sizeof(sNewname), "%s%s", g_sPrefixType, sOldname);
				SetClientName(client, sNewname);
				
				//PrintToChatAll("sNewname: %s",sNewname);
			}
		}
		else
		{
			if(CheckClientHasPreFix(sOldname))
			{
				ReplaceString(sOldname, sizeof(sOldname), g_sPrefixType, "", true);
				strcopy(sNewname,sizeof(sOldname),sOldname);
				SetClientName(client, sNewname);
				
				//PrintToChatAll("sNewname: %s",sNewname);
			}
		}
	}
	
	return Plugin_Continue;
}

stock bool:IsClientAndInGame(index)
{
	if (index > 0 && index < MaxClients)
	{
		return IsClientInGame(index);
	}
	return false;
}

bool:CheckClientHasPreFix(const String:sOldname[])
{
	for(new i =0 ; i< strlen(g_sPrefixType); ++i)
	{
		if(sOldname[i] == g_sPrefixType[i])
		{
			//PrintToChatAll("%d-%c",i,g_sPrefixType[i]);
			continue;
		}
		else
			return false;
	}
	return true;
}

