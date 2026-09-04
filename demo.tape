Output demo.gif

Set Shell "zsh"
Set FontSize 16
Set Width 1400
Set Height 800
Set Padding 20
Set Theme "Catppuccin Mocha"
Set TypingSpeed 50ms
Set WindowBar Colorful

# Open neovim (no file args = file tree only)
Type "nvim"
Enter
Sleep 3s

# Move focus to a file in neo-tree then open it
# (navigate right to editor area)
Ctrl+W
Type "l"
Sleep 500ms

# Open Crush popup with Space cc
Space
Type "cc"
Sleep 3s

# Ask Crush something
Type "Status?"
Enter
Sleep 8s

# Click outside / dismiss popup (Escape terminal mode, then toggle)
Escape
Escape
Sleep 300ms
Space
Type "cc"
Sleep 2s

# Quit
Type ":qa!"
Enter
Sleep 1s
