#!/bin/bash

COOKIE="PROGETTO_FL_SECRET"

# Forziamo a mano i percorsi per evitare che WSL usi i link UNC di rete
LINUX_PATH="/mnt/c/DistributedSystems/cluster_init"
WINDOWS_PATH="C:\\DistributedSystems\\cluster_init"

echo "=== Spostamento forzato nella cartella su Disco C ==="
# Creiamo la cartella reale su Windows se non esiste
mkdir -p "$LINUX_PATH"

# Ci spostiamo fisicamente dentro il disco C prima di compilare
cd "$LINUX_PATH" || exit

echo "=== Compilazione del codice Erlang ==="
erlc node_fl.erl

echo "=== Apertura dei 3 terminali nativi ==="

# Usiamo /d per obbligare Windows a partire da C:\DistributedSystems\cluster_init
cmd.exe /c start /d "$WINDOWS_PATH" wsl.exe erl -sname nodo1 -setcookie $COOKIE -run nodo_fl start_aggregator

sleep 1

cmd.exe /c start /d "$WINDOWS_PATH" wsl.exe erl -sname nodo2 -setcookie $COOKIE -run nodo_fl start_worker

cmd.exe /c start /d "$WINDOWS_PATH" wsl.exe erl -sname nodo3 -setcookie $COOKIE -run nodo_fl start_worker

echo "=== Fatto! Controlla la barra delle applicazioni ==="