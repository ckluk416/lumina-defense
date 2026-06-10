{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "lumina-defense-dev-shell";

  buildInputs = with pkgs; [
    # Roblox/Luau Development Tools
    aftman     # Roblox toolchain manager
    rojo       # Roblox sync tool
    luau       # Luau interpreter and repl
    stylua     # Lua/Luau code formatter
    selene     # Lua/Luau linter
    
    # Common helper utilities
    git        # Version control
    nodejs     # Node.js runtime if they have build scripts or dependencies
  ];

  shellHook = ''
    echo "====================================================="
    echo "   Welcome to the Lumina Defense Development Shell   "
    echo "====================================================="
    echo "Available commands:"
    echo "  - rojo serve   : Start the Rojo sync server"
    echo "  - rojo build   : Build the project to a .rbxl file"
    echo "  - aftman install : Install configured tools"
    echo "  - stylua .     : Format all Luau scripts"
    echo "  - selene src   : Lint all Luau scripts"
    echo ""
    echo "Active Toolchain Versions:"
    if command -v rojo &> /dev/null; then
      echo "  Rojo: $(rojo --version)"
    else
      echo "  Rojo: (not installed, run 'aftman install')"
    fi
    
    if command -v aftman &> /dev/null; then
      echo "  Aftman: $(aftman --version)"
    else
      echo "  Aftman: (not installed)"
    fi
    echo "====================================================="
  '';
}
