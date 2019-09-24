#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
Handle g_hEnable;
#define CLASSNAME_LENGTH 64

public Plugin myinfo = 
{
	name = "anti-friendly_fire",
	author = "HarryPotter",
	description = "shoot teammate = shoot yourself",
	version = "1.0",
	url = "https://steamcommunity.com/id/fbef0102/"
}

public void OnPluginStart()
{
	g_hEnable = CreateConVar(	"anti_friendly_fire_enable", "1",
								"Enable anti-friendly_fire plugin [0-Disable,1-Enable]",
								FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
}	

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if (GetConVarInt(g_hEnable) == 0 || !IsValidEdict(victim) || !IsValidEdict(attacker) || !IsValidEdict(inflictor) || GetConVarInt(FindConVar("god")) == 1 ) { return Plugin_Continue; }
	if(!IsClientAndInGame(attacker) || GetClientTeam(attacker) != 2 || !IsClientAndInGame(victim) || GetClientTeam(victim)!=2 || attacker == victim) { return Plugin_Continue; }
	
	char sClassname[CLASSNAME_LENGTH];
	GetEntityClassname(inflictor, sClassname, CLASSNAME_LENGTH);
	if(StrEqual(sClassname, "pipe_bomb_projectile") || damage <=0) return Plugin_Continue;
	
	//PrintToChatAll("victim: %d,attacker:%d ,sClassname is %s, damage is %f, victim health is %d",victim,attacker,sClassname,damage,GetClientHealth(victim));
	
	float attackerPos[3];
	char strDamage[16],strDamageTarget[16];
	
	GetClientEyePosition(attacker, attackerPos);
	FloatToString(damage, strDamage, sizeof(strDamage));
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

stock IsClientAndInGame(client)
{
	if (0 < client && client < MaxClients)
	{	
		return IsClientInGame(client);
	}
	return false;
}