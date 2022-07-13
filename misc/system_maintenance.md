# System Maintenance
--------------------

* use 'pacdiff' to remove pacnew files lying around

## Efficiently and Effectively Clean Up My System
----------------------------------------------

### This is what I do semi-regularly:
(Taken from https://www.reddit.com/r/archlinux/comments/3fq6pn/how_to_effectively_and_efficiently_clean_up_my/)

  * Uninstall unused packages. With pacman -Qet (pacman -Qqet for leaving out the version numbers) you can list packages that you explicitly installed and that are not required by other packages. However, you might find that there are a lot of packages in there that belong to larger groups (like base, base-devel or xorg) that you shouldn't remove. I wrote a script to filter those out that I'll append below. Review all of those packages and remove everything you don't need. If you need more info on what a package does, use pacman -Qi [packagename].

  * Uninstall obsolete dependencies. After removing a few packages, you can list dependencies that are not needed anymore with pacman -Qdt (or - again - pacman -Qqdt for just the names). Remove those. Obviously after removing those you might have more, different unneeded dependencies, so you might have to do that a few times. If you want, you can do pacman -Rsu to recursively delete all of those, but I prefer to manually check the list myself to make sure that nothing important is accidentally deleted.

  * Find orphaned files. Ideally, most files outside of the /home folders should belong to packages. Executables should almost always go in a package, so they can easily be updated/removed. To find unowned files, use the second script below. (Not mine) Try to use PKGBUILDs for binaries that are found, and see if you need other files that it finds.

  * Find space hogs. If hard drive space is of concern, install ncdu and run it in / as root. It's an ncurses app that shows what folders/files take up the most space on your system.

  * Monitor processes. This one is fairly obvious, but look at your running processes and check if there are unnecessary services that you could disable or programs that use unusual amounts of RAM. I would recommend htop for this.
