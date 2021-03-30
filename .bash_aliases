#Custom aliases
alias home='ssh pashb@4musicians.ddns.net'
alias gimli='ssh pashbyl@192.168.1.200'
alias panoply='cd ~/Desktop/PanoplyJ/;./panoply.sh'
alias cluster='ssh -p 922 pashbyl@csci-head.cluster.cs.wwu.edu'
alias vpn='sudo protonvpn c -f'
alias sudo='sudo '
alias k2='echo 0 | sudo tee /sys/module/hid_apple/parameters/fnmode'
alias ve='source ~/.venv/bin/activate'
alias server='java -Xmx8G -Xms1G -jar server.jar nogui'
alias dotf='cd ~/projects/dotfiles'
alias createVenv='python3 -m venv .venv'
# Attaches tmux to the last session; creates a new session if none exists.
alias t='tmux attach || tmux new-session'

# Attaches tmux to a session (example: ta portal)
alias ta='tmux attach -t'

# Creates a new session
alias tn='tmux new-session'

# Lists all ongoing sessions
alias tl='tmux list-sessions'

copyTo(){
    scp -r -P 922 "$1" pashbyl@linux.cs.wwu.edu:"$2";
}
copyFrom(){
    scp -r -P 922 pashbyl@linux.cs.wwu.edu:"$1" "$2";
}
fin(){
    cd ~/projects/finance;
    source .finance-venv/bin/activate;
    ./finance.py;
}

function jptt(){
    # Forwards port $1 into port $2 and listens to it
    ssh -p 922 -N -f -L localhost:$2:localhost:$1 pashbyl@cf408-hut-10.cs.wwu.edu
}
