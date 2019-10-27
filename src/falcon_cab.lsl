////////////////////////////////////////////////////////////////////////////////
////  CONSTANTS                                                             ////
////////////////////////////////////////////////////////////////////////////////

#include "falcon_common_constants.lsl"
string SIGNATURE = SIG_CAB;

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

move_to(float z_new, float speed)
{
        vector current_pos = llGetPos();
        float delta_z = z_new - current_pos.z;
        float move_time = llFabs(delta_z / speed);
        vector new_pos = <0.0, 0.0, delta_z>;

        debug("Moving from " + (string) current_pos.z + " to " + 
                    (string) z_new + " (" + (string) delta_z + " m) in " + 
                    (string) move_time + " s");

        llSetKeyframedMotion([new_pos, move_time], [KFM_DATA, KFM_TRANSLATION]);
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
    if (cmd == CMD_ACTION)
    {
        return handle_cmd_action(id, sig, ident, params);
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

integer handle_cmd_action(key id, string sig, string ident, list params)
{
    // TODO
    if (ACT_MOVE == llList2String(params, 0))
    {
        //debug("Moving to " + llList2String(params, 1));
        float z_new = llList2Float(params, 1);
        float speed = llList2Float(params, 2);
        move_to(z_new, speed);
    }
    return NOT_HANDLED;
}

integer init()
{
    uuid = llGetKey();
    owner = llGetOwner();
    
    llSetLinkPrimitiveParamsFast(LINK_SET,  [PRIM_SCRIPTED_SIT_ONLY, TRUE]);
    llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_PHYSICS_SHAPE_TYPE, PRIM_PHYSICS_SHAPE_CONVEX]);
    
    return TRUE;
}

default
{
    state_entry()
    {
        current_state = STATE_INITIAL;
        next_state = "";
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
        next_state = "";
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
        next_state = "";
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
        next_state = "";
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

/*
// Currently moving to another landing
// In this state, we need to consider mode changes, power outages, ...
state moving
{
    state_entry()
    {
        vector current_pos = llGetPos();
        float delta_z = move_to - current_pos.z;
        float move_time = llFabs(delta_z / speed);
        vector new_pos = <0.0, 0.0, delta_z>;

        llOwnerSay("Moving from " + (string) current_pos.z + " to " + 
                    (string) move_to + " (" + (string) delta_z + " m) in " + 
                    (string) move_time + " s");

        llSetKeyframedMotion([new_pos, move_time], [KFM_DATA, KFM_TRANSLATION]);
    }
    
    moving_end()
    {
        // Confirm the target position
        vector current_pos = llGetPos();
        vector target_pos = <current_pos.x, current_pos.y, move_to>;
        llSetLinkPrimitiveParamsFast(LINK_ROOT, [PRIM_POSITION, target_pos]);
        move_to = 0.0;
        speed   = 0.0;
        state arriving;
    }
    
    state_exit()
    {
    }
}

// Stopped, possibly between landings
// Useful for emergency power mode, power outages or manual system halt
state halted
{
    state_entry()
    {
        llSetKeyframedMotion([], [KFM_COMMAND, KFM_CMD_PAUSE]);
    }
    
    state_exit()
    {
        llSetKeyframedMotion([], [KFM_COMMAND, KFM_CMD_PLAY]);
    }
}
*/
