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
  - git

- Get basic bootmanager with GRUB installed.

(1) [Boot the live environment.](https://wiki.archlinux.org/title/Installation_guide#Boot_the_live_environment)

(2) Set any options (see [Options](#options))

(2.a) As environment variables:

```bash
$ export oTZ="Australia/Sydney"
$ export oLANG="en_AU"
```

(2.b) Or from a 'archless' file in your dotfiles folder/repo (see
[Config](#config))

```bash
$ export oSRC="<GH_USER>"
# from: https://raw.githubusercontent.com/<GH_USER>/dotfiles/main/archlessrc

$ export oSRC="<GH_USER>/<GH_REPO>"
# from: https://raw.githubusercontent.com/<GH_USER>/<GH_REPO>/main/archlessrc

$ export oSRC="<GH_USER>/<GH_REPO>/<FILE>"
# from: https://raw.githubusercontent.com/<GH_USER>/<GH_REPO>/main/<FILE>

$ export oSRC="<CUSTOM_URL>"
# from: <CUSTOM_URL>
```

(3) Run the installer

I would encourage that you read over the script first before executing with
bash. You may even want to fork the install script and use that instead.

```bash
$ curl https://peterboyer.github.io/archless/install.sh | bash
```

## Options

See environment variable options at top of `install.sh`.
