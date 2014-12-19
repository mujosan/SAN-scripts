# README #

### What is this repository for? ###

This is a collection of Ruby scripts created to assist with my day job as a storage admin.

Version **1.0**

### How do I get set up? ###

These scripts are intended to be run on a *nix platform. The Cisco and EMC Clariion/VNX scripts were initially created on a Linux (Centos) server and later "enhanced" on a Solaris machine. IBM SVC scripts created on the Solaris machine.

* Clone the repository.
* Amend equipment names to suit local naming conventions.
* Amend PATH constants to suit.
* Install SSH & EMC NavisecCLI.

#### Configuration ####

All scripts expect the storage equipment to be listed in the /etc/hosts file.

Create a file called "config" in your ~/.ssh directory:

    Host switch*
      StrictHostKeyChecking no
      UserKnownHostsFile=/dev/null


Without the above any upgrades to a switch will break this script for that switch. The "Host" entry should contain a wildcard string for the switch names.

#### Dependencies ####

* A server platform that supports /etc/hosts files and NavisecCLI
    * Solaris (Oracle)
    * AIX
    * RHEL (or Centos)
    * MS Windows Server.
* SSH client.
* EMC NavisecCLI

### Who do I talk to? ###

martin@mujosan.com

* [Learn Markdown](https://bitbucket.org/tutorials/markdowndemo)