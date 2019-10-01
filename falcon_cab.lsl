integer DEBUG = TRUE;

key owner = NULL_KEY;
key controller = NULL_KEY;

string bank_name = "";
string cab_name  = "";

integer falcon_channel = -130104;
integer listen_handle;

debug(string msg)
{
    if (DEBUG)
    {
        llOwnerSay(llGetScriptName() + " @ " + llGetObjectName() + ": " + msg);
    }
}

process_message(integer channel, string name, key id, string message)
{
    // Print the received message
    llOwnerSay(llGetObjectName() + " < `" + message + "`");
    
    // Get details about the sender
    list details = llGetObjectDetails(id, ([OBJECT_NAME, OBJECT_DESC, OBJECT_POS, OBJECT_ROT, OBJECT_OWNER]));
   
    // Abort if the sender isn't owned by us (unlikely)
    if (llList2Key(details, 4) != owner)
    {
        return;
    }
    
    // Split the message on spaces and extract the first tokens
    list    tokens     = llParseString2List(message, [" "], []);
    integer num_tokens = llGetListLength(tokens);
    string  command    = llList2String(tokens, 0);   
    string  signature  = llList2String(tokens, 1);
    
    if (command == "falcon-ping")
    {
        llRegionSayTo(id, channel, "falcon-pong cab");
    }
}

integer init()
{
    owner = llGetOwner();
    
    list tokens = llParseString2List(llGetObjectDesc(), [":"], []);
    integer num_tokens = llGetListLength(tokens);
    if (num_tokens < 2)
    {
        debug("init failed because description lacks required information");
        return FALSE;
    }
    bank_name = llList2String(tokens, 0);   
    cab_name  = llList2String(tokens, 1);
    debug("bank = " + bank_name + ", cab = " + cab_name);
    
    llSetLinkPrimitiveParamsFast(LINK_SET,  [PRIM_SCRIPTED_SIT_ONLY, TRUE]);
    llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_PHYSICS_SHAPE_TYPE, PRIM_PHYSICS_SHAPE_CONVEX]);
    
    //reset_scripts();
    
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
        listen_handle = llListen(falcon_channel, "", NULL_KEY, "");
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
