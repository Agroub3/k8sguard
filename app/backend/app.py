import sqlite3
from flask import Flask, request, jsonify

app = Flask(__name__)
DB = "meditrack.db"

# --- Faille #3 : secret codé en dur (FICTIF, pour la démo uniquement) ---
API_KEY = "sk_live_FAKE_1234567890abcdef"  # jamais un vrai secret, exprès visible pour Gitleaks


def get_db():
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db()
    conn.execute("""CREATE TABLE IF NOT EXISTS patients (
        id INTEGER PRIMARY KEY, nom TEXT, diagnostic TEXT, owner_role TEXT)""")
    conn.execute("DELETE FROM patients")
    conn.executemany(
        "INSERT INTO patients (id, nom, diagnostic, owner_role) VALUES (?, ?, ?, ?)",
        [(1, "Patient Fictif A", "Diagnostic confidentiel A", "medecin"),
         (2, "Patient Fictif B", "Diagnostic confidentiel B", "medecin")],
    )
    conn.commit()
    conn.close()


@app.route("/health")
def health():
    return jsonify(status="ok")


# --- Faille #1 : injection SQL (A03) ---
# Volontairement construite par concaténation de chaîne, sans requête paramétrée.
@app.route("/api/recherche")
def recherche():
    nom = request.args.get("nom", "")
    conn = get_db()
    query = f"SELECT * FROM patients WHERE nom LIKE '%{nom}%'"   # <-- faille ici
    rows = conn.execute(query).fetchall()
    conn.close()
    return jsonify([dict(r) for r in rows])


# --- Faille #2 : IDOR, contrôle d'accès cassé (A01) ---
# N'importe quel rôle peut lire n'importe quel dossier, sans vérifier owner_role.
@app.route("/api/dossier/<int:patient_id>")
def dossier(patient_id):
    role = request.headers.get("X-Role", "visiteur")   # censé être vérifié, mais ne l'est pas
    conn = get_db()
    row = conn.execute("SELECT * FROM patients WHERE id = ?", (patient_id,)).fetchone()
    conn.close()
    if row is None:
        return jsonify(error="not found"), 404
    return jsonify(dict(row))   # <-- aucune vérification de `role` ici : faille


if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000)
