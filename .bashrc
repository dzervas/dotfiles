# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# don't put duplicate lines in the history. See bash(1) for more options
export HISTCONTROL=ignoredups

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(lesspipe)"

# color prompt
PS1='\[\e[0;31m\]\u\[\e[m\] \[\e[1;34m\]\w\[\e[m\] \[\e[0;31m\]\$ \[\e[m\]\[\e[0;m\]'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

# remove all *.pyc files in current directory
alias rmpyc='find . -name "*.pyc" -exec rm -rf {} \;'

# update all git repos in current dir
alias gitup='for dir in *; do  if \[ -d "$dir/.git" \]; then cd $dir; echo "$dir:"; git pull; cd ..; fi; done'

#if [ -f ~/.bash_aliases ]; then
#    . ~/.bash_aliases
#fi

# enable color support of ls and also add handy aliases
if [ "$TERM" != "dumb" ]; then
    eval "`dircolors -b`"
    alias ls='ls --color=auto'
    alias grep='grep --color'
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi
# advanced bash completion
if [ -f ~/.bash-completion/bash_completion ]; then
    . ~/.bash-completion/bash_completion
fi

export EDITOR=vim
PATH="$PATH:~/.gem/ruby/1.9.1/bin"

#
# run fortune at startup
#

export PERL_LOCAL_LIB_ROOT="/home/ttouch/perl5";
export PERL_MB_OPT="--install_base /home/ttouch/perl5";
export PERL_MM_OPT="INSTALL_BASE=/home/ttouch/perl5";
export PERL5LIB="/home/ttouch/perl5/lib/perl5/x86_64-linux-thread-multi:/home/ttouch/perl5/lib/perl5";
export PATH="/home/ttouch/perl5/bin:$PATH";
