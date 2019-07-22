#include <sourcemod>
#include <sdktools>
#include <builtinvotes>
#include <colors>

//#pragma newdecls required
#pragma semicolon 1

#define MAX_CAMPAIGN_LIMIT 64

public Plugin myinfo =
{
	name = "Vote Custom Campaign",
	author = "Harry Potter",
	description = "Vote for custom campaign",
	version = "1.0",
	url = "https://steamcommunity.com/id/fbef0102"
};

/**
 * Globals
 */
int g_iCount;
char g_sMapinfo[MAX_CAMPAIGN_LIMIT][MAX_NAME_LENGTH];
char g_sMapname[MAX_CAMPAIGN_LIMIT][MAX_NAME_LENGTH];
char votemapinfo[MAX_NAME_LENGTH];
char votemapname[MAX_NAME_LENGTH];

Handle g_hVoteMenu;
KeyValues g_kvCampaigns;

ConVar g_hEnabled;
ConVar g_hMenuLeaveTime;
ConVar g_hVotePercent;
ConVar g_hPassPercent;


/**
 * Plugin Forwards
 */
public void OnPluginStart()
{
	char game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead2") && !StrEqual(game_name, "left4dead"))
	{
		SetFailState("<VCC> Enable only for left4dead or left4dead2 only.");
	}
	
	RegConsoleCmd("sm_vcc", Command_VoteCampaign, "Show custom campaigns menu");
	RegConsoleCmd("sm_map", Command_VoteCampaign, "Show custom campaigns menu");
	RegConsoleCmd("sm_votemap", Command_VoteCampaign, "Show custom campaigns menu");
	RegConsoleCmd("sm_vm", Command_VoteCampaign, "Show custom campaigns menu");
	RegConsoleCmd("sm_changemap", Command_VoteCampaign, "Show custom campaigns menu");
	RegConsoleCmd("sm_cm", Command_VoteCampaign, "Show custom campaigns menu");

	g_hEnabled = CreateConVar("vcc_enable", "1", "启用、关闭第三方地图投票插件", FCVAR_NOTIFY);
	g_hMenuLeaveTime = CreateConVar("vcc_menu_leavetime", "20", "After this time(second) the menu should leave.", FCVAR_NOTIFY);
	g_hVotePercent = CreateConVar("vcc_vote_percent", "0.60", "Votes reaching this percent of clients(no-spec) can a vote result.", FCVAR_NOTIFY);
	g_hPassPercent = CreateConVar("vcc_pass_percent", "0.60", "Approvals reaching this percent of votes can a vote pass.", FCVAR_NOTIFY);
	
	//ParseCampaigns();
}

public void OnMapStart()
{
	ParseCampaigns();
}


/**
 * Commands
 */
public Action Command_VoteCampaign(int client, int args) 
{ 
	if (!g_hEnabled.BoolValue) { return Plugin_Handled; }
	if (!IsClientValid(client)) { return Plugin_Handled; }
	
	Menu menu = CreateMenu(MapMenuHandler);
	menu.SetTitle( "▲ Vote Custom Campaigns <%d map%s>", g_iCount, ((g_iCount > 1) ? "s": "") );
	
	for (int i = 0; i < g_iCount; i++)
	{
		menu.AddItem(g_sMapinfo[i], g_sMapname[i]);
	}
	
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}


/**
 * Menu Handlers
 */
public int MapMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	if ( action == MenuAction_Select ) 
	{
		GetMenuItem(menu,
				itemNum,
				votemapinfo, sizeof(votemapinfo),
				_,
				votemapname, sizeof(votemapname));
				
		DisplayVoteMapsMenu(client);
	}
}

void DisplayVoteMapsMenu(int client)
{
	if (GetClientTeam(client) == 1)
	{
		CPrintToChat(client, "{green}<{default}VCC{green}> {olive}Spectator {default}cannot vote.");
		return;
	}
	if (IsBuiltinVoteInProgress())
	{
		CPrintToChat(client, "{green}<{default}VCC{green}> {default}There has been a vote in progress.");
		return;
	}
	if (CheckBuiltinVoteDelay() > 0)
	{
		CPrintToChat(client, "{green}<{default}VCC{green}> {default}Wait for another {olive}%ds {default}to toggle a vote.", CheckBuiltinVoteDelay());
		return;
	}
	
	g_hVoteMenu = CreateBuiltinVote(CallBack_VoteProgress, BuiltinVoteType_ChgCampaign, BuiltinVoteAction_Select|BuiltinVoteAction_Cancel|BuiltinVoteAction_End);
	
	CPrintToChatAll("{green}<{default}VCC{green}> {default}Player {lightgreen}%N {default}toggles a vote for {olive}custom campaign", client, votemapname);
	SetBuiltinVoteArgument(g_hVoteMenu, votemapname);
	SetBuiltinVoteInitiator(g_hVoteMenu, client);
	
	SetBuiltinVoteResultCallback(g_hVoteMenu, CallBack_VoteResult);
	DisplayBuiltinVoteToAllNonSpectators(g_hVoteMenu, g_hMenuLeaveTime.IntValue);
	FakeClientCommand(client, "Vote Yes");
}


/**
 * Menu CallBacks
 */
public CallBack_VoteProgress(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	if (action == BuiltinVoteAction_Select)
	{
		switch (param2)
		{
			case 0: { PrintToConsoleAll_YA("<VCC> Player %N vote for the campaign change.", param1); }
			case 1: { PrintToConsoleAll_YA("<VCC> Player %N vote against the campaign change.", param1); }
		}
	}
	else if (action == BuiltinVoteAction_Cancel)
	{
		DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
	}
	else if (action == BuiltinVoteAction_End)
	{
		CloseHandle(g_hVoteMenu);
		g_hVoteMenu = INVALID_HANDLE;
	}
}

public CallBack_VoteResult(Handle vote, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2])
{
	if ( float(num_votes) / float(num_clients) < g_hVotePercent.FloatValue)
	{
		DisplayBuiltinVoteFail(vote, BuiltinVoteFail_NotEnoughVotes);
		return;
	}
	
	int votey = 0;
	for (int i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{ votey = item_info[i][BUILTINVOTEINFO_ITEM_VOTES]; }
	}
	
	if ( float(votey) / float(num_votes) >= g_hPassPercent.FloatValue )
	{
		CreateTimer(0.7, Timer_PrintCampaignChanging);
		CreateTimer(4.7, Timer_Changelevel);
	}
	else
	{
		DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	}
}


/**
 * Timers
 */
public Action Timer_PrintCampaignChanging(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientValid(i))
		{
			CPrintToChat(i, "{green}<{default}VCC{green}> Map changing... >>> %s", votemapname);
		}
	}
}

public Action Timer_Changelevel(Handle timer)
{
	ServerCommand("changelevel %s", votemapinfo);
}


/**
 * Stocks
 */
bool IsClientValid(int client)
{
	if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
	{return true;} else {return false;}
}

void PrintToConsoleAll_YA(const char[] format, any ...)
{
	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientValid(i)) { PrintToConsole(i, buffer); }
	}
}


/**
 * Misc
 */
void ParseCampaigns()
{
	delete g_kvCampaigns;
	g_kvCampaigns = CreateKeyValues("VoteCustomCampaigns");

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/VoteCustomCampaigns.txt");

	if ( !FileToKeyValues(g_kvCampaigns, sPath) ) 
	{
		SetFailState("<VCC> Am I a joke to you? %s", sPath);
		return;
	}
	
	if (!g_kvCampaigns.GotoFirstSubKey())
	{
		SetFailState("<VCC> File Not write anything: you idiot noob!");
		return;
	}
	
	for (int i = 0; i < MAX_CAMPAIGN_LIMIT; i++)
	{
		g_kvCampaigns.GetString("mapinfo", g_sMapinfo[i], sizeof(g_sMapinfo));
		g_kvCampaigns.GetString("mapname", g_sMapname[i], sizeof(g_sMapname));
		
		if ( !g_kvCampaigns.GotoNextKey() )
		{
			g_iCount = ++i;
			break;
		}
	}
	
	/*  // previous, being normal
	int i = 0;
	
	if ( g_kvCampaigns.GotoFirstSubKey(false) )
	{
		do
		{
			g_kvCampaigns.GetString("mapinfo", g_sMapinfo[i], sizeof(g_sMapinfo));
			g_kvCampaigns.GetString("mapname", g_sMapname[i], sizeof(g_sMapname));
			
			i++
		}
		while ( g_kvCampaigns.GotoNextKey(false) )
	}
	
	g_iCount = i;
	*/
}

