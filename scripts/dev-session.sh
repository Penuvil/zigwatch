#!/usr/bin/env bash
tmux new-session -d -s dev -n edit 'hx .'
tmux split-window -h -t dev:0 'just watch'
tmux split-window -v -t dev:0.1 'bash'
tmux select-pane -t dev:0.0
tmux resize-pane -t dev:0.1 -D 6
tmux resize-pane -t dev:0.0 -R 12
tmux attach-session -t dev
