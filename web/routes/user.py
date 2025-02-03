from flask import Blueprint, render_template, session, redirect, url_for, request, flash
from boto3.dynamodb.conditions import Key
import boto3

user = Blueprint("user", __name__, url_prefix="/user")

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('cloud-game-engine')

@user.get("/login")
def login():
    return render_template("login.html")

@user.post("/login")
def process_login():
    form = request.form
    eventId = form.get("eventId")
    username = form.get("username")
    password = form.get("password")

    response = table.query(
        KeyConditionExpression=Key("PK").eq(f"USER#{username}") & Key("SK").eq(f"EVENT#{eventId}")
    )
    items = response["Items"]

    if len(items) == 1 and items[0]["Password"] == password:
        session["username"] = username
        session["eventId"] = eventId
        return redirect(url_for("func.endpoint"))
    
    flash("일치하지 않는 정보입니다.", category="error")
    return redirect(url_for("user.login"))

@user.route("/logout")
def logout():
    session.pop("username", None)
    session.pop("eventId", None)
    return redirect(url_for("user.login"))