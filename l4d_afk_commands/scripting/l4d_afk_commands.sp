/*version: 1.7*/
//本插件用來防止玩家換隊濫用的Bug
//禁止期間不能閒置 亦不可按M換隊
//1.嚇了Witch或被Witch抓倒 期間禁止換隊 (防止Witch失去目標)
//2.被特感抓住期間 期間禁止換隊 (防止濫用特感控了無傷)
//3.人類玩家死亡 期間禁止換隊 (防止玩家故意死亡 然後跳隊裝B)
//4.換隊成功之後 必須等待數秒才能再換隊 (防止玩家頻繁換隊洗頻伺服器)

#define PLUGIN_VERSION    "1.7"
#define PLUGIN_NAME       "[L4D(2)] AFK and Join Team Commands"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>

static InCoolDownTime[MAXPLAYERS+1] = false;//是否還有換隊冷卻時間
static Float:CoolTime;
static Handle:cvarCoolTime					= INVALID_HANDLE;
static bool:bClientJoinedTeam[MAXPLAYERS+1] = false; //在冷卻時間是否嘗試加入
static Float:g_iSpectatePenaltyCounter[MAXPLAYERS+1] ;//各自的冷卻時間
static bool:clientBusy[MAXPLAYERS+1];//是否被特感控
static bool:b_IsL4D2;
#define ZOMBIECLASS_CHARGER	6
static ChargerGot[MAXPLAYERS+1];//Charger抓住的人
static WitchTarget[5000];//WitchTarget[妹子元素編號]=鎖定的玩家
static clientteam[MAXPLAYERS+1];//玩家換隊成功之後的隊伍
static Handle:cvarDeadChangeTeamEnable					= INVALID_HANDLE;
static DeadChangeTeamEnable;
new Handle:g_hGameMode;
new String:CvarGameMode[20];
static bool:LEFT_SAFE_ROOM;

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "MasterMe,modify by Harry",
	description = "Adds commands to let the player spectate and join team. (!afk, !survivors, !infected, etc.),but no change team abuse",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=122476"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) 
{
	// Checks to see if the game is a L4D game. If it is, check if its the sequel. L4DVersion is L4D if false, L4D2 if true.
	decl String:GameName[64];
	GetGameFolderName(GameName, sizeof(GameName));
	if (StrContains(GameName, "left4dead", false) == -1)
		return APLRes_Failure; 
	else if (StrEqual(GameName, "left4dead2", false))
		b_IsL4D2 = true;
	
	return APLRes_Success; 
}

public OnPluginStart()
{


	RegConsoleCmd("sm_afk", TurnClientToSpectate);
	RegConsoleCmd("sm_s", TurnClientToSpectate);
	RegConsoleCmd("sm_join", TurnClientToSurvivors);
	RegConsoleCmd("sm_bot", TurnClientToSurvivors);
	RegConsoleCmd("sm_jointeam", TurnClientToSurvivors)
	RegConsoleCmd("sm_away", TurnClientToSpectate);
	RegConsoleCmd("sm_idle", TurnClientToSpectate);
	RegConsoleCmd("sm_spectate", TurnClientToSpectate);
	RegConsoleCmd("sm_spec", TurnClientToSpectate);
	RegConsoleCmd("sm_spectators", TurnClientToSpectate);
	RegConsoleCmd("sm_joinspectators", TurnClientToSpectate);
	RegConsoleCmd("sm_jointeam1", TurnClientToSpectate)
	RegConsoleCmd("sm_survivors", TurnClientToSurvivors);
	RegConsoleCmd("sm_survivor", TurnClientToSurvivors);
	RegConsoleCmd("sm_sur", TurnClientToSurvivors);
	RegConsoleCmd("sm_joinsurvivors", TurnClientToSurvivors);
	RegConsoleCmd("sm_jointeam2", TurnClientToSurvivors);
	RegConsoleCmd("sm_infected", TurnClientToInfected);
	RegConsoleCmd("sm_inf", TurnClientToInfected);
	RegConsoleCmd("sm_joininfected", TurnClientToInfected);
	RegConsoleCmd("sm_jointeam3", TurnClientToInfected);
	
	RegConsoleCmd("jointeam", WTF);
	RegConsoleCmd("go_away_from_keyboard", WTF2);

	cvarCoolTime = CreateConVar("l4d2_changeteam_cooltime", "4.0", "Time in seconds a player can't change team again.", FCVAR_NOTIFY);
	cvarDeadChangeTeamEnable = CreateConVar("l4d2_deadplayer_changeteam", "0", "Can Dead Survivor Player change team? (0:No, 1:Yes)", FCVAR_NOTIFY);
	
	DeadChangeTeamEnable = GetConVarBool(cvarDeadChangeTeamEnable);
	
	HookConVarChange(cvarCoolTime, ConVarChange_cvarCoolTime);
	HookConVarChange(cvarDeadChangeTeamEnable, ConVarChange_cvarDeadChangeTeamEnable);
	
	HookEvent("lunge_pounce", Event_Survivor_GOT);
	HookEvent("tongue_grab", Event_Survivor_GOT);
	HookEvent("pounce_stopped", Event_Survivor_RELEASE);
	HookEvent("tongue_release", Event_Survivor_RELEASE);
	HookEvent("witch_harasser_set", OnWitchWokeup);
	if(b_IsL4D2)
	{
		HookEvent("charger_carry_start", Event_Survivor_GOT);
		HookEvent("jockey_ride", Event_Survivor_GOT);
		HookEvent("charger_pummel_end", Event_Survivor_RELEASE);
		HookEvent("jockey_ride_end", Event_Survivor_RELEASE);
	}
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death",		Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerChangeTeam);
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea, EventHookMode_Post);
	
	//HookEvent("player_bot_replace", OnPlayerBotReplace);

	
	CheckSpectatePenalty();
	Clear();
	
	g_hGameMode = FindConVar("mp_gamemode");
	GetConVarString(g_hGameMode,CvarGameMode,sizeof(CvarGameMode));
	HookConVarChange(cvarDeadChangeTeamEnable, ConVarChange_CvarGameMode);
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsClientAndInGame(client)) return;
	clientBusy[client] = false;
	
	if(GetClientTeam(client) == 3 && GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_CHARGER && ChargerGot[client] > 0)
	{
		clientBusy[ChargerGot[client]] = false;
		ChargerGot[client] = 0;
	}
}

public Event_Survivor_GOT (Handle:event, const String:name[], bool:dontBroadcast)
{
	//PrintToChatAll("Got!");
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
    
	clientBusy[victim] = true;
	
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsClientAndInGame(attacker) && GetClientTeam(attacker) == 3 && GetEntProp(attacker,Prop_Send,"m_zombieClass") == ZOMBIECLASS_CHARGER)
	{
		ChargerGot[attacker] = victim;
	}
}
public Event_Survivor_RELEASE (Handle:event, const String:name[], bool:dontBroadcast)
{
	//PrintToChatAll("release");
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	
	clientBusy[victim] = false;
}

public OnClientPutInServer(client)
{
	Clear(client);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);	
}

public OnClientDisconnect(client)
{
	Clear(client);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if (!IsValidEdict(victim) || !IsValidEdict(attacker) || !IsValidEdict(inflictor) || !LEFT_SAFE_ROOM) { return Plugin_Continue; }
	
	if(GetClientTeam(victim) != 2 || !IsClientAndInGame(victim)) { return Plugin_Continue; }
	if(WitchTarget[attacker] == victim) { return Plugin_Continue; }
	decl String:sClassname[64];
	GetEntityClassname(inflictor, sClassname, 64);
	if(StrEqual(sClassname, "witch"))
	{
		WitchTarget[attacker] = victim;
		clientBusy[victim] = true;
		//PrintToChatAll("attacker: %d, victim: %d",attacker,victim);
		CreateTimer(0.25, TraceWitchAlive, attacker, TIMER_REPEAT);
	}
	return Plugin_Continue;
}

public Action:OnWitchWokeup(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!LEFT_SAFE_ROOM) return;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new witchid = GetEventInt(event, "witchid");
	if(client > 0 && client <= MaxClients &&  IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		WitchTarget[witchid] = client;
		clientBusy[client] = true;
		CreateTimer(0.25, TraceWitchAlive, witchid, TIMER_REPEAT);
	}
	
}

public Action:TraceWitchAlive(Handle:timer, any:entity)
{
	new witchtarget = WitchTarget[entity];
	if(!IsValidEntity(witchtarget)) return Plugin_Stop;
	if (!IsValidEntity(entity))//witch dead or gone
	{
		//PrintToChatAll("Witch id:%d dead or gone, client: %d",entity,witchtarget);
		new iWitch = -1;
		while((iWitch = FindEntityByClassname(iWitch, "witch")) != -1)
		{
			if(iWitch!=entity && WitchTarget[iWitch] == witchtarget)
			{
				//PrintToChatAll("Witch id:%d still tracing client: %d",iWitch,witchtarget);
				return Plugin_Stop;
			}
		}
		clientBusy[witchtarget] = false;
		WitchTarget[entity] = -1;
		return Plugin_Stop;
	}
	clientBusy[witchtarget] = true;
	return Plugin_Continue;
}

public Action:Event_PlayerChangeTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(0.1, ClientReallyChangeTeam, client, _); // check delay
}

public Action:Event_PlayerLeftStartArea(Handle:event, String:name[], bool:dontBroadcast)
{
	LEFT_SAFE_ROOM = true;
}

public ConVarChange_cvarCoolTime(Handle:convar, const String:oldValue[], const String:newValue[])
{
	CheckSpectatePenalty();
}

public ConVarChange_CvarGameMode(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_hGameMode = FindConVar("mp_gamemode");
	GetConVarString(g_hGameMode,CvarGameMode,sizeof(CvarGameMode));
}

public ConVarChange_cvarDeadChangeTeamEnable(Handle:convar, const String:oldValue[], const String:newValue[])
{
	DeadChangeTeamEnable = StringToInt(newValue);
}

static CheckSpectatePenalty()
{
	if(GetConVarFloat(cvarCoolTime) <= 0.0) CoolTime = 0.0;
	else CoolTime = GetConVarFloat(cvarCoolTime);
	
}
public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	Clear();
}

Clear(client = -1)
{
	if(client == -1)
	{
		for(new i = 1; i <= MaxClients; i++)
		{	
			InCoolDownTime[i] = false;
			bClientJoinedTeam[i] = false;
			clientBusy[i] = false;
			ChargerGot[i] = 0;
			clientteam[i] = 0;
		}
		LEFT_SAFE_ROOM = false;
	}	
	else
	{
		InCoolDownTime[client] = false;
		bClientJoinedTeam[client] = false;
		clientBusy[client] = false;
		ChargerGot[client] = -1;
		clientteam[client] = 0;
	}
}

//When a bot replaces a player (i.e. player switches to spectate or infected)
//public Action:OnPlayerBotReplace(Handle:event, const String:name[], bool:dontBroadcast)
//{
//	new client = GetClientOfUserId(GetEventInt(event, "player"));
//	InCoolDownTime[client] = true;
//}


public Action:TurnClientToSpectate(client, argCount)
{
	if (client == 0)
	{
		PrintToServer("[TS] command cannot be used by server.");
		return Plugin_Handled;
	}
	if(IsClientIdle(client))
	{
		PrintHintText(client, "You are now idle already.");
		return Plugin_Handled;
	}
	if(GetClientTeam(client) != 1)
	{
		if(!CanClientChangeTeam(client)) return Plugin_Handled;
		
		if(GetClientTeam(client) == 2)
			FakeClientCommand(client, "go_away_from_keyboard");
		
		CreateTimer(0.1, CheckClientInSpecTeam, client, _); // check if client really spec
		
		clientteam[client] = 1;
		StartChangeTeamCoolDown(client);
	}
	return Plugin_Handled;
}


public Action:TurnClientToSurvivors(client, args)
{ 
	if (client == 0)
	{
		PrintToServer("[TS] command cannot be used by server.");
		return Plugin_Handled;
	}
	if (GetClientTeam(client) == 2)			//if client is survivor
	{
		PrintHintText(client, "You are already on the Survivor team.");
		return Plugin_Handled;
	}
	if(IsClientIdle(client))
	{
		PrintHintText(client, "You are now idle. Press mouse to play as survivor");
		return Plugin_Handled;
	}
	
	if(!CanClientChangeTeam(client)) return Plugin_Handled;
	
	new maxSurvivorSlots = GetTeamMaxHumans(2);
	new survivorUsedSlots = GetTeamHumanCount(2);
	new freeSurvivorSlots = (maxSurvivorSlots - survivorUsedSlots);
	//debug
	//PrintToChatAll("Number of Survivor Slots %d.\nNumber of Survivor Players %d.\nNumber of Free Slots %d.", maxSurvivorSlots, survivorUsedSlots, freeSurvivorSlots);
	
	if (freeSurvivorSlots <= 0)
	{
		PrintHintText(client, "Survivor team is full.");
		return Plugin_Handled;
	}
	else
	{
		new bot;
		
		for(bot = 1; 
			bot < (MaxClients + 1) && (!IsClientConnected(bot) || !IsFakeClient(bot) || (GetClientTeam(bot) != 2));
			bot++) {}
		
		if(bot == (MaxClients + 1))
		{			
			new String:command[] = "sb_add";
			new flags = GetCommandFlags(command);
			SetCommandFlags(command, flags & ~FCVAR_CHEAT);
			
			ServerCommand("sb_add");
			
			SetCommandFlags(command, flags);
		}

		if(StrEqual(CvarGameMode,"coop")||StrEqual(CvarGameMode,"survival")||StrEqual(CvarGameMode,"realism"))
		{
			if(!IsClientConnected(client))
				return Plugin_Handled;
		
			if(IsClientInGame(client))
			{
				if (GetClientTeam(client) == 3)			//if client is infected
				{
					CreateTimer(0.1, Survivor_Take_Control, client, TIMER_FLAG_NO_MAPCHANGE);
					clientteam[client] = 2;	
					StartChangeTeamCoolDown(client);
					
				}
				else
				{	
					CreateTimer(0.1, TakeOverBot, client, TIMER_FLAG_NO_MAPCHANGE);			
				}
			}	
		}
		else if(StrEqual(CvarGameMode,"versus")||StrEqual(CvarGameMode,"scavenge"))
		{
			CreateTimer(0.1, Survivor_Take_Control, client, TIMER_FLAG_NO_MAPCHANGE);
			clientteam[client] = 2;	
			StartChangeTeamCoolDown(client);
		}
		else //其他未知模式
		{
			CreateTimer(0.1, Survivor_Take_Control, client, TIMER_FLAG_NO_MAPCHANGE);
			clientteam[client] = 2;	
			StartChangeTeamCoolDown(client);
		}
	}
	return Plugin_Handled;
}

public Action:TurnClientToInfected(client, args)
{ 
	if (client == 0)
	{
		PrintToServer("[TS] command cannot be used by server.");
		return Plugin_Handled;
	}
	if (GetClientTeam(client) == 3)			//if client is Infected
	{
		PrintHintText(client, "You are already on the Infected team.");
		return Plugin_Handled;
	}
	if(StrEqual(CvarGameMode,"coop")||StrEqual(CvarGameMode,"survival")||StrEqual(CvarGameMode,"realism"))
	{
		return Plugin_Handled;
	}
	
	if(!CanClientChangeTeam(client)) return Plugin_Handled;
	
	ChangeClientTeam(client, 3);clientteam[client] = 3;
	
	StartChangeTeamCoolDown(client);
	
	return Plugin_Handled;
}
	
public Action:Survivor_Take_Control(Handle:timer, any:client)
{
		new localClientTeam = GetClientTeam(client);
		new String:command[] = "sb_takecontrol";
		new flags = GetCommandFlags(command);
		SetCommandFlags(command, flags & ~FCVAR_CHEAT);
		new String:botNames[][] = { "teengirl", "manager", "namvet", "biker" ,"coach","gambler","mechanic","producer"};
		
		new i = 0;
		while((localClientTeam != 2) && i < 8)
		{
			FakeClientCommand(client, "sb_takecontrol %s", botNames[i]);
			localClientTeam = GetClientTeam(client);
			i++;
		}
		SetCommandFlags(command, flags);
}
stock GetTeamMaxHumans(team)
{
	if(team == 2)
	{
		return GetConVarInt(FindConVar("survivor_limit"));
	}
	else if(team == 3)
	{
		return GetConVarInt(FindConVar("z_max_player_zombies"));
	}
	
	return -1;
}
stock GetTeamHumanCount(team)
{
	new humans = 0;
	
	new i;
	for(i = 1; i < (MaxClients + 1); i++)
	{
		if(IsClientInGameHuman(i) && GetClientTeam(i) == team)
		{
			humans++;
		}
	}
	
	return humans;
}
//client is in-game and not a bot and not spec
bool:IsClientInGameHuman(client)
{
	return IsClientInGame(client) && !IsFakeClient(client) && ((GetClientTeam(client) == 2 || GetClientTeam(client) == 3));
}

public bool:IsInteger(String:buffer[])
{
    new len = strlen(buffer);
    for (new i = 0; i < len; i++)
    {
        if ( !IsCharNumeric(buffer[i]) )
            return false;
    }

    return true;    
}

public Action:WTF(client, args) //玩家press m
{
	if (client == 0)
	{
		PrintToServer("[TS] command cannot be used by server.");
		return Plugin_Handled;
	}
	if( args < 1 )
	{
		return Plugin_Handled;
	}
	
	if(!CanClientChangeTeam(client)) return Plugin_Handled;

	new String:arg1[64];
	GetCmdArg(1, arg1, 64);
	if(IsInteger(arg1))
	{
		new iteam = StringToInt(arg1);
		if(iteam == 2)
		{
			FakeClientCommand(client, "sm_sur");
			return Plugin_Handled;
		}
		else if(iteam == 3)
		{
			FakeClientCommand(client, "sm_inf");
			return Plugin_Handled;
		}
		else if(iteam == 1)
		{
			FakeClientCommand(client, "sm_s");
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action:WTF2(client, args)
{
	if (client == 0)
	{
		PrintToServer("[TS] command cannot be used by server.");
		return Plugin_Handled;
	}
	
	if (GetClientTeam(client) == 3)			//if client is Infected
	{
		PrintHintText(client, "Go away!! infected player, you can't take a break");
		return Plugin_Handled;
	}
	if(IsClientIdle(client))
	{
		PrintHintText(client, "You are now idle already.");
		return Plugin_Handled;
	}
	
	if(!CanClientChangeTeam(client)) return Plugin_Handled;
	
	clientteam[client] = 1;
	StartChangeTeamCoolDown(client);
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

bool:PlayerIsAlive (client)
{
	if (!GetEntProp(client,Prop_Send, "m_lifeState"))
		return true;
	return false;
}

public Action:CheckClientInSpecTeam(Handle:timer, any:client)
{
	if(!IsClientAndInGame(client)) return;
	
	if (GetClientTeam(client) != 1)
		ChangeClientTeam(client, 1);
}

public Action:TakeOverBot(Handle:timer, any:client)
{
	if (!IsClientInGame(client)) return;
	if (GetClientTeam(client) == 2) return;
	if (IsFakeClient(client)) return;
	
	new bot = FindBotToTakeOver()	;
	if (bot==0)
	{
		PrintHintText(client, "No survivor bots to take over.");
		return;
	}
	
	static Handle:hSetHumanSpec;
	if (hSetHumanSpec == INVALID_HANDLE)
	{
		new Handle:hGameConf	;	
		hGameConf = LoadGameConfigFile("l4d_afk_commands");
		
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "SetHumanSpec");
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
		hSetHumanSpec = EndPrepSDKCall();
	}
	
	SDKCall(hSetHumanSpec, bot, client);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
	
	
	return;
}

bool:IsAlive(client)
{
	if(!GetEntProp(client, Prop_Send, "m_lifeState"))
		return true;
	
	return false;
}

bool:IsClientIdle(client)
{
	if(GetClientTeam(client) != 1)
		return false;
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			if((GetClientTeam(i) == 2) && IsAlive(i))
			{
				if(IsFakeClient(i))
				{
					if(GetClientOfUserId(GetEntProp(i, Prop_Send, "m_humanSpectatorUserID")) == client)
						return true;
				}
			}
		}
	}
	return false;
}

stock FindBotToTakeOver()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			if(IsClientInGame(i))
			{
				if (IsFakeClient(i) && GetClientTeam(i)==2 && IsAlive(i) && !HasIdlePlayer(i))
					return i;
			}
		}
	}
	return 0;
}

bool:HasIdlePlayer(bot)
{
	if(!IsFakeClient(bot))
		return false;
	
	if(IsClientConnected(bot) && IsClientInGame(bot))
	{
		if((GetClientTeam(bot) == 2) && IsAlive(bot))
		{
			if(IsFakeClient(bot))
			{
				new client = GetClientOfUserId(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID"))	;		
				if(client)
				{
					if(!IsClientInGame(client)) return false;
					if(!IsFakeClient(client) && (GetClientTeam(client) == 1))
						return true;
				}
			}
		}
	}
	return false;
}

bool:CanClientChangeTeam(client)
{
	if (clientBusy[client])
	{
		PrintHintText(client, "特感抓住期間禁止換隊.");
		return false;
	}	
	if(InCoolDownTime[client])
	{
		bClientJoinedTeam[client] = true;
		CPrintToChat(client, "You can't change team so quickly! Wait %.0fs", g_iSpectatePenaltyCounter[client]);
		return false;
	}
	if(GetClientTeam(client) == 2)
	{
		if(!PlayerIsAlive(client)&&!DeadChangeTeamEnable)
		{
			PrintHintText(client, "死亡倖存者禁止換隊.");
			return false;
		}
	}
	return true;
}

StartChangeTeamCoolDown(client)
{
	if(InCoolDownTime[client]||!LEFT_SAFE_ROOM) return;
	if(CoolTime > 0.0)
	{
		InCoolDownTime[client] = true;
		g_iSpectatePenaltyCounter[client] = CoolTime;
		CreateTimer(0.25, Timer_CanJoin, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:ClientReallyChangeTeam(Handle:timer, any:client)
{
	if(!IsClientAndInGame(client)||IsFakeClient(client)||InCoolDownTime[client]||!LEFT_SAFE_ROOM) return;
	
	//PrintToChatAll("client: %N change Team: %d clientteam[client]:%d",client,GetClientTeam(client),clientteam[client]);
	if(GetClientTeam(client) != clientteam[client])
	{
		clientteam[client] = GetClientTeam(client);
		StartChangeTeamCoolDown(client);
		GetClientTeam(client);
	}
}

public Action:Timer_CanJoin(Handle:timer, any:client)
{
	if (!InCoolDownTime[client] || 
	!IsClientInGame(client) || 
	IsFakeClient(client) )//if client disconnected or is fake client or take a break on player bot
	{
		InCoolDownTime[client] = false;
		return Plugin_Stop;
	}

	
	if (g_iSpectatePenaltyCounter[client] != 0)
	{
		g_iSpectatePenaltyCounter[client]-=0.25;
		if(GetClientTeam(client)!=clientteam[client])
		{	
			bClientJoinedTeam[client] = true;
			CPrintToChat(client, "You can't change team so quickly! Wait %.0fs.", g_iSpectatePenaltyCounter[client]);
			ChangeClientTeam(client, 1);clientteam[client]=1;
			return Plugin_Continue;
		}
	}
	else if (g_iSpectatePenaltyCounter[client] <= 0)
	{
		if(GetClientTeam(client)!=clientteam[client])
		{	
			bClientJoinedTeam[client] = true;
			CPrintToChat(client, "You can't change team so quickly! Wait %.0fs.", g_iSpectatePenaltyCounter[client]);
			ChangeClientTeam(client, 1);clientteam[client]=1;
		}
		if (bClientJoinedTeam[client])
		{
			PrintHintText(client, "You can change team now");	//only print this hint text to the spectator if he tried to join team, and got swapped before
		}
		InCoolDownTime[client] = false;
		bClientJoinedTeam[client] = false;
		g_iSpectatePenaltyCounter[client] = CoolTime;
		return Plugin_Stop;
	}
	
	
	return Plugin_Continue;
}
