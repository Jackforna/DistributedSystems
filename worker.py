import sys

def main():
    # Loop infinito in ascolto sull'Input standard
    for line in sys.stdin:
        line = line.strip()
        if line.lower() == "quit":
            break
        
        try:
            # Simuliamo un calcolo pesante (es. moltiplicazione di uno spazio latente)
            number = float(line)
            result = number * 2.0
            
            # Scriviamo il risultato sull'Output standard per rimandarlo a Erlang
            sys.stdout.write(f"RISULTATO_PYTHON: {result}\n")
            
            # CRITICO: Il flush forza l'invio immediato del buffer a Erlang
            sys.stdout.flush() 
        except ValueError:
            sys.stdout.write("ERRORE: Payload non valido\n")
            sys.stdout.flush()

if __name__ == "__main__":
    main()