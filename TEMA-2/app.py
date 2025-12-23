import os
import pyodbc
from flask import Flask, render_template, request, redirect, url_for

app = Flask(__name__)

CONNECTION_STRING = os.environ.get('SQL_CONNECTION_STR')
# obtinem conexiunea la baza de date
def get_db_connection():
    if not CONNECTION_STRING:
        raise ValueError("Lipseste variabila de mediu SQL_CONNECTION_STR")
    return pyodbc.connect(CONNECTION_STRING)
# initializam baza de date
def init_db():
    # cream tabela daca nu exista
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Items' AND xtype='U')
            CREATE TABLE Items (ID INT IDENTITY(1,1) PRIMARY KEY,
            Content NVARCHAR(255) NOT NULL,
            CreatedAt DATETIME DEFAULT GETDATE())
        """)
        conn.commit()
        cursor.close()
        conn.close()
        print("Baza de date a fost creata sau exista deja.")
    except Exception as e:
        print(f"Eroare: {e}")

# initializam DB la pornirea aplicatiei
if CONNECTION_STRING:
    init_db()

@app.route('/', methods=['GET', 'POST'])
def index():
    # preia datele din formular si le insereaza in DB
    if request.method == 'POST':
        item_content = request.form.get('content', '').strip()
        if item_content:
            try:
                conn = get_db_connection()
                cursor = conn.cursor()
                cursor.execute("INSERT INTO Items (Content) VALUES (?)", item_content)
                conn.commit()
                cursor.close()
                conn.close()
            except Exception as e:
                print(f"Eroare: {e}")
        return redirect(url_for('index'))
    # afiseaza elementele din DB
    items = []
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT Content FROM Items ORDER BY ID DESC")
        items = [row[0] for row in cursor.fetchall()]
        cursor.close()
        conn.close()
    except Exception as e:
        items = [f"Eroare: {e}"]
    
    return render_template('index.html', items=items)

# pornim aplicatia
if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8000))
    app.run(host='0.0.0.0', port=port, debug=False)