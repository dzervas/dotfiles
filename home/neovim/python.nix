{ lib, ... }: {
  programs.nixvim = {
    plugins = {
      # Python interactive development
      molten = {
        enable = true;
        settings = {
          auto_image_popup = true;
          auto_init_behavior = "init";
          auto_open_output = true;
          output_win_max_height = 20;
          enter_output_behavior = "open_and_enter";
          tick_time = 150;
        };
        python3Dependencies = lib.mkAfter (p: with p; [
          cairosvg
          jupyter
          kaleido
          nbformat
          pillow
          plotly
          pnglatex
          pyperclip
        ]);
      };

      dap-python.enable = true;
    };

    keymaps = [
      { key = "<leader>pi"; action = "<CMD>MoltenInit python3<CR>"; options.desc = "Initialize Molten"; }
      { key = "<leader>pe"; action = "<CMD>MoltenEvaluateOperator<CR>"; options.desc = "Evaluate operator"; }
      { key = "<leader>pl"; action = "<CMD>MoltenEvaluateLine<CR>"; options.desc = "Evaluate line"; }
      { key = "<leader>pr"; action = "<CMD>MoltenReevaluateCell<CR>"; options.desc = "Evaluate cell"; }
      { key = "<leader>pv"; action = ":<C-u>MoltenEvaluateVisual<CR>gv"; mode = "v"; options.desc = "Evaluate selected code"; }
      { key = "<leader>ph"; action = "<CMD>MoltenHideOutput<CR>"; options.desc = "Hide output"; }
      { key = "<leader>ps"; action = "<CMD>MoltenShowOutput<CR>"; options.desc = "Show output"; }
      { key = "<leader>pd"; action = "<CMD>MoltenDelete<CR>"; options.desc = "Delete Molten session"; }
    ];
  };
}
