#include <sourcemod>
#include <sdktools>
#include <colors>


#define PLUGIN_VERSION "1.2"
#define DEBUG 0
#define L4D_TEAM_SURVIVORS 2
#define L4D_TEAM_INFECTED 3
#define L4D_TEAM_SPECTATE 1

static bool:GameCodeLock;
static GameCode;
static GameCodeClient;
static OriginalTeam[MAXPLAYERS+1];

native Is_Ready_Plugin_On();
native IsInReady();
#define MIX_DELAY 5.0

new result_int;
new String:client_name[32]; // Used to store the client_name of the player who calls coinflip
new previous_timeC = 0; // Used for coinflip
new current_timeC = 0; // Used for coinflip
new previous_timeN = 0; // Used for picknumber
new current_timeN = 0; // Used for picknumber
new Handle:delay_time; // Handle for the coinflip_delay cvar
new number_max = 6; // Default maximum bound for picknumber
public Plugin:myinfo = 
{
	name = "L4D1 Game",
	author = "Harry Potter",
	description = "Let's play a game, Duel 決鬥!!",
	version = PLUGIN_VERSION,
	url = "myself"
}

public OnPluginStart()
{
	delay_time = CreateConVar("coinflip_delay","1", "Time delay in seconds between allowed coinflips. Set at -1 if no delay at all is desired.");
	
	RegConsoleCmd("say", Game_Say);
	RegConsoleCmd("say_team", Game_Say);

	RegConsoleCmd("sm_roll", Game_Roll);
	RegConsoleCmd("sm_picknumber", Game_Roll);
	RegConsoleCmd("sm_code", Game_Code);
	HookEvent("round_start", Event_Round_Start);
	RegConsoleCmd("sm_coinflip", Command_Coinflip);
	RegConsoleCmd("sm_coin", Command_Coinflip);
	RegConsoleCmd("sm_cf", Command_Coinflip);
	RegConsoleCmd("sm_flip", Command_Coinflip);
}

public OnMapStart()
{
	GameCodeLock = false;
}

public Event_Round_Start(Handle:event, String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		OriginalTeam[i] = 0;
	}
}

public OnClientPutInServer(client)
{
	OriginalTeam[client] = 0;	
}
public Action:Command_Coinflip(client, args)
{
	current_timeC = GetTime();
	
	if((current_timeC - previous_timeC) > GetConVarInt(delay_time)) // Only perform a coinflip if enough time has passed since the last one. This prevents spamming.
	{
		result_int = GetURandomInt() % 2; // Gets a random integer and checks to see whether it's odd or even
		GetClientName(client, client_name, sizeof(client_name)); // Gets the client_name of the person using the command
		
		new iTeam = GetClientTeam(client);
		if(result_int == 0){
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i) && GetClientTeam(i) == iTeam)
					CPrintToChat(i,"[{green}決鬥!{default}] {olive}%s{default} flipped a coin!. It's {green}Heads{default}!",client_name); // Here \x04 is actually yellow
			}
		}
		else{
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i) && GetClientTeam(i) == iTeam)
					CPrintToChat(i,"[{green}決鬥!{default}] {olive}%s{default} flipped a coin!. It's {green}Tails{default}!",client_name); // Here \x04 is actually yellow
			}
		}
		
		previous_timeC = current_timeC; // Update the previous time
	}
	else
	{
		ReplyToCommand(client, "[決鬥!] Whoa there buddy, slow down. Wait at least %d seconds.", GetConVarInt(delay_time));
	}
	
	return Plugin_Handled;
}

public Action:Game_Say(client, args)
{
	if (client == 0)
	{
		return Plugin_Continue;
	}
	if(args < 1 || !GameCodeLock)
	{
		return Plugin_Continue;
	}
	
	new String:arg1[64];
	GetCmdArg(1, arg1, 64);
	if(IsInteger(arg1))
	{
		new iTeam = GetClientTeam(client);
		new result = StringToInt(arg1);
		if(result == GameCode){
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i) && GetClientTeam(i) == iTeam)
					CPrintToChat(i,"[{green}決鬥!{default}] BINGO! {olive}%N {default}has guessed the right {olive}%N{default}'s code:{lightgreen} %d{default}. Cheer!",client,GameCodeClient,result);
			}
			GameCodeLock = false;
		}
		else if(result < GameCode){
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i) && GetClientTeam(i) == iTeam)
					CPrintToChat(i,"[{green}決鬥!{default}] {olive}%N {default}guessed {green}%d{default}. Code is greater than{default} it.",client,result);
			}
		}
		else if(result > GameCode)
		{
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i) && GetClientTeam(i) == iTeam)
					CPrintToChat(i,"[{green}決鬥!{default}] {olive}%N {default}guessed {green}%d{default}. Code is less than {default}it.",client,result);
			}
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:Game_Code(client, args)
{
	if (client == 0)
	{
		PrintToServer("[決鬥!] sm_code cannot be used by server.");
		return Plugin_Handled;
	}
	if(GameCodeLock)
	{
		ReplyToCommand(client, "[決鬥!] Someone has chosen a Da Vinci Code. Figure it out first!");		
		return Plugin_Handled;
	}
	if(args < 1)
	{
		ReplyToCommand(client, "[決鬥!] Usage: sm_code <0-100000> - Play a Da Vinci Code.");		
		return Plugin_Handled;
	}
	if(args > 1)
	{
		ReplyToCommand(client, "[決鬥!] Usage: sm_code <0-100000> - Play a Da Vinci Code.");		
		return Plugin_Handled;
	}
	
	new String:arg1[64];
	GetCmdArg(1, arg1, 64);
	if(IsInteger(arg1))
	{
		new iTeam = GetClientTeam(client);
		GameCode = StringToInt(arg1);
		if(GameCode > 100000|| GameCode < 0)
		{
			ReplyToCommand(client, "[決鬥!] Usage: sm_code <0-100000> - Play a Da Vinci Code.");
			return Plugin_Handled;
		}
		
		GameCodeClient = client;
		CPrintToChat(client,"[{green}決鬥!{default}] {default}You choose {lightgreen}%d{default} as code.",GameCode);
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i) && GetClientTeam(i) == iTeam)
				CPrintToChat(i,"[{green}決鬥!{default}] {olive}%N {default}has chosen a {green}Da Vinci Code{default}. Anyone Wants to guess it ?",client);
		}
		GameCodeLock = true;
		return Plugin_Handled;
	}
	else
	{
		ReplyToCommand(client, "[決鬥!] Usage: sm_code <0-100000> - Play a Da Vinci Code.");
		return Plugin_Handled;
	}
}

public Action:Game_Roll(client, args)
{
	if (client == 0)
	{
		PrintToServer("[決鬥!] sm_roll/sm_picknumber cannot be used by server.");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		current_timeN = GetTime();
		if((current_timeN - previous_timeN) > GetConVarInt(delay_time)) // Only perform a numberpick if enough time has passed since the last one.
		{
			current_timeN = GetTime();
			new iTeam = GetClientTeam(client);
			new result = GetRandomInt(1, number_max);
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i) && GetClientTeam(i) == iTeam)
					CPrintToChat(i,"[{green}決鬥!{default}] {olive}%N {default}rolled a {lightgreen}%d {default}sided die!. It's {green}%d{default}!",client,number_max,result);
			}
			previous_timeN = current_timeN; // Update the previous time
		}
		else
		{
			ReplyToCommand(client, "[決鬥!] Whoa there buddy, slow down. Wait at least %d seconds.", GetConVarInt(delay_time));
		}	
		return Plugin_Handled;
	}
	if(args > 1)
	{
		ReplyToCommand(client, "[決鬥!] Usage: sm_roll/sm_picknumber <Integer> - Play a Integer-sided dice.");		
		return Plugin_Handled;
	}
	
	new String:arg1[64];
	GetCmdArg(1, arg1, 64);
	if(IsInteger(arg1))
	{
		current_timeN = GetTime();
		
		if((current_timeN - previous_timeN) > GetConVarInt(delay_time)) // Only perform a numberpick if enough time has passed since the last one.
		{
			new iTeam = GetClientTeam(client);
			new side = StringToInt(arg1);
			if(side <= 0)
			{
				ReplyToCommand(client, "[決鬥!] Usage: sm_roll/sm_picknumber <Integer> - Play a Integer-sided dice.");	
				return Plugin_Handled;
			}
			
			new result = GetRandomInt(1, side);
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i) && GetClientTeam(i) == iTeam)
					CPrintToChat(i,"[{green}決鬥!{default}] {olive}%N {default}rolled a {lightgreen}%d {default}sided die!. It's {green}%d{default}!",client,side,result);
			}
			previous_timeN = current_timeN; // Update the previous time
		}
		else
		{
			ReplyToCommand(client, "[決鬥!] Whoa there buddy, slow down. Wait at least %d seconds.", GetConVarInt(delay_time));
		}
		return Plugin_Handled;
	}
	else
	{
		ReplyToCommand(client, "[決鬥!] Usage: sm_roll/sm_picknumber <Integer> - Play a Integer-sided dice.");
		return Plugin_Handled;
	}
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

public Action:Survivor_Take_Control(Handle:timer, any:client)
{
		new localClientTeam = GetClientTeam(client);
		new String:command[] = "sb_takecontrol";
		new flags = GetCommandFlags(command);
		SetCommandFlags(command, flags & ~FCVAR_CHEAT);
		new String:botNames[][] = { "teengirl", "manager", "namvet", "biker" };
		
		new i = 0;
		while((localClientTeam != 2) && i < 4)
		{
			FakeClientCommand(client, "sb_takecontrol %s", botNames[i]);
			localClientTeam = GetClientTeam(client);
			i++;
		}
		SetCommandFlags(command, flags);
}
