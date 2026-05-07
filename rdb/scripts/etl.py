import psycopg2
import psycopg2.extras

from rdflib import Graph, URIRef, Namespace
from rdflib.namespace import RDF, RDFS



def load_query(sql_path):
    with open(sql_path, 'r') as f:
        q = f.read()
    return q

def query(conn, sql):
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cursor.execute(sql)
    rows = cursor.fetchall()
    return rows

def main():
    conn = psycopg2.connect(
        host="localhost",
        port=5432,
        dbname="industry_safety",
        user="joono",
        password="joono"
    )

    g = Graph()
    IS = Namespace("http://infiniq.co.kr/2026/industry_safety#")
    
    q = load_query('rdb/scripts/etl.sql')
    rows = query(conn, q)
    
    role_map = {
        "상시근로자": IS.상시근로자,
        "안전관리자": IS.안전관리자,
    }
    object_prop_map = {
        "상시근로자": IS.고용하다,
        "안전관리자": IS.선임하다,
    }
    for row in rows:
        factory_iri = IS[f"FACTORY_RDB-DB-1_{row['factory_id']}"]
        person_iri = IS[f"PERSON_RDB-DB-1_{row['id']}"]
        
        g.add((factory_iri, RDF.type, IS.사업장))
        g.add((person_iri, RDF.type, role_map[row['role_name']]))
        g.add((factory_iri, object_prop_map[row['role_name']], person_iri))
    
    
    g.serialize("ontology/abox/r1.abox.ttl")

if __name__ == "__main__":
    main()