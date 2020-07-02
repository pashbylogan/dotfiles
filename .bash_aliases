#Custom aliases
alias home='ssh pashb@4musicians.ddns.net'
alias lab='ssh -p 922 pashbyl@labs-last.cs.wwu.edu'
alias 408='ssh -J pashbyl@jump.cs.wwu.edu:922 -p 922 pashbyl@cf408-hut-11.cs.wwu.edu'
alias gimli='ssh pashbyl@192.168.1.200'
alias panoply='cd ~/Desktop/PanoplyJ/;./panoply.sh'
alias cluster='ssh -p 922 pashbyl@csci-head.cluster.cs.wwu.edu'
alias vpn='sudo protonvpn c -f'
alias sudo='sudo '
alias k2='echo 0 | sudo tee /sys/module/hid_apple/parameters/fnmode'
alias as='~/snap/android-studio/bin/./studio.sh'
alias sgit='ssh-add -D;ssh-add ~/.ssh/id_ed25519_school'
alias pgit='ssh-add -D;ssh-add ~/.ssh/id_ed25519'
alias ve='source ~/.venv/bin/activate'
alias hut='ssh -J pashbyl@jump.cs.wwu.edu:922 -p 922 pashbyl@cf408-hut-11.cs.wwu.edu'
alias fin='cd ~/projects/finance;source .finance-venv/bin/activate'