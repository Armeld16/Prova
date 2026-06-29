@staticmethod
def getAllArtists():
    conn = DBConnect.get_connection()
    cursor = conn.cursor(dictionary=True)
    query = """
        SELECT DISTINCT a.ArtistId, a.Name
        FROM Artist a, Album al, Track t, PlaylistTrack pt
        WHERE a.ArtistId = al.ArtistId
        AND al.AlbumId = t.AlbumId
        AND t.TrackId = pt.TrackId
    """
    cursor.execute(query)
    res = [Artist(**row) for row in cursor]
    cursor.close(); conn.close()
    return res
