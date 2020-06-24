/*version: 2.7*/
//add two convar
//"l4d_afk_commands_adm_only", "0", "If 1, only admins can use command to switch team"
//"l4d_afk_commands_adm_immue",	 "1", "If 1, admins are immune to all limit"

/*version: 2.6*/
//Improve code

/*version: 2.5*/
//Improve code

/*version: 2.4*/
//fixed InCoolDownTime error

/*version: 2.3*/
//fixed Exception reported: Language phrase "No matching client" not found

/*version: 2.2*/
//修正電腦玩家"m_humanSpectatorUserID" not found

/*version: 2.1*/
//修正玩家閒置後到了下一關或是重新回合無法換回隊伍

/*version: 2.0*/
//修正無法用jointeam2 <character> 選擇角色
//回合結束之前不准擅自更換隊伍
//管理員指令新增 sm_swapto <player> <team> 強制指定玩家換隊伍

/*version: 1.9*/
//修正出安全門無法換隊

/*version: 1.8*/
//修正參數沒正確改變的問題
//修正特感數量大於上限還是能換到特感隊伍

/*version: 1.7*/
//本插件用來防止玩家換隊濫用的Bug
//禁止期間不能閒置 亦不可按M換隊
//1.嚇了Witch或被Witch抓倒 期間禁止換隊 (防止Witch失去目標)
//2.被特感抓住期間 期間禁止換隊 (防止濫用特感控了無傷)
//3.人類玩家死亡 期間禁止換隊 (防止玩家故意死亡 然後跳隊裝B)
//4.換隊成功之後 必須等待數秒才能再換隊 (防止玩家頻繁換隊洗頻伺服器)

#define PLUGIN_VERSION    "2.7"
#define PLUGIN_NAME       "[L4D(2)] AFK and Join Team Commands"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>
#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法

#define STEAMID_SIZE 		32
#define L4D_TEAM_NAME(%1) (%1 == 2 ? "Survivors" : (%1 == 3 ? "Infected" : (%1 == 1 ? "Spectators" : "Unknown")))
static const int ARRAY_TEAM = 1;
static const int ARRAY_COUNT = 2;
//convar
ConVar cvarCoolTime					= null;
ConVar cvarDeadChangeTeamEnable		= null;
ConVar cvarEnforceTeamSwitch 		= null;
ConVar cvarAdmOnly 					= null;
ConVar cvarAdmImmue 				= null;
ConVar g_hGameMode;

//value
Handle arrayclientswitchteam;
static Handle hSetHumanSpec;

static bool InCoolDownTime[MAXPLAYERS+1] = false;//是否還有換隊冷卻時間
static float CoolTime;
static bool bClientJoinedTeam[MAXPLAYERS+1] = false; //在冷卻時間是否嘗試加入
static float g_iSpectatePenaltyCounter[MAXPLAYERS+1] ;//各自的冷卻時間
static bool clientBusy[MAXPLAYERS+1];//是否被witch抓
static int WitchTarget[5000];//WitchTarget[妹子元素編號]=鎖定的玩家
static int clientteam[MAXPLAYERS+1];//玩家換隊成功之後的隊伍
static int DeadChangeTeamEnable;
char CvarGameMode[20];
static bool LEFT_SAFE_ROOM;
bool EnforceTeamSwitch;
static bool L4D2Version;
bool bAdmOnly,bAdmImmue;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "MasterMe,modify by Harry",
	description = "Adds commands to let the player spectate and join team. (!afk, !survivors, !infected, etc.),but no change team abuse",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=122476"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	// Checks to see if the game is a L4D game. If it is, check if its the sequel. L4DVersion is L4D if false, L4D2 if true.
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead)
		L4D2Version = false;
	else if (test == Engine_Left4Dead2 )
		L4D2Version = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{

	LoadTranslations("common.phrases");
	RegConsoleCmd("sm_afk", TurnClientToSpectate);
	RegConsoleCmd("sm_s", TurnClientToSpectate);
	RegConsoleCmd("sm_join", TurnClientToSurvivors);
	RegConsoleCmd("sm_bot", TurnClientToSurvivors);
	RegConsoleCmd("sm_jointeam", TurnClientToSurvivors);
	RegConsoleCmd("sm_away", TurnClientToSpectate);
	RegConsoleCmd("sm_idle", TurnClientToSpectate);
	RegConsoleCmd("sm_spectate", TurnClientToSpectate);
	RegConsoleCmd("sm_spec", TurnClientToSpectate);
	RegConsoleCmd("sm_spectators", TurnClientToSpectate);
	RegConsoleCmd("sm_joinspectators", TurnClientToSpectate);
	RegConsoleCmd("sm_jointeam1", TurnClientToSpectate);
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
	
	RegAdminCmd("sm_swapto", Command_SwapTo, ADMFLAG_BAN, "sm_swapto <player1> [player2] ... [playerN] <teamnum> - swap all listed players to <teamnum> (1,2, or 3)");
	
	cvarCoolTime = CreateConVar("l4d_afk_commands_changeteam_cooltime", "4.0", "Cold Down Time in seconds a player can't change team again.", FCVAR_NOTIFY, true, 1.0);
	cvarDeadChangeTeamEnable = CreateConVar("l4d_afk_commands_deadplayer_changeteam_enable", "0", "Can Dead Survivor Player change team? (0:No, 1:Yes)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarEnforceTeamSwitch = CreateConVar("l4d_afk_commands_teamswitch_during_game_enabled", "0", "Can player use command to switch team during the game? (0:No, 1:Yes)", FCVAR_SPONLY | FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarAdmOnly = CreateConVar("l4d_afk_commands_adm_only", "0", "If 1, only admins can use command to switch team", FCVAR_SPONLY | FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarAdmImmue = CreateConVar("l4d_afk_commands_adm_immue", "1", "If 1, admins are immune to all limit", FCVAR_SPONLY | FCVAR_NOTIFY, true, 0.0, true, 1.0);

	DeadChangeTeamEnable = cvarDeadChangeTeamEnable.BoolValue;
	EnforceTeamSwitch = cvarEnforceTeamSwitch.BoolValue;
	bAdmOnly = cvarAdmOnly.BoolValue;
	bAdmImmue = cvarAdmImmue.BoolValue;
	CheckSpectatePenalty();

	g_hGameMode = FindConVar("mp_gamemode");
	g_hGameMode.GetString(CvarGameMode,sizeof(CvarGameMode));
	g_hGameMode.AddChangeHook(ConVarChange_CvarGameMode);
	cvarCoolTime.AddChangeHook(ConVarChanged_Cvars);
	cvarDeadChangeTeamEnable.AddChangeHook(ConVarChanged_Cvars);
	cvarEnforceTeamSwitch.AddChangeHook(ConVarChanged_Cvars);
	cvarAdmOnly.AddChangeHook(ConVarChanged_Cvars);
	cvarAdmImmue.AddChangeHook(ConVarChanged_Cvars);
	
	HookEvent("witch_harasser_set", OnWitchWokeup);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerChangeTeam);
	HookEvent("player_spawn", Event_PlayerSpawn);

	Clear();

	arrayclientswitchteam = CreateArray(ByteCountToCells(STEAMID_SIZE));
	
	Handle hGameConf;	
	hGameConf = LoadGameConfigFile("l4d_afk_commands");
	if(hGameConf == null)
	{
		SetFailState("Gamedata l4d_afk_commands.txt not found");
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

	AutoExecConfig(true, "l4d_afk_commands");
}

public void OnMapStart()
{
	ClearArray(arrayclientswitchteam);
	g_hGameMode.GetString(CvarGameMode,sizeof(CvarGameMode));
}

public Action Command_SwapTo(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_swapto <player1> [player2] ... [playerN] <teamnum> - swap all listed players to team <teamnum> (1,2,or 3)");
		return Plugin_Handled;
	}
	
	int team;
	char teamStr[64];
	GetCmdArg(args, teamStr, sizeof(teamStr));
	team = StringToInt(teamStr);
	if(0>=team||team>=4)
	{
		ReplyToCommand(client, "[SM] Invalid team %s specified, needs to be 1, 2, or 3", teamStr);
		return Plugin_Handled;
	}
	
	int player_id;

	char player[64];
	
	for(int i = 0; i < args - 1; i++)
	{
		GetCmdArg(i+1, player, sizeof(player));
		player_id = FindTarget(client, player, true /*nobots*/, false /*immunity*/);
		
		if(player_id == -1)
			continue;
		
		if(team == 1)
			ChangeClientTeam(player_id,1);
		else if(team == 2)
			ChangeClientTeam(player_id,2);
		else if (team == 3)
			ChangeClientTeam(player_id,3);
			
		PrintToChatAll("[SM] %N has been swapped to the %s team.", player_id, L4D_TEAM_NAME(team));
	}
	
	return Plugin_Handled;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) 
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if(!IsClientAndInGame(victim)) return;
	clientBusy[victim] = false;

	if(!EnforceTeamSwitch && IsClientInGame(victim) && !IsFakeClient(victim) && GetClientTeam(victim) == 2)
	{
		char steamID[STEAMID_SIZE];
		GetClientAuthId(victim, AuthId_Steam2,steamID, STEAMID_SIZE);
		int index = FindStringInArray(arrayclientswitchteam, steamID);
		if (index == -1) {
			PushArrayString(arrayclientswitchteam, steamID);
			PushArrayCell(arrayclientswitchteam, 4);
		}
		else
		{
			SetArrayCell(arrayclientswitchteam, index + ARRAY_TEAM, 4);
		}			
	}
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	int player = GetClientOfUserId(event.GetInt("userid"));
	if(!EnforceTeamSwitch && player > 0 && player <=MaxClients && IsClientInGame(player) && !IsFakeClient(player) && GetClientTeam(player) == 2)
	{
		CreateTimer(2.0,checksurvivorspawn,player);		
	}
}

public Action checksurvivorspawn(Handle timer, int client)
{
	if(!EnforceTeamSwitch && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
	{
		char steamID[STEAMID_SIZE];
		GetClientAuthId(client, AuthId_Steam2,steamID, STEAMID_SIZE);
		int index = FindStringInArray(arrayclientswitchteam, steamID);
		if (index == -1) {
			PushArrayString(arrayclientswitchteam, steamID);
			PushArrayCell(arrayclientswitchteam, 2);
		}
		else
		{
			SetArrayCell(arrayclientswitchteam, index + ARRAY_TEAM, 2);
		}			
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);	
}

public bool OnClientConnect(int client)
{
	Clear(client);
	return true;
}

public void OnClientDisconnect(int client)
{
	Clear(client);
}

public Action OnTakeDamage(int victim, int &attacker, int  &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (!IsValidEdict(victim) || !IsValidEdict(attacker) || !IsValidEdict(inflictor) || !LEFT_SAFE_ROOM) { return Plugin_Continue; }
	
	if(GetClientTeam(victim) != 2 || !IsClientAndInGame(victim)) { return Plugin_Continue; }
	if(WitchTarget[attacker] == victim) { return Plugin_Continue; }
	char sClassname[64];
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

public Action OnWitchWokeup(Event event, const char[] name, bool dontBroadcast) 
{
	if(!LEFT_SAFE_ROOM) return;
	int client = GetClientOfUserId(event.GetInt("userid"));
	int witchid = event.GetInt("witchid");
	if(client > 0 && client <= MaxClients &&  IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		WitchTarget[witchid] = client;
		clientBusy[client] = true;
		CreateTimer(0.25, TraceWitchAlive, witchid, TIMER_REPEAT);
	}
	
}

public Action TraceWitchAlive(Handle timer, int entity)
{
	int witchtarget = WitchTarget[entity];
	if(!IsValidEntity(witchtarget)) return Plugin_Stop;
	if (!IsValidEntity(entity))//witch dead or gone
	{
		//PrintToChatAll("Witch id:%d dead or gone, client: %d",entity,witchtarget);
		int iWitch = -1;
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

public Action Event_PlayerChangeTeam(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	CreateTimer(0.1, ClientReallyChangeTeam, client, _); // check delay
}

public void ConVarChange_CvarGameMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_hGameMode.GetString(CvarGameMode,sizeof(CvarGameMode));
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	DeadChangeTeamEnable = cvarDeadChangeTeamEnable.BoolValue;
	EnforceTeamSwitch = cvarEnforceTeamSwitch.BoolValue;
	bAdmOnly = cvarAdmOnly.BoolValue;
	bAdmImmue = cvarAdmImmue.BoolValue;
	CheckSpectatePenalty();
}

static void CheckSpectatePenalty()
{
	if(cvarCoolTime.FloatValue <= 0.0) CoolTime = 0.0;
	else CoolTime = cvarCoolTime.FloatValue;
	
}
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	for (int i = 0; i < (GetArraySize(arrayclientswitchteam) / ARRAY_COUNT); i++) {
		SetArrayCell(arrayclientswitchteam, (i * ARRAY_COUNT) + ARRAY_TEAM, 0);
	}
	Clear();
	CreateTimer(1.0, PlayerLeftStart, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}
public Action PlayerLeftStart(Handle Timer)
{
	if (LeftStartArea())
	{
		LEFT_SAFE_ROOM = true;
		return Plugin_Handled;
	}
	return Plugin_Continue; 
}

void Clear(int client = -1)
{
	if(client == -1)
	{
		for(int i = 1; i <= MaxClients; i++)
		{	
			InCoolDownTime[i] = false;
			bClientJoinedTeam[i] = false;
			clientBusy[i] = false;
			clientteam[i] = 0;
		}
		LEFT_SAFE_ROOM = false;
	}	
	else
	{
		InCoolDownTime[client] = false;
		bClientJoinedTeam[client] = false;
		clientBusy[client] = false;
		clientteam[client] = 0;
	}
}

//When a bot replaces a player (i.e. player switches to spectate or infected)
//public Action OnPlayerBotReplace(Event event, const char[] name, bool dontBroadcast) 
//{
//	int client = GetClientOfUserId(hEvent.GetInt( "player"));
//	InCoolDownTime[client] = true;
//}

public Action TurnClientToSpectate(int client, int argCount)
{
	if (client == 0)
	{
		PrintToServer("[TS] command cannot be used by server.");
		return Plugin_Handled;
	}
	bool bIsAdm = IsPlayerGenericAdmin(client);
	if(!bIsAdm && bAdmOnly)
	{
		ReplyToCommand(client, "You don't have access to change team");
		return Plugin_Handled;
	}
	if(IsClientIdle(client))
	{
		PrintHintText(client, "[TS] 你正在閒置中.");
		return Plugin_Handled;
	}
	if(GetClientTeam(client) != 1)
	{
		if(!CanClientChangeTeam(client,1,bIsAdm)) return Plugin_Handled;
		
		if(GetClientTeam(client) == 2)
			FakeClientCommand(client, "go_away_from_keyboard");
		
		CreateTimer(0.1, CheckClientInSpecTeam, client, _); // check if client really spec
		
		clientteam[client] = 1;
		StartChangeTeamCoolDown(client,bIsAdm);
	}
	else if(GetClientTeam(client) == 1 && (StrEqual(CvarGameMode,"versus")||StrEqual(CvarGameMode,"scavenge")))
	{
		ChangeClientTeam(client, 3);
		CreateTimer(0.1, Timer_Respectate, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Handled;
}

public Action Timer_Respectate(Handle timer, int client)
{
	ChangeClientTeam(client, 1);
}

public Action TurnClientToSurvivors(int client, int args)
{ 
	if (client == 0)
	{
		PrintToServer("[TS] command cannot be used by server.");
		return Plugin_Handled;
	}
	bool bIsAdm = IsPlayerGenericAdmin(client);
	if(bAdmOnly && !bIsAdm)
	{
		ReplyToCommand(client, "You don't have access to change team");
		return Plugin_Handled;
	}
	if (GetClientTeam(client) == 2)			//if client is survivor
	{
		PrintHintText(client, "[TS] 你已經在人類隊伍了! you dumb shit.");
		return Plugin_Handled;
	}
	if(IsClientIdle(client))
	{
		PrintHintText(client, "[TS] 你正在閒置中. 請按左鍵遊玩倖存者.");
		return Plugin_Handled;
	}
	
	if(!CanClientChangeTeam(client,2,bIsAdm)) return Plugin_Handled;
	
	int maxSurvivorSlots = GetTeamMaxSlots(2);
	int survivorUsedSlots = GetTeamHumanCount(2);
	int freeSurvivorSlots = (maxSurvivorSlots - survivorUsedSlots);
	//debug
	//PrintToChatAll("Number of Survivor Slots %d.\nNumber of Survivor Players %d.\nNumber of Free Slots %d.", maxSurvivorSlots, survivorUsedSlots, freeSurvivorSlots);
	
	if (freeSurvivorSlots <= 0)
	{
		PrintHintText(client, "[TS] 人類隊伍已滿.");
		return Plugin_Handled;
	}
	else
	{
		int bot;
		
		for(bot = 1; 
			bot < (MaxClients + 1) && (!IsClientConnected(bot) || !IsFakeClient(bot) || (GetClientTeam(bot) != 2));
			bot++) {}
		
		if(bot == (MaxClients + 1))
		{			
			char command[] = "sb_add";
			int flags = GetCommandFlags(command);
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
					StartChangeTeamCoolDown(client,bIsAdm);
					
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
			StartChangeTeamCoolDown(client,bIsAdm);
		}
		else //其他未知模式
		{
			CreateTimer(0.1, Survivor_Take_Control, client, TIMER_FLAG_NO_MAPCHANGE);
			clientteam[client] = 2;	
			StartChangeTeamCoolDown(client,bIsAdm);
		}
	}
	return Plugin_Handled;
}

public Action TurnClientToInfected(int client, int args)
{ 
	if (client == 0)
	{
		PrintToServer("[TS] command cannot be used by server.");
		return Plugin_Handled;
	}
	bool bIsAdm = IsPlayerGenericAdmin(client);
	if(bAdmOnly && !bIsAdm)
	{
		ReplyToCommand(client, "You don't have access to change team");
		return Plugin_Handled;
	}
	if (GetClientTeam(client) == 3)			//if client is Infected
	{
		PrintHintText(client, "[TS] 你已經在特感隊伍了.");
		return Plugin_Handled;
	}
	int maxInfectedSlots = GetTeamMaxSlots(3);
	int infectedUsedSlots = GetTeamHumanCount(3);
	int freeInfectedSlots = (maxInfectedSlots - infectedUsedSlots);
	if (freeInfectedSlots <= 0)
	{
		PrintHintText(client, "[TS] 特感隊伍已滿.");
		return Plugin_Handled;
	}
	if(StrEqual(CvarGameMode,"coop")||StrEqual(CvarGameMode,"survival")||StrEqual(CvarGameMode,"realism"))
	{
		return Plugin_Handled;
	}
	
	if(!CanClientChangeTeam(client,3,bIsAdm)) return Plugin_Handled;
	
	ChangeClientTeam(client, 3);clientteam[client] = 3;
	
	StartChangeTeamCoolDown(client,bIsAdm);
	
	return Plugin_Handled;
}
	
public Action Survivor_Take_Control(Handle timer, int client)
{
		int localClientTeam = GetClientTeam(client);
		char command[] = "sb_takecontrol";
		int flags = GetCommandFlags(command);
		SetCommandFlags(command, flags & ~FCVAR_CHEAT);
		char botNames[][] = { "teengirl", "manager", "namvet", "biker" ,"coach","gambler","mechanic","producer"};
		
		int i = 0;
		while((localClientTeam != 2) && i < 8)
		{
			FakeClientCommand(client, "sb_takecontrol %s", botNames[i]);
			localClientTeam = GetClientTeam(client);
			i++;
		}
		SetCommandFlags(command, flags);
}

stock int GetTeamMaxSlots(int team)
{
	int teammaxslots = 0;
	if(team == 2)
	{
		for(int i = 1; i < (MaxClients + 1); i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == team)
			{
				teammaxslots++;
			}
		}
	}
	else if (team == 3)
	{
		return FindConVar("z_max_player_zombies").IntValue;
	}
	
	return teammaxslots;
}
stock int GetTeamHumanCount(int team)
{
	int humans = 0;
	
	int i;
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
bool IsClientInGameHuman(int client)
{
	return IsClientInGame(client) && !IsFakeClient(client) && ((GetClientTeam(client) == 2 || GetClientTeam(client) == 3));
}

public bool IsInteger(char[] buffer)
{
    int len = strlen(buffer);
    for (int i = 0; i < len; i++)
    {
        if ( !IsCharNumeric(buffer[i]) )
            return false;
    }

    return true;    
}

public Action WTF(int client, int args) //玩家press m
{
	if (client == 0)
	{
		PrintToServer("[TS] command cannot be used by server.");
		return Plugin_Handled;
	}
	bool bIsAdm = IsPlayerGenericAdmin(client);
	if(bAdmOnly && !bIsAdm)
	{
		ReplyToCommand(client, "You don't have access to change team");
		return Plugin_Handled;
	}
	if(!CanClientChangeTeam(client,5,bIsAdm)) return Plugin_Handled;
	
	if(args == 2)
	{
		char arg1[64];
		GetCmdArg(1, arg1, 64);
		char arg2[64];
		GetCmdArg(2, arg2, 64);
		if(StrEqual(arg1,"2") &&
			(StrEqual(arg2,"Nick") ||
			 StrEqual(arg2,"Ellis") ||
			 StrEqual(arg2,"Rochelle") ||
			 StrEqual(arg2,"Coach") ||
			 StrEqual(arg2,"Bill") ||
			 StrEqual(arg2,"Zoey") ||
			 StrEqual(arg2,"Francis") ||
			 StrEqual(arg2,"Louis") 
			)
		)
		{	
			return Plugin_Continue;
		}
		ReplyToCommand(client, "Usage: jointeam 2 <character_name>");	
		return Plugin_Handled;
	}
	
	char arg1[64];
	GetCmdArg(1, arg1, 64);
	if(IsInteger(arg1))
	{
		int iteam = StringToInt(arg1);
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

public Action WTF2(int client, int args)
{
	if (client == 0)
	{
		PrintToServer("[TS] command cannot be used by server.");
		return Plugin_Handled;
	}
	bool bIsAdm = IsPlayerGenericAdmin(client);
	if(bAdmOnly && !bIsAdm)
	{
		ReplyToCommand(client, "You don't have access to change team");
		return Plugin_Handled;
	}
	if (GetClientTeam(client) == 3)			//if client is Infected
	{
		PrintHintText(client, "[TS] 走開!! 特感玩家無法閒置!.");
		return Plugin_Handled;
	}
	if(IsClientIdle(client))
	{
		PrintHintText(client, "[TS] 你正在閒置中.");
		return Plugin_Handled;
	}
	
	if(!CanClientChangeTeam(client,1,bIsAdm)) return Plugin_Handled;
	
	clientteam[client] = 1;
	StartChangeTeamCoolDown(client,bIsAdm);
	return Plugin_Continue;
}
stock bool IsClientAndInGame(int index)
{
	if (index > 0 && index < MaxClients)
	{
		return IsClientInGame(index);
	}
	return false;
}

bool PlayerIsAlive (int client)
{
	if (!GetEntProp(client,Prop_Send, "m_lifeState"))
		return true;
	return false;
}

public Action CheckClientInSpecTeam(Handle timer, int client)
{
	if(!IsClientAndInGame(client)) return;
	
	if (GetClientTeam(client) != 1)
		ChangeClientTeam(client, 1);
}

public Action TakeOverBot(Handle timer, int client)
{
	if (!IsClientInGame(client)) return;
	if (GetClientTeam(client) == 2) return;
	if (IsFakeClient(client)) return;
	
	int bot = FindBotToTakeOver(true)	;
	if (bot==0)
	{
		bot = FindBotToTakeOver(false);
		if (bot==0)
		{
			PrintHintText(client, "[TS] 沒有人類bot能取代.");
			return;
		}
	}
	
	if(IsPlayerAlive(bot))
	{
		SDKCall(hSetHumanSpec, bot, client);
		SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
	}
	else
	{
		CreateTimer(0.1, Survivor_Take_Control, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	return;
}

bool IsAlive(int client)
{
	if(!GetEntProp(client, Prop_Send, "m_lifeState"))
		return true;
	
	return false;
}

bool IsClientIdle(int client)
{
	if(GetClientTeam(client) != 1)
		return false;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && IsAlive(i))
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

stock int FindBotToTakeOver(bool alive)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			if(IsClientInGame(i))
			{
				if (IsFakeClient(i) && GetClientTeam(i)==2 && !HasIdlePlayer(i) && IsPlayerAlive(i) == alive)
					return i;
			}
		}
	}
	return 0;
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

bool CanClientChangeTeam(int client, int changeteam, bool isAdm)
{
	if(isAdm && bAdmImmue) //adm免疫力特權
	{
		return true;
	}
	if (L4D2_GetInfectedAttacker(client) != -1 || clientBusy[client])
	{
		PrintHintText(client, "[TS] 特感抓住期間禁止換隊.");
		return false;
	}	
	if(InCoolDownTime[client])
	{
		bClientJoinedTeam[client] = true;
		CPrintToChat(client, "[{olive}TS{default}] 無法快速換隊! 請等待 {green}%.0f {default}秒.", g_iSpectatePenaltyCounter[client]);
		return false;
	}
	if(GetClientTeam(client) == 2)
	{
		if(!PlayerIsAlive(client)&&!DeadChangeTeamEnable)
		{
			PrintHintText(client, "[TS] 死亡倖存者禁止換隊.");
			return false;
		}
	}
	if(!EnforceTeamSwitch && LEFT_SAFE_ROOM && GetClientTeam(client) != 1 && changeteam != 1) 
	{
		CPrintToChat(client, "[{olive}TS{default}] 遊戲中{green}禁止跳隊{default}!!");
		return false;
	}
	return true;
}

void StartChangeTeamCoolDown(int client, bool bIsAdm)
{
	if(InCoolDownTime[client]||!LEFT_SAFE_ROOM||(bIsAdm && bAdmImmue)) return;
	if(CoolTime > 0.0)
	{
		InCoolDownTime[client] = true;
		g_iSpectatePenaltyCounter[client] = CoolTime;
		CreateTimer(0.25, Timer_CanJoin, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action ClientReallyChangeTeam(Handle timer, int client)
{
	if(!IsClientAndInGame(client)||IsFakeClient(client)) return;
	bool bIsAdm = IsPlayerGenericAdmin(client);
	if(bIsAdm && bAdmImmue) return;

	if(!EnforceTeamSwitch)
	{
		int newteam = GetClientTeam(client);
		if(newteam != 1)
		{
			char steamID[STEAMID_SIZE];
			GetClientAuthId(client, AuthId_Steam2, steamID, STEAMID_SIZE);
			int index = FindStringInArray(arrayclientswitchteam, steamID);
			if (index == -1) {
				PushArrayString(arrayclientswitchteam, steamID);
				PushArrayCell(arrayclientswitchteam, newteam);
			}
			else
			{
				int oldteam = GetArrayCell(arrayclientswitchteam, index + ARRAY_TEAM);
				if(!LEFT_SAFE_ROOM || oldteam == 0)
					SetArrayCell(arrayclientswitchteam, index + ARRAY_TEAM, newteam);
				else
				{
					//PrintToChatAll("%N newteam: %d, oldteam: %d",client,newteam,oldteam);
					if(newteam != oldteam)
					{
						if(oldteam == 4 && !(newteam == 2 && !IsPlayerAlive(client)) ) //player survivor death
						{
							ChangeClientTeam(client,1);
							CPrintToChat(client,"[{olive}TS{default}] 你已經在倖存者隊伍死亡, {red}禁止跳隊{default}!!");
						}
						else if(oldteam != 4)
						{
							ChangeClientTeam(client,1);
							CPrintToChat(client,"[{olive}TS{default}] 回去 {green}%s {default}隊伍, 遊戲中{red}禁止跳隊{default}!!",(oldteam == 2) ? "倖存者" : "特感");
						}
					}
				}
			}		
		}
	}
	
	if(LEFT_SAFE_ROOM && InCoolDownTime[client]) return;
	
	//PrintToChatAll("client: %N change Team: %d clientteam[client]:%d",client,GetClientTeam(client),clientteam[client]);
	if(GetClientTeam(client) != clientteam[client])
	{
		if(clientteam[client] != 0) StartChangeTeamCoolDown(client,bIsAdm);
		clientteam[client] = GetClientTeam(client);		
	}
}

public Action Timer_CanJoin(Handle timer, int client)
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
			CPrintToChat(client, "[{olive}TS{default}] 無法快速換隊! 請等待 {green}%.0f {default}秒.", g_iSpectatePenaltyCounter[client]);
			ChangeClientTeam(client, 1);clientteam[client]=1;
			return Plugin_Continue;
		}
	}
	else if (g_iSpectatePenaltyCounter[client] <= 0)
	{
		if(GetClientTeam(client)!=clientteam[client])
		{	
			bClientJoinedTeam[client] = true;
			CPrintToChat(client, "[{olive}TS{default}]] 無法快速換隊! 請等待 {green}%.0f {default}秒.", g_iSpectatePenaltyCounter[client]);
			ChangeClientTeam(client, 1);clientteam[client]=1;
		}
		if (bClientJoinedTeam[client])
		{
			PrintHintText(client, "[TS] 你現在能換隊了.");	//only print this hint text to the spectator if he tried to join team, and got swapped before
		}
		InCoolDownTime[client] = false;
		bClientJoinedTeam[client] = false;
		g_iSpectatePenaltyCounter[client] = CoolTime;
		return Plugin_Stop;
	}
	
	
	return Plugin_Continue;
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

stock int L4D2_GetInfectedAttacker(int client)
{
	int attacker;

	if(L4D2Version)
	{
		/* Charger */
		attacker = GetEntPropEnt(client, Prop_Send, "m_pummelAttacker");
		if (attacker > 0)
		{
			return attacker;
		}

		attacker = GetEntPropEnt(client, Prop_Send, "m_carryAttacker");
		if (attacker > 0)
		{
			return attacker;
		}
		/* Jockey */
		attacker = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
		if (attacker > 0)
		{
			return attacker;
		}
	}

	/* Hunter */
	attacker = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
	if (attacker > 0)
	{
		return attacker;
	}

	/* Smoker */
	attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if (attacker > 0)
	{
		return attacker;
	}

	return -1;
}

bool IsPlayerGenericAdmin(int client)
{
    if (CheckCommandAccess(client, "generic_admin", ADMFLAG_GENERIC, false))
    {
        return true;
    }

    return false;
}  