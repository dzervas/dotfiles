#!/bin/bash
RUST_PATH=~/.local/share/Steam/steamapps/common/Rust

cd $RUST_PATH
./rust &
RUST_PID=$!
echo "Rust started with PID: $RUST_PID"
while ps -p $RUST_PID > /dev/null
do
	WORKER_PID=$(ps aux | grep " ./rust$" | grep -v grep | grep -v $RUST_PID | awk '{print $2}')
	if [ -n "$WORKER_PID"  ]
	then
		echo "Killing worker thread: $WORKER_PID"
		kill $WORKER_PID
	fi
	sleep 0.02
done
echo "Rust no longer appears to be running, shutting down"
cd -
