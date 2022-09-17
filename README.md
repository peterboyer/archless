# archless

Automate the base of your Arch Linux install (as per the wiki's first steps):

- Get a basic disk/partition layout configured:
  - boot partition (if gpt, detected automatically)
  - swap partition (configured with oSWAP)
  - root partition with btrfs (configured with oFS)

- Get all localisation configured:
  - timezone (configured with oTZ)
  - language (configured with oLANG)
  - keymap (configured with oKEYMAP)

- Get basic root & admin user configured:
  - root user (default)
  - admin user (name configured with oUSER)
  - admin user part of the `wheel` group + sudoers

- Get basic network/hostname/hosts configured:
  - hostname (name configured with oHOST)
  - /etc/hosts (using hostname)

- Get basic pacstrap packages:
  - base + base+devel
  - linux + linux-firmware
  - microcode patches (configured with oUCODE, detected automatically)
  - sof-firmware
  - man git

- Get basic bootmanager with GRUB installed.

# Usage

(1) [Boot the live environment.](https://wiki.archlinux.org/title/Installation_guide#Boot_the_live_environment)

(2) Download install script as `./install.sh`:

```bash
$ curl https://peterboyer.github.io/archless/install.sh -o install.sh
$ chmod +x install.sh

# (optional) set any option (if not using PROFILE)
$ export oTZ="Australia/Sydney"
$ export oLANG="en_AU"

# (optional) set target profile* github user/[repo] (to source `archless` file from)
$ export PROFILE=peterboyer

# (optional) set target disk (if detected wrong one)
$ export DEV=nvme0n1
```

(3) Run the install script:

I would encourage that you read over the script first before executing with
bash. You may even want to fork the install script and use that instead.

```bash
# top-level
$ ./install.sh
```

(4) Continue install script within arch-chroot:

```bash
# arch-chroot
$ ./install.sh
```

# PROFILE

```bash
$ export PROFILE="<GH_USER>"
# from: https://raw.githubusercontent.com/<GH_USER>/dotfiles/main/archlessrc

$ export PROFILE="<GH_USER>/<GH_REPO>"
# from: https://raw.githubusercontent.com/<GH_USER>/<GH_REPO>/main/archlessrc

$ export PROFILE="<GH_USER>/<GH_REPO>/<FILE>"
# from: https://raw.githubusercontent.com/<GH_USER>/<GH_REPO>/main/<FILE>

$ export PROFILE="<CUSTOM_URL>"
# from: <CUSTOM_URL>
```

## Options

See environment variable options at top of `install.sh`.
