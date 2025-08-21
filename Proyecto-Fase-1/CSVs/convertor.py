import pandas as pd
import os
import sys

def convert_tsv_to_csv(tsv_file_path, csv_file_path=None):

  try:
    if not os.path.isfile(tsv_file_path):
      print(f"El archivo {tsv_file_path} no existe.")
      return False

    if csv_file_path is None:
      csv_file_path = tsv_file_path.replace('.tsv', '.csv')
      if csv_file_path == tsv_file_path:
        csv_file_path = tsv_file_path + '.csv'

    print(f"Convirtiendo {tsv_file_path} a {csv_file_path}...")

    # Leer el archivo TSV
    df = pd.read_csv(tsv_file_path, sep='\t')
        
    # Guardar como CSV
    df.to_csv(csv_file_path, index=False)
        
    print(f" Conversión exitosa! Archivo guardado en: {csv_file_path}")
    print(f"   Filas procesadas: {len(df)}")
    print(f"   Columnas: {len(df.columns)}")
    
    return True
  except Exception as e:
    print(f" Error al convertir el archivo: {e}")
    return False

def main():
    print("=== Convertidor TSV a CSV ===\n")
    
    if len(sys.argv) > 1:
        # Si se proporciona un archivo como argumento de línea de comandos
        tsv_file = sys.argv[1]
        csv_file = sys.argv[2] if len(sys.argv) > 2 else None
        convert_tsv_to_csv(tsv_file, csv_file)
    else:
        # Si no se proporciona un archivo, iniciar la interfaz interactiva
        while True:
            print("Opciones:")
            print("1. Convertir un archivo TSV a CSV")
            print("2. Salir")
            
            choice = input("\nSelecciona una opción (1-2): ").strip()
            
            if choice == '1':
                tsv_file = input("Ingresa la ruta del archivo TSV: ").strip()
                
                tsv_file = tsv_file.strip('"\'')
                
                csv_file = input("Ingresa la ruta del archivo CSV de salida (presiona Enter para usar automático): ").strip()
                csv_file = csv_file.strip('"\'') if csv_file else None
                
                convert_tsv_to_csv(tsv_file, csv_file)
                print("\n" + "="*50 + "\n")
                
            elif choice == '2':
                print("¡Hasta luego!")
                break
            else:
                print("Opción no válida. Por favor, selecciona 1 o 2.\n")

if __name__ == "__main__":
    main()

