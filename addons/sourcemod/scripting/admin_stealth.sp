#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

//Defines
#define PLUGIN_VERSION "1.6.1"
#define JOIN_MESSAGE "Player %N has joined the game"
#define QUIT_MESSAGE "Player %N left the game (Disconnected by user.)"
#define STEALTHTEAM 0
#define PLAYER_MANAGER "tf_player_manager"


//Cvars and etc
new bool:g_bIsInvisible[MAXPLAYERS+1];
new g_iOldTeam[MAXPLAYERS+1];
new Float:nextStatus[MAXPLAYERS+1];
new Float:nextPing[MAXPLAYERS+1];
new Handle:g_hHostname;
new Handle:g_hTags;
new Handle:g_hTVEnabled;
new Handle:g_hTVDelay;
new Handle:g_hTVPort;
new Handle:g_hIpAddr;
new Handle:g_hIpPort;
new serverVer;
new bool:registered;

public Plugin:myinfo = 
{
	name = "Admin Stealth REDUX",
	author = "necavi and Naydef (new developer)",
	description = "Allows administrators to become nearly completely invisible.",
	version = PLUGIN_VERSION,
	url = "http://necavi.org/"
}

public OnPluginStart()
{
	CreateConVar("sm_adminstealth_version", PLUGIN_VERSION, "Admin-Stealth version cvar", FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_DONTRECORD);
	RegAdminCmd("sm_stealth", Command_Stealth, ADMFLAG_CUSTOM3, "Allows an administrator to toggle complete invisibility on themselves.");
	g_hHostname = FindConVar("hostname");
	g_hTags = FindConVar("sv_tags");
	g_hTVEnabled = FindConVar("tv_enable");
	g_hTVDelay = FindConVar("tv_delay");
	g_hTVPort = FindConVar("tv_port");
	g_hIpAddr = FindConVar("hostip");
	g_hIpPort = FindConVar("hostport");
	new String:buffer[32];
	GetConVarString(FindConVar("sv_registration_message"), buffer, sizeof(buffer));
	if(buffer[0]=='\0')
	{
		registered=true;
	}
	serverVer=GetSteamINFNum();
	AddCommandListener(Command_JoinTeamOrClass, "jointeam");
	AddCommandListener(Command_JoinTeamOrClass, "joinclass");
	AddCommandListener(Command_JoinTeamOrClass, "autoteam");
	AddCommandListener(Command_Status, "status");
	AddCommandListener(Command_Ping, "ping");
	for(new i=1; i<=MaxClients; i++)
	{
		if(ValidPlayer(i))
		{
			SDKHook(i, SDKHook_SetTransmit, Hook_Transmit);
		}
	}
	new TF2PManager=FindEntityByClassname(-1, PLAYER_MANAGER);
	if(IsValidEntity(TF2PManager)) // Why SDKHook doesn't have a native to test if the entity is already hooked?
	{
		SDKHook(TF2PManager, SDKHook_ThinkPost, Hook_ThinkPost);
	}
	HookEvent("player_disconnect", Event_StealthAdminDisconnect, EventHookMode_Pre);  
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	if(!IsTF2())
	{
		strcopy(error, err_max, "This version of the plugin is currently only for Team Fortress 2! Remove the plugin!");
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_SetTransmit, Hook_Transmit);
	g_bIsInvisible[client]=false;
	nextStatus[client]=0.0;
	nextPing[client]=0.0;
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_SetTransmit, Hook_Transmit);
}

public OnEntityCreated(entity, const String:classname[])
{
	if(StrEqual(classname, PLAYER_MANAGER, false))
	{
		SDKHook(entity, SDKHook_SpawnPost, Hook_SpawnPost);
	}
}

public Action:Hook_SpawnPost(entity)
{
	if(IsValidEntity(entity))
	{
		SDKHook(entity, SDKHook_ThinkPost, Hook_ThinkPost);
	}
	return Plugin_Continue;
}

public Hook_ThinkPost(entity)
{
	for(new i=1; i<=MaxClients; i++)
	{
		if(ValidPlayer(i) && g_bIsInvisible[i])
		{
			SetEntProp(entity, Prop_Send, "m_bConnected", false, _, i);
		}
	}
}

public Action:Command_JoinTeamOrClass(client, const String:command[], args)  
{ 
	if(g_bIsInvisible[client])
	{
		PrintToChat(client, "[SM] Can not join team or class when in stealth mode!");
		return Plugin_Handled;
	}
	else 
	{ 
		return Plugin_Continue; 
	} 
}

public Action:Event_StealthAdminDisconnect(Handle:event, const String:name[], bool:dontBroadCast)
{
	new client=GetClientOfUserId(GetEventInt(event, "userid"));
	if(ValidPlayer(client) && g_bIsInvisible[client]) return Plugin_Handled;
	return Plugin_Continue;
}

public Action:Command_Status(client, const String:command[], args)
{
	if(!ValidPlayer(client) || CheckCommandAccess(client, "sm_stealth", 0)) // Console will now work!!!
	{
		return Plugin_Continue;
	}
	if(nextStatus[client]<=GetGameTime())
	{
		new String:buffer[128];
		new Float:vec[3];
		GetConVarString(g_hHostname, buffer, sizeof(buffer));
		PrintToConsole(client, "hostname: %s", buffer);
		PrintToConsole(client, "version : %i/24 %i secure", serverVer, serverVer);
		ServerIP(buffer, sizeof(buffer));
		PrintToConsole(client, "upd/ip  :  %s:%i (public ip: %s)", buffer, GetConVarInt(g_hIpPort), buffer);
		GetCurrentMap(buffer, sizeof(buffer));
		GetClientAbsOrigin(client, vec);
		(registered) ? PrintToConsole(client, "account  : logged in") : PrintToConsole(client, "account  :  not logged in (No account specified)");
		PrintToConsole(client, "map     : %s at: %.0f x, %.0f y, %.0f z", buffer, vec[0], vec[1], vec[2]);
		GetConVarString(g_hTags, buffer, sizeof(buffer));
		PrintToConsole(client, "tags    : %s", buffer);
		if(GetConVarBool(g_hTVEnabled))
		{
			PrintToConsole(client, "sourcetv:  port %i, delay %.1fs", GetConVarInt(g_hTVPort), GetConVarFloat(g_hTVDelay));
		}
		PrintToConsole(client, "players : %i humans (%i max)", GetClientCount()-GetInvisCount(), MaxClients);
		PrintToConsole(client, "edicts  : %i used of %i max", GetUsedEntities()-GetInvisCount(), GetMaxEntities());
		PrintToConsole(client, "# userid name                uniqueid            connected ping loss state");
		new String:name[MAX_NAME_LENGTH];
		new String:steamID[24];
		new String:time[12];
		for(new i=1; i <= MaxClients; i++)
		{
			if(IsClientConnected(i))
			{
				if(!g_bIsInvisible[i])
				{
					Format(name,sizeof(name),"\"%N\"",i);
					GetClientAuthId(i, AuthId_Steam3, steamID, sizeof(steamID));
					if(!IsFakeClient(i))
					{
						FormatShortTime(RoundToFloor(GetClientTime(i)), time, sizeof(time));
						PrintToConsole(client, "# %6d %-19s %19s %9s %4d %4d %s", GetClientUserId(i), 
						name, steamID, time, RoundToFloor(GetClientAvgLatency(i, NetFlow_Both) * 1000.0), 
						RoundToFloor(GetClientAvgLoss(i, NetFlow_Both) * 100.0), (IsClientInGame(i) ? "active" : "spawning"));
					} 
					else 
					{
						PrintToConsole(client, "# %6d %-19s %19s                     %s", GetClientUserId(i), name, steamID, (IsClientInGame(i) ? "active" : "spawning"));
					}
				}
			}
		}
		nextStatus[client]=GetGameTime()+5.0;
	}
	return Plugin_Handled;
}

public Action:Command_Ping(client, const String:command[], args)
{
    if(!ValidPlayer(client) || CheckCommandAccess(client, "sm_stealth", 0)) // Console will now work!!!
	{
		return Plugin_Continue;
	}
	if(nextPing[client]<=GetGameTime())
	{
	    PrintToConsole(client, "Client ping times:");
		for(new i=1; i<=MaxClients; i++)
		{
		    if(ValidPlayer(i) && !g_bIsInvisible[i])
			{
			    PrintToConsole(client, " %i ms : %N", RoundToFloor(GetClientAvgLatency(i, NetFlow_Both) * 1000.0, i);
			}
		}
		nextPing[client]=GetGameTime()+5.0;
	}
	return Plugin_Handled;
}

public Action:Command_Stealth(client, args)
{
	if(!ValidPlayer(client))
	{
		PrintToServer("You cannot run this command!!!");
	}
	else
	{
		ToggleInvis(client);
		LogAction(client, -1, "%N has toggled stealth mode.", client);
	}
	return Plugin_Handled;
}

ToggleInvis(client)
{
    (g_bIsInvisible[client]) ? InvisOff(client) : InvisOn(client);
}

InvisOff(client, announce=true)
{
	g_bIsInvisible[client] = false;
	SetEntProp(client, Prop_Send, "m_lifeState", 2);
	ChangeClientTeam(client, g_iOldTeam[client]);
	SetEntityMoveType(client, MOVETYPE_ISOMETRIC);
	SetEntProp(client, Prop_Data, "m_takedamage", 2);
	new String:buffer[MAX_NAME_LENGTH];
	GetClientInfo(client, "name", buffer, sizeof(buffer));
	//SilentNameChange(client, buffer);
	if(announce)
	{
		PrintToChatAll(JOIN_MESSAGE, client);
	}
	PrintToChat(client, "You are no longer in stealth mode.");

}

InvisOn(client, announce=true)
{
	TF2_RemoveAllWeapons(client);
	new entity=-1;
	while((entity=FindEntityByClassname2(entity, "tf_wear*"))!=-1)
	{
		if(IsValidEntity(entity) && (GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")==client))
		{
			TF2_RemoveWearable(client, entity);
		}
	}
	g_bIsInvisible[client]=true;
	g_iOldTeam[client]=Arena_GetClientTeam(client);
	SetEntProp(client, Prop_Send, "m_lifeState", 2);
	ChangeClientTeam(client, STEALTHTEAM);
	SetEntityMoveType(client, MOVETYPE_NOCLIP);
	SetEntProp(client, Prop_Data, "m_takedamage", 0);
	if(announce)
	{
		PrintToChatAll(QUIT_MESSAGE, client);
	}
	//SilentNameChange(client, "");
	PrintToChat(client, "You are now in stealth mode.");

}

public Action:Hook_Transmit(entity, client)
{
	if(ValidPlayer(entity) && g_bIsInvisible[entity] && entity != client)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
	
}

bool:ValidPlayer(client)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		return true;
	}
	return false;
}

FormatShortTime(time, String:outTime[], size)
{
	new temp;
	temp = time % 60;
	Format(outTime, size,"%02d",temp);
	temp = (time % 3600) / 60;
	Format(outTime, size,"%02d:%s", temp, outTime);
	temp = (time % 86400) / 3600;
	if(temp > 0)
	{
		Format(outTime, size, "%d%:s", temp, outTime);

	}
}

GetInvisCount()
{
	new count = 0;
	for(new i; i <= MaxClients; i++)
	{
		if(ValidPlayer(i) && g_bIsInvisible[i])
		{
			count++;
		}
	}
	return count;
}

bool:IsTF2()
{
	return (GetEngineVersion()==Engine_TF2) ?  true : false;
}

Arena_GetClientTeam(entity) //Also works on entities!
{
	return (IsValidEntity(entity)) ? (GetEntProp(entity, Prop_Send, "m_iTeamNum")) : (-1);
}

stock FindEntityByClassname2(startEnt, const String:classname[])
{
	while(startEnt>-1 && !IsValidEntity(startEnt))
	{
		startEnt--;
	}
	return FindEntityByClassname(startEnt, classname);
}

//Credit: pilger
stock GetSteamINFNum(String:search[]="ServerVersion")
{
	new String:file[16]="./steam.inf", String:inf_buffer[64]; //It's not worth using decl
	new Handle:file_h=OpenFile(file, "r");
	
	do
	{
		if(!ReadFileLine(file_h, inf_buffer, sizeof(inf_buffer)))
		{
			return -1;
		}
		TrimString(inf_buffer);
	}
	while(StrContains(inf_buffer, search, false) < 0);
	CloseHandle(file_h);

	return StringToInt(inf_buffer[strlen(search)+1]);
}

stock GetUsedEntities()
{
	new count=0;
	for(new i=0; i<=GetMaxEntities(); i++)
	{
		if(IsValidEntity(i))
		{
			count++;
		}
	}
	return count;
}

/*
stock SilentNameChange(client, const String:newname[])
{
	//decl String:oldname[MAX_NAME_LENGTH];
	//GetClientName(client, oldname, sizeof(oldname));

	SetClientInfo(client, "name", newname);
	SetEntPropString(client, Prop_Data, "m_szNetname", newname);

	new Handle:event = CreateEvent("player_changename");

	if(event != INVALID_HANDLE)
	{
		SetEventInt(event, "userid", GetClientUserId(client));
		//SetEventString(event, "oldname", oldname);
		SetEventString(event, "newname", newname);
		FireEvent(event);
	}
}
*/

//https://forums.alliedmods.net/showpost.php?p=495342&postcount=14
ServerIP(String:buffer[], size)
{
	new pieces[4];
	new longip = GetConVarInt(g_hIpAddr);
	
	pieces[0] = (longip >> 24) & 0x000000FF;
	pieces[1] = (longip >> 16) & 0x000000FF;
	pieces[2] = (longip >> 8) & 0x000000FF;
	pieces[3] = longip & 0x000000FF;

	Format(buffer, size, "%d.%d.%d.%d", pieces[0], pieces[1], pieces[2], pieces[3]);
}

/*
FindServerStringId(string, size) //Why?
{
	new String:buffer[1024];
	new String:buffer1[10][512]
	ServerCommandEx("status", buffer, sizeof(buffer));
	new contains=StrContains(buffer, "steamid : ");
	if(contains>-1)
	{
		for(new i=contains; i<=1024; i++)
		{
			if(buffer[i]==')')
			{
				ExplodeString()
			}
		}
	}
}
*/