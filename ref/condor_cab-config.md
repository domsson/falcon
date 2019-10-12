###  CONFIGURATION NOTECARD
###  Do not remove or move any settings or your elevator may malfunction.
###  You may remove comments and blank lines to speed up loading.
###  YOUR ELEVATOR WILL AUTOMATICALLY STOP AND RESET UPON SAVING THIS NOTECARD.


##  IMPORTANT
#  The elevator's ID. Any alphanumeric string (A-Z, 0-9). All doors to this elevator must also have the same ID in their object description field.
#  Do not use spaces or special characters!
ElevatorID=Default


##  OPERATION SETTINGS
#  Wait time after arriving at destination (6-300 seconds).
WaitTime=8

#  Elevator speed (1-5). NOTE: 6-10 also supported but is unreliable and may cause script errors.
Speed=3

#  Recall floor number (0-15, depending on number of floors). Elevator returns to this floor after RecallTime AND when fire service mode phase 1 activated.
#  NOTE: Floors are counted starting with 0. Do not put floor names (see FloorNames).
RecallFloor=0

#  Recall floor time (0-3600 seconds, 0 to disable timed recall).
RecallTime=0


##  BASIC CUSTOMIZATION
#  Custom floor names (0-24, A-Z, B1-B9, LL, ML, UL, *, or "Auto" to use automatic numbering).
#  By default, this is set to automatic numbering (starts at 1). For basement floors, European numbering, etc. you must name floors manually.
#  Make sure you have the same number of names here as there are floors, otherwise setup will fail. Rez doors first.
#  Separate floors with commas, e.g. "B2, B1, L, 2, 3, 4" without quotes (spaces optional)
FloorNames=Auto

#  Color for activated buttons on elevator panel and door calls (except HOLD button and fire service indicator).
#  NOTE: For colors, you can use float or decimal RGB values (e.g. "<1.0, 0.5, 0.0>" OR "<255, 128, 0>"). The "<" and ">" characters are also optional, so you could also put "255, 128, 0".
ButtonOnColor=<0.80, 0.90, 1.00>

#  Color for deactivated buttons on elevator panel and door calls.
ButtonOffColor=<0.35, 0.35, 0.35>

#  Color for display.
DisplayColor=<0.80, 0.90, 1.00>

#  Door indicator color option (White or Color). White makes arrows white when on,  Color makes them green and red. (Both are white when off.)
IndicatorColor=White

#  Door indicator flash option (Steady or Flash).
IndicatorFlash=Steady

#  Auto align (Yes or No). Align doors to lowest door automatically.
AutoAlign=Yes

#  Nearby sensor for panel floor buttons (number of meters, 0 to disable). The radius in which to check for users when a panel floor button is pressed (not a switch or floor call button).
#  If the user isn't nearby, the button press is ignored. Helpful for preventing people from camming into the elevator and pressing all the buttons. Recommended setting is at least 4.0.
NearbyRange=4.0

#  Car teleportation. If enabled and the car is called to a floor with nobody in it, the car will jump immediately to that floor without movement.
#  Facilitates faster service for low-volume elevators, but should not be used outdoors.
CarTeleport=No


##  TEXTURE CUSTOMIZATION
#  See "Themes" in user manual for included texture codes. THESE ARE NOT UUIDs, YOU CANNOT MAKE YOUR OWN TEXTURES OR PUT UUIDs HERE.
#  Interior texture code.
InteriorTexture=XA9QEFwRRlQYBwALB1RTDwAteEpDQFhIE3hzVhRaMFIRQUJE

#  Door texture code.
DoorTexture=CAVRF1xGRQ4YAQkLUFRSDwF+eBZETQlISH92VUZdZFBDTktN

#  Light texture code.
LightTexture=DVBQR1UXFAQYUABaUlRWAAN/eBZPTVxIEX9xBRRdNQJEQUUR

#  Floor button texture code.
FloorButtonTexture=DlJWS1YWE1MYCwgIUVRSDAMqeEJORltISSpzABEBMgBBQBQT

#  Symbol button texture code.
SymbolButtonTexture=AFNbRwdMF1EYBFsMVVRQWwMreEQSQ1NIFSp3UkIMNQEUQxNE

#  Call button texture code.
CallButtonTexture=DwYAQVdNFA8YVg9cWVQCD114eEVHFl9IEnglVxAOZVAWEUAU

#  Button panel texture code.
#  These do not come included with the elevator. Do not change this unless you know what you're doing.
ButtonPanelTexture=Auto


##  SOUND CUSTOMIZATION
#  NOTICE: Use of these UUIDs outside the Gentek Elevator without written permission is theft and will be prosecuted.
#  Bell sound when arriving at a floor to go up. Must be a UUID (right click -> Copy Asset UUID from inventory)
#  Default: 94bf7389-e7ba-ed86-393e-0b98fe7f4112
#  Mechanical bell: dd8d6281-2487-3475-1958-c097c08958c2
BellUp=94bf7389-e7ba-ed86-393e-0b98fe7f4112
BellUpVol=0.3

#  Bell sound when arriving at a floor to go down. Must be a UUID (right click -> Copy Asset UUID from inventory)
#  Default: b80acea8-426f-feea-7925-07a33e611fd8
#  Mechanical bell: ad2d7f72-7476-2e7c-42c9-b5cf2f76254f
BellDown=b80acea8-426f-feea-7925-07a33e611fd8
BellDownVol=0.3

#  Bell sound when doors are being forced closed, a.k.a. nudge mode. Must be a UUID (right click -> Copy Asset UUID from inventory)
BellNudge=a119295b-6d53-1012-f941-8183707f15fb
BellNudgeVol=0.3

#  Bell sound when the floor indicator changes (e.g. a floor is passed). Must be a UUID (right click -> Copy Asset UUID from inventory)
#  NOTE: Don't forget to change the volume - although a sound is included if you want to use it, it's disabled by default (personal preference).
BellPass=696e606e-478c-cb01-04c0-5b67bcf00e91
BellPassVol=0.0
