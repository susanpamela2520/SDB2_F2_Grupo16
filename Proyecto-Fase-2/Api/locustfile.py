from locust import HttpUser, task, between
import random

GENEROS = [
    "Rock", "Pop", "Salsa", "Cumbia", "Reggaeton",
    "Jazz", "Blues", "Metal", "Punk", "Clásica",
    "Bachata", "Merengue", "Hip-Hop", "Electrónica", "Indie"
]

class InsercionGeneros(HttpUser):
    # Ajusta pacing para tu prueba
    wait_time = between(3, 5)

    @task
    def insertar_genero(self):
        genero = random.choice(GENEROS) + f" {random.randint(1, 10_000)}"
        self.client.post("/generos", json={"genero": genero})
