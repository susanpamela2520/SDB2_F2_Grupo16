import pandas as pd
import mysql.connector
from mysql.connector import Error
import hashlib
import os
from datetime import datetime
from imdb_loader import IMDBDataLoader

if __name__ == "__main__":
    db_config = {
        'host': 'localhost',
        'database': 'imdb_fase1',
        'user': 'root',
        'password': 'root',
        'charset': 'utf8mb4',
    }
    
    tsv_path = r"C:\Users\PC\Desktop\bases2p1"
    
    loader = IMDBDataLoader(db_config, tsv_path)
    loader.load_all_data()