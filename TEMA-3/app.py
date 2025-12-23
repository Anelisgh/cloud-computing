import os
import logging
from flask import Flask, render_template, request, redirect, url_for, jsonify
import pyodbc
from opencensus.ext.azure.log_exporter import AzureLogHandler
from opencensus.ext.azure import metrics_exporter
from opencensus.ext.flask.flask_middleware import FlaskMiddleware

app = Flask(__name__)

# Application Insights Configuration
APPINSIGHTS_CONNECTION_STRING = os.environ.get('APPLICATIONINSIGHTS_CONNECTION_STRING')

# Setup logging with Application Insights
if APPINSIGHTS_CONNECTION_STRING:
    logger = logging.getLogger(__name__)
    logger.addHandler(AzureLogHandler(connection_string=APPINSIGHTS_CONNECTION_STRING))
    logger.setLevel(logging.INFO)
    
    # Setup Flask middleware for automatic request tracking
    middleware = FlaskMiddleware(
        app,
        exporter=metrics_exporter.new_metrics_exporter(
            connection_string=APPINSIGHTS_CONNECTION_STRING
        )
    )
    print(f"Application Insights configured: {APPINSIGHTS_CONNECTION_STRING[:50]}...")
else:
    logger = logging.getLogger(__name__)
    logger.setLevel(logging.INFO)
    print("WARNING: Application Insights not configured")

# Database connection
CONNECTION_STRING = os.environ.get('SQL_CONNECTION_STR')

def get_db_connection():
    if not CONNECTION_STRING:
        raise ValueError("Lipseste variabila de mediu SQL_CONNECTION_STR")
    return pyodbc.connect(CONNECTION_STRING)

def init_db():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Items' AND xtype='U')
            CREATE TABLE Items (
                ID INT IDENTITY(1,1) PRIMARY KEY,
                Content NVARCHAR(255) NOT NULL UNIQUE,
                CreatedAt DATETIME DEFAULT GETDATE()
            )
        """)
        conn.commit()
        cursor.close()
        conn.close()
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Database initialization error: {e}")

if CONNECTION_STRING:
    init_db()

# Health endpoint
@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint pentru monitoring"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        conn.close()
        
        logger.info("Health check passed")
        return jsonify({
            'status': 'healthy',
            'database': 'connected'
        }), 200
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 503

@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        item_content = request.form.get('content', '').strip()
        
        if not item_content:
            logger.warning("Attempted to add empty item")
            return render_template('index.html', 
                                 items=get_all_items(), 
                                 error="Itemul nu poate fi gol!",
                                 appinsights_connection_string=APPINSIGHTS_CONNECTION_STRING), 400
        
        if len(item_content) < 3:
            logger.warning(f"Attempted to add item too short: {item_content}")
            return render_template('index.html', 
                                 items=get_all_items(), 
                                 error="Itemul trebuie sa aiba cel putin 3 caractere!",
                                 appinsights_connection_string=APPINSIGHTS_CONNECTION_STRING), 400
        
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            cursor.execute("INSERT INTO Items (Content) VALUES (?)", item_content)
            conn.commit()
            cursor.close()
            conn.close()
            
            logger.info(f"Item successfully added: {item_content}")
            
        except pyodbc.IntegrityError as e:
            logger.error(f"Duplicate item attempted: {item_content}")
            return render_template('index.html', 
                                 items=get_all_items(), 
                                 error=f"Itemul '{item_content}' exista deja!",
                                 appinsights_connection_string=APPINSIGHTS_CONNECTION_STRING), 409
        except Exception as e:
            logger.error(f"Error adding item: {e}")
            return render_template('index.html', 
                                 items=get_all_items(), 
                                 error="Eroare la salvare!",
                                 appinsights_connection_string=APPINSIGHTS_CONNECTION_STRING), 500
        
        return redirect(url_for('index'))

    items = get_all_items()
    return render_template('index.html', 
                         items=items, 
                         error=None,
                         appinsights_connection_string=APPINSIGHTS_CONNECTION_STRING)

def get_all_items():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT Content FROM Items ORDER BY ID DESC")
        items = [row[0] for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        return items
    except Exception as e:
        logger.error(f"Error fetching items: {e}")
        return []

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8000))
    app.run(host='0.0.0.0', port=port, debug=False)