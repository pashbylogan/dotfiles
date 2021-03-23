#!/bin/bash
WARNED=false
for dir in */; do
    if [ -d "${dir}dotfiles" ]; then 
        for f in `ls -A "${dir}dotfiles`; do
        if [ -e ~/$f ] && ! $WARNED; then
                echo Warning: Files will be overwritten if you continue.
                while true; do
                        echo -n "Continue? (y/n): "
                        read user_in
                        if [ "$user_in" = "y" ]; then
                                WARNED=true
                                break
                        elif [ "$user_in" = "n" ]; then
                                exit 0
                        fi
                done
        fi
        echo Copying "${dir}dotfiles"/$f into place...
        ln -s "${dir}dotfiles"/$f ~
    fi
done
echo Done
