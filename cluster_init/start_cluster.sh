#!/bin/bash

COOKIE="PROGETTO_FL_SECRET"

# Imposto i percorsi manualmente per evitare problemi con i path UNC di WSL
LINUX_PATH="/mnt/c/DistributedSystems/cluster_init"
WINDOWS_PATH="C:\Users\giaco\OneDrive\Documents\GitHub\DistributedSystems\cluster_init"

echo "=== Spostamento forzato nella cartella su Disco C ==="
# Creo la cartella se non esiste
mkdir -p "$LINUX_PATH"

# Entro nella cartella prima di compilare
cd "$LINUX_PATH" || exit

echo "=== Compilazione del codice Erlang ==="
erlc node_fl.erl

echo "=== Apertura dei 3 terminali nativi ==="

# /d serve per far partire Windows direttamente dalla cartella corretta
cmd.exe /c start /d "$WINDOWS_PATH" wsl.exe erl -sname nodo1 -setcookie $COOKIE -run nodo_fl start_aggregator

sleep 1

cmd.exe /c start /d "$WINDOWS_PATH" wsl.exe erl -sname nodo2 -setcookie $COOKIE -run nodo_fl start_worker

cmd.exe /c start /d "$WINDOWS_PATH" wsl.exe erl -sname nodo3 -setcookie $COOKIE -run nodo_fl start_worker

echo "=== Fatto! Controlla la barra delle applicazioni ==="