# Hospital Node (Erlang/Python Bridge)

Questo progetto utilizza Erlang come orchestrator e Python come worker, comunicando tramite `open_port`, implementando un'infrastruttura distribuita resiliente per il Federated Learning in ambito ospedaliero (Cross-Silo).

## 🏛️ Design Choices & Architettura (Federated Learning)
Per garantire i massimi standard di affidabilità e per giustificare le scelte architetturali in sede accademica, il sistema è stato progettato con le seguenti caratteristiche:

* **Ports vs NIFs (Fault Isolation):** La comunicazione Erlang-Python avviene tramite Standard I/O (`open_port`) anziché Native Implemented Functions (NIFs). Un crash di Python (es. GPU Out-of-Memory) non compromette la BEAM VM; il Supervisore Erlang rileva il guasto e riavvia il worker istantaneamente (`restart_type: permanent`).
* **Leader Election (Bully Algorithm):** Sfruttando la comparazione nativa degli atomi di Erlang (`node/0`), il Bully Algorithm offre un consenso stateless e rapido, ideale per reti Full-Mesh.
* **Resilienza agli Stragglers (Timeout Asincrono):** Il Leader gestisce i nodi ritardatari tramite timer asincroni non bloccanti (`erlang:send_after/3`). Allo scadere del timeout di round (5000 ms), il Leader esegue un'aggregazione d'emergenza parziale ignorando i nodi silenti per non paralizzare il processo.
* **Zero-Dependencies:** L'intera serializzazione JSON e l'instradamento dei pacchetti sono gestiti custom (es. `string:join/2`, `lists:splitwith/2`), eliminando la necessità di dipendenze esterne.

## Struttura
- `erlang_orchestrator/`: Applicazione OTP Erlang.
- `python_worker/`: Script Python per il processing dei dati.
- `test/`: Suite di Automated Testing (EUnit).

## Come avviare
1. Apri un terminale nella cartella `erlang_orchestrator`.
2. Compila i moduli (inclusi i file di test):
   ```bash
   erlc -DTEST -o ebin src/*.erl test/*.erl

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

## Cluster Auto-Discovery e FL Round

Per avviare il nodo in modalità cluster e autoconnetterti ad altri nodi, fornisci un nome di nodo (`-sname`), un cookie segreto (`-setcookie`) e passa la variabile `seed_nodes`:

```bash
erl -sname nodo1 -setcookie ospedale_cookie -pa ebin -erlang_orchestrator seed_nodes "['nodo2@hostname', 'nodo3@hostname']" -eval "application:start(erlang_orchestrator)."

```

All'avvio, il sistema stamperà log chiari (✅ / ⚠️) ad indicare lo stato della connessione verso ogni nodo seed fornito.

**Avviare il Federated Learning:**
Una volta che i nodi sono connessi, lancia l'elezione da un nodo qualsiasi:

```erlang
bully_srv:start_election().

```

Dal terminale del nodo appena eletto come Leader, innesca il round di addestramento globale:

```erlang
fl_manager_srv:start_round().

```

## 🧪 Collaudo Formale (Automated Testing)

La resilienza matematica, i calcoli dei quorum e la gestione asincrona degli stragglers sono collaudati tramite suite **EUnit** (White-Box Testing). I test sfruttano la tecnica del *PID Mocking* per isolare l'albero di supervisione e testare la logica OTP in ambiente puro.

Per eseguire la suite di test automatizzati:

```bash
erl -pa ebin -noshell -eval 'eunit:test(fl_manager_tests, [verbose]).' -s init stop

```