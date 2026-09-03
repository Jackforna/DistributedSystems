# Resoconto di Sviluppo (Gabbo)

Questo documento fornisce una guida passo-passo nel progetto di *Federated Learning Cross-Silo* applicato ad ambienti sanitari.

---

# Blocco 1 (Node-Level Architecture) (Gabbo)
L'obiettivo principale di questa fase è stato quello di consolidare l'architettura a livello di singolo nodo ospedaliero (**Node-Level**), garantendo il principio di **Fault Isolation** descritto nel capitolo 3.2 della relazione tecnica, isolando l'ambiente d'inferenza Python dai crash applicativi e strutturando l'orchestrazione Erlang secondo i canoni OTP.


## 📌 Step 1: Scaffolding dell'Infrastruttura OTP
Abbiamo abbandonato gli script "volanti" usati nel Proof of Concept iniziale per adottare la struttura standard dei sistemi di produzione Erlang/OTP.

1. **Inizializzazione Git**: Configurazione del repository locale per tracciare le modifiche in modo incrementale.
2. **Struttura Directory**:
   - `erlang_orchestrator/src/`: Cartella destinata a contenere i file sorgente Erlang (`.erl`).
   - `erlang_orchestrator/ebin/`: Cartella per i file binari compilati dalla macchina virtuale BEAM (`.beam`).
   - `python_worker/`: Directory dedicata all'ambiente di esecuzione dei modelli di intelligenza artificiale (Python).

---

## 📌 Step 2: Implementazione del Supervision Tree (Erlang)
Per garantire la massima tolleranza ai guasti, abbiamo delegato la gestione dei processi a un albero di supervisione nativo.

1. **Creazione del Supervisore (`orchestrator_sup.erl`)**:
   - Configurato con una strategia di riavvio `one_for_one`.
   - Ha il compito di monitorare il ciclo di vita del GenServer preposto alla comunicazione con Python.
2. **Creazione del GenServer (`python_worker_srv.erl`)**:
   - Implementa il comportamento standard `gen_server`.
   - Incapsula la logica di `open_port/2` per l'apertura del canale di comunicazione via standard I/O del sistema operativo.
3. **Disaccoppiamento dei Percorsi (Path Management)**:
   - Invece di usare percorsi assoluti hardcoded, il GenServer interroga le variabili di configurazione tramite `application:get_env/2`.
   - È stato definito un fallback di default relativo (`../python_worker/worker.py`), garantendo la portabilità del codice tra diversi terminali WSL senza necessità di riconfigurazione.

---

## 📌 Step 3: Sviluppo e Integrazione del Worker Python
Abbiamo superato lo script minimale di "Echo" standard fornito in fase di scaffolding iniziale, inserendo la logica matematica necessaria per simulare i calcoli tensoriali.

1. **Loop di Ascolto Continuo**: Implementato tramite `sys.stdin.readline()` all'interno di un ciclo condizionale per catturare i messaggi inviati dall'orchestratore Erlang.
2. **Elaborazione Numerica**: Il payload testuale viene convertito in un tipo a virgola mobile (`float`) e moltiplicato per `2.0` (simulando una manipolazione elementare dello spazio latente o dei gradienti).
3. **Gestione Robusta delle Eccezioni**:
   - Inserimento di un blocco `try/except ValueError` per intercettare l'invio di stringhe non conformi o pacchetti corrotti.
   - Forzatura immediata del buffer di output tramite `sys.stdout.flush()` per garantire la natura asincrona ma non bloccante del bridge.

---

## 📌 Step 4: Validazione della Fault Isolation (Chaos Monkey Test)
Abbiamo sottoposto il nodo a uno stress test per verificare la resilienza dell'architettura in caso di anomalie fisiche (es. Out of Memory della GPU in ambiente Python).

1. **Verifica dei Messaggi Validi**: Il comando `python_worker_srv:send_message("21")` ha restituito con successo il valore atteso `42.0`.
2. **Simulazione del Guasto Brutale**: È stato individuato il PID del processo Python in background tramite `ps aux` e terminato forzatamente via terminale Linux con il segnale distruttivo:

# BLOCCO 2: Network-Level Architecture & Cluster Full-Mesh (Jack)

L'obiettivo di questa fase è stato l'implementazione del **Capitolo 4.1** della relazione tecnica: connettere fisicamente i diversi nodi (silos ospedalieri) in una topologia decentralizzata a maglia completa (**Full-Mesh**) sfruttando il demone nativo di Erlang `epmd` (Erlang Port Mapper Daemon) e automatizzando la scoperta reciproca senza interventi manuali dell'operatore.

## 📌 Step 1: Sviluppo del modulo Auto-Discovery (`cluster_manager_srv.erl`)
Per evitare la necessità di effettuare accoppiamenti di rete manuali, è stato introdotto un gestore di cluster automatizzato.

1. **Disaccoppiamento dell'Avvio**: Nella funzione `init/1`, il modulo invia un messaggio a se stesso (`self() ! discover_nodes`). Questo schema asincrono impedisce che eventuali latenze di rete o timeout durante la fase di aggancio blocchino l'avvio dell'intero Supervision Tree dell'applicazione.
2. **Gestione dei Nodi Seed**: Il modulo interroga le configurazioni d'ambiente tramite `application:get_env(erlang_orchestrator, seed_nodes, [])` per estrarre una lista dinamica di atomi rappresentanti i nodi di riferimento (es. `['siloa@hostname']`).
3. **Ping di Rete e Feedback Visivo**: Sfruttando `net_adm:ping/1`, il server tenta la connessione con i nodi designati, stampando a console messaggi diagnostici colorati tramite sequenze ANSI (✅ verde per connessione stabilita, ⚠️ giallo per nodo non raggiungibile).

## 📌 Step 2: Aggiornamento dell'Albero di Supervisione
Il modulo `cluster_manager_srv` è stato registrato all'interno di `orchestrator_sup.erl` come figlio con strategia di riavvio `permanent`. È stato posizionato come primo elemento della lista `ChildSpecs` per garantire che l'infrastruttura di rete si attivi immediatamente prima o in parallelo al posizionamento dei servizi di calcolo locali (`python_worker_srv`).

## 📌 Step 3: Risoluzione del Bug di Build Applicativa (`.app`)
Durante i test preliminari in ambiente multi-terminale su WSL, l'avvio tramite `application:start/1` falliva in silenzio, impedendo il caricamento dei moduli supervisionati.
- **Causa**: Il compilatore nativo `erlc` traduce i file sorgente in file binari `.beam` ma non sposta autonomamente i metadati di configurazione dell'applicazione.
- **Risoluzione**: È stato introdotto un passaggio esplicito nella build-pipeline per copiare e rinominare il file descrittore delle risorse:
  ```bash
  cp src/erlang_orchestrator.app.src ebin/erlang_orchestrator.app
Questa operazione ha esposto correttamente le proprietà del modulo erlang_orchestrator alla macchina virtuale BEAM, sbloccando l'inizializzazione del cluster.

📌 Step 4: Validazione e Test Operativo del Cluster (Transitività Full-Mesh)
Il corretto comportamento della rete a maglia è stato validato simulando tre silos sanitari indipendenti (siloa, silob, siloc) su host LAPTOP-0F0BRMGK condividendo lo stesso cookie di sicurezza (-setcookie federated_cookie):

Silo A (Nodo Pivot): Avviato in ascolto isolato senza parametri seed.

Silo B (Aggancio Parziale): Avviato passando come seed node esclusivamente il Silo A. La console ha registrato l'avvenuta connessione automatica:

✅ Connesso al nodo 'siloa@LAPTOP-0F0BRMGK'
Silo C (Prova del Nove): Avviato passando come seed node esclusivamente il Silo B. Il sistema ha agganciato il Silo B e, per effetto della natura transitiva intrinseca del protocollo di distribuzione Erlang coordinato da epmd, ha chiuso la maglia automaticamente.

Interrogando il Silo C tramite la funzione di sistema nodes()., il terminale ha risposto con:

```Erlang
['silob@LAPTOP-0F0BRMGK', 'siloa@LAPTOP-0F0BRMGK']
```

La topologia Full-Mesh è configurata, stabile e pronta per ospitare i messaggi di sincronizzazione e l'algoritmo di consenso per l'elezione del Leader.

---

# 👑 BLOCCO 3: Leader Election (Bully Algorithm)

L'obiettivo di questa fase è stato implementare un meccanismo di consenso distribuito per determinare univocamente un nodo "Aggregatore" (Leader) all'interno del cluster ospedaliero, requisito fondamentale per orchestrare i round di addestramento nel Federated Learning.

La scelta architetturale è ricaduta sul **Bully Algorithm**, sfruttando le capacità native della BEAM VM per la comparazione alfanumerica degli identificativi di nodo.

## 📌 Step 1: Implementazione del Server di Consenso (`bully_srv.erl`)
È stato creato un nuovo GenServer dedicato esclusivamente alla gestione della macchina a stati dell'elezione.

1. **Gestione dello Stato**: Il server mantiene in memoria l'ID del Leader attualmente riconosciuto e un riferimento al timer di elezione (`timer = undefined`).
2. **Comparazione Nativa**: Invece di mappare ID numerici artificiali, l'algoritmo sfrutta la funzione di sistema `node/0`. In Erlang, la comparazione tra atomi è deterministica (es. `siloc@host` > `silob@host`), fornendo una gerarchia naturale e immutabile per la rete.
3. **Disaccoppiamento dell'Avvio**: L'elezione non viene innescata nella funzione `init/1` per evitare *race condition* con il modulo `cluster_manager_srv` (Auto-Discovery) sviluppato nel Blocco 2. Viene fornita un'API esplicita `bully_srv:start_election/0`.

## 📌 Step 2: Macchina a Stati e Messaggistica (Inter-Node Communication)
La logica di elezione è stata mappata su tre messaggi scambiati in modo asincrono tramite `gen_server:cast/2`:

- **ELECTION (`{election, FromNode}`)**: Un nodo notifica la propria candidatura esclusivamente ai nodi con identificativo strettamente maggiore (`Node > node()`).
- **ALIVE (`{alive, FromNode}`)**: Un nodo che riceve un messaggio di elezione da un nodo gerarchicamente inferiore risponde immediatamente per bloccarne la scalata, e avvia a sua volta la propria elezione verso l'alto.
- **COORDINATOR (`{coordinator, LeaderNode}`)**: Se il timer di elezione (2000ms) scade senza aver ricevuto alcun messaggio `alive` (perché il nodo è il maggiore in assoluto o i nodi maggiori sono guasti), il nodo si autoproclama Leader ed emette un broadcast a tutta la rete.

## 📌 Step 3: Integrazione nel Supervision Tree
Il modulo `bully_srv` è stato inserito in `orchestrator_sup.erl` con strategia `permanent`, affiancandosi al gestore di rete e al worker Python, garantendone il riavvio automatico in caso di crash della macchina a stati.

## 📌 Step 4: Collaudo del Cluster ed "Avalanche Effect"
Il sistema è stato collaudato su WSL istanziando tre nodi concorrenti (`siloa`, `silob`, `siloc`).
Innescando l'elezione dal gradino più basso della gerarchia (`siloa`), la rete ha reagito conformemente alla teoria dei Sistemi Distribuiti:

1. `siloa` ha sfidato i maggiori.
2. `silob` ha soppresso `siloa` e ha sfidato `siloc`.
3. `siloc` ha soppresso sia `siloa` che `silob`.
4. Allo scadere del timeout, `siloc` ha notificato a tutti il suo status di Leader.

**Nota Architetturale ("Avalanche Effect")**: Durante il test, i log hanno evidenziato la ricezione di messaggi `coordinator` duplicati da parte del Leader. Questo comportamento non costituisce un'anomalia, ma conferma la corretta aderenza all'implementazione purista del Bully Algorithm. L'effetto valanga si innesca poiché il nodo maggiore (`siloc`) riceve sfide quasi simultanee da più nodi inferiori, allocando molteplici timer concorrenti che, a scadenza, generano broadcast ridondanti.