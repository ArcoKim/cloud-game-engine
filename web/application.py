from flask import Flask, session, redirect, url_for, jsonify
from routes.user import user
from routes.func import func

application = Flask(__name__)
application.secret_key = "cloud-game-engine"
application.register_blueprint(user)
application.register_blueprint(func)

@application.route("/")
def index():
    if "username" in session:
        return redirect(url_for("func.endpoint"))
    else:
        return redirect(url_for("user.login"))

@application.route("/health")
def health():
    return jsonify({"status": "ok"})

if __name__ == "__main__":
    application.debug = True
    application.run()