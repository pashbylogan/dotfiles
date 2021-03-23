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
alias sql='ssh -N -p922 -L4321:mysql.cs.wwu.edu:3306 pashbyl@proxy.cs.wwu.edu'
alias dotf='cd ~/projects/dotfiles'
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
