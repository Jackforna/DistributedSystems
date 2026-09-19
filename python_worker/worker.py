import sys
import json
import random

def main():
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break # EOF ricevuto
            line = line.strip()
            
            if line.startswith("TRAIN"):
                # Simula l'allenamento restituendo un array con pesi fittizi +/- random
                w1 = 0.8 + random.uniform(-0.1, 0.1)
                w2 = 1.1 + random.uniform(-0.1, 0.1)
                w3 = 0.9 + random.uniform(-0.1, 0.1)
                response = f"TRAIN_RES|{json.dumps([w1, w2, w3])}"
                sys.stdout.write(response + "\n")
                sys.stdout.flush()
                
            elif line.startswith("AGGREGATE|"):
                payload = line.split("|", 1)[1]
                # payload sarà una lista di liste in JSON: [[w1, w2, w3], ...]
                weights_list = json.loads(payload)
                if not weights_list:
                    res = []
                else:
                    num_nodes = len(weights_list)
                    num_weights = len(weights_list[0])
                    res = [0.0] * num_weights
                    for w in weights_list:
                        for i in range(num_weights):
                            res[i] += w[i]
                    res = [round(x / num_nodes, 4) for x in res]
                
                response = f"AGGREGATE_RES|{json.dumps(res)}"
                sys.stdout.write(response + "\n")
                sys.stdout.flush()
                
            else:
                response = f"ECHO|{line}"
                sys.stdout.write(response + "\n")
                sys.stdout.flush()
                
        except KeyboardInterrupt:
            break
        except Exception as e:
            sys.stderr.write(f"Error: {e}\n")

if __name__ == "__main__":
    main()