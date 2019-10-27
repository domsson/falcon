////////////////////////////////////////////////////////////////////////////////
////  CONSTANTS                                                             ////
////////////////////////////////////////////////////////////////////////////////

#include "falcon_common_constants.lsl"
string SIGNATURE = SIG_DOORWAY;

////////////////////////////////////////////////////////////////////////////////
////  OTHER SCRIPT STATE GLOBALS                                            ////
////////////////////////////////////////////////////////////////////////////////

// important objects/ids
key uuid       = NULL_KEY;
key owner      = NULL_KEY;
key controller = NULL_KEY;

// state etc
integer listen_handle;
string  current_state;
string  next_state;
list    configuration;

////////////////////////////////////////////////////////////////////////////////
////  UTILITY FUNCTIONS                                                     ////
////////////////////////////////////////////////////////////////////////////////

#include "falcon_common_functions.lsl"

/*
 * Compares the element at position `idx` from the given identifier string
 * with this object's identifier string and returns TRUE if they are the same.
 */
integer ident_matches(string ident, integer idx)
{
    list other_tokens = parse_ident(ident, ":");
    list our_tokens   = parse_ident(get_ident(), ":");
    return llList2String(other_tokens, idx) == llList2String(our_tokens, idx);
}

////////////////////////////////////////////////////////////////////////////////
////  MESSAGE HANDLING FUNCTIONS                                            ////
////////////////////////////////////////////////////////////////////////////////

/*
 * Handles the incoming message. Returns a numeric value, where TRUE and other 
 * positive values are generally a sign of success. NOT_HANDLED indicates that 
 * no handler for this command is known or the handler didn't know what to do 
 * with the message. FALSE or other negative values indicate failure.
 */
integer process_message(integer chan, string name, key id, string msg)
{
    /*
    // Get the sender's owner and abort if they don't match with ours
    list details = llGetObjectDetails(id, [OBJECT_OWNER]);
    if (owner != llList2Key(details, 0))
    {
        return NOT_HANDLED;
    }
    */
    
    // Split the message on spaces
    list    tokens     = llParseString2List(msg, [" "], []);
    integer num_tokens = llGetListLength(tokens);
    
    // Extract the different components
    string sig    = llList2String(tokens, MSG_IDX_SIG);
    string ident  = llList2String(tokens, MSG_IDX_IDENT);
    string cmd    = llList2String(tokens, MSG_IDX_CMD);
    list   params = llList2List(tokens,   MSG_IDX_PARAMS, num_tokens - 1);
    
    // Abort if the message didn't come from a controller
    if (sig != SIG_CONTROLLER)
    {
        return NOT_HANDLED;
    }
    
    // Hand over to the appropriate command handler
    if (cmd == CMD_PING)
    {
        return handle_cmd_ping(id, sig, ident, params);
    }
    if (cmd == CMD_STATUS)
    {
        return handle_cmd_status(id, sig, ident, params);
    }
    if (cmd == CMD_PAIR)
    {
        return handle_cmd_pair(id, sig, ident, params);
    }
    if (cmd == CMD_CONFIG)
    {
        return handle_cmd_config(id, sig, ident, params);
    }
    
    // Message has not been handled
    return NOT_HANDLED;
}

integer handle_cmd_ping(key id, string sig, string ident, list params)
{
    send_message(id, CMD_PONG, []);
    return TRUE;
}

integer handle_cmd_status(key id, string sig, string ident, list params)
{
    // Abort if `bank` doesn't match
    if (!ident_matches(ident, IDENT_IDX_BANK))
    {
        return NOT_HANDLED;
    }
    
    // Send back status info, even to foreign controllers
    send_message(id, CMD_STATUS, [current_state, controller]);
    return TRUE;
}

integer handle_cmd_pair(key id, string sig, string ident, list params)
{
    // Abort if `bank` doesn't match
    if (!ident_matches(ident, IDENT_IDX_BANK))
    {
        return NOT_HANDLED;
    }

    // If we were paired before, but now switch to a new controller...
    if (controller != NULL_KEY && controller != id)
    {
        // ...let's first inform the old controller about it
        send_message(controller, CMD_STATUS, [current_state, id]);
    }
    
    // Set/update the controller and inform the new controller
    controller = id;
    send_message(id, CMD_STATUS, [current_state, controller]);
    return TRUE;
}

integer handle_cmd_config(key id, string sig, string ident, list params)
{
    // Abort if `bank` doesn't match
    if (!ident_matches(ident, IDENT_IDX_BANK))
    {
        return NOT_HANDLED;
    }
    
    // Abort if the controller doesn't match
    if (id != controller)
    {
        return NOT_HANDLED;
    }
    
    list configuration = params;
    
    // Request change to config state
    next_state = STATE_CONFIG;
    return TRUE;
}

integer init()
{
    uuid = llGetKey();
    owner = llGetOwner();
    
    return TRUE;
}

default
{
    state_entry()
    {
        current_state = STATE_INITIAL;
        print_state_info();
        
        // Perform basic initialization first
        init();
        
        // Listen to messages
        listen_handle = llListen(CHANNEL, "", NULL_KEY, "");
    }
    
    listen(integer channel, string name, key id, string message)
    {
        integer result = process_message(channel, name, id, message);
    
        if (next_state == STATE_CONFIG)
        {
            state config;
        }
        if (next_state == STATE_ERROR)
        {
            state error;
        }
    }
    
    state_exit()
    {
        // Nothing yet
    }
}

state config
{
    state_entry()
    {
        current_state = STATE_CONFIG;
        print_state_info();
        
        // Listen to messages
        listen_handle = llListen(CHANNEL, "", NULL_KEY, "");
        
        // We inform the controller of our status change
        send_message(controller, CMD_STATUS, [current_state, controller]);
        
        // TODO: initiate setup of subcomponents!        
        llSetTimerEvent(TIME_CONFIG - 1);
    }

    listen(integer channel, string name, key id, string message)
    {
        integer result = process_message(channel, name, id, message);
        
        if (next_state == STATE_INITIAL)
        {
            state default;
        }
        if (next_state == STATE_RUNNING)
        {
            state running;
        }
        if (next_state == STATE_ERROR)
        {
            state error;
        }
    }
    
    timer()
    {
        llSetTimerEvent(0.0);
        
        // TODO: check if all subcomponents were configured successfully,
        //       then enter running state if so. For now, we just pretend.
        state running;
    }

    state_exit()
    {
        // Nothing yet
    }
}

/*
 * This is the main operational state. It means the component is all set up 
 * and should operate as intended. 
 */
state running
{
    state_entry()
    {
        current_state = STATE_RUNNING;
        print_state_info();
        
        // Listen to messages
        listen_handle = llListen(CHANNEL, "", NULL_KEY, "");
        
        // We inform the controller of our status change
        send_message(controller, CMD_STATUS, [current_state, controller]);
    }

    listen(integer channel, string name, key id, string message)
    {
        integer result = process_message(channel, name, id, message);
        
        if (next_state == STATE_INITIAL)
        {
            state default;
        }
        if (next_state == STATE_CONFIG)
        {
            state config;
        }
        if (next_state == STATE_ERROR)
        {
            state error;
        }
    }
    
    touch_end(integer num_detected)
    {
        send_message(controller, "event", ["call"]);
    }
     
    state_exit()
    {
        // Nothing yet
    }
}

/*
 * If the component runs into a non-recoverable error, it might enter this 
 * state, so it can signal the problem to the controller and leave it to the 
 * controller to decide on what to do.
 */ 
state error
{
    state_entry()
    {
        current_state = STATE_ERROR;
        print_state_info();
        
        // Listen to messages
        listen_handle = llListen(CHANNEL, "", NULL_KEY, "");
        
        // We inform the controller of our status change
        send_message(controller, CMD_STATUS, [current_state, controller]);
    }
    
    listen(integer channel, string name, key id, string message)
    {
        integer result = process_message(channel, name, id, message);
        
        if (next_state == STATE_INITIAL)
        {
            state default;
        }
        if (next_state == STATE_CONFIG)
        {
            state config;
        }
        if (next_state == STATE_RUNNING)
        {
            state running;
        }
    }
     
    state_exit()
    {
        // Nothing yet
    }
}
