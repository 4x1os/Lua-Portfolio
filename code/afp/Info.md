Because the game is still indevelopment and contributed by multiple scripters, I can't show all the code, but I compiled the ones that I did the majority of the work on, or did heavy contributions on.
There is another project as a part of this which is to maintain and optimize a TPS gun framework, but again, a lot of the work was in sparse, tiny amounts in which the majority was from the original writer. We did however make
good performance changes on it: I was able to upload it to github and sync it with rojo as a fully managed project, convert the remotes into blink packets which cut down on the packet sizes that it was sending, implement object pooling
to reduce the CPU count of instancing new beams every time a gun would fire, and I also wrote a CLI in node as to pack and unpack it into a readable form, as the nature of the framework would put all the scripts into ServerScriptService and 
then unpack it into the respective services for ease of installation and use.

The original gun system is TREK 4 by Catritonix if you were curious
