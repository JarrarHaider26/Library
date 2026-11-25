from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from database.database import Base, engine
from ratelimiting.rate_limiting import limiter
from routes import auth_routes, book_routes, user_routes

app = FastAPI(title="Library API")
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
Instrumentator().instrument(app).expose(app, endpoint="/metrics")


@app.on_event("startup")
def startup_event():
    Base.metadata.create_all(bind=engine)


app.add_middleware(CORSMiddleware, allow_methods=["*"], allow_headers=["*"], allow_origins=["*"])

app.include_router(user_routes.router)
app.include_router(book_routes.router)
app.include_router(auth_routes.router)


@app.get("/")
def home():
    return {"Message": "API Running"}


@app.get("/health")
def health():
    return {"status": "ok"}
