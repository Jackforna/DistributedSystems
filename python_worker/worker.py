import sys

def main():
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break # EOF ricevuto, Erlang ha chiuso la porta
            
            clean_line = line.strip()
            if clean_line.lower() == "quit":
                break
                
            # Logica PoC: Moltiplicazione tensoriale simulata
            number = float(clean_line)
            result = number * 2.0
            
            # Formattiamo l'output per l'orchestratore Erlang
            sys.stdout.write(f"RISULTATO_PYTHON: {result}\n")
            sys.stdout.flush()
            
        except ValueError:
            # Se Erlang ci manda una stringa invece di un numero
            sys.stdout.write("ERRORE: Payload non valido\n")
            sys.stdout.flush()
        except KeyboardInterrupt:
            break
        except Exception as e:
            sys.stderr.write(f"Error: {e}\n")

if __name__ == "__main__":
    main()