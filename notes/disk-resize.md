# Resizing disks

Somehow I always forget how to do this. I'm not sure this is the best way but it's what I'm trying now.
If I figure out a better way maybe I'll try that later.
I've got a root partition and I run out of space. Why I'm running out of space so fast is something I'll have
to figure out later. For now let's just address the issue.

Shutdown the VM. Go into the VM settings in XO and click on disks. Remember that you can actually just click
on the size of the disk and enter a new number to resize it. But that only resizes the "physical" disk,
and not any of the partitions. It's hard (impossible?) to resize the partition live. Set your boot order
on the VM to have the DVD first and then attach a live CD. Open up cfdisk and resize the partition.

Shut down, eject the disk. Reboot. Figure your life out and understand why everything is taking up so much space.

