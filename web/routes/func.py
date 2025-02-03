from flask import Blueprint, render_template, session, redirect, url_for, request
from datetime import datetime, timezone, timedelta
from boto3.dynamodb.conditions import Key
import boto3

func = Blueprint("func", __name__, url_prefix="/func")

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('cloud-game-engine')

@func.before_request
def before_request():
    if "username" not in session:
        return redirect(url_for("user.login"))

@func.get("/endpoint")
def endpoint():
    response = table.query(
        KeyConditionExpression=Key("PK").eq(f"USER#{session["username"]}") & Key("SK").begins_with(f"ENDPOINT#{session["eventId"]}#"),
        ScanIndexForward=False,
        Limit=1
    )

    items = response.get("Items", [])
    endpoint = items[0]["Endpoint"] if items else None
    
    return render_template("endpoint.html", endpoint=endpoint)

@func.post("/endpoint")
def process_endpoint():
    endpoint = request.form.get("endpoint")
    KST = timezone(timedelta(hours=9))
    timestamp = datetime.now(KST).isoformat()

    username = session["username"]
    eventId = session["eventId"]

    table.put_item(
        Item={
            "PK": f"USER#{username}",
            "SK": f"ENDPOINT#{eventId}#{timestamp}",
            "Endpoint": endpoint,
            "Timestamp": timestamp
        }
    )

    ssm = boto3.client('ssm')
    ssm.put_parameter(
        Name=f"/{eventId}/{username}",
        Value=endpoint,
        Type="String",
        Overwrite=True
    )

    return redirect(url_for("func.endpoint"))

@func.route("/history")
def history():
    response = table.query(
        KeyConditionExpression=Key("PK").eq(f"USER#{session["username"]}") & Key("SK").begins_with(f"ENDPOINT#{session["eventId"]}#"),
        ScanIndexForward=False
    )

    items = response.get("Items", [])

    return render_template("history.html", items=enumerate(items))