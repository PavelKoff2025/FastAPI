from contextlib import asynccontextmanager
from collections.abc import AsyncIterator

from fastapi import FastAPI

from app.config import get_settings
from app.routers import health


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    yield


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        debug=settings.debug,
        lifespan=lifespan,
    )

    app.include_router(health.router)

    @app.get("/")
    async def root() -> dict[str, str]:
        return {"message": f"Welcome to {settings.app_name}"}

    return app


app = create_app()
