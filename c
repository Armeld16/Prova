=== Constructor.py ===

from dataclasses import dataclass, field

@dataclass
class Constructor:
    constructorId: int
    constructorRef: str
    name: str
    nationality: str
    url: str
    results: dict = field(default_factory=dict)

    def __hash__(self): return hash(self.constructorId)
    def __eq__(self, other): return self.constructorId == other.constructorId
    def __str__(self): return self.name


=== DAO.py ===

from database.DB_connect import DBConnect
from model.constructor import Constructor

class DAO():

    @staticmethod
    def getAllYears():
        conn = DBConnect.get_connection()
        cursor = conn.cursor(dictionary=True)
        query = "SELECT DISTINCT year FROM seasons ORDER BY year"
        cursor.execute(query)
        res = [row["year"] for row in cursor]
        cursor.close(); conn.close()
        return res

    @staticmethod
    def getAllConstructors():
        conn = DBConnect.get_connection()
        cursor = conn.cursor(dictionary=True)
        query = "SELECT * FROM constructors"
        cursor.execute(query)
        res = [Constructor(**row) for row in cursor]
        cursor.close(); conn.close()
        return res

    @staticmethod
    def getPiazzamenti(anno1, anno2):
        conn = DBConnect.get_connection()
        cursor = conn.cursor(dictionary=True)
        query = """
            SELECT r.constructorId AS cid, ra.year AS ye,
                   r.driverId AS did, r.position AS pos
            FROM results r, races ra
            WHERE r.raceId = ra.raceId
            AND ra.year BETWEEN %s AND %s
        """
        cursor.execute(query, (anno1, anno2))
        res = [(row["cid"], row["ye"], row["did"], row["pos"]) for row in cursor]
        cursor.close(); conn.close()
        return res


=== Model.py ===

import networkx as nx
from itertools import combinations
from database.DAO import DAO

class Model:
    def __init__(self):
        self._graph = nx.Graph()
        self._idMap = {}

    def buildGraph(self, anno1, anno2):
        self._graph.clear()
        self._idMap.clear()
        nodi = DAO.getAllConstructors()
        for n in nodi:
            self._idMap[n.constructorId] = n
        self._graph.add_nodes_from(nodi)
        for cid, ye, did, pos in DAO.getPiazzamenti(anno1, anno2):
            if ye not in self._idMap[cid].results:
                self._idMap[cid].results[ye] = []
            self._idMap[cid].results[ye].append((did, pos))
        attivi = [n for n in self._graph.nodes() if len(n.results) > 0]
        for a, b in combinations(attivi, 2):
            peso = self.gareCompletate(a) + self.gareCompletate(b)
            self._graph.add_edge(a, b, weight=peso)

    def gareCompletate(self, nodo):
        count = 0
        for lista in nodo.results.values():
            for did, pos in lista:
                if pos is not None:
                    count += 1
        return count

    def graphDetails(self):
        return len(self._graph.nodes), len(self._graph.edges)

    def getDettagliComponente(self):
        largest = max(nx.connected_components(self._graph), key=len)
        ordinati = sorted(largest,
                          key=lambda v: max(d["weight"]
                                            for _, _, d in self._graph.edges(v, data=True)),
                          reverse=True)
        return [(v, max(d["weight"] for _, _, d in self._graph.edges(v, data=True)))
                for v in ordinati]

    def getYear(self):
        return DAO.getAllYears()


=== Controller.py ===

import flet as ft

class Controller:
    def __init__(self, view, model):
        self._view = view
        self._model = model

    def handleCreaGrafo(self, e):
        anno1 = self._view._ddAnno1.value
        anno2 = self._view._ddAnno2.value
        if anno1 is None:
            self._view.txt_result.controls.clear()
            self._view.txt_result.controls.append(ft.Text("Selezionare anno 1", color="red"))
            self._view.update_page(); return
        if anno2 is None:
            self._view.txt_result.controls.clear()
            self._view.txt_result.controls.append(ft.Text("Selezionare anno 2", color="red"))
            self._view.update_page(); return
        if anno1 > anno2:
            self._view.txt_result.controls.clear()
            self._view.txt_result.controls.append(ft.Text("Anno 1 deve essere <= Anno 2", color="red"))
            self._view.update_page(); return
        self._model.buildGraph(anno1, anno2)
        nodi, archi = self._model.graphDetails()
        self._view.txt_result.controls.clear()
        self._view.txt_result.controls.append(ft.Text("Grafo correttamente creato."))
        self._view.txt_result.controls.append(ft.Text(f"Il grafo contiene {nodi} nodi e {archi} archi."))
        self._view.update_page()

    def handleStampaDettagli(self, e):
        if len(self._model._graph.nodes) == 0:
            self._view.txt_result.controls.append(ft.Text("Creare prima il grafo", color="red"))
            self._view.update_page(); return
        lista = self._model.getDettagliComponente()
        self._view.txt_result.controls.append(ft.Text("Stampa dettagli:"))
        for nodo, peso_max in lista:
            self._view.txt_result.controls.append(
                ft.Text(f"{nodo} -- {peso_max}"))
        self._view.update_page()

    def handleCercaTeam(self, e):
        pass

    def fillDD(self):
        years = self._model.getYear()
        for y in years:
            self._view._ddAnno1.options.append(ft.dropdown.Option(y))
            self._view._ddAnno2.options.append(ft.dropdown.Option(y))
        self._view.update_page()
