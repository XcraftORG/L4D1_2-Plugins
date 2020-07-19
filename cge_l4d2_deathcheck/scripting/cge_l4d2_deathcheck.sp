#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod> 
#include <sdktools>

public Plugin myinfo = { 
    name = "[L4D, L4D2] No Death Check Until Dead", 
    author = "chinagreenelvis, Harry", 
    description = "Prevents mission loss until all players have died.", 
    version = "1.6", 
    url = "https://forums.alliedmods.net/showthread.php?t=142432" 
}; 

ConVar deathcheck = null;
ConVar deathcheck_bots = null;

ConVar director_no_death_check = null;
ConVar allow_all_bot_survivor_team = null;

int director_no_death_check_default_cvar = 0;
int allow_all_bot_survivor_team_default_cvar = 0;

bool Enabled = false;
int g_iPlayerSpawn, g_iRoundStart;

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
	HookEvent("player_bot_replace", Event_PlayerBotReplace); 
	HookEvent("bot_player_replace", Event_BotPlayerReplace); 
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_death", Event_PlayerDeath);

	ResetPlugin();
}

public void OnPluginEnd()
{
	ResetPlugin();
}

public void OnConfigsExecuted()
{
	director_no_death_check_default_cvar = director_no_death_check.IntValue;
	allow_all_bot_survivor_team_default_cvar = allow_all_bot_survivor_team.IntValue;
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
				allow_all_bot_survivor_team.SetInt(allow_all_bot_survivor_team_default_cvar);
			}
		}
        else
		{
			//PrintToChatAll("Resetting director_no_death_check and allow_all_bot_survivor_team to default values.");
			director_no_death_check.SetInt(director_no_death_check_default_cvar);
			allow_all_bot_survivor_team.SetInt(allow_all_bot_survivor_team_default_cvar);
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
				SetConVarInt(allow_all_bot_survivor_team, 1);
			}
			else
			{
				//PrintToChatAll("Resetting allow_all_bot_survivor_team to default value.");
				SetConVarInt(allow_all_bot_survivor_team, allow_all_bot_survivor_team_default_cvar);
			}
		}
	}
}

public void OnMapEnd()
{
	ResetPlugin();
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
		CreateTimer(3.0, tmrStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(3.0, tmrStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
} 

public Action tmrStart(Handle timer)
{
	ResetPlugin();
	if (Enabled == false)
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
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)  
{
	ResetPlugin();
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