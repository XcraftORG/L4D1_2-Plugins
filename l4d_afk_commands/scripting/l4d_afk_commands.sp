/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * [L4D(2)] AFK and Join Team Commands (1.1)                                     *
 *                                                                               *
 * V 1.1 - Easy Editing and Changelog.                                           *
 * Added a changelog on this topic and in the .SP file.                          *
 * Added a editing guide for adding/removing commands in the .SP file.           *
 *                                                                               *
 * V 1.0 - Initial Release :                                                     *
 * Changelog starts here on the .SP file and on the site.                        *
 *                                                                               *
 * V Beta - Tested on my server:                                                 *
 * Creating/Testing the plugin on my server and in PawnStudio.                   * 
 *                                                                               *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * EDITING THE COMMANDS:                                                         *
 * Scroll down a bit, and you'll see for example a line like this:               *
 *                                                                               *
 * "RegConsoleCmd("sm_afk", AFKTurnClientToSpectate);"                           *
 *                                                                               *
 * Broken apart:                                                                 *
 * "RegConsoleCmd" The command to make a command.                                *
 * "("sm_afk"...                                                                 *
 * "sm_afk" is the command, anything which you type in chat with a '!' or        *
 * "/" before it MUST start with "sm_", after "sm_" you put the word.            *
 * Example: "sm_imgoingtospectate", if you wanna use that command,               *
 * you have to type "!imgoingtospectate" in the console.                         *
 *                                                                               *
 * Yet, after "("sm_afk"" there's something else...                              *
 * "("sm_afk", AFKTurnClientToSpectate);                                         *
 * If you look deeper into the code, you see:                                    *
 * public Action:AFKTurnClientToSpectate(client, argCount)                       *
 * What's between the '(' and ')' doesn't matter for you.                        *
 * Basicly, "AFKTurnClientToSpectate" if a name to forward to.                   *
 * You have:                                                                     *
 *                                                                               *
 * -AFKTurnClientToSpectate : Moves the client to spectator team.                *
 * -AFKTurnClientToSurvivors : Moves the client to infected team.                *
 * -AFKTurnClientToInfected : Moves the client to survivors team.                *
 *                                                                               *
 * So, you want for example, when you type "!imgoingafk" in chat,                *
 * you want to go spectate...                                                    *
 *                                                                               *
 * RegConsoleCmd ("sm_imgoingafk", AFKTurnClientToSpectate);                     *
 * Remember to place the ';' behind it!                                          *
 *                                                                               *
 * Now you want, when you type "!iwannaplayinfected" in chat,                    *
 * you want to go infected...                                                    *
 *                                                                               *
 * RegConsoleCmd ("sm_iwannaplayinfected", AFKTurnClientToInfected);             *
 * Again, make sure to place the ';' behind it.                                  *
 *                                                                               *
 * So, that's how to custimize it! Have fun with this, and                       *
 * when you like it, please leave behind a message on the forum topic.           *
 *                                                                               *
 * Remember, editing it correctly is safe, check if your line is like the others *
 * and you'll be fine, after editing, go to:                                     *
 * "MODDIR/addons/sourcemod/scripting" and paste the .SP file in there.          *
 * Then drag the .SP file into "compile.exe" and let it compile.                 *
 * Then go to the "compiled" folder and voilla, your edited plugin is there!     *
 *                                                                               *
 * NOTE: if you edit the plugin wrong, it won't compile or with errors...        *
 * * * * * *                                                           * * * * * *
 * NOTE: This is CASE-SENSITIVE!                                                 *
 * so: "!ImGoingToSpectate" isn't the same as "!imgoingtospectate"...            *
 * And doing so won't make it work...                                            *
 * Since people like to type everything in Lower-Case, i'd advise you to do too. *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * End of Commentry, editing behind these few lines may lead to a non working,   *
 * unstable plugin causing crashes or  bugs, editing at own risk.                *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#define PLUGIN_VERSION    "1.6"
#define PLUGIN_NAME       "[L4D(2)] AFK and Join Team Commands"

#include <sourcemod>
#include <sdktools>
#include <colors>

static InCoolDownTime[MAXPLAYERS+1] = false;//是否能加入
static Float:CoolTime;
static Handle:cvarCoolTime					= INVALID_HANDLE;
static bool:bClientJoinedTeam[MAXPLAYERS+1] = false; //在冷卻時間是否嘗試加入
static Float:g_iSpectatePenaltyCounter[MAXPLAYERS+1]  ;//各自的冷卻時間
static bool:clientBusy[MAXPLAYERS+1];//被特感抓住期間是否能換隊
static bool:b_IsL4D2;
#define ZOMBIECLASS_CHARGER	6
static ChargerGot;
static Handle:cvarDeadChangeTeamEnable					= INVALID_HANDLE;
static DeadChangeTeamEnable;
new Handle:g_hGameMode;
new String:CvarGameMode[20];

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "MasterMe,modify by Harry",
	description = "Adds commands to let the player spectate and join team. (!afk, !survivors, !infected, etc.),but no abuse",
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


	RegConsoleCmd("sm_afk", AFKTurnClientToSpectate);
	RegConsoleCmd("sm_s", AFKTurnClientToSpectate);
	RegConsoleCmd("sm_join", AFKTurnClientToSurvivors);
	RegConsoleCmd("sm_bot", AFKTurnClientToSurvivors);
	RegConsoleCmd("sm_away", AFKTurnClientToSpectate);
	RegConsoleCmd("sm_idle", AFKTurnClientToSpectate);
	RegConsoleCmd("sm_spectate", AFKTurnClientToSpectate);
	RegConsoleCmd("sm_spec", AFKTurnClientToSpectate);
	RegConsoleCmd("sm_spectators", AFKTurnClientToSpectate);
	RegConsoleCmd("sm_joinspectators", AFKTurnClientToSpectate);
	RegConsoleCmd("sm_jointeam1", AFKTurnClientToSpectate)
	RegConsoleCmd("sm_survivors", AFKTurnClientToSurvivors);
	RegConsoleCmd("sm_survivor", AFKTurnClientToSurvivors);
	RegConsoleCmd("sm_sur", AFKTurnClientToSurvivors);
	RegConsoleCmd("sm_joinsurvivors", AFKTurnClientToSurvivors);
	RegConsoleCmd("sm_jointeam2", AFKTurnClientToSurvivors);
	RegConsoleCmd("sm_infected", AFKTurnClientToInfected);
	RegConsoleCmd("sm_inf", AFKTurnClientToInfected);
	RegConsoleCmd("sm_joininfected", AFKTurnClientToInfected);
	RegConsoleCmd("sm_jointeam3", AFKTurnClientToInfected);
	
	RegConsoleCmd("jointeam", WTF);
	RegConsoleCmd("go_away_from_keyboard", WTF2);

	cvarCoolTime = CreateConVar("l4d2_spectate_cooltime", "4.0", "Time in seconds an sur/inf player can't rejoin the sur/inf team.", FCVAR_NOTIFY);
	cvarDeadChangeTeamEnable = CreateConVar("l4d2_deadplayer_changeteam", "0", "Can Dead Survivor Player change team? (0:No, 1:Yes)", FCVAR_NOTIFY);
	
	DeadChangeTeamEnable = GetConVarBool(cvarDeadChangeTeamEnable);
	
	HookConVarChange(cvarCoolTime, ConVarChange_cvarCoolTime);
	HookConVarChange(cvarDeadChangeTeamEnable, ConVarChange_cvarDeadChangeTeamEnable);
	
	HookEvent("lunge_pounce", Event_Survivor_GOT);
	HookEvent("tongue_grab", Event_Survivor_GOT);
	HookEvent("pounce_stopped", Event_Survivor_RELEASE);
	HookEvent("tongue_release", Event_Survivor_RELEASE);
	if(b_IsL4D2)
	{
		HookEvent("charger_carry_start", Event_Survivor_GOT);
		HookEvent("jockey_ride", Event_Survivor_GOT);
		HookEvent("charger_pummel_end", Event_Survivor_RELEASE);
		HookEvent("jockey_ride_end", Event_Survivor_RELEASE);
	}
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death",		Event_PlayerDeath);
	
	//HookEvent("player_bot_replace", OnPlayerBotReplace);

	
	CheckSpectatePenalty();
	
	g_hGameMode = FindConVar("mp_gamemode");
	GetConVarString(g_hGameMode,CvarGameMode,sizeof(CvarGameMode));
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsClientAndInGame(client)) return;
	clientBusy[client] = false;
	
	if(GetClientTeam(client) == 3 && GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_CHARGER && ChargerGot > 0)
	{
		clientBusy[ChargerGot] = false;
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
		ChargerGot = victim;
	}
}
public Event_Survivor_RELEASE (Handle:event, const String:name[], bool:dontBroadcast)
{
	//PrintToChatAll("release");
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	
	clientBusy[victim] = false;
}

public ConVarChange_cvarCoolTime(Handle:convar, const String:oldValue[], const String:newValue[])
{
	CheckSpectatePenalty();
}

public ConVarChange_cvarDeadChangeTeamEnable(Handle:convar, const String:oldValue[], const String:newValue[])
{
	DeadChangeTeamEnable = StringToInt(newValue);
}

static CheckSpectatePenalty()
{
	if(GetConVarFloat(cvarCoolTime) < -1.0) CoolTime = -1.0;
	else CoolTime = GetConVarFloat(cvarCoolTime);
	
	ChargerGot = 0;
	new i;
	for(i = 1; i <= MaxClients; i++)
	{	
		g_iSpectatePenaltyCounter[i] = CoolTime;
		InCoolDownTime[i] = false;
		bClientJoinedTeam[i] = false;
		clientBusy[i] = false;
	}
	
}
public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	CheckSpectatePenalty();
}

public OnRoundStart()
{
	CheckSpectatePenalty();
}


//When a bot replaces a player (i.e. player switches to spectate or infected)
//public Action:OnPlayerBotReplace(Handle:event, const String:name[], bool:dontBroadcast)
//{
//	new client = GetClientOfUserId(GetEventInt(event, "player"));
//	InCoolDownTime[client] = true;
//}


public Action:Timer_CanJoin(Handle:timer, any:client)
{
	
	if (!InCoolDownTime[client] || !IsClientInGame(client) || IsFakeClient(client)) return Plugin_Stop; //if client disconnected or is fake client

	
	
	if (g_iSpectatePenaltyCounter[client] != 0)
	{
		g_iSpectatePenaltyCounter[client]-=0.5;
		if(GetClientTeam(client)!=1)
		{	
			bClientJoinedTeam[client] = true;
			CPrintToChat(client, "{default}[{olive}TS{default}] Wait {green}%.0fs {default}to rejoin team again.", g_iSpectatePenaltyCounter[client]);
			ChangeClientTeam(client, 1);
			return Plugin_Continue;
		}
	}
	else if (g_iSpectatePenaltyCounter[client] <= 0)
	{
		if(GetClientTeam(client)!=1)
		{	
			bClientJoinedTeam[client] = true;
			CPrintToChat(client, "{default}[{olive}TS{default}] Wait {green}%.0fs {default}to rejoin team again.", g_iSpectatePenaltyCounter[client]);
			ChangeClientTeam(client, 1);
		}
		if (GetClientTeam(client) == 1 && bClientJoinedTeam[client])
		{
			CPrintToChat(client, "{default}[{olive}TS{default}] You can join team now.");	//only print this hint text to the spectator if he tried to join team, and got swapped before
		}
		InCoolDownTime[client] = false;
		bClientJoinedTeam[client] = false;
		g_iSpectatePenaltyCounter[client] = CoolTime;
		return Plugin_Stop;
	}
	
	
	return Plugin_Continue;
}


public Action:AFKTurnClientToSpectate(client, argCount)
{
	if (client == 0)
	{
		PrintToServer("[TS] command cannot be used by server.");
		return Plugin_Handled;
	}
	if(GetClientTeam(client) != 1)
	{
		if(GetClientTeam(client) == 2)
		{
			if(!PlayerIsAlive(client)&&!DeadChangeTeamEnable)
			{
				CPrintToChat(client, "{default}[{olive}TS{default}] 死亡倖存者禁止換隊.");
				return Plugin_Handled;
			}
			if (clientBusy[client])
			{
				CPrintToChat(client, "{default}[{olive}TS{default}] 特感抓住期間禁止換隊.");
				return Plugin_Handled;
			}
		
			FakeClientCommand(client, "go_away_from_keyboard");
		}
		
		if (GetClientTeam(client) != 1)
			ChangeClientTeam(client, 1);
			
		if(CoolTime > -1.0)
		{
			InCoolDownTime[client] = true;
			CreateTimer(0.5, Timer_CanJoin, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE); // Start unpause countdown
		}
	}
	return Plugin_Handled;
}


public Action:AFKTurnClientToSurvivors(client, args)
{ 
	if (client == 0)
	{
		PrintToServer("[TS] command cannot be used by server.");
		return Plugin_Handled;
	}
	if (GetClientTeam(client) == 2)			//if client is survivor
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] You are already on the Survivor team.");
		return Plugin_Handled;
	}
	if(InCoolDownTime[client])
	{
		bClientJoinedTeam[client] = true;
		CPrintToChat(client, "{default}[{olive}TS{default}] Wait {green}%.0fs {default}to rejoin team again.", g_iSpectatePenaltyCounter[client]);
		return Plugin_Handled;
	}
	
	new maxSurvivorSlots = GetTeamMaxHumans(2);
	new survivorUsedSlots = GetTeamHumanCount(2);
	new freeSurvivorSlots = (maxSurvivorSlots - survivorUsedSlots);
	//debug
	//PrintToChatAll("Number of Survivor Slots %d.\nNumber of Survivor Players %d.\nNumber of Free Slots %d.", maxSurvivorSlots, survivorUsedSlots, freeSurvivorSlots);
	
	if (freeSurvivorSlots <= 0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] Survivor team is full.");
		return Plugin_Handled;
	}
	else
	{
		if(StrEqual(CvarGameMode,"coop")||StrEqual(CvarGameMode,"survival"))
		{
			if(!IsClientConnected(client))
				return Plugin_Handled;
		
			if(IsClientInGame(client))
			{
				if (GetClientTeam(client) == 3)			//if client is infected
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
					CreateTimer(0.1, Survivor_Take_Control, client, TIMER_FLAG_NO_MAPCHANGE);
					
				}
				else if(GetClientTeam(client) == 2)
				{	
					if(DispatchKeyValue(client, "classname", "player") == true)
					{
						PrintHintText(client, "You are allready joined the Survivor team");
					}
					else if((DispatchKeyValue(client, "classname", "info_survivor_position") == true) && !IsAlive(client))
					{
						PrintHintText(client, "Please wait to be revived or rescued");
					}
				}
				else if(IsClientIdle(client))
				{
					PrintHintText(client, "You are now idle. Press mouse to play as survivor");
				}
				else
				{	
					TakeOverBot(client);			
				}
			}	
		}
		else if(StrEqual(CvarGameMode,"versus")||StrEqual(CvarGameMode,"scavenge"))
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
			CreateTimer(0.1, Survivor_Take_Control, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return Plugin_Handled;
}

public Action:AFKTurnClientToInfected(client, args)
{ 
	if (client == 0)
	{
		PrintToServer("[TS] command cannot be used by server.");
		return Plugin_Handled;
	}
	if (GetClientTeam(client) == 3)			//if client is Infected
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] You are already on the Infected team.");
		return Plugin_Handled;
	}
	if (clientBusy[client])
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] 特感抓住期間禁止換隊.");
		return Plugin_Handled;
	}
	ChangeClientTeam(client, 3);
	return Plugin_Handled;
}


public OnClientPutInServer(client)
{
	g_iSpectatePenaltyCounter[client] = CoolTime;
	InCoolDownTime[client] = false;
	bClientJoinedTeam[client] = false;
	clientBusy[client] = false;
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

public Action:WTF(client, args)
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
	
	if (clientBusy[client])
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] 特感抓住期間禁止換隊.");
		return Plugin_Handled;
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

bool:PlayerIsAlive (client)
{
	if (!GetEntProp(client,Prop_Send, "m_lifeState"))
		return true;
	return false;
}

public Action:Timer_AutoJoinTeam(Handle:timer, any:client)
{
	if(!IsClientConnected(client))
		return Plugin_Stop;
	
	if(IsClientInGame(client))
	{
		if(GetClientTeam(client) == 2)
			return Plugin_Stop;
		if(IsClientIdle(client))
			return Plugin_Stop;
		
		AFKTurnClientToSurvivors(client, 0);
	}
	return Plugin_Continue;
}

stock TakeOverBot(client)
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
		hGameConf = LoadGameConfigFile("l4dmultislots");
		
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
