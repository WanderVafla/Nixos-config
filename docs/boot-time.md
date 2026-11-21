# Boot time

Notes on the boot-time tuning of this machine (HP EliteBook 865 16 G11, AMD Ryzen 5 8540U, SK hynix NVMe, dual boot with Windows). Started on 2026-11-21.

## Result

| Stage | Before | After |
|---|---|---|
| Firmware | 7.3 s | ~7 s (sometimes ~15 s, see below) |
| Loader | 5.5 s | 1.5 s |
| Kernel | 0.7 s | 0.7 s |
| Initrd | 2.5 s | 2.2–2.4 s |
| Userspace | 4.0 s | 3.5–5.5 s |
| Power-on to greeter | ~22 s | ~18 s |

Use "power-on to greeter" to compare boots, not the `systemd-analyze` total. The total ends at `graphical.target`, which waits for NetworkManager and Tailscale, while `greetd.service` starts earlier and does not wait for them.

## Changes in `configuration.nix`

```nix
boot.loader.timeout = 1;
boot.initrd.services.lvm.enable = false;
boot.initrd.systemd.tpm2.enable = false;
boot.initrd.compressor = "zstd";
boot.initrd.compressorArgs = [ "-19" "-T0" ];
```

- LVM and TPM2 are dropped from the initrd: the root is plain ext4 on `nvme0n1p6` and nothing is encrypted.
- The initrd went from 28 MB (zstd `-10`, the NixOS default) to 21 MB.
- `timeout = 1` is kept on purpose, so the menu can still pick Windows or an older generation.
- Already in place before: `NetworkManager-wait-online` disabled, `docker.enableOnBoot = false`. `services.fstrim` is on by default and does not affect boot.

The initrd always uses systemd now: on this nixpkgs the scripted stage 1 is removed, so `boot.initrd.systemd.enable` no longer exists.

### Compression tried

| Compressor | Initrd size | Unpack time |
|---|---|---|
| zstd `-10` | 28 MB | fast (done at 1.30 s) |
| xz | 21 MB | +1.2 s (done at 2.52 s), kernel stage 0.7 → 2.0 s |
| zstd `-19` (current) | 21 MB | fast (done at 1.23 s) |
| zstd `--ultra -22` | 20 MB | fast, not worth the extra flag |

## Greeter

noctalia-greeter was replaced by dot-greeter (`packages/dot-greeter`, `system/greeter.nix`), a
console greeter in Rust.

| | noctalia-greeter | dot-greeter |
|---|---|---|
| greetd start → greeter on screen | 1.26–1.31 s | 0.36–0.39 s (+ a few ms to draw) |
| Power-on → greeter on screen (fast-POST boots) | 17.4–17.8 s | 16.5–16.7 s |

Measured from the journal on 2026-11-21: `Started greetd` to noctalia's first
`AccountsService` log line, or to the greeter PAM session for dot-greeter. Most of the remaining
0.36 s is greetd opening the PAM session of the `greeter` user (systemd --user, gnome-keyring).

## BIOS

BIOS settings can be read and written from Linux through the `hp_bioscfg` driver at `/sys/class/firmware-attributes/hp-bioscfg/attributes/<name>/current_value`. Writing needs root, and a new value applies on the next boot.

| Setting | Value | Note |
|---|---|---|
| BIOS version | 01.01.05 → 01.09.02 | updated with `fwupdmgr update`; POST did not get faster |
| Fast Boot | Enable | already set |
| Startup Delay (sec.) | 0 | already set |
| Network (PXE) Boot | Disable | set from Linux |
| Pre-boot WiFi | Disable | set from Linux; within noise (6.8 s vs ~7 s) |
| Pre-boot HBMA Support | Enable in sysfs, shown off in F10 | inactive while PXE boot is off (probable); writing it fails with `hp_bioscfg: Returned error 0x6, "Invalid command parameter"` |
| IPv6 during UEFI Boot | Enable in sysfs, shown off in F10 | same as above |

Do not touch Secure Boot, TPM clear or the storage mode. HP Cloud Managed and Remote Device Management are enabled, so a managing organisation could reset these settings.

## Open issues

- **Slow POST on some reboots.** Some boots spend 13.5–16 s in firmware instead of ~7 s, on both BIOS versions. All of them were quick reboots done while testing on 2026-11-21. Every cold power-on in the journal (13–21 Nov) took 6.7–7.8 s, so normal daily use is not affected. If it ever shows up on a cold boot, check the BIOS event log (F10 → Main).
- **Loader at 5.5 s.** Before the initrd change, the loader took either 2.7–3.2 s or 5.5 s with the same files. Since the change it has stayed at 1.5 s, which the 7 MB smaller initrd alone does not explain. If 5.5 s comes back, look at the firmware.

## Not done yet

- Optionally disable USB Storage Boot (no booting from a USB stick until it is enabled again).
- Make `libvirtd` socket-activated: it costs 1.6 s at every boot, but it does not delay the greeter.

## How to measure

```bash
systemd-analyze
systemd-analyze blame | grep -v device
systemd-analyze critical-chain greetd.service
for b in -4 -3 -2 -1 0; do journalctl -b $b -o cat | grep -m1 "Startup finished in .*firmware"; done
```

Change one setting at a time, judge it over 2–3 boots without touching the keyboard, and ignore the ~15 s firmware outliers. Time spent in the BIOS menu counts as firmware time.
