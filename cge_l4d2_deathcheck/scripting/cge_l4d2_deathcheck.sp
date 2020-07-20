#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod> 
#include <sdktools>

public Plugin myinfo = { 
    name = "[L4D, L4D2] No Death Check Until Dead", 
    author = "chinagreenelvis, Harry", 
    description = "Prevents mission loss until all players have died.", 
    version = "1.7", 
    url = "https://forums.alliedmods.net/showthread.php?t=142432" 
}; 

ConVar deathcheck = null;
ConVar deathcheck_bots = null;

ConVar director_no_death_check = null;
ConVar allow_all_bot_survivor_team = null;

bool Enabled = false;
int g_iPlayerSpawn, g_iRoundStart;
Handle PlayerLeftStartTimer;

public void OnPluginStart()
{  
	deathcheck = CreateConVar("deathcheck", "1", "0: Disable plugin, 1: Enable plugin", FCVAR_NOTIFY);
	deathcheck_bots = CreateConVar("deathcheck_bots", "1", "0: Mission will be lost if all human players have died, 1: Bots will continue playing after all human players are dead and can rescue them", FCVAR_NOTIFY);
	
	director_no_death_check = FindConVar("director_no_death_check");
	allow_all_bot_survivor_team = FindConVar("allow_all_bot_survivor_team");

	AutoExecConfig(true, "cge_l4d2_deathcheck");
	
	deathcheck.AddChangeHook(ConVarChange_deathcheck);
	deathcheck_bots.AddChangeHook(ConVarChange_deathcheck_bots);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd); //戰役過關到下一關的時候 (沒有觸發round_end)
	HookEvent("mission_lost", Event_RoundEnd); //戰役滅團重來該關卡的時候 (之後有觸發round_end)
	HookEvent("finale_vehicle_leaving", Event_RoundEnd); //救援載具離開之時  (沒有觸發round_end)
	HookEvent("player_bot_replace", Event_PlayerBotReplace); 
	HookEvent("bot_player_replace", Event_BotPlayerReplace); 
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_death", Event_PlayerDeath);

	ResetPlugin();
}

public void OnPluginEnd()
{
	ResetPlugin();
	ResetTimer();
	ResetConVar(director_no_death_check, true, true);
	ResetConVar(allow_all_bot_survivor_team, true, true);
}

public void ConVarChange_deathcheck(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (strcmp(oldValue, newValue) != 0)
    {
        if (strcmp(newValue, "1") == 0)
        {
			//PrintToChatAll("Setting director_no_death_check to 1.");
			director_no_death_check.SetInt(1);
			if (deathcheck_bots.BoolValue)
			{
				//PrintToChatAll("Setting allow_all_bot_survivor_team to 1.");
				allow_all_bot_survivor_team.SetInt(1);
			}
			else
			{
				//PrintToChatAll("Resetting allow_all_bot_survivor_team to default value.");
				ResetConVar(allow_all_bot_survivor_team, true, true);
			}
		}
        else
		{
			ResetConVar(director_no_death_check, true, true);
			ResetConVar(allow_all_bot_survivor_team, true, true);
			//PrintToChatAll("Resetting director_no_death_check and allow_all_bot_survivor_team to default values.");
		}
    }
}

public void ConVarChange_deathcheck_bots(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (deathcheck.BoolValue)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{
				//PrintToChatAll("Setting allow_all_bot_survivor_team to 1.");
				allow_all_bot_survivor_team.SetInt(1);
			}
			else
			{
				//PrintToChatAll("Resetting allow_all_bot_survivor_team to default value.");
				ResetConVar(allow_all_bot_survivor_team, true, true);
			}
		}
	}
}

public void OnMapEnd()
{
	ResetPlugin();
	ResetTimer();
}

public void OnClientDisconnect()
{ 
	DeathCheck();
}

public void OnClientDisconnect_Post()
{
	DeathCheck();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(0.5, tmrStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(0.5, tmrStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
} 

public Action tmrStart(Handle timer)
{
	director_no_death_check.SetInt(0);
	ResetPlugin();
	if(PlayerLeftStartTimer == null) PlayerLeftStartTimer = CreateTimer(1.0, PlayerLeftStart, _, TIMER_REPEAT);
}
public Action PlayerLeftStart(Handle Timer)
{
	if (LeftStartArea() || Enabled)
	{	
		if (deathcheck.BoolValue)
		{
			director_no_death_check.SetInt(1);
			if (deathcheck_bots.BoolValue)
			{
				allow_all_bot_survivor_team.SetInt(1);
			}
		}
		Enabled = true;
		PlayerLeftStartTimer = null;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)  
{
	ResetPlugin();
	ResetTimer();
}

public void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{  
	DeathCheck();
}  

public void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{  
	DeathCheck();
}  

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{  
	DeathCheck();
}  

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	DeathCheck();
}

void DeathCheck()
{
	if (Enabled == true)
	{
		CreateTimer(3.0, Timer_DeathCheck);
	}
}

public Action Timer_DeathCheck(Handle timer)
{
	if (deathcheck.BoolValue)
	{
		int survivors = 0;
		for (int i = 1; i <= MaxClients; i++) 
		{
			if (IsValidSurvivor(i))
			{
				survivors ++;
			}
		}
		
		//PrintToChatAll("%i survivors remaining.", survivors);
		
		if (survivors < 1)
		{
			//PrintToChatAll("Everyone is dead. Ending the round.");
			int oldFlags = GetCommandFlags("scenario_end");
			SetCommandFlags("scenario_end", oldFlags & ~(FCVAR_CHEAT|FCVAR_DEVELOPMENTONLY));
			ServerCommand("scenario_end");
			ServerExecute();
			SetCommandFlags("scenario_end", oldFlags);
		}
	}
}

stock bool IsValidSurvivor(int client)
{
	if (!client) return false;
	if (!IsClientInGame(client)) return false;
	if (!deathcheck_bots.BoolValue)
	{
		if (IsFakeClient(client)) return false;
	}
	if (!IsPlayerAlive(client)) return false;
	if (GetClientTeam(client) != 2) return false;
	return true;
}

void ResetPlugin()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	Enabled = false;
}

void ResetTimer()
{
	if(PlayerLeftStartTimer != null)
	{
		KillTimer(PlayerLeftStartTimer);
		PlayerLeftStartTimer = null;	
	}
}

bool LeftStartArea()
{
	int ent = -1, maxents = GetMaxEntities();
	for (int i = MaxClients+1; i <= maxents; i++)
	{
		if (IsValidEntity(i))
		{
			char netclass[64];
			GetEntityNetClass(i, netclass, sizeof(netclass));
			
			if (StrEqual(netclass, "CTerrorPlayerResource"))
			{
				ent = i;
				break;
			}
		}
	}
	
	if (ent > -1)
	{
		if (GetEntProp(ent, Prop_Send, "m_hasAnySurvivorLeftSafeArea"))
		{
			return true;
		}
	}
	return false;
}