/*version: 2.9*/
//add !zs, "Alive Survivor Suicide Command."

/*version: 2.8*/
//add three convars
//"l4d_afk_commands_immue_level", "z", "Access level needed to immune to all limit (Empty = Everyone, -1: Nobody)"
//"l4d_afk_commands_infected_attack_enable", "0", "If 1, player can change team when he is capped by special infected."
//"l4d_afk_commands_witch_attack_enable", "0", "If 1, player can change team when he is attacked by witch."
//"l4d_afk_commands_level", "0", "Access level needed to use command to switch team. (Empty = Everyone)"
//remove "l4d_afk_commands_adm_immue" and "l4d_afk_commands_adm_only convar.
//update afk signature

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

#define PLUGIN_VERSION    "2.9"
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
ConVar cvarCoolTime, cvarDeadChangeTeamEnable, cvarEnforceTeamSwitch, cvarCommandAccess, cvarSuicideAllow, 
	cvarImmueAccess, cvarInfectedAttackChangeTeamEnable, cvarWitchAttackChangeTeamEnable;
ConVar g_hGameMode;

//value
Handle arrayclientswitchteam;
static Handle hSetHumanSpec;
static Handle hTakeOver;
static Handle hAFKSDKCall;

static bool InCoolDownTime[MAXPLAYERS+1] = false;//是否還有換隊冷卻時間
static bool bClientJoinedTeam[MAXPLAYERS+1] = false; //在冷卻時間是否嘗試加入
static float g_iSpectatePenaltyCounter[MAXPLAYERS+1] ;//各自的冷卻時間
static bool clientBusyWitch[MAXPLAYERS+1];//是否被witch抓
static int WitchTarget[5000];//WitchTarget[妹子元素編號]=鎖定的玩家
static int clientteam[MAXPLAYERS+1];//玩家換隊成功之後的隊伍
static float fCoolTime;
char g_sImmueAcclvl[16], g_sCommandAccesslvl[16];
bool L4D2Version, bHasLeftSafeRoom;
bool bDeadChangeTeamEnable, bEnforceTeamSwitch, bSuicideAllow,
	bInfectedAttackerChangeTeamEnable, bWitchAttackChangeTeamEnable;
int iGameMode;
static Handle PlayerLeftStartTimer = null; //Detect player has left safe area or not

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "MasterMe,modify by Harry",
	description = "Adds commands to let the player spectate and join team. (!afk, !survivors, !infected, etc.), but no change team abuse",
	version = PLUGIN_VERSION,
	url = "Harry Potter School"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
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
	Handle hGameConf;	
	hGameConf = LoadGameConfigFile("l4d_afk_commands");
	if(hGameConf == null)
		SetFailState("Gamedata l4d_afk_commands.txt not found");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "SetHumanSpec");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	hSetHumanSpec = EndPrepSDKCall();
	if (hSetHumanSpec == null)
		SetFailState("Cant initialize SetHumanSpec SDKCall");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "TakeOverBot");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	hTakeOver = EndPrepSDKCall();
	if( hTakeOver == null)
		SetFailState("Could not prep the \"TakeOverBot\" function.");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTerrorPlayer::GoAwayFromKeyboard");
	hAFKSDKCall = EndPrepSDKCall();
	if(hAFKSDKCall == null)
		SetFailState("Unable to prep SDKCall 'CTerrorPlayer::GoAwayFromKeyboard'");

	delete hGameConf;

	LoadTranslations("common.phrases");
	RegConsoleCmd("sm_afk", TurnClientToSpectate);
	RegConsoleCmd("sm_s", TurnClientToSpectate);
	RegConsoleCmd("sm_jg", TurnClientToSurvivors);
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
	RegConsoleCmd("sm_zs", ForceSurvivorSuicide, "Alive Survivor Suicide Command.");

	cvarCoolTime = CreateConVar("l4d_afk_commands_changeteam_cooltime", "4.0", "Cold Down Time in seconds a player can't change team again.", FCVAR_NOTIFY, true, 1.0);
	cvarDeadChangeTeamEnable = CreateConVar("l4d_afk_commands_deadplayer_changeteam_enable", "0", "If 1, Dead Survivor Player can change team? (0:No, 1:Yes)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarEnforceTeamSwitch = CreateConVar("l4d_afk_commands_teamswitch_during_game_enable", "1", "If 1, player can use command to switch team during the game? (0:No, 1:Yes)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarImmueAccess = CreateConVar("l4d_afk_commands_immue_level", "z", "Access level needed to be immune to all limit (Empty = Everyone, -1: Nobody)", FCVAR_NOTIFY);
	cvarInfectedAttackChangeTeamEnable = CreateConVar("l4d_afk_commands_infected_attack_enable", "0", "If 1, player can change team when he is capped by special infected.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarWitchAttackChangeTeamEnable = CreateConVar("l4d_afk_commands_witch_attack_enable", "0", "If 1, player can change team when he is attacked by witch.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarCommandAccess = CreateConVar("l4d_afk_commands_level", "", "Access level needed to use command to switch team. (Empty = Everyone)", FCVAR_NOTIFY);
	cvarSuicideAllow = CreateConVar("l4d_afk_commands_suicide_allow", "0", "If 1, Allow alive survivor player suicides by using '!zs'", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	GetCvars();
	g_hGameMode = FindConVar("mp_gamemode");
	g_hGameMode.AddChangeHook(ConVarChange_CvarGameMode);
	cvarCoolTime.AddChangeHook(ConVarChanged_Cvars);
	cvarDeadChangeTeamEnable.AddChangeHook(ConVarChanged_Cvars);
	cvarEnforceTeamSwitch.AddChangeHook(ConVarChanged_Cvars);
	cvarImmueAccess.AddChangeHook(ConVarChanged_Cvars);
	cvarInfectedAttackChangeTeamEnable.AddChangeHook(ConVarChanged_Cvars);
	cvarWitchAttackChangeTeamEnable.AddChangeHook(ConVarChanged_Cvars);
	cvarCommandAccess.AddChangeHook(ConVarChanged_Cvars);
	cvarSuicideAllow.AddChangeHook(ConVarChanged_Cvars);
	
	HookEvent("witch_harasser_set", OnWitchWokeup);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerChangeTeam);
	HookEvent("player_spawn", Event_PlayerSpawn);

	Clear();

	arrayclientswitchteam = CreateArray(ByteCountToCells(STEAMID_SIZE));

	AutoExecConfig(true, "l4d_afk_commands");
}

public void OnMapStart()
{
	ClearArray(arrayclientswitchteam);
	GameModeCheck();
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

public Action ForceSurvivorSuicide(int client, int args)
{
	if (bSuicideAllow && client && GetClientTeam(client) == 2 && !IsFakeClient(client) && IsPlayerAlive(client))
	{
		if(bHasLeftSafeRoom == false)
		{
			PrintHintText(client, "[TS] 尚未離開安全區域禁止自殺. You wish!");
			return Plugin_Handled;
		}

		if(L4D2_GetInfectedAttacker(client) != -1)
		{
			PrintHintText(client, "[TS] 被控期間禁止自殺. In your dreams!");
			return Plugin_Handled;
		}
		
		if(clientBusyWitch[client])
		{
			PrintHintText(client, "[TS] Witch干擾期間禁止自殺. Not on your life!");
			return Plugin_Handled;
		}

		CPrintToChatAll("[{olive}TS{default}] {olive}%N {default}使用指令 {green}!zs{default} 自殺了!",client);
		ForcePlayerSuicide(client);
	}
	return Plugin_Handled;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) 
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if(!IsClientAndInGame(victim)) return;
	clientBusyWitch[victim] = false;

	if(!bEnforceTeamSwitch && IsClientInGame(victim) && !IsFakeClient(victim) && GetClientTeam(victim) == 2)
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
	if(!bEnforceTeamSwitch && player > 0 && player <=MaxClients && IsClientInGame(player) && !IsFakeClient(player) && GetClientTeam(player) == 2)
	{
		CreateTimer(2.0,checksurvivorspawn,player);		
	}
}

public Action checksurvivorspawn(Handle timer, int client)
{
	if(!bEnforceTeamSwitch && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
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
	if (!IsValidEdict(victim) || !IsValidEdict(attacker) || !IsValidEdict(inflictor) || !bHasLeftSafeRoom) { return Plugin_Continue; }
	
	if(GetClientTeam(victim) != 2 || !IsClientAndInGame(victim)) { return Plugin_Continue; }
	if(WitchTarget[attacker] == victim) { return Plugin_Continue; }
	char sClassname[64];
	GetEntityClassname(inflictor, sClassname, 64);
	if(StrEqual(sClassname, "witch"))
	{
		WitchTarget[attacker] = victim;
		clientBusyWitch[victim] = true;
		//PrintToChatAll("attacker: %d, victim: %d",attacker,victim);
		CreateTimer(0.25, TraceWitchAlive, attacker, TIMER_REPEAT);
	}
	return Plugin_Continue;
}

public Action OnWitchWokeup(Event event, const char[] name, bool dontBroadcast) 
{
	if(!bHasLeftSafeRoom) return;
	int client = GetClientOfUserId(event.GetInt("userid"));
	int witchid = event.GetInt("witchid");
	if(client > 0 && client <= MaxClients &&  IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		WitchTarget[witchid] = client;
		clientBusyWitch[client] = true;
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
		clientBusyWitch[witchtarget] = false;
		WitchTarget[entity] = -1;
		return Plugin_Stop;
	}
	clientBusyWitch[witchtarget] = true;
	return Plugin_Continue;
}

public Action Event_PlayerChangeTeam(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	CreateTimer(0.1, ClientReallyChangeTeam, client, _); // check delay
}

public void ConVarChange_CvarGameMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GameModeCheck();
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	bDeadChangeTeamEnable = cvarDeadChangeTeamEnable.BoolValue;
	bEnforceTeamSwitch = cvarEnforceTeamSwitch.BoolValue;
	bInfectedAttackerChangeTeamEnable = cvarInfectedAttackChangeTeamEnable.BoolValue;
	bWitchAttackChangeTeamEnable = cvarWitchAttackChangeTeamEnable.BoolValue;
	cvarImmueAccess.GetString(g_sImmueAcclvl,sizeof(g_sImmueAcclvl));
	cvarCommandAccess.GetString(g_sCommandAccesslvl,sizeof(g_sCommandAccesslvl));
	bSuicideAllow = cvarSuicideAllow.BoolValue;
	CheckSpectatePenalty();
}

static void CheckSpectatePenalty()
{
	if(cvarCoolTime.FloatValue <= 0.0) fCoolTime = 0.0;
	else fCoolTime = cvarCoolTime.FloatValue;
	
}
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	for (int i = 0; i < (GetArraySize(arrayclientswitchteam) / ARRAY_COUNT); i++) {
		SetArrayCell(arrayclientswitchteam, (i * ARRAY_COUNT) + ARRAY_TEAM, 0);
	}
	Clear();
	delete PlayerLeftStartTimer;
	PlayerLeftStartTimer = CreateTimer(1.0, PlayerLeftStart, _, TIMER_REPEAT);
}
public Action PlayerLeftStart(Handle Timer)
{
	if (LeftStartArea())
	{
		bHasLeftSafeRoom = true;
		PlayerLeftStartTimer = null;
		return Plugin_Stop;
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
			clientBusyWitch[i] = false;
			clientteam[i] = 0;
		}
		bHasLeftSafeRoom = false;
	}	
	else
	{
		InCoolDownTime[client] = false;
		bClientJoinedTeam[client] = false;
		clientBusyWitch[client] = false;
		clientteam[client] = 0;
	}
}

public Action TurnClientToSpectate(int client, int argCount)
{
	if (client == 0)
	{
		PrintToServer("[TS] command cannot be used by server.");
		return Plugin_Handled;
	}
	if(IsClientIdle(client))
	{
		PrintHintText(client, "[TS] 你正在閒置中.");
		return Plugin_Handled;
	}
	if(HasCommand_Access(client) == false)
	{
		PrintHintText(client, "[TS] 你沒有權限換隊.");
		return Plugin_Handled;
	}

	int iTeam = GetClientTeam(client);
	if(iTeam != 1)
	{
		if(CanClientChangeTeam(client,1) == false) return Plugin_Handled;
		
		if(iTeam == 2 && IsPlayerAlive(client) && iGameMode != 2) SDKCall(hAFKSDKCall, client);
		else ChangeClientTeam(client, 1);
		
		clientteam[client] = 1;
		StartChangeTeamCoolDown(client);
	}
	else
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
	if (GetClientTeam(client) == 2)			//if client is survivor
	{
		PrintHintText(client, "[TS] 你已經在人類隊伍了.");
		return Plugin_Handled;
	}
	if (IsClientIdle(client))
	{
		PrintHintText(client, "[TS] 你正在閒置中. 請按左鍵遊玩倖存者.");
		return Plugin_Handled;
	}
	if(HasCommand_Access(client) == false)
	{
		PrintHintText(client, "[TS] 你沒有權限換隊.");
		return Plugin_Handled;
	}

	if(CanClientChangeTeam(client,2) == false) return Plugin_Handled;
	
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
		int bot = FindBotToTakeOver(true)	;
		if (bot==0)
		{
			bot = FindBotToTakeOver(false);
		}
		if(iGameMode != 2) //coop/survival
		{
			if(IsPlayerAlive(bot))
			{
				SDKCall(hSetHumanSpec, bot, client);
			}
			else
			{
				SDKCall(hSetHumanSpec, bot, client);
				SDKCall(hTakeOver, client, true);	
				clientteam[client] = 2;	
				StartChangeTeamCoolDown(client);
			}
		}
		else //versus
		{
			SDKCall(hSetHumanSpec, bot, client);
			SDKCall(hTakeOver, client, true);
			clientteam[client] = 2;	
			StartChangeTeamCoolDown(client);
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
	if (GetClientTeam(client) == 3)			//if client is Infected
	{
		PrintHintText(client, "[TS] 你已經在特感隊伍了.");
		return Plugin_Handled;
	}
	if(HasCommand_Access(client) == false)
	{
		PrintHintText(client, "[TS] 你沒有權限換隊.");
		return Plugin_Handled;
	}

	if(CanClientChangeTeam(client,3)  == false) return Plugin_Handled;

	int maxInfectedSlots = GetTeamMaxSlots(3);
	int infectedUsedSlots = GetTeamHumanCount(3);
	int freeInfectedSlots = (maxInfectedSlots - infectedUsedSlots);
	if (freeInfectedSlots <= 0)
	{
		PrintHintText(client, "[TS] 特感隊伍已滿.");
		return Plugin_Handled;
	}
	if(iGameMode != 2)
	{
		return Plugin_Handled;
	}
	
	ChangeClientTeam(client, 3);clientteam[client] = 3;
	
	StartChangeTeamCoolDown(client);
	
	return Plugin_Handled;
}
	
public Action Survivor_Take_Control(Handle timer, int client)
{
	char command[] = "sb_takecontrol";
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "sb_takecontrol");
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

	if(CanClientChangeTeam(client,5)  == false) return Plugin_Handled;
	
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
			TurnClientToSurvivors(client,0);
			return Plugin_Handled;
		}
		else if(iteam == 3)
		{
			TurnClientToInfected(client,0);
			return Plugin_Handled;
		}
		else if(iteam == 1)
		{
			TurnClientToSpectate(client,0);
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

	if(CanClientChangeTeam(client,1) == false) return Plugin_Handled;
	
	clientteam[client] = 1;
	StartChangeTeamCoolDown(client);
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

bool IsClientIdle(int client)
{
	if(GetClientTeam(client) != 1)
		return false;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
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
	if(IsClientConnected(bot) && IsClientInGame(bot) && IsFakeClient(bot) && GetClientTeam(bot) == 2 && IsPlayerAlive(bot))
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

bool CanClientChangeTeam(int client, int changeteam)
{ 
	if(bHasLeftSafeRoom == false || HasImmueLimit_Access(client)) return true;

	if ( L4D2_GetInfectedAttacker(client) != -1 && bInfectedAttackerChangeTeamEnable == false)
	{
		PrintHintText(client, "[TS] 特感抓住期間禁止換隊.");
		return false;
	}	
	if( clientBusyWitch[client] && bWitchAttackChangeTeamEnable == false)
	{
		PrintHintText(client, "[TS] Witch干擾期間禁止換隊.");
		return false;
	}
	
	if(InCoolDownTime[client])
	{
		bClientJoinedTeam[client] = true;
		CPrintToChat(client, "[{olive}TS{default}] 無法快速換隊! 請等待 {green}%.0f {default}秒.", g_iSpectatePenaltyCounter[client]);
		return false;
	}

	if(GetClientTeam(client) == 2 && IsPlayerAlive(client) == false && bDeadChangeTeamEnable == false)
	{
		PrintHintText(client, "[TS] 死亡倖存者禁止換隊.");
		return false;
	}

	if(bEnforceTeamSwitch == false && bHasLeftSafeRoom && GetClientTeam(client) != 1 && changeteam != 1) 
	{
		CPrintToChat(client, "[{olive}TS{default}] 遊戲開始後{green}禁止跳隊{default}!!");
		return false;
	}
	return true;
}

void StartChangeTeamCoolDown(int client)
{
	if( InCoolDownTime[client] || bHasLeftSafeRoom == false || HasImmueLimit_Access(client)) return;

	if(fCoolTime > 0.0)
	{
		InCoolDownTime[client] = true;
		g_iSpectatePenaltyCounter[client] = fCoolTime;
		CreateTimer(0.25, Timer_CanJoin, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action ClientReallyChangeTeam(Handle timer, int client)
{
	if(!IsClientAndInGame(client)||IsFakeClient(client)) return;
	if(HasImmueLimit_Access(client)) return;

	if(bEnforceTeamSwitch == false)
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
				if(!bHasLeftSafeRoom || oldteam == 0)
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
							CPrintToChat(client,"[{olive}TS{default}] 請回到 {green}%s {default}隊伍, 遊戲開始後{red}禁止跳隊{default}!!",(oldteam == 2) ? "倖存者" : "特感");
						}
					}
				}
			}		
		}
	}
	
	if(bHasLeftSafeRoom && InCoolDownTime[client]) return;
	
	//PrintToChatAll("client: %N change Team: %d clientteam[client]:%d",client,GetClientTeam(client),clientteam[client]);
	if(GetClientTeam(client) != clientteam[client])
	{
		if(clientteam[client] != 0) StartChangeTeamCoolDown(client);
		clientteam[client] = GetClientTeam(client);		
	}
}

public Action Timer_CanJoin(Handle timer, int client)
{
	if (!InCoolDownTime[client] || 
	!IsClientInGame(client) || 
	IsFakeClient(client))//if client disconnected or is fake client or take a break on player bot
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
		g_iSpectatePenaltyCounter[client] = fCoolTime;
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

public bool HasImmueLimit_Access(int client)
{
	// no permissions set
	if (strlen(g_sImmueAcclvl) == 0)
		return true;

	else if (StrEqual(g_sImmueAcclvl, "-1"))
		return false;

	// check permissions
	if (GetUserFlagBits(client) & ReadFlagString(g_sImmueAcclvl) == 0)
	{
		return false;
	}

	return true;
}

public bool HasCommand_Access(int client)
{
	// no permissions set
	if (strlen(g_sCommandAccesslvl) == 0)
		return true;

	// check permissions
	if (GetUserFlagBits(client) & ReadFlagString(g_sCommandAccesslvl) == 0)
	{
		return false;
	}

	return true;
}

void GameModeCheck()
{
	char GameName[16];
	g_hGameMode.GetString(GameName,sizeof(GameName));
	if (StrEqual(GameName, "survival", false))
		iGameMode = 3;
	else if (StrEqual(GameName, "versus", false) || StrEqual(GameName, "teamversus", false) || StrEqual(GameName, "scavenge", false) || StrEqual(GameName, "teamscavenge", false) || StrEqual(GameName, "mutation12", false) || StrEqual(GameName, "mutation13", false) || StrEqual(GameName, "mutation15", false) || StrEqual(GameName, "mutation11", false))
		iGameMode = 2;
	else if (StrEqual(GameName, "coop", false) || StrEqual(GameName, "realism", false) || StrEqual(GameName, "mutation3", false) || StrEqual(GameName, "mutation9", false) || StrEqual(GameName, "mutation1", false) || StrEqual(GameName, "mutation7", false) || StrEqual(GameName, "mutation10", false) || StrEqual(GameName, "mutation2", false) || StrEqual(GameName, "mutation4", false) || StrEqual(GameName, "mutation5", false) || StrEqual(GameName, "mutation14", false))
		iGameMode = 1;
	else
		iGameMode = 1;
}