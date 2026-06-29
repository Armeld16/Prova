def getTop10Archi(self):
    edges = []
    for u, v, d in self._graph.edges(data=True):
        n1 = u.Name if u.Name else ""
        n2 = v.Name if v.Name else ""
        if n1 > n2:
            u, v = v, u   # swap: il più piccolo alfabeticamente va a sinistra
        edges.append((u, v, d))
    return sorted(edges,
                  key=lambda x: (-x[2]["weight"],
                                 x[0].Name if x[0].Name else "",
                                 x[1].Name if x[1].Name else ""))[:10]

for a in top10:
    self._view.txt_result.controls.append(
        ft.Text(f"{a[0]} & {a[1]} (peso: {a[2]['weight']})"))
