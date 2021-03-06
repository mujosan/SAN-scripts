# README #

### What is this repository for? ###

This is a collection of Ruby scripts created to assist with my day job as a storage admin.

The Cisco MDS and EMC Clariion/VNX scripts were initially created on a Linux (Centos) server and later "enhanced" on a Solaris machine. IBM SVC scripts were created on the Solaris machine.

Version **1.0**

### How do I get set up? ###

These scripts are intended to be run on a *nix platform. 

* Clone the repository.
* Amend equipment names to suit local naming conventions.
* Amend PATH constants to suit.
* Install EMC Solutions Enabler & NavisecCLI.

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
    * MS Windows Server (not recommended - path names in scripts will require amendment).
* SSH client.
* EMC NavisecCLI
* EMC Solutions Enabler

### Who do I talk to? ###

martin@mujosan.com