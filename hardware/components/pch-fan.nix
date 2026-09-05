{ lib, pkgs, ... }: let
  # The X570 chipset fan hangs off the nct6798's 6th fan header (fan6/pwm6).
  # ASUS does not expose it in the BIOS Q-Fan UI, so it runs a hardcoded EC
  # curve that pins it at ~4200 RPM even at idle.
  #
  # Rather than steering pwm6 from a userspace daemon, program the Super I/O's
  # own SmartFan IV curve: the chip then enforces it in hardware, so a crashed
  # or stopped service can never leave the chipset uncooled.

  # Temperature source index, matching tempN_input. 9 = SMBUSMASTER 1, which
  # reads the X570 I/O die over SB-TSI and carries the same value as
  # TSI1_TEMP (TSI0_TEMP tracks Tctl, i.e. the CPU die). The SmartFan source
  # register only accepts the chip's native inputs 1-12, so TSI1_TEMP's own
  # index (14) is rejected - 9 is the reachable alias for it.
  #
  # ASUS ships this fan keyed to source 8 (PECI, i.e. CPU temp), which is why
  # it ramps for reasons unrelated to the chipset.
  tempSource = 9;

  # Ascending (temp °C, duty 0-255) points. The fan has a hardware floor of
  # ~1400 RPM and cannot be stopped, so point 1 is just "as slow as it goes".
  curve = [
    { temp = 60; pwm = 20; }
    { temp = 70; pwm = 40; }
    { temp = 80; pwm = 90; }
    { temp = 90; pwm = 180; }
    { temp = 95; pwm = 255; }
  ];

  writePoints = lib.concatStringsSep "\n" (lib.imap1 (i: p: ''
    echo ${toString p.temp}000 > "$hw/pwm6_auto_point${toString i}_temp"
    echo ${toString p.pwm} > "$hw/pwm6_auto_point${toString i}_pwm"
  '') curve);

  setPchFan = pkgs.writeShellScript "set-pch-fan" ''
    set -eu
    shopt -s nullglob

    for hw in /sys/devices/platform/nct6775.*/hwmon/hwmon*; do
      [ -e "$hw/pwm6" ] || continue

      echo ${toString tempSource} > "$hw/pwm6_temp_sel"
      ${writePoints}
      echo 5 > "$hw/pwm6_enable" # SmartFan IV

      exit 0
    done

    echo "nct6775 pwm6 not found - PCH fan left on the firmware curve" >&2
    exit 1
  '';
in {
  boot.kernelModules = [ "nct6775" ];

  systemd.services.pch-fan = {
    description = "Program the X570 chipset fan curve into the nct6798";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];

    # The Super I/O loses its programming across S3, so reapply on resume.
    wants = [ "post-resume.target" ];
    partOf = [ "post-resume.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = setPchFan;
    };
  };
}
