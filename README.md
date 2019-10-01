# Falcon Elevator

This is an attempt to create a set of open source LSL scripts that can 
operate a somewhat realistic elevator system for use in Second Life.

While there is a highly sophisticated elevator system already available 
(see the _Condor_ and, more recently, _Delta_ elevators), those are 
closed source, the scripts come _no-mod_.

The Falcon aims for a similar feature-set as the Condor. However, its 
target audience are mainly creators, not end-users, which means it does 
not attempt to be as user-friendly when it comes to the setup.

The idea is to have a solid and versatile script that enables creators 
to come up with custom tailored elevator systems for their creations 
without having to go through the trouble of scripting them.

This is a very early work-in-progress. There isn't much to see here yet.


# Concept

The following are notes on how the system is intended to work; these are 
my personal implementation notes/concepts. Unless you are working on an 
elevator script yourself and want some inspiration, this won't be of use 
to you.


## Identifiers

Identifiers represent the relevant concepts of an elevator system:

- `bank`,  a set of elevators that work in conjunction
- `cab`,   an elevator operating in a bank
- `floor`, a landing that a cab can travel to


## Components

The following components are required for operation:

| name              | number                  | associated with        |
|-------------------|-------------------------|------------------------|
| `controller`      | 1 per system            | `bank`                 |
| `cab`             | 1-4 per `bank`          | `bank`                 |
| `doorway`         | 1 per `cab` and `floor` | `bank`, `cab`, `floor` |
| `call_buttons`    | 0-4 per `floor`         | `bank`, `floor`        |

Note that the `call_buttons` may be implemented as subcomponent of a
`doorway` instead, hence why they are listed as optional above.

The `doorway` could, in the simplest case, be an invisible prim or piece 
of the floor in front of the cab entrance. Its main purpose is to 
determine the position of the `floor` landings, i.e. where the `cab`s 
are supposed to travel to exactly when they are being called to a 
specific `floor`.


## Subcomponents

The following components are optional and should come as a linked prim 
of a specific main component:

| name              | number                  | parent component       |
|-------------------|-------------------------|------------------------|
| `cab_controls`    | 0-1 per `cab`           | `cab`                  |
| `cab_display`     | 0-n per `cab`           | `cab`                  |
| `cab_doors`       | 0-n per `cab`           | `cab`                  |
| `doorway_display` | 0-n per `doorway`       | `doorway`              |
| `doorway_doors`   | 0-n per `doorway`       | `doorway`              |
| `call_buttons`    | 0-1 per `doorway`       | `doorway`              |

The handling of subcomponents is not set in stone. For some systems, it 
can make more sense to have individual scripts take care of these 
subcomponents. In other systems, it might be sufficient to have a single 
script in the parent component take care of the subcomponents.

I'm hoping to be able to eventually get two reference implementations 
out there; one for each of these cases. For now, one will have to do.

## General thoughts

- All communcation between the main components always goes through the 
  controller; this means that even a system with only one cab needs to 
  have a controller
- The controller only knows the main components, it does not care 
  about the subcomponents (separation of concerns)
- Call buttons can be main components or subcomponents of doorways, 
  because we want the option to have a single call button for a set 
  (bank) of elevators, but we also want the option to simplify the 
  system by letting the doorways deal with the buttons

## Logic flow

### General initialization

1.  On rez, all components read their description and parse `bank` name, 
    `cab` name and `floor` number, if applicable
2.  The `controller` and all components of type `cab`, `doorway` and 
    `call_buttons` set up a listener on the same channel
3.  On touch, the `controller` pings all objects in the region on said 
    channel; the ping message contains the `bank` name
4.  All listening components check if the `bank` name matches their own;
    if so, they message the `controller` back, specifying their `cab` 
    and `floor` number, if applicable
5.  The `controller` creates and maintains a list of all components that 
    reported back
6.  The `controller` checks if all required components are in place; that 
    is, at least one `cab` and at least two `doorway` objects for each 
    `cab`; `call_buttons` are seen as optional as they might be 
    implemented as a subcomponent of the `doorway` objects
7.  The `controller` reads its configuration notecard and parses all 
    relevant information; amongst that information can optionally be a 
    list of floor numbers/names (one to two digits, alphanumeric)
7.  The `controller` queries the location and rotation of the _base_ 
    `doorway` (either the one with the lowest z-position, or the one 
    closests to the associated `cab`, not quite sure yet)
8.  The `controller` sends a message to all `doorway`s, instructing them 
    to perform setup; this message includes the x- and y-position and 
    rotation as queried from the _base_ doorway, as well as their custom 
    floor number/name, if any; additionally, it includes a list of all 
    `floor`s and their accessibility (this is important so that the 
    `doorway`s can setup linked `call_buttons` correctly, if any)
9.  All `doorway`s undergo setup and report failure or success back to
    the `controller`
10. The `controller` sends a message to all `cab`s, instructing them to
    perform setup; this message includes a list of all `floor`s, 
    including their z-position, as well as their custom floor 
    number/names, if any, and whether each `floor` is actually 
    accessible by that particular `cab` (some floors might not be 
    accessible by all the `cab`s in a `bank`)
11. All `cab`s perform setup, including setting up their subcomponents; 
    the `cab`s then send a message back to the `controller`, specifying 
    if setup was successfull or failed
12. The `controller` sends a message to all `call_buttons` (if any), 
    instructing them to perform setup; the message contains a list of 
    all `floor`s and their accessibility (this is important so that the 
    buttons can be set up correctly, i.e. show only an up-arrow button 
    if there are no floors below the current one)
13. All `call_buttons`, if any, perform initialization and report back 
    to the `controller` accordingly
14. If all components were setup successfully, the `controller` sends 
    out messages to all registered components, informing them that the 
    system is ready
15. All components may now peform additional steps to get into their 
    individual idle/ready states; for example, all `cab`s and 
    `doorway`s might want to close their doors, if any, unless they've 
    already done that during setup
    

### Cab subcomponent initialization

_TODO_


### Doorway subcomponent initialization

_TODO_


## Communication

### Message syntax

_TODO_

### Component signatures

_TODO_

### Message types

_TODO_
