/************************************************
* Plugin name:		[L4D(2)] MultiSlots
* Plugin author:	SwiftReal, Harry Potter
* 
* Based upon:
* - (L4D) Zombie Havoc by Bigbuck
* - (L4D2) Bebop by frool
************************************************/

#include <sourcemod>
#include <sdktools>
#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法

#define PLUGIN_VERSION 				"1.7"
#define CVAR_FLAGS					FCVAR_NOTIFY
#define DELAY_KICK_FAKECLIENT 		0.1
#define DELAY_KICK_NONEEDBOT 		5.0
#define DELAY_CHANGETEAM_NEWPLAYER 	1.5
#define TEAM_SPECTATORS 			1
#define TEAM_SURVIVORS 				2
#define TEAM_INFECTED				3
#define DAMAGE_EVENTS_ONLY			1
#define	DAMAGE_YES					2

ConVar hMaxSurvivors;
ConVar hTime;
int iMaxSurvivors,iTime;
Handle timer_SpecCheck = INVALID_HANDLE;
bool gbVehicleLeaving;
bool gbPlayedAsSurvivorBefore[MAXPLAYERS+1];
bool gbFirstItemPickedUp;
bool gbPlayerPickedUpFirstItem[MAXPLAYERS+1];
char gMapName[128];
int giIdleTicks[MAXPLAYERS+1];
static Handle hSetHumanSpec;
int g_iRoundStart,g_iPlayerSpawn ;
bool bKill;

public Plugin myinfo = 
{
	name 			= "[L4D(2)] MultiSlots",
	author 			= "SwiftReal, MI 5, HarryPotter",
	description 	= "Allows additional survivor players in coop, versus, and survival",
	version 		= PLUGIN_VERSION,
	url 			= "https://steamcommunity.com/id/TIGER_x_DRAGON/"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	// This plugin will only work on L4D 1/2
	char GameName[64];
	GetGameFolderName(GameName, sizeof(GameName));
	if (StrContains(GameName, "left4dead", false) == -1)
		return APLRes_Failure; 
	
	return APLRes_Success; 
}

public void OnPluginStart()
{
	// Create plugin version cvar and set it
	CreateConVar("l4d_multislots_version", PLUGIN_VERSION, "L4D(2) MultiSlots version", CVAR_FLAGS|FCVAR_SPONLY|FCVAR_REPLICATED);
	SetConVarString(FindConVar("l4d_multislots_version"), PLUGIN_VERSION);
	
	// Register commands
	RegAdminCmd("sm_muladdbot", AddBot, ADMFLAG_KICK, "Attempt to add a survivor bot");
	RegConsoleCmd("sm_join", JoinTeam, "Attempt to join Survivors");
	
	// Register cvars
	hMaxSurvivors	= CreateConVar("l4d_multislots_max_survivors", "4", "Kick Fake Survivor bots if numbers of survivors reach the certain value (does not kick real player)", CVAR_FLAGS, true, 4.0, true, 32.0);
	hTime = CreateConVar("l4d_multislots_time", "100", "Spawn a dead survivor bot after a certain time round starts [0: Disable]", CVAR_FLAGS, true, 0.0);
	
	GetCvars();
	hMaxSurvivors.AddChangeHook(ConVarChanged_Cvars);
	hTime.AddChangeHook(ConVarChanged_Cvars);
	
	// Hook events

	HookEvent("item_pickup", evtRoundStartAndItemPickup);
	HookEvent("player_left_start_area", evtPlayerLeftStart);
	HookEvent("survivor_rescued", evtSurvivorRescued);
	HookEvent("finale_vehicle_leaving", evtFinaleVehicleLeaving);
	HookEvent("mission_lost", evtMissionLost);
	HookEvent("player_activate", evtPlayerActivate);
	HookEvent("bot_player_replace", evtPlayerReplacedBot);
	HookEvent("player_bot_replace", evtBotReplacedPlayer);
	HookEvent("player_team", evtPlayerTeam);
	HookEvent("player_spawn", evtPlayerSpawn);
	HookEvent("player_death", evtPlayerDeath);
	HookEvent("round_start", 		Event_RoundStart);
	HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);
	
	// Create or execute plugin configuration file
	AutoExecConfig(true, "l4dmultislots");

	// ======================================
	// Prep SDK Calls
	// ======================================

	Handle hGameConf;	
	hGameConf = LoadGameConfigFile("l4dmultislots");
	if(hGameConf == null)
	{
		SetFailState("Gamedata l4dmultislots.txt not found");
		return;
	}
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "SetHumanSpec");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	hSetHumanSpec = EndPrepSDKCall();
	
	if (hSetHumanSpec == null)
	{
		SetFailState("Cant initialize SetHumanSpec SDKCall");
		return;
	}

	
	delete hGameConf;
}

public void OnPluginEnd()
{
	ClearDefault();
}

public void OnMapStart()
{
	GetCurrentMap(gMapName, sizeof(gMapName));
	//FindLocationStart()
	TweakSettings();
	gbFirstItemPickedUp = false;
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	iMaxSurvivors = hMaxSurvivors.IntValue;
	iTime = hTime.IntValue;
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	if(client)
	{
		gbPlayedAsSurvivorBefore[client] = false;
		gbPlayerPickedUpFirstItem[client] = false;
		giIdleTicks[client] = 0;
	}
	
	return true;
}

public void OnClientDisconnect(int client)
{
	gbPlayedAsSurvivorBefore[client] = false;
	gbPlayerPickedUpFirstItem[client] = false;
}

public void OnMapEnd()
{
	StopTimers();
	gbVehicleLeaving = false;
	gbFirstItemPickedUp = false;
	ClearDefault();
}

////////////////////////////////////
// Callbacks
////////////////////////////////////
public Action AddBot(int client, int args)
{
	if(client == 0)
		return Plugin_Continue;
	
	if(SpawnFakeClient())
		PrintToChat(client,"已召喚一個倖存者Bot.");
	
	return Plugin_Handled;
}

public Action JoinTeam(int client,int args)
{
	if(!IsClientConnected(client) || !IsClientInGame(client) || GetClientTeam(client) == 3)
		return Plugin_Handled;
	

	if(GetClientTeam(client) == TEAM_SURVIVORS)
	{	
		if(DispatchKeyValue(client, "classname", "player") == true)
		{
			PrintHintText(client, "You are allready joined the Survivor team, dumb fuck");
		}
		else if((DispatchKeyValue(client, "classname", "info_survivor_position") == true) && !IsAlive(client))
		{
			PrintHintText(client, "請等待救援或復活.");
		}
	}
	else if(IsClientIdle(client))
	{
		PrintHintText(client, "你正在閒置. 請按滑鼠加入倖存者");
	}
	else
	{			
		if(TotalAliveFreeBots() == 0)
		{
			if(bKill) 
			{
				ChangeClientTeam(client, TEAM_SURVIVORS);
				CreateTimer(0.1, Timer_KillSurvivor, client);
			}
			else 
			{
				SpawnFakeClient();
				CreateTimer(1.0, Timer_AutoJoinTeam, client, TIMER_REPEAT)	;			
			}
		}
		else
			TakeOverBot(client);
	}
	return Plugin_Handled;
}
////////////////////////////////////
// Events
////////////////////////////////////
public void evtRoundStartAndItemPickup(Event event, const char[] name, bool dontBroadcast) 
{
	if(!gbFirstItemPickedUp)
	{
		// alternative to round start...
		if(timer_SpecCheck == INVALID_HANDLE)
			timer_SpecCheck = CreateTimer(15.0, Timer_SpecCheck, _, TIMER_REPEAT)	;
		
		gbFirstItemPickedUp = true;
	}
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!gbPlayerPickedUpFirstItem[client] && !IsFakeClient(client))
	{
		// force setting client cvars here...
		//ForceClientCvars(client)
		gbPlayerPickedUpFirstItem[client] = true;
		gbPlayedAsSurvivorBefore[client] = true;
	}
}

public void evtPlayerActivate(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client)
	{
		if((GetClientTeam(client) != TEAM_INFECTED) && (GetClientTeam(client) != TEAM_SURVIVORS) && !IsFakeClient(client) && !IsClientIdle(client))
			CreateTimer(DELAY_CHANGETEAM_NEWPLAYER, Timer_AutoJoinTeam, client, TIMER_REPEAT);
	}
}
public void evtPlayerLeftStart(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client)
	{
		if(IsClientConnected(client) && IsClientInGame(client))
		{
			if(GetClientTeam(client)==TEAM_SURVIVORS)
				gbPlayedAsSurvivorBefore[client] = true;
		}
	}
}

public void evtPlayerTeam(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int newteam = GetEventInt(event, "team");
	
	if(client)
	{
		if(!IsClientConnected(client))
			return;
		if(!IsClientInGame(client) || IsFakeClient(client) || !IsAlive(client))
			return;
		
		if(newteam == TEAM_INFECTED)
		{
			char PlayerName[100];
			GetClientName(client, PlayerName, sizeof(PlayerName));
			//PrintToChatAll("\x01[\x04MultiSlots\x01] %s joined the Infected Team", PlayerName);
			giIdleTicks[client] = 0;
		}
	}
}

public void evtPlayerReplacedBot(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "player"));
	if(!client) return;
	if(GetClientTeam(client)!=TEAM_SURVIVORS || IsFakeClient(client)) return;
	
	if(!gbPlayedAsSurvivorBefore[client])
	{
		//ForceClientCvars(client)
		gbPlayedAsSurvivorBefore[client] = true;
		giIdleTicks[client] = 0;
		
		BypassAndExecuteCommand(client, "give", "health");
		
		char GameMode[30];
		GetConVarString(FindConVar("mp_gamemode"), GameMode, sizeof(GameMode))		;	
		if(StrEqual(GameMode, "mutation3", false))
		{
			SetEntityHealth(client, 1);
			SetEntityTempHealth(client, 99);
		}
		else
		{
			SetEntityHealth(client, 100);
			SetEntityTempHealth(client, 0);		
			GiveMedkit(client);
		}
		
		char PlayerName[100];
		GetClientName(client, PlayerName, sizeof(PlayerName));
		//PrintToChatAll("\x01[\x04MultiSlots\x01] %s joined the Survivor Team", PlayerName);
	}
}

public void evtSurvivorRescued(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "victim"));
	if(client)
	{	
		StripWeapons(client);
		//BypassAndExecuteCommand(client, "give", "pistol_magnum");
		if(StrContains(gMapName, "c1m1_hotel", false) == -1)
			GiveWeapon(client);
	}
}

public void evtFinaleVehicleLeaving(Event event, const char[] name, bool dontBroadcast) 
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			if((GetClientTeam(i) == TEAM_SURVIVORS) && IsAlive(i))
			{
				SetEntProp(i, Prop_Data, "m_takedamage", DAMAGE_EVENTS_ONLY, 1);
				float newOrigin[3] = { 0.0, 0.0, 0.0 };
				TeleportEntity(i, newOrigin, NULL_VECTOR, NULL_VECTOR);
				SetEntProp(i, Prop_Data, "m_takedamage", DAMAGE_YES, 1);
			}
		}
	}	
	StopTimers();
	gbVehicleLeaving = true;
}

public void evtMissionLost(Event event, const char[] name, bool dontBroadcast) 
{
	gbFirstItemPickedUp = false;
}

public void evtBotReplacedPlayer(Event event, const char[] name, bool dontBroadcast) 
{
	int fakebot = GetClientOfUserId(GetEventInt(event, "bot"));
	if(fakebot && GetClientTeam(fakebot) == TEAM_SURVIVORS && IsFakeClient(fakebot))
		CreateTimer(DELAY_KICK_NONEEDBOT, Timer_KickNoNeededBot, fakebot);
}

public void evtPlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client && GetClientTeam(client) == TEAM_SURVIVORS && IsFakeClient(client))
		CreateTimer(DELAY_KICK_NONEEDBOT, Timer_KickNoNeededBot, client);	

	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(0.5, PluginStart);
	g_iPlayerSpawn = 1;	
}

public void evtPlayerDeath(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client && GetClientTeam(client) == TEAM_SURVIVORS && IsFakeClient(client))
		CreateTimer(DELAY_KICK_NONEEDBOT, Timer_KickNoNeededBot, client);	
}

void ClearDefault()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	bKill = false;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ClearDefault();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(0.5, PluginStart);
	g_iRoundStart = 1;
}

////////////////////////////////////
// timers
////////////////////////////////////

int iCountDownTime;
public Action PluginStart(Handle timer)
{
	iCountDownTime = iTime;
	if(iCountDownTime > 0) CreateTimer(1.0, CountDown,_,TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action CountDown(Handle timer)
{
	if(iCountDownTime <= 0) 
	{
		bKill = true;
		return Plugin_Stop;
	}
	iCountDownTime--;
	return Plugin_Continue;
}

public Action Timer_SpecCheck(Handle timer)
{
	if(gbVehicleLeaving) return Plugin_Stop;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			if((GetClientTeam(i) == TEAM_SPECTATORS) && !IsFakeClient(i))
			{
				if(!IsClientIdle(i))
				{
					char PlayerName[100];
					GetClientName(i, PlayerName, sizeof(PlayerName))		;
					PrintToChat(i, "\x01[\x04MultiSlots\x01] %s, 聊天視窗輸入 \x03!join\x01 來加入倖存者隊伍", PlayerName);
				}
			}
		}
	}	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))		
		{
			if((GetClientTeam(i) == TEAM_SURVIVORS) && !IsFakeClient(i) && !IsAlive(i))
			{
				char PlayerName[100];
				GetClientName(i, PlayerName, sizeof(PlayerName));
				PrintToChat(i, "\x01[\x04MultiSlots\x01] %s, 請等待救援或復活", PlayerName);
			}
		}
	}	
	return Plugin_Continue;
}

public Action Timer_KillSurvivor(Handle timer, int client)
{
	if(client && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
	{
		ForcePlayerSuicide(client);
	}
}

public Action Timer_AutoJoinTeam(Handle timer, int client)
{
	if(!IsClientConnected(client))
		return Plugin_Stop;
	
	if(IsClientInGame(client))
	{
		if(GetClientTeam(client) == TEAM_SURVIVORS)
			return Plugin_Stop;
		if(IsClientIdle(client))
			return Plugin_Stop;
		
		JoinTeam(client, 0);
	}
	return Plugin_Continue;
}

public Action Timer_KickNoNeededBot(Handle timer, int bot)
{
	//PrintToChatAll("TotalSurvivors(): %d , iMaxSurvivors: %d",TotalSurvivors(),iMaxSurvivors);

	if((TotalSurvivors() <= iMaxSurvivors))
		return Plugin_Handled;
	
	if(IsClientConnected(bot) && IsClientInGame(bot) && IsFakeClient(bot))
	{
		if(GetClientTeam(bot) != TEAM_SURVIVORS)
			return Plugin_Handled;
		
		char BotName[100];
		GetClientName(bot, BotName, sizeof(BotName))	;			
		if(StrEqual(BotName, "FakeClient", true))
			return Plugin_Handled;
		
		if(!HasIdlePlayer(bot))
		{
			StripWeapons(bot);
			KickClient(bot, "Kicking No Needed Bot");
		}
	}	
	return Plugin_Handled;
}

public Action Timer_KickFakeBot(Handle timer, int fakeclient)
{
	if(IsClientConnected(fakeclient))
	{
		KickClient(fakeclient, "Kicking FakeClient")	;	
		return Plugin_Stop;
	}	
	return Plugin_Continue;
}
////////////////////////////////////
// stocks
////////////////////////////////////
stock void TweakSettings()
{
	Handle hMaxSurvivorsLimitCvar = FindConVar("survivor_limit");
	SetConVarBounds(hMaxSurvivorsLimitCvar,  ConVarBound_Lower, true, 4.0);
	SetConVarBounds(hMaxSurvivorsLimitCvar, ConVarBound_Upper, true, 32.0);
	SetConVarInt(hMaxSurvivorsLimitCvar, iMaxSurvivors);
	
	SetConVarInt(FindConVar("z_spawn_flow_limit"), 50000) ;// allow spawning bots at any time
}

stock void TakeOverBot(int client)
{
	if (!IsClientInGame(client)) return;
	if (GetClientTeam(client) == TEAM_SURVIVORS) return;
	if (IsFakeClient(client)) return;

	int fakebot = FindBotToTakeOver(true);
	if (fakebot ==0)
	{
		fakebot = FindBotToTakeOver(false);
		PrintHintText(client, "沒有倖存者Bot能取代.");
		return;
	}

	if(IsPlayerAlive(fakebot))
	{
		SDKCall(hSetHumanSpec, fakebot, client);
		SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
	}

	return;
}

stock int FindBotToTakeOver(bool alive)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			if(IsClientInGame(i))
			{
				if (IsFakeClient(i) && GetClientTeam(i)==TEAM_SURVIVORS && !HasIdlePlayer(i) && IsPlayerAlive(i) == alive)
					return i;
			}
		}
	}
	return 0;
}


stock void SetEntityTempHealth(int client, int hp)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	float newOverheal = hp * 1.0; // prevent tag mismatch
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", newOverheal);
}

stock void BypassAndExecuteCommand(int client, char[] strCommand, char[] strParam1)
{
	int flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}

stock void StripWeapons(int client) // strip all items from client
{
	int itemIdx;
	for (int x = 0; x <= 3; x++)
	{
		if((itemIdx = GetPlayerWeaponSlot(client, x)) != -1)
		{  
			RemovePlayerItem(client, itemIdx);
			AcceptEntityInput(itemIdx, "Kill");
		}
	}
}

stock void GiveWeapon(int client) // give client random weapon
{
	switch(GetRandomInt(0,3))
	{
		case 0: BypassAndExecuteCommand(client, "give", "smg");
		case 1: BypassAndExecuteCommand(client, "give", "smg_silenced");
		case 2: BypassAndExecuteCommand(client, "give", "shotgun_chrome");
		case 3: BypassAndExecuteCommand(client, "give", "pumpshotgun");
	}	
	BypassAndExecuteCommand(client, "give", "ammo");
}

stock void GiveMedkit(int client)
{
	int ent = GetPlayerWeaponSlot(client, 3);
	if(IsValidEdict(ent))
	{
		char sClass[128];
		GetEdictClassname(ent, sClass, sizeof(sClass));
		if(!StrEqual(sClass, "weapon_first_aid_kit", false))
		{
			RemovePlayerItem(client, ent);
			AcceptEntityInput(ent, "Kill");
			BypassAndExecuteCommand(client, "give", "first_aid_kit");
		}
	}
	else
	{
		BypassAndExecuteCommand(client, "give", "first_aid_kit");
	}
}

stock int TotalSurvivors() // total bots, including players
{
	int kk = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			if(IsClientInGame(i) && (GetClientTeam(i) == TEAM_SURVIVORS))
				kk++;
		}
	}
	return kk;
}

stock int HumanConnected()
{
	int kk = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(bot))
		{
			if(!IsFakeClient(i))
				kk++;
		}
	}
	return kk;
}

stock int TotalAliveFreeBots() // total bots (excl. IDLE players)
{
	int kk = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			if(IsFakeClient(i) && GetClientTeam(i)==TEAM_SURVIVORS && IsAlive(i))
			{
				if(!HasIdlePlayer(i))
					kk++;
			}
		}
	}
	return kk;
}

stock void StopTimers()
{
	if(timer_SpecCheck != INVALID_HANDLE)
	{
		KillTimer(timer_SpecCheck);
		timer_SpecCheck = INVALID_HANDLE;
	}	
}
////////////////////////////////////
// bools
////////////////////////////////////
bool SpawnFakeClient()
{
	bool fakeclientKicked = false;
	
	// create fakeclient
	int fakeclient = CreateFakeClient("FakeClient");
	
	// if entity is valid
	if(fakeclient != 0)
	{
		// move into survivor team
		ChangeClientTeam(fakeclient, TEAM_SURVIVORS);
		
		// check if entity classname is survivorbot
		if(DispatchKeyValue(fakeclient, "classname", "survivorbot") == true)
		{
			// spawn the client
			if(DispatchSpawn(fakeclient) == true)
			{
				// teleport client to the position of any active alive player
				for (int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && (GetClientTeam(i) == TEAM_SURVIVORS) && IsAlive(i) && i != fakeclient)
					{						
						// get the position coordinates of any active alive player
						float teleportOrigin[3];
						GetClientAbsOrigin(i, teleportOrigin)	;			
						TeleportEntity(fakeclient, teleportOrigin, NULL_VECTOR, NULL_VECTOR);						
						break;
					}
				}
				
				StripWeapons(fakeclient);
				//BypassAndExecuteCommand(fakeclient, "give", "pistol_magnum");
				if(StrContains(gMapName, "c1m1_hotel", false) == -1)
					GiveWeapon(fakeclient);

				// kick the fake client to make the bot take over
				CreateTimer(DELAY_KICK_FAKECLIENT, Timer_KickFakeBot, fakeclient, TIMER_REPEAT);
				fakeclientKicked = true;
			}
		}	

		// if something went wrong, kick the created FakeClient
		if(fakeclientKicked == false)
			KickClient(fakeclient, "Kicking FakeClient");
	}	
	return fakeclientKicked;
}

bool HasIdlePlayer(int bot)
{
	if(IsClientConnected(bot) && IsClientInGame(bot) && IsFakeClient(bot) && GetClientTeam(bot) == 2 && IsAlive(bot))
	{
		if(HasEntProp(bot, Prop_Send, "m_humanSpectatorUserID"))
		{
			int client = GetClientOfUserId(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID"))	;		
			if(client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client) && IsClientObserver(client))
			{
				return true;
			}
		}
	}
	return false;
}

bool IsClientIdle(int client)
{
	if(GetClientTeam(client) != 1)
		return false;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsAlive(i))
		{
			if(HasEntProp(i, Prop_Send, "m_humanSpectatorUserID"))
			{
				if(GetClientOfUserId(GetEntProp(i, Prop_Send, "m_humanSpectatorUserID")) == client)
						return true;
			}
		}
	}
	return false;
}

bool IsAlive(int client)
{
	if(!GetEntProp(client, Prop_Send, "m_lifeState"))
		return true;
	
	return false;
}