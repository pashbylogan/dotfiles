echo "Welcome! Let's start setting up your system. It could take more than 10 minutes, be patient"
PATH = "~/projects/dotfiles/"

echo "What name do you want to use in GIT user.name?"
echo "For example, mine will be \"Logan Pashby\""
read git_config_user_name

echo "What email do you want to use in GIT user.email?"
echo "For example, mine will be \"pashbylogan@gmail.com\""
read git_config_user_email

echo "What is your github username?"
echo "For example, mine will be \"pashbylogan\""
read username

cd ~ && sudo apt-get update

echo 'Installing curl' 
sudo apt-get install curl -y

echo 'Installing neofetch' 
sudo apt-get install neofetch -y

echo 'Installing tool to handle clipboard via CLI'
sudo apt-get install xclip -y

echo 'Installing latest git' 
sudo add-apt-repository ppa:git-core/ppa -y
sudo apt-get update && sudo apt-get install git -y

echo 'Installing python3-pip'
sudo apt-get install python3-pip -y

echo "Setting up your git global user name and email"
git config --global user.name "$git_config_user_name"
git config --global user.email $git_config_user_email

echo 'Cloning your .gitconfig from gist'
cp $PATH+.gitconfig ~

echo 'Generate SSH Key?'
read bool
if [$bool == 'Y' || $bool == 'y'] ; then
  ssh-keygen -t ed25519 -C $git_config_user_email
  ssh-add ~/.ssh/id_ed25519
  cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard
fi

echo 'Installing ZSH'
sudo apt-get install zsh -y
sh -c "$(wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"
chsh -s $(which zsh)

echo 'Cloning your .zshrc from gist'
cp $PATH+.zshrc ~
cp -r $PATH+.oh-my-zsh ~

echo 'Indexing snap to ZSH'
sudo chmod 777 /etc/zsh/zprofile
echo "emulate sh -c 'source /etc/profile.d/apps-bin-path.sh'" >> /etc/zsh/zprofile

source ~/.zshrc
clear

echo 'Installing NodeJS LTS'
nvm --version
nvm install --lts
nvm current

# echo 'Installing VSCode'
# curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
# sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
# sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
# sudo apt-get install apt-transport-https -y
# sudo apt-get update && sudo apt-get install code -y

# echo 'Installing Code Settings Sync'
# code --install-extension Shan.code-settings-sync
# sudo apt-get install gnome-keyring -y
# cls

echo 'Installing Docker'
sudo apt-get purge docker docker-engine docker.io
sudo apt-get install docker.io -y
sudo systemctl start docker
sudo systemctl enable docker
docker --version

sudo groupadd docker
sudo usermod -aG docker $USER
sudo chmod 777 /var/run/docker.sock

echo 'Installing docker-compose'
sudo curl -L "https://github.com/docker/compose/releases/download/1.26.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version

echo 'Installing Heroku CLI'
curl https://cli-assets.heroku.com/install-ubuntu.sh | sh
heroku --version

echo 'Installing Neovim'
sudo apt install neovim
mkdir ~/.config
cp -r $PATH+.config ~/.config

echo 'Installing Tmux'
sudo apt install tmux
cp -r $PATH+.tmux ~
cd ~
ln -s -f .tmux/.tmux.conf
cd -
cp $PATH+.tmux.conf.local .

echo 'Updating and Cleaning Unnecessary Packages'
sudo -- sh -c 'apt-get update; apt-get upgrade -y; apt-get full-upgrade -y; apt-get autoremove -y; apt-get autoclean -y'
clear

echo 'All setup, enjoy!'
