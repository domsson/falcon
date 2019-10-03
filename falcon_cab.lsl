// CONSTS
integer DEBUG = TRUE;
integer CHANNEL = -130104;
string  SIGNATURE = "falcon-cab";

string SIG_CONTROLLER = "falcon-control";

integer NOT_FOUND = -1; // ll* functions often return -1 to indicate 'not found'
float   FLOAT_MAX = 3.402823466E+38;

integer MSG_IDX_SIG    = 0;
integer MSG_IDX_IDENT  = 1;
integer MSG_IDX_CMD    = 2;
integer MSG_IDX_PARAMS = 3;

integer IDENT_IDX_BANK  = 0;
integer IDENT_IDX_SHAFT = 1;
integer IDENT_IDX_FLOOR = 2;

// description identifiers
// 0: bank, 1: shaft, 2: floor
list identifiers;

// important objects/ids
key uuid = NULL_KEY;
key owner = NULL_KEY;
key controller = NULL_KEY;

// state etc
integer listen_handle;
string current_state;

/*
 * Debug output `msg` via llOwnerSay if the global variable DEBUG is TRUE
 */
debug(string msg)
{
    if (DEBUG)
    {
        llOwnerSay(llGetScriptName() + "@" + llGetObjectName() + ": " + msg);
    }
}

/*
 * Parses an identifier string into a list of 3 elements, using `sep` 
 * as the separator to split the string into tokens. See these examples:
 * - parse_ident("bank1:shaft1:7", ":") => ["bank1", "shaft1", "7"]
 * - parse_ident("bank1", ":")          => ["bank1", "", ""]
 * - parse_ident("bank1::4, ":")        => ["bank1", "", "4"]
 * - parse_ident("", ":")               => ["", "", ""]
 */
list parse_ident(string ident, string sep)
{
    list tks = llParseString2List(ident, [sep], []);
    return [llList2String(tks, 0), llList2String(tks, 1), llList2String(tks, 2)];
}

process_message(integer chan, string name, key id, string msg)
{
    // Debug print the received message
    debug(" < `" + msg + "`");
    
    // Get details about the sender
    list details = llGetObjectDetails(id, ([OBJECT_NAME, OBJECT_DESC, 
                                            OBJECT_POS, OBJECT_ROT, OBJECT_OWNER]));
   
    // Abort if the message came from someone else's object
    if (owner != llList2Key(details, 4))
    {
        return;
    }
    
    // Split the message on spaces and extract the first two tokens
    list    tokens     = llParseString2List(msg, [" "], []);
    integer num_tokens = llGetListLength(tokens);
    string  signature  = llList2String(tokens, MSG_IDX_SIG);
    string  ident      = llList2String(tokens, MSG_IDX_IDENT);
    string  command    = llList2String(tokens, MSG_IDX_CMD);
    list    params     = llList2List(tokens, MSG_IDX_PARAMS, num_tokens - 1);
    
    // Abort if the message didn't come from a controller
    if (signature != SIG_CONTROLLER)
    {
        return;
    }
    
    if (command == "ping")
    {
        handle_cmd_ping(signature, id, ident);
        return;
    }
    
    if (command == "pair")
    {
        handle_cmd_pair(signature, id, ident);
        return;
    }
    
    if (command == "status")
    {
        handle_cmd_status(signature, id, ident);
        return;
    }
}

integer ident_matches(list ident1, list ident2, integer idx)
{
    return llList2String(ident1, idx) == llList2String(ident2, idx);
}

handle_cmd_ping(string sig, key id, string ident)
{
    // Abort if `bank` doesn't match
    if (!ident_matches(identifiers, parse_ident(ident, ":"), IDENT_IDX_BANK))
    {
        return;
    }
    
    send_message(id, "pong", []);
}

handle_cmd_pair(string sig, key id, string ident)
{
    // Abort if `bank` doesn't match
    if (!ident_matches(identifiers, parse_ident(ident, ":"), IDENT_IDX_BANK))
    {
        return;
    }

    // We weren't paired yet, let's do it now
    if (controller == NULL_KEY)
    {
        set_controller(id);
        state paired;
    }
    
    // We were already paired, just let the controller know
    send_message(id, "status", [current_state, (string) controller]);
}

handle_cmd_status(string sig, key id, string ident)
{
    send_message(id, "status", [current_state, (string) controller]);
}

/*
 * Send a message to the object with UUID `id`.
 * Note: this function depends on the globals `SIGNATURE`, `CHANNEL`
 *       and `identifiers`.
 */ 
send_message(key id, string cmd, list params)
{
    list msg = [SIGNATURE, llDumpList2String(identifiers, ":"),
                cmd,  llDumpList2String(params, " ")];
    llRegionSayTo(id, CHANNEL, llDumpList2String(msg, " "));
}
 
set_controller(key id)
{
    controller = id;
}

integer init()
{
    uuid = llGetKey();
    owner = llGetOwner();
    identifiers = parse_ident(llGetObjectDesc(), ":");
    
    llSetLinkPrimitiveParamsFast(LINK_SET,  [PRIM_SCRIPTED_SIT_ONLY, TRUE]);
    llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_PHYSICS_SHAPE_TYPE, PRIM_PHYSICS_SHAPE_CONVEX]);
    
    return TRUE;
}

default
{
    state_entry()
    {
        current_state = "default";
        init();
        state booted;
    }
    
    state_exit()
    {
        // Nothing yet
    }
}

/*
 * Only basic initialization has been done, neither pairing not setup has been 
 * performed yet. In this state, we're waiting for a `pair` request from the  
 * controller. We're also going to listen to `ping` and `status` messages.
 */
state booted
{
    state_entry()
    {
        current_state = "booted";
    
        // We can't inform the controller of our status change as we don't 
        // have a reference to the controller yet
    
        // We're waiting for a `ping`, `pair` or `status` by the controller
        listen_handle = llListen(CHANNEL, "", NULL_KEY, "");
    }
     
    listen(integer channel, string name, key id, string message)
    {
        process_message(channel, name, id, message);
    }
    
    state_exit()
    {
        // Nothing yet
    }
}

/*
 * We've been paired with a controller. In this state, we're waiting for setup
 * instructions by the controller. We're also listening to `ping` and similar 
 * messages, of course.
 */
state paired
{
    state_entry()
    {
        current_state = "paired";
        
        // We inform the controller of our status change
        send_message(controller, "status", ["paired", (string) controller]);
        
        // We could only listen for messages by the controller as we now know 
        // its UUID; however, that could get us stuck if the controller UUID 
        // ever changes to to re-rez or region restart or what-not
        listen_handle = llListen(CHANNEL, "", NULL_KEY, "");
    }
    
    listen(integer channel, string name, key id, string message)
    {
        process_message(channel, name, id, message);
    }
    
    state_exit()
    {
    }
}
