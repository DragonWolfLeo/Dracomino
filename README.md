# Dracomino
Dracomino is a falling block puzzle game adapted into a randomizer using [Archipelago](https://archipelago.gg). 
Arrange shapes into full lines to clear them and gain items, and place shapes onto coins to collect them and 
gain more items. Dracomino features 29 different shapes, including monominos, dominos, trominos, tetrominos,
and pentominos.

The APWorld is found [here](https://github.com/DragonWolfLeo/DracominoAPWorld/releases).

## What does randomization do to this game?

Your items are shapes and abilities. The order you receive items, and even the color and orientation
remain consistent throughout multiple playthroughs. The number of pieces you have is limited, so
you'll have to collect more to reach further in a run.

## What is the goal of Dracomino?

The goal is to clear a number of lines in a single run. You can set this goal in your options.

## What are location checks in Dracomino?

Your checks are clearing lines and coins scattered throughout your board. As you clear lines, more
coins are revealed.

# How to play

  - Install [Archipelago](https://github.com/ArchipelagoMW/Archipelago/releases/latest)
  - Install [dracomino.apworld](https://github.com/DragonWolfLeo/DracominoAPWorld/releases)
  - Use Archipelago to generate your options/yaml
  - Use Archipelago to generate a multiworld
  - Host the resulting zip file either with Archipelago or [the website](https://archipelago.gg/uploads)

  - Choose how you'll play Dracomino
    - [Windows and Linux Builds](https://github.com/DragonWolfLeo/Dracomino/releases/latest)
    - [Web Version](https://dragonwolfleo.github.io/Dracomino/)
    - From source. You can run the project in [Godot 4.4.x](https://godotengine.org/download/archive/4.4.1-stable/)

## In Beta
This game is in the beta stage. It's fully playable, and should be stable for syncs and asyncs. There's many features we're planning. We're aware of what's missing; beta means beta. It takes time to develop a game. Consider [supporting us](https://ko-fi.com/dragonwolfleo) so we could put more time into development.

## Controls
This is playable with either keyboard or controller. Abilities and stuff will require you to unlock them first!
(Not rebindable right now. Edit in Godot if you want to change it. It's quite easy.)
 - **Movement:** WASD/Arrow Keys/D-pad
 - **Soft Drop:** Down
 - **Hard Drop:** Up
 - **Rotate Clockwise:** E/Z/Joypad Right Action
 - **Rotate Counterclockwise:** Q/X/Joypad Bottom Action
 - **Hold:** Shift/Space/Joypad Right Shoulder
 - **Restart:** Ctrl-R/Joypad Back
 - **Pause:** Enter/Escape/Joypad Start

**(No mobile support yet. It is planned!)**

## Note about Trackers
Dracomino does not support trackers. This game is designed to be played because you want to play it, not because a tool told you to. Trackers create the illusion of blocking a multiworld when the player is actually ahead. Do not complain about hypothetical logic issues based on a flawed conclusion by the use of unsupported tools.

# Credits
 - **Dragon Wolf Leo** - Programming 
 - **VAdaPEGA** - Art, Sounds

## Libraries Used
  - [GodotAP](https://github.com/EmilyV99/GodotAP)