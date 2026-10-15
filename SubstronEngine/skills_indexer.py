#!/usr/bin/env python3
"""
Substron Skills Indexer & Fast Search Engine
Creates a lightweight, portable SQLite FTS5 database from the 2,600+ skills catalog.
Enables sub-millisecond skill discovery for the Substron Autonomous Engine.
"""

import json
import os
import sqlite3
import sys
import time

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKILLS_RAW_DIR = os.path.join(BASE_DIR, "SubstronSkills", "raw")
INDEX_JSON_PATH = os.path.join(SKILLS_RAW_DIR, "skills_index.json")
DB_PATH = os.path.join(BASE_DIR, "SubstronSkills", "substron_skills.db")

def build_index():
    if not os.path.exists(INDEX_JSON_PATH):
        print(f"Error: {INDEX_JSON_PATH} not found.")
        return False

    print(f"[*] Reading skills catalog: {INDEX_JSON_PATH}")
    with open(INDEX_JSON_PATH, "r", encoding="utf-8") as f:
        skills_data = json.load(f)

    print(f"[*] Loaded {len(skills_data)} skills from catalog.")
    
    # Remove old DB if exists
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Create storage table with portable relative paths
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS skills (
        id TEXT PRIMARY KEY,
        name TEXT,
        category TEXT,
        description TEXT,
        tags TEXT,
        rel_path TEXT,
        risk TEXT
    );
    """)

    # Create FTS5 virtual table for lightning search
    cursor.execute("""
    CREATE VIRTUAL TABLE IF NOT EXISTS skills_fts USING fts5(
        id,
        name,
        category,
        description,
        tags,
        prefix='2,3'
    );
    """)

    skills_batch = []
    fts_batch = []

    for item in skills_data:
        s_id = item.get("id", "")
        name = item.get("name", s_id)
        cat = item.get("category", "general")
        desc = item.get("description", "")
        tags_list = item.get("tags", [])
        tags_str = " ".join(tags_list) if isinstance(tags_list, list) else str(tags_list)
        rel_path = item.get("path", f"skills/{s_id}")
        risk = item.get("risk", "safe")

        skills_batch.append((s_id, name, cat, desc, tags_str, rel_path, risk))
        fts_batch.append((s_id, name, cat, desc, tags_str))

    cursor.executemany("INSERT INTO skills VALUES (?, ?, ?, ?, ?, ?, ?)", skills_batch)
    cursor.executemany("INSERT INTO skills_fts VALUES (?, ?, ?, ?, ?)", fts_batch)

    conn.commit()
    conn.close()

    db_size = os.path.getsize(DB_PATH) / (1024 * 1024)
    print(f"[+] Portable index built successfully! Saved to: {DB_PATH}")
    print(f"[+] Total indexed skills: {len(skills_batch)} (DB Size: {db_size:.2f} MB)")
    return True

def search_skills(query: str, limit: int = 5):
    """
    Search skills using SQLite FTS5 BM25 relevance ranking.
    Dynamically computes the full path relative to the current installation root.
    """
    if not os.path.exists(DB_PATH):
        print("[!] DB not found. Building index first...")
        build_index()

    t0 = time.perf_counter()
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Clean query for FTS syntax
    clean_terms = [f'"{w}"' for w in query.split() if w.isalnum()]
    if not clean_terms:
        clean_terms = [f'"{query}"']
    fts_query = " OR ".join(clean_terms)

    sql = """
    SELECT s.id, s.name, s.category, s.description, s.tags, s.rel_path, bm25(skills_fts) as rank
    FROM skills_fts f
    JOIN skills s ON f.id = s.id
    WHERE skills_fts MATCH ?
    ORDER BY rank
    LIMIT ?;
    """

    cursor.execute(sql, (fts_query, limit))
    rows = cursor.fetchall()
    t1 = time.perf_counter()
    latency_ms = (t1 - t0) * 1000

    results = []
    for r in rows:
        rel_path = r[5]
        computed_full_path = os.path.join(SKILLS_RAW_DIR, rel_path, "SKILL.md")
        results.append({
            "id": r[0],
            "name": r[1],
            "category": r[2],
            "description": r[3],
            "tags": r[4],
            "rel_path": rel_path,
            "full_path": computed_full_path,
            "score": round(r[6], 4),
            "file_exists": os.path.exists(computed_full_path)
        })

    conn.close()
    return results, latency_ms

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "build":
        build_index()
    elif len(sys.argv) > 1 and sys.argv[1] == "search":
        q = " ".join(sys.argv[2:]) if len(sys.argv) > 2 else "docker"
        res, lat = search_skills(q)
        print(f"\n--- Search results for '{q}' in {lat:.2f}ms ---")
        for i, item in enumerate(res, 1):
            print(f"[{i}] {item['name']} ({item['category']}) - Score: {item['score']}")
            print(f"    Path: {item['full_path']} (Exists: {item['file_exists']})")
            print(f"    Desc: {item['description'][:100]}...\n")
    else:
        build_index()
        sample_q = "fastapi jwt authentication"
        res, lat = search_skills(sample_q)
        print(f"\n--- Benchmark test: '{sample_q}' in {lat:.2f}ms ---")
        for i, item in enumerate(res, 1):
            print(f"[{i}] {item['name']} ({item['category']}) - {item['description'][:90]}...")
