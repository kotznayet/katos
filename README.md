## Katos (WIP)
Wanted a lightweight and cool os* for youra proxmox lxc... You may have found it.

> It needs:
>+ 5.5 GB storage
>+ 1GB memory
>+ amd64 processor
>+ Debian Trixie 

Katos is a KDE desktop and toolbox installer designed forDebian trixie on amd64, but with Breeze Dark, VSCodium, Zen Browser (and ublock origin).

A lot of tools preinstalled.

>It has:
>+ nmap
>+ KDE partition manager
>+ pi-apps
>+ Persepolis download manager
>+ zram
>+ ark

First get an image of Debian Trixie-like arm64 os (RPi os lite/Debian Trixie on other SBCs) and run 
`bash <(curl -fsSL https://raw.githubusercontent.com/kotznayet/katos/lxc/install.sh)`
 to install.

*It is an installer script not a distro.
