import errno
import io
import logging
import os
import sys
import tempfile


# Parse --model-dir early so MODELSCOPE_CACHE is set before funasr is imported.
# funasr/modelscope reads the cache path at import time, so env must be set first.
def _parse_arg_early(flag: str) -> str | None:
    for i, arg in enumerate(sys.argv):
        if arg == flag and i + 1 < len(sys.argv):
            return sys.argv[i + 1]
    return None


_early_model_dir = _parse_arg_early("--model-dir")
_early_hub = (_parse_arg_early("--hub") or "ms").strip().lower()
if _early_hub not in {"ms", "hf"}:
    _early_hub = "ms"
_early_hf_endpoint = (_parse_arg_early("--hf-endpoint") or "").strip()

if _early_model_dir:
    os.makedirs(_early_model_dir, exist_ok=True)
    os.environ["MODELSCOPE_CACHE"] = _early_model_dir
if _early_hf_endpoint:
    os.environ["HF_ENDPOINT"] = _early_hf_endpoint

from contextlib import asynccontextmanager

from fastapi import FastAPI, File, Form, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from funasr import AutoModel


class SafePipeStream(io.TextIOBase):
    """Stream wrapper that swallows EPIPE/BrokenPipeError writes.

    Some ASR dependencies write progress logs to stdout/stderr during inference.
    If the server process is launched in a detached context with closed pipes,
    those writes can raise BrokenPipeError and break request handling.
    """

    def __init__(self, wrapped):
        self._wrapped = wrapped

    def write(self, data):
        try:
            return self._wrapped.write(data)
        except (BrokenPipeError, OSError) as e:
            if isinstance(e, BrokenPipeError) or getattr(e, "errno", None) == errno.EPIPE:
                return 0
            raise

    def flush(self):
        try:
            return self._wrapped.flush()
        except (BrokenPipeError, OSError) as e:
            if isinstance(e, BrokenPipeError) or getattr(e, "errno", None) == errno.EPIPE:
                return None
            raise


# Guard process stdio to avoid EPIPE crashes in detached runs.
sys.stdout = SafePipeStream(sys.stdout)
sys.stderr = SafePipeStream(sys.stderr)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("funasr_server")

# Global model singleton
model = None


def get_model():
    global model
    if model is None:
        logger.info("Model hub=%s", _early_hub)
        if _early_hf_endpoint:
            logger.info("HF endpoint=%s", _early_hf_endpoint)
        model = AutoModel(
            model="paraformer-zh",
            vad_model="fsmn-vad",
            punc_model="ct-punc",
            disable_update=True,
            hub=_early_hub,
        )
    return model


def reset_model():
    """Discard the current model instance so the next get_model() rebuilds it."""
    global model
    logger.warning("Resetting ASR model due to internal error")
    model = None


def _is_pipe_error(exc: Exception) -> bool:
    """Check if an exception is a BrokenPipeError or EPIPE OSError."""
    if isinstance(exc, BrokenPipeError):
        return True
    if isinstance(exc, OSError) and getattr(exc, "errno", None) == errno.EPIPE:
        return True
    return False


@asynccontextmanager
async def lifespan(app):
    logger.info("Loading ASR model...")
    get_model()
    logger.info("Model loaded, server ready")
    yield


app = FastAPI(title="FunASR API Server", version="1.1", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/asr")
async def asr(file: UploadFile = File(...)):
    """Upload an audio file and return ASR result."""
    suffix = os.path.splitext(file.filename or "audio.wav")[1] or ".wav"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(await file.read())
        tmp_path = tmp.name

    try:
        try:
            res = get_model().generate(input=tmp_path, batch_size_s=300)
        except Exception as first_err:
            if not _is_pipe_error(first_err):
                raise
            # Model's internal pipe is broken — rebuild and retry once
            logger.warning("BrokenPipe during generate, retrying with fresh model")
            reset_model()
            res = get_model().generate(input=tmp_path, batch_size_s=300)

        text = "".join(item.get("text", "") for item in res)
        return JSONResponse({"code": 0, "text": text, "result": res})
    except Exception as e:
        logger.exception("ASR failed for %s", tmp_path)
        return JSONResponse({"code": 1, "error": str(e)}, status_code=500)
    finally:
        try:
            os.unlink(tmp_path)
        except FileNotFoundError:
            pass


@app.post("/asr/url")
async def asr_url(url: str = Form(...)):
    """Run ASR from a remote file URL."""
    if not url or not url.startswith(("http://", "https://")):
        return JSONResponse(
            {"code": 1, "error": "Invalid URL, must start with http:// or https://"},
            status_code=400,
        )
    try:
        try:
            res = get_model().generate(input=url, batch_size_s=300)
        except Exception as first_err:
            if not _is_pipe_error(first_err):
                raise
            logger.warning("BrokenPipe during generate (url), retrying with fresh model")
            reset_model()
            res = get_model().generate(input=url, batch_size_s=300)

        text = "".join(item.get("text", "") for item in res)
        return JSONResponse({"code": 0, "text": text, "result": res})
    except Exception as e:
        logger.exception("ASR URL failed: %s", url)
        return JSONResponse({"code": 1, "error": str(e)}, status_code=500)


if __name__ == "__main__":
    import argparse

    import uvicorn

    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=10095)
    parser.add_argument(
        "--model-dir",
        default=None,
        help="Directory used as MODELSCOPE_CACHE (must match early parse)",
    )
    parser.add_argument(
        "--hub",
        default="ms",
        choices=["ms", "hf"],
        help="Model hub backend: ms (ModelScope) or hf (HuggingFace)",
    )
    parser.add_argument(
        "--hf-endpoint",
        default=None,
        help="Custom HuggingFace endpoint, e.g. https://hf-mirror.com",
    )
    args = parser.parse_args()

    uvicorn.run(app, host="0.0.0.0", port=args.port, access_log=False)
