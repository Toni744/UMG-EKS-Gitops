import time
from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI(title="Automate All The Things API")


@app.get("/")
def root():
    return JSONResponse(content={
        "message": "Automate all the things!",
        "timestamp": int(time.time())
    })


@app.get("/health")
def health():
    return {"status": "ok"}