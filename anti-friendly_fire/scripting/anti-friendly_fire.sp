#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod>
#include <sdktools>

#define CLASSNAME_LENGTH 64
#define L4D_TEAM_SURVIVOR
enum CountdownTimer
{
	CTimer_Null = 0 /**< Invalid Timer when lookup fails */
}

ConVar g_hEnable;

public Plugin myinfo = 
{
	name = "anti-friendly_fire",
	author = "HarryPotter",
	description = "shoot teammate = shoot yourself",
	version = "1.1",
	url = "https://steamcommunity.com/id/fbef0102/"
}

public void OnPluginStart()
{
	g_hEnable = CreateConVar(	"anti_friendly_fire_enable", "1",
								"Enable anti-friendly_fire plugin [0-Disable,1-Enable]",
								FCVAR_NOTIFY, true, 0.0, true, 1.0 );
								
	HookEvent("player_hurt", Event_PlayerHurt);
}	

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) 
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(GetConVarBool(g_hEnable) == false || !IsClientAndInGame(attacker) || GetClientTeam(attacker) != 2 || !IsClientAndInGame(victim) || GetClientTeam(victim)!=2 || attacker == victim) { return Plugin_Continue; }
	
	int damage = GetEventInt(event, "dmg_health");
	char WeaponName[CLASSNAME_LENGTH];
	GetEventString(event, "weapon", WeaponName, sizeof(WeaponName));
	
	if(StrEqual(WeaponName, "inferno") || StrEqual(WeaponName, "pipe_bomb") || StrEqual(WeaponName, "fire_cracker_blast") || damage <=0) return Plugin_Continue;
	
	int health = GetEventInt(event, "health");
	SetEntityHealth(victim, health + damage);
	
	//PrintToChatAll("victim: %d,attacker:%d ,WeaponName is %s, damage is %f",victim,attacker,WeaponName,damage);
	
	float attackerPos[3];
	char strDamage[16],strDamageTarget[16];
	
	GetClientEyePosition(attacker, attackerPos);
	IntToString(damage, strDamage, sizeof(strDamage));
	Format(strDamageTarget, sizeof(strDamageTarget), "hurtme%d", attacker);
	
	int entPointHurt = CreateEntityByName("point_hurt");
	if(!entPointHurt) return Plugin_Continue;

	// Config, create point_hurt
	DispatchKeyValue(attacker, "targetname", strDamageTarget);
	DispatchKeyValue(entPointHurt, "DamageTarget", strDamageTarget);
	DispatchKeyValue(entPointHurt, "Damage", strDamage);
	DispatchKeyValue(entPointHurt, "DamageType", "anti-friendly_fire"); // DMG_GENERIC
	DispatchSpawn(entPointHurt);
	
	// Teleport, activate point_hurt
	TeleportEntity(entPointHurt, attackerPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entPointHurt, "Hurt", (attacker && attacker < 32 && IsClientInGame(attacker)) ? attacker : -1);
	
	// Config, delete point_hurt
	DispatchKeyValue(entPointHurt, "classname", "point_hurt");
	DispatchKeyValue(attacker, "targetname", "null");
	RemoveEdict(entPointHurt);
	
	return Plugin_Handled;
}

stock bool IsClientAndInGame(int client)
{
	if (0 < client && client < MaxClients)
	{	
		return IsClientInGame(client);
	}
	return false;
}