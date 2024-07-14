{ pkgs, ... }: {
	programs.swaylock = {
		enable = true;
		package = pkgs.swaylock-effects;
		settings = {
			grace = 5;
			fade-in = 0.1;
			effect-blur = "20x3";
			disable-caps-lock-text = true;
			show-keyboard-layout = true;
			show-failed-attempts = true;
		};
	};
}
