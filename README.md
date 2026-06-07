# Hospital Node (Erlang/Python Bridge)

Questo progetto utilizza Erlang come orchestrator e Python come worker, comunicando tramite `open_port`.

## Struttura
- `erlang_orchestrator/`: Applicazione OTP Erlang.
- `python_worker/`: Script Python per il processing dei dati.

## Come avviare
1. Apri un terminale nella cartella `erlang_orchestrator`.
2. Compila i moduli:
   ```bash
   erlc -o ebin src/*.erl
   ```
3. Avvia la shell di Erlang:
   ```bash
   erl -pa ebin -eval "application:start(erlang_orchestrator)."
   ```
   *Nota: Il percorso del worker Python è predefinito come `../python_worker/worker.py` (assumendo l'avvio dalla directory `erlang_orchestrator`). Puoi sovrascriverlo con:*
   ```bash
   erl -pa ebin -erlang_orchestrator python_worker_script '"/percorso/assoluto/worker.py"' -eval "application:start(erlang_orchestrator)."
   ```
4. Testa il bridge inviando un messaggio:
   ```erlang
   python_worker_srv:send_message("Ciao Python!").
   ```

## Cluster Auto-Discovery
Per avviare il nodo in modalità cluster e autoconnetterti ad altri nodi, fornisci un nome di nodo (`-sname`), un cookie segreto (`-setcookie`) e passa la variabile `seed_nodes`:
```bash
erl -sname nodo1 -setcookie ospedale_cookie -pa ebin -erlang_orchestrator seed_nodes "['nodo2@hostname', 'nodo3@hostname']" -eval "application:start(erlang_orchestrator)."
```
All'avvio, il sistema stamperà log chiari (✅ / ⚠️) ad indicare lo stato della connessione verso ogni nodo seed fornito.
