<h1 align="center">SSH Ramdisk Script</h1>

<p align="center">
Create and boot a SSH ramdisk on checkm8 devices
</p>

---



# Prerequsites

1. A computer running macOS/linux
2. A checkm8 device (A7-A11)

# Warning

I AM NOT responsible for any data loss. The user of this program accepts responsibility should something happen to their device. While nothing should happen, jailbreaking has risks in itself. If your device is stuck in recovery, please run one of the following:
futurerestore --exit-recovery
irecovery -n

# Usage

1. Clone and cd into this repository: `git clone https://github.com/verygenericname/SSHRD_Script --recursive && cd SSHRD_Script`
    - If you have cloned this before, run `cd SSHRD_Script && git pull` to pull new changes
2. Run `./sshrd.sh <iOS version for ramdisk>`, **without** the `<>`.
3. Place your device into DFU mode
    - A11 users, go to recovery first, then DFU.
4. Run `./sshrd.sh boot` to boot the ramdisk
5. Run `./sshrd.sh ssh` to connect to SSH on your device
6. Finally, to mount the filesystems, run `mount_filesystems`  
    - /var is mounted to /mnt2 in the ssh session.
    - /private/preboot is mounted to /mnt6.
7. Have fun!

# Other commands

- Reset your device: `./sshrd.sh reset`
- Dump onboard blobs: `./sshrd.sh dump-blobs`
- Delete old SSH ramdisk: `./sshrd.sh clean`

# Other Stuff

- [Reddit Post](https://www.reddit.com/r/jailbreak/comments/wgiye1/free_release_ssh_ramdisk_creator_for_iphones_ipad/)
