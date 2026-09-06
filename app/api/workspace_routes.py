from functools import lru_cache
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel, Field, field_validator
from starlette.concurrency import run_in_threadpool

from app.api.routes import current_user, bearer_token
from app.core.dependencies import get_database, get_analysis_service, get_rule_engine, get_public_api_client
from app.services.workspace import Workspace, WorkspaceError
from app.services.profile_tokens import normalize_profile_token
from app.services.analysis import AnalysisError
from app.services.ocr import OcrProviderError, CostGuardError

router = APIRouter(prefix="/api/v1")
User = Annotated[dict, Depends(current_user)]
Token = Annotated[str, Depends(bearer_token)]


@lru_cache
def workspace():
    return Workspace(get_database())


class ProfileInput(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    profiles: list[str] = Field(min_length=1, max_length=30)
    language: Literal["ko", "en", "ar", "zh", "ja"] = "ko"

    @field_validator("profiles")
    @classmethod
    def valid_profiles(cls, values):
        tokens = [normalize_profile_token(v) for v in values]
        if any(t is None for t in tokens):
            raise ValueError("Unknown dietary criterion")
        return list(dict.fromkeys(tokens))


class CartItemInput(BaseModel):
    request_id: str = Field(min_length=1, max_length=64)
    name: str = Field(min_length=1, max_length=150)
    quantity: int = Field(default=1, ge=1, le=100)


class ProductInput(BaseModel):
    request_id: str = Field(min_length=1, max_length=64)
    name: str = Field(min_length=1, max_length=150)
    category: str = Field(min_length=1, max_length=60)


class NutritionInput(BaseModel):
    energy_kcal: float | None = Field(default=None, ge=0, le=100000, allow_inf_nan=False)
    sodium_mg: float | None = Field(default=None, ge=0, le=1000000, allow_inf_nan=False)
    carbohydrate_g: float | None = Field(default=None, ge=0, le=100000, allow_inf_nan=False)
    sugars_g: float | None = Field(default=None, ge=0, le=100000, allow_inf_nan=False)
    fat_g: float | None = Field(default=None, ge=0, le=100000, allow_inf_nan=False)
    saturated_fat_g: float | None = Field(default=None, ge=0, le=100000, allow_inf_nan=False)
    protein_g: float | None = Field(default=None, ge=0, le=100000, allow_inf_nan=False)


class PairInput(BaseModel):
    code: str = Field(min_length=16, max_length=100)


class ReferenceInput(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    kind: Literal['nutrition', 'ingredient'] = 'nutrition'


@router.post('/references/search')
def search_reference(payload: ReferenceInput, user: User):
    return get_public_api_client().search_reference(payload.name, payload.kind)


@router.post("/auth/logout")
def logout(user: User, token: Token):
    get_database().revoke_session(token)
    return {"status": "logged_out"}


@router.get("/family")
def families(user: User):
    return {"profiles": workspace().families(user["user_id"])}


@router.post("/family")
def save_family(payload: ProfileInput, user: User):
    return workspace().save_family(user["user_id"], **payload.model_dump())


@router.put("/family/{profile_id}")
def update_family(profile_id: str, payload: ProfileInput, user: User):
    return workspace().save_family(user["user_id"], **payload.model_dump(), profile_id=profile_id)


@router.delete("/family/{profile_id}")
def delete_family(profile_id: str, user: User):
    workspace().delete_family(user["user_id"], profile_id)
    return {"status": "deleted"}


@router.get("/history")
def history(user: User):
    return {"analyses": workspace().history(user["user_id"])}


@router.post("/carts")
def create_cart(payload: ProfileInput, user: User):
    return workspace().create_cart(user["user_id"], **payload.model_dump())


@router.get("/carts")
def carts(user: User):
    return {"carts": workspace().carts(user["user_id"])}


@router.get("/carts/{cart_id}")
def cart_report(cart_id: str, user: User):
    return workspace().report(user["user_id"], cart_id)


@router.post("/carts/{cart_id}/items")
def cart_add(cart_id: str, payload: CartItemInput, user: User):
    return workspace().add_item(user["user_id"], cart_id, **payload.model_dump())


@router.delete("/carts/{cart_id}/items/{item_id}")
def cart_remove(cart_id: str, item_id: str, user: User):
    workspace().remove_item(user["user_id"], cart_id, item_id)
    return {"status": "deleted"}


@router.post("/carts/{cart_id}/close")
def cart_close(cart_id: str, user: User):
    return workspace().close_cart(user["user_id"], cart_id)


@router.put('/carts/{cart_id}/items/{item_id}/nutrition')
def cart_nutrition(cart_id: str, item_id: str, payload: NutritionInput, user: User):
    return workspace().confirm_nutrition(user['user_id'], cart_id, item_id, payload.model_dump(exclude_none=True))


@router.post("/carts/{cart_id}/pair")
def cart_pair(cart_id: str, user: User):
    return workspace().pairing(user["user_id"], cart_id)


@router.post("/devices/redeem")
def device_redeem(payload: PairInput):
    return workspace().redeem(payload.code)


@router.get("/devices/session")
def device_session(token: Token):
    cart = workspace().device_cart(token)
    return {k:cart[k] for k in ["id", "name", "profiles", "language", "status"]}


@router.post("/devices/analyze")
async def device_analyze(token: Token, file: UploadFile = File(...), name: str = Form("카트 스캔")):
    cart = workspace().device_cart(token)
    service = get_analysis_service()
    raw = await file.read(service.settings.ocr_max_upload_mb * 1024 * 1024 + 1)
    try:
        result = await run_in_threadpool(service.analyze_image, image_bytes=raw, filename=file.filename,
            profiles=cart["profiles"], user_id=cart["user_id"], language=cart["language"])
    except AnalysisError as exc:
        raise HTTPException(400, str(exc)) from exc
    except CostGuardError as exc:
        raise HTTPException(402, str(exc)) from exc
    except OcrProviderError as exc:
        raise HTTPException(502, str(exc)) from exc
    # Recheck after OCR: closing a cart immediately revokes device access.
    workspace().device_cart(token)
    workspace().add_item(cart["user_id"], cart["id"], result["request_id"], name[:150], 1)
    return result


@router.post("/products")
def product_save(payload: ProductInput, user: User):
    return workspace().save_product(user["user_id"], **payload.model_dump())


@router.get('/products')
def products(user: User):
    return {'products': workspace().products(user['user_id'])}


@router.delete('/products/{product_id}')
def product_delete(product_id: str, user: User):
    workspace().delete_product(user['user_id'], product_id)
    return {'status': 'deleted'}


@router.post("/alternatives")
def alternatives(payload: ProfileInput, user: User):
    return workspace().alternatives(user["user_id"], payload.profiles, payload.name, get_rule_engine())
