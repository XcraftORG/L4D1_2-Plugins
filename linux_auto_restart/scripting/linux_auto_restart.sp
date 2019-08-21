#include <sourcemod>

public Plugin:myinfo =
{
	name = "L4D linux auto restart",
	author = "Harry Potter",
	description = "make linux auto restart server when the last player disconnects from the server",
	version = "1.0",
	url = "http://forums.alliedmods.net/showthread.php?t=84086"
};


public OnClientDisconnect(client)
{
	ServerCommand("sm_cvar sb_all_bot_team 1");
	if(IsClientConnected(client)&&!IsClientInGame(client)) return; //連線中尚未進來的玩家離線
	if(client&&!IsFakeClient(client)&&!checkrealplayerinSV(client)) //檢查是否還有玩家以外的人還在伺服器或是連線中
		CreateTimer(20.0,COLD_DOWN);
}
public Action:COLD_DOWN(Handle:timer,any:client)
{
	if(checkrealplayerinSV(0)) return;
	
	ServerCommand("sv_cheats 1");
	ServerCommand("sv_crash");//crash server, make linux auto restart server
	LogMessage("Last one player left the server, Restart server now");
}

bool:checkrealplayerinSV(client)
{
	for (new i = 1; i < MaxClients+1; i++)
		if(IsClientConnected(i)&&!IsFakeClient(i)&&i!=client)
			return true;
	return false;
}