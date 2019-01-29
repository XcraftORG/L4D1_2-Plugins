#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#define PLUGIN_VERSION "1.5"

#define		DN_TAG		"[DHostName]"
#define		SYMBOL_LEFT		'('
#define		SYMBOL_RIGHT	')'

static		Handle:g_hHostName, Handle:g_hReadyUp, String:g_sDefaultN[68];

public Plugin:myinfo = 
{
	name = "L4D Dynamic中文伺服器名",
	author = "Harry Potter",
	description = "Show what mode is it now on chinese server name with txt file",
	version = PLUGIN_VERSION,
	url = "myself"
}

public OnPluginStart()
{
	g_hReadyUp = CreateConVar("l4d_current_mode", "", "League notice displayed on server name", FCVAR_SPONLY | FCVAR_NOTIFY);
	g_hHostName	= FindConVar("hostname");
	GetConVarString(g_hHostName, g_sDefaultN, sizeof(g_sDefaultN));
	if (strlen(g_sDefaultN))//strlen():回傳字串的長度
		ChangeServerName();
}

public OnConfigsExecuted()
{		
	if (!strlen(g_sDefaultN)) return;
		

	if (g_hReadyUp == INVALID_HANDLE){
	
		ChangeServerName();
		LogMessage("l4d_current_mode no found!");
	}
	else {
	
		decl String:sReadyUpCfgName[128];
		GetConVarString(g_hReadyUp, sReadyUpCfgName, 128);

		ChangeServerName(sReadyUpCfgName);
	}
	
}

ChangeServerName(String:sReadyUpCfgName[] = "")
{

        new String:sPath[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, sPath, sizeof(sPath),"configs/hostname/server_hostname.txt");//檔案路徑設定
        
        new Handle:file = OpenFile(sPath, "r");//讀取檔案
        if(file == INVALID_HANDLE)
		{
			LogMessage("file configs/hostname/server_hostname.txt doesn't exist!");
			return;
		}
        
        new String:readData[256];
        if(!IsEndOfFile(file) && ReadFileLine(file, readData, sizeof(readData)))//讀一行
        {
			decl String:sNewName[128];
			if(strlen(sReadyUpCfgName) == 0)
				Format(sNewName, sizeof(sNewName), "%s", readData);
			else
				Format(sNewName, sizeof(sNewName), "%s%c%s%c", readData, SYMBOL_LEFT, sReadyUpCfgName, SYMBOL_RIGHT);
			
			SetConVarString(g_hHostName,sNewName);
			LogMessage("%s New server name \"%s\"", DN_TAG, sNewName);
			
			Format(g_sDefaultN,sizeof(g_sDefaultN),"%s",sNewName);
        }
}
