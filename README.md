# Helpful information

turtle api: https://computercraft.info/wiki/Turtle_(API)

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

Start the turtle right above the bedrock, facing north.

Start the tutle in front of the chest, facing away from it. Place its disk drive to the right of the tutle.

You can make the disk persist across restarts by doing `label right/front/etc main` (or something like that). You'll find the data for this disk in the world save, in computer/. Do not just link your source code directory to there! If you ever delete the world through MineCraft's UI, it'll go into the source directory and delete those files.

# Terms

Coordinate: An x, y, z coordinate
Position: An x, y, z, and face.
Location: A specific point in space that you often travel to. There's logic in place to find the quickest route from one location to another.

shortTermPlan: A series of steps that needs to be taken until you get to a place where an interruption can happen. (e.g. an interruption to go refuel)
strategy: The overall plan from harvesting the first tree to the last projects.

primary task: The main project you're currently working on (like building a tree farm)
active task: What you're currently doing, like getting more fuel