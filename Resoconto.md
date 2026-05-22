# Resoconto di Sviluppo: Blocco 1 (Node-Level Architecture) (Gabbo)

Questo documento fornisce una guida passo-passo e un resoconto tecnico dettagliato delle operazioni effettuate durante il **Blocco 1** del progetto di *Federated Learning Cross-Silo* applicato ad ambienti sanitari.

L'obiettivo principale di questa fase è stato quello di consolidare l'architettura a livello di singolo nodo ospedaliero (**Node-Level**), garantendo il principio di **Fault Isolation** descritto nel capitolo 3.2 della relazione tecnica, isolando l'ambiente d'inferenza Python dai crash applicativi e strutturando l'orchestrazione Erlang secondo i canoni OTP.

---

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