import requests
import json
import time
from os import environ

def main():
  if environ.get("GITHUB_ENV", None):
    Data = {
      "username": "EPD Hub Update",
      "content": environ.get("PingTag"),
      "embeds": [
        {
          "title": "EPD Hub Updated",
          "url": "https://github.com/PBeta-R34/EPD-HUB",
          "description": "Update Date " + time.strftime("%a, %d %b %Y %H:%M:%S", time.gmtime()),
          "color": 0x0DACE0,
          "fields": [
            {
              "name": "Commit Number:",
              "value": str(environ.get("GITHUB_RUN_NUMBER")),
            },
            {
              "name": "Commit Reason:",
              "value": environ.get("CommitMessage"),
            },
          ],

        }
      ]
    }
    Result = requests.post(environ.get("DiscordWebhookToken"), headers={"Content-Type": "application/json"}, data=json.dumps(Data))

main()