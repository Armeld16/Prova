from dataclasses import dataclass

@dataclass
class State:
    abbreviation: str
    name: str
    Lat: float
    Lng: float

    def __hash__(self): return hash(self.abbreviation)
    def __eq__(self, other): return self.abbreviation == other.abbreviation
    def __str__(self): return self.name

from database.DB_connect import DBConnect
from model.state import State

class DAO():

    @staticmethod
    def getMinMaxLatLng():
        conn = DBConnect.get_connection()
        cursor = conn.cursor(dictionary=True)
        query = """SELECT MIN(Lat) as minLat, MAX(Lat) as maxLat,
                          MIN(Lng) as minLng, MAX(Lng) as maxLng
                   FROM state"""
        cursor.execute(query)
        row = cursor.fetchone()
        cursor.close(); conn.close()
        return row["minLat"], row["maxLat"], row["minLng"], row["maxLng"]

    @staticmethod
    def getShapes():
        conn = DBConnect.get_connection()
        cursor = conn.cursor(dictionary=True)
        query = """SELECT DISTINCT shape FROM sighting
                   WHERE shape IS NOT NULL AND shape <> ''
                   ORDER BY shape DESC"""
        cursor.execute(query)
        res = [row["shape"] for row in cursor]
        cursor.close(); conn.close()
        return res

    @staticmethod
    def getAllStates():
        conn = DBConnect.get_connection()
        cursor = conn.cursor(dictionary=True)
        query = "SELECT * FROM state"
        cursor.execute(query)
        res = [State(**row) for row in cursor]
        cursor.close(); conn.close()
        return res

    @staticmethod
    def getNodiAttivi(lat, lng, shape):
        conn = DBConnect.get_connection()
        cursor = conn.cursor(dictionary=True)
        query = """SELECT s.state AS abbr, SUM(s.duration) AS peso
                   FROM sighting s, state st
                   WHERE s.state = st.abbreviation
                   AND st.Lat > %s
                   AND st.Lng > %s
                   AND s.shape = %s
                   GROUP BY s.state"""
        cursor.execute(query, (lat, lng, shape))
        res = [(row["abbr"], row["peso"]) for row in cursor]
        cursor.close(); conn.close()
        return res

    @staticmethod
    def getConfini():
        conn = DBConnect.get_connection()
        cursor = conn.cursor(dictionary=True)
        query = "SELECT state, neighbor FROM neighbors"
        cursor.execute(query)
        res = [(row["state"], row["neighbor"]) for row in cursor]
        cursor.close(); conn.close()
        return res

import networkx as nx
from database.DAO import DAO

class Model:
    def __init__(self):
        self._graph = nx.Graph()
        self._idMap = {}
        self._pesoMap = {}

    def buildGraph(self, lat, lng, shape):
        self._graph.clear()
        self._idMap.clear()
        self._pesoMap.clear()
        for s in DAO.getAllStates():
            self._idMap[s.abbreviation] = s
        for abbr, peso in DAO.getNodiAttivi(lat, lng, shape):
            self._pesoMap[abbr] = peso
        for abbr in self._pesoMap:
            self._graph.add_node(self._idMap[abbr])
        for s1, s2 in DAO.getConfini():
            if s1 in self._pesoMap and s2 in self._pesoMap:
                peso = self._pesoMap[s1] + self._pesoMap[s2]
                self._graph.add_edge(self._idMap[s1], self._idMap[s2], weight=peso)

    def graphDetails(self):
        return len(self._graph.nodes), len(self._graph.edges)

    def getTop5Nodi(self):
        return sorted([(n, self._graph.degree(n)) for n in self._graph.nodes()],
                      key=lambda x: x[1], reverse=True)[:5]

    def getTop5Archi(self):
        return sorted(self._graph.edges(data=True),
                      key=lambda x: x[2]["weight"], reverse=True)[:5]

    def getMinMaxLatLng(self):
        return DAO.getMinMaxLatLng()

    def getShapes(self):
        return DAO.getShapes()

import flet as ft

class Controller:
    def __init__(self, view, model):
        self._view = view
        self._model = model
        self._minLat = self._maxLat = None
        self._minLng = self._maxLng = None

    def handleCreaGrafo(self, e):
        # validazione lat
        try:
            lat = float(self._view._txtLat.value)
        except (ValueError, TypeError):
            self._view.txt_result.controls.clear()
            self._view.txt_result.controls.append(ft.Text("Inserire latitudine numerica", color="red"))
            self._view.update_page(); return
        if not (self._minLat <= lat <= self._maxLat):
            self._view.txt_result.controls.clear()
            self._view.txt_result.controls.append(
                ft.Text(f"La latitudine deve essere tra {self._minLat} e {self._maxLat}", color="red"))
            self._view.update_page(); return

        # validazione lng
        try:
            lng = float(self._view._txtLng.value)
        except (ValueError, TypeError):
            self._view.txt_result.controls.clear()
            self._view.txt_result.controls.append(ft.Text("Inserire longitudine numerica", color="red"))
            self._view.update_page(); return
        if not (self._minLng <= lng <= self._maxLng):
            self._view.txt_result.controls.clear()
            self._view.txt_result.controls.append(
                ft.Text(f"La longitudine deve essere tra {self._minLng} e {self._maxLng}", color="red"))
            self._view.update_page(); return

        # validazione shape
        shape = self._view._ddShape.value
        if shape is None:
            self._view.txt_result.controls.clear()
            self._view.txt_result.controls.append(ft.Text("Selezionare una shape", color="red"))
            self._view.update_page(); return

        self._model.buildGraph(lat, lng, shape)
        nodi, archi = self._model.graphDetails()
        self._view.txt_result.controls.clear()
        self._view.txt_result.controls.append(ft.Text(f"Numero di vertici: {nodi}"))
        self._view.txt_result.controls.append(ft.Text(f"Numero di archi: {archi}"))

        top5n = self._model.getTop5Nodi()
        self._view.txt_result.controls.append(ft.Text("I 5 nodi di grado maggiore sono:"))
        for nodo, grado in top5n:
            self._view.txt_result.controls.append(ft.Text(f"{nodo} -> degree: {grado}"))

        top5a = self._model.getTop5Archi()
        self._view.txt_result.controls.append(ft.Text("I 5 archi di peso maggiore sono:"))
        for a in top5a:
            self._view.txt_result.controls.append(
                ft.Text(f"{a[0]}<->{a[1]} | peso ={a[2]['weight']:.0f}"))
        self._view.update_page()

    def fillInterface(self):
        self._minLat, self._maxLat, self._minLng, self._maxLng = self._model.getMinMaxLatLng()
        shapes = self._model.getShapes()
        for s in shapes:
            self._view._ddShape.options.append(ft.dropdown.Option(s))
        self._view.update_page()
