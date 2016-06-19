/** Double-include prevention */
#if defined _adminstealthredux_included_
  #endinput
#endif
#define _adminstealthredux_included_
 
/**
 * Check if the client is stealthed.
 *
 * @param client      Client index
 * @return            True if the client is stealthed | False otherwise.
 */
native bool ADMStealth_IsStealthed(int client);

/**
 * Toggle stealth mode for specific client.
 *
 * @param client      Client index
 * @param enabled     true - enable stealth mode | false - disable it
 * @param annotations true - enable annotations for the client(valid only when enabled=true) | false - No annotations 
 * @return            True if the client is successfully stealthed | False otherwise.
 */
native ADMStealth_ToggleStealth(int client, bool enabled, bool annotations);


/**
 * Toggle stealth mode for specific client.
 *
 * @param client      Client index
 * @param enabled     true - enable stealth mode | false - disable it
 * @param annotations true - enable annotations for the client(valid only when enabled=true) | false - No annotations 
 * @return            True if the client is stealthed | False otherwise.
 */
forward Action ADMStealth_OnToggle(int client, bool enabled, bool &annotations);



public SharedPlugin:__pl_NT_SetNTVOptional=
{
	name="Admin_Stealth_Redux",
	file="admin_stealth.smx",
	#if defined REQUIRE_PLUGIN
	required=1,
	#else
	required=0,
	#endif
};


#if !defined REQUIRE_PLUGIN
public __pl_NeutralTeamMode_SetNTVOptional()
{
	MarkNativeAsOptional("ADMStealth_IsStealthed");
	MarkNativeAsOptional("ADMStealth_ToggleStealth");
}
#endif