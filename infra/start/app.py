import boto3
import json
import os
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("cloud-game-engine")
ssm = boto3.client("ssm")
ecs = boto3.client("ecs")

def handler(event, context):
    eventId = event["eventId"]
    time = event["time"]
    response = table.query(
        KeyConditionExpression=Key("PK").eq(f"EVENT#{eventId}") & Key("SK").begins_with("USER#")
    )

    for item in response["Items"]:
        username = item["SK"].split("#")[-1]

        try:
            response = ssm.get_parameter(Name=f"/{eventId}/{username}")
            endpoint = response["Parameter"]["Value"]
        except ClientError:
            continue

        with open("task_definition.json", "r") as file:
            task_definition = json.load(file)
        
        task_definition["containerDefinitions"][0]["image"] = os.getenv("LOCUST_IMAGE")
        task_definition["containerDefinitions"][0]["command"][1] = username
        task_definition["containerDefinitions"][0]["command"][4] = time
        task_definition["containerDefinitions"][0]["command"][10] = endpoint
        task_definition["containerDefinitions"][0]["environment"][0]["value"] = eventId
        task_definition["containerDefinitions"][0]["environment"][1]["value"] = username
        task_definition["containerDefinitions"][0]["environment"][2]["value"] = item["AccessKey"]
        task_definition["containerDefinitions"][0]["environment"][3]["value"] = item["SecretAccessKey"]
        task_definition["taskRoleArn"] = os.getenv("TASK_ROLE_ARN")
        task_definition["executionRoleArn"] = os.getenv("EXECUTION_ROLE_ARN")

        response = ecs.register_task_definition(**task_definition)
        task_definition_arn = response["taskDefinition"]["taskDefinitionArn"]

        ecs.run_task(
            cluster="load-test",
            launchType="FARGATE",
            taskDefinition=task_definition_arn,
            count=1,
            networkConfiguration={
                "awsvpcConfiguration": {
                    "subnets": [os.getenv("TASK_SUBNET")],
                    "securityGroups": [os.getenv("TASK_SECURITY_GROUP")],
                    "assignPublicIp": "ENABLED"
                }
            }
        )