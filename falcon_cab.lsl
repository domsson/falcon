// CONSTS
integer DEBUG = TRUE;
string  SIGNATURE = "falcon-cab";
integer CHANNEL = -130104;
integer NOT_FOUND = -1; // ll* functions often return -1 to indicate 'not found'

integer listen_handle;

// description identifiers
// 0: bank, 1: shaft, 2: floor
list identifiers;

// important objects/ids
key owner = NULL_KEY;
key controller = NULL_KEY;

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
 * Parses the object's description string into a list of 3 elements, using `sep` 
 * as the separator to split the string into tokens. See these examples:
 * - parse_desc("bank1:cab1:7", ":") => ["bank1", "cab1", "7"]
 * - parse_desc("bank1", ":")        => ["bank1", "", ""]
 * - parse_desc("bank1::4, ":")      => ["bank1", "", "4"]
 * - parse_desc("", ":")             => ["", "", ""]
 */
list parse_desc(string sep)
{
    list tks = llParseString2List(llGetObjectDesc(), [sep], []);
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
    string  signature  = llList2String(tokens, 0);   
    string  command    = llList2String(tokens, 1);
    list    parameters = llList2List(tokens, 2, num_tokens - 1);
    
    if (command == "ping")
    {
        handle_cmd_ping(signature, id, parameters);
    }
}

handle_cmd_ping(string sig, key id, list params)
{
    if (sig != "falcon-control")
    {
        return;
    }
    
    if (llList2String(params, 0) != llList2String(identifiers, 0))
    {
        return;
    }
    
    set_controller(id);
    send_message(id, "pong", "");
}
 
/*
 * Send a message to the object with UUID `id`.
 */ 
send_message(key id, string cmd, string params)
{
    string msg = SIGNATURE + " " + cmd + " " + params;
    //debug(" > `" + msg + "`");
    llRegionSayTo(id, CHANNEL, msg);
}

/*
 * Broadcast a message to all objects in the region.
 */
send_broadcast(string cmd, string params)
{
    string msg = SIGNATURE + " " + cmd + " " + params;
    //debug(" >> `" + msg + "`");
    llRegionSay(CHANNEL, msg);
}
 
set_controller(key id)
{
    controller = id;
}

integer init()
{
    owner = llGetOwner();
    identifiers = parse_desc(":");
    
    llSetLinkPrimitiveParamsFast(LINK_SET,  [PRIM_SCRIPTED_SIT_ONLY, TRUE]);
    llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_PHYSICS_SHAPE_TYPE, PRIM_PHYSICS_SHAPE_CONVEX]);
    
    return TRUE;
}

default
{
    state_entry()
    {
        init();
        state uninitialized;
    }
    
    state_exit()
    {
        // Nothing yet
    }
}

state uninitialized
{
    state_entry()
    {
        // We're specifically listening for a ping by the controller
        listen_handle = llListen(CHANNEL, "", NULL_KEY, "");
    }
    
    state_exit()
    {
        // Nothing yet
    }
    
    listen(integer channel, string name, key id, string message)
    {
        process_message(channel, name, id, message);
    }
}
