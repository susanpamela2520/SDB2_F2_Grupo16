# Convertir de TSV a CSV

## Requisitos

- Python 3.x
- pandas (`pip install pandas`)

## Cómo usar

### Opción 1: Conversión rápida
Simplemente ejecuta el programa con el nombre del archivo TSV:

```bash
python converter.py archivo.tsv
```

**Ejemplo:**
```bash
python converter.py title.ratings.tsv
```

El programa automáticamente creará un archivo CSV con el mismo nombre (cambiando la extensión de `.tsv` a `.csv`).

### Opción 2: Especificar archivo de salida
Si quieres elegir el nombre del archivo de salida:

```bash
python converter.py archivo.tsv archivo_salida.csv
```

### Opción 3: Modo interactivo
Ejecuta el programa sin argumentos para usar el menú interactivo:

```bash
python converter.py
```

## Qué hace el programa

-  Convierte archivos TSV a CSV
-  Muestra el progreso de la conversión
-  Informa cuántas filas y columnas se procesaron
-  Maneja errores automáticamente

## Ejemplo de salida

```
=== Convertidor TSV a CSV ===

Convirtiendo title.ratings.tsv a title.ratings.csv...
 Conversión exitosa! Archivo guardado en: title.ratings.csv
   Filas procesadas: 1604159
   Columnas: 3
```

