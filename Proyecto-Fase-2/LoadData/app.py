import pandas as pd
import psycopg2
from psycopg2 import sql
import hashlib
import os
from datetime import datetime
from imdb_loader import IMDBDataLoader

if __name__ == "__main__":
    db_config = {
        'host': 'localhost',
        'port': 5432,
        'database': 'bases2-db',
        'user': 'root',
        'password': 'root',
    }
    
    tsv_path = r"C:\Users\PC\Desktop\bases2p1"
    
    loader = IMDBDataLoader(db_config, tsv_path)
    loader.load_all_data()