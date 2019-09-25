function docker_rm --description "Removed all exited docker instances"
	docker rm (docker ps --no-trunc -aqf status=exited)
end

function docker_rmi --description "Remove all dangling docker images"
	docker rmi (docker images --no-trunc -qf dangling=true)
end

alias 1ping      "ping 1.1.1.1"
alias open       "xdg-open"
alias passgen    "gpg --gen-random --armor 1 "
alias pgrep      "pgrep -af"
alias weather    "curl wttr.in"
alias webserver  "python3 -m http.server"

alias cat        "bat -p --paging=never"
alias diff       "colordiff -ub"
alias grep       "rg"
alias less       "bat -p"
alias find       "fd"

alias d          "docker"
alias dc         "docker-compose"
alias g          "git"
alias ipy        "ipython"
alias jc         "curl -i -H 'Content-Type: application/json'"
alias l          "lsd -F"
alias ll         "lsd -Fal"
alias ls         "lsd -F"
alias py         "python"
alias py2        "python2"
alias py3        "python3"
alias v          "nvim"
alias sv         "sudoedit"
alias :q         "exit"
