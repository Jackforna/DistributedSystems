import sys

def main():
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break # EOF ricevuto
            
            # Logica elaborazione (qui facciamo solo un echo)
            response = f"Echo: {line.strip()}"
            
            sys.stdout.write(response + "\n")
            sys.stdout.flush()
        except KeyboardInterrupt:
            break
        except Exception as e:
            sys.stderr.write(f"Error: {e}\n")

if __name__ == "__main__":
    main()
