#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <basecomm>

public Plugin myinfo =
{
	name = "No Team Chat",
	author = "bullet28, HarryPotter",
	description = "Redirecting all 'say_team' messages to 'say' in order to remove (Survivor) prefix when it's useless",
	version = "2.0",
	url = "https://forums.alliedmods.net/showthread.php?p=2691314"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead2 && test != Engine_Left4Dead)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	
	return APLRes_Success; 
}

ConVar cvarIgnoreList;
char ignoreList[16][16];

public void OnPluginStart() {
	cvarIgnoreList = CreateConVar("noteamsay_ignorelist", "!/@", "Messages starting with this will be ignored, separate by | symbol", FCVAR_NONE);
	cvarIgnoreList.AddChangeHook(OnConVarChange);
	
	AutoExecConfig(true, "lfd_noTeamSay");
}

public void OnConVarChange(ConVar convar, char[] oldValue, char[] newValue) {
	char buffer[256];
	cvarIgnoreList.GetString(buffer, sizeof buffer);
	for (int i = 0; i < sizeof ignoreList; i++) ignoreList[i] = "";
	ExplodeString(buffer, "|", ignoreList, sizeof ignoreList, sizeof ignoreList[]);
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs) {
	
	if (!StrEqual(command, "say_team", false))
		return Plugin_Continue;

	if (client <= 0)
		return Plugin_Continue;

	if(BaseComm_IsClientGagged(client) == true) //this client has been gagged
		return Plugin_Stop;	

	for (int i = 0; i < sizeof ignoreList; i++) {
		if (ignoreList[i][0] != EOS && StrContains(sArgs, ignoreList[i]) == 0) {
			return Plugin_Continue;
		}
	}

	char buffer[512];
	Format(buffer, sizeof(buffer), "\x03%N\x01 :  %s", client, sArgs);

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			SayText2(i, client, buffer);
		}
	}

	return Plugin_Stop;
}

void SayText2(int client, int sender, const char[] msg) {
	Handle hMessage = StartMessageOne("SayText2", client);
	if (hMessage != null) {
		BfWriteByte(hMessage, sender);
		BfWriteByte(hMessage, true);
		BfWriteString(hMessage, msg);
		EndMessage();
	}
}
