# Running the program

Use `lua ./run --help` to see information about how to run this program.

To run it in mock mode, you can use the following:

```sh
lua ./run --base $(pwd)/ --mock
```

To run this in a turtle, follow the "prepare the world" instructions below, then run `run`

Automated tests can be run with

```sh
lua ./run --base $(pwd)/ --test
```

# Helpful information

turtle api: https://computercraft.info/wiki/Turtle_(API)
All APIs available to the turtle: https://computercraft.info/wiki/Category:APIs

       (-Z)
         N     up: +y
         ^   down: -y
         |
(-x) W<--*-->E (+x)
         |
         V
         S
       (+Z)

# Installing ComputerCraft

Use Minecraft 1.8.9

When starting up MineCraft, it would crash. The error came from a stacktrace that originated from a third-party library that MineCraft used, and the function name was something to do with not finding any displays. I just had to install some missing program in order to make that work, but can't remember what that was.

# Preparing the world

Use Skyblock 2.1 (Some downloads are for more recent versions of Minecraft. Make sure to get one that supports 1.8.9).

Start the turtle in front of the chest, facing away from it. Place its disk drive to the left of the turtle. It should have 16 charcoal in its top-left inventory slot for fuel, and a crafting table next to that. Equipped on its right should be a diamond pickaxe, and on its left it should have a modem.

You can make the disk persist across restarts by doing `label right/front/etc main` (or something like that). You'll find the data for this disk in the world save, in computer/. Do not just symlink your source code directory to there! If you ever delete the world through MineCraft's UI, it'll go into the source directory and delete those files.

# Terms

Coordinate: A forward,right,up coordinate.
Position: A coordinate with a face.
Location: A specific point in space that you often travel to. There's logic in place to find the quickest route from one location to another.
(At the time of writing, act/space.lua has more information about coordinate terminology in its module comment)

plan: A series of immediate steps that needs to be taken (like turn left, go forward, etc) until you get to a place where an interruption can happen. An interruption could be, for example, refueling, or tending a farm.
strategy: The overall plan from harvesting the first tree to the last projects.

primary task: The main project you're currently working on (like building a tree farm)
active task: What you're currently doing, like getting more fuel
interrupt task: Sometimes the active task can be interrupted, so the turtle can go harvest a farm and what-not.

Unit of work: A measurement of how much work it takes to accomplish a task. Used to figure out when it's worth it to harvest a farm (by comparing the work it takes to the value of the resources). A single unit is equivalent to the time it takes to do a 90 degree turn. Movement costs extra (at the time of writing, it's 1.5 units), to account for the fact that it also took work to gather the fuel to make that movement possible.
