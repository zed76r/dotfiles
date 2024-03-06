# load acme.sh
if [ -f "$HOME/.acme.sh/acme.sh.env" ]; then
    . "$HOME/.acme.sh/acme.sh.env"
fi

# set PATH so it includes user's private bin if it exists 
if [ -d "$HOME/bin" ] ; then 
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# pnpm
export PNPM_HOME="/home/zed/.local/share/pnpm"
PATH="$PNPM_HOME:$PATH"
# pnpm end

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"


#if [[ -f "$HOME/.kube/config" ]]; then
#    export KUBECONFIG=$HOME/.kube/config
#fi
