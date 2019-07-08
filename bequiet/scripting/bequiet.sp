#include <sourcemod>
#include <sdktools>
#include <basecomm>

public Plugin:myinfo = 
{
	name = "BeQuiet",
	author = "Sir & Harry Potter",
	description = "Please be Quiet! Block unnecessary chat or announcement",
	version = "1.4",
	url = "https://github.com/SirPlease/SirCoding"
}

new UserMsg:g_umSayText2;

public OnPluginStart()
{
	AddCommandListener(Say_Callback, "say");
	AddCommandListener(TeamSay_Callback, "say_team");

	//Server CVar
	HookEvent("server_cvar", Event_ServerDontNeedPrint, EventHookMode_Pre);
	
	g_umSayText2 = GetUserMessageId("SayText2");
	HookUserMessage(g_umSayText2, UserMessageHook, true);
}

public Action:Say_Callback(client, const String:command[], argc)
{
	decl String:sayWord[MAX_NAME_LENGTH];
	GetCmdArg(1, sayWord, sizeof(sayWord));
	
	if(sayWord[0] == '!' || sayWord[0] == '/')
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:TeamSay_Callback(client, const String:command[], argc)
{
	decl String:sayWord[MAX_NAME_LENGTH];
	GetCmdArg(1, sayWord, sizeof(sayWord));
	
	if(sayWord[0] == '!' || sayWord[0] == '/')
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}


public Action:Event_ServerDontNeedPrint(Handle:event, const String:name[], bool:dontBroadcast)
{
    return Plugin_Handled;
}

public Action:UserMessageHook(UserMsg:msg_hd, Handle:bf, const players[], playersNum, bool:reliable, bool:init)
{

	decl String:_sMessage[96];
	BfReadString(bf, _sMessage, sizeof(_sMessage));
	BfReadString(bf, _sMessage, sizeof(_sMessage));

	if(StrContains(_sMessage, "Name_Change") != -1)
	{
		BfReadString(bf, _sMessage, sizeof(_sMessage));

		for(new i = 1; i <= MaxClients; i++)
			if(IsClientInGame(i))
				return Plugin_Handled;
	}

	return Plugin_Continue;
}