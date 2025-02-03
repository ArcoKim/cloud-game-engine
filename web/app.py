from flask import Flask, render_template, session, redirect, url_for
from routes.user import user
from routes.func import func

app = Flask(__name__)
app.secret_key = "cloud-game-engine"
app.register_blueprint(user)
app.register_blueprint(func)

@app.route("/")
def index():
    if "username" in session:
        return redirect(url_for("func.endpoint"))
    else:
        return redirect(url_for("user.login"))

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80, debug=True)