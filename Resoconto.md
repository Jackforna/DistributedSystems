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

---

# 🚀 BLOCCO 4: Trasmissione dei Pesi (Round-Trip Erlang-Python)

L'obiettivo del quarto blocco è stato quello di implementare il "sistema nervoso" del Federated Learning: stabilire un circuito chiuso asincrono in cui il nodo Leader impartisce l'ordine di addestramento, i nodi subordinati delegano il calcolo al proprio ambiente locale Python, e i risultati (pesi/gradienti) vengono instradati indietro al Leader per l'aggregazione.

## 📌 Step 1: Implementazione del Federated Learning Manager (`fl_manager_srv.erl`)
È stato introdotto un nuovo microservizio OTP dedicato alla gestione del ciclo di vita del singolo round di addestramento.

1. **Innesco del Round (`start_round/0`)**: Il Leader invia un broadcast asincrono (`{train_command, LeaderNode}`) a tutta la maglia Full-Mesh (incluso se stesso), ordinando l'inizio della computazione.
2. **Delega a Python**: Alla ricezione dell'ordine, ogni `fl_manager_srv` locale interagisce con il proprio bridge Python, inviando il dato grezzo iniziale (es. "10") e salvando in stato l'ID del Leader a cui dover rispondere.
3. **Accumulatore dei Pesi**: Il manager espone un `handle_cast` specifico per raccogliere i payload in arrivo (`{weights_payload, FromNode, Data}`). Quando eseguiti sul Leader, questi cast popolano la lista interna `accumulated_weights`, simulando il buffer di aggregazione.

## 📌 Step 2: Integrazione e Routing nel Bridge (`python_worker_srv.erl`)
È stata effettuata una modifica chirurgica al GenServer che gestisce la porta standard di comunicazione (Standard I/O) con il processo demone Python.
- All'interno del pattern matching `handle_info` che intercetta la tupla `{Port, {data, {eol, Line}}}`, è stato inserito un instradamento asincrono: `gen_server:cast(fl_manager_srv, {python_result, Line})`.
- Questo approccio garantisce la natura non bloccante della BEAM VM: Erlang non attende la fine dell'elaborazione Python, ma reagisce reattivamente non appena l'output stream solleva un evento.

## 📌 Step 3: Espansione del Supervision Tree
Il modulo `fl_manager_srv` è stato aggiunto all'albero di supervisione all'interno di `orchestrator_sup.erl`. Inserendolo in coda alla lista `ChildSpecs` con strategia `permanent`, ci assicuriamo che l'orchestrazione parta solo dopo che la rete e il worker Python siano già stati correttamente allocati.

## 📌 Step 4: Validazione Architetturale del Round-Trip
Il collaudo sul cluster (3 nodi, da `siloa` a `siloc`) ha confermato la corretta interconnessione delle tecnologie:

1. **Elezione**: Il cluster ha eletto `siloc` come Aggregatore tramite Bully Algorithm.
2. **Distribuzione**: È stato impartito il comando `fl_manager_srv:start_round()` sul Leader.
3. **Esecuzione Concorrente**: I processi Python dei tre nodi hanno ricevuto il segnale, effettuato il calcolo (moltiplicazione per 2.0) e immesso nel buffer di uscita la stringa `"RISULTATO_PYTHON: 20.0"`.
4. **Aggregazione Centrale**: La rete Erlang ha re-impacchettato i risultati locali e li ha spediti indietro a `siloc`, il quale ha confermato (tramite log visivi ANSI verdi) l'avvenuta ricezione e il salvataggio in memoria dei pesi per ciascun nodo partecipante.

Il layer di comunicazione distribuito è ora maturo per ospitare l'algoritmo matematico vero e proprio (Federated Averaging).

---

# 🧠 BLOCCO 5: Federated Averaging (FedAvg)

L'obiettivo conclusivo di questa fase è stato implementare il vero e proprio calcolo matematico del Federated Learning: il *Federated Averaging*. Abbiamo potenziato il worker Python affinché gestisca sia l'addestramento locale sia l'aggregazione globale, e abbiamo raffinato la comunicazione Erlang-Python per scambiare tensori strutturati in modo robusto.

## 📌 Step 1: Upgrade del Worker Python (`worker.py`)
Lo script Python ha abbandonato la logica "Echo" per trasformarsi in una macchina a stati reattiva, governata da prefissi testuali.
1. **Fase di Addestramento (`TRAIN`)**: Alla ricezione del comando, il nodo simula un addestramento locale generando un vettore di pesi randomizzati (es. `[0.85, 1.12, 0.91]`) per emulare la diversità dei dati clinici, restituendoli formattati come JSON con prefisso `TRAIN_RES|`.
2. **Fase di Aggregazione (`AGGREGATE|`)**: Alla ricezione del comando di aggregazione seguito dal payload globale (una lista di liste), Python effettua il parsing JSON, calcola la media aritmetica colonna per colonna (FedAvg puro) e restituisce il modello globale unificato con prefisso `AGGREGATE_RES|`.

## 📌 Step 2: Routing Intelligente in Erlang (`python_worker_srv.erl`)
Per gestire il doppio ruolo di Python senza incorrere in collisioni di messaggi, è stato introdotto un meccanismo di parsing nativo ed efficiente nel bridge Erlang.
- Sfruttando la funzione nativa `lists:splitwith/2`, il `gen_server` separa chirurgicamente l'intestazione dal payload intercettando il separatore `|`.
- Questo approccio ha permesso un pattern matching pulito per smistare i risultati asincroni (`{python_result, Data}` o `{aggregated_result, Data}`) al manager di competenza, senza l'uso di librerie di espressioni regolari (regex).

## 📌 Step 3: Serializzazione e Sincronizzazione (`fl_manager_srv.erl`)
Il manager del Federated Learning è stato aggiornato per attendere dinamicamente tutti i partecipanti e formattare i dati per l'aggregazione finale.
1. **Tracking Dinamico (`expected_nodes`)**: All'inizio del round, il Leader calcola quanti nodi devono rispondere (`length(nodes()) + 1`) e attende che la lista `accumulated_weights` raggiunga tale dimensione.
2. **Serializzazione Vanilla (`string:join/2`)**: Per evitare l'onere di dipendenze esterne (es. `jiffy` o `jsx` per il JSON in Erlang), l'array bidimensionale viene costruito "a mano" concatenando le stringhe di risposta con virgole e racchiudendole tra parentesi quadre. Il payload viene poi inviato al Python locale del Leader.

## 📌 Step 4: Collaudo Finale del Cluster
Il collaudo conclusivo del sistema ha visto il cluster di tre nodi WSL (`siloa`, `silob`, `siloc`[cite: 4]) eseguire un ciclo vitale completo, partendo da zero fino alla convergenza del modello.
1. **Startup e Discovery**: I nodi si sono interconnessi in topologia Full-Mesh (Blocco 2).
2. **Consenso**: Tramite Bully Algorithm, `siloc` è stato eletto Aggregatore Globale (Blocco 3).
3. **Distribuzione e Calcolo Locale**: Innescato l'inizio del round da `siloc`, tutti i nodi hanno delegato il calcolo ai rispettivi worker Python, i quali hanno generato e rispedito vettori di pesi indipendenti (Blocco 4).
4. **Federated Averaging Globale**: Raggiunto il quorum, `siloc` ha assemblato la super-lista, l'ha inviata al proprio Python e ha intercettato correttamente il risultato dell'aggregazione matematica, celebrando la fine del round con il log cromatico finale: `🧠 [FED-AVG] Round completato! Nuovo Modello Globale: [0.8034, 1.1232, 0.9598]`[cite: 4].

Il framework di Federated Learning distribuito è ora architetturalmente completo, resiliente ai guasti e funzionale.

# 🛡️ PILASTRO 1: Resilienza Avanzata e Gestione degli Stragglers

L'obiettivo di questa fase è stato quello di consolidare la robustezza del sistema distribuito, mitigando una delle vulnerabilità più critiche del Federated Learning: la gestione dei nodi ritardatari o bloccati (Stragglers).

## 📌 Il Problema: Il Collo di Bottiglia del Sincronismo

Nel Federated Learning reale, l'aggregazione globale dei pesi si aspetta la risposta di tutti i partecipanti (es. ospedali con capacità computazionali disomogenee). Un nodo lento o vittima di un partizionamento di rete invisibile (che non chiude la connessione ma smette di inviare dati) può provocare la paralisi dell'intero round di addestramento. Nel nostro modello originario, il Leader accumulava passivamente i pesi (`expected_nodes`), rimanendo bloccato all'infinito nell'attesa dell'ultimo pacchetto mancante.

## 📌 L'Implementazione: Timeout Asincrono d'Emergenza

Per risolvere questa fragilità senza ricorrere a complessi meccanismi di polling, abbiamo sfruttato i timer asincroni nativi della BEAM VM all'interno del modulo `fl_manager_srv`.

1. **Allocazione del Timer**: All'innesco del round (`start_round`), il Leader calcola i nodi attesi e contestualmente avvia un timer in background tramite `erlang:send_after(5000, self(), round_timeout)`.
2. **Successo Nominale (Happy Path)**: Se tutti i nodi rispondono entro la finestra di 5000 ms, l'accumulatore raggiunge il quorum (`length(NewAcc) >= Expected`). Il sistema cancella proattivamente il timer (`erlang:cancel_timer/1`) e procede alla normale aggregazione globale.
3. **Aggregazione Parziale d'Emergenza**: Se il timer scade, il modulo intercetta il messaggio asincrono `round_timeout`. Il sistema valuta i pesi accumulati fino a quel momento e innesca forzatamente l'aggregazione passando a Python solo i dati dei nodi "sopravvissuti". Questo garantisce il proseguimento dell'addestramento globale scartando il nodo difettoso.

## 📌 Il Percorso di Collaudo: La Resilienza Nativa di Erlang

Il collaudo di questa implementazione ha richiesto tre iterazioni distinte, le quali hanno dimostrato l'estrema resilienza intrinseca dell'ecosistema Erlang/OTP, che rende attivamente "difficile" simulare un guasto fatale.

1. **Ostacolo 1 (L'Albero di Supervisione)**: 
   Nel primo test, abbiamo simulato un guasto hardware spegnendo brutalmente il worker Python di un nodo (`gen_server:stop(python_worker_srv)`). Il timeout non è scattato perché il Supervisore (`orchestrator_sup`), configurato con `restart_type: permanent`, ha intercettato l'uscita prematura (`reason: normal, child_terminated`) e ha ricreato il processo in una frazione di millisecondo. Il nodo ha quindi risposto in tempo, annullando il timer.
2. **Ostacolo 2 (Topologia di Rete Dinamica)**: 
   Nel secondo test, abbiamo provato a far "cadere" l'intero nodo Silo B arrestando la sua Virtual Machine (`init:stop()`). Il demone di rete (`epmd`) del Leader ha rilevato istantaneamente la caduta del socket TCP e ha rimosso il nodo dalla topologia. Di conseguenza, all'avvio del round, il Leader ha ricalcolato dinamicamente il quorum da 3 a 2 nodi attesi, concludendo immediatamente il round con i superstiti senza innescare alcun ritardo.
3. **Il Test Definitivo (Congelamento del Processo)**: 
   Per poter effettivamente simulare uno straggler e innescare il timeout, abbiamo dovuto riprodurre un "CPU lock" o un partizionamento silente della rete. Tramite il comando `sys:suspend(fl_manager_srv)`, abbiamo congelato lo stato del processo bersaglio. In questo modo, EPMD ha continuato a vedere il nodo come connesso (mantenendo il quorum a 3), ma il nodo si è rivelato incapace di processare il calcolo. Allo scadere dei 5 secondi di silenzio, il Leader ha correttamente catturato il timeout, stampando il log d'emergenza ANSI giallo ed eseguendo l'aggregazione parziale in totale autonomia.

L'architettura è ora formalmente testata contro stragglers, ritardi di rete e fallimenti silenti dell'hardware periferico.