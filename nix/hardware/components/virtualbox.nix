{ ... }: {
  virtualisation.virtualbox.host = {
    enable = true;
    enableKvm = true;
    enableExtensionPack = true;

    # Can't co-exist with enableKvm
    addNetworkInterface = false;
  };
}
