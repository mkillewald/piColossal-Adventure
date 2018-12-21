<b>[Spoiler Alert!!]</b> The YouTube video linked to the below image reveals   
the original Atari easter egg and the added Pico-8 secret ending!   
[![Alt text](https://img.youtube.com/vi/aR71roPKuy0/0.jpg)](https://www.youtube.com/watch?v=aR71roPKuy0)   
Video and Muisc Credit: YouTube user "David Wood Super Guy"

# piColossal Adventure

A pico-8 remake of and tribute to Adventure for the Atari Video Computer System

Code structure, construct definitions, sprite movement, collision, and animation routines copied from and/or very heavily influenced by Dom8verse (by Haunted Tie).

An evil magician has stolen the enchanted chalice and has hidden it somewhere in the Kingdom. The object of the game is to rescue the enchanted chalice and place it inside the golden castle where it belongs. This is no easy task, as the evil magician has created three dragons to hinder you in your quest for the golden chalice. There is Yorgle, the yellow dragon, who is just plain mean; there is Grundle, the green dragon, who is mean and ferocious; and there is Rhindle, the red dragon, who is the most ferocious of all. Rhindle is also the fastest dragon and is the most difficult to out maneuver.

<b>[Update v2.0]</b> Have you ever wondered why Yorgle is afraid of the yellow key, or who exactly is the Evil Magician? I mean whats his deal, has anyone ever even seen him before? Now you can finally go face to face with him and find out! There is one catch,.. you'll first have to locate him and his lair hidden deep within the Kingdom. Are you up to the challenge?

Play piColossal Adventure in your web browser: https://www.lexaloffle.com/bbs/?tid=27901

### Skill Levels:

selectable at cartridge boot or reset (see Controls)

Level 1: small Kingdom, no bat, 2 dragons  
Level 2: full Kingdom, bat and 3 dragons  
Level 3: full Kingdom, bat, 3 dragons and random object placement  

### Difficulty:

changeable through the in-game menu (see Controls)  
\*denotes default settings

**Dragon Attack (Atari 2600 left switch):**  
\*(hard) dragons attack instantly  
(easy) dragons hesitate before attacking  

**Dragon Fear (Atari 2600 right switch):**  
\*(hard) all dragons run from sword  
(easy) dragons do not run from sword  

### Controls:

**Level select screen:**  
X change skill level (rotates through 1, 2 or 3 with each press)  
Z start game at chosen skill level  

**in game:**  
UP/DOWN/LEFT/RIGHT move player  
Z drop item  
X special use discoverable inside evil magician's castle  
Z and X pressed together bring up an in game menu to change difficulty and reincarnate  

**in game menu:**  
UP/DOWN to change active selection  
Z to select or toggle item  
LEFT/RIGHT immediate/emergency menu exit  

A word of caution with the in game menu is that the Kingdom is always operating in real time. In other words, the dragons and bat do not pause while the menu is open (or after you have been eaten for that matter).

This was for me a really fun game to recreate while learning how to make a game in pico-8. It took me about a month to build version 1.0 while teaching myself about OOP, collision detection, map changing and very low level AI logic.

### Change Log:

2.0 code cleanup, token savings, changed chalice and secret room color cycle routines, changed message in secret room, added new secrets with new ending and extended storyline, added timer and statistics for new ending.

1.6 added collision flicker, grab object inside wall at edge of wall fix, movement in belly of the beast fix, bridge grab-in-use fix, string->table unpacker provided by cheepicus (thanks!!!), code clean up, and token reduction

1.5 add/drop sound effect correction by dw817 (thanks, dude!)

1.4 in game menu created, fix to black castle maze, nmsg transparency

1.3 difficulty switch init fix, blue maze fix, code cleanup

1.2 exits to nowhere peek fix

1.1 exits to nowhere fix

1.0 first release
