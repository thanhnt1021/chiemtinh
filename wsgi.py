from app import create_app
from project_conf import APP_PORT

app = create_app()

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=APP_PORT, debug=False, threaded=True)


